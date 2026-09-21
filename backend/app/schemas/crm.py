from datetime import date
from typing import Literal
from pydantic import BaseModel, Field, ConfigDict, model_validator

Stage = Literal["new", "qualified", "scheduled", "proposal", "closed_won", "closed_lost"]

class CrmInput(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True, allow_inf_nan=False, extra="forbid")

class LeadCreate(CrmInput):
    name: str = Field(min_length=2, max_length=160)
    contact: str | None = Field(default=None,max_length=200)
    source: str = Field(default="manual",min_length=1,max_length=80)
    funnel: str | None = Field(default=None,max_length=80)
    stage: Stage = "new"
    notes: str | None = Field(default=None,max_length=5000)
    expected_value: float = Field(default=0, ge=0)

class LeadStageUpdate(CrmInput):
    stage: Stage

class LeadUpdate(CrmInput):
    name: str | None = Field(default=None,min_length=2,max_length=160)
    contact: str | None = Field(default=None,max_length=200)
    source: str | None = Field(default=None,min_length=1,max_length=80)
    funnel: str | None = Field(default=None,max_length=80)
    notes: str | None = Field(default=None,max_length=5000)
    expected_value: float | None = Field(default=None,ge=0)
    @model_validator(mode="after")
    def validate_patch(self):
        if not self.model_fields_set:
            raise ValueError("Informe uma alteração")
        for key in ("name", "source", "expected_value"):
            if key in self.model_fields_set and getattr(self,key) is None:
                raise ValueError(f"{key} não pode ser nulo")
        return self

class SaleCreate(CrmInput):
    lead_id: str | None = None
    amount: float = Field(gt=0)
    product: str = Field(default="Mentoria",min_length=1,max_length=160)
    source: str = Field(default="manual",min_length=1,max_length=80)
    request_id: str | None = Field(default=None,min_length=1,max_length=64)

class FollowUpCreate(CrmInput):
    due_date: date
    notes: str = Field(default="",max_length=5000)

class FollowUpUpdate(CrmInput):
    status: Literal["pending", "done"]

class MetricCreate(CrmInput):
    period: str = Field(pattern=r'^[1-9][0-9]{3}-(0[1-9]|1[0-2])$')
    leads: int = Field(default=0, ge=0)
    calls: int = Field(default=0, ge=0)
    sales_count: int = Field(default=0, ge=0)
    revenue: float = Field(default=0, ge=0)
    ad_spend: float = Field(default=0, ge=0)
