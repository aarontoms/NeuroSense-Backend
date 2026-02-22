from pydantic import BaseModel, Field, EmailStr
from typing import List
from datetime import datetime


class TeacherCreate(BaseModel):
    fullName: str = Field(..., min_length=1)
    email: EmailStr
    password: str = Field(..., min_length=1)
    dateOfRegistration: datetime
    institution: str = Field(..., min_length=1)
    contentId: List[str] = []


class TeacherOut(BaseModel):
    fullName: str
    email: EmailStr
    password: str
    dateOfRegistration: datetime
    institution: str
    contentId: List[str] = []
    id: str
