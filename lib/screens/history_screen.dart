import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../main.dart';

// ==========================================
// PANTALLA 5: HISTÓRICO DE PERIODOS
// ==========================================
class HistoryScreen extends StatefulWidget {
  final String coupleId;
  final NidoUsageMode mode;

  const HistoryScreen({super.key, required this.coupleId, required this.mode});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _guestRefreshCount = 0;

  Future<void> _confirmarEliminarPeriodo(HistoryPeriod period) async {
    final surface = context.nidoSurface;
    final textDark = context.nidoTextDark;
    final textMuted = context.nidoTextMuted;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.delete_outline_rounded, color: kDangerColor, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '¿Eliminar periodo archivado?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: textDark,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Se eliminará el resumen "${period.title}" de tu histórico. Esta acción no se puede deshacer.',
          style: TextStyle(fontSize: 13, color: textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kDangerColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await NidoRepository.instance.deleteHistoryPeriod(
        coupleId: widget.coupleId,
        mode: widget.mode,
        periodId: period.id,
      );

      if (mounted) {
        setState(() {
          _guestRefreshCount++;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Periodo archivado eliminado'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar periodo: ${e.toString()}'),
            backgroundColor: kDangerColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mode == NidoUsageMode.guest) {
      return FutureBuilder<List<Map<String, dynamic>>>(
        key: ValueKey('guest_history_$_guestRefreshCount'),
        future: LocalGuestStorage.getHistory(),
        builder: (context, snapshot) {
          final raw = snapshot.data ?? [];
          final periods = raw.map((e) => HistoryPeriod.fromJson(e)).toList();
          periods.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return _buildHistoryUI(context, periods);
        },
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('couples')
          .doc(widget.coupleId)
          .collection('history_periods')
          .orderBy('createdAt', descending: true)
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
                  'Usa "Archivar Periodo Actual" en el Menú para guardar resúmenes de ciclos pasados.',
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              itemCount: periods.length,
              itemBuilder: (context, index) {
                final p = periods[index];
                final isPositive = p.balance >= 0;

                final dateRangeStr =
                    '${DateFormat('d MMM yyyy', 'es').format(p.startDate)} – ${DateFormat('d MMM yyyy', 'es').format(p.endDate)}';

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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: kPrimaryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.history_rounded,
                              color: kPrimaryColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: textDark,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  dateRangeStr,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: textMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
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
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: Colors.grey,
                            ),
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Eliminar del histórico',
                            onPressed: () => _confirmarEliminarPeriodo(p),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
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
                                const SizedBox(height: 2),
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
                                const SizedBox(height: 2),
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
                                const SizedBox(height: 2),
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
                      if (p.closedBy.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Cerrado por ${p.closedBy}',
                          style: TextStyle(
                            fontSize: 11,
                            color: textMuted.withValues(alpha: 0.8),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }
}
