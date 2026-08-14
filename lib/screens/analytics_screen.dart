import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';

// ==========================================
// PANTALLA 2: ANÁLISIS
// ==========================================
class AnalyticsScreen extends StatelessWidget {
  final String coupleId;
  final String userName;
  final NidoUsageMode mode;

  const AnalyticsScreen({
    super.key,
    required this.coupleId,
    required this.userName,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    if (mode == NidoUsageMode.guest) {
      return FutureBuilder<List<Map<String, dynamic>>>(
        future: LocalGuestStorage.getExpenses(),
        builder: (context, snapshot) {
          final raw = snapshot.data ?? [];
          final transactions = raw.map((e) => Expense.fromJson(e)).toList();
          return _buildAnalyticsContent(context, transactions);
        },
      );
    }

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('couples')
          .doc(coupleId)
          .collection('expenses')
          .where(
            'date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: kPrimaryColor),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final transactions = docs.map((d) => Expense.fromFirestore(d)).toList();

        return _buildAnalyticsContent(context, transactions);
      },
    );
  }

  Widget _buildAnalyticsContent(BuildContext context, List<Expense> transactions) {
    final surface = context.nidoSurface;
    final border = context.nidoBorder;
    final textDark = context.nidoTextDark;
    final textMuted = context.nidoTextMuted;
    final bg = context.nidoBg;

    final expensesOnly = transactions.where((t) => !t.isIncome).toList();
    final incomesOnly = transactions.where((t) => t.isIncome).toList();

    final totalIngresos = incomesOnly.fold<double>(0, (acc, t) => acc + t.amount);
    final totalGastos = expensesOnly.fold<double>(0, (acc, t) => acc + t.amount);
    final ahorroNeto = totalIngresos - totalGastos;

    final Map<String, double> gastosPorCategoria = {};
    for (var e in expensesOnly) {
      gastosPorCategoria[e.category] = (gastosPorCategoria[e.category] ?? 0) + e.amount;
    }
    final sortedCategories = gastosPorCategoria.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final Map<String, double> ingresosPorMiembro = {};
    for (var i in incomesOnly) {
      final user = i.createdBy.isNotEmpty ? i.createdBy : 'Usuario';
      ingresosPorMiembro[user] = (ingresosPorMiembro[user] ?? 0) + i.amount;
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Image.asset(
                'assets/images/nido_icon.png',
                width: 26,
                height: 26,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.favorite, color: kPrimaryColor, size: 22),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Nido · Análisis',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          AnimatedListItem(
            index: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: border, width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Balance Financiero del Mes',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildMetricTile(
                        label: 'Ingresos',
                        value: formatCurrency(totalIngresos),
                        color: kIncomeColor,
                        textMuted: textMuted,
                        bg: bg,
                        border: border,
                      ),
                      const SizedBox(width: 8),
                      _buildMetricTile(
                        label: 'Gastos',
                        value: formatCurrency(totalGastos),
                        color: kExpenseColor,
                        textMuted: textMuted,
                        bg: bg,
                        border: border,
                      ),
                      const SizedBox(width: 8),
                      _buildMetricTile(
                        label: 'Balance',
                        value: formatCurrency(ahorroNeto),
                        color: ahorroNeto >= 0 ? kDisponibleColor : kExpenseColor,
                        textMuted: textMuted,
                        bg: bg,
                        border: border,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Gráfica de barras sencilla: 3 valores comparados
                  _buildSimpleBar(
                    label: 'Ingresos',
                    value: totalIngresos,
                    maxValue: [totalIngresos, totalGastos, ahorroNeto.abs()].reduce((a, b) => a > b ? a : b).clamp(1.0, double.infinity),
                    color: const Color(0xFF34D399),
                    textMuted: textMuted,
                    textDark: textDark,
                    bg: bg,
                  ),
                  const SizedBox(height: 10),
                  _buildSimpleBar(
                    label: 'Egresos',
                    value: totalGastos,
                    maxValue: [totalIngresos, totalGastos, ahorroNeto.abs()].reduce((a, b) => a > b ? a : b).clamp(1.0, double.infinity),
                    color: const Color(0xFFFF5252),
                    textMuted: textMuted,
                    textDark: textDark,
                    bg: bg,
                  ),
                  const SizedBox(height: 10),
                  _buildSimpleBar(
                    label: 'Balance',
                    value: ahorroNeto.abs(),
                    maxValue: [totalIngresos, totalGastos, ahorroNeto.abs()].reduce((a, b) => a > b ? a : b).clamp(1.0, double.infinity),
                    color: ahorroNeto >= 0 ? kDisponibleColor : kExpenseColor,
                    prefix: ahorroNeto >= 0 ? '+' : '-',
                    textMuted: textMuted,
                    textDark: textDark,
                    bg: bg,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          AnimatedListItem(
            index: 1,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: border, width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Distribución de Gastos por Categoría',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (sortedCategories.isEmpty)
                    Text(
                      'Aún no hay gastos registrados este mes.',
                      style: TextStyle(color: textMuted, fontSize: 13),
                    )
                  else
                    ...sortedCategories.map((entry) {
                      final porcentaje = totalGastos > 0
                          ? (entry.value / totalGastos)
                          : 0.0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    entry.key,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: textDark,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      '${formatCurrency(entry.value)} (${(porcentaje * 100).toStringAsFixed(1)}%)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: textDark,
                                      ),
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            TweenAnimationBuilder<double>(
                              key: ValueKey(entry.key),
                              tween: Tween(begin: 0.0, end: porcentaje),
                              duration: const Duration(milliseconds: 900),
                              curve: Curves.easeOutCubic,
                              builder: (context, val, child) => ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: val,
                                  minHeight: 8,
                                  backgroundColor: bg,
                                  color: kPrimaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          AnimatedListItem(
            index: 2,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: border, width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aportantes al Fondo',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (ingresosPorMiembro.isEmpty)
                    Text(
                      'Aún no se han registrado ingresos este mes.',
                      style: TextStyle(color: textMuted, fontSize: 13),
                    )
                  else
                    ...ingresosPorMiembro.entries.map((e) {
                      final pct = totalIngresos > 0
                          ? (e.value / totalIngresos)
                          : 0.0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: kSecondaryColor.withValues(alpha: 0.2),
                              child: Text(
                                e.key.substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: kSecondaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.key,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  TweenAnimationBuilder<double>(
                                    key: ValueKey(e.key),
                                    tween: Tween(begin: 0.0, end: pct),
                                    duration: const Duration(milliseconds: 900),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, val, child) => ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: val,
                                        minHeight: 6,
                                        backgroundColor: bg,
                                        color: kSecondaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${formatCurrency(e.value)} (${(pct * 100).toInt()}%)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: textDark,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleBar({
    required String label,
    required double value,
    required double maxValue,
    required Color color,
    required Color textMuted,
    required Color textDark,
    required Color bg,
    String prefix = '',
  }) {
    final ratio = maxValue > 0 ? (value / maxValue).clamp(0.0, 1.0) : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textMuted,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                // Fondo de la barra
                Container(height: 22, color: bg),
                // Relleno proporcional animado
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: ratio),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (context, val, _) => FractionallySizedBox(
                    widthFactor: val,
                    child: Container(
                      height: 22,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 90,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              '$prefix${formatCurrency(value)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required Color color,
    required Color textMuted,
    required Color bg,
    required Color border,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: 1.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: textMuted,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
