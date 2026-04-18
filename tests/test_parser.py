"""
Тесты для парсера цен из Telegram.
"""

import pytest

from telegram_parser import SourceBotParser


class TestSourceBotParser:
    """Тесты парсера цен."""

    @pytest.fixture
    def parser(self):
        return SourceBotParser("test_token")

    def test_parse_simple_format_dash(self, parser):
        """Парсинг формата: Товар - 1000 руб."""
        message = "iPhone 15 - 50000 руб."
        result = parser.parse_prices_from_message(message)

        assert len(result) == 1
        assert result[0]["name"] == "iPhone 15"
        assert result[0]["price"] == 50000

    def test_parse_simple_format_colon(self, parser):
        """Парсинг формата: Товар: 1000₽"""
        message = "iPhone 15: 50000₽"
        result = parser.parse_prices_from_message(message)

        assert len(result) == 1
        assert result[0]["name"] == "iPhone 15"
        assert result[0]["price"] == 50000

    def test_parse_rubles_word(self, parser):
        """Парсинг с полным словом 'рублей'."""
        message = "Samsung S24 - 45000 рублей"
        result = parser.parse_prices_from_message(message)

        assert len(result) == 1
        assert result[0]["name"] == "Samsung S24"
        assert result[0]["price"] == 45000

    def test_parse_multiple_lines(self, parser):
        """Парсинг многострочного сообщения."""
        message = """
iPhone 15 - 50000 руб.
iPhone 15 Pro - 70000 руб.
Samsung S24 - 45000 рублей
"""
        result = parser.parse_prices_from_message(message)

        assert len(result) == 3
        assert result[0]["name"] == "iPhone 15"
        assert result[1]["name"] == "iPhone 15 Pro"
        assert result[2]["name"] == "Samsung S24"

    def test_parse_empty_lines_ignored(self, parser):
        """Пустые строки игнорируются."""
        message = """

iPhone 15 - 50000 руб.

"""
        result = parser.parse_prices_from_message(message)
        assert len(result) == 1

    def test_apply_markup_fixed_amount(self, parser):
        """Наценка фиксированной суммой."""
        prices = [
            {"name": "Item 1", "price": 1000},
            {"name": "Item 2", "price": 2000},
        ]

        result = parser.apply_markup(prices, markup=500)

        assert result[0]["price"] == 1500
        assert result[1]["price"] == 2500
        assert result[0]["original_price"] == 1000
        assert result[1]["original_price"] == 2000

    def test_apply_markup_percentage(self, parser):
        """Наценка процентом (< 100)."""
        prices = [
            {"name": "Item 1", "price": 1000},
        ]

        # 20% наценка
        result = parser.apply_markup(prices, markup=20)

        assert result[0]["price"] == 1200
        assert result[0]["original_price"] == 1000

    def test_apply_markup_zero(self, parser):
        """Без наценки."""
        prices = [
            {"name": "Item 1", "price": 1000},
        ]

        result = parser.apply_markup(prices, markup=0)

        assert result[0]["price"] == 1000

    def test_parse_no_price_text(self, parser):
        """Текст без цен возвращает пустой список."""
        message = "Привет, это тестовое сообщение без цен"
        result = parser.parse_prices_from_message(message)
        assert len(result) == 0

    def test_parse_empty_string(self, parser):
        """Пустая строка."""
        result = parser.parse_prices_from_message("")
        assert len(result) == 0
