from bson.objectid import ObjectId
from typing import Optional


class AnalysisResult:
    __slots__ = ("id", "studentId", "result")

    def __init__(
        self,
        studentId: ObjectId,
        result: str,
        _id: Optional[ObjectId] = None,
    ) -> None:
        self.id = _id or ObjectId()
        self.studentId = studentId
        self.result = result

    def to_document(self) -> dict:
        return {
            "_id": self.id,
            "studentId": self.studentId,
            "result": self.result,
        }

    @staticmethod
    def from_document(doc: dict) -> "AnalysisResult":
        return AnalysisResult(
            _id=doc["_id"],
            studentId=doc["studentId"],
            result=doc["result"],
        )
