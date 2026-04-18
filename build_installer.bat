@echo off
REM Скрипт для сборки установочного файла Price Updater для Windows
REM Автоматически скачивает проект, настраивает окружение и собирает дистрибутив

setlocal enabledelayedexpansion

echo ==========================================
echo   СБОРКА УСТАНОВОЧНОГО ФАЙЛА (Windows)
echo ==========================================

set REPO_URL=%REPO_URL:~%https://github.com/YOUR_USERNAME/YOUR_REPO.git%
set PROJECT_DIR=price-updater-build
set PYTHON_CMD=python

REM Проверка версии Python
echo [INFO] Проверка версии Python...
%PYTHON_CMD% --version >nul 2>&1
if errorlevel 1 (
    echo [WARN] Python не найден. Попытка установки...
    goto :install_python
)

for /f "tokens=2" %%i in ('%PYTHON_CMD% --version 2^>^&1') do set FULL_VERSION=%%i
for /f "tokens=1,2 delims=." %%a in ("!FULL_VERSION!") do (
    set MAJOR=%%a
    set MINOR=%%b
)

if !MAJOR! equ 3 (
    if !MINOR! GEQ 9 if !MINOR! LEQ 12 (
        echo [OK] Подходящая версия Python найдена: !FULL_VERSION!
        goto :download_project
    )
)

:install_python
echo [WARN] Версия Python не подходит (!FULL_VERSION!). Требуется 3.9-3.12
echo [INFO] Скачивание портативной версии Python 3.11...

set PYTHON_INSTALL_DIR=%~dp0python_portable
if not exist "%PYTHON_INSTALL_DIR%" (
    mkdir "%PYTHON_INSTALL_DIR%"
)

REM Скачивание портативного Python
set PYTHON_URL=https://www.python.org/ftp/python/3.11.8/python-3.11.8-embed-amd64.zip
set PYTHON_ZIP=%TEMP%\python_embed.zip

echo [INFO] Загрузка Python...
powershell -Command "& {Invoke-WebRequest -Uri '%PYTHON_URL%' -OutFile '%PYTHON_ZIP%'}"

echo [INFO] Распаковка Python...
powershell -Command "& {Expand-Archive -Path '%PYTHON_ZIP%' -DestinationPath '%PYTHON_INSTALL_DIR%' -Force}"

REM Включение pip
echo import site >> "%PYTHON_INSTALL_DIR%\python311._pth"
set PYTHON_CMD=%PYTHON_INSTALL_DIR%\python.exe

echo [OK] Python установлен в %PYTHON_INSTALL_DIR%

:download_project
echo ==========================================
echo   СКАЧИВАНИЕ ПРОЕКТА
echo ==========================================

if exist "%PROJECT_DIR%" (
    echo [INFO] Проект уже существует. Обновление...
    cd %PROJECT_DIR%
    git pull
    cd ..
) else (
    echo [INFO] Скачивание проекта...
    git clone %REPO_URL% %PROJECT_DIR%
)

cd %PROJECT_DIR%

:setup_environment
echo ==========================================
echo   НАСТРОЙКА ОКРУЖЕНИЯ
echo ==========================================

echo [INFO] Создание виртуального окружения...
%PYTHON_CMD% -m venv venv

echo [INFO] Активация виртуального окружения...
call venv\Scripts\activate.bat

echo [INFO] Установка зависимостей...
%PYTHON_CMD% -m pip install --upgrade pip
%PYTHON_CMD% -m pip install -r requirements.txt

echo [INFO] Установка PyInstaller...
%PYTHON_CMD% -m pip install pyinstaller

:prepare_build
echo ==========================================
echo   ПОДГОТОВКА К СБОРКЕ
echo ==========================================

REM Создание необходимых директорий
if not exist "data" mkdir data
if not exist "logs" mkdir logs
if not exist "reports" mkdir reports
if not exist "sessions" mkdir sessions
if not exist "static" mkdir static
if not exist "templates" mkdir templates

REM Копирование примера конфигурации если нет реального
if not exist "config.json" (
    copy config.json.example config.json
)

REM Очистка предыдущих сборок
if exist "build" rmdir /s /q build
if exist "dist" rmdir /s /q dist
del /q *.spec 2>nul

:build_installer
echo ==========================================
echo   СБОРКА УСТАНОВЩИКА
echo ==========================================

echo [INFO] Запуск сборки для Windows...
call build_windows.bat

:finish
echo.
echo ==========================================
echo   СБОРКА ЗАВЕРШЕНА
echo ==========================================
echo Установочный файл находится в папке: dist_release\
echo.

endlocal
