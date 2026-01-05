from pydantic import BaseModel

class ReportCreate(BaseModel):
    entity: str
    entity_id: str
    reason: str | None = None
    severity: int = 1
