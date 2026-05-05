from functools import wraps
from flask import request
from app.extensions import mongo
from app.utils.responses import forbidden, unauthorized
from pymongo.database import Database
from typing import cast
from bson import ObjectId


def role_required(*required_roles: str):
    def decorator(fn):
        @wraps(fn)
        def wrapper(*args, **kwargs):
            user_id = request.headers.get("X-User-Id")
            
            if not user_id:
                # For backward compatibility or testing, if you want to skip auth when no ID is sent, comment out the return.
                # But typically this should block.
                return unauthorized("Missing User ID header")

            db = cast(Database, mongo.db)
            try:
                oid = ObjectId(user_id)
            except:
                return unauthorized("Invalid User ID format")

            user = db.users.find_one({"_id": oid})

            if not user:
                return unauthorized("User not found")

            # Check if user role matches one of the required roles
            # user["role"] is a string, required_roles is a tuple of strings
            if user.get("role") not in required_roles:
                return forbidden("Insufficient permissions")

            return fn(*args, **kwargs)

        return wrapper
    return decorator
