import ast
import json
import unittest
from datetime import date
from types import SimpleNamespace as NS
import test_pillar_flow as base
from sqlalchemy import select, func
from pydantic import ValidationError

ns = base.ns
for filename, classname in [('strategy.py','ActionPlanItem'), ('strategic_report.py','StrategicReport')]:
    tree=ast.parse((base.ROOT/'app/models'/filename).read_text(encoding='utf-8'))
    imports=[n for n in tree.body if isinstance(n,(ast.Import,ast.ImportFrom)) and not(isinstance(n,ast.ImportFrom) and n.module.startswith('app.'))]
    cls=next(n for n in tree.body if isinstance(n,ast.ClassDef) and n.name==classname)
    exec(compile(ast.Module(body=imports+[cls],type_ignores=[]),filename,'exec'),ns)
schema={}
exec((base.ROOT/'app/schemas/strategy.py').read_text(encoding='utf-8'),schema)
Patch=schema['ActionPlanStatusUpdate']
class HTTPException(Exception):
    def __init__(self,status_code,detail): self.status_code=status_code;super().__init__(detail)
ns.update(User=base.User,func=func,HTTPException=HTTPException,PILLARS=['positioning','promise','funnel','closing'])
base.load_functions('app/api/routes/strategy.py',['get_action_plan','update_action_plan_item'])
base.load_functions('app/api/routes/strategy_full.py')
Action,Report=ns['ActionPlanItem'],ns['StrategicReport']

class StrategyTests(unittest.TestCase):
    def setUp(self):
        self.engine=base.create_engine('sqlite://')
        base.Base.metadata.create_all(self.engine)
        self.db=base.Session(self.engine)
        self.db.add(base.User(id='u'));self.db.add(base.User(id='other'));self.db.commit()
        self.user=NS(id='u',approved_by_user_id='mentor')
        self.calls=[]
        self.response=dict(executive_summary='Estratégia',stage_summary='Momento atual',strengths=[],gaps=[],priorities=['Prioridade'],
            pillar_summaries={k:k for k in ns['PILLARS']},recommendations=['Recomendação'],model_used='stub',mode='test',
            action_plan=[dict(pillar_key='positioning',title='Ação estratégica',description='Descrição concreta',priority='high')])
        def generate(*args): self.calls.append(args);return self.response
        ns.update(generate_report=generate,configured=lambda:True,commercial_context=lambda db,user:{},
            mentor_context_for_user=lambda db,mentor:{'metodologia':mentor})
    def tearDown(self):self.db.close();self.engine.dispose()
    def validate(self):
        for key in ns['PILLARS']:
            self.db.add(base.Report(user_id='u',pillar_key=key,ready_for_next='true',summary='Plano validado',mentor_review_note='Revisão humana'))
        self.db.commit()
    def action(self,**values):
        row=Action(user_id='u',pillar_key='positioning',title='Ação estratégica',**values)
        self.db.add(row);self.db.commit();return row
    def update(self,row,**values):return ns['update_action_plan_item'](row.id,Patch(**values),self.user,self.db)
    def test_requires_all_validated_reports(self):
        with self.assertRaises(HTTPException) as result:ns['generate_full_strategy'](self.user,self.db)
        self.assertEqual(result.exception.status_code,409);self.assertFalse(self.calls)
    def test_generation_uses_reviewed_plans_and_methodology(self):
        self.validate();ns['generate_full_strategy'](self.user,self.db)
        self.assertEqual(self.calls[0][2]['positioning']['mentor_review_note'],'Revisão humana')
        self.assertEqual(self.calls[0][3],{'metodologia':'mentor'})
        self.assertEqual(len(ns['get_action_plan'](self.user,self.db)),1)
    def test_generation_preserves_existing_action_and_retry(self):
        row=self.action(status='done',notes='Já executada',due_date=date(2026,9,10));self.validate()
        ns['generate_full_strategy'](self.user,self.db)
        ns['generate_full_strategy'](self.user,self.db)
        self.assertEqual(len(self.calls),1)
        rows=ns['get_action_plan'](self.user,self.db)
        self.assertEqual(len(rows),1);self.assertEqual(rows[0]['id'],row.id)
        self.assertEqual(rows[0]['notes'],'Já executada');self.assertEqual(rows[0]['status'],'done')
    def test_patch_retains_other_fields_and_date_roundtrip(self):
        row=self.action(notes='Anotação',priority='high',due_date=date(2026,9,10))
        self.update(row,status='in_progress');self.db.expire_all()
        item=ns['get_action_plan'](self.user,self.db)[0]
        self.assertEqual(item['notes'],'Anotação');self.assertEqual(item['due_date'],date(2026,9,10))
        self.assertEqual(item['priority'],'high')
        self.update(row,due_date=None);self.assertIsNone(row.due_date)
    def test_completion_timestamp_and_reopen(self):
        row=self.action();self.update(row,status='done');stamp=row.completed_at
        self.assertIsNotNone(stamp)
        self.update(row,status='done');self.assertEqual(row.completed_at,stamp)
        self.update(row,status='pending');self.assertIsNone(row.completed_at)
    def test_cannot_update_another_user(self):
        row=self.action();row.user_id='other';self.db.commit()
        with self.assertRaises(HTTPException) as result:self.update(row,notes='não deve salvar')
        self.assertEqual(result.exception.status_code,404)
        self.assertEqual(ns['get_action_plan'](self.user,self.db),[])
    def test_invalid_values_and_empty_patch(self):
        for data in [{},{'status':None},{'status':'finished'},{'priority':'urgent'},{'notes':None},{'notes':'x'*5001},{'due_date':'2026-02-30'}]:
            with self.subTest(data=str(data)[:70]),self.assertRaises(ValidationError):Patch(**data)
        self.assertEqual(Patch(due_date=None).model_dump(exclude_unset=True),{'due_date':None})

if __name__=='__main__':unittest.main()
