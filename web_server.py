"""
FastAPI веб-сервер для управления Price Updater.
Предоставляет REST API + веб-интерфейс.
"""

import json
import logging
import os
from contextlib import asynccontextmanager
from datetime import datetime
from typing import Optional

from fastapi import FastAPI, HTTPException, Request, UploadFile, File
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.templating import Jinja2Templates
from pydantic import BaseModel

from price_database import PriceDatabase
from report_generator import ReportGenerator

logger = logging.getLogger(__name__)


# ============================================================
# Глобальные объекты (устанавливаются из main.py)
# ============================================================
price_updater = None  # PriceUpdater instance
scheduler = None      # APScheduler instance
report_gen = None     # ReportGenerator instance


def set_global_objects(updater, sched):
    """Устанавливает глобальные объекты для веб-сервера."""
    global price_updater, scheduler, report_gen
    price_updater = updater
    scheduler = sched
    if updater and hasattr(updater, 'db'):
        report_gen = ReportGenerator(updater.db)


# ============================================================
# Pydantic модели для API
# ============================================================

class ConfigUpdate(BaseModel):
    mode: Optional[str] = None
    source_bot_token: Optional[str] = None
    your_bot_token: Optional[str] = None
    channel_id: Optional[str] = None
    price_markup: Optional[int] = None
    schedule: Optional[dict] = None
    excel: Optional[dict] = None
    user_api: Optional[dict] = None


class ModeUpdate(BaseModel):
    mode: str  # "auto" или "manual"


class ManualUpdateRequest(BaseModel):
    force: bool = True


class ReportRequest(BaseModel):
    year: Optional[int] = None
    month: Optional[int] = None


class LogRequest(BaseModel):
    log_file: str = "price_updater.log"
    lines: int = 100


# ============================================================
# Lifespan
# ============================================================

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Веб-сервер запущен")
    yield
    logger.info("Веб-сервер остановлен")


# ============================================================
# Приложение
# ============================================================

app = FastAPI(
    title="Price Updater Dashboard",
    description="Панель управления Price Updater",
    version="1.0.0",
    lifespan=lifespan
)

# Шаблоны
templates_dir = os.path.join(os.path.dirname(__file__), "templates")
templates = Jinja2Templates(directory=templates_dir)


# ============================================================
# Страницы
# ============================================================

@app.get("/", response_class=HTMLResponse)
async def dashboard(request: Request):
    """Главная страница панели управления."""
    return templates.TemplateResponse("index.html", {"request": request})


# ============================================================
# API: Статус
# ============================================================

@app.get("/api/status")
async def get_status():
    """Возвращает текущий статус системы."""
    db = PriceDatabase()
    stats = db.get_storage_stats()

    jobs = []
    if scheduler:
        for job in scheduler.get_jobs():
            jobs.append({
                "id": job.id,
                "next_run_time": str(job.next_run_time) if job.next_run_time else None
            })

    return {
        "running": scheduler is not None and scheduler.running,
        "scheduler_jobs": jobs,
        "database": stats,
        "timestamp": datetime.now().isoformat()
    }


# ============================================================
# API: Конфигурация
# ============================================================

@app.get("/api/config")
async def get_config():
    """Возвращает текущую конфигурацию (без токенов)."""
    try:
        with open("config.json", "r", encoding="utf-8") as f:
            config = json.load(f)

        # Скрываем токены
        config["source_bot_token"] = mask_token(config.get("source_bot_token"))
        config["your_bot_token"] = mask_token(config.get("your_bot_token"))

        if config.get("user_api"):
            config["user_api"]["user_api_hash"] = mask_token(
                config["user_api"].get("user_api_hash")
            )

        return config

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/config")
async def update_config(data: ConfigUpdate):
    """Обновляет конфигурацию."""
    try:
        with open("config.json", "r", encoding="utf-8") as f:
            config = json.load(f)

        # Обновляем только переданные поля
        if data.source_bot_token and not data.source_bot_token.startswith("****"):
            config["source_bot_token"] = data.source_bot_token
        if data.your_bot_token and not data.your_bot_token.startswith("****"):
            config["your_bot_token"] = data.your_bot_token
        if data.channel_id:
            config["channel_id"] = data.channel_id
        if data.price_markup is not None:
            config["price_markup"] = data.price_markup
        if data.schedule:
            config["schedule"] = data.schedule
        if data.user_api:
            if "user_api" not in config:
                config["user_api"] = {}
            for key, value in data.user_api.items():
                if value and not str(value).startswith("****"):
                    config["user_api"][key] = value

        with open("config.json", "w", encoding="utf-8") as f:
            json.dump(config, f, ensure_ascii=False, indent=4)

        logger.info("Конфигурация обновлена")
        return {"status": "ok", "message": "Конфигурация сохранена"}

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================
# API: Ручное обновление прайса
# ============================================================

@app.post("/api/update")
async def manual_update(data: ManualUpdateRequest):
    """Запускает ручное обновление прайса."""
    if not price_updater:
        raise HTTPException(status_code=500, detail="PriceUpdater не инициализирован")

    try:
        import asyncio
        asyncio.create_task(price_updater.update_price())
        return {"status": "ok", "message": "Обновление запущено"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================
# API: Режим работы
# ============================================================

@app.get("/api/mode")
async def get_mode():
    """Возвращает текущий режим работы."""
    try:
        with open("config.json", "r", encoding="utf-8") as f:
            config = json.load(f)
        return {"mode": config.get("mode", "manual")}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/mode")
async def set_mode(data: ModeUpdate):
    """Переключает режим работы (auto/manual)."""
    if data.mode not in ("auto", "manual"):
        raise HTTPException(status_code=400, detail="Режим должен быть 'auto' или 'manual'")

    try:
        with open("config.json", "r", encoding="utf-8") as f:
            config = json.load(f)

        config["mode"] = data.mode

        with open("config.json", "w", encoding="utf-8") as f:
            json.dump(config, f, ensure_ascii=False, indent=4)

        logger.info(f"Режим изменён на: {data.mode}")
        return {"status": "ok", "mode": data.mode}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================
# API: Загрузка Excel файла
# ============================================================

@app.post("/api/upload")
async def upload_excel(file: UploadFile = File(...)):
    """Загружает Excel файл прайс-листа."""
    if not file.filename:
        raise HTTPException(status_code=400, detail="Файл не выбран")

    # Разрешаем только .xlsx
    if not file.filename.endswith(".xlsx"):
        raise HTTPException(status_code=400, detail="Только .xlsx файлы")

    upload_dir = "uploads"
    os.makedirs(upload_dir, exist_ok=True)

    filepath = os.path.join(upload_dir, file.filename)

    try:
        with open(filepath, "wb") as f:
            content = await file.read()
            f.write(content)

        logger.info(f"Excel файл загружен: {filepath} ({len(content)} байт)")

        # Парсим файл
        from excel_parser import ExcelPriceParser
        parser = ExcelPriceParser()
        prices = parser.parse_file(filepath)

        return {
            "status": "ok",
            "filename": file.filename,
            "items_count": len(prices),
            "filepath": filepath,
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Ошибка парсинга: {str(e)}")


@app.post("/api/upload/process")
async def process_uploaded_excel(data: ManualUpdateRequest):
    """Парсит загруженный Excel файл и обновляет прайс."""
    if not price_updater:
        raise HTTPException(status_code=500, detail="PriceUpdater не инициализирован")

    # Ищем последний загруженный файл
    upload_dir = "uploads"
    if not os.path.exists(upload_dir):
        raise HTTPException(status_code=404, detail="Нет загрученных файлов")

    files = [f for f in os.listdir(upload_dir) if f.endswith(".xlsx")]
    if not files:
        raise HTTPException(status_code=404, detail="Нет .xlsx файлов")

    # Берём самый свежий
    latest = max(files, key=lambda f: os.path.getmtime(os.path.join(upload_dir, f)))
    filepath = os.path.join(upload_dir, latest)

    try:
        from excel_parser import ExcelPriceParser

        parser = ExcelPriceParser()
        prices = parser.parse_file(filepath)

        markup = price_updater.config.get("price_markup", 0)
        prices = parser.apply_markup(prices, markup)

        # Сохраняем
        price_updater.storage.save_prices(prices)
        snapshot_id = price_updater.db.save_snapshot(prices, markup)
        logger.info(f"Снимок #{snapshot_id} из Excel: {len(prices)} позиций")

        # Публикуем
        if price_updater.message_id:
            success = await price_updater.publisher.update_price_list(
                price_updater.message_id, prices
            )
            if success:
                logger.info("Сообщение обновлено из Excel")
        else:
            price_updater.message_id = await price_updater.publisher.send_price_list(prices)
            price_updater._save_message_id(price_updater.message_id)
            logger.info(f"Создано сообщение из Excel, ID: {price_updater.message_id}")

        return {
            "status": "ok",
            "message": f"Обновлено {len(prices)} позиций из {latest}",
            "snapshot_id": snapshot_id,
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Ошибка обработки: {str(e)}")


# ============================================================
# API: Планировщик
# ============================================================

@app.post("/api/scheduler/start")
async def start_scheduler():
    """Запускает планировщик."""
    if scheduler:
        scheduler.start()
        return {"status": "ok", "message": "Планировщик запущен"}
    raise HTTPException(status_code=500, detail="Планировщик не инициализирован")


@app.post("/api/scheduler/stop")
async def stop_scheduler():
    """Останавливает планировщик."""
    if scheduler:
        scheduler.pause()
        return {"status": "ok", "message": "Планировщик остановлен"}
    raise HTTPException(status_code=500, detail="Планировщик не инициализирован")


# ============================================================
# API: Отчёты
# ============================================================

@app.post("/api/report")
async def generate_report(data: ReportRequest):
    """Генерирует отчёт за месяц."""
    if not price_updater:
        raise HTTPException(status_code=500, detail="PriceUpdater не инициализирован")

    try:
        report_text = await price_updater.generate_report(data.year, data.month)

        if not report_text:
            return {"status": "warning", "message": "Нет данных для отчёта"}

        return {"status": "ok", "report": report_text}

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/reports")
async def list_reports():
    """Список доступных отчётов."""
    reports_dir = "reports"
    if not os.path.exists(reports_dir):
        return {"reports": []}

    files = [f for f in os.listdir(reports_dir) if f.endswith(".json")]
    files.sort(reverse=True)

    reports = []
    for filename in files:
        filepath = os.path.join(reports_dir, filename)
        try:
            with open(filepath, "r", encoding="utf-8") as f:
                data = json.load(f)
            reports.append({
                "filename": filename,
                "period": f"{data.get('period_start', '?')} — {data.get('period_end', '?')}",
                "generated_at": data.get("generated_at", "?"),
                "summary": data.get("summary", {})
            })
        except Exception:
            reports.append({"filename": filename, "error": "Не удалось прочитать"})

    return {"reports": reports}


@app.get("/api/reports/{filename}")
async def get_report(filename: str):
    """Возвращает конкретный отчёт."""
    filepath = os.path.join("reports", filename)
    if not os.path.exists(filepath):
        raise HTTPException(status_code=404, detail="Отчёт не найден")

    return FileResponse(filepath, media_type="application/json")


# ============================================================
# API: Аналитика и графики
# ============================================================

@app.get("/api/analytics")
async def get_analytics(product_name: Optional[str] = None):
    """Получает всю аналитику для графиков: тренды, дни недели, месяцы."""
    if not report_gen:
        raise HTTPException(status_code=500, detail="ReportGenerator не инициализирован")
    
    try:
        stats = report_gen.get_all_stats(product_name)
        return {"status": "ok", "data": stats}
    except Exception as e:
        logger.error(f"Error getting analytics: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/analytics/trend")
async def get_trend(days: int = 30, product_name: Optional[str] = None):
    """Динамика цен за последние N дней."""
    if not report_gen:
        raise HTTPException(status_code=500, detail="ReportGenerator не инициализирован")
    
    try:
        data = report_gen.generate_price_trend_report(product_name, days)
        return data
    except Exception as e:
        logger.error(f"Error getting trend: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/analytics/day-of-week")
async def get_day_of_week(weeks: int = 8, product_name: Optional[str] = None):
    """Анализ цен по дням недели."""
    if not report_gen:
        raise HTTPException(status_code=500, detail="ReportGenerator не инициализирован")
    
    try:
        data = report_gen.generate_day_of_week_analysis(product_name, weeks)
        return data
    except Exception as e:
        logger.error(f"Error getting day of week analysis: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/analytics/monthly")
async def get_monthly(months: int = 3, product_name: Optional[str] = None):
    """Анализ волатильности по месяцам."""
    if not report_gen:
        raise HTTPException(status_code=500, detail="ReportGenerator не инициализирован")
    
    try:
        data = report_gen.generate_monthly_volatility(product_name, months)
        return data
    except Exception as e:
        logger.error(f"Error getting monthly volatility: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================
# API: Логи
# ============================================================

@app.get("/api/logs")
async def get_logs(log_file: str = "price_updater.log", lines: int = 100):
    """Возвращает содержимое лог-файла."""
    allowed_files = ["price_updater.log", "errors.log", "scheduler.log", "telegram.log"]
    if log_file not in allowed_files:
        raise HTTPException(status_code=400, detail="Недопустимый файл лога")

    filepath = os.path.join("logs", log_file)
    if not os.path.exists(filepath):
        return {"content": "Лог-файл ещё не создан"}

    try:
        with open(filepath, "r", encoding="utf-8") as f:
            all_lines = f.readlines()

        # Последние N строк
        recent_lines = all_lines[-lines:]
        content = "".join(recent_lines)

        return {
            "file": log_file,
            "total_lines": len(all_lines),
            "showing": len(recent_lines),
            "content": content
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/logs/errors")
async def get_errors(lines: int = 50):
    """Быстрый доступ к ошибкам."""
    return await get_logs("errors.log", lines)


# ============================================================
# Утилиты
# ============================================================

def mask_token(token: Optional[str]) -> str:
    """Маскирует токен для безопасности."""
    if not token:
        return ""
    if len(token) < 10:
        return "****"
    return f"{token[:4]}****{token[-4:]}"
