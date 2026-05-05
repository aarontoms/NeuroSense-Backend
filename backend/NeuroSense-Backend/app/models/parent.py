from bson.objectid import ObjectId
from datetime import datetime
from typing import List


class Parent:
    __slots__ = (
        "id",
        "fullName",
        "email",
        "password",
        "dateOfRegistration",
        "studentId",
    )

    def __init__(
        self,
        fullName: str,
        email: str,
        password: str,
        studentId: List[ObjectId] | None = None,
        dateOfRegistration: datetime | None = None,
        _id: ObjectId | None = None,
    ):
        self.id = _id or ObjectId()
        self.fullName = fullName
        self.email = email
        self.password = password
        self.dateOfRegistration = dateOfRegistration or datetime.utcnow()
        self.studentId = studentId or []

    def to_document(self) -> dict:
        return {
            "_id": self.id,
            "fullName": self.fullName,
            "email": self.email,
            "password": self.password,
            "dateOfRegistration": self.dateOfRegistration,
            "studentId": self.studentId,
        }

    @staticmethod
    def from_document(doc: dict) -> "Parent":
        return Parent(
            _id=doc["_id"],
            fullName=doc["fullName"],
            email=doc["email"],
            password=doc["password"],
            dateOfRegistration=doc.get("dateOfRegistration"),
            studentId=doc.get("studentId", []),
        )

    def public_view(self) -> dict:
        return {
            "id": str(self.id),
            "fullName": self.fullName,
            "email": self.email,
            "dateOfRegistration": self.dateOfRegistration,
            "studentId": [str(sid) for sid in self.studentId],
        }
