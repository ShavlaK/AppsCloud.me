# PROJECT CONTEXT — Price Updater

> Этот файл содержит полный контекст разработки проекта Price Updater.
> Передайте его другому AI-ассистенту для мгновенного понимания проекта.

---

## 📋 О проекте

**Price Updater** — утилита для автоматического обновления прайс-листов в Telegram каналах.
Работает на Windows/macOS/Linux, поддерживает хостинг на домашнем сервере (Proxmox).

### Основная логика
1. Каждый час с 11:30 до 19:30 парсит цены из Telegram бота-источника
2. Добавляет наценку (фиксированную или %)
3. Редактирует одно сообщение в Telegram канале с актуальным прайсом
4. Сохраняет снимок цен в SQLite (хранится 30 дней)
5. В конце месяца формирует отчёт об изменениях цен

---

## 🏗 Архитектура проекта

```
price-updater/
├── main.py              # Точка входа: запускает APScheduler + FastAPI (uvicorn)
├── web_server.py        # FastAPI сервер + REST API
├── telegram_parser.py   # Парсер цен из текстовых сообщений
├── telegram_channel.py  # Публикация/редактирование сообщений в канале
├── price_database.py    # SQLite хранилище истории цен (30 дней)
├── price_storage.py     # JSON хранилище (legacy, для совместимости)
├── report_generator.py  # Генератор ежемесячных отчётов
├── logger_setup.py      # Система логирования (4 файла логов)
├── user_bot_client.py   # User API через Telethon — ЗАКОММЕНТИРОВАН, готов к использованию
├── demo.py              # Демо-режим для тестирования без токенов
│
├── templates/index.html # Веб-панель управления (Dashboard)
│
├── tests/               # pytest тесты
│   ├── conftest.py
│   ├── test_parser.py
│   ├── test_database.py
│   ├── test_reports.py
│   └── test_web.py
│
├── build_scripts/       # Скрипты сборки
│   ├── build_windows.spec   # PyInstaller → .exe
│   ├── build_macos.py       # py2app → .dmg
│   └── build_debian.sh      # dpkg-deb → .deb
│
├── .github/workflows/
│   └── build-release.yml    # GitHub Actions CI/CD
│
├── pyproject.toml       # pip install, зависимости
├── config.json          # Конфигурация (в .gitignore!)
└── requirements.txt
```

---

## 💡 Ключевые решения и причины

### Почему SQLite вместо JSON?
- Нужна история цен за 30 дней для ежемесячных отчётов
- JSON не подходит для сравнения снимков за период
- `prices.json` оставлен для обратной совместимости

### Почему User API (Telethon) закомментирован?
- Bot API не позволяет читать историю чата — только `getUpdates`
- Бот-источник НЕ принадлежит пользователю, нужен User API для чтения сообщений
- Модуль полностью готов, но требует `api_id`/`api_hash` с my.telegram.org
- Активируется раскомментированием импорта и блока в `main.py`

### Почему редактирование сообщения, а не новое?
- Чтобы не спамить в канале
- Одно закреплённое сообщение с актуальным прайсом

### Почему FastAPI + APScheduler в одном процессе?
- Uvicorn работает в asyncio loop — тот же loop что и APScheduler
- `set_global_objects()` передаёт PriceUpdater и scheduler в веб-сервер
- Веб-интерфейс может управлять планировщиком

---

## ⚙️ Конфигурация (config.json)

```json
{
    "source_bot_token": "токен бота-источника",
    "your_bot_token": "токен вашего бота для канала",
    "channel_id": "@your_channel",
    "price_markup": 100,
    "schedule": {
        "start_hour": 11,
        "start_minute": 30,
        "end_hour": 19,
        "end_minute": 30
    },
    "price_message_id": null,
    "user_api": {
        "enabled": false,
        "user_api_id": 123456,
        "user_api_hash": "...",
        "user_phone": "+79001234567",
        "source_bot_username": "source_bot",
        "navigation_chain": [
            {"text": "Apple", "wait": 2},
            {"text": "Смартфоны", "wait": 3},
            {"text": "Показать прайс", "wait": 5}
        ],
        "message_count": 5,
        "start_keyword": "Прайс-лист",
        "end_keyword": "Итого"
    }
}
```

---

## 🔌 REST API (FastAPI)

| Метод | Endpoint | Описание |
|-------|----------|----------|
| GET | `/` | Веб-панель управления |
| GET | `/api/status` | Статус системы + статистика БД |
| GET | `/api/config` | Конфигурация (токены замаскированы) |
| POST | `/api/config` | Обновить конфигурацию |
| POST | `/api/update` | Ручное обновление прайса |
| POST | `/api/scheduler/start` | Запуск планировщика |
| POST | `/api/scheduler/stop` | Остановка планировщика |
| POST | `/api/report` | Генерация отчёта |
| GET | `/api/reports` | Список отчётов |
| GET | `/api/reports/{filename}` | Конкретный отчёт |
| GET | `/api/logs` | Просмотр логов |
| GET | `/api/logs/errors` | Быстрый доступ к ошибкам |

---

## 📊 Система логирования

| Файл | Уровень | Назначение |
|------|---------|------------|
| `logs/price_updater.log` | DEBUG+ | Все логи, ротация 5МБ |
| `logs/errors.log` | ERROR+ | Только ошибки для быстрого поиска |
| `logs/scheduler.log` | INFO+ | События планировщика |
| `logs/telegram.log` | WARNING+ | Предупреждения от Telegram API |

---

## 📈 Система отчётов

**Сравнивает первый и последний снимки за период:**

| Категория | Описание |
|-----------|----------|
| 📈 Выросли | Товар + старая→новая цена + % роста |
| 📉 Упали | Товар + старая→новая цена + % падения |
| ➡️ Без изменений | Стабильные позиции |
| 🆕 Новые | Появились в прайсе |
| ❌ Исчезли | Пропали из прайса |

**Методы:**
- `ReportGenerator.generate_monthly_report(year, month)` — за месяц
- `ReportGenerator.generate_period_report(start_date, end_date)` — произвольный период
- `ReportGenerator.format_report_text(report)` — HTML для Telegram
- `ReportGenerator.format_report_json(report)` — JSON для сохранения
- `ReportGenerator.save_report_to_file(report)` — сохранение в `reports/`

---

## 👤 User API (Telethon) — НЕ АКТИВИРОВАН

**Модуль:** `user_bot_client.py`

**Навигация по боту:**
1. `/start` → ожидание inline-кнопок
2. Клик по кнопке "Apple" → ожидание
3. Клик по кнопке "Смартфоны" → ожидание
4. Клик по кнопке "Показать прайс" → получение сообщений
5. Сбор N сообщений с ценами

**Анти-спам:** рандомизация задержек `±0.5s`

**Для активации:**
1. Получить `api_id` и `api_hash` на https://my.telegram.org
2. В `config.json` — `"enabled": true`
3. В `main.py` — раскомментировать импорт и блок User API

---

## 🚀 Установка и запуск

### pip install
```bash
pip install -e .
price-updater
```

### Из исходников
```bash
pip install -r requirements.txt
python main.py
```

### Демо-режим (без токенов)
```bash
python demo.py
```

### После запуска
Веб-интерфейс: **http://localhost:8000**

---

## 🏗 Сборка бинарников

```bash
# Windows .exe
pyinstaller build_scripts/build_windows.spec

# macOS .dmg
python build_scripts/build_macos.py
hdiutil create -volname "Price Updater" -srcfolder build/app -ov -format UDZO price-updater-macos.dmg

# Linux .deb
bash build_scripts/build_debian.sh
```

---

## 🔄 CI/CD (GitHub Actions)

При push тега `v*`:
1. Запускаются тесты на Python 3.9–3.12
2. Собираются: .exe, .dmg, .deb, PyPI package
3. Создаётся GitHub Release с артефактами
4. Публикуется на PyPI

```bash
git tag v1.0.0
git push origin v1.0.0
```

---

## 🧪 Тесты

```bash
pip install -e ".[dev]"
pytest tests/ -v
```

**Покрытие:** парсер цен, SQLite БД, генератор отчётов, FastAPI endpoints

---

## 🎯 Будущие планы (НЕ реализовано)

1. **Интеграция с Авито** — автоматическое обновление цен
2. **Интеграция с ВК** — обновление прайсов
3. **Интеграция с Яндекс.Картами** — обновление цен
4. **Активация User API** — полноценный парсинг бота-источника с кнопками
5. **Авторизация в веб-интерфейсе** — защита паролем
6. **Уведомления об ошибках в Telegram** — отправка алертов
7. **Docker образ** — для Proxmox/серверного хостинга
8. **Графики изменения цен** — визуализация в веб-интерфейсе

---

## ⚠️ Важные нюансы

1. **Токены в config.json** — НЕ коммитьте в git (в .gitignore)
2. **Telethon сессия** — `.session` файл создаётся при первом запуске User API
3. **Первый запуск User API** — требует ввода номера телефона и кода подтверждения
4. **Парсинг цен** — регулярки в `telegram_parser.py` могут потребовать адаптации под формат бота-источника
5. **SQLite** — `prices.db` создаётся автоматически, хранит 30 дней
6. **Веб-сервер** — работает на `0.0.0.0:8000` (доступен по сети)

---

## 📝 Диалог разработки (история решений)

1. **Язык:** Python — кроссплатформенность, отличные библиотеки для Telegram
2. **Хранение цен:** изначально JSON → мигрировано на SQLite для истории
3. **Парсинг:** Bot API не читает историю → нужен User API (Telethon)
4. **Навигация по боту:** кнопки через `message.click(data=button.data)`
5. **Обновление в канале:** редактирование одного сообщения (не спам)
6. **Расписание:** APScheduler cron trigger, каждый час 11:30–19:30
7. **Логи:** RotatingFileHandler, 4 файла, ротация по 5МБ
8. **Отчёты:** сравнение первого и последнего снимков за период
9. **Веб-интерфейс:** FastAPI + Jinja2 template, vanilla JS (без фреймворков)
10. **Сборка:** PyInstaller (.exe), py2app (.dmg), dpkg-deb (.deb), PyPI
11. **CI/CD:** GitHub Actions, авто-сборка при теге `v*`
12. **Тесты:** pytest, моки для aiohttp, фикстуры для БД

---

> **Конец контекста.** Передайте этот файл другому AI для понимания проекта.
