import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lovecost/main.dart';
import 'package:lovecost/screens/add_expense_bottom_sheet.dart';

void main() {
  testWidgets('NidoApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const NidoApp());
  });

  testWidgets('AddExpenseBottomSheet shows custom categories', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AddExpenseBottomSheet(
            coupleId: 'couple-test',
            userName: 'Alice',
            mode: NidoUsageMode.individual,
            customCategories: [
              CustomCategory(
                id: 'custom-1',
                name: 'Mascotas',
                emoji: '🐶',
                colorHex: 0xFF0D9488,
                type: 'expense',
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Mascotas'), findsOneWidget);
  });
}
