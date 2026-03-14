import os
from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent.parent


def _as_bool(value: str | None, default: bool = False) -> bool:
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


def _resolve_upload_folder(value: str | None) -> str:
    raw = (value or "").strip()
    if not raw:
        return str(BASE_DIR / "uploads")
    if os.path.isabs(raw):
        return raw
    return str((BASE_DIR / raw).resolve())


class BaseConfig:
    DEBUG = False
    TESTING = False


    JWT_ACCESS_TOKEN_EXPIRES = int(os.getenv("JWT_ACCESS_TOKEN_EXPIRES", str(60 * 60 * 24)))
    MAX_CONTENT_LENGTH = int(os.getenv("MAX_CONTENT_LENGTH", str(10 * 1024 * 1024)))
    NISHAB_DUMMY = float(os.getenv("NISHAB_DUMMY", "85000000"))
    UPLOAD_FOLDER = _resolve_upload_folder(os.getenv("UPLOAD_FOLDER"))
    MONGODB_URI = os.getenv("MONGODB_URI", "mongodb://localhost:27017")
    DB_NAME = os.getenv("DB_NAME", "averroes_db")
    SESSION_COOKIE_HTTPONLY = True
    SESSION_COOKIE_SAMESITE = "Lax"
    SESSION_COOKIE_SECURE = False
    REMEMBER_COOKIE_HTTPONLY = True
    REMEMBER_COOKIE_SECURE = False
    WTF_CSRF_TIME_LIMIT = None

    AUTO_CREATE_DB = False
    SEED_ON_STARTUP = False
    REQUIRE_ENV_SECRETS = False
    USE_PROXY_FIX = _as_bool(os.getenv("USE_PROXY_FIX"), default=True)
    PREFERRED_URL_SCHEME = os.getenv("PREFERRED_URL_SCHEME", "https")
    NEWS_SCRAPER_ENABLED = _as_bool(os.getenv("NEWS_SCRAPER_ENABLED"), default=True)
    NEWS_SCRAPER_INTERVAL_SECONDS = int(os.getenv("NEWS_SCRAPER_INTERVAL_SECONDS", "21600"))
    NEWS_SCRAPER_LIMIT = int(os.getenv("NEWS_SCRAPER_LIMIT", "20"))
    NEWS_SCRAPER_RUN_ON_STARTUP = _as_bool(os.getenv("NEWS_SCRAPER_RUN_ON_STARTUP"), default=True)
    PASSWORD_RESET_OTP_EXPIRES_SECONDS = int(os.getenv("PASSWORD_RESET_OTP_EXPIRES_SECONDS", "300"))
    PASSWORD_RESET_DEBUG_OTP_IN_RESPONSE = _as_bool(os.getenv("PASSWORD_RESET_DEBUG_OTP_IN_RESPONSE"), default=False)
    PUSTAKA_SIGNED_URL_EXPIRES_SECONDS = int(os.getenv("PUSTAKA_SIGNED_URL_EXPIRES_SECONDS", "600"))
    MIDTRANS_SERVER_KEY = os.getenv("MIDTRANS_SERVER_KEY", "SB-Mid-server-x-placeholder")
    MIDTRANS_CLIENT_KEY = os.getenv("MIDTRANS_CLIENT_KEY", "SB-Mid-client-x-placeholder")
    MIDTRANS_IS_PRODUCTION = _as_bool(os.getenv("MIDTRANS_IS_PRODUCTION"), default=False)
    GOOGLE_OAUTH_CLIENT_IDS = os.getenv("GOOGLE_OAUTH_CLIENT_IDS", "")

    # Flask-Mail Configuration
    MAIL_SERVER = os.getenv("MAIL_SERVER", "smtp.gmail.com")
    MAIL_PORT = int(os.getenv("MAIL_PORT", "587"))
    MAIL_USE_TLS = _as_bool(os.getenv("MAIL_USE_TLS"), default=True)
    MAIL_USERNAME = os.getenv("MAIL_USERNAME")
    MAIL_PASSWORD = os.getenv("MAIL_PASSWORD")
    MAIL_DEFAULT_SENDER = os.getenv("MAIL_DEFAULT_SENDER", MAIL_USERNAME)

    NEWS_SCRAPER_FEEDS = [
        feed.strip()
        for feed in os.getenv(
            "NEWS_SCRAPER_FEEDS",
            "https://cryptowave.co.id/",
        ).split(",")
        if feed.strip()
    ]

    SECRET_KEY = os.getenv("SECRET_KEY")
    JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY")

    @classmethod
    def validate(cls) -> None:
        if not cls.REQUIRE_ENV_SECRETS:
            return
        required = {
            "SECRET_KEY": cls.SECRET_KEY,
            "JWT_SECRET_KEY": cls.JWT_SECRET_KEY,
            "MONGODB_URI": os.getenv("MONGODB_URI"),
            "DB_NAME": os.getenv("DB_NAME"),
        }
        missing = [name for name, value in required.items() if not value]
        if missing:
            joined = ", ".join(missing)
            raise RuntimeError(f"Missing required environment variables for production: {joined}")

        weak_secret_tokens = {
            "ganti-dengan-secret-kuat",
            "ganti-dengan-jwt-secret-kuat",
            "ganti-dengan-secret-produksi",
            "ganti-jwt-secret-produksi",
            "dev-insecure-secret-key",
            "dev-insecure-jwt-secret",
        }
        for key in ("SECRET_KEY", "JWT_SECRET_KEY"):
            value = str(required[key]).strip()
            if len(value) < 32 or value in weak_secret_tokens or value.startswith("ganti-"):
                raise RuntimeError(
                    f"{key} is too weak for production. Use a random value with at least 32 characters."
                )


class DevelopmentConfig(BaseConfig):
    DEBUG = True
    SECRET_KEY = os.getenv("SECRET_KEY", "dev-insecure-secret-key")
    JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY", "dev-insecure-jwt-secret")
    AUTO_CREATE_DB = True
    SEED_ON_STARTUP = True
    REQUIRE_ENV_SECRETS = False
    PREFERRED_URL_SCHEME = "http"
    PASSWORD_RESET_DEBUG_OTP_IN_RESPONSE = _as_bool(
        os.getenv("PASSWORD_RESET_DEBUG_OTP_IN_RESPONSE"), default=True
    )


class ProductionConfig(BaseConfig):
    SESSION_COOKIE_SECURE = True
    REMEMBER_COOKIE_SECURE = True
    REQUIRE_ENV_SECRETS = True
    AUTO_CREATE_DB = False
    SEED_ON_STARTUP = False
    DEBUG = False
    TESTING = False
