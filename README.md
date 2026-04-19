# Price Updater — Автоматическое обновление цен в Telegram

[![Python 3.9+](https://img.shields.io/badge/python-3.9+-blue.svg)](https://www.python.org/downloads/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-lightgrey)]()

Мощное решение для автоматического мониторинга и обновления прайс-листов в Telegram-каналах. Приложение парсит цены из источника, применяет наценку, сохраняет историю изменений в базу данных и публикует актуальные данные в ваш канал по расписанию. Включает веб-интерфейс для управления и генерации отчетов.

## 🚀 Возможности

*   **Автоматизация:** Парсинг цен из Telegram-бота/канала источника каждый час (настраиваемо).
*   **Умная наценка:** Гибкая система наценок (процент или фиксированная сумма).
*   **История цен:** Сохранение всей истории изменений в SQLite базу данных.
*   **Веб-интерфейс (Dashboard):**
    *   Мониторинг статуса системы в реальном времени.
    *   Управление конфигурацией через браузер.
    *   Просмотр логов работы парсера.
    *   Генерация отчетов (Excel/CSV) по истории цен.
*   **REST API:** Полноценный API для интеграции с внешними системами.
*   **Кроссплатформенность:** Работает на Windows, macOS и Linux.
*   **Простая установка:** Скрипты для автоматической настройки окружения и сборки установочных файлов (.exe, .dmg, .deb).

---

## ⚡ Быстрый старт (One-Click Setup)

Вам не нужно клонировать репозиторий или вручную устанавливать Python. Используйте наши скрипты автоматической установки.

### Для запуска приложения

Скопируйте и выполните **одну команду** в терминале (PowerShell для Windows, Terminal для macOS/Linux):

#### 🪟 Windows (PowerShell)
```powershell
irm https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/run_project.bat -OutFile run_project.bat; .\run_project.bat
```

#### 🍎 macOS / 🐧 Linux (Bash)
```bash
curl -O https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/run_project.sh && chmod +x run_project.sh && ./run_project.sh
```

> **Что сделает скрипт:**
> 1. Проверит версию Python и при необходимости установит подходящую изолированно.
> 2. Скачает последнюю версию проекта.
> 3. Создаст виртуальное окружение и установит все зависимости.
> 4. Создаст файлы конфигурации и папки для данных.
> 5. Запустит приложение и откроет веб-интерфейс в браузере.

---

### Для сборки установочного файла

Хотите создать `.exe` (Windows), `.dmg` (macOS) или `.deb` (Linux) дистрибутив? Используйте скрипты сборщики. Они сами настройт всё необходимое.

#### 🪟 Windows (PowerShell)
```powershell
irm https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/build_installer.bat -OutFile build_installer.bat; .\build_installer.bat
```

#### 🍎 macOS / 🐧 Linux (Bash)
```bash
curl -O https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/build_installer.sh && chmod +x build_installer.sh && ./build_installer.sh
```

> **Результат:** Готовый установочный файл появится в папке `dist_release`.

---

## 🛠 Ручная установка (для разработчиков)

Если вы предпочитаете классический способ установки:

### Требования
*   Python 3.9 – 3.12
*   Git

### Шаги установки

1.  **Клонируйте репозиторий:**
    ```bash
    git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git
    cd YOUR_REPO
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

Скрипты автоматически проверят зависимости, соберут бинарный файл и упаковщик (где применимо).

---

## 📂 Структура проекта

```text
.
├── main.py              # Точка входа
├── config.json.example  # Пример конфигурации
├── requirements.txt     # Зависимости Python
├── telegram_parser.py   # Логика парсинга источников
├── telegram_channel.py  # Публикация в канал
├── price_database.py    # Работа с SQLite
├── web_server.py        # FastAPI сервер и Dashboard
├── report_generator.py  # Генерация Excel/CSV отчетов
├── static/              # CSS, JS для веба
├── templates/           # HTML шаблоны
├── data/                # База данных и логи (игнорируется git)
├── logs/                # Логи (игнорируется git)
├── reports/             # Отчёты (игнорируется git)
├── run_project.*        # Скрипты быстрого запуска
└── build_installer.*    # Скрипты сборки установщиков
```

---

## 🔒 Безопасность

*   Токены ботов хранятся только локально в `config.json`.
*   **Никогда не коммитьте `config.json` в репозиторий!** Используйте `config.json.example`.
*   Приложение не передает ваши токены третьим сторонам.
*   Рекомендуется запускать приложение на выделенном сервере или локальной машине.

## 📄 Лицензия

Этот проект распространяется под лицензией MIT. См. файл [LICENSE](LICENSE) для подробностей.

## 🤝 Поддержка

Если у вас возникли вопросы или проблемы:
1.  Проверьте раздел [Issues](https://github.com/YOUR_USERNAME/YOUR_REPO/issues).
2.  Убедитесь, что версия Python соответствует требованиям (3.9–3.12).
3.  Проверьте логи в папке `logs/` или во вкладке "Логи" веб-интерфейса.

---
*Разработано для автоматизации рутинных задач в Telegram.*
