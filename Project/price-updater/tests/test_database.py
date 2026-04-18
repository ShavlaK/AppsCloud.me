"""
Тесты для SQLite хранилища цен.
"""

from datetime import datetime, timedelta

import pytest

from price_database import PriceDatabase


class TestPriceDatabase:
    """Тесты SQLite хранилища."""

    @pytest.fixture
    def db(self, temp_dir):
        return PriceDatabase(db_path="test_prices.db")

    def test_save_snapshot(self, db):
        """Сохранение снимка."""
        prices = [
            {"name": "Item 1", "original_price": 1000, "price": 1500},
            {"name": "Item 2", "original_price": 2000, "price": 2500},
        ]

        snapshot_id = db.save_snapshot(prices, markup=500)

        assert snapshot_id > 0
        assert db.get_snapshot_count() == 1

    def test_get_latest_snapshot(self, db):
        """Получение последнего снимка."""
        prices = [
            {"name": "Item 1", "original_price": 1000, "price": 1500},
        ]

        db.save_snapshot(prices, markup=500)
        result = db.get_latest_snapshot()

        assert result is not None
        snapshot, items = result
        assert len(items) == 1
        assert items[0]["name"] == "Item 1"

    def test_get_latest_snapshot_empty(self, db):
        """Получение снимка из пустой базы."""
        result = db.get_latest_snapshot()
        assert result is None

    def test_cleanup_old_snapshots(self, db):
        """Удаление старых снимков."""
        # Устанавливаем короткое время хранения
        db.retention_days = 1

        prices = [{"name": "Item 1", "original_price": 1000, "price": 1500}]

        # Сохраняем снимок
        db.save_snapshot(prices)
        assert db.get_snapshot_count() == 1

        # manually вставляем старую дату
        with db.get_connection() as conn:
            conn.execute(
                "UPDATE price_snapshots SET snapshot_date = ?",
                ((datetime.now() - timedelta(days=10)).strftime("%Y-%m-%d"),)
            )

        # Сохраняем ещё один — триггерит очистку
        db.save_snapshot(prices)

        # Старый должен быть удалён
        assert db.get_snapshot_count() == 1

    def test_get_snapshot_by_date(self, db):
        """Получение снимка по дате."""
        prices = [{"name": "Item 1", "original_price": 1000, "price": 1500}]
        db.save_snapshot(prices)

        today = datetime.now().strftime("%Y-%m-%d")
        result = db.get_snapshot_by_date(today)

        assert result is not None
        snapshot, items = result
        assert len(items) == 1

    def test_get_snapshot_by_date_empty(self, db):
        """Получение снимка за дату без данных."""
        result = db.get_snapshot_by_date("2000-01-01")
        assert result is None

    def test_get_all_product_names(self, db):
        """Получение уникальных названий товаров."""
        prices1 = [{"name": "iPhone 15", "original_price": 50000, "price": 50500}]
        prices2 = [{"name": "Samsung S24", "original_price": 45000, "price": 45500}]

        db.save_snapshot(prices1)
        db.save_snapshot(prices2)

        names = db.get_all_product_names()
        assert "iPhone 15" in names
        assert "Samsung S24" in names
        assert len(names) == 2

    def test_storage_stats(self, db):
        """Статистика хранилища."""
        prices = [{"name": "Item 1", "original_price": 1000, "price": 1500}]
        db.save_snapshot(prices)

        stats = db.get_storage_stats()

        assert stats["snapshots_count"] == 1
        assert stats["items_count"] == 1
        assert stats["db_size_mb"] > 0

    def test_multiple_snapshots(self, db):
        """Несколько снимков."""
        for i in range(5):
            prices = [{"name": f"Item {i}", "original_price": 1000, "price": 1500}]
            db.save_snapshot(prices)

        assert db.get_snapshot_count() == 5
