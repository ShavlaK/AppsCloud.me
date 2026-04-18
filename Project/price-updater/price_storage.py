"""
Модуль для работы с локальным хранилищем цен (prices.json).
"""

import json
import os
from datetime import datetime
from typing import Dict, List, Optional


class PriceStorage:
    """Хранилище цен в формате JSON."""

    def __init__(self, file_path: str = "prices.json"):
        self.file_path = file_path
        self._ensure_file_exists()

    def _ensure_file_exists(self):
        """Создаёт файл хранилища если он не существует."""
        if not os.path.exists(self.file_path):
            self._save_data({"last_updated": None, "items": []})

    def load_prices(self) -> Dict:
        """Загружает цены из файла."""
        try:
            with open(self.file_path, "r", encoding="utf-8") as f:
                return json.load(f)
        except (json.JSONDecodeError, FileNotFoundError):
            return {"last_updated": None, "items": []}

    def save_prices(self, prices: List[Dict[str, any]]):
        """Сохраняет цены в файл."""
        data = {
            "last_updated": datetime.now().isoformat(),
            "items": prices
        }
        self._save_data(data)

    def _save_data(self, data: Dict):
        """Внутренний метод для сохранения данных."""
        with open(self.file_path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=4)

    def get_last_updated(self) -> Optional[str]:
        """Возвращает дату последнего обновления."""
        data = self.load_prices()
        return data.get("last_updated")

    def get_prices_count(self) -> int:
        """Возвращает количество сохранённых позиций."""
        data = self.load_prices()
        return len(data.get("items", []))
