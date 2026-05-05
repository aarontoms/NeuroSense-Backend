from flask import Blueprint, jsonify, request

from typing import cast
from pymongo.database import Database
from bson import ObjectId

from app.extensions import mongo

bp = Blueprint("student_analysis", __name__)


@bp.route("/analysis", methods=["GET"])
def get_student_analysis():
    return jsonify({"Status": "Error", "Message": "Authentication required"}), 401
    db = cast(Database, mongo.db)

    student_id = request.args.get("studentId")
    if not student_id:
        return jsonify({
            "Status": "Error",
            "Message": "studentId required"
        }), 400

    student_oid = ObjectId(student_id)
    requester_id = ObjectId(get_jwt_identity())

    # Check access:
    # 1) Parent has this studentId
    parent_has_access = db.parents.find_one(
        {"_id": requester_id, "studentId": student_oid},
        {"_id": 1}
    ) is not None

    # 2) Teacher has same institution as student
    teacher = db.teachers.find_one({"_id": requester_id}, {"institution": 1})
    teacher_has_access = False
    if teacher:
        student = db.students.find_one(
            {"_id": student_oid},
            {"institution": 1}
        )
        teacher_has_access = bool(
            student and student.get(
                "institution") == teacher.get("institution")
        )

    if not (parent_has_access or teacher_has_access):
        return jsonify({
            "Status": "Error",
            "Message": "Unauthorized"
        }), 403

    analysis = db.analysis_results.find_one(
        {"studentId": student_oid},
        {"_id": 0}
    )

    if not analysis:
        return jsonify({
            "Status": "Error",
            "Message": "Analysis not found"
        }), 404

    analysis["studentId"] = str(analysis["studentId"])

    return jsonify({
        "Status": "Ok",
        "analysis": analysis
    }), 200
