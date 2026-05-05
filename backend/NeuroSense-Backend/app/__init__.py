from flask import Flask
from flask_cors import CORS
from .config import Config
from .extensions import mongo, bcrypt
from .routes import auth, parent, student, teacher, profile, analysis_result, predict
from . import db_init


def create_app():
    app = Flask(__name__)
    app.config.from_object(Config)

    CORS(
        app,
        resources={r"/*": {"origins": "*"}},
        supports_credentials=True
    )

    mongo.init_app(app)
    bcrypt.init_app(app)

    with app.app_context():
        db_init._ensure_db()

    app.register_blueprint(auth.bp)
    app.register_blueprint(profile.bp)
    app.register_blueprint(parent.bp)
    app.register_blueprint(student.bp)
    app.register_blueprint(teacher.bp)
    app.register_blueprint(analysis_result.bp)
    app.register_blueprint(predict.bp)

    return app
