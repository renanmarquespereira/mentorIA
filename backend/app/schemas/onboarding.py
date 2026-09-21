from pydantic import BaseModel, Field

class OnboardingRequest(BaseModel):
    city_state: str | None = None
    education: str | None = None
    experience_months: int = Field(default=0, ge=0)
    has_clients: bool = False
    sells_mentoring: bool = False
    has_professional_instagram: bool = False
    active_clients: int = Field(default=0, ge=0)
    current_ticket: float = Field(default=0, ge=0)
    monthly_revenue: float = Field(default=0, ge=0)
    main_difficulty: str | None = None
    main_goal: str | None = None
