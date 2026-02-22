from flask import Blueprint, request

from app.services.auth_service import *

from app.utils.responses import success, error

bp = Blueprint("auth", __name__, url_prefix="/auth")


@bp.route("/student/signup", methods=["POST"])
def student_signup_route():
    try:
        result = student_signup(request.json)
        return success(result, code=201)
    except Exception as e:
        print(e)
        return error(str(e))


@bp.route("/parent/signup", methods=["POST"])
def parent_signup_route():
    try:
        result = parent_signup(request.json)
        return success(result, code=201)
    except Exception as e:
        return error(str(e))


@bp.route("/teacher/signup", methods=["POST"])
def teacher_signup_route():
    try:
        result = teacher_signup(request.json)
        return success(result, code=201)
    except Exception as e:
        return error(str(e))


@bp.route("/signin", methods=["POST"])
def common_signin():
    try:
        result = signin(request.json)
        return success(result)
    except Exception as e:
        return error(str(e))


@bp.route("/signout", methods=["POST"])
def signout():
    return success(message="Signed out successfully")
