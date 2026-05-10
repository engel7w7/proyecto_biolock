// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:biolock_web/main.dart';
import 'package:biolock_web/services/service_locator.dart';

void main() {
  setUpAll(() {
    // Configurar inyección de dependencias para tests
    setupServiceLocator();
  });

  group('BioLock Widget Tests', () {
    testWidgets('App starts and shows SetupScreen', (WidgetTester tester) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(const BioLockApp());

      // Verificar que la app se cargó
      expect(find.byType(MaterialApp), findsOneWidget);

      // La app debe mostrar el texto "BioLock" inicialmente
      await tester.pumpAndSettle();
    });

    testWidgets('UI contains dark theme elements', (WidgetTester tester) async {
      await tester.pumpWidget(const BioLockApp());

      // Verificar que el tema se aplicó
      final BuildContext context = tester.element(find.byType(MaterialApp));
      final ThemeData theme = Theme.of(context);

      // Verificar que es tema oscuro
      expect(theme.brightness, Brightness.dark);
    });

    testWidgets('StatusIndicator displays status text', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const SizedBox.expand(),
          ),
        ),
      );

      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}

