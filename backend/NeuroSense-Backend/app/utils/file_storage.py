import os
import re
from uuid import uuid4
from flask import current_app

ALLOWED_EXT = re.compile(r"^[a-z0-9]+$", re.I)


def get_upload_dir() -> str:
    path = os.path.join(current_app.instance_path, "uploads")
    os.makedirs(path, exist_ok=True)
    return path


def validate_and_store_file(raw: bytes, teacher_id: str, filename: str) -> tuple[str, str]:
    if not raw:
        raise ValueError("Invalid file")

    if not filename:
        raise ValueError("FILENAME_REQUIRED")

    ext = os.path.splitext(filename)[1].lstrip(".")
    if not ext or not ALLOWED_EXT.match(ext):
        raise ValueError("INVALID_EXTENSION")

    file_id = f"{teacher_id}-{uuid4().hex}"
    stored_name = f"{file_id}.{ext}"

    path = os.path.join(get_upload_dir(), stored_name)

    with open(path, "xb") as f:
        f.write(raw)

    return file_id, stored_name
