import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';

// Exports list of default categories for external filtering sheets
const List<Map<String, dynamic>> defaultExpenseCategories = [
  {'name': 'Citas & Salidas', 'icon': Icons.local_bar_outlined},
  {'name': 'Supermercado', 'icon': Icons.shopping_cart_outlined},
  {'name': 'Viajes & Escapadas', 'icon': Icons.flight_outlined},
  {'name': 'Servicios & Hogar', 'icon': Icons.home_outlined},
  {'name': 'Detalles & Sorpresas', 'icon': Icons.card_giftcard_outlined},
  {'name': 'Entretenimiento', 'icon': Icons.movie_outlined},
  {'name': 'Ahorro Pareja', 'icon': Icons.savings_outlined},
  {'name': 'Transporte', 'icon': Icons.directions_car_outlined},
  {'name': 'Otros', 'icon': Icons.more_horiz_outlined},
];

const List<Map<String, dynamic>> defaultIncomeCategories = [
  {'name': 'Sueldo / Nómina', 'icon': Icons.attach_money_outlined},
  {'name': 'Freelance / Trabajo', 'icon': Icons.work_outline},
  {'name': 'Rendimientos', 'icon': Icons.trending_up_outlined},
  {'name': 'Regalo / Bono', 'icon': Icons.card_giftcard_outlined},
  {'name': 'Ahorro Previo', 'icon': Icons.account_balance_outlined},
  {'name': 'Otros', 'icon': Icons.more_horiz_outlined},
];

class InviteCodeCard extends StatelessWidget {
  final String inviteCode;

  const InviteCodeCard({super.key, required this.inviteCode});

  void _copyCode(BuildContext context) {
    if (inviteCode.isEmpty) return;
    Clipboard.setData(ClipboardData(text: inviteCode));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Código copiado al portapapeles'),
        backgroundColor: kSecondaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (inviteCode.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kSecondaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kSecondaryColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(
            'Comparte este código con tu pareja:',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: context.nidoTextMuted),
          ),
          const SizedBox(height: 10),
          Text(
            inviteCode,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: context.nidoTextDark,
              letterSpacing: 6,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _copyCode(context),
            icon: const Icon(
              Icons.copy_rounded,
              size: 16,
              color: kPrimaryColor,
            ),
            label: const Text(
              'Copiar código',
              style: TextStyle(
                color: kPrimaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ExpenseCard extends StatelessWidget {
  final Expense expense;
  final String coupleId;
  final String currentUserName;
  final NidoUsageMode mode;
  final VoidCallback onEdit;
  final VoidCallback? onGuestRefresh;
  final List<CustomCategory> customCategories;

  const ExpenseCard({
    super.key,
    required this.expense,
    required this.coupleId,
    required this.currentUserName,
    required this.mode,
    required this.onEdit,
    this.onGuestRefresh,
    this.customCategories = const [],
  });

  Color _categoryColor(String cat, bool isIncome) {
    final custom = customCategories.where((c) => c.name == cat).toList();
    if (custom.isNotEmpty) {
      return Color(custom.first.colorHex);
    }

    if (isIncome) return kIncomeColor;
    switch (cat) {
      case 'Citas & Salidas':
      case 'Comida':
        return kExpenseColor;
      case 'Supermercado':
        return const Color(0xFF059669);
      case 'Viajes & Escapadas':
        return const Color(0xFF0284C7);
      case 'Servicios & Hogar':
      case 'Hogar':
        return const Color(0xFFEA580C);
      case 'Detalles & Sorpresas':
        return const Color(0xFF9333EA);
      case 'Entretenimiento':
      case 'Suscripciones':
        return const Color(0xFFD97706);
      case 'Ahorro Pareja':
        return const Color(0xFF0D9488);
      case 'Transporte':
        return const Color(0xFF2563EB);
      default:
        return kSecondaryColor;
    }
  }

  String _categoryEmoji(String cat) {
    final custom = customCategories.where((c) => c.name == cat).toList();
    if (custom.isNotEmpty) {
      return custom.first.emoji;
    }

    switch (cat) {
      case 'Sueldo / Nómina':
        return '💵';
      case 'Freelance / Trabajo':
        return '💼';
      case 'Rendimientos':
        return '📈';
      case 'Regalo / Bono':
        return '🎉';
      case 'Ahorro Previo':
        return '🏦';
      case 'Citas & Salidas':
      case 'Comida':
        return '🍷';
      case 'Supermercado':
        return '🛒';
      case 'Viajes & Escapadas':
        return '✈️';
      case 'Servicios & Hogar':
      case 'Hogar':
        return '🏠';
      case 'Detalles & Sorpresas':
        return '🎁';
      case 'Entretenimiento':
      case 'Suscripciones':
        return '🍿';
      case 'Ahorro Pareja':
        return '🐷';
      case 'Transporte':
        return '🚗';
      default:
        return expense.isIncome ? '💰' : '💸';
    }
  }

  void _showReactionPicker(BuildContext context) {
    if (mode == NidoUsageMode.guest) return;

    final reactions = [
      '🥰 ¡Gracias mi amor!',
      '❤️ ¡Anotado!',
      '🍰 ¡Te debo un postre!',
      '🥂 ¡Salud por nosotros!',
      '👏 ¡Buen movimiento!',
    ];
    final noteController = TextEditingController();
    String? selectedReaction;
    final surface = context.nidoSurface;
    final bg = context.nidoBg;
    final border = context.nidoBorder;
    final textDark = context.nidoTextDark;
    final textMuted = context.nidoTextMuted;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: StatefulBuilder(
          builder: (ctx, setModalState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Reaccionar a este movimiento 💕',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  expense.createdBy == currentUserName
                      ? 'Deja una nota para recordar este movimiento'
                      : 'Responde al gasto de ${expense.createdBy}',
                  style: TextStyle(fontSize: 12, color: textMuted),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: reactions.map((r) {
                    final isSelected = selectedReaction == r;
                    return ActionChip(
                      label: Text(
                        r,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? kPrimaryColor : textDark,
                        ),
                      ),
                      backgroundColor: isSelected
                          ? kPrimaryColor.withValues(alpha: 0.15)
                          : bg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isSelected ? kPrimaryColor : border,
                        ),
                      ),
                      onPressed: () =>
                          setModalState(() => selectedReaction = r),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: noteController,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Nota personal (opcional)',
                    hintText:
                        'Ej: Está bien, pero la próxima lo vemos juntos 💬',
                    prefixIcon: Icon(
                      Icons.edit_note_outlined,
                      size: 20,
                      color: textMuted,
                    ),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    final note = noteController.text.trim();
                    if (selectedReaction == null && note.isEmpty) return;

                    final String reactionText = [
                      if (selectedReaction != null) selectedReaction!,
                      if (note.isNotEmpty) note,
                    ].join(' · ');

                    Navigator.pop(ctx);
                    final updatedReactions = Map<String, String>.from(
                      expense.reactions,
                    );
                    updatedReactions[currentUserName] = reactionText;

                    await FirebaseFirestore.instance
                        .collection('couples')
                        .doc(coupleId)
                        .collection('expenses')
                        .doc(expense.id)
                        .update({'reactions': updatedReactions});

                    showLocalNotification(
                      '💬 Comentario de $currentUserName',
                      'Reaccionó en ${expense.description.isEmpty ? 'movimiento' : expense.description}: "$reactionText"',
                    );

                    HapticFeedback.lightImpact();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Enviar respuesta',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(noteController.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = expense.isIncome;
    final accentColor = _categoryColor(expense.category, isIncome);
    final initial = expense.createdBy.isNotEmpty
        ? expense.createdBy.substring(0, 1).toUpperCase()
        : '?';

    final surface = context.nidoSurface;
    final bg = context.nidoBg;
    final border = context.nidoBorder;
    final textDark = context.nidoTextDark;
    final textMuted = context.nidoTextMuted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Dismissible(
        key: Key(expense.id),
        direction: DismissDirection.endToStart,
        secondaryBackground: Container(
          decoration: BoxDecoration(
            color: Colors.red.shade900.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(
            Icons.delete_outline,
            color: kDangerColor,
            size: 24,
          ),
        ),
        background: const SizedBox.shrink(),
        confirmDismiss: (_) async {
          bool confirm = false;
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: surface,
              title: Text(
                isIncome ? '¿Eliminar ingreso?' : '¿Eliminar gasto?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
              content: Text(
                expense.description.isEmpty
                    ? 'Esto eliminará el movimiento de ${formatCurrency(expense.amount)}.'
                    : '¿Seguro que quieres eliminar "${expense.description}"?',
                style: TextStyle(color: textMuted, fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(color: textMuted),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    confirm = true;
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kDangerColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  child: const Text('Eliminar'),
                ),
              ],
            ),
          );
          return confirm;
        },
        onDismissed: (_) async {
          if (mode == NidoUsageMode.guest) {
            final list = await LocalGuestStorage.getExpenses();
            list.removeWhere((item) => item['id'] == expense.id);
            await LocalGuestStorage.saveExpenses(list);
            if (onGuestRefresh != null) onGuestRefresh!();
          } else {
            await FirebaseFirestore.instance
                .collection('couples')
                .doc(coupleId)
                .collection('expenses')
                .doc(expense.id)
                .delete();
          }
          HapticFeedback.lightImpact();
        },
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(width: 5, color: accentColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                _categoryEmoji(expense.category),
                                style: const TextStyle(fontSize: 20),
                              ),
                            ),
                            const SizedBox(width: 12),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    expense.description.isEmpty
                                        ? (isIncome
                                              ? 'Ingreso registrado'
                                              : 'Gasto general')
                                        : expense.description,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: textDark,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${expense.category} · ${formatDate(expense.date)}',
                                    style: TextStyle(
                                      color: textMuted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isIncome
                                        ? kIncomeColor.withValues(alpha: 0.12)
                                        : kExpenseColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${isIncome ? '+' : '-'}${formatCurrency(expense.amount)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: isIncome
                                          ? kIncomeColor
                                          : kExpenseColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: bg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 7,
                                    backgroundColor: accentColor,
                                    child: Text(
                                      initial,
                                      style: const TextStyle(
                                        fontSize: 8,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    expense.createdBy,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: textMuted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),

                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: bg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '📍 ${expense.sourceOrDestination}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),

                            const Spacer(),

                            IconButton(
                              icon: Icon(
                                Icons.edit_outlined,
                                size: 16,
                                color: textMuted,
                              ),
                              onPressed: onEdit,
                              tooltip: 'Editar movimiento',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            if (mode == NidoUsageMode.couple) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(
                                  Icons.favorite_border_rounded,
                                  size: 16,
                                  color: kAccentColor,
                                ),
                                onPressed: () => _showReactionPicker(context),
                                tooltip: 'Reaccionar',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ],
                        ),

                        if (expense.reactions.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: expense.reactions.entries
                                .map(
                                  (e) => Container(
                                    margin: const EdgeInsets.only(right: 6),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: kPrimaryColor.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${e.key}: ${e.value}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: kPrimaryColor,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
