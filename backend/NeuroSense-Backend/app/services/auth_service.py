from app.extensions import mongo, bcrypt
from app.schemas.auth_schema import StudentSignup, ParentSignup, TeacherSignup, SignIn

from datetime import datetime, time
from typing import cast
from pymongo.database import Database


def _hash(password: str) -> str:
    return bcrypt.generate_password_hash(password).decode()


def create_user_entry(db: Database, data: dict, role: str) -> str:
    # Check if user already exists in users collection
    if db.users.find_one({"email": data["email"]}):
        raise ValueError(f"User with email {data['email']} already exists")

    user_doc = {
        "username": data["fullName"],
        "email": data["email"],
        "password": _hash(data["password"]),
        "date_of_registration": datetime.utcnow(),
        "role": role
    }
    result = db.users.insert_one(user_doc)
    return str(result.inserted_id)


def student_signup(data: dict):
    db = cast(Database, mongo.db)
    payload = StudentSignup(**data)
    
    # Create user in users collection
    user_id = create_user_entry(db, data, "student")

    # Add to students collection
    db.students.insert_one({
        "user_id": user_id,
        "fullName": payload.fullName,
        "email": payload.email,
        "description": payload.description,
        "dob": datetime.combine(payload.dob, time.min),
        "institution": payload.institution.lower(),
        "history": [],
    })
    
    return {"_id": user_id, "role": "student"}


def parent_signup(data: dict):
    db = cast(Database, mongo.db)
    payload = ParentSignup(**data)
    
    # Create user in users collection
    user_id = create_user_entry(db, data, "parent")

    # Add to parents collection
    db.parents.insert_one({
        "user_id": user_id,
        "fullName": payload.fullName,
        "email": payload.email,
        "history": [],
        "students": [],
    })
    
    return {"_id": user_id, "role": "parent"}


def teacher_signup(data: dict):
    db = cast(Database, mongo.db)
    payload = TeacherSignup(**data)
    
    # Create user in users collection
    user_id = create_user_entry(db, data, "teacher")

    # Add to teachers collection
    db.teachers.insert_one({
        "user_id": user_id,
        "fullName": payload.fullName,
        "email": payload.email,
        "institution": payload.institution.lower(),
        "history": [],
        "students": [],
    })
    
    return {"_id": user_id, "role": "teacher"}


def signin(data: dict):
    db = cast(Database, mongo.db)
    payload = SignIn(**data)

    user = db.users.find_one({"email": payload.email})
    if not user or not bcrypt.check_password_hash(user["password"], payload.password):
        raise ValueError("Invalid credentials")

    return {
        "_id": str(user["_id"]),
        "role": user["role"],
        "username": user["username"],
        "email": user["email"]
    }
