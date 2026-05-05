from datetime import datetime
from flask import Blueprint, jsonify, request
from app.utils.responses import error

from typing import cast
from pymongo.database import Database
from bson import ObjectId

from app.extensions import mongo

bp = Blueprint("parent", __name__, url_prefix="/user")


@bp.route("/students", methods=["GET"])
def get_students_for_parent():
    user_id = request.headers.get("X-User-Id")
    if not user_id:
        return error("Authentication required", 401)

    db = cast(Database, mongo.db)
    
    # Check if user_id is valid
    try:
        # The parent collection stores "user_id" as a string which links to users collection _id
        parent = db.parents.find_one({"user_id": user_id})
    except:
        return error("Invalid User ID", 400)

    if not parent:
        return jsonify({
            "Status": "Error",
            "Message": "Parent not found"
        }), 404

    # Check both 'students' and 'studentId' for backwards compatibility
    # Parent document has 'students' array containing user IDs from users collection
    student_ids = parent.get("students", []) or parent.get("studentId", [])
    
    if not student_ids:
        return jsonify({
            "Status": "Ok",
            "students": []
        }), 200

    # Query students collection by user_id (not _id)
    # because parent stores user IDs from users collection
    students_cursor = db.students.find(
        {"user_id": {"$in": student_ids}},
        {"password": 0}
    )

    students = []
    for s in students_cursor:
        s["_id"] = str(s["_id"])
        # ensure history is present
        if "history" not in s:
            s["history"] = []
        students.append(s)

    return jsonify({
        "Status": "Ok",
        "students": students
    }), 200


@bp.route("/add-student", methods=["POST"])
def add_student_to_parent():
    user_id = request.headers.get("X-User-Id")
    if not user_id:
        return error("Authentication required", 401)

    db = cast(Database, mongo.db)

    body = request.json or {}
    email = body.get("email")
    code = body.get("code")

    if not email or not code:
        return jsonify({
            "Status": "Error",
            "Message": "Email and code required"
        }), 400

    student = db.students.find_one({"email": email})
    if not student:
        return jsonify({
            "Status": "Error",
            "Message": "Invalid student or code"
        }), 401

    if (
        student.get("pairingCode") != code or
        not student.get("pairingCodeExpires") or
        student["pairingCodeExpires"] < datetime.now()
    ):
        return jsonify({
            "Status": "Error",
            "Message": "Invalid or expired code"
        }), 401

    parent = db.parents.find_one({"user_id": user_id})
    if not parent:
         return error("Parent profile not found", 404)

    db.parents.update_one(
        {"_id": parent["_id"]},
        {"$addToSet": {"studentId": student["_id"]}}
    )

    # Invalidate code (one-time use)
    db.students.update_one(
        {"_id": student["_id"]},
        {"$unset": {"pairingCode": "", "pairingCodeExpires": ""}}
    )

    return jsonify({
        "Status": "Ok",
        "Message": "Student linked successfully"
    }), 200
