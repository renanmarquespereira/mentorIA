from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import os
from app.api.routes.voice import router as voice_router
from app.api.routes.plan_conversation import router as conversation_router
from app.db.session import Base, engine
from app.models import MentorMenteeNote, MentorMenteeIntelligence, User, EducatorProfile, PillarProgress, DiagnosisAnswer, DiagnosisSession, DiagnosisAIAnalysis, PositioningSynthesis, ActionPlanItem, StrategicReport, Lead, Sale, CommercialMetric, PillarAssessmentRound
from app.db.migrations import run_lightweight_migrations
from app.api.routes.auth import router as auth_router
from app.api.routes.app import router as app_router
from app.api.routes.ai import router as ai_router
from app.api.routes.strategy import router as strategy_router
from app.api.routes.strategy_full import router as strategy_full_router
from app.api.routes.knowledge import router as knowledge_router
from app.api.routes.dev_restore import router as dev_restore_router
from app.api.routes.pillars import router as pillars_router
from app.api.routes.crm import router as crm_router
from app.api.routes.metrics import router as metrics_router
from app.api.routes.pillar_reports import router as pillar_reports_router
from app.api.routes.mentor_admin import router as mentor_admin_router

from app.api.routes.mentee_journey import router as mentee_journey_router

app = FastAPI(title="Mentoria AI API", version="2.26.1")

# Browser clients require CORS. In development the default accepts any origin.
# In production set CORS_ORIGINS to a comma-separated list of trusted URLs.
_cors_raw = os.getenv("CORS_ORIGINS", "*").strip()
_cors_origins = [x.strip() for x in _cors_raw.split(",") if x.strip()] or ["*"]
app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_origins,
    allow_credentials="*" not in _cors_origins,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("startup")
def startup():
    Base.metadata.create_all(bind=engine)
    run_lightweight_migrations()


@app.get("/health")
def health():
    return {"status":"ok","version":"2.26.1"}

app.include_router(voice_router, prefix="/api/v1")
app.include_router(conversation_router, prefix="/api/v1")
app.include_router(auth_router, prefix="/api/v1")
app.include_router(app_router, prefix="/api/v1")
app.include_router(ai_router, prefix="/api/v1")
app.include_router(strategy_router, prefix="/api/v1")
app.include_router(pillars_router, prefix="/api/v1")
app.include_router(crm_router, prefix="/api/v1")
app.include_router(metrics_router, prefix="/api/v1")

app.include_router(strategy_full_router, prefix="/api/v1")
app.include_router(knowledge_router, prefix="/api/v1")

app.include_router(dev_restore_router, prefix="/api/v1")
app.include_router(pillar_reports_router, prefix="/api/v1")
app.include_router(mentor_admin_router, prefix="/api/v1")
app.include_router(mentee_journey_router, prefix="/api/v1")
