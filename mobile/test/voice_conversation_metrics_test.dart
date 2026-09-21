import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mentoria_ai/screens/plan_conversation_screen.dart';
import 'package:mentoria_ai/screens/pillar_report_screen.dart';
import 'package:mentoria_ai/screens/metric_form_screen.dart';
import 'package:mentoria_ai/widgets/voice_input.dart';
import 'pillar_navigation_test.dart' as mock;
import 'strategy_action_test.dart' as helpers;

class Client extends mock.Client {
  Client() : super([]);
  bool fail = true;
  final requests = <Map<String, dynamic>>[];
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    if (url.path.contains('/pillar-reports/'))
      return helpers.Request({
        'summary': 'Plano que posso consultar',
        'ready_for_next': true,
        'practical_plan': [
          {'title': 'Começar', 'description': 'Usar minha experiência real.'}
        ]
      });
    if (url.path.endsWith('/drafts'))
      return helpers.Request([
        {'id': 'draft-id', 'duration': 12, 'created_at': '2026-09-07T00:00:00'}
      ]);
    if (url.path.endsWith('/transcribe'))
      return helpers.Request(
          fail
              ? {'detail': 'Transcrição indisponível. Áudio mantido.'}
              : {'transcript': 'Organizei as finanças da família.'},
          code: fail ? 503 : 200);
    if (method == 'DELETE') return helpers.Request({'ok': true});
    if (method == 'GET') return helpers.Request([]);
    return helpers.Request(
        fail
            ? {'detail': 'Tente novamente.'}
            : {
                'id': 'reply',
                'question': 'Como começo?',
                'reply': 'Comece com sua experiência real.'
              },
        code: fail ? 503 : 200,
        onBody: requests.add);
  }
}

class Overrides extends HttpOverrides {
  final Client client;
  Overrides(this.client);
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
  testWidgets(
      'conversa fica no plano e mantém rascunho ao consultar e recolher',
      (tester) async {
    setup(Client());
    await tester.pumpWidget(helpers.app(const PillarReportScreen(
        pillarKey: 'positioning', pillarName: 'Posicionamento')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Conversar sobre meu plano'));
    await tester.tap(find.text('Conversar sobre meu plano'));
    await tester.pumpAndSettle();
    expect(find.byType(Scaffold), findsOneWidget);
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(
        find.byType(TextField), 'Como uso minha experiência?');
    await tester.scrollUntilVisible(find.text('Plano que posso consultar'), -250,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('Plano que posso consultar'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Recolher conversa'), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Recolher conversa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Conversar sobre meu plano'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Como uso minha experiência?');
    await tester.ensureVisible(find.text('Gravar áudio'));
    expect(find.text('Gravar áudio'), findsOneWidget);
  });
  testWidgets(
      'conversa mantém dúvida após falha e reutiliza identificação no retry',
      (tester) async {
    final client = Client();
    setup(client);
    await tester.pumpWidget(helpers.app(const PlanConversationScreen(
        pillarKey: 'positioning', pillarName: 'Posicionamento')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Como começo?');
    await tester.ensureVisible(find.text('Enviar dúvida'));
    await tester.tap(find.text('Enviar dúvida'));
    await tester.pumpAndSettle();
    expect(find.text('Como começo?'), findsOneWidget);
    client.fail = false;
    await tester.ensureVisible(find.text('Enviar dúvida'));
    await tester.tap(find.text('Enviar dúvida'));
    await tester.pumpAndSettle();
    expect(client.requests.length, 2);
    expect(client.requests[0]['request_id'], client.requests[1]['request_id']);
    expect(find.textContaining('Comece com sua experiência real.'),
        findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);
  });
  testWidgets('microfone negado preserva texto e libera envio por escrito',
      (tester) async {
    final controller = TextEditingController(text: 'Minha resposta digitada');
    bool busy = false;
    const channel = MethodChannel('com.llfbandit.record/messages');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel, (call) async => call.method == 'hasPermission' ? false : null);
    await tester.pumpWidget(helpers.app(Scaffold(
        body: VoiceInput(
            pillarKey: 'positioning',
            questionKey: 'q',
            controller: controller,
            onAttachment: (_) {},
            onBusy: (value) => busy = value))));
    await tester.tap(find.text('Gravar áudio'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Verifique a permissão'), findsOneWidget);
    expect(controller.text, 'Minha resposta digitada');
    expect(busy, isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    controller.dispose();
  });
  testWidgets(
      'recupera áudio, preserva anexo após falha e acrescenta transcrição sem apagar texto',
      (tester) async {
    final client = Client();
    setup(client);
    final controller = TextEditingController(text: 'Texto anterior');
    String? attached;
    await tester.pumpWidget(helpers.app(Scaffold(
        body: SingleChildScrollView(
            child: VoiceInput(
                pillarKey: 'positioning',
                questionKey: 'q',
                controller: controller,
                onAttachment: (value) => attached = value,
                onBusy: (_) {})))));
    await tester.tap(find.text('Recuperar gravação pendente'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('12 segundos'));
    await tester.pumpAndSettle();
    expect(attached, 'draft-id');
    await tester.tap(find.text('Tentar transcrição novamente'));
    await tester.pumpAndSettle();
    expect(attached, 'draft-id');
    expect(controller.text, 'Texto anterior');
    client.fail = false;
    await tester.tap(find.text('Tentar transcrição novamente'));
    await tester.pumpAndSettle();
    expect(
        controller.text, 'Texto anterior\nOrganizei as finanças da família.');
    await tester.tap(find.text('Remover áudio (manter texto)'));
    await tester.pumpAndSettle();
    expect(attached, isNull);
    expect(controller.text, contains('Texto anterior'));
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
  testWidgets(
      'métricas validam mês e preservam formulário quando servidor falha',
      (tester) async {
    final client = Client();
    setup(client);
    await tester.pumpWidget(helpers.app(const MetricFormScreen()));
    await tester.enterText(find.byType(TextFormField).at(0), '2026-13');
    await tester.ensureVisible(find.text('Salvar resumo do mês'));
    await tester.tap(find.text('Salvar resumo do mês'));
    await tester.pumpAndSettle();
    expect(client.requests, isEmpty);
    await tester.enterText(find.byType(TextFormField).at(0), '2026-09');
    await tester.enterText(find.byType(TextFormField).at(4), '1.200,50');
    await tester.ensureVisible(find.text('Salvar resumo do mês'));
    await tester.tap(find.text('Salvar resumo do mês'));
    await tester.pumpAndSettle();
    expect(client.requests.single['revenue'], 1200.50);
    expect(find.textContaining('Não consegui salvar.'), findsOneWidget);
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(4))
            .controller!
            .text,
        '1.200,50');
  });
}
