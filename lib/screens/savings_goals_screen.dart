import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';

// ==========================================
// PANTALLA 4: METAS DE AHORRO
// ==========================================
class SavingsGoalsScreen extends StatefulWidget {
  final String coupleId;
  final NidoUsageMode mode;

  const SavingsGoalsScreen({
    super.key,
    required this.coupleId,
    required this.mode,
  });

  @override
  State<SavingsGoalsScreen> createState() => _SavingsGoalsScreenState();
}

class _SavingsGoalsScreenState extends State<SavingsGoalsScreen> {
  List<Map<String, dynamic>> _guestSavings = [];

  @override
  void initState() {
    super.initState();
    if (widget.mode == NidoUsageMode.guest) {
      _loadGuestSavings();
    }
  }

  Future<void> _loadGuestSavings() async {
    final list = await LocalGuestStorage.getSavings();
    if (mounted) setState(() => _guestSavings = list);
  }

  void _addGoal(BuildContext context) {
    final titleController = TextEditingController();
    final targetController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: context.nidoSurface,
        title: Text(
          'Nueva Meta de Ahorro',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: context.nidoTextDark,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(color: context.nidoTextDark),
              decoration: InputDecoration(
                labelText: '¿Para qué estamos ahorrando?',
                labelStyle: TextStyle(color: context.nidoTextMuted),
                prefixIcon: Icon(
                  Icons.flag_outlined,
                  size: 20,
                  color: context.nidoTextMuted,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: targetController,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsSeparatorInputFormatter()],
              style: TextStyle(color: context.nidoTextDark),
              decoration: InputDecoration(
                labelText: 'Meta \$',
                labelStyle: TextStyle(color: context.nidoTextMuted),
                prefixIcon: Icon(
                  Icons.attach_money,
                  size: 20,
                  color: context.nidoTextMuted,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: context.nidoTextMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final target = parseFormattedAmount(targetController.text);
              final title = titleController.text.trim();
              if (title.isNotEmpty && target > 0) {
                if (widget.mode == NidoUsageMode.guest) {
                  _guestSavings.add({
                    'id': DateTime.now().millisecondsSinceEpoch.toString(),
                    'title': title,
                    'target': target,
                    'current': 0.0,
                  });
                  await LocalGuestStorage.saveSavings(_guestSavings);
                  _loadGuestSavings();
                } else {
                  await FirebaseFirestore.instance
                      .collection('couples')
                      .doc(widget.coupleId)
                      .collection('savings')
                      .add({
                        'title': title,
                        'target': target,
                        'current': 0.0,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
              titleController.dispose();
              targetController.dispose();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Crear Meta'),
          ),
        ],
      ),
    );
  }

  void _editarMeta(
    BuildContext context,
    String goalId,
    String title,
    double target,
    double current,
  ) {
    final titleCtrl = TextEditingController(text: title);
    final targetCtrl = TextEditingController(text: target.toInt().toString());
    final currentCtrl = TextEditingController(text: current.toInt().toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: context.nidoSurface,
        title: Text(
          'Modificar Meta de Ahorro',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: context.nidoTextDark,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              style: TextStyle(color: context.nidoTextDark),
              decoration: InputDecoration(
                labelText: 'Título de la meta',
                labelStyle: TextStyle(color: context.nidoTextMuted),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: targetCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsSeparatorInputFormatter()],
              style: TextStyle(color: context.nidoTextDark),
              decoration: InputDecoration(
                labelText: 'Monto objetivo \$',
                labelStyle: TextStyle(color: context.nidoTextMuted),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: currentCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsSeparatorInputFormatter()],
              style: TextStyle(color: context.nidoTextDark),
              decoration: InputDecoration(
                labelText: 'Saldo actual ahorrado \$',
                labelStyle: TextStyle(color: context.nidoTextMuted),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: context.nidoTextMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newTitle = titleCtrl.text.trim();
              final newTarget = parseFormattedAmount(targetCtrl.text);
              final newCurrent = parseFormattedAmount(currentCtrl.text);

              if (newTitle.isNotEmpty && newTarget > 0) {
                if (widget.mode == NidoUsageMode.guest) {
                  final idx = _guestSavings.indexWhere(
                    (s) => s['id'] == goalId,
                  );
                  if (idx != -1) {
                    _guestSavings[idx]['title'] = newTitle;
                    _guestSavings[idx]['target'] = newTarget;
                    _guestSavings[idx]['current'] = newCurrent;
                    await LocalGuestStorage.saveSavings(_guestSavings);
                    _loadGuestSavings();
                  }
                } else {
                  await FirebaseFirestore.instance
                      .collection('couples')
                      .doc(widget.coupleId)
                      .collection('savings')
                      .doc(goalId)
                      .update({
                        'title': newTitle,
                        'target': newTarget,
                        'current': newCurrent,
                      });
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
              titleCtrl.dispose();
              targetCtrl.dispose();
              currentCtrl.dispose();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _borrarMeta(BuildContext context, String goalId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: context.nidoSurface,
        title: Text(
          '¿Borrar meta de ahorro?',
          style: TextStyle(color: context.nidoTextDark),
        ),
        content: Text(
          '¿Seguro que deseas borrar "$title"?',
          style: TextStyle(color: context.nidoTextMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: context.nidoTextMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kDangerColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Borrar Meta'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (widget.mode == NidoUsageMode.guest) {
        _guestSavings.removeWhere((s) => s['id'] == goalId);
        await LocalGuestStorage.saveSavings(_guestSavings);
        _loadGuestSavings();
      } else {
        await FirebaseFirestore.instance
            .collection('couples')
            .doc(widget.coupleId)
            .collection('savings')
            .doc(goalId)
            .delete();
      }
      HapticFeedback.lightImpact();
    }
  }

  void _contribuirAhorro(
    BuildContext context,
    String goalId,
    double currentSavings,
    double target,
  ) {
    final amountController = TextEditingController();
    final remaining = target - currentSavings;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: context.nidoSurface,
        title: Text(
          'Abonar al Ahorro',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: context.nidoTextDark,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Faltan ${formatCurrency(remaining)} para la meta.',
              style: TextStyle(fontSize: 13, color: context.nidoTextMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsSeparatorInputFormatter()],
              autofocus: true,
              style: TextStyle(color: context.nidoTextDark),
              decoration: InputDecoration(
                labelText: 'Monto a abonar \$',
                labelStyle: TextStyle(color: context.nidoTextMuted),
                prefixIcon: Icon(
                  Icons.attach_money,
                  size: 20,
                  color: context.nidoTextMuted,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: context.nidoTextMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = parseFormattedAmount(amountController.text);
              if (val > 0) {
                if (widget.mode == NidoUsageMode.guest) {
                  final idx = _guestSavings.indexWhere(
                    (s) => s['id'] == goalId,
                  );
                  if (idx != -1) {
                    final old =
                        (_guestSavings[idx]['current'] as num?)?.toDouble() ??
                        0.0;
                    _guestSavings[idx]['current'] = old + val;
                    await LocalGuestStorage.saveSavings(_guestSavings);
                    _loadGuestSavings();
                  }
                } else {
                  await FirebaseFirestore.instance
                      .collection('couples')
                      .doc(widget.coupleId)
                      .collection('savings')
                      .doc(goalId)
                      .update({'current': FieldValue.increment(val)});
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
              amountController.dispose();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Abonar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Metas de Ahorro')),
      body: widget.mode == NidoUsageMode.guest
          ? _buildSavingsUI(
              _guestSavings
                  .map(
                    (s) => _SavingsGoalWrapper(
                      id: (s['id'] as String?) ?? '',
                      title: (s['title'] as String?) ?? 'Meta',
                      target: ((s['target'] as num?) ?? 0.0).toDouble(),
                      current: ((s['current'] as num?) ?? 0.0).toDouble(),
                    ),
                  )
                  .toList(),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('couples')
                  .doc(widget.coupleId)
                  .collection('savings')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: kPrimaryColor),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                final goals = docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return _SavingsGoalWrapper(
                    id: doc.id,
                    title: (data['title'] as String?) ?? 'Meta',
                    target: ((data['target'] as num?) ?? 0.0).toDouble(),
                    current: ((data['current'] as num?) ?? 0.0).toDouble(),
                  );
                }).toList();

                return _buildSavingsUI(goals);
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addGoal(context),
        elevation: 0,
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSavingsUI(List<_SavingsGoalWrapper> goals) {
    if (goals.isEmpty) {
      return const EmptyState(
        icon: Icons.savings_outlined,
        title: 'Sin metas aún',
        subtitle: 'Crea tu primera meta de ahorro.',
      );
    }

    final surface = context.nidoSurface;
    final border = context.nidoBorder;
    final textDark = context.nidoTextDark;
    final textMuted = context.nidoTextMuted;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      itemCount: goals.length,
      itemBuilder: (context, index) {
        final goal = goals[index];
        final double progress = goal.target > 0
            ? (goal.current / goal.target).clamp(0.0, 1.0)
            : 0.0;
        final bool isCompleted = goal.target > 0 && goal.current >= goal.target;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isCompleted
                ? kSecondaryColor.withValues(alpha: 0.08)
                : surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isCompleted
                  ? kSecondaryColor.withValues(alpha: 0.4)
                  : border,
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      goal.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textDark,
                      ),
                    ),
                  ),
                  if (isCompleted)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: kSecondaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '✓ Logrado',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: kSecondaryColor,
                        ),
                      ),
                    ),
                  IconButton(
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: textMuted,
                    ),
                    onPressed: () => _editarMeta(
                      context,
                      goal.id,
                      goal.title,
                      goal.target,
                      goal.current,
                    ),
                    tooltip: 'Modificar meta',
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: kDangerColor,
                    ),
                    onPressed: () => _borrarMeta(context, goal.id, goal.title),
                    tooltip: 'Borrar meta',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: border,
                  color: isCompleted ? kSecondaryColor : kPrimaryColor,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${formatCurrency(goal.current)} de ${formatCurrency(goal.target)}',
                    style: TextStyle(fontSize: 12, color: textMuted),
                  ),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: textDark,
                    ),
                  ),
                ],
              ),
              if (!isCompleted) ...[
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: () => _contribuirAhorro(
                      context,
                      goal.id,
                      goal.current,
                      goal.target,
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text(
                      'Abonar',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: surface,
                      foregroundColor: kPrimaryColor,
                      elevation: 0,
                      side: const BorderSide(color: kPrimaryColor, width: 1.0),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SavingsGoalWrapper {
  final String id;
  final String title;
  final double target;
  final double current;

  _SavingsGoalWrapper({
    required this.id,
    required this.title,
    required this.target,
    required this.current,
  });
}
