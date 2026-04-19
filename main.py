"""
Основной файл для запуска Price Updater.
Запускает планировщик задач для обновления прайса в Telegram канале.
"""

import asyncio
import json
import logging
from typing import Optional

import uvicorn
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger

from logger_setup import setup_logging
from price_database import PriceDatabase
from report_generator import ReportGenerator
from telegram_channel import ChannelPublisher
from telegram_parser import SourceBotParser
from web_server import app, set_global_objects

# ============================================================
# User API модуль (ЗАКОММЕНТИРОВАН — раскомментируйте для использования)
# ============================================================
# from user_bot_client import UserBotClient, create_user_client_from_config

# Настройка логирования
setup_logging()
logger = logging.getLogger(__name__)


class PriceUpdater:
    """Основной класс для управления обновлением прайса."""

    def __init__(self, config_path: str = "config.json"):
        self.config = self._load_config(config_path)
        self.parser = SourceBotParser(self.config["source_bot_token"])
        self.publisher = ChannelPublisher(
            self.config["your_bot_token"],
            self.config["channel_id"]
        )
        self.db = PriceDatabase()      # SQLite база для хранения истории
        self.report_gen = ReportGenerator(self.db)
        self.message_id = self.config.get("price_message_id")

    def _load_config(self, config_path: str) -> dict:
        """Загружает конфигурацию из файла."""
        with open(config_path, "r", encoding="utf-8") as f:
            return json.load(f)

    def _save_message_id(self, message_id: int):
        """Сохраняет ID сообщения в конфиг."""
        self.config["price_message_id"] = message_id
        with open("config.json", "w", encoding="utf-8") as f:
            json.dump(self.config, f, ensure_ascii=False, indent=4)
        self.message_id = message_id

    async def update_price(self):
        """
        Основная задача: парсит цены, применяет наценку, обновляет канал.
        """
        logger.info("Запуск обновления прайса...")

        try:
            # ============================================================
            # ВАРИАНТ 1: User API (Telethon) — РАСКОММЕНТИРУЙТЕ ДЛЯ ИСПОЛЬЗОВАНИЯ
            # ============================================================
            # user_api_config = self.config.get("user_api", {})
            # if user_api_config.get("enabled", False):
            #     logger.info("Используем User API (Telethon) для парсинга...")
            #
            #     user_client = create_user_client_from_config(self.config)
            #     connected = await user_client.connect()
            #
            #     if not connected:
            #         logger.error("Не удалось подключиться к User API")
            #         return
            #
            #     try:
            #         # Получаем тексты сообщений с ценами
            #         price_texts = await user_client.get_full_price(
            #             button_chain=user_api_config["navigation_chain"],
            #             message_count=user_api_config.get("message_count", 5),
            #             start_keyword=user_api_config.get("start_keyword"),
            #             end_keyword=user_api_config.get("end_keyword")
            #         )
            #
            #         if not price_texts:
            #             logger.warning("Не получено сообщений с ценами")
            #             return
            #
            #         # Парсим все сообщения
            #         prices = []
            #         for text in price_texts:
            #             parsed = self.parser.parse_prices_from_message(text)
            #             prices.extend(parsed)
            #
            #         logger.info(f"Найдено позиций: {len(prices)}")
            #
            #     finally:
            #         await user_client.disconnect()
            #
            #     if not prices:
            #         logger.warning("Не найдено цен для обновления")
            #         return
            #
            #     # Применяем наценку
            #     markup = self.config.get("price_markup", 0)
            #     prices = self.parser.apply_markup(prices, markup)
            #     logger.info(f"Наценка применена: {markup}")

            # ============================================================
            # ВАРИАНТ 2: Демо-данные (заглушка для тестирования)
            # ============================================================

            # Демо-данные (замените на реальный парсинг)
            demo_message_text = """
            iPhone 15 - 50000 руб.
            iPhone 15 Pro - 70000 руб.
            Samsung S24 - 45000 рублей
            Xiaomi 14 - 35000₽
            """

            # Парсим цены
            prices = self.parser.parse_prices_from_message(demo_message_text)
            logger.info(f"Найдено позиций: {len(prices)}")

            if not prices:
                logger.warning("Не найдено цен для обновления")
                return

            # Применяем наценку
            markup = self.config.get("price_markup", 0)
            prices = self.parser.apply_markup(prices, markup)
            logger.info(f"Наценка применена: {markup}")

            # Сохраняем в оба хранилища (JSON для совместимости, SQLite для истории)
            self.storage.save_prices(prices)
            snapshot_id = self.db.save_snapshot(prices, markup)
            logger.info(f"Снимок #{snapshot_id} сохранён в SQLite")

            # Публикуем в канал
            if self.message_id:
                # Редактируем существующее сообщение
                success = await self.publisher.update_price_list(self.message_id, prices)
                if success:
                    logger.info("Сообщение обновлено")
            else:
                # Отправляем новое сообщение и сохраняем ID
                self.message_id = await self.publisher.send_price_list(prices)
                self._save_message_id(self.message_id)
                logger.info(f"Создано новое сообщение, ID: {self.message_id}")

            logger.info("Обновление прайса завершено")

        except Exception as e:
            logger.error(f"Ошибка при обновлении прайса: {e}", exc_info=True)

    async def generate_report(self, year: int = None, month: int = None) -> Optional[str]:
        """
        Генерирует отчёт за месяц.

        Args:
            year: Год (по умолчанию — предыдущий месяц)
            month: Месяц

        Returns:
            Текст отчёта для публикации в канале или None
        """
        try:
            report = self.report_gen.generate_monthly_report(year, month)

            if not report:
                logger.warning("Не удалось сформировать отчёт — нет данных")
                return None

            # Форматируем текст
            report_text = self.report_gen.format_report_text(report)

            # Сохраняем в файл
            filepath = self.report_gen.save_report_to_file(report)
            logger.info(f"Отчёт сохранён в файл: {filepath}")

            return report_text

        except Exception as e:
            logger.error(f"Ошибка при генерации отчёта: {e}", exc_info=True)
            return None

    async def start(self):
        """Запускает планировщик задач и веб-сервер."""
        schedule = self.config.get("schedule", {})

        scheduler = AsyncIOScheduler()

        # Настраиваем расписание: каждый час с 11:30 до 19:30
        start_hour = schedule.get("start_hour", 11)
        start_minute = schedule.get("start_minute", 30)
        end_hour = schedule.get("end_hour", 19)
        end_minute = schedule.get("end_minute", 30)

        # Добавляем job на каждый час в указанном диапазоне
        for hour in range(start_hour, end_hour + 1):
            # Пропускаем если час выходит за диапазон
            if hour == start_hour:
                minute = start_minute
            elif hour == end_hour:
                # Если время окончания 19:30, последний запуск в 19:30
                if end_minute == 30:
                    minute = 30
                else:
                    continue
            else:
                minute = 0

            scheduler.add_job(
                self.update_price,
                CronTrigger(hour=hour, minute=minute),
                id=f"update_{hour:02d}:{minute:02d}"
            )

        scheduler.start()

        logger.info("=" * 50)
        logger.info("Price Updater запущен!")
        logger.info(f"Расписание: с {start_hour}:{start_minute:02d} до {end_hour}:{end_minute:02d}")
        logger.info(f"Следующие job'ы: {[str(j.trigger) for j in scheduler.get_jobs()]}")
        logger.info("Веб-интерфейс: http://localhost:8000")
        logger.info("=" * 50)

        # Передаём объекты в веб-сервер
        set_global_objects(self, scheduler)

        try:
            # Запускаем веб-сервер параллельно с планировщиком
            config = uvicorn.Config(
                app,
                host="0.0.0.0",
                port=8000,
                log_level="info"
            )
            server = uvicorn.Server(config)
            await server.serve()

        except (KeyboardInterrupt, SystemExit):
            logger.info("Остановка Price Updater...")
            scheduler.shutdown()


async def main():
    """Точка входа."""
    updater = PriceUpdater()
    await updater.start()


def main_entry():
    """Entry point для команды price-updater (pyproject.toml)."""
    asyncio.run(main())


if __name__ == "__main__":
    asyncio.run(main())
