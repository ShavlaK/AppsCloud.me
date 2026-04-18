#!/bin/bash
# Скрипт быстрого запуска проекта Price Updater
# Автоматически скачивает проект, настраивает окружение и запускает приложение

set -e

echo "=========================================="
echo "  ЗАПУСК PRICE UPDATER"
echo "=========================================="

# Определение ОС
OS="$(uname -s)"
REPO_URL="${REPO_URL:-https://github.com/YOUR_USERNAME/YOUR_REPO.git}"
PROJECT_DIR="price-updater"

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

# Установка pyenv для управления версиями Python
install_pyenv() {
    echo "[INFO] Установка pyenv..."
    if [ "$OS" = "Darwin" ]; then
        if ! command -v brew &> /dev/null; then
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        brew install pyenv
    else
        curl https://pyenv.run | bash
        echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
        echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
        echo 'eval "$(pyenv init -)"' >> ~/.bashrc
    fi
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
}

# Подготовка конфигурации
prepare_config() {
    echo "[INFO] Подготовка конфигурации..."
    
    if [ ! -f "config.json" ]; then
        cp config.json.example config.json
        echo "[WARN] Создан файл config.json. Отредактируйте его с вашими токенами!"
    fi
    
    # Создание необходимых директорий
    mkdir -p data logs reports sessions static templates
}

# Запуск приложения
run_app() {
    echo "[INFO] Инициализация базы данных..."
    $PYTHON_CMD -c "from price_database import init_db; init_db()" 2>/dev/null || true
    
    echo "=========================================="
    echo "  ЗАПУСК ПРИЛОЖЕНИЯ"
    echo "=========================================="
    echo ""
    echo "Веб-интерфейс будет доступен по адресу:"
    echo "http://localhost:8080"
    echo ""
    echo "Для остановки нажмите Ctrl+C"
    echo "=========================================="
    
    $PYTHON_CMD main.py
}

# Основная логика
setup_python
download_project
cd "$PROJECT_DIR"
setup_environment
prepare_config
run_app
