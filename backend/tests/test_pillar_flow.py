import ast
import sys
import unittest
from pathlib import Path
from types import SimpleNamespace as NS

from sqlalchemy import create_engine, select, String
from sqlalchemy.orm import DeclarativeBase, Session, Mapped, mapped_column

ROOT = Path(__file__).resolve().parent.parent
class Base(DeclarativeBase): pass
class User(Base):
    __tablename__ = 'users'
    id: Mapped[str] = mapped_column(String, primary_key=True)

ns = {'Base': Base}
for filename, classname in [('pillar_report.py', 'PillarReport'), ('diagnosis.py', 'DiagnosisAnswer'), ('educator.py', 'PillarProgress')]:
    tree = ast.parse((ROOT / 'app/models' / filename).read_text(encoding='utf-8'))
    nodes = [n for n in tree.body if isinstance(n, (ast.Import, ast.ImportFrom)) and not (isinstance(n, ast.ImportFrom) and n.module.startswith('app.'))]
    cls = next(n for n in tree.body if isinstance(n, ast.ClassDef) and n.name == classname)
    cls.body = [n for n in cls.body if not (isinstance(n, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'user' for t in n.targets))]
    exec(compile(ast.Module(body=nodes+[cls], type_ignores=[]), filename, 'exec'), ns)

def load_functions(path, names=None):
    tree = ast.parse((ROOT / path).read_text(encoding='utf-8'))
    nodes = []
    for n in tree.body:
        if isinstance(n, ast.FunctionDef) and (names is None or n.name in names):
            n.decorator_list = []
            n.returns = None
            n.args.defaults = []
            for arg in n.args.args: arg.annotation = None
            nodes.append(n)
    exec(compile(ast.Module(body=nodes, type_ignores=[]), path, 'exec'), ns)

class HTTPException(Exception):
    def __init__(self, status, detail): self.status_code = status; super().__init__(detail)

import json
ns.update(select=select, json=json, HTTPException=HTTPException, VALID=['positioning','promise','funnel','closing'])
load_functions('app/api/routes/pillar_reports.py')
load_functions('app/api/routes/pillars.py', ['unlocked'])
Report, Answer, Progress = [ns[k] for k in ('PillarReport','DiagnosisAnswer','PillarProgress')]

class FlowTests(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine('sqlite://')
        Base.metadata.create_all(self.engine)
        self.db = Session(self.engine)
        self.db.add(User(id='u')); self.db.commit()
        self.user = NS(id='u', approved_by_user_id='mentor')
        self.calls = []
        self.data = dict(summary='Resumo', perceived_authority='Autoridade', strengths=['Força'], gaps=['Lacuna'],
            missing_information=['Detalhe'], practical_plan=[], ready_for_next=False, completion_question='Pergunta da metodologia?', model_used='stub')
        def generate(key, answers, context):
            self.calls.append((key, answers, context)); return self.data.copy()
        ns.update(configured=lambda: True, generate_pillar_report=generate,
                  mentor_context_for_user=lambda db, mentor: {'metodologia': mentor})
        self.db.add(Answer(user_id='u',pillar_key='positioning',question_key='q1',answer_text='Resposta original'))
        self.db.commit()
    def tearDown(self): self.db.close(); self.engine.dispose()
    def generate(self): return ns['generate_report']('positioning', self.user, self.db)
    def get(self): return ns['get_report']('positioning', self.user, self.db)
    def opened(self): return ns['unlocked'](self.db, 'u', {'requires':'positioning'})
    def test_pending_question_survives_reopen_and_uses_methodology(self):
        self.generate(); self.db.expire_all()
        self.assertEqual(self.get()['completion_question'], 'Pergunta da metodologia?')
        self.assertEqual(self.calls[0][2], {'metodologia':'mentor'})
        self.assertFalse(self.opened())
    def test_100_percent_does_not_unlock_pending_report(self):
        self.generate()
        progress = self.db.scalar(select(Progress)); progress.score=100; progress.status='validated'; self.db.commit()
        self.assertFalse(self.opened())
    def test_valid_report_unlocks_without_progress_row(self):
        self.data['ready_for_next']=True; self.generate()
        self.db.delete(self.db.scalar(select(Progress))); self.db.commit()
        self.assertTrue(self.opened())
    def test_complement_preserves_history_and_mentor_note(self):
        self.generate()
        report = self.db.scalar(select(Report)); report.mentor_review_note='Nota mantida'; report.mentor_review_status='edited'; self.db.commit()
        self.data['ready_for_next']=True; self.data['completion_question']=None
        result = ns['complete_pillar_report']('positioning', NS(answer_text='Complemento detalhado da usuária'), self.user, self.db)
        self.assertEqual(result['mentor_review_note'],'Nota mantida')
        self.assertEqual(result['complement_answers'][0]['answer_text'],'Complemento detalhado da usuária')
        self.assertIn('report_followup_1',self.calls[-1][1])
        self.assertTrue(self.opened())
        again=ns['complete_pillar_report']('positioning',NS(answer_text='Reenvio'),self.user,self.db)
        self.assertEqual(again['summary'], result['summary'])
        self.assertEqual(len(again['complement_answers']),1)
    def test_legacy_question_recovery_preserves_report_and_gate(self):
        self.generate(); report=self.db.scalar(select(Report)); report.completion_question=None; report.summary='Texto revisado'; self.db.commit()
        result=ns['recover_completion_question']('positioning',self.user,self.db)
        self.assertEqual(result['summary'],'Texto revisado')
        self.assertEqual(result['completion_question'],'Pergunta da metodologia?')
        self.assertFalse(self.opened())
    def test_first_module_open_and_missing_report_locked(self):
        self.assertTrue(ns['unlocked'](self.db,'u',{})); self.assertFalse(self.opened())

if __name__ == '__main__': unittest.main()
