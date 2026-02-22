from typing import cast
from pymongo.database import Database
from app.extensions import mongo


def _ensure_db():
    db = cast(Database, mongo.db)

    # touch DB (forces creation)
    db["_init"].insert_one({"_init": True})

    # indexes
    db.students.create_index("email", unique=True)
    db.parents.create_index("email", unique=True)
    db.teachers.create_index("email", unique=True)

    db.contents.create_index("fileId", unique=True)
    db.revoked_tokens.create_index("expires_at", expireAfterSeconds=0)
    db.analysis_results.create_index("studentId", unique=True)
