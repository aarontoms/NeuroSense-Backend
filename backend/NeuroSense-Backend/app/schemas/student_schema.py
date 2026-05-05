from pydantic import BaseModel, Field, EmailStr
from datetime import datetime


class StudentCreate(BaseModel):
    fullName: str = Field(..., min_length=1)
    email: EmailStr
    description: str = Field(..., min_length=1)
    dob: datetime
    password: str = Field(..., min_length=6)
    institution: str = Field(..., min_length=1)


class StudentInternal(BaseModel):
    id: str
    fullName: str
    email: EmailStr
    description: str
    dob: datetime
    password: str
    dateOfRegistration: datetime
    institution: str


class StudentOut(BaseModel):
    id: str
    fullName: str
    email: EmailStr
    description: str
    dob: datetime
    dateOfRegistration: datetime
    institution: str
