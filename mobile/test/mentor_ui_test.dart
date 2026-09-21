import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mentoria_ai/screens/mentor_admin_screen.dart';
import 'package:mentoria_ai/screens/mentor_edit_pillar_report_screen.dart';
import 'package:mentoria_ai/screens/pillar_screen.dart';
import 'pillar_navigation_test.dart' as mock;

class CaptureRequest extends mock.Request {
  CaptureRequest(super.data, this.capture);
  final void Function(Object) capture;
  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    final bytes = await stream.fold<List<int>>([], (a, b) => a..addAll(b));
    if (bytes.isNotEmpty) capture(jsonDecode(utf8.decode(bytes)));
  }
}

class Client extends mock.Client {
  Client(this.response) : super([]);
  final Object response;
  Object? sent;
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      CaptureRequest(response, (value) => sent = value);
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
  testWidgets('desbloqueadas primeiro, mantendo busca e ordem dos demais',
      (tester) async {
    setup(Client([
      {
        'id': '1',
        'name': 'Ana pendente',
        'email': 'ana@test',
        'approval_status': 'pending_approval'
      },
      {
        'id': '2',
        'name': 'Bia ativa',
        'email': 'bia@test',
        'approval_status': 'active'
      },
      {
        'id': '3',
        'name': 'Clara bloqueada',
        'email': 'clara@test',
        'approval_status': 'rejected'
      },
      {
        'id': '4',
        'name': 'Dora ativa',
        'email': 'dora@test',
        'approval_status': 'active'
      },
    ]));
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: MentorAdminScreen()));
    await tester.pumpAndSettle();
    final names = [
      'Bia ativa',
      'Dora ativa',
      'Ana pendente',
      'Clara bloqueada'
    ];
    final ys =
        names.map((name) => tester.getTopLeft(find.text(name)).dy).toList();
    expect(ys, orderedEquals([...ys]..sort()));
    await tester.enterText(find.byType(TextField), 'ana@test');
    await tester.pumpAndSettle();
    expect(find.text('Ana pendente'), findsOneWidget);
    expect(find.text('Bia ativa'), findsNothing);
  });

  for (final exists in [false, true]) {
    testWidgets('botão respeita existência do plano: $exists', (tester) async {
      setup(Client({
        'unlocked': true,
        'progress': 100,
        'next_question': null,
        'report_generated': exists
      }));
      await tester.pumpWidget(const MaterialApp(
          home: PillarScreen(
              keyName: 'positioning', name: 'Posicionamento Único')));
      await tester.pumpAndSettle();
      expect(
          find.text(
              exists ? 'Visualizar plano' : 'Gerar / abrir Plano do Pilar'),
          findsOneWidget);
    });
  }

  testWidgets('prioridades em português preservam os valores ao salvar',
      (tester) async {
    final client = Client({});
    setup(client);
    await tester.binding.setSurfaceSize(const Size(900, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: MentorEditPillarReportScreen(
            userId: 'u',
            pillarKey: 'positioning',
            pillarName: 'Posicionamento',
            report: {
          'practical_plan': [
            {'title': 'A', 'description': 'Uma ação', 'priority': 'high'},
            {'title': 'B', 'description': 'Outra ação', 'priority': 'medium'},
            {'title': 'C', 'description': 'Terceira ação', 'priority': 'low'},
          ]
        })));
    await tester.pumpAndSettle();
    final plan = tester
        .widgetList<TextField>(find.byType(TextField))
        .firstWhere((field) => field.decoration?.labelText == 'Plano prático');
    expect(plan.controller!.text,
        'A | Uma ação | Alta\nB | Outra ação | Média\nC | Terceira ação | Baixa');
    await tester.scrollUntilVisible(find.text('Salvar revisão'), 400, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Salvar revisão'));
    await tester.pumpAndSettle();
    final payload = client.sent as Map;
    expect((payload['practical_plan'] as List).map((row) => row['priority']),
        ['high', 'medium', 'low']);
  });
}
