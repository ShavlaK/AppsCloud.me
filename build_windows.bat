@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: ==========================================
:: СБОРКА УСТАНОВОЧНОГО ФАЙЛА (WINDOWS)
:: Полностью автоматическая сборка в EXE
:: Один клик - полная настройка и сборка
:: ==========================================

echo ==========================================
echo   СБОРКА УСТАНОВЩИКА PRICE UPDATER (Windows)
echo ==========================================
echo.

:: Переход в директорию проекта
cd /d "%~dp0"
echo [INFO] Рабочая директория: %CD%
echo.

:: Функция проверки команды
:check_command
where %1 >nul 2>nul
if %errorlevel% neq 0 (
    exit /b 1
)
exit /b 0

:: Установка Python
:install_python
echo [INFO] Python не найден или версия не подходит. Установка Python 3.11...
echo.

set PYTHON_INSTALL_DIR=%~dp0python_portable
if not exist "%PYTHON_INSTALL_DIR%" (
    mkdir "%PYTHON_INSTALL_DIR%"
)

:: Скачивание портативного Python
set PYTHON_URL=https://www.python.org/ftp/python/3.11.8/python-3.11.8-embed-amd64.zip
set PYTHON_ZIP=%TEMP%\python_embed.zip

echo [INFO] Загрузка Python 3.11...
powershell -Command "& {Invoke-WebRequest -Uri '%PYTHON_URL%' -OutFile '%PYTHON_ZIP%'}"

echo [INFO] Распаковка Python...
powershell -Command "& {Expand-Archive -Path '%PYTHON_ZIP%' -DestinationPath '%PYTHON_INSTALL_DIR%' -Force}"

:: Включение pip
echo import site >> "%PYTHON_INSTALL_DIR%\python311._pth"

:: Установка pip
echo [INFO] Установка pip...
set GET_PIP_URL=https://bootstrap.pypa.io/get-pip.py
powershell -Command "& {Invoke-WebRequest -Uri '%GET_PIP_URL%' -OutFile '%PYTHON_INSTALL_DIR%\get-pip.py'}"
"%PYTHON_INSTALL_DIR%\python.exe" "%PYTHON_INSTALL_DIR%\get-pip.py"

set PYTHON_CMD=%PYTHON_INSTALL_DIR%\python.exe
echo [OK] Python установлен в %PYTHON_INSTALL_DIR%
echo.
goto :check_python_done

:: Проверка версии Python
:check_python
where python >nul 2>nul
if %errorlevel% neq 0 (
    goto :install_python
)

for /f "tokens=2" %%i in ('python --version') do set FULL_VERSION=%%i
for /f "tokens=1,2 delims=." %%a in ("%FULL_VERSION%") do (
    set MAJOR=%%a
    set MINOR=%%b
)

:: Проверка на диапазон 3.9-3.12
if %MAJOR%==3 if %MINOR% GEQ 9 if %MINOR% LEQ 12 (
    echo [OK] Подходящая версия Python найдена: %FULL_VERSION%. Пропуск установки.
    set PYTHON_CMD=python
    goto :check_python_done
)

echo [WARN] Версия Python %FULL_VERSION% не подходит (требуется 3.9-3.12). Будет установлен Python 3.11.
goto :install_python

:check_python_done
echo.
echo ════════════════════════════════════════
echo   ШАГ 1: ПРОВЕРКА И НАСТРОЙКА ОКРУЖЕНИЯ
echo ════════════════════════════════════════
echo.

:: Проверка Git
where git >nul 2>nul
if %errorlevel% neq 0 (
    echo [WARN] Git не найден. Установка Git...
    echo [INFO] Загрузка Git installer...
    set GIT_URL=https://github.com/git-for-windows/git/releases/download/v2.45.0.windows.1/Git-2.45.0-64-bit.exe
    set GIT_INSTALLER=%TEMP%\git_installer.exe
    
    powershell -Command "& {Invoke-WebRequest -Uri '%GIT_URL%' -OutFile '%GIT_INSTALLER%'}"
    
    echo [INFO] Установка Git в тихом режиме...
    start /wait "" "%GIT_INSTALLER%" /VERYSILENT /NORESTART /NOCANCEL /SP- /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS
    
    :: Очистка установщика
    del "%GIT_INSTALLER%"
    
    :: Обновление PATH
    set "PATH=%PATH%;C:\Program Files\Git\bin"
    
    :: Проверка успешности установки
    where git >nul 2>nul
    if %errorlevel% neq 0 (
        echo [ОШИБКА] Не удалось установить Git автоматически.
        echo [INFO] Установите Git вручную с https://git-scm.com/download/win
        pause
        exit /b 1
    )
    echo [OK] Git успешно установлен.
) else (
    for /f "tokens=*" %%i in ('git --version') do set GIT_VER=%%i
    echo [OK] Git уже установлен: !GIT_VER!. Пропуск установки.
)
echo.

:: Проверка Visual Studio Build Tools (необходимы для компиляции некоторых пакетов)
echo [INFO] Проверка Visual Studio Build Tools...
set "VS_INSTALLED=0"
if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vs_installershell.exe" (
    echo [OK] Visual Studio Installer найден. Проверка компонентов...
    set "VS_INSTALLED=1"
)

if %VS_INSTALLED%==0 (
    where cl.exe >nul 2>nul
    if %errorlevel% equ 0 (
        echo [OK] Visual Studio Build Tools уже установлены (cl.exe найден).
        set "VS_INSTALLED=1"
    )
)

if %VS_INSTALLED%==0 (
    echo [WARN] Visual Studio Build Tools не найдены. Установка...
    echo [INFO] Загрузка VS Build Tools installer...
    set VS_URL=https://aka.ms/vs/17/release/vs_buildtools.exe
    set VS_INSTALLER=%TEMP%\vs_buildtools.exe
    
    powershell -Command "& {Invoke-WebRequest -Uri '%VS_URL%' -OutFile '%VS_INSTALLER%'}"
    
    echo [INFO] Установка Visual Studio Build Tools в тихом режиме...
    echo [INFO] Это может занять несколько минут...
    start /wait "" "%VS_INSTALLER%" --quiet --wait --norestart --nocache ^
        --installPath "%ProgramFiles(x86)%\Microsoft Visual Studio\2022\BuildTools" ^
        --add Microsoft.VisualStudio.Workload.VCTools ^
        --includeRecommended
    
    :: Очистка установщика
    del "%VS_INSTALLER%"
    
    :: Обновление PATH для текущей сессии
    set "PATH=%PATH%;%ProgramFiles(x86)%\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\*\bin\Hostx64\x64"
    
    echo [OK] Visual Studio Build Tools установлены.
) else (
    echo [OK] Visual Studio Build Tools уже установлены. Пропуск установки.
)
echo.

echo.
echo ════════════════════════════════════════
echo   ШАГ 2: СОЗДАНИЕ ВИРТУАЛЬНОГО ОКРУЖЕНИЯ
echo ════════════════════════════════════════
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
%PYTHON_CMD% -m venv venv
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
%PYTHON_CMD% -m pip install --upgrade pip --quiet
echo.

echo.
echo ════════════════════════════════════════
echo   ШАГ 3: УСТАНОВКА ЗАВИСИМОСТЕЙ
echo ════════════════════════════════════════
echo.

:: Установка зависимостей
echo [INFO] Установка зависимостей из requirements.txt...
if exist "requirements.txt" (
    :: Установка pydantic с совместимой версией
    echo [INFO] Установка совместимых версий pydantic...
    %PYTHON_CMD% -m pip install "pydantic>=2.5,<2.7" "pydantic-core>=2.14,<2.15" --quiet
    
    echo [INFO] Установка зависимостей из requirements.txt...
    %PYTHON_CMD% -m pip install -r requirements.txt --quiet
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

:: Установка инструментов для сборки
echo [INFO] Установка инструментов сборки (PyInstaller, dmgbuild)...
%PYTHON_CMD% -m pip install pyinstaller --quiet

:: Проверка необходимости dmgbuild для создания архива
echo [INFO] Установка дополнительных инструментов...
%PYTHON_CMD% -m pip install zipapp --quiet 2>nul || true
echo.

echo.
echo ════════════════════════════════════════
echo   ШАГ 4: ПОДГОТОВКА ФАЙЛОВ ПРОЕКТА
echo ════════════════════════════════════════
echo.

:: Создание необходимых директорий
echo [INFO] Создание необходимых директорий...
if not exist "static" mkdir static
if not exist "templates" mkdir templates
if not exist "data" mkdir data
if not exist "logs" mkdir logs
if not exist "reports" mkdir reports
if not exist "sessions" mkdir sessions

:: Создание заглушек для static и templates
if not exist "static\.gitkeep" type nul > static\.gitkeep
if not exist "templates\.gitkeep" type nul > templates\.gitkeep

:: Копирование config.json если нет
if not exist "config.json" (
    echo [INFO] Копирование config.json.example в config.json...
    copy config.json.example config.json >nul
    echo [WARN] Не забудьте настроить config.json перед запуском!
)
echo.

:: Проверка наличия основных файлов проекта
if not exist "main.py" (
    echo [ОШИБКА] Файл main.py не найден!
    pause
    exit /b 1
)
echo.

echo.
echo ════════════════════════════════════════
echo   ШАГ 5: СБОРКА PYINSTALLER
echo ════════════════════════════════════════
echo.

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

echo.
echo ════════════════════════════════════════
echo   ШАГ 6: ПОДГОТОВКА ДИСТРИБУТИВА
echo ════════════════════════════════════════
echo.

:: Создание директории для релиза
echo [INFO] Создание директории для релиза...
if exist "dist_release" rmdir /s /q dist_release
mkdir dist_release
mkdir dist_release\Windows

:: Копирование собранного приложения
copy dist\PriceUpdater.exe dist_release\Windows\ >nul
copy config.json dist_release\Windows\config.json.example >nul
copy requirements.txt dist_release\Windows\ >nul 2>nul || true

:: Создание ZIP архива с дистрибутивом
echo [INFO] Создание ZIP архива...
powershell -Command "Compress-Archive -Path 'dist_release\Windows\*' -DestinationPath 'dist_release\PriceUpdater_Windows.zip' -Force"
echo [OK] ZIP архив создан: dist_release\PriceUpdater_Windows.zip

:: Создание README файла
(
    echo =========================================
    echo Price Updater - Установочный пакет
    echo =========================================
    echo.
    echo Файлы в папке:
    echo   - PriceUpdater.exe - исполняемый файл приложения
    echo   - config.json.example - пример конфигурации
    echo   - README.txt - этот файл
    echo.
    echo ИНСТРУКЦИЯ ПО ЗАПУСКУ:
    echo =====================
    echo 1. Скопируйте config.json.example в config.json
    echo 2. Отредактируйте config.json, указав ваши токены:
    echo    - source_bot_token - токен бота-источника
    echo    - channel_bot_token - токен вашего бота для канала
    echo    - channel_id - ID Telegram-канала
    echo    - markup_percent - процент наценки
    echo 3. Запустите PriceUpdater.exe
    echo.
    echo Веб-интерфейс будет доступен по адресу:
    echo http://localhost:8080
    echo.
    echo =========================================
) > dist_release\Windows\README.txt

:: Вывод результатов
echo.
echo ==========================================
echo ✅ СБОРКА ЗАВЕРШЕНА УСПЕШНО!
echo ==========================================
echo.
echo 📦 Результаты находятся в папке: dist_release\Windows\
echo.
echo Файлы:
dir /b dist_release\Windows\
echo.
echo 📋 Для запуска:
echo   1. Скопируйте папку Windows в удобное место
echo   2. Настройте config.json (скопируйте из config.json.example)
echo   3. Запустите PriceUpdater.exe
echo.
echo 🌐 Веб-интерфейс будет доступен по адресу: http://localhost:8080
echo.
pause
