from bson.objectid import ObjectId
from typing import List
from datetime import datetime


class Teacher:
    __slots__ = (
        "fullName",
        "email",
        "password",
        "dateOfRegistration",
        "institution",
        "contentId",
        "id"
    )

    def __init__(self, fullName: str, email: str, password: str, dateOfRegistration: datetime, institution: str, contentId: List[ObjectId], id: ObjectId | None = None) -> None:
        self.id = id or None
        self.contentId = contentId
        self.dateOfRegistration = dateOfRegistration
        self.institution = institution
        self.password = password
        self.email = email
        self.fullName = fullName

    def to_document(self) -> dict:
        return {
            "id": str(self.id),
            "fullName": self.fullName,
            "email": self.email,
            "dateOfRegistration": self.dateOfRegistration,
            "contentId": self.contentId,
            "institution": self.institution,
            "password": self.password
        }

    def public_view(self) -> dict:
        return {
            "id": str(self.id),
            "fullName": self.fullName,
            "email": self.email,
            "dateOfRegistration": self.dateOfRegistration,
            "contentId": self.contentId,
            "institution": self.institution
        }

    @staticmethod
    def from_document(doc: dict) -> "Teacher":
        return Teacher(
            contentId=doc["contentId"],
            dateOfRegistration=doc["dateOfRegistration"],
            email=doc["email"],
            fullName=doc["fullName"],
            id=doc["_id"],
            institution=doc["institution"],
            password=doc["password"],
        )
