#!/bin/bash

# =============================================================================
# Скрипт автоматической установки и запуска Price Updater
# =============================================================================
# Описание:
#   - Проверяет наличие Python 3.9+
#   - Создает виртуальное окружение
#   - Устанавливает зависимости
#   - Создает шаблон config.json (если отсутствует)
#   - Инициализирует базу данных
#   - Запускает приложение
# =============================================================================

set -e  # Остановить скрипт при ошибке

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Без цвета

# Логотип
echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════╗"
echo "║       Price Updater - Setup Script        ║"
echo "╚═══════════════════════════════════════════╝"
echo -e "${NC}"

# Функция для печати сообщений
print_message() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] ✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] ⚠${NC} $1"
}

print_error() {
    echo -e "${RED}[$(date +'%H:%M:%S')] ✗${NC} $1"
}

# Переход в директорию проекта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

print_message "Рабочая директория: $SCRIPT_DIR"

# =============================================================================
# 1. Проверка Python
# =============================================================================
print_message "Проверка версии Python..."

if ! command -v python3 &> /dev/null; then
    print_error "Python 3 не найден. Пожалуйста, установите Python 3.9 или выше."
    exit 1
fi

PYTHON_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
PYTHON_MAJOR=$(python3 -c 'import sys; print(sys.version_info.major)')
PYTHON_MINOR=$(python3 -c 'import sys; print(sys.version_info.minor)')

if [ "$PYTHON_MAJOR" -lt 3 ] || ([ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 9 ]); then
    print_error "Требуется Python 3.9+, найдена версия $PYTHON_VERSION"
    exit 1
fi

print_success "Python $PYTHON_VERSION найден"

# =============================================================================
# 2. Создание виртуального окружения
# =============================================================================
VENV_DIR="venv"

if [ ! -d "$VENV_DIR" ]; then
    print_message "Создание виртуального окружения..."
    python3 -m venv $VENV_DIR
    print_success "Виртуальное окружение создано"
else
    print_success "Виртуальное окружение уже существует"
fi

# Активация виртуального окружения
print_message "Активация виртуального окружения..."
source $VENV_DIR/bin/activate
print_success "Виртуальное окружение активировано"

# =============================================================================
# 3. Установка зависимостей
# =============================================================================
print_message "Обновление pip..."
pip install --upgrade pip --quiet

if [ -f "requirements.txt" ]; then
    print_message "Установка зависимостей из requirements.txt..."
    pip install -r requirements.txt --quiet
    print_success "Зависимости установлены"
else
    print_error "Файл requirements.txt не найден!"
    exit 1
fi

# =============================================================================
# 4. Создание конфигурационного файла
# =============================================================================
CONFIG_FILE="config.json"

if [ ! -f "$CONFIG_FILE" ]; then
    print_warning "Файл конфигурации не найден. Создание шаблона..."
    
    cat > $CONFIG_FILE << EOF
{
    "telegram": {
        "bot_token": "YOUR_BOT_TOKEN",
        "source_bot_username": "source_bot_username",
        "channel_id": -1001234567890,
        "admin_ids": [123456789]
    },
    "parser": {
        "update_interval_hours": 1,
        "markup_percentage": 15,
        "working_hours": {
            "start": 9,
            "end": 22
        }
    },
    "database": {
        "path": "data/prices.db"
    },
    "web_server": {
        "host": "0.0.0.0",
        "port": 8080,
        "enable_dashboard": true
    },
    "logging": {
        "level": "INFO",
        "file": "logs/app.log",
        "max_size_mb": 10,
        "backup_count": 5
    }
}
EOF
    
    print_success "Шаблон конфигурации создан: $CONFIG_FILE"
    print_warning "⚠️  НЕОБХОДИМО отредактировать $CONFIG_FILE и указать ваши токены!"
else
    print_success "Файл конфигурации найден"
fi

# =============================================================================
# 5. Создание необходимых директорий
# =============================================================================
print_message "Создание служебных директорий..."

mkdir -p data
mkdir -p logs
mkdir -p reports

print_success "Директории созданы"

# =============================================================================
# 6. Инициализация базы данных
# =============================================================================
print_message "Инициализация базы данных..."
python3 -c "
import sys
sys.path.insert(0, '$SCRIPT_DIR')
from price_database import PriceDatabase
db = PriceDatabase()
db.initialize()
print('База данных инициализирована')
" 2>/dev/null || print_warning "Не удалось инициализировать БД (возможно, потребуется первый запуск)"

print_success "База данных готова"

# =============================================================================
# 7. Запуск приложения
# =============================================================================
echo ""
echo -e "${GREEN}═══════════════════════════════════════════${NC}"
echo -e "${GREEN}         Настройка завершена успешно!      ${NC}"
echo -e "${GREEN}═══════════════════════════════════════════${NC}"
echo ""

print_warning "Перед запуском убедитесь, что:"
echo "  1. В файле $CONFIG_FILE указаны корректные токены"
echo "  2. Бот добавлен в канал как администратор"
echo "  3. Порт 8080 (или другой из конфига) свободен"
echo ""

read -p "$(echo -e ${YELLOW}Запустить приложение сейчас? (y/n): ${NC})" -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_message "Запуск приложения..."
    echo ""
    print_success "Веб-интерфейс будет доступен по адресу: http://localhost:8080"
    echo ""
    python3 main.py
else
    print_message "Приложение не запущено. Для запуска используйте команду:"
    echo -e "  ${GREEN}source venv/bin/activate && python3 main.py${NC}"
fi
