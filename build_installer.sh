#!/bin/bash
# Скрипт для сборки установочного файла Price Updater
# Автоматически скачивает проект, настраивает окружение и собирает дистрибутив

set -e

echo "=========================================="
echo "  СБОРКА УСТАНОВОЧНОГО ФАЙЛА"
echo "=========================================="

# Определение ОС
OS="$(uname -s)"
REPO_URL="${REPO_URL:-https://github.com/YOUR_USERNAME/YOUR_REPO.git}"
PROJECT_DIR="price-updater-build"

# Функция проверки версии Python
check_python_version() {
    local version=$1
    local major=$(echo $version | cut -d. -f1)
    local minor=$(echo $version | cut -d. -f2)
    
    if [ "$major" -eq 3 ] && [ "$minor" -ge 9 ] && [ "$minor" -le 12 ]; then
        return 0
    fi
    return 1
}

# Установка подходящей версии Python
setup_python() {
    local target_version="3.11.8"
    
    # Проверка текущей версии
    if command -v python3 &> /dev/null; then
        current_version=$(python3 --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        if [ -n "$current_version" ] && check_python_version "$current_version"; then
            echo "[OK] Подходящая версия Python найдена: $current_version"
            PYTHON_CMD="python3"
            return
        fi
    fi
    
    echo "[WARN] Версия Python не подходит или не найдена. Установка Python $target_version..."
    
    # Попытка использовать pyenv
    if command -v pyenv &> /dev/null; then
        pyenv install --skip-existing $target_version
        pyenv local $target_version
        PYTHON_CMD="python3"
    else
        # Попытка установки через системный пакетный менеджер
        if [ "$OS" = "Darwin" ]; then
            if ! command -v brew &> /dev/null; then
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            fi
            brew install python@3.11
        elif command -v apt &> /dev/null; then
            sudo apt update
            sudo apt install -y python3.11 python3.11-venv python3.11-dev
            PYTHON_CMD="python3.11"
        elif command -v yum &> /dev/null; then
            sudo yum install -y python3.11
            PYTHON_CMD="python3.11"
        else
            echo "[ERROR] Не удалось установить подходящую версию Python автоматически."
            echo "Пожалуйста, установите Python 3.9-3.12 вручную."
            exit 1
        fi
    fi
    
    echo "[OK] Python установлен."
}

# Скачивание проекта
download_project() {
    if [ -d "$PROJECT_DIR" ]; then
        echo "[INFO] Проект уже существует. Обновление..."
        cd "$PROJECT_DIR"
        git pull
        cd ..
    else
        echo "[INFO] Скачивание проекта..."
        git clone "$REPO_URL" "$PROJECT_DIR"
    fi
    
    cd "$PROJECT_DIR"
}

# Создание виртуального окружения и установка зависимостей
setup_environment() {
    echo "[INFO] Создание виртуального окружения..."
    $PYTHON_CMD -m venv venv
    
    echo "[INFO] Активация виртуального окружения..."
    source venv/bin/activate
    
    echo "[INFO] Установка зависимостей..."
    pip install --upgrade pip
    pip install -r requirements.txt
    
    echo "[INFO] Установка PyInstaller и инструментов для упаковки..."
    pip install pyinstaller
    
    if [ "$OS" = "Darwin" ]; then
        pip install dmgbuild || echo "[WARN] Не удалось установить dmgbuild"
    fi
}

# Подготовка к сборке
prepare_build() {
    echo "[INFO] Подготовка к сборке..."
    
    # Создание необходимых директорий
    mkdir -p data logs reports sessions static templates
    
    # Копирование примера конфигурации если нет реального
    if [ ! -f "config.json" ]; then
        cp config.json.example config.json
    fi
    
    # Очистка предыдущих сборок
    rm -rf build dist *.spec
}

# Сборка в зависимости от ОС
build_installer() {
    echo "[INFO] Запуск сборки..."
    
    if [ "$OS" = "Darwin" ]; then
        echo "[INFO] Сборка для macOS..."
        chmod +x build_macos.sh
        ./build_macos.sh
    elif [ "$OS" = "Linux" ]; then
        echo "[INFO] Сборка для Linux..."
        chmod +x build_linux.sh
        ./build_linux.sh
    else
        echo "[ERROR] Неподдерживаемая ОС: $OS"
        echo "Используйте build_installer.bat для Windows"
        exit 1
    fi
}

# Основная логика
setup_python
download_project
cd "$PROJECT_DIR"
setup_environment
prepare_build
build_installer

echo ""
echo "=========================================="
echo "  СБОРКА ЗАВЕРШЕНА"
echo "=========================================="
echo "Установочный файл находится в папке: dist_release/"
echo ""
