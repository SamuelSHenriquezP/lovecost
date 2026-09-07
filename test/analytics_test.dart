import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lovecost/main.dart';
import 'package:lovecost/widgets/stock_line_chart.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es', null);
  });

  group('StockLineChart Tests', () {
    testWidgets('StockLineChart renders points and title correctly', (
      WidgetTester tester,
    ) async {
      final now = DateTime(2026, 9, 7);
      final points = [
        ChartPoint(date: now.subtract(const Duration(days: 3)), value: 100.0),
        ChartPoint(date: now.subtract(const Duration(days: 2)), value: 150.0),
        ChartPoint(date: now.subtract(const Duration(days: 1)), value: 120.0),
        ChartPoint(date: now, value: 250.0),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StockLineChart(
              points: points,
              title: 'Balance Neto Acumulado',
              currencyFormatter: (v) => '\$${v.toInt()}',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Balance Neto Acumulado'), findsOneWidget);
      expect(find.text('\$250'), findsOneWidget);
      expect(find.byType(StockLineChart), findsOneWidget);
    });

    testWidgets('StockLineChart shows empty state when points are empty', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StockLineChart(
              points: const [],
              title: 'Balance',
              currencyFormatter: (v) => '\$${v.toInt()}',
            ),
          ),
        ),
      );

      expect(
        find.text('Sin datos para graficar en este periodo'),
        findsOneWidget,
      );
    });
  });

  group('AnalyticsScreen UI Tests', () {
    testWidgets('AnalyticsScreen renders period selector chips', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AnalyticsScreen(
            coupleId: 'test-couple',
            userName: 'Samuel',
            mode: NidoUsageMode.guest,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('7D'), findsOneWidget);
      expect(find.text('Este Mes'), findsOneWidget);
      expect(find.text('30D'), findsOneWidget);
      expect(find.text('3M'), findsOneWidget);
      expect(find.text('Este Año'), findsOneWidget);
      expect(find.text('Balance Financiero'), findsOneWidget);
    });
  });
}

