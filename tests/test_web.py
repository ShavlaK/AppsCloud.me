"""
Тесты для веб-сервера (FastAPI).
"""


import pytest
from fastapi.testclient import TestClient

from web_server import app


class TestWebServer:
    """Тесты веб-сервера."""

    @pytest.fixture
    def client(self):
        return TestClient(app)

    def test_dashboard_page(self, client):
        """Главная страница загружается."""
        response = client.get("/")
        assert response.status_code == 200
        assert "Price Updater" in response.text

    def test_api_status(self, client):
        """API статуса работает."""
        response = client.get("/api/status")
        assert response.status_code == 200

        data = response.json()
        assert "running" in data
        assert "database" in data

    def test_api_config_get(self, client, mock_config):
        """Получение конфигурации."""
        response = client.get("/api/config")
        assert response.status_code == 200

        data = response.json()
        assert "source_bot_token" in data
        assert "****" in data["source_bot_token"]  # Токен замаскирован

    def test_api_config_post(self, client, mock_config):
        """Обновление конфигурации."""
        response = client.post("/api/config", json={
            "channel_id": "@new_channel",
            "price_markup": 200
        })

        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "ok"

    def test_api_logs(self, client, temp_dir):
        """Получение логов."""
        import os
        os.makedirs("logs", exist_ok=True)
        with open("logs/price_updater.log", "w") as f:
            f.write("Test log line 1\nTest log line 2\n")

        response = client.get("/api/logs?log_file=price_updater.log&lines=10")
        assert response.status_code == 200

        data = response.json()
        assert "content" in data

    def test_api_logs_invalid_file(self, client):
        """Запрос несуществующего лога."""
        response = client.get("/api/logs?log_file=hack.log")
        assert response.status_code == 400

    def test_api_reports_empty(self, client):
        """Список отчётов пуст."""
        response = client.get("/api/reports")
        assert response.status_code == 200

        data = response.json()
        assert "reports" in data

    def test_mask_token(self):
        """Маскировка токенов."""
        from web_server import mask_token

        assert mask_token(None) == ""
        assert mask_token("short") == "****"

        token = "123456:ABC-DEF123456"
        masked = mask_token(token)
        assert masked.startswith("1234")
        assert masked.endswith("3456")
        assert "****" in masked
