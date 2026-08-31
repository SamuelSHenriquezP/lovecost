import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import 'services.dart';

/// Unified Repository providing transparent data access across Guest (local) and Couple/Individual (Firestore) modes.
class NidoRepository {
  NidoRepository._internal();
  static final NidoRepository instance = NidoRepository._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==========================================
  // EXPENSES / MOVIMIENTOS
  // ==========================================

  /// Stream of active expenses starting from cycleStartDate.
  Stream<List<Expense>> streamExpenses({
    required String coupleId,
    required NidoUsageMode mode,
    required DateTime cycleStartDate,
    int? limit,
  }) {
    if (mode == NidoUsageMode.guest) {
      return Stream.fromFuture(LocalGuestStorage.getExpenses()).map((raw) {
        final parsed = raw.map((e) => Expense.fromJson(e)).toList();
        final filtered = parsed
            .where((e) => !e.date.isBefore(cycleStartDate))
            .toList();
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
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(cycleStartDate))
        .orderBy('date', descending: true);

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
      await _firestore
          .collection('couples')
          .doc(coupleId)
          .collection('expenses')
          .add({
            'type': expense.type,
            'amount': expense.amount,
            'description': expense.description,
            'category': expense.category,
            'sourceOrDestination': expense.sourceOrDestination,
            'createdBy': expense.createdBy,
            'date': Timestamp.fromDate(expense.date),
            'reactions': expense.reactions,
          });
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
          .delete();
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
}
