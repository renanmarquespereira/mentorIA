import 'package:flutter_test/flutter_test.dart';
import 'package:mentoria_ai/main.dart';
import 'package:mentoria_ai/screens/login_screen.dart';

void main() {
  testWidgets('Abre a tela de login da mentoria', (tester) async {
    await tester.pumpWidget(const MentoriaApp());
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
