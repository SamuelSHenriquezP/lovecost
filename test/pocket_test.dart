import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lovecost/main.dart';
import 'package:lovecost/screens/add_expense_bottom_sheet.dart';
import 'package:lovecost/widgets/pocket_widgets.dart';

void main() {
  group('Pocket Model & Metrics Tests', () {
    test('Pocket serialization and deserialization', () {
      final pocket = Pocket(
        id: 'pocket-123',
        name: 'Supermercado',
        emoji: '🛒',
        colorHex: 0xFF059669,
        targetAmount: 500000.0,
        initialAmount: 100000.0,
        createdBy: 'Samuel',
        createdAt: DateTime(2026, 9, 7),
      );

      final json = pocket.toJson();
      expect(json['id'], 'pocket-123');
      expect(json['name'], 'Supermercado');
      expect(json['emoji'], '🛒');
      expect(json['targetAmount'], 500000.0);
      expect(json['initialAmount'], 100000.0);

      final fromJson = Pocket.fromJson(json);
      expect(fromJson.id, pocket.id);
      expect(fromJson.name, pocket.name);
      expect(fromJson.emoji, pocket.emoji);
      expect(fromJson.targetAmount, pocket.targetAmount);
      expect(fromJson.initialAmount, pocket.initialAmount);
    });

    test('calculatePocketMetrics calculates available, spent and progress correctly', () {
      final pocket = Pocket(
        id: 'pocket-vacaciones',
        name: 'Vacaciones',
        emoji: '🏖️',
        colorHex: 0xFF0D9488,
        targetAmount: 1000.0,
        initialAmount: 200.0,
        createdBy: 'Samuel',
        createdAt: DateTime(2026, 9, 7),
      );

      final expenses = [
        Expense(
          id: '1',
          type: 'income',
          amount: 300.0,
          description: 'Aporte nómina',
          category: 'Ahorro Nido',
          createdBy: 'Samuel',
          date: DateTime.now(),
          pocketId: 'pocket-vacaciones',
          pocketName: 'Vacaciones',
        ),
        Expense(
          id: '2',
          type: 'expense',
          amount: 150.0,
          description: 'Reserva hotel',
          category: 'Viajes',
          createdBy: 'Samuel',
          date: DateTime.now(),
          pocketId: 'pocket-vacaciones',
          pocketName: 'Vacaciones',
        ),
        Expense(
          id: '3',
          type: 'expense',
          amount: 50.0,
          description: 'Otro gasto no relacionado',
          category: 'Otros',
          createdBy: 'Samuel',
          date: DateTime.now(),
          // sin bolsillo
        ),
      ];

      final metrics = calculatePocketMetrics(
        pocket: pocket,
        expenses: expenses,
      );

      // Disponible = initialAmount (200) + income (300) - expense (150) = 350
      expect(metrics.available, 350.0);
      // Gastado = 150
      expect(metrics.spent, 150.0);
      // Total ingresos = 300
      expect(metrics.totalIncome, 300.0);
      // Progreso = 350 / 1000 = 0.35
      expect(metrics.progress, 0.35);
    });
  });

  group('Pocket UI & Contextual Opening Tests', () {
    testWidgets('PocketCard renders pocket name, emoji and metrics', (
      WidgetTester tester,
    ) async {
      final pocket = Pocket(
        id: 'p-1',
        name: 'Mercado Mensual',
        emoji: '🛒',
        colorHex: 0xFF0D9488,
        targetAmount: 400.0,
        initialAmount: 0.0,
        createdBy: 'Samuel',
        createdAt: DateTime.now(),
      );

      const metrics = PocketMetrics(
        available: 250.0,
        spent: 150.0,
        totalIncome: 400.0,
        progress: 0.625,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PocketCard(
              pocket: pocket,
              metrics: metrics,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Mercado Mensual'), findsOneWidget);
      expect(find.text('🛒'), findsOneWidget);
      expect(find.text('Disponible'), findsOneWidget);
      expect(find.textContaining('250'), findsWidgets);
      expect(find.textContaining('150'), findsWidgets);
    });

    testWidgets('AddExpenseBottomSheet opens in income mode when initialType is income', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddExpenseBottomSheet(
              coupleId: 'test-couple',
              userName: 'Samuel',
              mode: NidoUsageMode.guest,
              initialType: 'income',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Debería tener seleccionado y visible el botón de Guardar Ingreso
      expect(find.text('Guardar Ingreso'), findsOneWidget);
      expect(find.text('¿De qué es este ingreso?'), findsOneWidget);
    });

    testWidgets('AddExpenseBottomSheet opens in expense mode when initialType is expense', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddExpenseBottomSheet(
              coupleId: 'test-couple',
              userName: 'Samuel',
              mode: NidoUsageMode.guest,
              initialType: 'expense',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Debería tener seleccionado y visible el botón de Registrar Gasto
      expect(find.text('Registrar Gasto'), findsOneWidget);
      expect(find.text('¿En qué se gastó?'), findsOneWidget);
    });
  });
}

