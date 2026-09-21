import ast
import unittest
from datetime import date
from types import SimpleNamespace as NS
import test_pillar_flow as base
from sqlalchemy import select, func
from pydantic import ValidationError

ns=dict(base.ns)
tree=ast.parse((base.ROOT/'app/models/crm.py').read_text(encoding='utf-8'))
nodes=[n for n in tree.body if not(isinstance(n,ast.ImportFrom) and n.module.startswith('app.'))]
exec(compile(ast.Module(body=nodes,type_ignores=[]),'crm models','exec'),ns)
schema={};exec((base.ROOT/'app/schemas/crm.py').read_text(encoding='utf-8'),schema)
class HTTPException(Exception):
    def __init__(self,status_code,detail):self.status_code=status_code;super().__init__(detail)
ns.update(User=base.User,HTTPException=HTTPException)
routes=ast.parse((base.ROOT/'app/api/routes/crm.py').read_text(encoding='utf-8'))
functions=[]
for node in routes.body:
    if isinstance(node,ast.FunctionDef):
        node.decorator_list=[];node.returns=None;node.args.defaults=[]
        for arg in node.args.args:arg.annotation=None
        functions.append(node)
exec(compile(ast.Module(body=functions,type_ignores=[]),'crm routes','exec'),ns)
Lead,Sale,FollowUp=(ns[name] for name in ('Lead','Sale','LeadFollowUp'))

class CrmTests(unittest.TestCase):
    def setUp(self):
        self.engine=base.create_engine('sqlite://');base.Base.metadata.create_all(self.engine)
        self.db=base.Session(self.engine);self.db.add_all([base.User(id='u'),base.User(id='other')]);self.db.commit()
        self.user=NS(id='u');self.other=NS(id='other')
        self.lead=Lead(user_id='u',name='Maria',contact='maria@test',notes='Preservar',expected_value=1200)
        self.db.add(self.lead);self.db.commit()
    def tearDown(self):self.db.close();self.engine.dispose()
    def sale(self,**kwargs):
        return ns['create_sale'](schema['SaleCreate'](lead_id=self.lead.id,amount=1200.5,request_id='retry-1',**kwargs),self.user,self.db)
    def test_edit_preserves_fields_not_sent(self):
        ns['edit_lead'](self.lead.id,schema['LeadUpdate'](contact='novo@test'),self.user,self.db)
        self.assertEqual(self.lead.notes,'Preservar');self.assertEqual(self.lead.expected_value,1200)
        self.assertEqual(self.lead.contact,'novo@test')
    def test_follow_up_roundtrip_and_completion(self):
        result=ns['create_follow_up'](self.lead.id,schema['FollowUpCreate'](due_date='2026-10-01',notes='Retomar conversa'),self.user,self.db)
        self.db.expire_all();items=ns['list_follow_ups'](self.lead.id,self.user,self.db)
        self.assertEqual(items[0]['notes'],'Retomar conversa')
        self.assertEqual(ns['list_leads'](self.user,self.db)[0]['next_follow_up'],date(2026,10,1))
        ns['update_follow_up'](result['id'],schema['FollowUpUpdate'](status='done'),self.user,self.db)
        self.assertIsNone(ns['list_leads'](self.user,self.db)[0]['next_follow_up'])
        ns['update_follow_up'](result['id'],schema['FollowUpUpdate'](status='pending'),self.user,self.db)
        self.assertIsNone(ns['list_follow_ups'](self.lead.id,self.user,self.db)[0]['completed_at'])
    def test_sale_retry_does_not_duplicate(self):
        first=self.sale();second=self.sale()
        self.assertEqual(first['id'],second['id']);self.assertTrue(second['already_recorded'])
        self.assertEqual(self.db.scalar(select(func.count()).select_from(Sale)),1)
        self.assertEqual(self.lead.stage,'closed_won')
        self.assertEqual(ns['list_sales'](self.user,self.db)[0]['lead_name'],'Maria')
    def test_retry_with_changed_payload_rejected(self):
        self.sale()
        with self.assertRaises(HTTPException) as result:
            ns['create_sale'](schema['SaleCreate'](lead_id=self.lead.id,amount=999,request_id='retry-1'),self.user,self.db)
        self.assertEqual(result.exception.status_code,409)
        self.assertEqual(self.db.scalar(select(func.count()).select_from(Sale)),1)
    def test_foreign_contact_sale_rejected_without_insert(self):
        with self.assertRaises(HTTPException):
            ns['create_sale'](schema['SaleCreate'](lead_id=self.lead.id,amount=100),self.other,self.db)
        self.assertEqual(self.db.scalar(select(func.count()).select_from(Sale)),0)
        self.assertNotEqual(self.lead.stage,'closed_won')
    def test_foreign_follow_up_and_edit_rejected(self):
        with self.assertRaises(HTTPException):ns['create_follow_up'](self.lead.id,schema['FollowUpCreate'](due_date='2026-10-01'),self.other,self.db)
        with self.assertRaises(HTTPException):ns['edit_lead'](self.lead.id,schema['LeadUpdate'](name='Outro'),self.other,self.db)
        self.assertEqual(ns['list_leads'](self.other,self.db),[])
        self.assertEqual(ns['list_sales'](self.other,self.db),[])
    def test_invalid_inputs(self):
        for model,data in [('LeadCreate',{'name':'  '}),('LeadStageUpdate',{'stage':'invalid'}),('SaleCreate',{'amount':float('inf')}),('SaleCreate',{'amount':-1}),('FollowUpCreate',{'due_date':'2026-02-30'}),('LeadUpdate',{}),('LeadUpdate',{'name':None})]:
            with self.subTest(model=model),self.assertRaises(ValidationError):schema[model](**data)

if __name__=='__main__':unittest.main()
