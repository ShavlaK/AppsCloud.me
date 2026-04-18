"""
Модуль для парсинга цен из Telegram бота-источника.
"""

import re
from typing import Dict, List

import aiohttp


class SourceBotParser:
    """Парсер для получения цен из бота-источника."""

    def __init__(self, bot_token: str):
        self.bot_token = bot_token
        self.api_url = f"https://api.telegram.org/bot{bot_token}"

    async def get_updates(self, offset: int = 0, limit: int = 100) -> List[Dict]:
        """Получает последние обновления от бота."""
        async with aiohttp.ClientSession() as session:
            url = f"{self.api_url}/getUpdates"
            params = {
                "offset": offset,
                "limit": limit,
                "timeout": 30
            }
            async with session.get(url, params=params) as response:
                data = await response.json()
                if data.get("ok"):
                    return data.get("result", [])
                return []

    async def get_chat_history(self, chat_id: str, limit: int = 50) -> List[Dict]:
        """
        Получает историю сообщений из чата с ботом.
        Примечание: Bot API не позволяет напрямую читать историю.
        Для полноценного парсинга нужен User API (Telethon/Pyrogram).
        """
        # Этот метод требует использования User API
        # Пока оставляю заглушку для будущей реализации
        raise NotImplementedError(
            "Для парсинга истории необходим User API (Telethon/Pyrogram). "
            "Используйте метод parse_prices_from_message с текстом сообщения."
        )

    def parse_prices_from_message(self, message_text: str) -> List[Dict[str, any]]:
        """
        Парсит цены из текстового сообщения.

        Пример формата:
        "Товар 1 - 1000 руб.
         Товар 2 - 2000 руб."

        Возвращает:
        [{"name": "Товар 1", "price": 1000}, ...]
        """
        prices = []

        # Регулярка для поиска паттернов: название - цена
        # Поддерживаемые форматы:
        # - Товар - 1000 руб.
        # - Товар: 1000₽
        # - Товар 1000 рублей

        patterns = [
            r"^(.+?)\s*[-–—:]\s*(\d+)\s*(?:руб\.?|рублей|₽|RUB)?\s*$",
            r"^(.+?)\s+(\d+)\s*(?:руб\.?|рублей|₽|RUB)?\s*$",
        ]

        for line in message_text.split("\n"):
            line = line.strip()
            if not line:
                continue

            for pattern in patterns:
                match = re.match(pattern, line, re.IGNORECASE)
                if match:
                    name = match.group(1).strip()
                    price = int(match.group(2))
                    prices.append({
                        "name": name,
                        "price": price
                    })
                    break

        return prices

    def apply_markup(self, prices: List[Dict[str, any]], markup: float) -> List[Dict[str, any]]:
        """
        Применяет наценку к ценам.

        Args:
            prices: Список товаров с ценами
            markup: Сумма наценки (если < 100 - считается процентом)

        Returns:
            Обновлённый список с новыми ценами
        """
        updated = []
        for item in prices:
            original_price = item["price"]

            # Если наценка < 100, считаем что это процент
            if markup < 100:
                new_price = int(original_price * (1 + markup / 100))
            else:
                new_price = original_price + markup

            updated.append({
                "name": item["name"],
                "original_price": original_price,
                "price": new_price
            })

        return updated
