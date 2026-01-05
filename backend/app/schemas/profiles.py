from pydantic import BaseModel
from typing import List, Optional

class Profile(BaseModel):
    id: str
    username: Optional[str] = None
    full_name: Optional[str] = None
    avatar_url: Optional[str] = None
    bio: Optional[str] = None
    languages: List[str] = []
    timezone: Optional[str] = None
    country: Optional[str] = None
    region: Optional[str] = None
    roles: List[str] = []
    reputation: int = 0
    offers: List[str] = []
    needs: List[str] = []
    anon_allowed: bool = True

class ProfileUpdate(BaseModel):
    username: Optional[str] = None
    full_name: Optional[str] = None
    avatar_url: Optional[str] = None
    bio: Optional[str] = None
    languages: Optional[List[str]] = None
    timezone: Optional[str] = None
    country: Optional[str] = None
    region: Optional[str] = None
    offers: Optional[List[str]] = None
    needs: Optional[List[str]] = None
    anon_allowed: Optional[bool] = None
