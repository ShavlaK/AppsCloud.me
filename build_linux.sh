#!/bin/bash

# ==========================================
# СБОРКА УСТАНОВОЧНОГО ФАЙЛА (LINUX)
# Полностью автоматическая сборка
# Один клик - полная настройка и сборка
# ==========================================

echo "=========================================="
echo "  СБОРКА УСТАНОВЩИКА PRICE UPDATER (Linux)"
echo "=========================================="

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Переход в директорию проекта
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo -e "${BLUE}[INFO]${NC} Рабочая директория: $SCRIPT_DIR"

# ==========================================
# ПРОВЕРКА ВЕРСИИ ОС
# ==========================================
check_os_version() {
    echo -e "${YELLOW}[INFO]${NC} Проверка версии операционной системы..."
    
    local OS_NAME=""
    local OS_VERSION=""
    local MIN_VERSION=""
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME=$NAME
        OS_VERSION=$VERSION_ID
        
        case "$ID" in
            ubuntu)
                MIN_VERSION="20.04"
                if (( $(echo "$OS_VERSION < $MIN_VERSION" | bc -l 2>/dev/null || echo 0) )); then
                    echo -e "${RED}[ОШИБКА]${NC} Требуется Ubuntu $MIN_VERSION или выше. Найдена версия: $OS_VERSION"
                    return 1
                fi
                ;;
            debian)
                MIN_VERSION="11"
                if (( $(echo "$OS_VERSION < $MIN_VERSION" | bc -l 2>/dev/null || echo 0) )); then
                    echo -e "${RED}[ОШИБКА]${NC} Требуется Debian $MIN_VERSION или выше. Найдена версия: $OS_VERSION"
                    return 1
                fi
                ;;
            fedora)
                MIN_VERSION="38"
                if (( $(echo "$OS_VERSION < $MIN_VERSION" | bc -l 2>/dev/null || echo 0) )); then
                    echo -e "${RED}[ОШИБКА]${NC} Требуется Fedora $MIN_VERSION или выше. Найдена версия: $OS_VERSION"
                    return 1
                fi
                ;;
            rhel|centos|rocky|almalinux)
                MIN_VERSION="8"
                if (( $(echo "$OS_VERSION < $MIN_VERSION" | bc -l 2>/dev/null || echo 0) )); then
                    echo -e "${RED}[ОШИБКА]${NC} Требуется RHEL/CentOS $MIN_VERSION или выше. Найдена версия: $OS_VERSION"
                    return 1
                fi
                ;;
            arch|manjaro)
                # Arch Linux всегда использует последние версии
                echo -e "${GREEN}[OK]${NC} Обнаружен Arch-based дистрибутив: $OS_NAME"
                return 0
                ;;
            *)
                echo -e "${YELLOW}[WARN]${NC} Непроверенный дистрибутив: $OS_NAME $OS_VERSION. Продолжаем с осторожностью..."
                return 0
                ;;
        esac
        
        echo -e "${GREEN}[OK]${NC} Обнаружена ОС: $OS_NAME $OS_VERSION (требуется: $ID >= $MIN_VERSION)"
        
    elif [ -f /etc/redhat-release ]; then
        OS_INFO=$(cat /etc/redhat-release)
        echo -e "${GREEN}[OK]${NC} Обнаружена Red Hat-совместимая система: $OS_INFO"
    else
        echo -e "${YELLOW}[WARN]${NC} Не удалось определить версию ОС. Продолжаем..."
    fi
    
    # Определение архитектуры
    ARCH=$(uname -m)
    echo -e "${GREEN}[OK]${NC} Архитектура системы: $ARCH"
    
    return 0
}

# Запуск проверки ОС
check_os_version || exit 1

# Функция для проверки команд
check_command() {
    if ! command -v $1 &> /dev/null; then
        return 1
    fi
    return 0
}

# Функция установки зависимостей системы
install_system_deps() {
    echo -e "${YELLOW}[INFO]${NC} Проверка системных зависимостей..."
    
    # Определение пакетного менеджера
    if command -v apt &> /dev/null; then
        PKG_MANAGER="apt"
        UPDATE_CMD="sudo apt update"
        INSTALL_CMD="sudo apt install -y"
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
        UPDATE_CMD="sudo yum update -y"
        INSTALL_CMD="sudo yum install -y"
    elif command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
        UPDATE_CMD="sudo dnf update -y"
        INSTALL_CMD="sudo dnf install -y"
    elif command -v pacman &> /dev/null; then
        PKG_MANAGER="pacman"
        UPDATE_CMD="sudo pacman -Sy"
        INSTALL_CMD="sudo pacman -S --noconfirm"
    elif command -v zypper &> /dev/null; then
        PKG_MANAGER="zypper"
        UPDATE_CMD="sudo zypper refresh"
        INSTALL_CMD="sudo zypper install -y"
    else
        echo -e "${RED}[ОШИБКА]${NC} Не найден поддерживаемый пакетный менеджер (apt, yum, dnf, pacman, zypper)"
        return 1
    fi
    
    echo -e "${GREEN}[OK]${NC} Обнаружен пакетный менеджер: $PKG_MANAGER"
    
    # Установка необходимых пакетов
    local MISSING_DEPS=()
    local MISSING_DEPS_NAMES=()
    
    # Проверка Python
    if ! command -v python3 &> /dev/null; then
        MISSING_DEPS+=("python3")
        MISSING_DEPS_NAMES+=("Python 3")
    else
        PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2 | cut -d'.' -f1,2)
        MAJOR=$(echo $PYTHON_VERSION | cut -d'.' -f1)
        MINOR=$(echo $PYTHON_VERSION | cut -d'.' -f2)
        if [ "$MAJOR" -ne 3 ] || [ "$MINOR" -lt 9 ] || [ "$MINOR" -gt 12 ]; then
            echo -e "${YELLOW}[WARN]${NC} Найдена версия Python $PYTHON_VERSION (требуется 3.9-3.12). Требуется установка."
            MISSING_DEPS+=("python3")
            MISSING_DEPS_NAMES+=("Python 3.9-3.12")
        else
            echo -e "${GREEN}[OK]${NC} Python $PYTHON_VERSION уже установлен."
        fi
    fi
    
    # Проверка pip3
    if ! command -v pip3 &> /dev/null; then
        # Проверяем альтернативные названия
        if command -v python3-pip &> /dev/null; then
            echo -e "${GREEN}[OK]${NC} pip3 уже установлен."
        else
            MISSING_DEPS+=("python3-pip")
            MISSING_DEPS_NAMES+=("pip3")
        fi
    else
        echo -e "${GREEN}[OK]${NC} pip3 уже установлен."
    fi
    
    # Проверка git
    if ! command -v git &> /dev/null; then
        MISSING_DEPS+=("git")
        MISSING_DEPS_NAMES+=("Git")
    else
        GIT_VERSION=$(git --version)
        echo -e "${GREEN}[OK]${NC} Git уже установлен: $GIT_VERSION"
    fi
    
    # Проверка make
    if ! command -v make &> /dev/null; then
        MISSING_DEPS+=("make")
        MISSING_DEPS_NAMES+=("make")
    else
        MAKE_VERSION=$(make --version | head -n1)
        echo -e "${GREEN}[OK]${NC} Make уже установлен: $MAKE_VERSION"
    fi
    
    # Проверка gcc
    if ! command -v gcc &> /dev/null; then
        MISSING_DEPS+=("gcc")
        MISSING_DEPS_NAMES+=("gcc")
    else
        GCC_VERSION=$(gcc --version | head -n1)
        echo -e "${GREEN}[OK]${NC} GCC уже установлен: $GCC_VERSION"
    fi
    
    # Проверка python3-venv
    if ! python3 -m venv --help &> /dev/null; then
        MISSING_DEPS+=("python3-venv")
        MISSING_DEPS_NAMES+=("python3-venv")
    else
        echo -e "${GREEN}[OK]${NC} python3-venv уже доступен."
    fi
    
    if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
        echo -e "${YELLOW}[INFO]${NC} Установка отсутствующих зависимостей: ${MISSING_DEPS_NAMES[*]}"
        $UPDATE_CMD
        $INSTALL_CMD "${MISSING_DEPS[@]}"
        echo -e "${GREEN}[OK]${NC} Системные зависимости установлены."
    else
        echo -e "${GREEN}[OK]${NC} Все системные зависимости найдены. Пропуск установки."
    fi
}

# Функция установки Python
setup_python() {
    # Сначала проверяем, есть ли уже подходящая версия
    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2 | cut -d'.' -f1,2)
        MAJOR=$(echo $PYTHON_VERSION | cut -d'.' -f1)
        MINOR=$(echo $PYTHON_VERSION | cut -d'.' -f2)
        
        if [ "$MAJOR" -eq 3 ] && [ "$MINOR" -ge 9 ] && [ "$MINOR" -le 12 ]; then
            echo -e "${GREEN}[OK]${NC} Подходящая версия Python уже установлена: $PYTHON_VERSION. Пропуск установки."
            return 0
        else
            echo -e "${YELLOW}[WARN]${NC} Найдена версия Python $PYTHON_VERSION (требуется 3.9-3.12). Будет установлена версия 3.11."
        fi
    fi
    
    local target_version="python3.11"
    
    # Попытка установки Python 3.11
    echo -e "${YELLOW}[INFO]${NC} Установка Python 3.11..."
    
    if [ "$PKG_MANAGER" = "apt" ]; then
        sudo apt install -y software-properties-common || true
        sudo add-apt-repository -y ppa:deadsnakes/ppa || true
        sudo apt update
        sudo apt install -y python3.11 python3.11-venv python3.11-dev
        # Обновляем альтернативы для использования python3.11 по умолчанию в этом скрипте
        update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 2>/dev/null || true
        # Экспортируем путь к python3.11 для текущего сеанса
        export PYTHON_CMD="/usr/bin/python3.11"
    elif [ "$PKG_MANAGER" = "yum" ] || [ "$PKG_MANAGER" = "dnf" ]; then
        $INSTALL_CMD python3.11 python3.11-pip python3.11-devel
        export PYTHON_CMD="/usr/bin/python3.11"
    elif [ "$PKG_MANAGER" = "pacman" ]; then
        $INSTALL_CMD python
        # Arch всегда имеет последнюю версию, проверяем её
        PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2 | cut -d'.' -f1,2)
        MAJOR=$(echo $PYTHON_VERSION | cut -d'.' -f1)
        MINOR=$(echo $PYTHON_VERSION | cut -d'.' -f2)
        if [ "$MAJOR" -eq 3 ] && [ "$MINOR" -ge 9 ] && [ "$MINOR" -le 12 ]; then
            echo -e "${GREEN}[OK]${NC} Python $PYTHON_VERSION подходит."
            export PYTHON_CMD="/usr/bin/python3"
        else
            echo -e "${RED}[ОШИБКА]${NC} Версия Python $PYTHON_VERSION не поддерживается на Arch Linux."
            exit 1
        fi
    fi
    
    # Проверка что PYTHON_CMD существует и работает
    if [ -n "$PYTHON_CMD" ] && [ -f "$PYTHON_CMD" ]; then
        echo -e "${GREEN}[OK]${NC} Python 3.11 установлен и найден по пути: $PYTHON_CMD"
        $PYTHON_CMD --version
    else
        echo -e "${YELLOW}[WARN]${NC} Не удалось найти явный путь к Python 3.11, пробуем python3"
        export PYTHON_CMD="python3"
    fi
}

# Функция определения архитектуры
detect_architecture() {
    ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then
        echo -e "${GREEN}[INFO]${NC} Обнаружена архитектура x86_64"
        ARCH_NAME="amd64"
    elif [ "$ARCH" = "aarch64" ]; then
        echo -e "${GREEN}[INFO]${NC} Обнаружена архитектура ARM64"
        ARCH_NAME="arm64"
    else
        echo -e "${YELLOW}[WARN]${NC} Необычная архитектура: $ARCH"
        ARCH_NAME="$ARCH"
    fi
}

echo ""
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}  ШАГ 1: ПРОВЕРКА И НАСТРОЙКА ОКРУЖЕНИЯ${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""

# Установка системных зависимостей
install_system_deps

# Установка Python
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
rm -rf venv build dist dist_release *.spec __pycache__ deb_package
find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find . -type f -name "*.pyc" -delete 2>/dev/null || true

# Создание виртуального окружения с использованием правильной версии Python
echo -e "${GREEN}[INFO]${NC} Создание виртуального окружения..."
if [ -n "$PYTHON_CMD" ] && [ -f "$PYTHON_CMD" ]; then
    $PYTHON_CMD -m venv venv || {
        echo -e "${RED}[ОШИБКА]${NC} Не удалось создать виртуальное окружение с $PYTHON_CMD"
        exit 1
    }
else
    python3 -m venv venv || {
        echo -e "${RED}[ОШИБКА]${NC} Не удалось создать виртуальное окружение"
        exit 1
    }
fi

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
echo -e "${GREEN}[INFO]${NC} Установка инструментов сборки (PyInstaller)..."
pip install pyinstaller --quiet

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
    --console \
    --add-data "config.json:." \
    --hidden-import="telethon" \
    --hidden-import="aiogram" \
    --hidden-import="fastapi" \
    --hidden-import="uvicorn" \
    --hidden-import="pandas" \
    --hidden-import="openpyxl" \
    main.py 2>&1 || {
    echo -e "${RED}[ОШИБКА]${NC} Ошибка при сборке PyInstaller!"
    exit 1
}

# Добавляем templates если существует
if [ -d "templates" ]; then
    echo -e "${GREEN}[INFO]${NC} Добавление папки templates..."
    # Для Linux путь разделяется двоеточием
    pyinstaller --name="PriceUpdater" \
        --onefile \
        --console \
        --add-data "templates:templates" \
        --add-data "config.json:." \
        --hidden-import="telethon" \
        --hidden-import="aiogram" \
        --hidden-import="fastapi" \
        --hidden-import="uvicorn" \
        --hidden-import="pandas" \
        --hidden-import="openpyxl" \
        main.py 2>&1 || true
    echo -e "${GREEN}[OK]${NC} Templates добавлены."
fi

# Добавляем static если существует
if [ -d "static" ]; then
    echo -e "${GREEN}[INFO]${NC} Добавление папки static..."
    pyinstaller --name="PriceUpdater" \
        --onefile \
        --console \
        --add-data "static:static" \
        --add-data "templates:templates" \
        --add-data "config.json:." \
        --hidden-import="telethon" \
        --hidden-import="aiogram" \
        --hidden-import="fastapi" \
        --hidden-import="uvicorn" \
        --hidden-import="pandas" \
        --hidden-import="openpyxl" \
        main.py 2>&1 || true
    echo -e "${GREEN}[OK]${NC} Static добавлен."
fi

# Проверка успешности сборки
if [ ! -f "dist/PriceUpdater" ]; then
    echo -e "${RED}[ОШИБКА]${NC} Файл приложения не найден после сборки!"
    exit 1
fi

echo -e "${GREEN}[OK]${NC} PyInstaller сборка завершена успешно!"

echo ""
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}  ШАГ 6: ПОДГОТОВКА ДИСТРИБУТИВА${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""

# Подготовка дистрибутива
echo -e "${GREEN}[INFO]${NC} Подготовка папки дистрибутива..."
rm -rf dist_release
mkdir -p dist_release
cp dist/PriceUpdater dist_release/
cp config.json dist_release/config.json.example

# Создание README файла
cat > dist_release/README.txt << EOF
=========================================
Price Updater - Дистрибутив для Linux
=========================================

Файлы в папке:
  - PriceUpdater - исполняемый файл приложения
  - config.json.example - пример конфигурации
  - README.txt - этот файл

ИНСТРУКЦИЯ ПО ЗАПУСКУ:
======================
1. Скопируйте config.json.example в config.json
   cp config.json.example config.json

2. Отредактируйте config.json, указав ваши токены:
   - source_bot_token - токен бота-источника
   - channel_bot_token - токен вашего бота для канала
   - channel_id - ID Telegram-канала
   - markup_percent - процент наценки

3. Запустите приложение:
   ./PriceUpdater

Веб-интерфейс будет доступен по адресу:
http://localhost:8080

=========================================
EOF

echo -e "${GREEN}[OK]${NC} README создан."

# Создание .deb пакета (для Debian/Ubuntu)
if command -v dpkg-deb &> /dev/null; then
    echo ""
    echo -e "${BLUE}[INFO]${NC} Создание .deb пакета..."
    mkdir -p deb_package/DEBIAN
    mkdir -p deb_package/usr/bin
    mkdir -p deb_package/etc/price-updater
    
    cp dist_release/PriceUpdater deb_package/usr/bin/price-updater
    cp config.json.example deb_package/etc/price-updater/config.json.example 2>/dev/null || cp config.json deb_package/etc/price-updater/config.json.example
    
    cat > deb_package/DEBIAN/control << DEBEOF
Package: price-updater
Version: 1.0.0
Section: utils
Priority: optional
Architecture: $ARCH_NAME
Maintainer: Developer
Description: Telegram Price Updater
 Автоматическое обновление цен в Telegram-канале
Depends: python3, python3-pip
DEBEOF
    
    cat > deb_package/DEBIAN/postinst << POSTINSTEOF
#!/bin/bash
echo "Установка завершена!"
echo "Настройте /etc/price-updater/config.json перед запуском"
chmod +x /usr/bin/price-updater
POSTINSTEOF
    
    chmod +x deb_package/DEBIAN/postinst
    chmod +x deb_package/usr/bin/price-updater
    
    cd deb_package
    dpkg-deb --build . ../dist_release/price-updater_1.0.0_${ARCH_NAME}.deb
    cd ..
    
    # Очистка временных файлов
    rm -rf deb_package
    
    echo -e "${GREEN}[OK]${NC} .deb пакет создан: dist_release/price-updater_1.0.0_${ARCH_NAME}.deb"
else
    echo -e "${YELLOW}[INFO]${NC} dpkg-deb не найден. Пропуск создания .deb пакета."
fi

# Создание tar.gz архива
echo ""
echo -e "${BLUE}[INFO]${NC} Создание tar.gz архива..."
cd dist_release
tar -czf PriceUpdater_Linux_${ARCH_NAME}.tar.gz PriceUpdater README.txt config.json.example 2>/dev/null || tar -czf PriceUpdater_Linux_${ARCH_NAME}.tar.gz PriceUpdater README.txt
cd ..
echo -e "${GREEN}[OK]${NC} tar.gz архив создан: dist_release/PriceUpdater_Linux_${ARCH_NAME}.tar.gz"

# Вывод результатов
echo ""
echo "=========================================="
echo -e "${GREEN}✅ СБОРКА ЗАВЕРШЕНА УСПЕШНО!${NC}"
echo "=========================================="
echo ""
echo -e "${BLUE}📦 Результаты находятся в папке:${NC} dist_release/"
echo ""
echo -e "${BLUE}Файлы:${NC}"
ls -lh dist_release/
echo ""
echo -e "${BLUE}📋 Для запуска:${NC}"
echo "  1. Скопируйте папку dist_release в удобное место"
echo "  2. Настройте config.json (скопируйте из config.json.example)"
echo "  3. Запустите ./PriceUpdater"
echo ""
echo -e "${GREEN}🌐 Веб-интерфейс будет доступен по адресу: http://localhost:8080${NC}"
echo ""