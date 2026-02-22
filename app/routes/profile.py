from flask import Blueprint, jsonify, request
from app.utils.responses import error

from typing import cast
from pymongo.database import Database
from bson import ObjectId

from app.extensions import mongo

bp = Blueprint("profile", __name__)


@bp.route("/profile", methods=["GET"])
def profile():
    user_id = request.headers.get("X-User-Id")
    if not user_id:
        return error("Authentication required", 401)

    db = cast(Database, mongo.db)
    try:
        oid = ObjectId(user_id)
    except:
        return error("Invalid User ID", 400)

    # Fetch basic user info
    user = db.users.find_one({"_id": oid}, {"password": 0})
    if not user:
        return error("User not found", 404)

    role = user.get("role")
    role_data = None
    
    # Query role-specific data using the user_id (string)
    # The auth_service saves user_id as a string in the role collections
    uid_str = str(user["_id"])
    
    if role == "student":
        role_data = db.students.find_one({"user_id": uid_str}, {"password": 0})
    elif role == "parent":
        role_data = db.parents.find_one({"user_id": uid_str}, {"password": 0})
    elif role == "teacher":
        role_data = db.teachers.find_one({"user_id": uid_str}, {"password": 0})

    # Merge data: role_data takes precedence or just include it?
    # User requested: "send the user's corresponding mongo _id... direct method to check who method is"
    # Basic profile info is what we want.
    
    profile_data = {
        "username": user.get("username"),
        "email": user.get("email"),
        "role": role,
        "section_id": str(user["_id"]), # Returning the main user ID
        "date_of_registration": user.get("date_of_registration")
    }
    
    if role_data:
        # exclude _id from role_data or convert it
        role_data["_id"] = str(role_data["_id"])
        # Merge role specific fields
        profile_data.update(role_data)

    return jsonify({
        "Status": "Ok",
        "role": role,
        "profile": profile_data
    }), 200
