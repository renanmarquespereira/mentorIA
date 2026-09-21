from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session
from app.api.deps import current_user
from app.db.session import get_db
from app.models.user import User
from app.models.crm import Lead, Sale, LeadFollowUp
from app.schemas.crm import LeadCreate, LeadStageUpdate, SaleCreate, LeadUpdate, FollowUpCreate, FollowUpUpdate

router = APIRouter(prefix="/crm", tags=["crm"])

def owned_lead(db, user_id, lead_id):
    row = db.scalar(select(Lead).where(Lead.id == lead_id, Lead.user_id == user_id))
    if row is None:
        raise HTTPException(status_code=404, detail="Contato não encontrado")
    return row

def lead_data(row):
    return {"id":row.id,"name":row.name,"contact":row.contact,"source":row.source,"funnel":row.funnel,
            "stage":row.stage,"notes":row.notes,"expected_value":row.expected_value,"created_at":row.created_at}

@router.post("/leads")
def create_lead(data: LeadCreate, user: User = Depends(current_user), db: Session = Depends(get_db)):
    row = Lead(user_id=user.id, **data.model_dump())
    db.add(row); db.commit(); db.refresh(row)
    return {"id": row.id, "ok": True}

@router.get("/leads")
def list_leads(user: User = Depends(current_user), db: Session = Depends(get_db)):
    rows = db.scalars(select(Lead).where(Lead.user_id == user.id).order_by(Lead.created_at.desc())).all()
    pending = db.scalars(select(LeadFollowUp).where(LeadFollowUp.user_id == user.id, LeadFollowUp.status == "pending")).all()
    dates = {}
    for item in pending:
        dates[item.lead_id] = min(dates.get(item.lead_id,item.due_date),item.due_date)
    return [{**lead_data(row), "next_follow_up":dates.get(row.id)} for row in rows]

@router.get("/leads/{lead_id}")
def get_lead(lead_id: str, user: User = Depends(current_user), db: Session = Depends(get_db)):
    return lead_data(owned_lead(db,user.id,lead_id))

@router.patch("/leads/{lead_id}")
def edit_lead(lead_id: str, data: LeadUpdate, user: User = Depends(current_user), db: Session = Depends(get_db)):
    row = owned_lead(db,user.id,lead_id)
    for key,value in data.model_dump(exclude_unset=True).items():
        setattr(row,key,value)
    db.commit()
    return lead_data(row)

@router.patch("/leads/{lead_id}/stage")
def update_stage(lead_id: str, data: LeadStageUpdate, user: User = Depends(current_user), db: Session = Depends(get_db)):
    row = db.scalar(select(Lead).where(Lead.id == lead_id, Lead.user_id == user.id))
    if not row:
        raise HTTPException(status_code=404, detail="Lead não encontrado")
    row.stage = data.stage; db.commit()
    return {"ok": True, "stage": row.stage}

@router.post("/sales")
def create_sale(data: SaleCreate, user: User = Depends(current_user), db: Session = Depends(get_db)):
    db.scalar(select(User).where(User.id == user.id).with_for_update())
    if data.request_id:
        previous = db.scalar(select(Sale).where(Sale.user_id == user.id, Sale.request_id == data.request_id))
        if previous:
            if any(getattr(previous,key) != getattr(data,key) for key in ("lead_id","amount","product","source")):
                raise HTTPException(status_code=409,detail="Esta tentativa já registrou uma venda com outros dados. Confira o histórico antes de registrar outra.")
            return {"id":previous.id,"ok":True,"already_recorded":True}
    lead = owned_lead(db,user.id,data.lead_id) if data.lead_id else None
    row = Sale(user_id=user.id, **data.model_dump())
    db.add(row)
    if lead:
        lead.stage = "closed_won"
    db.commit(); db.refresh(row)
    return {"id": row.id, "ok": True}

@router.get("/sales")
def list_sales(user: User = Depends(current_user), db: Session = Depends(get_db)):
    rows = db.scalars(select(Sale).where(Sale.user_id == user.id).order_by(Sale.created_at.desc())).all()
    names = {row.id:row.name for row in db.scalars(select(Lead).where(Lead.user_id == user.id)).all()}
    return [{"id":r.id,"lead_id":r.lead_id,"lead_name":names.get(r.lead_id),"amount":r.amount,"product":r.product,"source":r.source,"created_at":r.created_at} for r in rows]

@router.get("/leads/{lead_id}/follow-ups")
def list_follow_ups(lead_id: str, user: User = Depends(current_user), db: Session = Depends(get_db)):
    owned_lead(db,user.id,lead_id)
    rows = db.scalars(select(LeadFollowUp).where(LeadFollowUp.user_id == user.id, LeadFollowUp.lead_id == lead_id)
                      .order_by(LeadFollowUp.due_date,LeadFollowUp.created_at)).all()
    return [{"id":r.id,"due_date":r.due_date,"notes":r.notes,"status":r.status,"completed_at":r.completed_at} for r in rows]

@router.post("/leads/{lead_id}/follow-ups")
def create_follow_up(lead_id: str, data: FollowUpCreate, user: User = Depends(current_user), db: Session = Depends(get_db)):
    owned_lead(db,user.id,lead_id)
    row = LeadFollowUp(user_id=user.id,lead_id=lead_id,**data.model_dump())
    db.add(row);db.commit();db.refresh(row)
    return {"ok":True,"id":row.id}

@router.patch("/follow-ups/{follow_up_id}")
def update_follow_up(follow_up_id: str, data: FollowUpUpdate, user: User = Depends(current_user), db: Session = Depends(get_db)):
    row = db.scalar(select(LeadFollowUp).where(LeadFollowUp.id == follow_up_id,LeadFollowUp.user_id == user.id))
    if row is None:
        raise HTTPException(status_code=404,detail="Retorno não encontrado")
    if row.status != data.status:
        row.status = data.status
        row.completed_at = datetime.utcnow() if data.status == "done" else None
    db.commit()
    return {"ok":True,"status":row.status}
