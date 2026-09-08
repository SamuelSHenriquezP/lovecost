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
}
