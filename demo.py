"""
Демо-режим Price Updater.
Запускает приложение без реальных Telegram токенов для тестирования.

Использование:
    python demo.py
"""

import asyncio
import logging
from datetime import datetime

from logger_setup import setup_logging
from price_database import PriceDatabase
from report_generator import ReportGenerator
from telegram_parser import SourceBotParser

logger = logging.getLogger(__name__)


class DemoMode:
    """Демонстрационный режим без подключения к Telegram."""

    def __init__(self):
        self.parser = SourceBotParser("demo_token")
        self.db = PriceDatabase()
        self.report_gen = ReportGenerator(self.db)

    def generate_demo_prices(self, day_offset: int = 0) -> list:
        """Генерирует демо-данные цен."""
        import random

        base_prices = [
            {"name": "iPhone 15 128GB", "base": 50000},
            {"name": "iPhone 15 Pro 256GB", "base": 70000},
            {"name": "iPhone 15 Pro Max 512GB", "base": 90000},
            {"name": "Samsung Galaxy S24", "base": 45000},
            {"name": "Samsung Galaxy S24 Ultra", "base": 65000},
            {"name": "Xiaomi 14", "base": 35000},
            {"name": "Xiaomi 14 Pro", "base": 42000},
            {"name": "Google Pixel 8", "base": 40000},
            {"name": "Google Pixel 8 Pro", "base": 55000},
            {"name": "OnePlus 12", "base": 38000},
        ]

        # Меняем цены немного каждый день
        prices = []
        for item in base_prices:
            variation = random.randint(-2000, 2000) + (day_offset * 100)
            price = item["base"] + variation

            prices.append({
                "name": item["name"],
                "original_price": item["base"],
                "price": price,
            })

        # В некоторые дни добавляем/убираем товары
        if day_offset % 7 == 0:
            prices.append({
                "name": "AirPods Pro 2",
                "original_price": 15000,
                "price": 15000 + random.randint(-500, 500),
            })

        return prices

    async def run_demo(self, days: int = 30, interval_seconds: int = 2):
        """
        Запускает демо: генерирует данные за N дней с интервалом.

        Args:
            days: Количество дней симуляции
            interval_seconds: Пауза между обновлениями
        """
        logger.info("=" * 60)
        logger.info("🎭 ДЕМО-РЕЖИМ Price Updater")
        logger.info("=" * 60)
        logger.info(f"Симуляция {days} дней, интервал {interval_seconds}с")

        for day in range(days):
            logger.info(f"\n📅 День {day + 1}/{days}")

            # Генерируем цены
            prices = self.generate_demo_prices(day)
            logger.info(f"  Сгенерировано {len(prices)} позиций")

            # Сохраняем
            snapshot_id = self.db.save_snapshot(prices, markup=100)
            logger.info(f"  Снимок #{snapshot_id} сохранён")

            # Логируем изменения
            if day > 0:
                latest = self.db.get_latest_snapshot()
                if latest:
                    _, items = latest
                    logger.info(
                        f"  Последняя цена iPhone 15: {items[0]['final_price']}₽"
                    )

            # Пауза
            await asyncio.sleep(interval_seconds)

        # Формируем отчёт
        logger.info("\n📊 Генерация отчёта за период...")
        report = self.report_gen.generate_period_report(
            start_date=datetime.now().strftime("%Y-%m-%d"),
            end_date=datetime.now().strftime("%Y-%m-%d")
        )

        if report:
            report_text = self.report_gen.format_report_text(report)
            logger.info(f"\n{report_text}")

        # Статистика
        stats = self.db.get_storage_stats()
        logger.info("\n📁 Статистика базы:")
        logger.info(f"  Снимков: {stats['snapshots_count']}")
        logger.info(f"  Позиций: {stats['items_count']}")
        logger.info(f"  Размер БД: {stats['db_size_mb']} МБ")

        logger.info("\n✅ Демо завершено!")
        logger.info("Теперь можно запустить полноценный сервер: python main.py")


async def main():
    """Точка входа демо-режима."""
    setup_logging()

    demo = DemoMode()
    await demo.run_demo(days=30, interval_seconds=1)


if __name__ == "__main__":
    asyncio.run(main())
