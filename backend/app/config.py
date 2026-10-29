"""App settings. Secrets only dinhi (backend .env), wala sa Flutter."""
from pathlib import Path
import os

from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parents[1]
load_dotenv(BASE_DIR / ".env")  # existing env vars win (important for pytest)


def _bool(name: str, default: bool = False) -> bool:
    return os.getenv(name, str(default)).strip().lower() in ("1", "true", "yes", "on")


class Settings:
    database_url: str = os.getenv(
        "DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/parkkeys_db"
    )
    jwt_secret: str = os.getenv("JWT_SECRET", "dev-only-secret-change-me")
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = int(os.getenv("JWT_EXPIRE_MINUTES", "720"))
    cors_origins: list[str] = [
        origin.strip()
        for origin in os.getenv("CORS_ORIGINS", "*").split(",")
        if origin.strip()
    ]
    ml_enabled: bool = _bool("ML_ENABLED", True)
    ml_refresh_minutes: int = int(os.getenv("ML_REFRESH_MINUTES", "30"))
    bcrypt_rounds: int = 12


settings = Settings()
