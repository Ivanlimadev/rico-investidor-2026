from pydantic import BaseModel, EmailStr, Field, field_validator

from app.domain.auth.password_policy import validate_password_strength


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    name: str = Field(min_length=2, max_length=80)

    @field_validator("password")
    @classmethod
    def validate_password(cls, value: str) -> str:
        validate_password_strength(value)
        return value


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=128)


class AnonymousAuthRequest(BaseModel):
    device_id: str = Field(min_length=8, max_length=128)


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int


class UserResponse(BaseModel):
    id: str
    email: str
    name: str
    is_anonymous: bool = False


class UpdateProfileRequest(BaseModel):
    name: str = Field(min_length=2, max_length=80)
