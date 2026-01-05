from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

class EventCreate(BaseModel):
    title: str
    description: Optional[str] = None
    type: str  # 'course'|'webinar'|'workshop'
    starts_at: datetime
    ends_at: Optional[datetime] = None
    location: Optional[str] = None
    capacity: Optional[int] = None
    tags: List[str] = []
    visibility: str = "public"
