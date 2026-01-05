from pydantic import BaseModel
from typing import Any, List, Optional

class Msg(BaseModel):
    message: str

class Paginated(BaseModel):
    items: list[Any]
    total: int
