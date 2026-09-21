import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mentoria_ai/screens/action_plan_screen.dart';
import 'package:mentoria_ai/screens/report_screen.dart';
import 'pillar_navigation_test.dart' as mock;

class Response extends mock.Response {
  Response(super.data, this.code);
  final int code;
  @override
  int get statusCode => code;
}

class Request extends mock.Request {
  Request(super.data, {this.code = 200, this.onBody});
  final int code;
  final void Function(Map<String, dynamic>)? onBody;
  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    final bytes = await stream.fold<List<int>>([], (a, b) => a..addAll(b));
    if (bytes.isNotEmpty)
      onBody?.call(Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes))));
  }

  @override
  Future<HttpClientResponse> close() async => Response(data, code);
}

class Client extends mock.Client {
  Client() : super([]);
  bool failRead = false, failWrite = false, ready = false;
  Map<String, dynamic>? report;
  Map<String, dynamic>? sent;
  final actions = <Map<String, dynamic>>[
    {
      'id': '1',
      'title': 'Ação vencida',
      'description': 'Primeiro passo',
      'pillar_key': 'positioning',
      'priority': 'high',
      'status': 'pending',
      'sort_order': 1,
      'due_date': '2001-01-01',
      'notes': ''
    },
    {
      'id': '2',
      'title': 'Ação finalizada',
      'description': 'Segundo passo',
      'pillar_key': 'promise',
      'priority': 'low',
      'status': 'done',
      'sort_order': 2,
      'due_date': null,
      'notes': ''
    },
  ];
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    if (method == 'PATCH')
      return Request({}, code: failWrite ? 500 : 200, onBody: (body) {
        sent = body;
        if (!failWrite)
          actions
              .firstWhere((a) => a['id'] == url.pathSegments.last)
              .addAll(body);
      });
    if (failRead) return Request({'detail': 'Falha temporária'}, code: 500);
    if (url.path.endsWith('/action-plan')) return Request(actions);
    if (url.path.endsWith('/full-report'))
      return report == null
          ? Request({'detail': 'Ainda não gerado'}, code: 404)
          : Request(report!);
    if (url.path.endsWith('/dashboard'))
      return Request(
          {'journey_status': ready ? 'diagnosis_completed' : 'in_diagnosis'});
    return Request({});
  }
}

class Overrides extends HttpOverrides {
  Overrides(this.client);
  final Client client;
  @override
  HttpClient createHttpClient(SecurityContext? context) => client;
}

Widget app(Widget home) => MaterialApp(
    locale: const Locale('pt', 'BR'),
    supportedLocales: const [Locale('pt', 'BR')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: home);
void setup(Client client) {
  SharedPreferences.setMockInitialValues({});
  final previous = HttpOverrides.current;
  HttpOverrides.global = Overrides(client);
  addTearDown(() => HttpOverrides.global = previous);
}

Finder dropdown(String label) => find.byWidgetPredicate((w) =>
    w is DropdownButtonFormField<String> && w.decoration.labelText == label);

void main() {
  testWidgets('andamento atualiza progresso e filtros', (tester) async {
    final client = Client();
    setup(client);
    await tester.binding.setSurfaceSize(const Size(450, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(const ActionPlanScreen()));
    await tester.pumpAndSettle();
    expect(find.text('1 de 2 ações concluídas'), findsOneWidget);
    expect(find.text('1 ações com prazo vencido'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('1-pending-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Em andamento').last);
    await tester.pumpAndSettle();
    expect(client.actions.first['status'], 'in_progress');
    await tester.tap(dropdown('Situação'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Concluída').last);
    await tester.pumpAndSettle();
    expect(find.text('Ação vencida'), findsNothing);
    expect(find.text('Ação finalizada'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('prazo e observações persistem; prazo pode ser removido',
      (tester) async {
    final client = Client();
    client.actions.removeLast();
    client.actions.first['due_date'] = null;
    setup(client);
    await tester.binding.setSurfaceSize(const Size(450, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(const ActionPlanScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prioridade, prazo e observações'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Definir prazo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar').last);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).last, 'Conversei com a mentora');
    await tester.tap(find.text('Salvar ação'));
    await tester.pumpAndSettle();
    expect(client.sent!['due_date'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    expect(client.actions.first['notes'], 'Conversei com a mentora');
    await tester.tap(find.text('Prioridade, prazo e observações'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remover prazo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar ação'));
    await tester.pumpAndSettle();
    expect(client.sent!.containsKey('due_date'), isTrue);
    expect(client.sent!['due_date'], isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets('falha ao salvar mantém andamento anterior', (tester) async {
    final client = Client()..failWrite = true;
    client.actions.removeLast();
    setup(client);
    await tester.binding.setSurfaceSize(const Size(450, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(const ActionPlanScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('1-pending-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Concluída').last);
    await tester.pumpAndSettle();
    expect(client.actions.first['status'], 'pending');
    expect(find.text('0 de 1 ações concluídas'), findsOneWidget);
    expect(
        tester
            .state<FormFieldState<String>>(
                find.byKey(const ValueKey('1-pending-1')))
            .value,
        'pending');
    expect(
        find.text('Não foi possível salvar. Sua alteração não foi confirmada.'),
        findsOneWidget);
  });
  testWidgets('erro de leitura não aparece como plano vazio', (tester) async {
    final client = Client()..failRead = true;
    setup(client);
    await tester.pumpWidget(app(const ActionPlanScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(find.text('Abrir estratégia'), findsNothing);
    client.failRead = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('1 de 2 ações concluídas'), findsOneWidget);
  });
  testWidgets('erro ao salvar observações mantém o texto para nova tentativa',
      (tester) async {
    final client = Client()..failWrite = true;
    client.actions.removeLast();
    setup(client);
    await tester.binding.setSurfaceSize(const Size(450, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(const ActionPlanScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prioridade, prazo e observações'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).last, 'Não perder este acompanhamento');
    await tester.tap(find.text('Salvar ação'));
    await tester.pumpAndSettle();
    expect(find.text('Organizar ação'), findsOneWidget);
    expect(find.text('Não perder este acompanhamento'), findsOneWidget);
    client.failWrite = false;
    await tester.tap(find.text('Salvar ação'));
    await tester.pumpAndSettle();
    expect(client.actions.first['notes'], 'Não perder este acompanhamento');
    expect(find.text('Organizar ação'), findsNothing);
  });
  testWidgets('estratégia aguarda os quatro planos validados', (tester) async {
    setup(Client());
    await tester.pumpWidget(app(const ReportScreen()));
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Gerar estratégia completa'));
    expect(button.onPressed, isNull);
  });
  testWidgets('estratégia exibe resumo e abre acompanhamento', (tester) async {
    final client = Client()
      ..report = {
        'executive_summary': 'Visão estratégica',
        'stage_summary': 'Momento real',
        'pillar_summaries': {'positioning': 'Posicionamento revisado'},
        'priorities': ['Ação prioritária']
      };
    setup(client);
    await tester.pumpWidget(app(const ReportScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Visão estratégica'), findsOneWidget);
    await tester.tap(find.text('Acompanhar plano de ação'));
    await tester.pumpAndSettle();
    expect(find.byType(ActionPlanScreen), findsOneWidget);
  });
}
