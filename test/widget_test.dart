import 'package:flutter_test/flutter_test.dart';
import 'package:moradia_app/main.dart';

void main() {
  testWidgets('App smoke test — tela de login renderiza', (WidgetTester tester) async {
    await tester.pumpWidget(const MeuAppEstudantil());
    // A tela de login deve exibir o botão "Entrar"
    expect(find.text('Entrar'), findsOneWidget);
  });
}
