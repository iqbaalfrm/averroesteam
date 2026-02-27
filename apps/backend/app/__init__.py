import os

from flask import Flask
from dotenv import load_dotenv
from werkzeug.middleware.proxy_fix import ProxyFix

from .admin.routes import admin_bp
from .api.auth import auth_bp
from .api.berita import berita_bp
from .api.diskusi import diskusi_bp
from .api.edukasi import edukasi_bp
from .api.portofolio import portofolio_bp
from .api.pustaka import pustaka_admin_bp, pustaka_bp
from .api.screener import screener_bp
from .api.zakat import zakat_bp
from .config import DevelopmentConfig, ProductionConfig
from .extensions import csrf, db, jwt, migrate
from .seed import seed_data
from .services.berita_scraper import start_berita_scheduler


def _resolve_config(env_name: str):
    env = (env_name or "").strip().lower()
    if env in {"prod", "production"}:
        return ProductionConfig
    return DevelopmentConfig


def create_app() -> Flask:
    load_dotenv()
    app = Flask(__name__)
    config_class = _resolve_config(os.getenv("APP_ENV", "development"))
    app.config.from_object(config_class)
    config_class.validate()

    os.makedirs(app.config["UPLOAD_FOLDER"], exist_ok=True)

    db.init_app(app)
    migrate.init_app(app, db)
    jwt.init_app(app)
    csrf.init_app(app)

    if app.config.get("USE_PROXY_FIX", True):
        app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_proto=1, x_host=1, x_port=1)

    app.register_blueprint(auth_bp)
    app.register_blueprint(edukasi_bp)
    app.register_blueprint(portofolio_bp)
    app.register_blueprint(zakat_bp)
    app.register_blueprint(screener_bp)
    app.register_blueprint(diskusi_bp)
    app.register_blueprint(berita_bp)
    app.register_blueprint(pustaka_bp)
    app.register_blueprint(pustaka_admin_bp)
    app.register_blueprint(admin_bp)

    # API uses JWT header token, so CSRF is enforced only for admin forms.
    csrf.exempt(auth_bp)
    csrf.exempt(edukasi_bp)
    csrf.exempt(portofolio_bp)
    csrf.exempt(zakat_bp)
    csrf.exempt(screener_bp)
    csrf.exempt(diskusi_bp)
    csrf.exempt(berita_bp)
    csrf.exempt(pustaka_bp)
    csrf.exempt(pustaka_admin_bp)

    with app.app_context():
        if app.config.get("AUTO_CREATE_DB"):
            db.create_all()
        if app.config.get("SEED_ON_STARTUP"):
            seed_data()

    # Debug reloader starts app twice; run scheduler only in effective process.
    is_reloader_process = os.environ.get("WERKZEUG_RUN_MAIN") == "true"
    if (not app.debug) or is_reloader_process:
        start_berita_scheduler(app)

    @app.get("/")
    def index():
        return {
            "status": "success",
            "message": "Backend Averroes Flask aktif",
            "data": {"admin": "/admin", "api": "/api"},
        }

    return app
