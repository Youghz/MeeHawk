from pathlib import Path

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    PROJECT_ROOT: Path = Path(__file__).resolve().parents[3]
    UPLOAD_DIR: Path = Path(__file__).resolve().parents[3] / "data" / "uploads"
    RESULTS_DIR: Path = Path(__file__).resolve().parents[3] / "data" / "results"
    VIDEOS_DIR: Path = Path(__file__).resolve().parents[3] / "videos"
    ALLOWED_EXTENSIONS: set[str] = {".mp4", ".avi", ".mov", ".mkv"}
    MAX_FILE_SIZE: int = 500 * 1024 * 1024  # 500MB
    CORS_ORIGINS: list[str] = ["http://localhost:5173"]


settings = Settings()

# Ensure directories exist
settings.UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
settings.RESULTS_DIR.mkdir(parents=True, exist_ok=True)
