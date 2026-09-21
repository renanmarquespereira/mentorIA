from datetime import date, timedelta, datetime
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.orm import Session
from app.api.deps import current_user
from app.db.session import get_db
from app.models.user import User
from app.models.educator import EducatorProfile
from app.models.strategy import ActionPlanItem
from app.models.pillar_report import PillarReport
from app.models.mentee_journey import MenteeCheckIn, MenteeNotification
from app.models.mentor_session import MentorSession
from app.ai.methodology_full import get_pillar

router = APIRouter(tags=['mentee-journey'])
PILLAR_NAMES={'positioning':'Posicionamento Único','promise':'Promessa Atrativa','funnel':'Funil de Venda Poderoso','closing':'Fechamento Irrecusável'}

class ProfileUpdate(BaseModel):
    name: str = Field(min_length=2,max_length=120)
    phone: str = Field(default='',max_length=40)
    profile_photo: str = Field(default='',max_length=1500000)
    city_state: str | None = Field(default=None,max_length=160)
    education: str | None = Field(default=None,max_length=4000)
    experience_months: int = Field(default=0,ge=0)
    has_clients: bool=False
    sells_mentoring: bool=False
    has_professional_instagram: bool=False
    active_clients: int=Field(default=0,ge=0)
    current_ticket: float=Field(default=0,ge=0)
    monthly_revenue: float=Field(default=0,ge=0)
    main_difficulty: str | None=Field(default=None,max_length=5000)
    main_goal: str | None=Field(default=None,max_length=5000)

class CheckInCreate(BaseModel):
    progress: str=Field(min_length=3,max_length=5000)
    blockers: str=Field(default='',max_length=5000)
    next_session_topic: str=Field(min_length=3,max_length=5000)
    confidence_level: int=Field(default=3,ge=1,le=5)

class SessionCancel(BaseModel):
    reason: str=Field(min_length=3,max_length=2000)

def profile_payload(user, profile):
    return {'name':user.name,'email':user.email,'phone':user.phone or '', 'profile_photo':getattr(user,'profile_photo','') or '',
      'city_state':getattr(profile,'city_state',None),'education':getattr(profile,'education',None),'experience_months':getattr(profile,'experience_months',0) or 0,
      'has_clients':bool(getattr(profile,'has_clients',False)),'sells_mentoring':bool(getattr(profile,'sells_mentoring',False)),
      'has_professional_instagram':bool(getattr(profile,'has_professional_instagram',False)),'active_clients':getattr(profile,'active_clients',0) or 0,
      'current_ticket':getattr(profile,'current_ticket',0) or 0,'monthly_revenue':getattr(profile,'monthly_revenue',0) or 0,
      'main_difficulty':getattr(profile,'main_difficulty',None),'main_goal':getattr(profile,'main_goal',None)}

@router.get('/profile')
def get_profile(user:User=Depends(current_user),db:Session=Depends(get_db)):
    p=db.scalar(select(EducatorProfile).where(EducatorProfile.user_id==user.id))
    return profile_payload(user,p)

@router.put('/profile')
def update_profile(data:ProfileUpdate,user:User=Depends(current_user),db:Session=Depends(get_db)):
    user.name=data.name.strip(); user.phone=data.phone.strip(); user.profile_photo=data.profile_photo
    p=db.scalar(select(EducatorProfile).where(EducatorProfile.user_id==user.id))
    if not p: p=EducatorProfile(user_id=user.id); db.add(p)
    for k,v in data.model_dump(exclude={'name','phone','profile_photo'}).items(): setattr(p,k,v)
    db.commit(); return profile_payload(user,p)

@router.get('/my-reports')
def my_reports(user:User=Depends(current_user),db:Session=Depends(get_db)):
    rows=db.scalars(select(PillarReport).where(PillarReport.user_id==user.id)).all()
    return [{'pillar_key':r.pillar_key,'pillar_name':PILLAR_NAMES.get(r.pillar_key,r.pillar_key),'updated_at':r.updated_at,'ready':r.ready_for_next=='true'} for r in rows]

@router.get('/check-ins')
def checkins(user:User=Depends(current_user),db:Session=Depends(get_db)):
    rows=db.scalars(select(MenteeCheckIn).where(MenteeCheckIn.user_id==user.id).order_by(MenteeCheckIn.created_at.desc()).limit(10)).all()
    return [{'id':x.id,'progress':x.progress,'blockers':x.blockers,'next_session_topic':x.next_session_topic,'confidence_level':x.confidence_level or 3,'created_at':x.created_at} for x in rows]

@router.post('/check-ins')
def create_checkin(data:CheckInCreate,user:User=Depends(current_user),db:Session=Depends(get_db)):
    row=MenteeCheckIn(user_id=user.id,**data.model_dump()); db.add(row)
    db.add(MenteeNotification(user_id=user.id,kind='checkin',title='Check-in registrado',message='Sua preparação para a próxima mentoria foi salva.'))
    db.commit(); return {'ok':True,'id':row.id}

@router.get('/my-sessions')
def my_sessions(user:User=Depends(current_user),db:Session=Depends(get_db)):
    rows=db.scalars(select(MentorSession).where(MentorSession.mentee_user_id==user.id,MentorSession.mentee_hidden==False).order_by(MentorSession.scheduled_at.desc())).all()
    now=datetime.utcnow()
    upcoming=sorted([r for r in rows if r.status=='scheduled' and r.scheduled_at>=now],key=lambda r:r.scheduled_at)
    def item(r): return {
        'id':r.id,'scheduled_at':r.scheduled_at,'status':r.status,'subject':r.subject or '',
        'summary':r.summary if r.status=='completed' else '',
        'decisions':r.decisions if r.status=='completed' else '',
        'next_steps':r.next_steps if r.status=='completed' else '',
        'cancellation_reason':r.cancellation_reason if r.status=='canceled' else '',
    }
    return {'sessions':[item(r) for r in rows],'next_session':item(upcoming[0]) if upcoming else None}

@router.post('/my-sessions/{session_id}/cancel')
def cancel_my_session(session_id:str,data:SessionCancel,user:User=Depends(current_user),db:Session=Depends(get_db)):
    row=db.scalar(select(MentorSession).where(MentorSession.id==session_id,MentorSession.mentee_user_id==user.id))
    if not row: raise HTTPException(404,'Sessão não encontrada')
    if row.status!='scheduled': raise HTTPException(409,'Somente mentorias agendadas podem ser canceladas')
    row.status='canceled'; row.cancellation_reason=data.reason.strip()
    db.add(MenteeNotification(user_id=user.id,kind='session',title='Mentoria cancelada',message='O cancelamento e o motivo foram registrados.'))
    db.commit(); return {'ok':True,'status':'canceled','cancellation_reason':row.cancellation_reason}


@router.get('/notifications')
def notifications(user:User=Depends(current_user),db:Session=Depends(get_db)):
    # Cria lembretes de prazo de forma idempotente por mensagem/título recentes.
    soon=date.today()+timedelta(days=3)
    actions=db.scalars(select(ActionPlanItem).where(ActionPlanItem.user_id==user.id,ActionPlanItem.status!='done',ActionPlanItem.due_date!=None,ActionPlanItem.due_date<=soon)).all()
    existing={(n.title,n.message) for n in db.scalars(select(MenteeNotification).where(MenteeNotification.user_id==user.id)).all()}
    for a in actions:
        title='Ação atrasada' if a.due_date < date.today() else 'Prazo de ação próximo'
        msg=f'{a.title} • prazo {a.due_date.strftime("%d/%m/%Y")}'
        if (title,msg) not in existing: db.add(MenteeNotification(user_id=user.id,kind='action',title=title,message=msg))
    db.commit()
    rows=db.scalars(select(MenteeNotification).where(MenteeNotification.user_id==user.id).order_by(MenteeNotification.created_at.desc()).limit(30)).all()
    return [{'id':n.id,'kind':n.kind,'title':n.title,'message':n.message,'is_read':n.is_read,'created_at':n.created_at} for n in rows]

@router.patch('/notifications/{notification_id}/read')
def read_notification(notification_id:str,user:User=Depends(current_user),db:Session=Depends(get_db)):
    n=db.scalar(select(MenteeNotification).where(MenteeNotification.id==notification_id,MenteeNotification.user_id==user.id))
    if not n: raise HTTPException(404,'Aviso não encontrado')
    n.is_read=True; db.commit(); return {'ok':True}

@router.patch('/my-sessions/{session_id}/hide')
def hide_my_session(session_id:str,user:User=Depends(current_user),db:Session=Depends(get_db)):
    row=db.scalar(select(MentorSession).where(MentorSession.id==session_id,MentorSession.mentee_user_id==user.id))
    if not row: raise HTTPException(404,'Sessão não encontrada')
    if row.status!='completed': raise HTTPException(409,'Somente mentorias realizadas podem ser limpas da sua visualização')
    row.mentee_hidden=True; db.commit(); return {'ok':True}

@router.patch('/my-sessions/completed/hide')
def hide_completed_sessions(user:User=Depends(current_user),db:Session=Depends(get_db)):
    rows=db.scalars(select(MentorSession).where(MentorSession.mentee_user_id==user.id,MentorSession.status=='completed',MentorSession.mentee_hidden==False)).all()
    for row in rows: row.mentee_hidden=True
    db.commit(); return {'ok':True,'hidden':len(rows)}

@router.delete('/notifications/{notification_id}')
def delete_notification(notification_id:str,user:User=Depends(current_user),db:Session=Depends(get_db)):
    n=db.scalar(select(MenteeNotification).where(MenteeNotification.id==notification_id,MenteeNotification.user_id==user.id))
    if not n: raise HTTPException(404,'Aviso não encontrado')
    db.delete(n); db.commit(); return {'ok':True}

@router.delete('/notifications')
def clear_notifications(user:User=Depends(current_user),db:Session=Depends(get_db)):
    rows=db.scalars(select(MenteeNotification).where(MenteeNotification.user_id==user.id)).all()
    for n in rows: db.delete(n)
    db.commit(); return {'ok':True,'deleted':len(rows)}
