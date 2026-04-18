#!/bin/bash

echo "=========================================="
echo "  СБОРКА УСТАНОВОЧНОГО ФАЙЛА (MACOS)"
echo "=========================================="

# Проверка наличия Python
if ! command -v python3 &> /dev/null; then
    echo "[ОШИБКА] Python3 не найден! Установите Python 3.9+ через Homebrew или python.org"
    exit 1
fi

PYTHON_VERSION=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)
REQUIRED_VERSION="3.9"

if [[ "$(printf '%s\n' "$REQUIRED_VERSION" "$PYTHON_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]]; then
    echo "[ОШИБКА] Требуется Python 3.9+, у вас версия $PYTHON_VERSION"
    exit 1
fi

echo "[OK] Python $PYTHON_VERSION найден."

# Проверка архитектуры (Intel/Apple Silicon)
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    echo "[INFO] Обнаружена архитектура Apple Silicon (M1/M2/M3)"
    ARCH_NAME="apple_silicon"
elif [ "$ARCH" = "x86_64" ]; then
    echo "[INFO] Обнаружена архитектура Intel"
    ARCH_NAME="intel"
else
    echo "[WARN] Неизвестная архитектура: $ARCH"
    ARCH_NAME="universal"
fi

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
pyinstaller --name="PriceUpdater" \
    --onefile \
    --console \
    --add-data "config.json:." \
    --add-data "templates:templates" \
    --add-data "static:static" \
    --hidden-import=telethon \
    --hidden-import=aiogram \
    --hidden-import=fastapi \
    --hidden-import=uvicorn \
    --hidden-import=pandas \
    --hidden-import=openpyxl \
    --osx-bundle-identifier="com.priceupdater.app" \
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

# Создание .app бандла (опционально)
echo "[INFO] Создание macOS .app бандла..."
mkdir -p PriceUpdater.app/Contents/MacOS
mkdir -p PriceUpdater.app/Contents/Resources

cat > PriceUpdater.app/Contents/Info.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>PriceUpdater</string>
    <key>CFBundleIdentifier</key>
    <string>com.priceupdater.app</string>
    <key>CFBundleName</key>
    <string>PriceUpdater</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.15</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

cp dist/PriceUpdater PriceUpdater.app/Contents/MacOS/
chmod +x PriceUpdater.app/Contents/MacOS/PriceUpdater

# Копирование ресурсов
cp -r templates PriceUpdater.app/Contents/Resources/ 2>/dev/null || true
cp -r static PriceUpdater.app/Contents/Resources/ 2>/dev/null || true
cp config.json PriceUpdater.app/Contents/Resources/ 2>/dev/null || true

# Упаковка в DMG (если есть hdiutil)
if command -v hdiutil &> /dev/null; then
    echo "[INFO] Создание DMG образа..."
    
    mkdir -p dmg_temp
    cp -r PriceUpdater.app dmg_temp/
    cp dist_release/README.txt dmg_temp/
    cp dist_release/config.json.example dmg_temp/
    
    hdiutil create -volname "PriceUpdater" -srcfolder dmg_temp -ov -format UDZO dist_release/PriceUpdater_${ARCH_NAME}.dmg
    
    rm -rf dmg_temp
    echo "[OK] DMG образ создан: dist_release/PriceUpdater_${ARCH_NAME}.dmg"
else
    cp -r PriceUpdater.app dist_release/
    echo "[INFO] .app бандл скопирован в dist_release/"
fi

rm -rf PriceUpdater.app

echo "=========================================="
echo "  СБОРКА ЗАВЕРШЕНА УСПЕШНО!"
echo "  Файлы находятся в папке: dist_release"
echo "  - PriceUpdater (исполняемый файл)"
if command -v hdiutil &> /dev/null; then
    echo "  - PriceUpdater_${ARCH_NAME}.dmg (DMG образ)"
fi
echo "  - PriceUpdater.app (.app бандл)"
echo "=========================================="