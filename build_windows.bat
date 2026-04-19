@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: ==========================================
:: СБОРКА УСТАНОВОЧНОГО ФАЙЛА (WINDOWS)
:: Полностью автоматическая сборка в EXE
:: ==========================================

echo ==========================================
echo   СБОРКА УСТАНОВОЧНОГО ФАЙЛА (WINDOWS)
echo ==========================================
echo.

:: Проверка наличия Python
where python >nul 2>nul
if %errorlevel% neq 0 (
    echo [ОШИБКА] Python не найден!
    echo Пожалуйста, установите Python 3.11 или 3.12 с https://www.python.org/downloads/
    echo При установке отметьте галочку "Add Python to PATH"
    pause
    exit /b 1
)

for /f "tokens=2" %%i in ('python --version') do set PYTHON_VERSION=%%i
echo [OK] Python %PYTHON_VERSION% найден.

:: Проверка версии Python (предупреждение для 3.13+)
for /f "tokens=1,2 delims=." %%a in ("%PYTHON_VERSION%") do (
    set MAJOR=%%a
    set MINOR=%%b
)

if %MAJOR%==3 if %MINOR% GEQ 13 (
    echo [ПРЕДУПРЕЖДЕНИЕ] Обнаружена Python %PYTHON_VERSION%.
    echo Версии Python 3.13+ могут иметь проблемы с совместимостью библиотек.
    echo Рекомендуется использовать Python 3.11 или 3.12.
    echo.
    set /p CONTINUE="Хотите продолжить с текущей версией? (y/n): "
    if /i not "!CONTINUE!"=="y" (
        echo Пожалуйста, установите Python 3.11 с https://www.python.org/downloads/release/python-31110/
        pause
        exit /b 1
    )
) else if %MAJOR% NEQ 3 (
    echo [ОШИБКА] Требуется Python 3.x, найдено: %PYTHON_VERSION%
    pause
    exit /b 1
) else if %MINOR% LSS 9 (
    echo [ОШИБКА] Требуется Python 3.9+, найдено: %PYTHON_VERSION%
    pause
    exit /b 1
)

:: Переход в директорию проекта
cd /d "%~dp0"
echo [INFO] Рабочая директория: %CD%
echo.

:: Очистка предыдущих сборок
echo [INFO] Очистка предыдущих сборок...
if exist "venv" rmdir /s /q venv
if exist "build" rmdir /s /q build
if exist "dist" rmdir /s /q dist
if exist "dist_release" rmdir /s /q dist_release
if exist "*.spec" del /q *.spec
for /d %%i in (__pycache__) do @rmdir /s /q "%%i" 2>nul
for /d /r %%i in (__pycache__) do @rmdir /s /q "%%i" 2>nul
echo.

:: Создание виртуального окружения
echo [INFO] Создание виртуального окружения...
python -m venv venv
if %errorlevel% neq 0 (
    echo [ОШИБКА] Не удалось создать виртуальное окружение!
    pause
    exit /b 1
)
echo.

:: Активация виртуального окружения
echo [INFO] Активация виртуального окружения...
call venv\Scripts\activate.bat
if %errorlevel% neq 0 (
    echo [ОШИБКА] Не удалось активировать виртуальное окружение!
    pause
    exit /b 1
)
echo.

:: Обновление pip
echo [INFO] Обновление pip...
python -m pip install --upgrade pip --quiet
echo.

:: Установка зависимостей
echo [INFO] Установка зависимостей...
if exist "requirements.txt" (
    :: Установка pydantic с совместимой версией
    echo [INFO] Установка pydantic...
    pip install "pydantic>=2.5,<2.7" "pydantic-core>=2.14,<2.15" --quiet
    
    echo [INFO] Установка зависимостей из requirements.txt...
    pip install -r requirements.txt --quiet
    if %errorlevel% neq 0 (
        echo [ОШИБКА] Ошибка при установке зависимостей!
        pause
        exit /b 1
    )
) else (
    echo [ОШИБКА] Файл requirements.txt не найден!
    pause
    exit /b 1
)
echo.

:: Установка дополнительных инструментов для сборки
echo [INFO] Установка инструментов сборки...
pip install pyinstaller --quiet
echo.

:: Создание необходимых директорий
echo [INFO] Создание необходимых директорий...
if not exist "static" mkdir static
if not exist "templates" mkdir templates
if not exist "data" mkdir data
if not exist "logs" mkdir logs
if not exist "reports" mkdir reports

:: Создание заглушек для static и templates
if not exist "static\.gitkeep" type nul > static\.gitkeep
if not exist "templates\.gitkeep" type nul > templates\.gitkeep
echo.

:: Проверка наличия основных файлов проекта
if not exist "main.py" (
    echo [ОШИБКА] Файл main.py не найден!
    pause
    exit /b 1
)

:: Запуск сборки PyInstaller
echo [INFO] Запуск сборки PyInstaller...
pyinstaller --name="PriceUpdater" ^
    --onefile ^
    --windowed ^
    --add-data "static;static" ^
    --add-data "templates;templates" ^
    --add-data "config.json;." ^
    --hidden-import="aiohttp" ^
    --hidden-import="aiogram" ^
    --hidden-import="fastapi" ^
    --hidden-import="uvicorn" ^
    --hidden-import="jinja2" ^
    --icon="icon.ico" ^
    main.py

if %errorlevel% neq 0 (
    echo [ОШИБКА] Ошибка при сборке PyInstaller!
    pause
    exit /b 1
)

:: Проверка успешности сборки
if not exist "dist\PriceUpdater.exe" (
    echo [ОШИБКА] Файл PriceUpdater.exe не найден после сборки!
    pause
    exit /b 1
)

echo [OK] PyInstaller сборка завершена успешно!
echo.

:: Создание директории для релиза
echo [INFO] Создание директории для релиза...
if exist "dist_release" rmdir /s /q dist_release
mkdir dist_release
mkdir dist_release\Windows

:: Копирование собранного приложения
copy dist\PriceUpdater.exe dist_release\Windows\ >nul
copy config.json dist_release\Windows\config.json.example >nul

:: Создание README файла
(
    echo Скопируйте config.json.example в config.json и настройте токены перед запуском!
    echo.
    echo Для запуска:
    echo 1. Настройте config.json
    echo 2. Запустите PriceUpdater.exe
    echo.
    echo Веб-интерфейс будет доступен по адресу: http://localhost:8080
) > dist_release\Windows\README.txt

:: Вывод результатов
echo.
echo ==========================================
echo СБОРКА ЗАВЕРШЕНА УСПЕШНО!
echo ==========================================
echo Результаты находятся в папке: dist_release\Windows\
echo.
echo Файлы:
dir /b dist_release\Windows\
echo.
echo Для установки:
echo   1. Скопируйте папку Windows в удобное место
echo   2. Настройте config.json (скопируйте из config.json.example)
echo   3. Запустите PriceUpdater.exe
echo.
echo Веб-интерфейс будет доступен по адресу: http://localhost:8080
echo.
pause
