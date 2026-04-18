#!/bin/bash

echo "=========================================="
echo "  СБОРКА УСТАНОВОЧНОГО ФАЙЛА (LINUX)"
echo "=========================================="

# Проверка наличия Python
if ! command -v python3 &> /dev/null; then
    echo "[ОШИБКА] Python3 не найден! Установите Python 3.9+."
    exit 1
fi

PYTHON_VERSION=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)
REQUIRED_VERSION="3.9"

if [[ "$(printf '%s\n' "$REQUIRED_VERSION" "$PYTHON_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]]; then
    echo "[ОШИБКА] Требуется Python 3.9+, у вас версия $PYTHON_VERSION"
    exit 1
fi

echo "[OK] Python $PYTHON_VERSION найден."

# Создание виртуального окружения
if [ ! -d "venv" ]; then
    echo "[INFO] Создание виртуального окружения..."
    python3 -m venv venv
else
    echo "[INFO] Виртуальное окружение уже существует."
fi

# Активация окружения
echo "[INFO] Активация виртуального окружения..."
source venv/bin/activate

# Установка зависимостей
echo "[INFO] Установка зависимостей..."
pip install --upgrade pip
pip install -r requirements.txt
pip install pyinstaller

# Создание директорий
mkdir -p data logs reports

# Создание шаблона config.json, если отсутствует
if [ ! -f "config.json" ]; then
    echo "[INFO] Создание шаблона config.json..."
    cat > config.json <<EOF
{
  "bot_token": "YOUR_BOT_TOKEN",
  "api_id": 0,
  "api_hash": "YOUR_API_HASH",
  "source_channel": "@source_channel",
  "target_channel": "@target_channel",
  "markup_percent": 10,
  "update_interval_hours": 1,
  "admin_ids": [],
  "web_host": "0.0.0.0",
  "web_port": 8080
}
EOF
fi

# Сборка через PyInstaller
echo "[INFO] Запуск сборки PyInstaller..."

# Проверка наличия директорий для сборки
if [ -d "static" ]; then
    STATIC_OPT="--add-data \"static:static\""
else
    STATIC_OPT=""
fi

pyinstaller --name="PriceUpdater" \
    --onefile \
    --console \
    --add-data "config.json:." \
    --add-data "templates:templates" \
    $STATIC_OPT \
    --hidden-import=telethon \
    --hidden-import=aiogram \
    --hidden-import=fastapi \
    --hidden-import=uvicorn \
    --hidden-import=pandas \
    --hidden-import=openpyxl \
    main.py

if [ $? -ne 0 ]; then
    echo "[ОШИБКА] Ошибка при сборке!"
    exit 1
fi

# Подготовка дистрибутива
echo "[INFO] Подготовка папки дистрибутива..."
rm -rf dist_release
mkdir -p dist_release
cp dist/PriceUpdater dist_release/
cp config.json dist_release/config.json.example
echo "Скопируйте config.json.example в config.json и настройте токены перед запуском!" > dist_release/README.txt

# Создание .deb пакета (опционально, для Debian/Ubuntu)
if command -v dpkg-deb &> /dev/null; then
    echo "[INFO] Создание .deb пакета..."
    mkdir -p deb_package/DEBIAN
    mkdir -p deb_package/usr/bin
    mkdir -p deb_package/etc/price-updater
    
    cp dist_release/PriceUpdater deb_package/usr/bin/price-updater
    cp config.json deb_package/etc/price-updater/config.json.example
    
    cat > deb_package/DEBIAN/control <<EOF
Package: price-updater
Version: 1.0.0
Section: utils
Priority: optional
Architecture: amd64
Maintainer: Developer
Description: Telegram Price Updater
 Автоматическое обновление цен в Telegram-канале
EOF
    
    cat > deb_package/DEBIAN/postinst <<EOF
#!/bin/bash
echo "Установка завершена!"
echo "Настройте /etc/price-updater/config.json перед запуском"
chmod +x /usr/bin/price-updater
EOF
    
    chmod +x deb_package/DEBIAN/postinst
    chmod +x deb_package/usr/bin/price-updater
    
    cd deb_package
    dpkg-deb --build . ../dist_release/price-updater_1.0.0_amd64.deb
    cd ..
    
    echo "[OK] .deb пакет создан: dist_release/price-updater_1.0.0_amd64.deb"
fi

echo "=========================================="
echo "  СБОРКА ЗАВЕРШЕНА УСПЕШНО!"
echo "  Файлы находятся в папке: dist_release"
echo "  - PriceUpdater (исполняемый файл)"
echo "  - price-updater_1.0.0_amd64.deb (для Debian/Ubuntu)"
echo "=========================================="