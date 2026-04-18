# -*- mode: python ; coding: utf-8 -*-
"""
PyInstaller spec файл для Windows.
Создаёт standalone .exe файл.

Использование:
    pyinstaller build_scripts/build_windows.spec
"""

import os
import sys
from PyInstaller.utils.hooks import collect_data_files

block_cipher = None

# Собираем шаблоны
datas = [
    ('templates', 'templates'),
    ('config.json', '.'),
    ('README.md', '.'),
]

a = Analysis(
    ['main.py'],
    pathex=[],
    binaries=[],
    datas=datas,
    hiddenimports=[
        'apscheduler',
        'apscheduler.schedulers.asyncio',
        'apscheduler.triggers.cron',
        'uvicorn',
        'uvicorn.logging',
        'uvicorn.loops',
        'uvicorn.loops.auto',
        'uvicorn.protocols',
        'uvicorn.protocols.http',
        'uvicorn.protocols.http.auto',
        'uvicorn.protocols.websockets',
        'uvicorn.protocols.websockets.auto',
        'jinja2',
        'telethon',
        'aiohttp',
        'aiogram',
        'fastapi',
        'price_database',
        'report_generator',
        'telegram_parser',
        'telegram_channel',
        'price_storage',
        'logger_setup',
        'web_server',
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        'tkinter',
        'matplotlib',
        'scipy',
        'numpy',
    ],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name='PriceUpdater',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=None,  # Добавьте: icon='icon.ico' если есть
)
