from pydantic import BaseModel, Field
from typing import List


class TimestampMeta(BaseModel):
    time: str
    data: str


class ContentCreate(BaseModel):
    fileName: str = Field(..., min_length=1)
    fileId: str = Field(..., min_length=1)
    timestampWiseMetaData: List[TimestampMeta] = []


class ContentOut(BaseModel):
    id: str
    fileName: str
    fileId: str
    timestampWiseMetaData: List[TimestampMeta]
