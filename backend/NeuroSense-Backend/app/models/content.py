from bson.objectid import ObjectId
from typing import Dict, List

class Content:
    __slots__ = ("id", "fileName", "timestampWiseMetaData", "fileId")

    def __init__(self, fileName: str, timestampWiseMetaData: List[Dict[str, str]], fileId: str, _id : ObjectId | None = None) -> None:
        self.fileId = fileId
        self.fileName = fileName
        self.timestampWiseMetaData = timestampWiseMetaData
        self.id = _id or ObjectId()

    def to_document(self) -> dict:
        return {
            "_id": self.id,
            "fileName": self.fileName,
            "timestampWiseMetaData": self.timestampWiseMetaData,
            "fileId": self.fileId
        }
    
    @staticmethod
    def from_document(doc: dict) -> "Content":
        return Content(_id = doc["id"], fileId = doc["fileId"], fileName = doc["fileName"], timestampWiseMetaData = doc["timestampWiseMetaData"])

    def public_view(self) -> dict:
         return {
            "fileName": self.fileName,
            "timestampWiseMetaData": self.timestampWiseMetaData,
            "fileId": self.fileId
        }