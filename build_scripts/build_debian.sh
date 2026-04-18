#!/bin/bash
# Скрипт сборки .deb пакета для Debian/Ubuntu
#
# Использование:
#   bash build_scripts/build_debian.sh
#
# Требования: dpkg-deb, python3

set -e

VERSION="1.0.0"
PKG_NAME="price-updater"
BUILD_DIR="build/debian"
PKG_DIR="$BUILD_DIR/${PKG_NAME}_${VERSION}_all"

echo "🔧 Сборка .deb пакета: ${PKG_NAME} v${VERSION}"

# Очистка
rm -rf "$BUILD_DIR"

# Создание структуры пакета
DEBIAN_DIR="$PKG_DIR/DEBIAN"
mkdir -p "$DEBIAN_DIR"
mkdir -p "$PKG_DIR/usr/share/${PKG_NAME}"
mkdir -p "$PKG_DIR/usr/bin"
mkdir -p "$PKG_DIR/usr/lib/${PKG_NAME}"

# control файл
cat > "$DEBIAN_DIR/control" << EOF
Package: ${PKG_NAME}
Version: ${VERSION}
Section: utils
Priority: optional
Architecture: all
Depends: python3 (>= 3.9), python3-pip
Maintainer: Price Updater Contributors
Description: Автоматическое обновление прайс-листов в Telegram
 Price Updater — утилита для автоматического обновления прайс-листов
 в Telegram каналах с ежемесячными отчётами и веб-интерфейсом.
EOF

# postinst скрипт (после установки)
cat > "$DEBIAN_DIR/postinst" << 'EOF'
#!/bin/bash
echo "Установка Price Updater завершена!"
echo "Для запуска выполните: price-updater"
echo "Веб-интерфейс: http://localhost:8000"
EOF
chmod 755 "$DEBIAN_DIR/postinst"

# Копирование файлов проекта
cp -r templates "$PKG_DIR/usr/lib/${PKG_NAME}/"
cp *.py "$PKG_DIR/usr/lib/${PKG_NAME}/"
cp config.json "$PKG_DIR/usr/lib/${PKG_NAME}/"
cp README.md "$PKG_DIR/usr/lib/${PKG_NAME}/"
cp requirements.txt "$PKG_DIR/usr/lib/${PKG_NAME}/"
cp pyproject.toml "$PKG_DIR/usr/lib/${PKG_NAME}/"

# Создание wrapper скрипта
cat > "$PKG_DIR/usr/bin/price-updater" << 'EOF'
#!/bin/bash
cd /usr/lib/price-updater
python3 main.py "$@"
EOF
chmod 755 "$PKG_DIR/usr/bin/price-updater"

# Установка зависимостей через pip (postinst)
cat >> "$DEBIAN_DIR/postinst" << 'EOF'

# Установка Python зависимостей
pip3 install --break-system-packages -q \
    aiogram apscheduler aiohttp telethon \
    fastapi uvicorn jinja2 python-multipart 2>/dev/null || \
pip3 install -q \
    aiogram apscheduler aiohttp telethon \
    fastapi uvicorn jinja2 python-multipart
EOF

# Сборка пакета
cd "$BUILD_DIR"
dpkg-deb --build "${PKG_NAME}_${VERSION}_all"

echo "✅ .deb пакет создан: ${BUILD_DIR}/${PKG_NAME}_${VERSION}_all.deb"
echo "📦 Размер: $(du -h "${BUILD_DIR}/${PKG_NAME}_${VERSION}_all.deb" | cut -f1)"
echo ""
echo "Установка:"
echo "  sudo dpkg -i ${PKG_NAME}_${VERSION}_all.deb"
echo "  sudo apt-get install -f  # для зависимостей"
