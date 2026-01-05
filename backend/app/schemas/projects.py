from pydantic import BaseModel
from typing import List, Optional

class ProjectCreate(BaseModel):
    title: str
    description: Optional[str] = None
    needed_roles: List[str] = []
    region: Optional[str] = None
    tags: List[str] = []
    visibility: str = "public"

class ProjectApply(BaseModel):
    message: Optional[str] = None
