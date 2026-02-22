from pydantic import BaseModel, Field
from datetime import date


class StudentSignup(BaseModel):
    fullName: str = Field(..., min_length=1)
    email: str
    description: str
    password: str = Field(..., min_length=1)
    dob: date
    institution: str


class ParentSignup(BaseModel):
    fullName: str
    email: str
    password: str = Field(..., min_length=1)


class TeacherSignup(BaseModel):
    fullName: str
    email: str
    password: str = Field(..., min_length=1)
    institution: str


class SignIn(BaseModel):
    email: str
    password: str
