"""
Модуль формирования ежемесячных отчётов об изменениях цен.
Сравнивает снимки прайсов, выявляет:
- Изменение цен (рост/падение/без изменений)
- Новые позиции
- Исчезнувшие позиции
"""

import json
import logging
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from enum import Enum
from typing import Dict, List, Optional, Any
from collections import defaultdict

from price_database import PriceDatabase

logger = logging.getLogger(__name__)


class PriceChange(Enum):
    """Тип изменения цены."""
    INCREASED = "increased"       # Цена выросла
    DECREASED = "decreased"       # Цена упала
    UNCHANGED = "unchanged"       # Без изменений
    NEW = "new"                   # Новая позиция
    REMOVED = "removed"           # Позиция исчезла


@dataclass
class PriceChangeInfo:
    """Информация об изменении цены."""
    name: str
    change_type: PriceChange
    old_price: Optional[float] = None
    new_price: Optional[float] = None
    difference: float = 0.0
    difference_percent: float = 0.0


@dataclass
class MonthlyReport:
    """Ежемесячный отчёт."""
    period_start: str           # YYYY-MM-DD
    period_end: str             # YYYY-MM-DD
    generated_at: str           # ISO datetime

    # Статистика
    total_items_start: int = 0
    total_items_end: int = 0

    # Изменения
    price_increased: List[PriceChangeInfo] = field(default_factory=list)
    price_decreased: List[PriceChangeInfo] = field(default_factory=list)
    price_unchanged: List[PriceChangeInfo] = field(default_factory=list)
    new_items: List[PriceChangeInfo] = field(default_factory=list)
    removed_items: List[PriceChangeInfo] = field(default_factory=list)

    # Сводка
    @property
    def summary(self) -> Dict:
        return {
            "period": f"{self.period_start} — {self.period_end}",
            "generated_at": self.generated_at,
            "total_items_start": self.total_items_start,
            "total_items_end": self.total_items_end,
            "price_increased_count": len(self.price_increased),
            "price_decreased_count": len(self.price_decreased),
            "price_unchanged_count": len(self.price_unchanged),
            "new_items_count": len(self.new_items),
            "removed_items_count": len(self.removed_items),
            "avg_increase_percent": self._avg_percent(self.price_increased),
            "avg_decrease_percent": self._avg_percent(self.price_decreased),
        }

    @staticmethod
    def _avg_percent(items: List[PriceChangeInfo]) -> float:
        if not items:
            return 0.0
        return round(sum(i.difference_percent for i in items) / len(items), 1)


class ReportGenerator:
    """Генератор отчётов об изменениях цен."""

    def __init__(self, database: PriceDatabase):
        self.db = database

    def generate_monthly_report(
        self,
        year: int = None,
        month: int = None
    ) -> Optional[MonthlyReport]:
        """
        Генерирует отчёт за месяц.

        Args:
            year: Год (по умолчанию — текущий)
            month: Месяц (по умолчанию — предыдущий)

        Returns:
            MonthlyReport или None если нет данных
        """
        now = datetime.now()

        if year is None:
            year = now.year
        if month is None:
            month = now.month - 1
            if month == 0:
                month = 12
                year -= 1

        # Определяем период
        period_start = f"{year}-{month:02d}-01"

        # Последний день месяца
        if month == 12:
            next_month = f"{year + 1}-01-01"
        else:
            next_month = f"{year}-{month + 1:02d}-01"

        period_end = (
            datetime.strptime(next_month, "%Y-%m-%d") - timedelta(days=1)
        ).strftime("%Y-%m-%d")

        logger.info(f"Генерация отчёта за период: {period_start} — {period_end}")

        # Получаем снимки за период
        snapshots = self.db.get_snapshots_for_period(period_start, period_end)

        if not snapshots:
            logger.warning(f"Нет данных за период {period_start} — {period_end}")
            return None

        # Берём первый и последний снимки
        first_snapshot, first_items = snapshots[0]
        last_snapshot, last_items = snapshots[-1]

        # Сравниваем
        return self._compare_snapshots(
            first_items,
            last_items,
            period_start,
            period_end
        )

    def generate_period_report(
        self,
        start_date: str,
        end_date: str
    ) -> Optional[MonthlyReport]:
        """
        Генерирует отчёт за произвольный период.

        Args:
            start_date: YYYY-MM-DD
            end_date: YYYY-MM-DD
        """
        logger.info(f"Генерация отчёта за период: {start_date} — {end_date}")

        snapshots = self.db.get_snapshots_for_period(start_date, end_date)

        if not snapshots:
            logger.warning(f"Нет данных за период {start_date} — {end_date}")
            return None

        first_snapshot, first_items = snapshots[0]
        last_snapshot, last_items = snapshots[-1]

        return self._compare_snapshots(
            first_items,
            last_items,
            start_date,
            end_date
        )

    def _compare_snapshots(
        self,
        old_items: List[Dict],
        new_items: List[Dict],
        period_start: str,
        period_end: str
    ) -> MonthlyReport:
        """
        Сравнивает два снимка и формирует отчёт.
        """
        # Создаём словари name -> item
        old_dict = {item["name"]: item for item in old_items}
        new_dict = {item["name"]: item for item in new_items}

        old_names = set(old_dict.keys())
        new_names = set(new_dict.keys())

        report = MonthlyReport(
            period_start=period_start,
            period_end=period_end,
            generated_at=datetime.now().isoformat(),
            total_items_start=len(old_items),
            total_items_end=len(new_items)
        )

        # Новые позиции
        for name in (new_names - old_names):
            item = new_dict[name]
            report.new_items.append(PriceChangeInfo(
                name=name,
                change_type=PriceChange.NEW,
                old_price=None,
                new_price=item["final_price"],
                difference=item["final_price"],
                difference_percent=0.0
            ))

        # Исчезнувшие позиции
        for name in (old_names - new_names):
            item = old_dict[name]
            report.removed_items.append(PriceChangeInfo(
                name=name,
                change_type=PriceChange.REMOVED,
                old_price=item["final_price"],
                new_price=None,
                difference=-item["final_price"],
                difference_percent=0.0
            ))

        # Общие позиции — сравниваем цены
        for name in (old_names & new_names):
            old_item = old_dict[name]
            new_item = new_dict[name]

            old_price = old_item["final_price"]
            new_price = new_item["final_price"]
            difference = new_price - old_price

            # Процент изменения
            if old_price > 0:
                difference_percent = round((difference / old_price) * 100, 1)
            else:
                difference_percent = 0.0

            if difference > 0:
                change_type = PriceChange.INCREASED
                report.price_increased.append(PriceChangeInfo(
                    name=name,
                    change_type=change_type,
                    old_price=old_price,
                    new_price=new_price,
                    difference=difference,
                    difference_percent=difference_percent
                ))
            elif difference < 0:
                change_type = PriceChange.DECREASED
                report.price_decreased.append(PriceChangeInfo(
                    name=name,
                    change_type=change_type,
                    old_price=old_price,
                    new_price=new_price,
                    difference=difference,
                    difference_percent=difference_percent
                ))
            else:
                change_type = PriceChange.UNCHANGED
                report.price_unchanged.append(PriceChangeInfo(
                    name=name,
                    change_type=change_type,
                    old_price=old_price,
                    new_price=new_price,
                    difference=0,
                    difference_percent=0.0
                ))

        # Сортируем по абсолютному проценту изменения (по убыванию)
        report.price_increased.sort(key=lambda x: abs(x.difference_percent), reverse=True)
        report.price_decreased.sort(key=lambda x: abs(x.difference_percent), reverse=True)
        report.new_items.sort(key=lambda x: x.name)
        report.removed_items.sort(key=lambda x: x.name)

        logger.info(
            f"Отчёт сформирован: "
            f"↑{len(report.price_increased)} ↓{len(report.price_decreased)} "
            f"—{len(report.price_unchanged)} +{len(report.new_items)} "
            f"-{len(report.removed_items)}"
        )

        return report

    def format_report_text(self, report: MonthlyReport) -> str:
        """
        Форматирует отчёт в текстовый вид (для Telegram/файла).
        """
        lines = [
            "📊 <b>Отчёт об изменениях цен</b>",
            f"📅 Период: <b>{report.period_start}</b> — <b>{report.period_end}</b>",
            f"🕐 Сформирован: {report.generated_at[:19]}",
            "",
            "─────────────────",
            f"📦 Позиций на начало: <b>{report.total_items_start}</b>",
            f"📦 Позиций на конец: <b>{report.total_items_end}</b>",
            "",
        ]

        # Рост цен
        if report.price_increased:
            lines.append(f"📈 <b>Выросли в цене ({len(report.price_increased)})</b>")
            for item in report.price_increased[:10]:  # Топ-10
                lines.append(
                    f"  • {item.name}: "
                    f"{item.old_price:.0f} → {item.new_price:.0f} ₽ "
                    f"(+{item.difference_percent}%)"
                )
            if len(report.price_increased) > 10:
                lines.append(f"  ... и ещё {len(report.price_increased) - 10}")
            lines.append("")

        # Падение цен
        if report.price_decreased:
            lines.append(f"📉 <b>Упали в цене ({len(report.price_decreased)})</b>")
            for item in report.price_decreased[:10]:
                lines.append(
                    f"  • {item.name}: "
                    f"{item.old_price:.0f} → {item.new_price:.0f} ₽ "
                    f"({item.difference_percent}%)"
                )
            if len(report.price_decreased) > 10:
                lines.append(f"  ... и ещё {len(report.price_decreased) - 10}")
            lines.append("")

        # Без изменений
        if report.price_unchanged:
            lines.append(f"➡️ <b>Без изменений: {len(report.price_unchanged)}</b>")
            lines.append("")

        # Новые позиции
        if report.new_items:
            lines.append(f"🆕 <b>Новые позиции ({len(report.new_items)})</b>")
            for item in report.new_items[:10]:
                lines.append(f"  • {item.name}: {item.new_price:.0f} ₽")
            if len(report.new_items) > 10:
                lines.append(f"  ... и ещё {len(report.new_items) - 10}")
            lines.append("")

        # Исчезнувшие позиции
        if report.removed_items:
            lines.append(f"❌ <b>Исчезли ({len(report.removed_items)})</b>")
            for item in report.removed_items[:10]:
                lines.append(f"  • {item.name} (было: {item.old_price:.0f} ₽)")
            if len(report.removed_items) > 10:
                lines.append(f"  ... и ещё {len(report.removed_items) - 10}")
            lines.append("")

        lines.append("─────────────────")
        lines.append("📋 <i>Полный отчёт доступен в веб-интерфейсе</i>")

        return "\n".join(lines)

    def format_report_json(self, report: MonthlyReport) -> str:
        """Форматирует отчёт в JSON."""
        def serialize_change_info(item: PriceChangeInfo) -> Dict:
            return {
                "name": item.name,
                "change_type": item.change_type.value,
                "old_price": item.old_price,
                "new_price": item.new_price,
                "difference": item.difference,
                "difference_percent": item.difference_percent
            }

        data = {
            "period_start": report.period_start,
            "period_end": report.period_end,
            "generated_at": report.generated_at,
            "summary": report.summary,
            "price_increased": [serialize_change_info(i) for i in report.price_increased],
            "price_decreased": [serialize_change_info(i) for i in report.price_decreased],
            "price_unchanged": [serialize_change_info(i) for i in report.price_unchanged],
            "new_items": [serialize_change_info(i) for i in report.new_items],
            "removed_items": [serialize_change_info(i) for i in report.removed_items],
        }

        return json.dumps(data, ensure_ascii=False, indent=2)

    def save_report_to_file(
        self,
        report: MonthlyReport,
        output_path: str = "reports"
    ) -> str:
        """
        Сохраняет отчёт в файл.

        Returns:
            Путь к файлу
        """
        import os

        os.makedirs(output_path, exist_ok=True)

        filename = f"report_{report.period_start}_{report.period_end}.json"
        filepath = os.path.join(output_path, filename)

        json_text = self.format_report_json(report)
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(json_text)

        logger.info(f"Отчёт сохранён: {filepath}")
        return filepath

    def generate_price_trend_report(self, product_name: Optional[str] = None, days: int = 30) -> Dict[str, Any]:
        """Генерирует отчет о динамике цен за последние N дней."""
        conn = self.db._get_connection()
        try:
            cursor = conn.cursor()
            date_from = (datetime.now() - timedelta(days=days)).isoformat()
            
            query = """
                SELECT product_name, price, timestamp 
                FROM price_history 
                WHERE timestamp > ? 
            """
            params = [date_from]
            
            if product_name:
                query += " AND product_name = ?"
                params.append(product_name)
            
            query += " ORDER BY timestamp ASC"
            
            cursor.execute(query, params)
            rows = cursor.fetchall()
            
            # Группировка данных по продуктам
            trends = defaultdict(list)
            for row in rows:
                trends[row['product_name']].append({
                    'date': row['timestamp'],
                    'price': row['price']
                })
            
            return {
                'success': True,
                'data': dict(trends),
                'period_days': days
            }
        except Exception as e:
            logger.error(f"Error generating trend report: {e}")
            return {'success': False, 'error': str(e)}
        finally:
            conn.close()

    def generate_day_of_week_analysis(self, product_name: Optional[str] = None, weeks: int = 4) -> Dict[str, Any]:
        """Анализирует среднюю цену по дням недели за последние N недель."""
        conn = self.db._get_connection()
        try:
            cursor = conn.cursor()
            date_from = (datetime.now() - timedelta(weeks=weeks)).isoformat()
            
            query = """
                SELECT product_name, price, timestamp 
                FROM price_history 
                WHERE timestamp > ? 
            """
            params = [date_from]
            
            if product_name:
                query += " AND product_name = ?"
                params.append(product_name)
            
            cursor.execute(query, params)
            rows = cursor.fetchall()
            
            # Агрегация по дням недели (0=Пн, 6=Вс)
            day_prices = defaultdict(list)
            for row in rows:
                dt = datetime.fromisoformat(row['timestamp'])
                day_idx = dt.weekday()
                day_prices[day_idx].append(row['price'])
            
            result = {}
            day_names = ["Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота", "Воскресенье"]
            
            for i in range(7):
                prices = day_prices[i]
                avg_price = sum(prices) / len(prices) if prices else 0
                min_price = min(prices) if prices else 0
                max_price = max(prices) if prices else 0
                result[day_names[i]] = {
                    'average': round(avg_price, 2),
                    'min': min_price,
                    'max': max_price,
                    'count': len(prices)
                }
            
            return {
                'success': True,
                'data': result
            }
        except Exception as e:
            logger.error(f"Error generating day of week analysis: {e}")
            return {'success': False, 'error': str(e)}
        finally:
            conn.close()

    def generate_monthly_volatility(self, product_name: Optional[str] = None, months: int = 3) -> Dict[str, Any]:
        """Анализирует волатильность и изменения цен по месяцам."""
        conn = self.db._get_connection()
        try:
            cursor = conn.cursor()
            date_from = (datetime.now() - timedelta(days=months*30)).isoformat()
            
            query = """
                SELECT product_name, price, timestamp 
                FROM price_history 
                WHERE timestamp > ? 
            """
            params = [date_from]
            
            if product_name:
                query += " AND product_name = ?"
                params.append(product_name)
            
            cursor.execute(query, params)
            rows = cursor.fetchall()
            
            # Группировка по месяцам (YYYY-MM)
            month_data = defaultdict(list)
            for row in rows:
                dt = datetime.fromisoformat(row['timestamp'])
                month_key = dt.strftime("%Y-%m")
                month_data[month_key].append(row['price'])
            
            result = {}
            sorted_months = sorted(month_data.keys())
            
            prev_avg = None
            for month in sorted_months:
                prices = month_data[month]
                avg_price = sum(prices) / len(prices)
                volatility = (max(prices) - min(prices)) if prices else 0
                
                change_percent = 0.0
                if prev_avg is not None and prev_avg > 0:
                    change_percent = ((avg_price - prev_avg) / prev_avg) * 100
                
                result[month] = {
                    'average': round(avg_price, 2),
                    'min': min(prices),
                    'max': max(prices),
                    'volatility': round(volatility, 2),
                    'change_percent': round(change_percent, 2),
                    'samples': len(prices)
                }
                prev_avg = avg_price
            
            return {
                'success': True,
                'data': result
            }
        except Exception as e:
            logger.error(f"Error generating monthly volatility report: {e}")
            return {'success': False, 'error': str(e)}
        finally:
            conn.close()

    def get_all_stats(self, product_name: Optional[str] = None) -> Dict[str, Any]:
        """Получает всю статистику одним запросом для фронтенда."""
        trend = self.generate_price_trend_report(product_name, days=30)
        dow = self.generate_day_of_week_analysis(product_name, weeks=8)
        monthly = self.generate_monthly_volatility(product_name, months=3)
        
        return {
            'trend_30d': trend.get('data', {}),
            'day_of_week': dow.get('data', {}),
            'monthly': monthly.get('data', {})
        }
