"""
Скрипт сборки .app для macOS через py2app.

Использование:
    python build_scripts/build_macos.py
"""


from setuptools import setup

APP = ['main.py']
DATA_FILES = [
    ('templates', ['templates/index.html']),
    ('.', ['config.json', 'README.md']),
]

OPTIONS = {
    'argv_emulation': False,
    'plist': {
        'CFBundleName': 'Price Updater',
        'CFBundleDisplayName': 'Price Updater',
        'CFBundleVersion': '1.0.0',
        'CFBundleShortVersionString': '1.0.0',
        'CFBundleIdentifier': 'com.priceupdater.app',
        'NSHumanReadableCopyright': 'MIT License',
    },
    'packages': [
        'apscheduler',
        'uvicorn',
        'jinja2',
        'telethon',
        'aiohttp',
        'fastapi',
    ],
    'includes': [
        'price_database',
        'report_generator',
        'telegram_parser',
        'telegram_channel',
        'price_storage',
        'logger_setup',
        'web_server',
    ],
    'excludes': [
        'tkinter',
        'matplotlib',
        'scipy',
        'numpy',
    ],
}

if __name__ == '__main__':
    setup(
        app=APP,
        data_files=DATA_FILES,
        options={'py2app': OPTIONS},
        setup_requires=['py2app'],
    )
