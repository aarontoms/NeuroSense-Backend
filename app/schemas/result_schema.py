from pydantic import BaseModel, Field


class AnalysisResultCreate(BaseModel):
    studentId: str = Field(..., min_length=1)
    result: str = Field(..., min_length=1)


class AnalysisResultOut(BaseModel):
    studentId: str
    result: str
