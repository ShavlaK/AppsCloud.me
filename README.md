# Price Updater — Автоматическое обновление цен в Telegram

[![Python 3.9+](https://img.shields.io/badge/python-3.9+-blue.svg)](https://www.python.org/downloads/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-lightgrey)]()
[![Docker](https://img.shields.io/badge/docker-ready-blue.svg)](https://www.docker.com/)

Мощное решение для автоматического мониторинга и обновления прайс-листов в Telegram-каналах. Приложение парсит цены из источника, применяет наценку, сохраняет историю изменений в базу данных и публикует актуальные данные в ваш канал по расписанию. Включает веб-интерфейс для управления и генерации отчетов.

## 🚀 Возможности

*   **Автоматизация:** Парсинг цен из Telegram-бота/канала источника каждый час (настраиваемо).
*   **Умная наценка:** Гибкая система наценок (процент или фиксированная сумма).
*   **История цен:** Сохранение всей истории изменений в SQLite базу данных.
*   **Веб-интерфейс (Dashboard):**
    *   Мониторинг статуса системы в реальном времени.
    *   Управление конфигурацией через браузер.
    *   Просмотр логов работы парсера.
    *   Графики и аналитика: тренды цен, анализ по дням недели, волатильность.
    *   Генерация отчетов (Excel/CSV/JSON) по истории цен.
*   **REST API:** Полноценный API для интеграции с внешними системами (`/api/status`, `/api/config`, `/api/update`, `/api/report`, `/api/analytics`).
*   **Планировщик задач:** APScheduler с поддержкой Cron-триггеров.
*   **Кроссплатформенность:** Работает на Windows, macOS и Linux.
*   **Docker поддержка:** Готовые Dockerfile и docker-compose.yml для контейнеризации.
*   **Простая установка:** Скрипты для автоматической настройки окружения и сборки установочных файлов (.exe, .dmg, .deb).

---

## ⚡ Быстрый старт (One-Click Setup)

Вам не нужно вручную устанавливать Python или настраивать окружение. Используйте наши скрипты автоматической установки — они всё сделают за вас!

### Вариант 1: Запуск приложения

Скопируйте и выполните **одну команду** в терминале:

#### 🪟 Windows (PowerShell)
```powershell
irm https://raw.githubusercontent.com/ShavlaK/AppsCloud.me/main/run_project.bat -OutFile run_project.bat; .\run_project.bat
```

#### 🍎 macOS / 🐧 Linux (Bash)
```bash
curl -fsSL https://raw.githubusercontent.com/ShavlaK/AppsCloud.me/main/run_project.sh -o run_project.sh && chmod +x run_project.sh && ./run_project.sh
```

> **Что сделает скрипт:**
> 1. Проверит версию Python и при необходимости установит подходящую изолированно.
> 2. Скачает последнюю версию проекта.
> 3. Создаст виртуальное окружение и установит все зависимости.
> 4. Создаст файлы конфигурации и папки для данных.
> 5. Запустит приложение и откроет веб-интерфейс в браузере.

---

### Вариант 2: Сборка установочного файла

Хотите создать `.exe` (Windows), `.dmg` (macOS) или `.deb`/`.tar.gz` (Linux) дистрибутив? Используйте скрипты сборщики. Они сами настройт всё необходимое.

#### 🪟 Windows (PowerShell)
```powershell
irm https://raw.githubusercontent.com/ShavlaK/AppsCloud.me/main/build_windows.bat -OutFile build_windows.bat; .\build_windows.bat
```

#### 🍎 macOS (Bash)
```bash
curl -fsSL https://raw.githubusercontent.com/ShavlaK/AppsCloud.me/main/build_macos.sh -o build_macos.sh && chmod +x build_macos.sh && ./build_macos.sh
```

#### 🐧 Linux (Bash)
```bash
curl -fsSL https://raw.githubusercontent.com/ShavlaK/AppsCloud.me/main/build_linux.sh -o build_linux.sh && chmod +x build_linux.sh && ./build_linux.sh
```

> **Результат:** Готовый установочный файл появится в папке `dist_release`:
> - **Windows:** `PriceUpdater_Windows.zip` с `.exe` файлом внутри
> - **macOS:** `PriceUpdater.dmg` образ
> - **Linux:** `.deb` пакет (для Debian/Ubuntu) и `tar.gz` архив (для остальных дистрибутивов)

---

### Вариант 3: Запуск через Docker

Самый быстрый способ развернуть приложение:

```bash
# Клонировать репозиторий
git clone https://github.com/ShavlaK/AppsCloud.me.git
cd AppsCloud.me

# Создать конфиг из примера
cp config.json.example config.json
# Отредактировать config.json (указать токены и channel_id)

# Запустить через docker-compose
docker-compose up -d
```

Веб-интерфейс будет доступен по адресу: `http://localhost:8080`

**Полезные команды Docker:**
```bash
# Просмотр логов
docker-compose logs -f

# Остановка
docker-compose down

# Пересборка
docker-compose up -d --build
```

---

## 🛠 Ручная установка (для разработчиков)

Если вы предпочитаете классический способ установки:

### Требования
*   Python 3.9 – 3.12
*   Git

### Шаги установки

1.  **Клонируйте репозиторий:**
    ```bash
    git clone https://github.com/ShavlaK/AppsCloud.me.git
    cd AppsCloud.me
    ```

2.  **Создайте виртуальное окружение и активируйте его:**
    ```bash
    # Windows
    python -m venv venv
    venv\Scripts\activate

    # macOS/Linux
    python3 -m venv venv
    source venv/bin/activate
    ```

3.  **Установите зависимости:**
    ```bash
    pip install -r requirements.txt
    ```

4.  **Настройте конфигурацию:**
    Скопируйте пример конфигурации и отредактируйте его:
    ```bash
    cp config.json.example config.json
    ```
    
    Отредактируйте файл `config.json`, указав токены ваших ботов и ID каналов:
    ```json
    {
      "source_bot_token": "ВАШ_ТОКЕН_ИСТОЧНИКА",
      "channel_bot_token": "ВАШ_ТОКЕН_КАНАЛА",
      "channel_id": "@ваш_канал",
      "markup_percent": 15,
      "update_interval_hours": 1
    }
    ```
    
    Или используйте переменные окружения (создайте файл `.env` на основе `.env.example`):
    ```bash
    cp .env.example .env
    # Отредактируйте .env, указав ваши токены
    ```

5.  **Запустите приложение:**
    ```bash
    python main.py
    ```
    Веб-интерфейс будет доступен по адресу: `http://localhost:8080`

---

## 📦 Сборка дистрибутива вручную

Если вы уже настроили окружение и хотите собрать установщик вручную:

*   **Windows:** Запустите `build_windows.bat`
*   **macOS:** Запустите `chmod +x build_macos.sh && ./build_macos.sh`
*   **Linux:** Запустите `chmod +x build_linux.sh && ./build_linux.sh`

Все скрипты автоматически:
- Проверят версию ОС и совместимость
- Проверят и установят недостающие зависимости (Python, Git, системные пакеты) только если их нет
- Создут виртуальное окружение
- Установят все необходимые библиотеки
- Соберут бинарный файл и упаковщик (где применимо)

---

## 🧪 Разработка и тестирование

### Установка pre-commit хуков
Для автоматической проверки кода перед коммитом:
```bash
pip install pre-commit
pre-commit install
```

Хуки будут автоматически проверять:
- Форматирование кода (Black)
- Сортировку импортов (isort)
- Стиль кода (flake8)
- Типизацию (mypy)
- Концевые пробелы и переводы строк

### Запуск тестов
```bash
pytest tests/
```

---

## 📂 Структура проекта

```text
.
├── main.py              # Точка входа
├── config.json.example  # Пример конфигурации
├── .env.example         # Пример переменных окружения
├── requirements.txt     # Зависимости Python
├── telegram_parser.py   # Логика парсинга источников
├── telegram_channel.py  # Публикация в канал
├── price_database.py    # Работа с SQLite
├── web_server.py        # FastAPI сервер и Dashboard
├── report_generator.py  # Генерация Excel/CSV отчетов
├── excel_parser.py      # Парсинг Excel файлов
├── Dockerfile           # Docker образ
├── docker-compose.yml   # Docker Compose конфигурация
├── templates/           # HTML шаблоны
├── tests/               # Тесты (pytest)
├── data/                # База данных (игнорируется git)
├── logs/                # Логи (игнорируется git)
├── reports/             # Отчёты (игнорируется git)
├── run_project.*        # Скрипты быстрого запуска
├── build_*              # Скрипты сборки установщиков
└── .pre-commit-config.yaml  # Pre-commit хуки
```

---

## 🔒 Безопасность

*   Токены ботов хранятся только локально в `config.json` или `.env`.
*   **Никогда не коммитьте `config.json` или `.env` в репозиторий!** Используйте `config.json.example` и `.env.example`.
*   Приложение не передает ваши токены третьим сторонам.
*   Рекомендуется запускать приложение на выделенном сервере или локальной машине.
*   Все чувствительные файлы добавлены в `.gitignore`.

## 📄 Лицензия

Этот проект распространяется под лицензией MIT. См. файл [LICENSE](LICENSE) для подробностей.

## 🤝 Поддержка

Если у вас возникли вопросы или проблемы:
1.  Проверьте раздел [Issues](https://github.com/ShavlaK/AppsCloud.me/issues).
2.  Убедитесь, что версия Python соответствует требованиям (3.9–3.12).
3.  Проверьте логи в папке `logs/` или во вкладке "Логи" веб-интерфейса.
4.  Убедитесь, что конфигурационный файл заполнен корректно.

---

*Разработано для автоматизации рутинных задач в Telegram.*
