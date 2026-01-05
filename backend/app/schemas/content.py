from pydantic import BaseModel
from typing import List, Optional, Any

class ContentCreate(BaseModel):
    type: str
    title: str
    summary: Optional[str] = None
    body: Optional[str] = None
    evidence: str = "n_a"
    visibility: str = "public"
    sources: Optional[list[Any]] = None
    region: Optional[str] = None
    language: str = "tr"
    tags: Optional[List[str]] = None

class Content(BaseModel):
    id: str
    author_id: str
    type: str
    title: str
    summary: Optional[str] = None
    body: Optional[str] = None
    evidence: str
    visibility: str
    region: Optional[str] = None
    language: str = "tr"
