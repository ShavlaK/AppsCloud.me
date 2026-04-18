"""
Тесты для генератора отчётов.
"""

import pytest

from price_database import PriceDatabase
from report_generator import ReportGenerator


class TestReportGenerator:
    """Тесты генератора отчётов."""

    @pytest.fixture
    def db(self, temp_dir):
        return PriceDatabase(db_path="test_reports.db")

    @pytest.fixture
    def generator(self, db):
        return ReportGenerator(db)

    def _add_snapshot(self, db, prices, date_str=None, time_str=None):
        """Добавляет снимок с определённой датой и временем."""
        if date_str is None:
            db.save_snapshot(prices, skip_cleanup=True)
        else:
            db.save_snapshot(
                prices,
                snapshot_date=date_str,
                snapshot_time=time_str or "12:00:00",
                skip_cleanup=True,
            )

    def test_report_price_increased(self, generator, db):
        """Отчёт: цена выросла."""
        old_prices = [{"name": "iPhone 15", "original_price": 50000, "price": 50000}]
        new_prices = [{"name": "iPhone 15", "original_price": 55000, "price": 55000}]

        self._add_snapshot(db, old_prices, "2026-03-01", "10:00:00")
        self._add_snapshot(db, new_prices, "2026-03-31", "18:00:00")

        report = generator.generate_period_report("2026-03-01", "2026-03-31")

        assert report is not None
        assert len(report.price_increased) == 1
        assert report.price_increased[0].name == "iPhone 15"
        assert report.price_increased[0].difference == 5000
        assert report.price_increased[0].difference_percent == 10.0

    def test_report_price_decreased(self, generator, db):
        """Отчёт: цена упала."""
        old_prices = [{"name": "iPhone 15", "original_price": 60000, "price": 60000}]
        new_prices = [{"name": "iPhone 15", "original_price": 50000, "price": 50000}]

        self._add_snapshot(db, old_prices, "2026-03-01", "10:00:00")
        self._add_snapshot(db, new_prices, "2026-03-31", "18:00:00")

        report = generator.generate_period_report("2026-03-01", "2026-03-31")

        assert report is not None
        assert len(report.price_decreased) == 1
        assert report.price_decreased[0].name == "iPhone 15"
        assert report.price_decreased[0].difference == -10000
        assert report.price_decreased[0].difference_percent == pytest.approx(-16.7, abs=0.1)

    def test_report_price_unchanged(self, generator, db):
        """Отчёт: цена не изменилась."""
        prices = [{"name": "iPhone 15", "original_price": 50000, "price": 50000}]

        self._add_snapshot(db, prices, "2026-03-01", "10:00:00")
        self._add_snapshot(db, prices, "2026-03-31", "18:00:00")

        report = generator.generate_period_report("2026-03-01", "2026-03-31")

        assert report is not None
        assert len(report.price_unchanged) == 1

    def test_report_new_item(self, generator, db):
        """Отчёт: новая позиция."""
        old_prices = [{"name": "iPhone 15", "original_price": 50000, "price": 50000}]
        new_prices = [
            {"name": "iPhone 15", "original_price": 50000, "price": 50000},
            {"name": "iPhone 16", "original_price": 60000, "price": 60000},
        ]

        self._add_snapshot(db, old_prices, "2026-03-01", "10:00:00")
        self._add_snapshot(db, new_prices, "2026-03-31", "18:00:00")

        report = generator.generate_period_report("2026-03-01", "2026-03-31")

        assert report is not None
        assert len(report.new_items) == 1
        assert report.new_items[0].name == "iPhone 16"

    def test_report_removed_item(self, generator, db):
        """Отчёт: позиция исчезнула."""
        old_prices = [
            {"name": "iPhone 15", "original_price": 50000, "price": 50000},
            {"name": "iPhone 14", "original_price": 40000, "price": 40000},
        ]
        new_prices = [{"name": "iPhone 15", "original_price": 50000, "price": 50000}]

        self._add_snapshot(db, old_prices, "2026-03-01", "10:00:00")
        self._add_snapshot(db, new_prices, "2026-03-31", "18:00:00")

        report = generator.generate_period_report("2026-03-01", "2026-03-31")

        assert report is not None
        assert len(report.removed_items) == 1
        assert report.removed_items[0].name == "iPhone 14"

    def test_report_no_data(self, generator, db):
        """Отчёт: нет данных за период."""
        report = generator.generate_period_report("2020-01-01", "2020-01-31")
        assert report is None

    def test_format_report_text(self, generator, db):
        """Форматирование отчёта в текст."""
        old_prices = [{"name": "iPhone 15", "original_price": 50000, "price": 50000}]
        new_prices = [{"name": "iPhone 15", "original_price": 55000, "price": 55000}]

        self._add_snapshot(db, old_prices, "2026-03-01", "10:00:00")
        self._add_snapshot(db, new_prices, "2026-03-31", "18:00:00")

        report = generator.generate_period_report("2026-03-01", "2026-03-31")
        text = generator.format_report_text(report)

        assert "iPhone 15" in text
        assert "50000" in text
        assert "55000" in text
        assert "📈" in text

    def test_format_report_json(self, generator, db):
        """Форматирование отчёта в JSON."""
        old_prices = [{"name": "iPhone 15", "original_price": 50000, "price": 50000}]
        new_prices = [{"name": "iPhone 15", "original_price": 55000, "price": 55000}]

        self._add_snapshot(db, old_prices, "2026-03-01", "10:00:00")
        self._add_snapshot(db, new_prices, "2026-03-31", "18:00:00")

        report = generator.generate_period_report("2026-03-01", "2026-03-31")
        json_text = generator.format_report_json(report)

        import json
        data = json.loads(json_text)

        assert "summary" in data
        assert data["summary"]["price_increased_count"] == 1

    def test_save_report_to_file(self, generator, db, temp_dir):
        """Сохранение отчёта в файл."""
        old_prices = [{"name": "iPhone 15", "original_price": 50000, "price": 50000}]
        new_prices = [{"name": "iPhone 15", "original_price": 55000, "price": 55000}]

        self._add_snapshot(db, old_prices, "2026-03-01", "10:00:00")
        self._add_snapshot(db, new_prices, "2026-03-31", "18:00:00")

        report = generator.generate_period_report("2026-03-01", "2026-03-31")
        filepath = generator.save_report_to_file(report, output_path="test_reports")

        import os
        assert os.path.exists(filepath)

        import json
        with open(filepath) as f:
            data = json.load(f)

        assert data["summary"]["price_increased_count"] == 1
