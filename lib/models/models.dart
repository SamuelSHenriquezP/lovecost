import 'package:cloud_firestore/cloud_firestore.dart';

// ==========================================
// MODOS DE USO DE LA APP
// ==========================================
enum NidoUsageMode {
  guest, // Invitado 100% local
  individual, // Usuario logueado como Individuo (Personal)
  couple, // Usuario logueado en Pareja
}

// ==========================================
// MODELOS DE DATOS
// ==========================================
class Expense {
  final String id;
  final String type; // 'expense' o 'income'
  final double amount;
  final String description;
  final String category;
  final String sourceOrDestination;
  final String createdBy;
  final DateTime date;
  final Map<String, String> reactions;

  const Expense({
    required this.id,
    this.type = 'expense',
    required this.amount,
    required this.description,
    required this.category,
    this.sourceOrDestination = 'General',
    required this.createdBy,
    required this.date,
    this.reactions = const {},
  });

  bool get isIncome => type == 'income';

  factory Expense.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawReactions = data['reactions'] as Map<String, dynamic>? ?? {};
    final reactions = rawReactions.map((k, v) => MapEntry(k, v.toString()));

    return Expense(
      id: doc.id,
      type: (data['type'] as String?) ?? 'expense',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      description: (data['description'] as String?) ?? '',
      category: (data['category'] as String?) ?? 'Otros',
      sourceOrDestination:
          (data['sourceOrDestination'] as String?) ??
          (data['paymentMethod'] as String?) ??
          'General',
      createdBy: (data['createdBy'] as String?) ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reactions: reactions,
    );
  }

  factory Expense.fromJson(Map<String, dynamic> data) {
    final rawReactions = data['reactions'] as Map<String, dynamic>? ?? {};
    final reactions = rawReactions.map((k, v) => MapEntry(k, v.toString()));

    return Expense(
      id:
          (data['id'] as String?) ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      type: (data['type'] as String?) ?? 'expense',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      description: (data['description'] as String?) ?? '',
      category: (data['category'] as String?) ?? 'Otros',
      sourceOrDestination:
          (data['sourceOrDestination'] as String?) ?? 'General',
      createdBy: (data['createdBy'] as String?) ?? 'Invitado',
      date: DateTime.tryParse(data['date'] as String? ?? '') ?? DateTime.now(),
      reactions: reactions,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'amount': amount,
    'description': description,
    'category': category,
    'sourceOrDestination': sourceOrDestination,
    'createdBy': createdBy,
    'date': date.toIso8601String(),
    'reactions': reactions,
  };
}

class CustomCategory {
  final String id;
  final String name;
  final String emoji;
  final int colorHex;
  final String type;

  CustomCategory({
    required this.id,
    required this.name,
    required this.emoji,
    required this.colorHex,
    required this.type,
  });

  factory CustomCategory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CustomCategory(
      id: doc.id,
      name: (data['name'] as String?) ?? 'Categoría',
      emoji: (data['emoji'] as String?) ?? '🏷️',
      colorHex: (data['colorHex'] as num?)?.toInt() ?? 0xFF00897B,
      type: (data['type'] as String?) ?? 'expense',
    );
  }

  factory CustomCategory.fromJson(Map<String, dynamic> data) {
    return CustomCategory(
      id:
          (data['id'] as String?) ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: (data['name'] as String?) ?? 'Categoría',
      emoji: (data['emoji'] as String?) ?? '🏷️',
      colorHex: (data['colorHex'] as num?)?.toInt() ?? 0xFF00897B,
      type: (data['type'] as String?) ?? 'expense',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'colorHex': colorHex,
    'type': type,
  };
}

class HistoryPeriod {
  final String id;
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final double totalIncome;
  final double totalExpense;
  final double balance;
  final String closedBy;
  final DateTime createdAt;

  HistoryPeriod({
    required this.id,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
    required this.closedBy,
    required this.createdAt,
  });

  factory HistoryPeriod.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HistoryPeriod(
      id: doc.id,
      title: (data['title'] as String?) ?? 'Periodo Pasado',
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      totalIncome: ((data['totalIncome'] as num?) ?? 0.0).toDouble(),
      totalExpense: ((data['totalExpense'] as num?) ?? 0.0).toDouble(),
      balance: ((data['balance'] as num?) ?? 0.0).toDouble(),
      closedBy: (data['closedBy'] as String?) ?? 'Nido',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory HistoryPeriod.fromJson(Map<String, dynamic> data) {
    return HistoryPeriod(
      id:
          (data['id'] as String?) ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: (data['title'] as String?) ?? 'Periodo Pasado',
      startDate:
          DateTime.tryParse(data['startDate'] as String? ?? '') ??
          DateTime.now(),
      endDate:
          DateTime.tryParse(data['endDate'] as String? ?? '') ?? DateTime.now(),
      totalIncome: ((data['totalIncome'] as num?) ?? 0.0).toDouble(),
      totalExpense: ((data['totalExpense'] as num?) ?? 0.0).toDouble(),
      balance: ((data['balance'] as num?) ?? 0.0).toDouble(),
      closedBy: (data['closedBy'] as String?) ?? 'Nido',
      createdAt:
          DateTime.tryParse(data['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'totalIncome': totalIncome,
    'totalExpense': totalExpense,
    'balance': balance,
    'closedBy': closedBy,
    'createdAt': createdAt.toIso8601String(),
  };
}
