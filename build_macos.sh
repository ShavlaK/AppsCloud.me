#!/bin/bash

# ==========================================
# СБОРКА УСТАНОВОЧНОГО ФАЙЛА (MACOS)
# Полностью автоматическая сборка в DMG
# ==========================================

set -e

echo "=========================================="
echo "  СБОРКА УСТАНОВОЧНОГО ФАЙЛА (MACOS)"
echo "=========================================="

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функция для проверки команд
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}[ОШИБКА]${NC} Команда $1 не найдена. Пожалуйста, установите её."
        exit 1
    fi
}

# Функция для проверки версии Python
check_python_version() {
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}[ОШИБКА]${NC} Python 3 не найден."
        echo "Пожалуйста, установите Python 3.11 или 3.12:"
        echo "  brew install python@3.11"
        exit 1
    fi

    PYTHON_VERSION=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)
    
    # Проверка на слишком новую версию (3.13+)
    MAJOR=$(echo $PYTHON_VERSION | cut -d'.' -f1)
    MINOR=$(echo $PYTHON_VERSION | cut -d'.' -f2)
    
    if [ "$MAJOR" -eq 3 ] && [ "$MINOR" -ge 13 ]; then
        echo -e "${YELLOW}[ПРЕДУПРЕЖДЕНИЕ]${NC} Обнаружена Python $PYTHON_VERSION."
        echo "Версии Python 3.13+ могут иметь проблемы с совместимостью библиотек."
        echo "Рекомендуется использовать Python 3.11 или 3.12."
        echo ""
        read -p "Хотите продолжить с текущей версией? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Пожалуйста, установите Python 3.11: brew install python@3.11"
            exit 1
        fi
    elif [ "$MAJOR" -ne 3 ] || [ "$MINOR" -lt 9 ]; then
        echo -e "${RED}[ОШИБКА]${NC} Требуется Python 3.9+, найдено: $PYTHON_VERSION"
        exit 1
    fi
    
    echo -e "${GREEN}[OK]${NC} Python $PYTHON_VERSION найден."
}

# Функция для определения архитектуры
detect_architecture() {
    ARCH=$(uname -m)
    if [ "$ARCH" = "arm64" ]; then
        echo -e "${GREEN}[INFO]${NC} Обнаружена архитектура Apple Silicon (M1/M2/M3)"
        ARCH_NAME="apple_silicon"
    elif [ "$ARCH" = "x86_64" ]; then
        echo -e "${GREEN}[INFO]${NC} Обнаружена архитектура Intel"
        ARCH_NAME="intel"
    else
        echo -e "${RED}[ОШИБКА]${NC} Неизвестная архитектура: $ARCH"
        exit 1
    fi
}

# Проверка зависимостей
check_command python3
check_command pip3
check_command git

# Проверка версии Python
check_python_version

# Определение архитектуры
detect_architecture

# Переход в директорию проекта
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo -e "${GREEN}[INFO]${NC} Рабочая директория: $SCRIPT_DIR"

# Очистка предыдущих сборок
echo -e "${GREEN}[INFO]${NC} Очистка предыдущих сборок..."
rm -rf venv build dist dist_release *.spec __pycache__
find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find . -type f -name "*.pyc" -delete 2>/dev/null || true

# Создание виртуального окружения
echo -e "${GREEN}[INFO]${NC} Создание виртуального окружения..."
python3 -m venv venv

# Активация виртуального окружения
echo -e "${GREEN}[INFO]${NC} Активация виртуального окружения..."
source venv/bin/activate

# Обновление pip
echo -e "${GREEN}[INFO]${NC} Обновление pip..."
pip install --upgrade pip

# Установка зависимостей
echo -e "${GREEN}[INFO]${NC} Установка зависимостей..."
if [ -f "requirements.txt" ]; then
    # Установка pydantic с совместимой версией
    pip install "pydantic>=2.5,<2.7" "pydantic-core>=2.14,<2.15"
    pip install -r requirements.txt
else
    echo -e "${RED}[ОШИБКА]${NC} Файл requirements.txt не найден!"
    exit 1
fi

# Установка дополнительных инструментов для сборки
echo -e "${GREEN}[INFO]${NC} Установка инструментов сборки..."
pip install pyinstaller dmgbuild

# Создание необходимых директорий
echo -e "${GREEN}[INFO]${NC} Создание необходимых директорий..."
mkdir -p static templates data logs reports

# Создание заглушек для static и templates если они пусты
if [ ! -f "static/.gitkeep" ]; then
    touch static/.gitkeep
fi
if [ ! -f "templates/.gitkeep" ]; then
    touch templates/.gitkeep
fi

# Проверка наличия основных файлов проекта
if [ ! -f "main.py" ]; then
    echo -e "${RED}[ОШИБКА]${NC} Файл main.py не найден!"
    exit 1
fi

# Запуск сборки PyInstaller
echo -e "${GREEN}[INFO]${NC} Запуск сборки PyInstaller..."
pyinstaller --name="PriceUpdater" \
    --onefile \
    --windowed \
    --add-data "static:static" \
    --add-data "templates:templates" \
    --add-data "config.json:." \
    --hidden-import="aiohttp" \
    --hidden-import="aiogram" \
    --hidden-import="fastapi" \
    --hidden-import="uvicorn" \
    --hidden-import="jinja2" \
    --osx-bundle-identifier="com.priceupdater.app" \
    --icon="icon.icns" \
    main.py 2>&1 || {
    echo -e "${RED}[ОШИБКА]${NC} Ошибка при сборке PyInstaller!"
    exit 1
}

# Проверка успешности сборки
if [ ! -f "dist/PriceUpdater.app" ]; then
    echo -e "${RED}[ОШИБКА]${NC} Файл приложения не найден после сборки!"
    exit 1
fi

echo -e "${GREEN}[OK]${NC} PyInstaller сборка завершена успешно!"

# Создание директории для релиза
echo -e "${GREEN}[INFO]${NC} Создание директории для релиза..."
mkdir -p dist_release/macOS

# Копирование собранного приложения
cp -R dist/PriceUpdater.app dist_release/macOS/

# Создание DMG образа
echo -e "${GREEN}[INFO]${NC} Создание DMG образа..."

# Создание скрипта для dmgbuild
cat > dmg_config.py << EOF
format = 'UDZO'
size = None
files_dir = 'dist_release/macOS'
symlinks = {'Applications': '/Applications'}
background = None
icon_size = 80
text_size = 12
EOF

# Сборка DMG
dmgbuild -s dmg_config.py -D dist_release/macOS "PriceUpdater" dist_release/macOS/PriceUpdater.dmg
echo -e "${GREEN}[OK]${NC} DMG образ создан: dist_release/macOS/PriceUpdater.dmg"

# Очистка временных файлов
rm -f dmg_config.py

# Вывод результатов
echo ""
echo "=========================================="
echo -e "${GREEN}СБОРКА ЗАВЕРШЕНА УСПЕШНО!${NC}"
echo "=========================================="
echo "Результаты находятся в папке: dist_release/macOS/"
echo ""
echo "Файлы:"
ls -lh dist_release/macOS/
echo ""
echo "Для установки:"
echo "  1. Откройте PriceUpdater.dmg"
echo "  2. Перетащите PriceUpdater.app в папку Applications"
echo "  3. Запустите приложение из папки Applications"
echo ""
echo -e "${YELLOW}Примечание:${NC} При первом запуске macOS может предупредить о неизвестном разработчике."
echo "Чтобы обойти это: Системные настройки -> Защита и безопасность -> Разрешить"
echo ""