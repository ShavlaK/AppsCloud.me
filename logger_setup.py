"""
Модуль настройки логирования для Price Updater.
Логирует в консоль + файл + отдельный файл для ошибок.
"""

import logging
import os
from logging.handlers import RotatingFileHandler


def setup_logging(log_dir: str = "logs", max_bytes: int = 5_000_000, backup_count: int = 3):
    """
    Настраивает систему логирования.

    Args:
        log_dir: Директория для логов
        max_bytes: Максимальный размер файла лога (ротация)
        backup_count: Количество резервных файлов
    """
    # Создаём директорию логов
    os.makedirs(log_dir, exist_ok=True)

    # Формат логов
    log_format = logging.Formatter(
        "%(asctime)s | %(levelname)-8s | %(name)s | %(funcName)s:%(lineno)d | %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S"
    )

    # --- Root logger ---
    root_logger = logging.getLogger()
    root_logger.setLevel(logging.DEBUG)

    # --- Консоль (INFO и выше) ---
    console_handler = logging.StreamHandler()
    console_handler.setLevel(logging.INFO)
    console_handler.setFormatter(log_format)
    root_logger.addHandler(console_handler)

    # --- Файл всех логов (DEBUG и выше) ---
    all_log_file = os.path.join(log_dir, "price_updater.log")
    all_handler = RotatingFileHandler(
        all_log_file,
        maxBytes=max_bytes,
        backupCount=backup_count,
        encoding="utf-8"
    )
    all_handler.setLevel(logging.DEBUG)
    all_handler.setFormatter(log_format)
    root_logger.addHandler(all_handler)

    # --- Файл ошибок (ERROR и CRITICAL) ---
    error_log_file = os.path.join(log_dir, "errors.log")
    error_handler = RotatingFileHandler(
        error_log_file,
        maxBytes=max_bytes,
        backupCount=backup_count,
        encoding="utf-8"
    )
    error_handler.setLevel(logging.ERROR)
    error_handler.setFormatter(log_format)
    root_logger.addHandler(error_handler)

    # --- Файл планировщика (INFO и выше) ---
    scheduler_log_file = os.path.join(log_dir, "scheduler.log")
    scheduler_handler = RotatingFileHandler(
        scheduler_log_file,
        maxBytes=max_bytes,
        backupCount=backup_count,
        encoding="utf-8"
    )
    scheduler_handler.setLevel(logging.INFO)
    scheduler_handler.setFormatter(log_format)

    # Логгер для планировщика
    scheduler_logger = logging.getLogger("apscheduler")
    scheduler_logger.addHandler(scheduler_handler)
    scheduler_logger.setLevel(logging.INFO)

    # --- Логгер для Telegram API ---
    telegram_log_file = os.path.join(log_dir, "telegram.log")
    telegram_handler = RotatingFileHandler(
        telegram_log_file,
        maxBytes=max_bytes,
        backupCount=backup_count,
        encoding="utf-8"
    )
    telegram_handler.setLevel(logging.WARNING)
    telegram_handler.setFormatter(log_format)

    # Приглушаем лишние логи от aiohttp и telethon
    logging.getLogger("aiohttp").setLevel(logging.WARNING)
    logging.getLogger("telethon").setLevel(logging.WARNING)
    logging.getLogger("aiogram").setLevel(logging.WARNING)
