from fastapi import APIRouter, Depends
from sqlalchemy import select, func
from sqlalchemy.orm import Session
from app.api.deps import current_user
from app.db.session import get_db
from app.models.user import User
from app.models.crm import Lead, Sale, LeadFollowUp
from datetime import date
from app.models.metrics import CommercialMetric
from app.schemas.crm import MetricCreate

router = APIRouter(prefix="/metrics", tags=["metrics"])

@router.post("")
def save_metric(data: MetricCreate, user: User = Depends(current_user), db: Session = Depends(get_db)):
    db.scalar(select(User).where(User.id == user.id).with_for_update())
    row = db.scalar(select(CommercialMetric).where(CommercialMetric.user_id == user.id,
        CommercialMetric.period == data.period).order_by(CommercialMetric.created_at.desc(), CommercialMetric.id.desc()).limit(1))
    if row is None:
        row = CommercialMetric(user_id=user.id, **data.model_dump())
        db.add(row)
    else:
        for key, value in data.model_dump().items():
            setattr(row, key, value)
    db.commit(); db.refresh(row)
    return {"id": row.id, "ok": True}

@router.get("/summary")
def summary(user: User = Depends(current_user), db: Session = Depends(get_db)):
    leads = db.scalar(select(func.count()).select_from(Lead).where(Lead.user_id == user.id)) or 0
    sales = db.scalar(select(func.count()).select_from(Sale).where(Sale.user_id == user.id)) or 0
    revenue = db.scalar(select(func.coalesce(func.sum(Sale.amount), 0)).where(Sale.user_id == user.id)) or 0
    buyers = db.scalar(select(func.count(func.distinct(Sale.lead_id))).join(Lead, Lead.id == Sale.lead_id)
        .where(Sale.user_id == user.id, Lead.user_id == user.id)) or 0
    overdue = db.scalar(select(func.count()).select_from(LeadFollowUp).where(
        LeadFollowUp.user_id == user.id, LeadFollowUp.status == 'pending', LeadFollowUp.due_date < date.today())) or 0
    return {"leads": leads, "sales_count": sales, "revenue": float(revenue),
            "buyers": buyers, "average_ticket": round(float(revenue)/sales, 2) if sales else None,
            "overdue_follow_ups": overdue,
            "conversion_rate": round((buyers / leads) * 100, 2) if leads else None}

@router.get("/history")
def history(user: User = Depends(current_user), db: Session = Depends(get_db)):
    rows = db.scalars(select(CommercialMetric).where(
        CommercialMetric.user_id == user.id).order_by(CommercialMetric.created_at.desc())).all()
    return [{
        "id":r.id,"period":r.period,"leads":r.leads,"calls":r.calls,"sales_count":r.sales_count,
        "revenue":r.revenue,"ad_spend":r.ad_spend,
        "conversion_rate":round((r.sales_count/r.calls)*100,2) if r.calls else None,
        "cpl":round(r.ad_spend/r.leads,2) if r.leads else None,
        "cac":round(r.ad_spend/r.sales_count,2) if r.sales_count else None,
        "revenue_ad_ratio":round(r.revenue/r.ad_spend,2) if r.ad_spend else None,
        "roi":round(((r.revenue-r.ad_spend)/r.ad_spend)*100,2) if r.ad_spend else None
    } for r in rows]
