import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';

// ==========================================
// PANTALLA 5: HISTÓRICO DE PERIODOS
// ==========================================
class HistoryScreen extends StatelessWidget {
  final String coupleId;
  final NidoUsageMode mode;

  const HistoryScreen({super.key, required this.coupleId, required this.mode});

  @override
  Widget build(BuildContext context) {
    if (mode == NidoUsageMode.guest) {
      return FutureBuilder<List<Map<String, dynamic>>>(
        future: LocalGuestStorage.getHistory(),
        builder: (context, snapshot) {
          final raw = snapshot.data ?? [];
          final periods = raw.map((e) => HistoryPeriod.fromJson(e)).toList();
          return _buildHistoryUI(context, periods);
        },
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('couples')
          .doc(coupleId)
          .collection('history_periods')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: kPrimaryColor),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final periods = docs
            .map((d) => HistoryPeriod.fromFirestore(d))
            .toList();

        return _buildHistoryUI(context, periods);
      },
    );
  }

  Widget _buildHistoryUI(BuildContext context, List<HistoryPeriod> periods) {
    final surface = context.nidoSurface;
    final border = context.nidoBorder;
    final textDark = context.nidoTextDark;
    final textMuted = context.nidoTextMuted;

    return Scaffold(
      appBar: AppBar(title: const Text('Histórico de Periodos')),
      body: periods.isEmpty
          ? const EmptyState(
              icon: Icons.history_toggle_off_rounded,
              title: 'Sin periodos archivados',
              subtitle:
                  'Usa "Archivar Periodo" en el Menú para guardar resúmenes de ciclos pasados.',
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              itemCount: periods.length,
              itemBuilder: (context, index) {
                final p = periods[index];
                final isPositive = p.balance >= 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: border, width: 1.2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.history_rounded,
                            color: kPrimaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            p.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textDark,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: (isPositive
                                      ? kIncomeColor
                                      : kExpenseColor)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isPositive ? 'Superávit' : 'Déficit',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isPositive
                                    ? kIncomeColor
                                    : kExpenseColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ingresos',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: textMuted,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    formatCurrency(p.totalIncome),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: kIncomeColor,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Gastos',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: textMuted,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    formatCurrency(p.totalExpense),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: kExpenseColor,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Balance Final',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: textMuted,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    formatCurrency(p.balance),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: isPositive
                                          ? kIncomeColor
                                          : kExpenseColor,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
