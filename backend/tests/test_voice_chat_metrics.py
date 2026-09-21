import io
import json
import os
import unittest
import uuid
import wave
from datetime import date, timedelta
from types import SimpleNamespace as NS
from unittest.mock import patch

# Tests never use the deployed database or call the AI provider.
os.environ['DATABASE_URL'] = 'sqlite://'
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select, func
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool
from app.main import app
from app.api.deps import current_user
from app.db.session import Base, get_db
from app.core.config import settings
from app.models.user import User
from app.models.conversation import VoiceAnswer, PlanConversation
from app.models.diagnosis import DiagnosisAnswer
from app.models.pillar_report import PillarReport
from app.models.mentor_settings import MentorSettings
from app.models.crm import Lead, Sale, LeadFollowUp
from app.models.metrics import CommercialMetric
from app.services.voice_answers import attach_voice
from app.ai.methodology_full import get_pillar


def wav(seconds=1):
    buf = io.BytesIO()
    with wave.open(buf, 'wb') as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(16000)
        f.writeframes(b'\x01\x00' * int(seconds * 16000))
    return buf.getvalue()


class VoiceChatMetricsTests(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine('sqlite://', connect_args={'check_same_thread': False}, poolclass=StaticPool)
        Base.metadata.create_all(self.engine)
        self.db = Session(self.engine)
        self.users = {}
        for name, role in [('u','mentee'),('other','mentee'),('mentor','mentor'),('stranger','mentor')]:
            user = User(id=name, name=name, email=f'{name}@example.com', password_hash='test',
                role=role, approval_status='active', approved_by_user_id='mentor')
            self.users[name] = user; self.db.add(user)
        self.db.commit()
        self.user = self.users['u']
        app.dependency_overrides[current_user] = lambda: self.user
        app.dependency_overrides[get_db] = lambda: self.db
        self.client = TestClient(app, raise_server_exceptions=False)
        self.q = get_pillar('positioning')['questions'][0]['key']
    def tearDown(self):
        app.dependency_overrides.clear(); self.client.close(); self.db.close(); self.engine.dispose()
    def upload(self, q=None, raw=None, identifier=None):
        identifier = identifier or str(uuid.uuid4())
        result = self.client.put(f'/api/v1/voice/{identifier}',params={'pillar_key':'positioning','question_key':q or self.q},content=wav() if raw is None else raw)
        self.assertEqual(result.status_code,200,result.text)
        return result.json()['id']
    def report(self):
        self.db.add(PillarReport(user_id='u',pillar_key='positioning', summary='Comece com sua experiência real',
            ready_for_next='false', completion_question='Qual experiência você já tem?', mentor_review_note='Nota importante'))
        self.db.commit()
    def test_audio_persistence_retry_and_access(self):
        audio_id = self.upload()
        self.upload(identifier=audio_id)
        self.assertEqual(self.db.scalar(select(func.count()).select_from(VoiceAnswer)),1)
        self.assertEqual(self.client.get(f'/api/v1/voice/{audio_id}/audio').content,wav())
        self.user=self.users['mentor']
        self.assertEqual(self.client.get(f'/api/v1/voice/{audio_id}/audio').status_code,403)
        attach_voice(self.db,'u','positioning',self.q,audio_id,self.q,'Resposta revisada')
        self.db.commit()
        self.assertEqual(self.client.get(f'/api/v1/voice/{audio_id}/audio').status_code,200)
        self.assertEqual(self.client.get('/api/v1/voice',params={'pillar_key':'positioning','owner_id':'u'}).json()[0]['submitted_text'],'Resposta revisada')
        for name in ['other','stranger']:
            self.user=self.users[name]
            self.assertEqual(self.client.get(f'/api/v1/voice/{audio_id}/audio').status_code,403)
            self.assertEqual(self.client.get('/api/v1/voice',params={'pillar_key':'positioning','owner_id':'u'}).status_code,403)
    def test_audio_rejects_wrong_question_other_owner_and_invalid_files(self):
        audio_id=self.upload()
        from fastapi import HTTPException
        for owner,pillar,q in [('other','positioning',self.q),('u','promise',self.q),('u','positioning','wrong')]:
            with self.assertRaises(HTTPException): attach_voice(self.db,owner,pillar,q,audio_id,q,'texto')
        result=self.client.put(f'/api/v1/voice/{uuid.uuid4()}',params={'pillar_key':'positioning','question_key':self.q},content=b'not audio')
        self.assertEqual(result.status_code,422)
        with patch('app.api.routes.voice.MAX_BYTES',100):
            result=self.client.put(f'/api/v1/voice/{uuid.uuid4()}',params={'pillar_key':'positioning','question_key':self.q},content=wav())
            self.assertEqual(result.status_code,413)
        self.db.rollback()
        self.user.approval_status='blocked';self.db.commit()
        self.assertEqual(self.client.get(f'/api/v1/voice/{audio_id}/audio').status_code,403)
    def test_transcription_failure_keeps_audio_retry_caches_text(self):
        audio_id=self.upload()
        with patch.object(settings,'openai_api_key','fake'),patch('app.api.routes.voice.OpenAI',side_effect=RuntimeError('offline')):
            self.assertEqual(self.client.post(f'/api/v1/voice/{audio_id}/transcribe').status_code,503)
        self.assertEqual(self.client.get(f'/api/v1/voice/{audio_id}/audio').status_code,200)
        create=__import__('unittest.mock',fromlist=['Mock']).Mock(return_value=NS(text='Minha experiência real'))
        fake=NS(audio=NS(transcriptions=NS(create=create)))
        with patch.object(settings,'openai_api_key','fake'),patch('app.api.routes.voice.OpenAI',return_value=fake):
            for _ in range(2):
                r=self.client.post(f'/api/v1/voice/{audio_id}/transcribe')
                self.assertEqual(r.json()['transcript'],'Minha experiência real')
        self.assertEqual(create.call_count,1)
        self.assertEqual(self.client.delete(f'/api/v1/voice/{audio_id}').status_code,200)
        self.assertEqual(self.client.get(f'/api/v1/voice/{audio_id}/audio').status_code,404)
    def test_answer_attaches_audio_and_preserves_original(self):
        audio_id=self.upload()
        with patch('app.api.routes.pillars.configured',return_value=False):
            r=self.client.post('/api/v1/pillars/positioning/answer',json={'question_key':self.q,'answer_text':'Minha experiência pessoal e profissional é em educação financeira há vários anos.','audio_id':audio_id})
        self.assertEqual(r.status_code,200,r.text)
        row=self.db.get(VoiceAnswer,audio_id)
        self.assertEqual(row.answer_key,self.q)
        self.assertEqual(row.audio,wav())
        self.assertEqual(self.client.delete(f'/api/v1/voice/{audio_id}').status_code,409)
    def test_complement_retry_does_not_duplicate_saved_audio_answer(self):
        self.report();audio_id=self.upload(q='report_complement')
        payload={'answer_text':'Minha experiência foi organizar o orçamento da família.','audio_id':audio_id}
        with patch('app.api.routes.pillar_reports.generate_pillar_report',side_effect=RuntimeError('offline')):
            self.client.post('/api/v1/pillar-reports/positioning/complete',json=payload)
            self.client.post('/api/v1/pillar-reports/positioning/complete',json=payload)
        count=self.db.scalar(select(func.count()).select_from(DiagnosisAnswer))
        self.assertEqual(count,1)
        self.assertEqual(self.db.get(VoiceAnswer,audio_id).answer_key,'report_followup_1')
    def test_chat_context_retry_history_and_no_progress_mutation(self):
        self.report()
        self.db.add(DiagnosisAnswer(user_id='u',pillar_key='positioning',question_key=self.q,answer_text='Organizei as finanças de casa.'))
        self.db.add(MentorSettings(mentor_user_id='mentor',tone_of_voice='Use show de bola.',freeform_methodology_notes='Começar sem clientes é possível.'))
        self.db.commit()
        calls=[]
        def create(**kwargs):calls.append(kwargs);return NS(output_text='Show de bola! Você pode começar pela experiência que relatou.')
        payload={'request_id':str(uuid.uuid4()),'question':'Como começo sem resultados de clientes?'}
        with patch.object(settings,'openai_api_key','fake'),patch('app.api.routes.plan_conversation.OpenAI',return_value=NS(responses=NS(create=create))):
            for _ in range(2):
                result=self.client.post('/api/v1/plan-conversations/positioning',json=payload)
                self.assertEqual(result.status_code,200,result.text)
        self.assertEqual(len(calls),1)
        context=json.loads(calls[0]['input'])
        self.assertEqual(context['mentor_preferences']['tone_of_voice'],'Use show de bola.')
        self.assertEqual(context['answers'][0]['answer'],'Organizei as finanças de casa.')
        self.assertEqual(context['current_plan']['mentor_note'],'Nota importante')
        self.assertIn('NÃO impede começar',calls[0]['instructions'])
        self.assertEqual(len(self.client.get('/api/v1/plan-conversations/positioning').json()),1)
        self.assertEqual(self.db.scalar(select(PillarReport)).ready_for_next,'false')
        self.user=self.users['other'];self.assertEqual(self.client.get('/api/v1/plan-conversations/positioning').status_code,409)
    def test_chat_failure_does_not_save_fake_reply(self):
        self.report()
        with patch.object(settings,'openai_api_key','fake'),patch('app.api.routes.plan_conversation.OpenAI',side_effect=RuntimeError('offline')):
            r=self.client.post('/api/v1/plan-conversations/positioning',json={'request_id':str(uuid.uuid4()),'question':'Como começar?'})
        self.assertEqual(r.status_code,503)
        self.assertEqual(self.db.scalar(select(func.count()).select_from(PlanConversation)),0)
    def test_metrics_unique_buyers_manual_upsert_and_validation(self):
        self.db.add(Lead(id='lead',user_id='u',name='Contato'));self.db.flush()
        self.db.add_all([Sale(user_id='u',lead_id='lead',amount=100),Sale(user_id='u',lead_id='lead',amount=200),Sale(user_id='other',amount=5000)])
        self.db.add(LeadFollowUp(user_id='u',lead_id='lead',due_date=date.today()-timedelta(days=1)))
        self.db.commit()
        data=self.client.get('/api/v1/metrics/summary').json()
        self.assertEqual(data['conversion_rate'],100)
        self.assertEqual(data['average_ticket'],150)
        self.assertEqual(data['overdue_follow_ups'],1)
        for revenue in [100,200]:
            r=self.client.post('/api/v1/metrics',json={'period':'2026-09','revenue':revenue})
            self.assertEqual(r.status_code,200,r.text)
        rows=self.client.get('/api/v1/metrics/history').json()
        self.assertEqual(len(rows),1);self.assertEqual(rows[0]['revenue'],200)
        self.assertIsNone(rows[0]['conversion_rate']);self.assertIsNone(rows[0]['revenue_ad_ratio'])
        self.assertEqual(self.client.post('/api/v1/metrics',json={'period':'2026-13'}).status_code,422)
        self.assertEqual(self.client.post('/api/v1/metrics',json={'period':'2026-09','revenue':-1}).status_code,422)
    def test_dev_elevation_disabled_by_default(self):
        self.assertEqual(self.client.post('/api/v1/dev/make-me-mentor').status_code,403)
        self.assertEqual(self.user.role,'mentee')

    def test_chat_audio_attached_only_on_success_and_restored_in_history(self):
        self.report(); audio_id=self.upload(q='plan_chat')
        payload={'request_id':str(uuid.uuid4()),'question':'Como começo com o que já vivi?','audio_id':audio_id}
        with patch.object(settings,'openai_api_key','fake'),patch('app.api.routes.plan_conversation.OpenAI',side_effect=RuntimeError('offline')):
            self.assertEqual(self.client.post('/api/v1/plan-conversations/positioning',json=payload).status_code,503)
        self.assertIsNone(self.db.get(VoiceAnswer,audio_id).answer_key)
        fake=NS(responses=NS(create=lambda **kwargs:NS(output_text='Comece por sua experiência real.')))
        with patch.object(settings,'openai_api_key','fake'),patch('app.api.routes.plan_conversation.OpenAI',return_value=fake):
            for _ in range(2):
                result=self.client.post('/api/v1/plan-conversations/positioning',json=payload)
                self.assertEqual(result.status_code,200,result.text)
                self.assertEqual(result.json()['audio_id'],audio_id)
        rows=self.client.get('/api/v1/plan-conversations/positioning').json()
        self.assertEqual(len(rows),1);self.assertEqual(rows[0]['audio_id'],audio_id)
        self.assertEqual(self.db.get(VoiceAnswer,audio_id).submitted_text,payload['question'])
        self.assertEqual(self.db.scalar(select(PillarReport)).ready_for_next,'false')

if __name__=='__main__':unittest.main()
