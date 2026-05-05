from bson.objectid import ObjectId
from datetime import datetime
from typing import Optional


class Student:
    __slots__ = (
        "id",
        "fullName",
        "email",
        "description",
        "dob",
        "password",
        "dateOfRegistration",
        "institution",
        "pairingCode",
        "pairingCodeExpires",
    )

    def __init__(
        self,
        fullName: str,
        email: str,
        description: str,
        dob: datetime,
        password: str,
        institution: str,
        dateOfRegistration: Optional[datetime] = None,
        _id: Optional[ObjectId] = None,
        pairingCode: Optional[str] = None,
        pairingCodeExpires: Optional[datetime] = None,
    ) -> None:
        self.id = _id or ObjectId()
        self.fullName = fullName
        self.email = email
        self.description = description
        self.dob = dob
        self.password = password
        self.institution = institution
        self.dateOfRegistration = dateOfRegistration or datetime.now()
        self.pairingCode = pairingCode
        self.pairingCodeExpires = pairingCodeExpires

    def to_document(self) -> dict:
        doc = {
            "_id": self.id,
            "fullName": self.fullName,
            "email": self.email,
            "description": self.description,
            "dob": self.dob,
            "password": self.password,
            "dateOfRegistration": self.dateOfRegistration,
            "institution": self.institution,
        }

        if self.pairingCode:
            doc["pairingCode"] = self.pairingCode
            doc["pairingCodeExpires"] = self.pairingCodeExpires

        return doc

    @staticmethod
    def from_document(doc: dict) -> "Student":
        return Student(
            _id=doc["_id"],
            fullName=doc["fullName"],
            email=doc["email"],
            description=doc["description"],
            dob=doc["dob"],
            password=doc["password"],
            institution=doc["institution"],
            dateOfRegistration=doc.get("dateOfRegistration"),
            pairingCode=doc.get("pairingCode"),
            pairingCodeExpires=doc.get("pairingCodeExpires"),
        )

    def public_view(self) -> dict:
        return {
            "id": str(self.id),
            "fullName": self.fullName,
            "email": self.email,
            "description": self.description,
            "dob": self.dob,
            "dateOfRegistration": self.dateOfRegistration,
            "institution": self.institution,
        }
