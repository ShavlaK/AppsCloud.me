# Contributing в Price Updater

Спасибо за интерес к проекту! Вот как можно помочь:

## 🐛 Баг-репорты

1. Проверьте, что баг ещё не reported в [Issues](https://github.com/yourusername/price-updater/issues)
2. Откройте новый issue с шаблоном:
   - **Описание:** Что произошло
   - **Ожидаемое поведение:** Что должно было произойти
   - **Шаги воспроизведения:**
   - **Логи:** (если есть)
   - **Окружение:** OS, Python версия

## 💡 Фича-реквесты

1. Откройте issue с меткой `enhancement`
2. Опишите:
   - Какую проблему решает фича
   - Как должна работать
   - Примеры использования

## 🔀 Pull Requests

### Подготовка

```bash
# Форкните репозиторий
git clone https://github.com/YOUR_USERNAME/price-updater.git
cd price-updater

# Создайте ветку
git checkout -b feature/my-awesome-feature
```

### Стандарты кода

```bash
# Форматирование
black .

# Линтинг
ruff check .

# Тесты
pytest tests/ -v
```

### Коммиты

Используйте [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: добавлена поддержка Avito API
fix: исправлён парсинг цен с символом ₽
docs: обновлён README
test: добавлены тесты для отчётов
refactor: переписан модуль логирования
```

### Чеклист PR

- [ ] Код отформатирован (`black .`)
- [ ] Линтер проходит (`ruff check .`)
- [ ] Тесты проходят (`pytest tests/`)
- [ ] Добавлены тесты для нового функционала
- [ ] Документация обновлена

## 🏗 Архитектура проекта

```
price-updater/
├── main.py              # Точка входа (планировщик + веб-сервер)
├── web_server.py        # FastAPI API + веб-интерфейс
├── telegram_parser.py   # Парсер цен из сообщений
├── telegram_channel.py  # Публикация в Telegram
├── price_database.py    # SQLite хранилище
├── price_storage.py     # JSON хранилище (legacy)
├── report_generator.py  # Генератор отчётов
├── logger_setup.py      # Настройка логирования
├── user_bot_client.py   # User API (Telethon) — TODO
├── demo.py              # Демо-режим
└── tests/               # Тесты
```

## 🧪 Тестирование

```bash
# Все тесты
pytest tests/ -v

# Конкретный файл
pytest tests/test_parser.py -v

# С покрытием
pytest tests/ --cov=. --cov-report=html
```

### Моки для Telegram

Для тестов без реального Telegram используются моки:

```python
from unittest.mock import patch, AsyncMock

@patch("aiohttp.ClientSession")
async def test_something(mock_session):
    mock_session.return_value.post.return_value.json.return_value = {
        "ok": True,
        "result": {"message_id": 12345}
    }
    # ... тест
```

## 📦 Сборка

### Локальная

```bash
# Python пакет
pip install -e .

# Windows .exe
pyinstaller build_scripts/build_windows.spec

# macOS .app
python build_scripts/build_macos.py

# Linux .deb
bash build_scripts/build_debian.sh
```

### CI/CD

При push тега `v*` автоматически собираются все форматы:

```bash
git tag v1.1.0
git push origin v1.1.0
```

## 🤝 Кодекс поведения

- Будьте уважительны к другим контрибьюторам
- Конструктивная критика приветствуется
- Помогайте новичкам

## 📞 Контакты

- Issues: https://github.com/yourusername/price-updater/issues
- Discussions: https://github.com/yourusername/price-updater/discussions

---

Спасибо за ваш вклад! 🎉
