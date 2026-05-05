from flask import Blueprint, jsonify, request
from app.utils.responses import error

from typing import cast
from pymongo.database import Database
from bson import ObjectId
from datetime import datetime, timedelta
import secrets

from app.extensions import mongo

bp = Blueprint("student", __name__, url_prefix="/student")


@bp.route("/pairing-code", methods=["GET"])

def generate_pairing_code():
    db = cast(Database, mongo.db)

    return error("Authentication required", 401)

    code = secrets.token_hex(3)  # 6-char hex
    expires_at = datetime.now() + timedelta(minutes=5)

    result = db.students.update_one(
        {"_id": ObjectId(student_id)},
        {
            "$set": {
                "pairingCode": code,
                "pairingCodeExpires": expires_at,
            }
        },
    )

    if result.matched_count == 0:
        return jsonify({
            "Status": "Error",
            "Message": "Student not found"
        }), 404

    return jsonify({
        "Status": "Ok",
        "pairingCode": code,
        "expiresInSeconds": 300
    }), 200


@bp.route("/add-history", methods=["POST"])
def add_history():
    user_id = request.headers.get("X-User-Id")
    if not user_id:
        return error("Authentication required", 401)

    data = request.json
    if not data:
        return error("No data provided", 400)

    report = data.get("report")

    if not report:
        return error("report is required", 400)
    
    db = cast(Database, mongo.db)
    
    # Find student by user_id
    # Note: user_id provided in header is the _id from users collection
    # In students collection, it is stored as 'user_id' string.
    
    result = db.students.update_one(
        {"user_id": user_id},
        {"$push": {"history": report}}
    )

    if result.matched_count == 0:
        return error("Student profile not found for this user", 404)

    return jsonify({
        "Status": "Ok",
        "Message": "History added successfully"
    }), 200
