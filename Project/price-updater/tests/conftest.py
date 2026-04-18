"""
Pytest конфигурация и фикстуры для тестирования.
"""

import json
import os
import tempfile
from unittest.mock import AsyncMock, patch

import pytest

# ============================================================
# Фикстуры
# ============================================================

@pytest.fixture
def temp_dir():
    """Временная директория для тестов."""
    with tempfile.TemporaryDirectory() as tmpdir:
        original_cwd = os.getcwd()
        os.chdir(tmpdir)
        yield tmpdir
        os.chdir(original_cwd)


@pytest.fixture
def mock_config(temp_dir):
    """Mock config.json для тестов."""
    config = {
        "source_bot_token": "123456:TEST-SOURCE-BOT-TOKEN",
        "your_bot_token": "789012:TEST-YOUR-BOT-TOKEN",
        "channel_id": "@test_channel",
        "price_markup": 100,
        "schedule": {
            "start_hour": 11,
            "start_minute": 30,
            "end_hour": 19,
            "end_minute": 30,
            "interval_hours": 1
        },
        "price_message_id": None,
        "user_api": {
            "enabled": False,
            "user_api_id": 123456,
            "user_api_hash": "test_hash",
            "user_phone": "+79001234567",
            "source_bot_username": "test_bot",
            "user_session_name": "test_session",
            "navigation_chain": [
                {"text": "Apple", "wait": 1},
                {"text": "Смартфоны", "wait": 1}
            ],
            "message_count": 3,
            "start_keyword": "Прайс",
            "end_keyword": "Итого"
        }
    }

    with open("config.json", "w") as f:
        json.dump(config, f)

    return config


@pytest.fixture
def sample_price_message():
    """Пример сообщения с ценами."""
    return """
📋 Прайс-лист Apple

iPhone 15 128GB - 50000 руб.
iPhone 15 Pro 256GB - 70000 руб.
iPhone 15 Pro Max 512GB - 90000 рублей
"""


@pytest.fixture
def sample_price_items():
    """Пример распарсенных позиций."""
    return [
        {"name": "iPhone 15 128GB", "price": 50000, "original_price": 50000},
        {"name": "iPhone 15 Pro 256GB", "price": 70000, "original_price": 70000},
        {"name": "iPhone 15 Pro Max 512GB", "price": 90000, "original_price": 90000},
    ]


@pytest.fixture
def mock_aiohttp_response():
    """Mock для aiohttp ответа."""
    async def _mock(ok=True, result=None, description=None):
        response = AsyncMock()
        response.json.return_value = {
            "ok": ok,
            "result": result or {"message_id": 12345},
            "description": description
        }
        return response
    return _mock


@pytest.fixture
def mock_telegram_api():
    """Mock для Telegram API вызовов."""
    with patch("aiohttp.ClientSession") as mock_session:
        mock_response = AsyncMock()
        mock_response.json.return_value = {
            "ok": True,
            "result": {"message_id": 12345}
        }
        mock_response.__aenter__ = AsyncMock(return_value=mock_response)
        mock_response.__aexit__ = AsyncMock(return_value=None)

        mock_session.return_value.get.return_value = mock_response
        mock_session.return_value.post.return_value = mock_response

        yield mock_session
