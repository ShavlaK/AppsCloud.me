"""
SQLite хранилище для истории цен.
Хранит снимки прайсов за 30 дней для последующего формирования отчётов.
"""

import logging
import os
import sqlite3
from contextlib import contextmanager
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple

logger = logging.getLogger(__name__)


class PriceDatabase:
    """SQLite база для хранения истории цен."""

    def __init__(self, db_path: str = "prices.db", retention_days: int = 30):
        """
        Args:
            db_path: Путь к файлу базы данных
            retention_days: Сколько дней хранить историю
        """
        self.db_path = db_path
        self.retention_days = retention_days
        self._init_db()

    @contextmanager
    def get_connection(self):
        """Контекстный менеджер для подключения к БД."""
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        try:
            yield conn
            conn.commit()
        except Exception as e:
            conn.rollback()
            raise e
        finally:
            conn.close()

    def _init_db(self):
        """Создаёт таблицы если их нет."""
        with self.get_connection() as conn:
            conn.executescript("""
                -- Таблица снимков прайсов
                CREATE TABLE IF NOT EXISTS price_snapshots (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    snapshot_date TEXT NOT NULL,
                    snapshot_time TEXT NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );

                -- Таблица позиций в снимке
                CREATE TABLE IF NOT EXISTS price_items (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    snapshot_id INTEGER NOT NULL,
                    name TEXT NOT NULL,
                    original_price REAL NOT NULL,
                    final_price REAL NOT NULL,
                    markup REAL DEFAULT 0,
                    FOREIGN KEY (snapshot_id) REFERENCES price_snapshots(id)
                );

                -- Индексы для ускорения
                CREATE INDEX IF NOT EXISTS idx_snapshot_date
                    ON price_snapshots(snapshot_date);
                CREATE INDEX IF NOT EXISTS idx_item_name
                    ON price_items(name);
                CREATE INDEX IF NOT EXISTS idx_item_snapshot
                    ON price_items(snapshot_id);
            """)

            logger.info("База данных инициализирована")

    def save_snapshot(
        self,
        prices: List[Dict[str, any]],
        markup: float = 0,
        snapshot_date: str = None,
        snapshot_time: str = None,
        skip_cleanup: bool = False,
    ) -> int:
        """
        Сохраняет снимок прайса.

        Args:
            prices: Список позиций [{"name": "...", "original_price": 100, "price": 150}]
            markup: Применённая наценка
            snapshot_date: Дата снимка (YYYY-MM-DD), по умолчанию — сегодня
            snapshot_time: Время снимка (HH:MM:SS), по умолчанию — сейчас
            skip_cleanup: Пропустить удаление старых записей (для тестов)

        Returns:
            ID сохранённого снимка
        """
        now = datetime.now()
        if snapshot_date is None:
            snapshot_date = now.strftime("%Y-%m-%d")
        if snapshot_time is None:
            snapshot_time = now.strftime("%H:%M:%S")

        with self.get_connection() as conn:
            cursor = conn.execute(
                "INSERT INTO price_snapshots (snapshot_date, snapshot_time) VALUES (?, ?)",
                (snapshot_date, snapshot_time)
            )
            snapshot_id = cursor.lastrowid

            for item in prices:
                conn.execute(
                    """INSERT INTO price_items
                       (snapshot_id, name, original_price, final_price, markup)
                       VALUES (?, ?, ?, ?, ?)""",
                    (
                        snapshot_id,
                        item["name"],
                        item.get("original_price", item["price"]),
                        item["price"],
                        markup
                    )
                )

            logger.info(
                f"Сохранён снимок #{snapshot_id}: {len(prices)} позиций, "
                f"{snapshot_date} {snapshot_time}"
            )

        # Очищаем старые записи (только если не пропущено)
        if not skip_cleanup:
            self._cleanup_old_snapshots()

        return snapshot_id

    def _cleanup_old_snapshots(self):
        """Удаляет снимки старше retention_days."""
        cutoff_date = (datetime.now() - timedelta(days=self.retention_days)).strftime("%Y-%m-%d")

        with self.get_connection() as conn:
            # Находим старые снимки
            old_snapshots = conn.execute(
                "SELECT id FROM price_snapshots WHERE snapshot_date < ?",
                (cutoff_date,)
            ).fetchall()

            if old_snapshots:
                snapshot_ids = [row["id"] for row in old_snapshots]
                placeholders = ",".join("?" * len(snapshot_ids))

                conn.execute(
                    f"DELETE FROM price_items WHERE snapshot_id IN ({placeholders})",
                    snapshot_ids
                )
                conn.execute(
                    f"DELETE FROM price_snapshots WHERE id IN ({placeholders})",
                    snapshot_ids
                )

                logger.info(f"Удалено {len(snapshot_ids)} старых снимков")

    def get_latest_snapshot(self) -> Optional[Tuple[Dict, List[Dict]]]:
        """
        Возвращает последний снимок.

        Returns:
            (snapshot_info, items) или None
        """
        with self.get_connection() as conn:
            snapshot = conn.execute(
                "SELECT * FROM price_snapshots ORDER BY created_at DESC LIMIT 1"
            ).fetchone()

            if not snapshot:
                return None

            items = conn.execute(
                "SELECT * FROM price_items WHERE snapshot_id = ?",
                (snapshot["id"],)
            ).fetchall()

            return (
                dict(snapshot),
                [dict(item) for item in items]
            )

    def get_snapshot_by_date(self, date_str: str) -> Optional[Tuple[Dict, List[Dict]]]:
        """
        Возвращает снимок за определённую дату (последний за этот день).

        Args:
            date_str: Дата в формате YYYY-MM-DD
        """
        with self.get_connection() as conn:
            snapshot = conn.execute(
                """SELECT * FROM price_snapshots
                   WHERE snapshot_date = ?
                   ORDER BY snapshot_time DESC LIMIT 1""",
                (date_str,)
            ).fetchone()

            if not snapshot:
                return None

            items = conn.execute(
                "SELECT * FROM price_items WHERE snapshot_id = ?",
                (snapshot["id"],)
            ).fetchall()

            return (dict(snapshot), [dict(item) for item in items])

    def get_snapshots_for_period(
        self,
        start_date: str,
        end_date: str
    ) -> List[Tuple[Dict, List[Dict]]]:
        """
        Возвращает все снимки за период.

        Args:
            start_date: YYYY-MM-DD
            end_date: YYYY-MM-DD
        """
        with self.get_connection() as conn:
            snapshots = conn.execute(
                """SELECT * FROM price_snapshots
                   WHERE snapshot_date BETWEEN ? AND ?
                   ORDER BY snapshot_date, snapshot_time""",
                (start_date, end_date)
            ).fetchall()

            result = []
            for snapshot in snapshots:
                items = conn.execute(
                    "SELECT * FROM price_items WHERE snapshot_id = ?",
                    (snapshot["id"],)
                ).fetchall()
                result.append((
                    dict(snapshot),
                    [dict(item) for item in items]
                ))

            return result

    def get_all_product_names(self) -> List[str]:
        """Возвращает список всех уникальных названий товаров."""
        with self.get_connection() as conn:
            rows = conn.execute(
                "SELECT DISTINCT name FROM price_items ORDER BY name"
            ).fetchall()
            return [row["name"] for row in rows]

    def get_snapshot_count(self) -> int:
        """Возвращает количество снимков в базе."""
        with self.get_connection() as conn:
            result = conn.execute("SELECT COUNT(*) as cnt FROM price_snapshots").fetchone()
            return result["cnt"]

    def get_storage_stats(self) -> Dict:
        """Возвращает статистику хранилища."""
        with self.get_connection() as conn:
            snapshots_count = conn.execute(
                "SELECT COUNT(*) as cnt FROM price_snapshots"
            ).fetchone()["cnt"]

            items_count = conn.execute(
                "SELECT COUNT(*) as cnt FROM price_items"
            ).fetchone()["cnt"]

            date_range = conn.execute(
                """SELECT MIN(snapshot_date) as min_date,
                          MAX(snapshot_date) as max_date
                   FROM price_snapshots"""
            ).fetchone()

            db_size = os.path.getsize(self.db_path) if os.path.exists(self.db_path) else 0

            return {
                "snapshots_count": snapshots_count,
                "items_count": items_count,
                "first_date": date_range["min_date"],
                "last_date": date_range["max_date"],
                "db_size_mb": round(db_size / 1_000_000, 2)
            }
