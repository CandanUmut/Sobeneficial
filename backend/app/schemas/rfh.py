from pydantic import BaseModel
from typing import List, Optional

class RFHCreate(BaseModel):
    title: str
    body: str | None = None
    tags: List[str] = []
    sensitivity: str = "normal"
    anonymous: bool = False
    region: str | None = None
    language: str = "tr"

class RFH(BaseModel):
    id: str
    requester_id: str | None = None
    title: str
    body: str | None = None
    tags: List[str] = []
    sensitivity: str
    anonymous: bool
    status: str
    region: str | None = None
    language: str

class MatchResult(BaseModel):
    helper_id: str
    score: float
    note: str | None = None
