"""
Модуль для публикации и обновления прайса в Telegram канале.
"""

from datetime import datetime
from typing import Dict, List

import aiohttp


class ChannelPublisher:
    """Публикатор для обновления прайса в Telegram канале."""

    def __init__(self, bot_token: str, channel_id: str):
        self.bot_token = bot_token
        self.channel_id = channel_id
        self.api_url = f"https://api.telegram.org/bot{bot_token}"

    async def send_price_list(self, prices: List[Dict[str, any]]) -> int:
        """
        Отправляет новый прайс-лист в канал.

        Returns:
            message_id - ID отправленного сообщения
        """
        message_text = self._format_price_list(prices)

        async with aiohttp.ClientSession() as session:
            url = f"{self.api_url}/sendMessage"
            data = {
                "chat_id": self.channel_id,
                "text": message_text,
                "parse_mode": "HTML"
            }
            async with session.post(url, json=data) as response:
                result = await response.json()
                if result.get("ok"):
                    return result["result"]["message_id"]
                else:
                    raise Exception(f"Ошибка отправки: {result.get('description')}")

    async def update_price_list(self, message_id: int, prices: List[Dict[str, any]]) -> bool:
        """
        Редактирует существующее сообщение с прайсом.

        Args:
            message_id: ID сообщения для редактирования
            prices: Список товаров с ценами

        Returns:
            True если успешно
        """
        message_text = self._format_price_list(prices)

        async with aiohttp.ClientSession() as session:
            url = f"{self.api_url}/editMessageText"
            data = {
                "chat_id": self.channel_id,
                "message_id": message_id,
                "text": message_text,
                "parse_mode": "HTML"
            }
            async with session.post(url, json=data) as response:
                result = await response.json()
                if result.get("ok"):
                    return True
                else:
                    raise Exception(f"Ошибка редактирования: {result.get('description')}")

    def _format_price_list(self, prices: List[Dict[str, any]]) -> str:
        """Форматирует прайс-лист в красивое сообщение."""
        now = datetime.now().strftime("%d.%m.%Y %H:%M")

        lines = [
            "<b>📋 Прайс-лист</b>",
            f"<i>Обновлён: {now}</i>",
            "",
            "─────────────────"
        ]

        for i, item in enumerate(prices, 1):
            name = item.get("name", "Без названия")
            price = item.get("price", 0)

            # Форматируем цену с разделителями
            formatted_price = f"{price:,}".replace(",", " ")

            lines.append(f"{i}. <b>{name}</b> — {formatted_price} ₽")

        lines.extend([
            "─────────────────",
            "",
            "💰 <i>Цены указаны с учётом наценки</i>"
        ])

        return "\n".join(lines)
