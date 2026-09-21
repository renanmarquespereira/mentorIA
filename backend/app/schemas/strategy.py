from datetime import date
from typing import Literal
from pydantic import BaseModel, Field, model_validator

class ActionPlanStatusUpdate(BaseModel):
    status: Literal["pending", "in_progress", "done"] | None = None
    priority: Literal["high", "medium", "low"] | None = None
    due_date: date | None = None
    notes: str | None = Field(default=None, max_length=5000)
    progress_percent: int | None = Field(default=None, ge=0, le=100)

    @model_validator(mode="after")
    def valid_patch(self):
        if not self.model_fields_set:
            raise ValueError("Informe ao menos uma alteração")
        for name in ("status", "priority", "notes", "progress_percent"):
            if name in self.model_fields_set and getattr(self, name) is None:
                raise ValueError(f"{name} não pode ser nulo")
        return self
