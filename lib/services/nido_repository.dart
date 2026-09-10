import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import 'services.dart';

/// Unified Repository providing transparent data access across Guest (local) and Couple/Individual (Firestore) modes.
class NidoRepository {
  NidoRepository._internal();
  static final NidoRepository instance = NidoRepository._internal();

  FirebaseFirestore? _firestoreInstance;
  FirebaseFirestore get _firestore => _firestoreInstance ??= FirebaseFirestore.instance;

  // ==========================================
  // EXPENSES / MOVIMIENTOS
  // ==========================================

  /// Stream of active expenses starting from cycleStartDate (and optional cycleEndDate).
  Stream<List<Expense>> streamExpenses({
    required String coupleId,
    required NidoUsageMode mode,
    required DateTime cycleStartDate,
    DateTime? cycleEndDate,
    int? limit,
  }) {
    if (mode == NidoUsageMode.guest) {
      return Stream.fromFuture(LocalGuestStorage.getExpenses()).map((raw) {
        final parsed = raw.map((e) => Expense.fromJson(e)).toList();
        final filtered = parsed.where((e) {
          if (e.date.isBefore(cycleStartDate)) return false;
          if (cycleEndDate != null && e.date.isAfter(cycleEndDate)) return false;
          return true;
        }).toList();
        filtered.sort((a, b) => b.date.compareTo(a.date));
        if (limit != null && filtered.length > limit) {
          return filtered.sublist(0, limit);
        }
        return filtered;
      });
    }

    Query query = _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('expenses')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(cycleStartDate));

    if (cycleEndDate != null) {
      query = query.where('date', isLessThanOrEqualTo: Timestamp.fromDate(cycleEndDate));
    }

    query = query.orderBy('date', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Expense.fromFirestore(doc)).toList();
    });
  }

  /// Adds a new expense or income.
  Future<void> addExpense({
    required String coupleId,
    required NidoUsageMode mode,
    required Expense expense,
  }) async {
    if (mode == NidoUsageMode.guest) {
      final list = await LocalGuestStorage.getExpenses();
      list.add(expense.toJson());
      await LocalGuestStorage.saveExpenses(list);
    } else {
      final docRef = _firestore
          .collection('couples')
          .doc(coupleId)
          .collection('expenses')
          .doc(expense.id.isNotEmpty ? expense.id : null);
      await docRef
          .set({
            'type': expense.type,
            'amount': expense.amount,
            'description': expense.description,
            'category': expense.category,
            'sourceOrDestination': expense.sourceOrDestination,
            'createdBy': expense.createdBy,
            'date': Timestamp.fromDate(expense.date),
            'reactions': expense.reactions,
            if (expense.pocketId != null) 'pocketId': expense.pocketId,
            if (expense.pocketName != null) 'pocketName': expense.pocketName,
          })
          .timeout(
            const Duration(milliseconds: 1500),
            onTimeout: () {},
          );
    }
  }

  /// Updates an existing expense or income.
  Future<void> updateExpense({
    required String coupleId,
    required NidoUsageMode mode,
    required Expense expense,
  }) async {
    if (mode == NidoUsageMode.guest) {
      final list = await LocalGuestStorage.getExpenses();
      final idx = list.indexWhere((item) => item['id'] == expense.id);
      if (idx != -1) {
        list[idx] = expense.toJson();
        await LocalGuestStorage.saveExpenses(list);
      }
    } else {
      await _firestore
          .collection('couples')
          .doc(coupleId)
          .collection('expenses')
          .doc(expense.id)
          .update({
            'type': expense.type,
            'amount': expense.amount,
            'description': expense.description,
            'category': expense.category,
            'sourceOrDestination': expense.sourceOrDestination,
            'createdBy': expense.createdBy,
            'date': Timestamp.fromDate(expense.date),
            'reactions': expense.reactions,
            if (expense.pocketId != null) 'pocketId': expense.pocketId,
            if (expense.pocketName != null) 'pocketName': expense.pocketName,
          })
          .timeout(
            const Duration(milliseconds: 1500),
            onTimeout: () {},
          );
    }
  }

  /// Deletes an expense by ID.
  Future<void> deleteExpense({
    required String coupleId,
    required NidoUsageMode mode,
    required String expenseId,
  }) async {
    if (mode == NidoUsageMode.guest) {
      final list = await LocalGuestStorage.getExpenses();
      list.removeWhere((item) => item['id'] == expenseId);
      await LocalGuestStorage.saveExpenses(list);
    } else {
      await _firestore
          .collection('couples')
          .doc(coupleId)
          .collection('expenses')
          .doc(expenseId)
          .delete()
          .timeout(
            const Duration(milliseconds: 1500),
            onTimeout: () {},
          );
    }
  }

  // ==========================================
  // CUSTOM CATEGORIES
  // ==========================================

  /// Stream of custom categories.
  Stream<List<CustomCategory>> streamCategories({
    required String coupleId,
    required NidoUsageMode mode,
  }) {
    if (mode == NidoUsageMode.guest) {
      return Stream.fromFuture(LocalGuestStorage.getCategories()).map((raw) {
        return raw.map((c) => CustomCategory.fromJson(c)).toList();
      });
    }

    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('categories')
        .snapshots()
        .map((snap) => snap.docs.map((d) => CustomCategory.fromFirestore(d)).toList());
  }

  /// Adds a custom category.
  Future<void> addCategory({
    required String coupleId,
    required NidoUsageMode mode,
    required CustomCategory category,
  }) async {
    if (mode == NidoUsageMode.guest) {
      final cats = await LocalGuestStorage.getCategories();
      cats.add(category.toJson());
      await LocalGuestStorage.saveCategories(cats);
    } else {
      await _firestore
          .collection('couples')
          .doc(coupleId)
          .collection('categories')
          .add({
            'name': category.name,
            'emoji': category.emoji,
            'colorHex': category.colorHex,
            'type': category.type,
          });
    }
  }

  /// Deletes a custom category.
  Future<void> deleteCategory({
    required String coupleId,
    required NidoUsageMode mode,
    required String categoryId,
  }) async {
    if (mode == NidoUsageMode.guest) {
      final cats = await LocalGuestStorage.getCategories();
      cats.removeWhere((c) => c['id'] == categoryId);
      await LocalGuestStorage.saveCategories(cats);
    } else {
      await _firestore
          .collection('couples')
          .doc(coupleId)
          .collection('categories')
          .doc(categoryId)
          .delete();
    }
  }

  // ==========================================
  // BUDGET & METAS
  // ==========================================

  /// Sets monthly budget limit.
  Future<void> setBudget({
    required String coupleId,
    required NidoUsageMode mode,
    required double budgetLimit,
  }) async {
    if (mode == NidoUsageMode.guest) {
      await LocalGuestStorage.setBudget(budgetLimit);
    } else {
      await _firestore
          .collection('couples')
          .doc(coupleId)
          .update({'budget_limit': budgetLimit});
    }
  }

  // ==========================================
  // BOLSILLOS (POCKETS)
  // ==========================================

  /// Stream of bolsillos (pockets).
  Stream<List<Pocket>> streamPockets({
    required String coupleId,
    required NidoUsageMode mode,
  }) {
    if (mode == NidoUsageMode.guest) {
      return Stream.fromFuture(LocalGuestStorage.getPockets()).map((raw) {
        return raw.map((p) => Pocket.fromJson(p)).toList();
      });
    }

    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('pockets')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Pocket.fromFirestore(d)).toList());
  }

  /// Adds a new pocket and returns its ID.
  Future<String> addPocket({
    required String coupleId,
    required NidoUsageMode mode,
    required Pocket pocket,
  }) async {
    if (mode == NidoUsageMode.guest) {
      final list = await LocalGuestStorage.getPockets();
      list.add(pocket.toJson());
      await LocalGuestStorage.savePockets(list);
      return pocket.id;
    } else {
      final docRef = _firestore
          .collection('couples')
          .doc(coupleId)
          .collection('pockets')
          .doc(pocket.id.isNotEmpty ? pocket.id : null);
      await docRef
          .set({
            'name': pocket.name,
            'emoji': pocket.emoji,
            'colorHex': pocket.colorHex,
            'targetAmount': pocket.targetAmount,
            'initialAmount': pocket.initialAmount,
            'createdBy': pocket.createdBy,
            'createdAt': FieldValue.serverTimestamp(),
          })
          .timeout(
            const Duration(milliseconds: 1500),
            onTimeout: () {},
          );
      return docRef.id;
    }
  }

  /// Updates an existing pocket.
  Future<void> updatePocket({
    required String coupleId,
    required NidoUsageMode mode,
    required Pocket pocket,
  }) async {
    if (mode == NidoUsageMode.guest) {
      final list = await LocalGuestStorage.getPockets();
      final idx = list.indexWhere((p) => p['id'] == pocket.id);
      if (idx != -1) {
        list[idx] = pocket.toJson();
        await LocalGuestStorage.savePockets(list);
      }
    } else {
      await _firestore
          .collection('couples')
          .doc(coupleId)
          .collection('pockets')
          .doc(pocket.id)
          .update({
            'name': pocket.name,
            'emoji': pocket.emoji,
            'colorHex': pocket.colorHex,
            'targetAmount': pocket.targetAmount,
            'initialAmount': pocket.initialAmount,
          })
          .timeout(
            const Duration(milliseconds: 1500),
            onTimeout: () {},
          );
    }
  }

  /// Deletes a pocket by ID.
  Future<void> deletePocket({
    required String coupleId,
    required NidoUsageMode mode,
    required String pocketId,
  }) async {
    if (mode == NidoUsageMode.guest) {
      final list = await LocalGuestStorage.getPockets();
      list.removeWhere((p) => p['id'] == pocketId);
      await LocalGuestStorage.savePockets(list);
    } else {
      await _firestore
          .collection('couples')
          .doc(coupleId)
          .collection('pockets')
          .doc(pocketId)
          .delete()
          .timeout(
            const Duration(milliseconds: 1500),
            onTimeout: () {},
          );
    }
  }

  // ==========================================
  // CICLO Y ARCHIVADO DE PERIODOS
  // ==========================================

  /// Obtiene la fecha de inicio del ciclo activo actual.
  Future<DateTime> getCycleStartDate({
    required String coupleId,
    required NidoUsageMode mode,
  }) async {
    if (mode == NidoUsageMode.guest) {
      return await LocalGuestStorage.getCycleStartDate();
    }

    try {
      final doc = await _firestore.collection('couples').doc(coupleId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final timestamp = data['cycle_start_date'] as Timestamp?;
        if (timestamp != null) {
          return timestamp.toDate();
        }
        final resetDay = (data['resetDay'] as num?)?.toInt() ?? 1;
        final now = DateTime.now();
        if (now.day >= resetDay) {
          return DateTime(now.year, now.month, resetDay);
        } else {
          final prevMonth = DateTime(now.year, now.month - 1, 1);
          final daysInPrevMonth = DateTime(now.year, now.month, 0).day;
          final safeDay = resetDay > daysInPrevMonth ? daysInPrevMonth : resetDay;
          return DateTime(prevMonth.year, prevMonth.month, safeDay);
        }
      }
    } catch (_) {}

    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  /// Consulta todos los gastos e ingresos registrados estrictamente en el ciclo indicado.
  Future<List<Expense>> getCycleExpenses({
    required String coupleId,
    required NidoUsageMode mode,
    required DateTime cycleStartDate,
    DateTime? cycleEndDate,
  }) async {
    final end = cycleEndDate ?? DateTime.now();
    if (mode == NidoUsageMode.guest) {
      final raw = await LocalGuestStorage.getExpenses();
      final parsed = raw.map((e) => Expense.fromJson(e)).toList();
      return parsed.where((e) {
        if (e.date.isBefore(cycleStartDate)) return false;
        if (e.date.isAfter(end)) return false;
        return true;
      }).toList();
    }

    final snapshot = await _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('expenses')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(cycleStartDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

    return snapshot.docs.map((doc) => Expense.fromFirestore(doc)).toList();
  }

  /// Archiva el periodo activo actual en el histórico y reinicia el saldo a $0 iniciando un nuevo ciclo.
  Future<HistoryPeriod> archiveCurrentPeriodAndReset({
    required String coupleId,
    required NidoUsageMode mode,
    required String userName,
    required String resetMode,
  }) async {
    final now = DateTime.now();
    final cycleStartDate = await getCycleStartDate(coupleId: coupleId, mode: mode);

    final expenses = await getCycleExpenses(
      coupleId: coupleId,
      mode: mode,
      cycleStartDate: cycleStartDate,
      cycleEndDate: now,
    );

    double totalIncome = 0.0;
    double totalExpense = 0.0;
    for (final e in expenses) {
      if (e.isIncome) {
        totalIncome += e.amount;
      } else {
        totalExpense += e.amount;
      }
    }
    final balance = totalIncome - totalExpense;

    String periodTitle;
    if (resetMode == 'biweekly') {
      periodTitle = 'Quincena (${DateFormat('d MMM', 'es').format(cycleStartDate)} - ${DateFormat('d MMM yyyy', 'es').format(now)})';
    } else {
      if (cycleStartDate.month == now.month && cycleStartDate.year == now.year) {
        periodTitle = DateFormat('MMMM yyyy', 'es').format(cycleStartDate).capitalize();
      } else {
        periodTitle = '${DateFormat('d MMM', 'es').format(cycleStartDate)} - ${DateFormat('d MMM yyyy', 'es').format(now)}';
      }
    }

    final period = HistoryPeriod(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: periodTitle,
      startDate: cycleStartDate,
      endDate: now,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      balance: balance,
      closedBy: userName,
      createdAt: now,
    );

    if (mode == NidoUsageMode.guest) {
      final historyList = await LocalGuestStorage.getHistory();
      historyList.add(period.toJson());
      await LocalGuestStorage.saveHistory(historyList);
      await LocalGuestStorage.setCycleStartDate(now);
    } else {
      await _firestore
          .collection('couples')
          .doc(coupleId)
          .collection('history_periods')
          .add({
            'title': period.title,
            'startDate': Timestamp.fromDate(period.startDate),
            'endDate': Timestamp.fromDate(period.endDate),
            'totalIncome': period.totalIncome,
            'totalExpense': period.totalExpense,
            'balance': period.balance,
            'closedBy': period.closedBy,
            'createdAt': Timestamp.fromDate(period.createdAt),
          });

      await _firestore
          .collection('couples')
          .doc(coupleId)
          .set({
            'cycle_start_date': Timestamp.fromDate(now),
          }, SetOptions(merge: true));
    }

    return period;
  }

  /// Reinicia el ciclo activo a $0 sin archivar nada en el histórico.
  Future<void> resetCycleWithoutArchiving({
    required String coupleId,
    required NidoUsageMode mode,
  }) async {
    final now = DateTime.now();
    if (mode == NidoUsageMode.guest) {
      await LocalGuestStorage.setCycleStartDate(now);
    } else {
      await _firestore
          .collection('couples')
          .doc(coupleId)
          .set({
            'cycle_start_date': Timestamp.fromDate(now),
          }, SetOptions(merge: true));
    }
  }

  /// Elimina un periodo archivado del histórico.
  Future<void> deleteHistoryPeriod({
    required String coupleId,
    required NidoUsageMode mode,
    required String periodId,
  }) async {
    if (mode == NidoUsageMode.guest) {
      final list = await LocalGuestStorage.getHistory();
      list.removeWhere((p) => p['id'] == periodId);
      await LocalGuestStorage.saveHistory(list);
    } else {
      await _firestore
          .collection('couples')
          .doc(coupleId)
          .collection('history_periods')
          .doc(periodId)
          .delete();
    }
  }
}

