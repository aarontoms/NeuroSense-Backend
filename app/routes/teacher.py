from flask import Blueprint, jsonify, request, send_file

from typing import cast
from bson import ObjectId
from pymongo.database import Database
from app.extensions import mongo

from app.services.teacher_service import (
    upload_file,
    save_metadata,
    resolve_file_path,
)
from app.utils.responses import success, error

bp = Blueprint("teacher", __name__, url_prefix="/teacher")


@bp.route("/upload", methods=["POST"])

def upload():
    raw = request.get_data()
    filename = request.headers.get("X-Filename")

    if not raw:
        return error("Invalid file", 400)

    if not filename:
        return error("FILENAME_REQUIRED", 400)

    try:
        file_id = upload_file(
            raw=raw,
            filename=filename,
            teacher_id=None,
        )
        return success(
            {
                "fileId": file_id,
                "message": "File received. Send metadata with fileId.",
            },
            code=201,
        )
    except ValueError as e:
        return error(str(e), 400)
    except PermissionError:
        return error("Unauthorized", 403)
    except FileExistsError:
        return error("FILE_ALREADY_EXISTS", 409)
    except Exception:
        return error("Error saving file", 500)


@bp.route("/upload-metadata", methods=["POST"])

def upload_metadata():
    body = request.json or {}
    metadata = body.get("metadata")
    file_id = body.get("fileId")

    if not metadata or not file_id:
        return error("Invalid request", 400)

    try:
        save_metadata(
            metadata=metadata,
            file_id=file_id,
            teacher_id=None,
        )
        return success(message="Metadata saved")
    except FileNotFoundError as e:
        return error(str(e), 404)
    except PermissionError:
        return error("Unauthorized", 403)
    except Exception:
        return error("Internal Server Error", 500)


@bp.route("/get-file", methods=["GET"])
def get_file():
    file_id = request.args.get("fileId")

    if not file_id:
        return error("fileId required", 400)

    try:
        path = resolve_file_path(file_id)
        return send_file(
            path,
            as_attachment=True,
            download_name=file_id,
            mimetype="application/octet-stream",
        )
    except FileNotFoundError as e:
        return error(str(e), 404)
    except Exception:
        return error("STREAM_FAIL", 500)


@bp.route("/get-students", methods=["GET"])

def get_students_for_teacher():
    db = cast(Database, mongo.db)

    teacher_id = None

    teacher = db.teachers.find_one(
        {"_id": ObjectId(teacher_id)},
        {"institution": 1}
    )

    if not teacher:
        return jsonify({
            "Status": "Error",
            "Message": "Teacher not found"
        }), 404

    institution = teacher.get("institution")
    if not institution:
        return jsonify({
            "Status": "Error",
            "Message": "Teacher institution not set"
        }), 400

    students = list(
        db.students.find(
            {"institution": institution},
            {"fullName": 1, "email": 1}
        )
    )

    result = [
        {
            "id": str(s["_id"]),
            "fullName": s.get("fullName"),
            "email": s.get("email"),
        }
        for s in students
    ]

    return jsonify({
        "Status": "Ok",
        "students": result
    }), 200
