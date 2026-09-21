import ast
from pathlib import Path
from types import SimpleNamespace as NS
import unittest

ROOT = Path(__file__).resolve().parent.parent
methodology = {}
exec((ROOT / 'app/ai/methodology_full.py').read_text(encoding='utf-8'), methodology)
tree = ast.parse((ROOT / 'app/api/routes/app.py').read_text(encoding='utf-8'))
function = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == 'pillars')
function.decorator_list = []
function.args.defaults = []
for arg in function.args.args:
    arg.annotation = None

class Query:
    user_id = None
    def where(self, *args): return self

namespace = dict(methodology, select=lambda *_: Query(), PillarProgress=Query,
                 DiagnosisAnswer=Query, PillarReport=Query,
                 PILLARS=[('positioning', 'Posicionamento Único')])
exec(compile(ast.Module(body=[function], type_ignores=[]), '<actual pillars route>', 'exec'), namespace)

class ProgressTests(unittest.TestCase):
    def result(self, count=0, stored=None, report=None, review=False):
        questions = methodology['get_pillar']('positioning')['questions']
        answers = [NS(pillar_key='positioning', question_key=q['key'], status='needs_review' if review else 'answered_ai') for q in questions[:count]]
        rows = iter([[stored] if stored else [], answers, [report] if report else []])
        db = NS(scalars=lambda _: NS(all=lambda: next(rows)))
        return namespace['pillars'](NS(id='user'), db)[0]

    def test_missing_progress_uses_answers(self):
        n = len(methodology['get_pillar']('positioning')['questions'])
        self.assertEqual(self.result(n-1)['score'], round((n-1)*100/n))

    def test_stale_zero_uses_answers(self):
        result = self.result(2, NS(pillar_key='positioning', score=0))
        self.assertGreater(result['score'], 0)
        self.assertEqual(result['status'], 'in_diagnosis')

    def test_answered_does_not_mean_report_completed(self):
        result = self.result(100)
        self.assertEqual((result['score'], result['status']), (100, 'answered_ai'))

    def test_report_requires_complement(self):
        self.assertEqual(self.result(100, report=NS(pillar_key='positioning', ready_for_next='false'))['status'], 'needs_report_completion')

    def test_valid_report_is_completed(self):
        result = self.result(report=NS(pillar_key='positioning', ready_for_next='true'))
        self.assertEqual((result['score'], result['status']), (100, 'validated'))

    def test_new_user(self):
        self.assertEqual((self.result()['score'], self.result()['status']), (0, 'not_started'))

    def test_review_is_in_progress(self):
        self.assertEqual(self.result(1, review=True)['status'], 'in_diagnosis')

if __name__ == '__main__':
    for path in ROOT.rglob('*.py'):
        ast.parse(path.read_text(encoding='utf-8-sig'), filename=str(path))
    unittest.main()
