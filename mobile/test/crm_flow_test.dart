import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentoria_ai/screens/crm_screen.dart';
import 'package:mentoria_ai/screens/crm_form_screen.dart';
import 'package:mentoria_ai/screens/crm_labels.dart';
import 'strategy_action_test.dart' as shared;
import 'pillar_navigation_test.dart' as mock;
import 'package:shared_preferences/shared_preferences.dart';

class Client extends mock.Client {
  Client() : super([]);
  bool fail = false;
  final bodies = <Map<String, dynamic>>[];
  @override
  Future<HttpClientRequest> openUrl(String method, Uri uri) async {
    if (method != 'GET')
      return shared.Request({'ok': true},
          code: fail ? 500 : 200, onBody: (body) => bodies.add(body));
    if (uri.path.endsWith('/leads'))
      return shared.Request([
        {
          'id': '1',
          'name': 'Maria',
          'contact': 'maria@test',
          'stage': 'qualified',
          'source': 'instagram',
          'notes': 'Interessada',
          'next_follow_up': '2001-01-01'
        },
        {
          'id': '2',
          'name': 'Ana',
          'contact': 'ana@test',
          'stage': 'new',
          'source': 'indicacao',
          'notes': ''
        }
      ]);
    return shared.Request([
      {
        'id': 'sale1',
        'lead_name': 'Maria',
        'amount': 1200.5,
        'product': 'Mentoria',
        'source': 'instagram',
        'created_at': '2026-09-01'
      }
    ]);
  }
}

class Overrides extends HttpOverrides {
  Overrides(this.client);
  final Client client;
  @override
  HttpClient createHttpClient(SecurityContext? context) => client;
}

void setup(Client client) {
  SharedPreferences.setMockInitialValues({});
  final previous = HttpOverrides.current;
  HttpOverrides.global = Overrides(client);
  addTearDown(() => HttpOverrides.global = previous);
}

void main() {
  test('valores em reais aceitam formato brasileiro sem truncar centavos', () {
    expect(CrmLabels.amount('1.200,50'), 1200.5);
    expect(CrmLabels.amount('1200.50'), 1200.5);
    expect(CrmLabels.amount('1.200'), 1200);
    expect(CrmLabels.amount('1,2,3'), isNull);
    expect(CrmLabels.amount('NaN'), isNull);
    expect(CrmLabels.money(1200.5), 'R\$ 1.200,50');
  });
  testWidgets('CRM busca contato e exibe vendas em português', (tester) async {
    setup(Client());
    await tester.pumpWidget(shared.app(const CrmScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Qualificado'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'maria@test');
    await tester.pumpAndSettle();
    expect(find.text('Maria'), findsOneWidget);
    expect(find.text('Ana'), findsNothing);
    await tester.tap(find.text('Vendas'));
    await tester.pumpAndSettle();
    expect(find.text('1 vendas • R\$ 1.200,50'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('venda preserva dados e chave da tentativa quando falha',
      (tester) async {
    final client = Client()..fail = true;
    setup(client);
    await tester.binding.setSurfaceSize(const Size(450, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(shared.app(const CrmFormScreen(
        kind: CrmFormKind.sale,
        lead: {
          'id': '1',
          'name': 'Maria',
          'expected_value': 1200.5,
          'source': 'manual'
        })));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar venda'));
    await tester.pumpAndSettle();
    expect(client.bodies.single['amount'], 1200.5);
    expect(find.text('Confirmar venda'), findsOneWidget);
    final id = client.bodies.single['request_id'];
    client.fail = false;
    await tester.tap(find.text('Confirmar venda'));
    await tester.pumpAndSettle();
    expect(client.bodies.last['request_id'], id);
    expect(client.bodies.length, 2);
    expect(tester.takeException(), isNull);
  });
  testWidgets('retorno envia data e observação', (tester) async {
    final client = Client();
    setup(client);
    await tester.binding.setSurfaceSize(const Size(450, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(shared.app(const CrmFormScreen(
        kind: CrmFormKind.followUp, lead: {'id': '1', 'name': 'Maria'})));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Retomar proposta');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(client.bodies.single['notes'], 'Retomar proposta');
    expect(client.bodies.single['due_date'],
        matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
  });
  testWidgets('nome inválido não envia novo contato', (tester) async {
    final client = Client();
    setup(client);
    await tester.binding.setSurfaceSize(const Size(450, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester
        .pumpWidget(shared.app(const CrmFormScreen(kind: CrmFormKind.contact)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(client.bodies, isEmpty);
    expect(find.text('Informe pelo menos dois caracteres.'), findsOneWidget);
  });
}
