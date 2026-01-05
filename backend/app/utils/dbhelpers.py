from typing import Any, Mapping

def row_to_dict(row: Mapping[str, Any]) -> dict:
    return dict(row._mapping) if hasattr(row, "_mapping") else dict(row)
