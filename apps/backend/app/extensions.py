from flask_jwt_extended import JWTManager
from flask_wtf.csrf import CSRFProtect
from flask_mail import Mail
from pymongo import MongoClient


class MongoExtension:
    def __init__(self):
        self.client = None
        self.db = None

    def init_app(self, app):
        uri = app.config.get("MONGODB_URI")
        db_name = app.config.get("DB_NAME")
        if not uri or not db_name:
            raise RuntimeError("MONGODB_URI or DB_NAME is missing in config")
        self.client = MongoClient(uri)
        self.db = self.client[db_name]


mongo = MongoExtension()
jwt = JWTManager()
csrf = CSRFProtect()
mail = Mail()
