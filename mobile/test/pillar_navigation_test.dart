import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mentoria_ai/screens/pillar_report_screen.dart';
import 'package:mentoria_ai/screens/pillar_screen.dart';
import 'package:mentoria_ai/screens/report_screen.dart';

class Headers extends Fake implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void forEach(void Function(String, List<String>) action) {
    action('content-type', ['application/json']);
  }
}

class Response extends Stream<List<int>> implements HttpClientResponse {
  Response(this.data);
  final Object data;
  @override
  int get statusCode => 200;
  @override
  int get contentLength => -1;
  @override
  bool get isRedirect => false;
  @override
  List<RedirectInfo> get redirects => [];
  @override
  bool get persistentConnection => false;
  @override
  String get reasonPhrase => 'OK';
  @override
  HttpHeaders get headers => Headers();
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(void Function(List<int>)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream.value(utf8.encode(jsonEncode(data))).listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Request extends Fake implements HttpClientRequest {
  Request(this.data);
  final Object data;
  @override
  HttpHeaders get headers => Headers();
  @override
  set followRedirects(bool value) {}
  @override
  set maxRedirects(int value) {}
  @override
  set persistentConnection(bool value) {}
  @override
  set contentLength(int value) {}
  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await stream.drain<void>();
  }

  @override
  Future<HttpClientResponse> close() async => Response(data);
}

class Client extends Fake implements HttpClient {
  Client(this.paths);
  final List<String> paths;
  @override
  set autoUncompress(bool value) {}
  @override
  void close({bool force = false}) {}
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    paths.add(url.path);
    if (url.path.contains('/pillar-reports/')) {
      return Request({
        'ready_for_next': true,
        'summary': 'Resumo preservado',
        'mentor_review_status': 'edited',
        'mentor_review_note': 'Observação preservada',
        'missing_information': ['Informação preservada'],
        'strengths': [],
        'gaps': [],
        'practical_plan': []
      });
    }
    return Request({
      'unlocked': true,
      'progress': 0,
      'next_question': {
        'key': 'p_test',
        'title': 'Pergunta do próximo módulo',
        'question': 'Descreva sua resposta'
      }
    });
  }
}

class Overrides extends HttpOverrides {
  Overrides(this.paths);
  final List<String> paths;
  @override
  HttpClient createHttpClient(SecurityContext? context) => Client(paths);
}

void main() {
  for (final pair in [
    ('positioning', 'promise'),
    ('promise', 'funnel'),
    ('funnel', 'closing'),
    ('closing', 'strategy')
  ]) {
    testWidgets('${pair.$1} continua para ${pair.$2} sem perder o plano',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final paths = <String>[];
      final original = HttpOverrides.current;
      HttpOverrides.global = Overrides(paths);
      addTearDown(() => HttpOverrides.global = original);
      await tester.pumpWidget(MaterialApp(
          home: PillarReportScreen(pillarKey: pair.$1, pillarName: pair.$1)));
      await tester.pumpAndSettle();
      expect(find.text('Resumo preservado'), findsOneWidget,
          reason: tester
              .widgetList<Text>(find.byType(Text))
              .map((t) => t.data)
              .join(' | '));
      expect(find.text('Observação preservada'), findsOneWidget);
      final button = find.widgetWithText(
          FilledButton,
          pair.$2 == 'strategy'
              ? 'Continuar para a estratégia'
              : 'Continuar para o próximo módulo');
      await tester.scrollUntilVisible(button, 250);
      await tester.tap(button);
      await tester.pumpAndSettle();
      if (pair.$2 == 'strategy') {
        expect(find.byType(ReportScreen), findsOneWidget);
      } else {
        expect(tester.widget<PillarScreen>(find.byType(PillarScreen)).keyName,
            pair.$2);
        expect(paths, contains('/api/v1/pillars/${pair.$2}'));
        expect(find.text('Pergunta do próximo módulo'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
