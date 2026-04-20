#!/bin/bash

# ==========================================
# СБОРКА УСТАНОВОЧНОГО ФАЙЛА (MACOS)
# Полностью автоматическая сборка в DMG
# Один клик - полная настройка и сборка
# ==========================================

set -e

echo "=========================================="
echo "  СБОРКА УСТАНОВЧИКА PRICE UPDATER (macOS)"
echo "=========================================="

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Переход в директорию проекта
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Создаем временную директорию для сборки
TEMP_DIR=$(mktemp -d)
REPO_URL="https://github.com/ShavlaK/AppsCloud.me.git"
PROJECT_DIR="price_updater_build"

echo -e "${BLUE}[INFO]${NC} Рабочая директория: $SCRIPT_DIR"
echo -e "${BLUE}[INFO]${NC} Временная директория для сборки: $TEMP_DIR"

# ==========================================
# КЛОНИРОВАНИЕ РЕПОЗИТОРИЯ
# ==========================================
echo ""
echo "════════════════════════════════════════"
echo "  ШАГ 0: КЛОНИРОВАНИЕ РЕПОЗИТОРИЯ"
echo "════════════════════════════════════════"

cd "$TEMP_DIR"
echo -e "${BLUE}[INFO]${NC} Клонирование репозитория..."
git clone "$REPO_URL" "$PROJECT_DIR"
cd "$PROJECT_DIR"

echo -e "${GREEN}[OK]${NC} Репозиторий успешно клонирован."

# ==========================================
# ПРОВЕРКА ВЕРСИИ MACOS
# ==========================================
check_macos_version() {
    echo -e "${YELLOW}[INFO]${NC} Проверка версии macOS..."
    
    # Получение версии macOS
    local MACOS_VERSION=$(sw_vers -productVersion)
    local MAJOR_VERSION=$(echo $MACOS_VERSION | cut -d'.' -f1)
    
    echo -e "${GREEN}[OK]${NC} Обнаружена версия macOS: $MACOS_VERSION"
    
    # Проверка минимальной версии (требуется macOS 10.15 Catalina или выше)
    if [ "$MAJOR_VERSION" -lt 10 ]; then
        echo -e "${RED}[ОШИБКА]${NC} Требуется macOS 10.15 (Catalina) или выше. Найдена версия: $MACOS_VERSION"
        return 1
    elif [ "$MAJOR_VERSION" -eq 10 ]; then
        local MINOR_VERSION=$(echo $MACOS_VERSION | cut -d'.' -f2)
        if [ "$MINOR_VERSION" -lt 15 ]; then
            echo -e "${RED}[ОШИБКА]${NC} Требуется macOS 10.15 (Catalina) или выше. Найдена версия: $MACOS_VERSION"
            return 1
        fi
    fi
    
    echo -e "${GREEN}[OK]${NC} Версия macOS совместима (требуется 10.15+)"
    
    # Определение архитектуры
    local ARCH=$(uname -m)
    echo -e "${GREEN}[OK]${NC} Архитектура системы: $ARCH"
    
    return 0
}

# Запуск проверки macOS
check_macos_version || exit 1

# Функция для проверки команд
check_command() {
    if ! command -v $1 &> /dev/null; then
        return 1
    fi
    return 0
}

# Функция установки Homebrew
install_homebrew() {
    echo -e "${YELLOW}[INFO]${NC} Установка Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
    echo -e "${GREEN}[OK]${NC} Homebrew установлен."
}

# Функция установки Python
setup_python() {
    local target_version="python@3.11"
    
    # Проверка текущей версии Python
    if check_command python3; then
        PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2 | cut -d'.' -f1,2)
        MAJOR=$(echo $PYTHON_VERSION | cut -d'.' -f1)
        MINOR=$(echo $PYTHON_VERSION | cut -d'.' -f2)
        
        if [ "$MAJOR" -eq 3 ] && [ "$MINOR" -ge 9 ] && [ "$MINOR" -le 12 ]; then
            echo -e "${GREEN}[OK]${NC} Подходящая версия Python уже установлена: $PYTHON_VERSION. Пропуск установки."
            return 0
        else
            echo -e "${YELLOW}[WARN]${NC} Версия Python $PYTHON_VERSION не подходит (требуется 3.9-3.12). Будет установлен Python 3.11."
        fi
    fi
    
    # Установка Python через Homebrew
    if ! check_command brew; then
        install_homebrew
    fi
    
    echo -e "${YELLOW}[INFO]${NC} Установка Python 3.11 через Homebrew..."
    brew install $target_version || true
    
    # Принудительное переключение на Python 3.11
    echo -e "${YELLOW}[INFO]${NC} Принудительное переключение на Python 3.11..."
    brew unlink python@3.11 2>/dev/null || true
    brew link --force python@3.11 || true
    
    # Поиск пути к Python 3.11
    PYTHON_311_PATH=$(brew --prefix python@3.11)/bin/python3.11
    
    if [ ! -f "$PYTHON_311_PATH" ]; then
        echo -e "${RED}[ОШИБКА]${NC} Не удалось найти исполняемый файл Python 3.11"
        exit 1
    fi
    
    echo -e "${GREEN}[OK]${NC} Python 3.11 установлен и найден по пути: $PYTHON_311_PATH"
    
    # Обновление PATH для использования Python 3.11
    export PATH="$(dirname $PYTHON_311_PATH):$PATH"
    hash -r 2>/dev/null || true
    
    # Проверка версии
    $PYTHON_311_PATH --version
}

# Функция установки Git
setup_git() {
    if ! check_command git; then
        echo -e "${YELLOW}[INFO]${NC} Git не найден. Установка..."
        if ! check_command brew; then
            install_homebrew
        fi
        brew install git
        echo -e "${GREEN}[OK]${NC} Git установлен."
    else
        GIT_VERSION=$(git --version)
        echo -e "${GREEN}[OK]${NC} Git уже установлен: $GIT_VERSION. Пропуск установки."
    fi
}

# Функция определения архитектуры
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

echo ""
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}  ШАГ 1: ПРОВЕРКА И НАСТРОЙКА ОКРУЖЕНИЯ${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""

# Проверка и установка зависимостей
setup_git
setup_python

# Проверка версии Python после установки
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}[ОШИБКА]${NC} Python 3 не найден после установки."
    exit 1
fi

PYTHON_VERSION=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)
echo -e "${GREEN}[OK]${NC} Активная версия Python: $PYTHON_VERSION"

# Определение архитектуры
detect_architecture

echo ""
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}  ШАГ 2: СОЗДАНИЕ ВИРТУАЛЬНОГО ОКРУЖЕНИЯ${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""

# Очистка предыдущих сборок
echo -e "${GREEN}[INFO]${NC} Очистка предыдущих сборок..."
rm -rf venv build dist dist_release *.spec __pycache__
find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find . -type f -name "*.pyc" -delete 2>/dev/null || true

# Создание виртуального окружения с использованием Python 3.11
echo -e "${GREEN}[INFO]${NC} Создание виртуального окружения..."
python3 -m venv venv || {
    echo -e "${RED}[ОШИБКА]${NC} Не удалось создать виртуальное окружение с python3"
    # Попытка использовать явный путь к Python 3.11
    if [ -f "$PYTHON_311_PATH" ]; then
        echo -e "${YELLOW}[INFO]${NC} Попытка создать окружение с Python 3.11 напрямую..."
        $PYTHON_311_PATH -m venv venv || exit 1
    else
        exit 1
    fi
}

# Активация виртуального окружения
echo -e "${GREEN}[INFO]${NC} Активация виртуального окружения..."
source venv/bin/activate

# Обновление pip
echo -e "${GREEN}[INFO]${NC} Обновление pip..."
pip install --upgrade pip --quiet

# Проверка версии Python в виртуальном окружении
VENV_PYTHON_VERSION=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)
echo -e "${GREEN}[INFO]${NC} Версия Python в виртуальном окружении: $VENV_PYTHON_VERSION"

# Проверка на совместимость
MAJOR=$(echo $VENV_PYTHON_VERSION | cut -d'.' -f1)
MINOR=$(echo $VENV_PYTHON_VERSION | cut -d'.' -f2)
if [ "$MAJOR" -ne 3 ] || [ "$MINOR" -lt 9 ] || [ "$MINOR" -gt 12 ]; then
    echo -e "${RED}[ОШИБКА]${NC} Версия Python в виртуальном окружении ($VENV_PYTHON_VERSION) не поддерживается!"
    echo -e "${YELLOW}[INFO]${NC} Требуется Python 3.9-3.12 для совместимости с pydantic-core."
    exit 1
fi

echo ""
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}  ШАГ 3: УСТАНОВКА ЗАВИСИМОСТЕЙ${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""

# Установка зависимостей
echo -e "${GREEN}[INFO]${NC} Установка зависимостей из requirements.txt..."
if [ -f "requirements.txt" ]; then
    # Установка pydantic с совместимой версией
    echo -e "${YELLOW}[INFO]${NC} Установка совместимых версий pydantic..."
    pip install "pydantic>=2.5,<2.7" "pydantic-core>=2.14,<2.15" --quiet
    pip install -r requirements.txt --quiet
else
    echo -e "${RED}[ОШИБКА]${NC} Файл requirements.txt не найден!"
    exit 1
fi

# Установка инструментов для сборки
echo -e "${GREEN}[INFO]${NC} Установка инструментов сборки (PyInstaller, dmgbuild)..."
pip install pyinstaller dmgbuild --quiet

# Проверка наличия необходимых системных библиотек
echo -e "${GREEN}[INFO]${NC} Проверка системных зависимостей..."

# Функция проверки установленных Xcode Command Line Tools
check_xcode_clt() {
    if pkgutil --pkgs | grep -q com.apple.pkg.CLTools_Executables; then
        # Проверяем, что инструменты действительно работают
        if xcode-select -p &> /dev/null; then
            return 0
        fi
    fi
    return 1
}

if ! check_xcode_clt; then
    echo -e "${YELLOW}[WARN]${NC} Xcode Command Line Tools не найдены. Установка..."
    # Пробуем установить через xcode-select
    xcode-select --install 2>/dev/null || true
    
    # Ждем подтверждения пользователем (до 60 секунд)
    echo -e "${YELLOW}[INFO]${NC} Если появилось окно установки, подтвердите установку Xcode Command Line Tools."
    
    # Проверяем установку в цикле (максимум 60 секунд)
    WAIT_TIME=0
    MAX_WAIT=60
    while ! check_xcode_clt && [ $WAIT_TIME -lt $MAX_WAIT ]; do
        sleep 5
        WAIT_TIME=$((WAIT_TIME + 5))
        echo -ne "${YELLOW}[INFO]${NC} Ожидание установки... ($WAIT_TIME сек)\r"
    done
    echo ""
    
    if check_xcode_clt; then
        echo -e "${GREEN}[OK]${NC} Xcode Command Line Tools успешно установлены."
    else
        echo -e "${YELLOW}[WARN]${NC} Не удалось автоматически установить Xcode Command Line Tools."
        echo -e "${YELLOW}[INFO]${NC} Установите их вручную через: xcode-select --install"
        echo -e "${YELLOW}[INFO]${NC} Продолжение сборки без Xcode CLT может привести к ошибкам компиляции."
    fi
else
    XCODE_PATH=$(xcode-select -p)
    echo -e "${GREEN}[OK]${NC} Xcode Command Line Tools уже установлены: $XCODE_PATH"
fi
echo -e "${GREEN}[OK]${NC} Системные зависимости проверены."

echo ""
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}  ШАГ 4: ПОДГОТОВКА ФАЙЛОВ ПРОЕКТА${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""

# Создание необходимых директорий
echo -e "${GREEN}[INFO]${NC} Создание необходимых директорий..."
mkdir -p static templates data logs reports sessions

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

# Копирование config.json если нет
if [ ! -f "config.json" ]; then
    echo -e "${YELLOW}[INFO]${NC} Копирование config.json.example в config.json..."
    cp config.json.example config.json
    echo -e "${YELLOW}[WARN]${NC} Не забудьте настроить config.json перед запуском!"
fi

echo ""
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}  ШАГ 5: СБОРКА PYINSTALLER${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""

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

echo ""
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}  ШАГ 6: СОЗДАНИЕ DMG ОБРАЗА${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""

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
echo -e "${GREEN}✅ СБОРКА ЗАВЕРШЕНА УСПЕШНО!${NC}"
echo "=========================================="
echo ""
echo -e "${BLUE}📦 Результаты находятся в папке:${NC} dist_release/macOS/"
echo ""
echo -e "${BLUE}Файлы:${NC}"
ls -lh dist_release/macOS/
echo ""
echo -e "${BLUE}📋 Для установки:${NC}"
echo "  1. Откройте PriceUpdater.dmg"
echo "  2. Перетащите PriceUpdater.app в папку Applications"
echo "  3. Запустите приложение из папки Applications"
echo ""
echo -e "${YELLOW}⚠️ Примечание:${NC} При первом запуске macOS может предупредить о неизвестном разработчике."
echo "   Чтобы обойти это: Системные настройки → Защита и безопасность → Разрешить"
echo ""
echo -e "${GREEN}🌐 Веб-интерфейс будет доступен по адресу: http://localhost:8080${NC}"
echo ""
