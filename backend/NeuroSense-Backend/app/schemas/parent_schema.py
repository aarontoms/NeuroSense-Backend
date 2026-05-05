from pydantic import BaseModel, EmailStr, Field
from typing import List
from datetime import datetime


class ParentCreate(BaseModel):
    fullName: str = Field(..., min_length=1)
    email: EmailStr
    password: str = Field(..., min_length=8)
    studentId: List[str] = []


class ParentOut(BaseModel):
    id: str
    fullName: str
    email: EmailStr
    dateOfRegistration: datetime
    studentId: List[str]
