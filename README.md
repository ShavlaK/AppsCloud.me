# Price Updater

Автоматизированная система для обновления прайс-листов в Telegram-канале с наценкой, мониторингом истории цен и веб-интерфейсом управления.

## 📋 Описание функционала

### Основные возможности

1. **Автоматическое обновление цен**
   - Парсинг прайс-листа из бота-источника через Telegram User API
   - Применение наценки к ценам (настраивается в конфиге)
   - Публикация обновлённого прайса в целевой Telegram-канал
   - Расписание обновлений: каждый час (настраивается через APScheduler)

2. **Хранение истории цен**
   - SQLite база данных для хранения истории изменений цен
   - Отслеживание динамики цен по каждому товару
   - Возможность анализа ценовых трендов

3. **Веб-интерфейс (Dashboard)**
   - **Статус системы**: отображение текущего состояния парсера, расписания, последних обновлений
   - **Конфигурация**: управление настройками через веб-интерфейс (токены, наценки, расписание)
   - **Логи**: просмотр логов работы системы в реальном времени
   - **Отчёты**: генерация отчётов по истории цен за выбранный период
   - Адаптивный дизайн с поддержкой тёмной темы

4. **REST API**
   - `/api/status` — получение статуса системы
   - `/api/config` — управление конфигурацией
   - `/api/logs` — получение логов
   - `/api/report` — генерация отчётов
   - `/api/trigger-update` — принудительный запуск обновления

5. **Генерация отчётов**
   - Экспорт истории цен в Excel/CSV
   - Фильтрация по датам и товарам
   - Статистика изменений цен

## 🚀 Установка

### Требования

- Python 3.9+
- pip 21.0+

### Шаг 1: Клонирование репозитория

```bash
git clone <URL_РЕПОЗИТОРИЯ>
cd price-updater
```

### Шаг 2: Создание виртуального окружения

```bash
python -m venv venv

# Windows
venv\Scripts\activate

# Linux/macOS
source venv/bin/activate
```

### Шаг 3: Установка зависимостей

```bash
pip install -r requirements.txt
```

### Шаг 4: Настройка конфигурации

Скопируйте пример конфигурации и отредактируйте его:

```bash
cp config.json.example config.json
```

Заполните `config.json` необходимыми параметрами:

```json
{
  "telegram": {
    "bot_token": "YOUR_BOT_TOKEN",
    "api_id": YOUR_API_ID,
    "api_hash": "YOUR_API_HASH",
    "session_name": "price_updater",
    "source_bot_username": "source_bot_username",
    "channel_id": -100XXXXXXXXXX
  },
  "pricing": {
    "markup_percent": 15,
    "round_prices": true
  },
  "scheduler": {
    "update_interval_hours": 1
  },
  "web_server": {
    "host": "0.0.0.0",
    "port": 8000,
    "debug": false
  },
  "database": {
    "path": "prices.db"
  }
}
```

**Важно:**
- `bot_token` — токен бота для публикации в канал (от @BotFather)
- `api_id` и `api_hash` — получить на [my.telegram.org](https://my.telegram.org)
- `channel_id` — ID канала, куда публиковать прайс (можно узнать через @userinfobot)
- Бот должен быть добавлен в канал как администратор

## 📦 Формирование установочных файлов

### Создание исполняемого файла (Windows/Linux/macOS)

Для создания автономного исполняемого файла используйте PyInstaller:

```bash
# Установка PyInstaller
pip install pyinstaller

# Сборка для вашей ОС
pyinstaller --onefile --name price-updater main.py

# Для Windows с иконкой
pyinstaller --onefile --name price-updater --icon=icon.ico main.py

# Для скрытия консоли (только для GUI режима)
pyinstaller --onefile --windowed --name price-updater main.py
```

Исполняемый файл появится в папке `dist/`.

### Создание Docker-образа

Создайте файл `Dockerfile`:

```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["python", "main.py"]
```

Сборка и запуск:

```bash
docker build -t price-updater .
docker run -d -p 8000:8000 -v $(pwd)/config.json:/app/config.json -v $(pwd)/prices.db:/app/prices.db price-updater
```

### Создание установочного пакета для Linux (.deb)

```bash
# Установка инструментов
sudo apt-get install -y dpkg-dev debhelper

# Создание структуры пакета
mkdir -p price-updater_{version}_amd64/{DEBIAN,opt/price-updater,etc/price-updater}

# Копирование файлов
cp -r * price-updater_{version}_amd64/opt/price-updater/
cp config.json.example price-updater_{version}_amd64/etc/price-updater/config.json

# Создание control файла
echo "Package: price-updater
Version: 1.0.0
Section: utils
Priority: optional
Architecture: amd64
Maintainer: Your Name <your@email.com>
Description: Automated Telegram price updater
 Dependends: python3, python3-pip" > price-updater_{version}_amd64/DEBIAN/control

# Сборка пакета
dpkg-deb --build price-updater_{version}_amd64
```

## 📖 Инструкция по использованию

### Запуск приложения

#### Основной режим (с веб-интерфейсом)

```bash
python main.py
```

После запуска:
- Веб-интерфейс доступен по адресу: `http://localhost:8000`
- API доступно по адресу: `http://localhost:8000/api`
- Первое обновление произойдёт согласно расписанию

#### Только парсер (без веб-интерфейса)

```bash
python main.py --no-web
```

#### Принудительное обновление

Через веб-интерфейс:
1. Откройте вкладку "Статус"
2. Нажмите кнопку "Обновить сейчас"

Или через API:

```bash
curl -X POST http://localhost:8000/api/trigger-update
```

### Работа с веб-интерфейсом

1. **Вкладка "Статус"**
   - Отображает текущее состояние системы
   - Показывает время последнего обновления
   - Индикаторы активности парсера и планировщика

2. **Вкладка "Конфигурация"**
   - Редактирование настроек без перезапуска
   - Изменение размера наценки
   - Настройка интервала обновлений
   - Сохранение изменений применяется немедленно

3. **Вкладка "Логи"**
   - Просмотр логов в реальном времени
   - Фильтрация по уровню (INFO, WARNING, ERROR)
   - Автообновление каждые 5 секунд

4. **Вкладка "Отчёты"**
   - Выбор периода для отчёта
   - Генерация отчёта в Excel или CSV
   - Просмотр статистики изменений цен

### Работа с API

Примеры запросов:

```bash
# Получить статус
curl http://localhost:8000/api/status

# Получить конфигурацию
curl http://localhost:8000/api/config

# Обновить конфигурацию
curl -X PUT http://localhost:8000/api/config \
  -H "Content-Type: application/json" \
  -d '{"pricing": {"markup_percent": 20}}'

# Получить логи (последние 100 строк)
curl "http://localhost:8000/api/logs?limit=100"

# Сгенерировать отчёт за период
curl -X POST http://localhost:8000/api/report \
  -H "Content-Type: application/json" \
  -d '{"start_date": "2024-01-01", "end_date": "2024-01-31", "format": "excel"}'
```

### Планировщик задач

По умолчанию обновление происходит каждый час. Для изменения интервала:

1. Отредактируйте `config.json`:
   ```json
   "scheduler": {
     "update_interval_hours": 2
   }
   ```

2. Или через веб-интерфейс на вкладке "Конфигурация"

### Мониторинг и логирование

Логи сохраняются в файл `price_updater.log` и дублируются в консоль.

Уровни логирования:
- `INFO` — стандартные события
- `WARNING` — предупреждения
- `ERROR` — ошибки

Для просмотра логов в реальном времени:

```bash
tail -f price_updater.log
```

## 🔧 Структура проекта

```
price-updater/
├── main.py                 # Точка входа
├── telegram_parser.py      # Парсинг из Telegram
├── telegram_channel.py     # Публикация в канал
├── excel_parser.py         # Работа с Excel
├── price_database.py       # База данных цен
├── web_server.py           # Веб-сервер и API
├── report_generator.py     # Генерация отчётов
├── user_bot_client.py      # Telethon клиент
├── config.json             # Конфигурация
├── requirements.txt        # Зависимости
├── tests/                  # Тесты
│   └── test_*.py
└── templates/              # HTML шаблоны веб-интерфейса
    └── *.html
```

## 🧪 Тестирование

Запуск тестов:

```bash
pytest tests/ -v
```

Запуск с покрытием:

```bash
pytest tests/ --cov=. --cov-report=html
```

## ⚠️ Важные замечания

1. **Безопасность**: Не коммитьте `config.json` с реальными токенами в репозиторий
2. **Session file**: Файл сессии `*.session` создаётся автоматически при первом запуске
3. **Rate limits**: Telegram имеет ограничения на частоту запросов, не устанавливайте интервал меньше 15 минут
4. **База данных**: Регулярно делайте бэкап `prices.db`

## 📄 Лицензия

[Укажите вашу лицензию]

## 🤝 Поддержка

При возникновении проблем создайте issue в репозитории с описанием ошибки и логами.