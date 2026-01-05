from pydantic import BaseModel
from typing import List, Optional, Any

class QuestionCreate(BaseModel):
    title: str
    body: Optional[str] = None
    tags: List[str] = []
    visibility: str = "public"

class AnswerCreate(BaseModel):
    question_id: str
    body: str
    evidence: str = "n_a"
    sources: list[Any] = []
