from pydantic import BaseModel


class AvatarUploadOut(BaseModel):
    avatar_url: str


class IntelPhotoUploadOut(BaseModel):
    object_key: str
    view_url: str
