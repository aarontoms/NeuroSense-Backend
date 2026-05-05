import os
from typing import cast
from bson import ObjectId
from pymongo.database import Database

from app.extensions import mongo
from app.utils.file_storage import validate_and_store_file, get_upload_dir


def upload_file(raw: bytes, filename: str, teacher_id: str) -> str:
    db = cast(Database, mongo.db)

    teacher = db.teachers.find_one({"_id": ObjectId(teacher_id)})
    if not teacher:
        raise PermissionError("Unauthorized")

    file_id, _ = validate_and_store_file(raw, teacher_id, filename)
    return file_id


def save_metadata(metadata: list, file_id: str, teacher_id: str):
    db = cast(Database, mongo.db)

    teacher = db.teachers.find_one({"_id": ObjectId(teacher_id)})
    if not teacher:
        raise PermissionError("Unauthorized")

    upload_dir = get_upload_dir()
    stored_file = next(
        (f for f in os.listdir(upload_dir) if f.startswith(file_id)),
        None,
    )

    if not stored_file:
        raise FileNotFoundError("File not found")

    result = db.contents.insert_one({
        "fileName": stored_file,
        "timestampWiseMetaData": metadata,
        "fileId": file_id,
    })

    db.teachers.update_one(
        {"_id": teacher["_id"]},
        {"$push": {"contentId": result.inserted_id}},
    )


def resolve_file_path(file_id: str) -> str:
    db = cast(Database, mongo.db)

    content = db.contents.find_one({"fileId": file_id})
    if not content:
        raise FileNotFoundError("File not found")

    path = os.path.join(get_upload_dir(), content["fileName"])
    if not os.path.exists(path):
        raise FileNotFoundError("FILE_NOT_FOUND")

    return path
