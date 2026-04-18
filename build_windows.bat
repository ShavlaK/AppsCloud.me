@echo off
setlocal enabledelayedexpansion

echo ==========================================
echo   СБОРКА УСТАНОВОЧНОГО ФАЙЛА (WINDOWS)
echo ==========================================

:: Проверка наличия Python
python --version >nul 2>&1
if errorlevel 1 (
    echo [ОШИБКА] Python не найден! Установите Python 3.9+ и добавьте его в PATH.
    pause
    exit /b 1
)

echo [OK] Python найден.

:: Создание виртуального окружения
if not exist "venv" (
    echo [INFO] Создание виртуального окружения...
    python -m venv venv
) else (
    echo [INFO] Виртуальное окружение уже существует.
)

:: Активация окружения
echo [INFO] Активация виртуального окружения...
call venv\Scripts\activate.bat

:: Установка зависимостей
echo [INFO] Установка зависимостей...
pip install --upgrade pip
pip install -r requirements.txt
pip install pyinstaller

:: Создание директорий
if not exist "data" mkdir data
if not exist "logs" mkdir logs
if not exist "reports" mkdir reports

:: Создание шаблона config.json, если отсутствует
if not exist "config.json" (
    echo [INFO] Создание шаблона config.json...
    (
        echo {
        echo   "bot_token": "YOUR_BOT_TOKEN",
        echo   "api_id": 0,
        echo   "api_hash": "YOUR_API_HASH",
        echo   "source_channel": "@source_channel",
        echo   "target_channel": "@target_channel",
        echo   "markup_percent": 10,
        echo   "update_interval_hours": 1,
        echo   "admin_ids": [],
        echo   "web_host": "0.0.0.0",
        echo   "web_port": 8080
        echo }
    ) > config.json
)

:: Сборка через PyInstaller
echo [INFO] Запуск сборки PyInstaller...

:: Проверяем наличие папок templates и static
set "PYINSTALLER_ARGS=--name=\"PriceUpdater\" --onefile --console --add-data \"config.json;.\""

if exist "templates" (
    echo [INFO] Добавлена папка templates
    set "PYINSTALLER_ARGS=!PYINSTALLER_ARGS! --add-data \"templates;templates\""
)

if exist "static" (
    echo [INFO] Добавлена папка static
    set "PYINSTALLER_ARGS=!PYINSTALLER_ARGS! --add-data \"static;static\""
)

set "PYINSTALLER_ARGS=!PYINSTALLER_ARGS! --hidden-import=telethon --hidden-import=aiogram --hidden-import=fastapi --hidden-import=uvicorn --hidden-import=pandas --hidden-import=openpyxl"

pyinstaller !PYINSTALLER_ARGS! main.py

if errorlevel 1 (
    echo [ОШИБКА] Ошибка при сборке!
    pause
    exit /b 1
)

:: Подготовка дистрибутива
echo [INFO] Подготовка папки дистрибутива...
if exist "dist_release" rmdir /s /q dist_release
mkdir dist_release
copy dist\PriceUpdater.exe dist_release\
copy config.json dist_release\config.json.example
echo Скопируйте config.json.example в config.json и настройте токены перед запуском! > dist_release\README.txt

echo ==========================================
echo   СБОРКА ЗАВЕРШЕНА УСПЕШНО!
echo   Файл находится в папке: dist_release
echo ==========================================
pause