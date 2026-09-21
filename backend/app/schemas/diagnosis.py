from pydantic import BaseModel, Field

class DiagnosisAnswerRequest(BaseModel):
    question_key: str = Field(min_length=2, max_length=120)
    answer_text: str = Field(min_length=1)
    audio_id: str | None = Field(default=None, max_length=36)

class AIAnalysisPayload(BaseModel):
    mode: str
    quality_score: int
    decision: str
    feedback: str
    follow_up_question: str | None = None
    extracted_facts: list[str] = []
    risks: list[str] = []
    model_used: str | None = None

class DiagnosisAnswerResponse(BaseModel):
    saved: bool
    score: int
    progress: int
    status: str
    next_question: dict | None = None
    ai_analysis: AIAnalysisPayload | None = None

class PositioningSynthesisResponse(BaseModel):
    ready: bool
    mode: str
    positioning_statement: str | None = None
    authority_summary: str | None = None
    values_summary: str | None = None
    transformation_summary: str | None = None
    strengths: list[str] = []
    gaps: list[str] = []
    next_actions: list[str] = []
    model_used: str | None = None

class AnswerCoachRequest(BaseModel):
    question_key: str = Field(min_length=2, max_length=120)
    answer_text: str = Field(min_length=1)
    message: str = Field(min_length=1, max_length=2000)
    history: list[dict] = []
