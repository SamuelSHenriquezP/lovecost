import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lovecost/models/models.dart';
import 'package:lovecost/services/services.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('HistoryPeriod Model Tests', () {
    test('HistoryPeriod serialization and deserialization', () {
      final period = HistoryPeriod(
        id: 'hist-123',
        title: 'Septiembre 2026',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 15),
        totalIncome: 3500.0,
        totalExpense: 1200.0,
        balance: 2300.0,
        closedBy: 'Samuel',
        createdAt: DateTime(2026, 9, 15, 18, 30),
      );

      final json = period.toJson();
      expect(json['id'], 'hist-123');
      expect(json['title'], 'Septiembre 2026');
      expect(json['totalIncome'], 3500.0);
      expect(json['totalExpense'], 1200.0);
      expect(json['balance'], 2300.0);
      expect(json['closedBy'], 'Samuel');

      final fromJson = HistoryPeriod.fromJson(json);
      expect(fromJson.id, period.id);
      expect(fromJson.title, period.title);
      expect(fromJson.totalIncome, period.totalIncome);
      expect(fromJson.totalExpense, period.totalExpense);
      expect(fromJson.balance, period.balance);
      expect(fromJson.closedBy, period.closedBy);
    });
  });

  group('Cycle & Archiving Calculations Tests', () {
    test('Calculates cycle metrics and filters out past cycle expenses', () async {
      final cycleStart = DateTime(2026, 9, 1, 0, 0, 0);
      final now = DateTime(2026, 9, 10, 12, 0, 0);

      final allExpenses = [
        // Old expense from August (should be excluded)
        Expense(
          id: 'old-1',
          type: 'expense',
          amount: 500.0,
          description: 'Cena agosto',
          category: 'Salidas',
          createdBy: 'Samuel',
          date: DateTime(2026, 8, 25),
        ),
        // Current cycle income
        Expense(
          id: 'inc-1',
          type: 'income',
          amount: 2500.0,
          description: 'Nómina quincena',
          category: 'Salario',
          createdBy: 'Samuel',
          date: DateTime(2026, 9, 2),
        ),
        // Current cycle expense 1
        Expense(
          id: 'exp-1',
          type: 'expense',
          amount: 400.0,
          description: 'Mercado',
          category: 'Comida',
          createdBy: 'Samuel',
          date: DateTime(2026, 9, 5),
        ),
        // Current cycle expense 2
        Expense(
          id: 'exp-2',
          type: 'expense',
          amount: 150.0,
          description: 'Servicios',
          category: 'Hogar',
          createdBy: 'Samuel',
          date: DateTime(2026, 9, 8),
        ),
        // Future expense (should be excluded if after now)
        Expense(
          id: 'future-1',
          type: 'expense',
          amount: 800.0,
          description: 'Planeado fin de mes',
          category: 'Otros',
          createdBy: 'Samuel',
          date: DateTime(2026, 9, 25),
        ),
      ];

      // Filter as NidoRepository does:
      final cycleExpenses = allExpenses.where((e) {
        if (e.date.isBefore(cycleStart)) return false;
        if (e.date.isAfter(now)) return false;
        return true;
      }).toList();

      expect(cycleExpenses.length, 3);
      expect(cycleExpenses.any((e) => e.id == 'old-1'), isFalse);
      expect(cycleExpenses.any((e) => e.id == 'future-1'), isFalse);

      double totalIncome = 0;
      double totalExpense = 0;
      for (final e in cycleExpenses) {
        if (e.isIncome) {
          totalIncome += e.amount;
        } else {
          totalExpense += e.amount;
        }
      }

      expect(totalIncome, 2500.0);
      expect(totalExpense, 550.0);
      expect(totalIncome - totalExpense, 1950.0);
    });
  });

  group('NidoRepository Guest Cycle & Archiving Flow Tests', () {
    test('Full lifecycle: add expenses -> archive and reset -> balance is zero -> delete history', () async {
      final repo = NidoRepository.instance;
      const coupleId = 'guest_local';
      const mode = NidoUsageMode.guest;

      // 1. Initial cycle start date
      final initialCycleStart = DateTime(2026, 9, 1);
      await LocalGuestStorage.setCycleStartDate(initialCycleStart);

      // 2. Add an income and an expense in current cycle
      final inc = Expense(
        id: 'test-inc-1',
        type: 'income',
        amount: 1000.0,
        description: 'Ingreso inicial',
        category: 'Salario',
        createdBy: 'Invitado',
        date: DateTime(2026, 9, 2),
      );
      final exp = Expense(
        id: 'test-exp-1',
        type: 'expense',
        amount: 350.0,
        description: 'Gasto prueba',
        category: 'Alimentación',
        createdBy: 'Invitado',
        date: DateTime(2026, 9, 3),
      );

      await repo.addExpense(coupleId: coupleId, mode: mode, expense: inc);
      await repo.addExpense(coupleId: coupleId, mode: mode, expense: exp);

      // Verify cycle expenses before archive
      final expensesBefore = await repo.getCycleExpenses(
        coupleId: coupleId,
        mode: mode,
        cycleStartDate: initialCycleStart,
      );
      expect(expensesBefore.length, 2);

      // 3. Archive period and reset cycle to zero
      final archived = await repo.archiveCurrentPeriodAndReset(
        coupleId: coupleId,
        mode: mode,
        userName: 'Invitado',
        resetMode: 'monthly',
      );

      expect(archived.totalIncome, 1000.0);
      expect(archived.totalExpense, 350.0);
      expect(archived.balance, 650.0);
      expect(archived.closedBy, 'Invitado');

      // 4. Verify that new cycle start date was updated to now
      final newCycleStart = await repo.getCycleStartDate(coupleId: coupleId, mode: mode);
      expect(newCycleStart.isAfter(initialCycleStart), isTrue);

      // 5. Verify that in the new cycle, old expenses are excluded (starts from zero!)
      final expensesAfter = await repo.getCycleExpenses(
        coupleId: coupleId,
        mode: mode,
        cycleStartDate: newCycleStart,
      );
      expect(expensesAfter.isEmpty, isTrue);

      // 6. Verify that history period was saved in LocalGuestStorage
      final historyList = await LocalGuestStorage.getHistory();
      expect(historyList.length, 1);
      expect(historyList.first['id'], archived.id);
      expect(historyList.first['balance'], 650.0);

      // 7. Delete the history period
      await repo.deleteHistoryPeriod(coupleId: coupleId, mode: mode, periodId: archived.id);
      final historyAfterDelete = await LocalGuestStorage.getHistory();
      expect(historyAfterDelete.isEmpty, isTrue);
    });

    test('resetCycleWithoutArchiving updates cycleStartDate without touching history', () async {
      final repo = NidoRepository.instance;
      const coupleId = 'guest_local';
      const mode = NidoUsageMode.guest;

      final pastDate = DateTime(2026, 8, 1);
      await LocalGuestStorage.setCycleStartDate(pastDate);

      // Add expense
      await repo.addExpense(
        coupleId: coupleId,
        mode: mode,
        expense: Expense(
          id: 'test-reset-1',
          type: 'expense',
          amount: 150.0,
          description: 'Gasto viejo',
          category: 'Varios',
          createdBy: 'Invitado',
          date: DateTime(2026, 8, 15),
        ),
      );

      // Reset without archiving
      await repo.resetCycleWithoutArchiving(coupleId: coupleId, mode: mode);

      final newStart = await repo.getCycleStartDate(coupleId: coupleId, mode: mode);
      expect(newStart.isAfter(pastDate), isTrue);

      // History should remain empty
      final history = await LocalGuestStorage.getHistory();
      expect(history.isEmpty, isTrue);

      // Cycle expenses should now be 0
      final expenses = await repo.getCycleExpenses(
        coupleId: coupleId,
        mode: mode,
        cycleStartDate: newStart,
      );
      expect(expenses.isEmpty, isTrue);
    });
  });
}
