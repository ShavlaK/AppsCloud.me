"""
Модуль для навигации по боту-источнику через User API (Telethon).
Позволяет эмулировать действия обычного пользователя: кликать по кнопкам,
читать сообщения, собирать прайс.

ВНИМАНИЕ: Модуль готов к использованию, но пока ЗАКОММЕНТИРОВАН в main.py.
Для активации — раскомментируйте соответствующий блок в PriceUpdater.update_price().
"""

import asyncio
import logging
import random
from typing import Dict, List, Optional

from telethon import TelegramClient
from telethon.errors import SessionPasswordNeededError
from telethon.tl.types import KeyboardButtonCallback, Message

logger = logging.getLogger(__name__)


class UserBotClient:
    """
    Клиент для работы с Telegram как обычный пользователь.
    Используется для навигации по боту-источнику через inline-кнопки.
    """

    def __init__(
        self,
        api_id: int,
        api_hash: str,
        phone: str,
        bot_username: str,
        session_name: str = "user_session"
    ):
        """
        Args:
            api_id: Telegram API ID (получить на my.telegram.org)
            api_hash: Telegram API Hash
            phone: Номер телефона аккаунта
            bot_username: Username бота-источника (без @)
            session_name: Имя файла сессии
        """
        self.api_id = api_id
        self.api_hash = api_hash
        self.phone = phone
        self.bot_username = bot_username
        self.session_name = session_name

        self.client: Optional[TelegramClient] = None
        self.bot_entity = None

    async def connect(self) -> bool:
        """
        Подключается к Telegram. При первом запуске запросит номер телефона
        и код подтверждения. Сохраняет сессию в .session файл.
        """
        self.client = TelegramClient(
            self.session_name,
            self.api_id,
            self.api_hash,
            device_model="Desktop",
            system_version="Windows",
            app_version="1.0",
            lang_code="en",
            system_lang_code="en-US"
        )

        try:
            await self.client.connect()

            if not await self.client.is_user_authorized():
                logger.info("Авторизация не найдена. Выполняем вход...")
                await self.client.start(phone=self.phone)
                logger.info("Авторизация успешна!")

            # Находим бота-источника
            self.bot_entity = await self.client.get_entity(self.bot_username)
            logger.info(f"Бот-источник найден: {self.bot_username}")

            return True

        except SessionPasswordNeededError:
            logger.error(
                "Требуется двухфакторная аутентификация. "
                "Введите пароль вручную или отключите 2FA."
            )
            return False
        except Exception as e:
            logger.error(f"Ошибка подключения: {e}")
            return False

    async def disconnect(self):
        """Отключается от Telegram."""
        if self.client:
            await self.client.disconnect()

    async def start_bot(self) -> Optional[Message]:
        """Отправляет /start боту-источнику."""
        if not self.client or not self.bot_entity:
            logger.error("Клиент не подключён")
            return None

        await self.client.send_message(
            self.bot_entity,
            "/start"
        )

        # Небольшая задержка для ответа бота
        await asyncio.sleep(1 + random.uniform(0, 1))

        # Получаем последнее сообщение от бота
        messages = await self.client.get_messages(
            self.bot_entity,
            limit=1
        )

        if messages:
            logger.info(f"Получен ответ от бота: {messages[0].text[:50]}...")
            return messages[0]

        return None

    async def click_button_by_text(
        self,
        message: Message,
        button_text: str,
        wait_seconds: float = 2.0
    ) -> Optional[Message]:
        """
        Находит кнопку по тексту и кликает по ней.

        Args:
            message: Сообщение с inline-кнопками
            button_text: Текст кнопки (например, "Apple")
            wait_seconds: Задержка после клика (с рандомизацией)

        Returns:
            Сообщение-ответ бота после клика
        """
        if not message.reply_markup or not hasattr(message.reply_markup, 'rows'):
            logger.warning("В сообщении нет кнопок")
            return None

        # Ищем кнопку по тексту
        target_button = None
        for row in message.reply_markup.rows:
            for button in row.buttons:
                if isinstance(button, KeyboardButtonCallback):
                    if button.text == button_text:
                        target_button = button
                        break
            if target_button:
                break

        if not target_button:
            # Логируем доступные кнопки для отладки
            available = []
            for row in message.reply_markup.rows:
                for button in row.buttons:
                    if isinstance(button, KeyboardButtonCallback):
                        available.append(button.text)
            logger.error(
                f"Кнопка '{button_text}' не найдена. "
                f"Доступные: {available}"
            )
            return None

        logger.info(f"Кликаем по кнопке: {button_text}")

        # Добавляем рандомизацию задержки (анти-спам)
        actual_wait = wait_seconds + random.uniform(-0.5, 0.5)
        await asyncio.sleep(max(0.5, actual_wait))

        # Кликаем по кнопке
        try:
            await message.click(data=target_button.data)

            # Ждём ответ бота
            await asyncio.sleep(actual_wait)

            # Получаем новое сообщение
            messages = await self.client.get_messages(
                self.bot_entity,
                limit=1
            )

            if messages:
                msg_text = messages[0].text or "[нет текста]"
                logger.info(f"Ответ после клика: {msg_text[:50]}...")
                return messages[0]

        except Exception as e:
            logger.error(f"Ошибка при клике: {e}")

        return None

    async def navigate_chain(
        self,
        button_chain: List[Dict[str, any]]
    ) -> Optional[Message]:
        """
        Проходит по цепочке кнопок.

        Args:
            button_chain: Список кнопок для нажатия
                [{"text": "Apple", "wait": 2}, {"text": "Смартфоны", "wait": 3}]

        Returns:
            Финальное сообщение после всех кликов
        """
        # Начинаем с /start
        message = await self.start_bot()
        if not message:
            return None

        # Проходим по цепочке
        for step in button_chain:
            button_text = step["text"]
            wait = step.get("wait", 2.0)

            message = await self.click_button_by_text(message, button_text, wait)
            if not message:
                logger.error(f"Не удалось нажать кнопку '{button_text}'")
                return None

        return message

    async def collect_price_messages(
        self,
        message_count: int = 5,
        start_keyword: str = None,
        end_keyword: str = None
    ) -> List[str]:
        """
        Собирает сообщения с ценами.

        Args:
            message_count: Максимальное количество сообщений для сбора
            start_keyword: Текст, обозначающий начало прайса
            end_keyword: Текст, обозначающий конец прайса

        Returns:
            Список текстов сообщений с ценами
        """
        if not self.client or not self.bot_entity:
            logger.error("Клиент не подключён")
            return []

        texts = []
        collecting = not start_keyword  # Если нет маркера начала, собираем всё

        async for message in self.client.iter_messages(
            self.bot_entity,
            limit=message_count
        ):
            if message.text:
                text = message.text.strip()

                # Проверяем маркер начала
                if start_keyword and not collecting:
                    if start_keyword.lower() in text.lower():
                        collecting = True
                        logger.info("Найден маркер начала прайса")
                        texts.append(text)
                        continue

                # Собираем текст
                if collecting:
                    # Проверяем маркер конца
                    if end_keyword and end_keyword.lower() in text.lower():
                        logger.info("Найден маркер конца прайса")
                        texts.append(text)
                        break

                    texts.append(text)
                    logger.info(f"Собрано сообщение: {text[:30]}...")

        # Возвращаем в правильном порядке (от старых к новым)
        return list(reversed(texts))

    async def get_full_price(
        self,
        button_chain: List[Dict[str, any]],
        message_count: int = 10,
        start_keyword: str = None,
        end_keyword: str = None
    ) -> List[str]:
        """
        Полный цикл: навигация по кнопкам + сбор прайса.

        Args:
            button_chain: Цепочка кнопок для навигации
            message_count: Сколько сообщений собирать
            start_keyword: Маркер начала прайса
            end_keyword: Маркер конца прайса

        Returns:
            Список текстов с ценами
        """
        # Навигация
        final_message = await self.navigate_chain(button_chain)
        if not final_message:
            logger.error("Не удалось пройти навигацию")
            return []

        # Задержка для полной загрузки
        await asyncio.sleep(2)

        # Сбор сообщений
        return await self.collect_price_messages(
            message_count=message_count,
            start_keyword=start_keyword,
            end_keyword=end_keyword
        )


# ============================================================
# ФАБРИЧНЫЙ МЕТОД (для удобства создания из config.json)
# ============================================================

def create_user_client_from_config(config: dict) -> UserBotClient:
    """
    Создаёт UserBotClient из конфигурации.

    Expected config keys:
    - user_api_id
    - user_api_hash
    - user_phone
    - source_bot_username
    - user_session_name
    """
    return UserBotClient(
        api_id=config["user_api_id"],
        api_hash=config["user_api_hash"],
        phone=config["user_phone"],
        bot_username=config["source_bot_username"],
        session_name=config.get("user_session_name", "user_session")
    )
