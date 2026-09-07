import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import 'color_picker.dart';

// ==========================================
// CÁLCULO DE MÉTRICAS DEL BOLSILLO
// ==========================================
class PocketMetrics {
  final double available;
  final double spent;
  final double totalIncome;
  final double? progress; // 0.0 a 1.0 si hay meta

  const PocketMetrics({
    required this.available,
    required this.spent,
    required this.totalIncome,
    this.progress,
  });
}

PocketMetrics calculatePocketMetrics({
  required Pocket pocket,
  required List<Expense> expenses,
}) {
  double income = 0.0;
  double spent = 0.0;

  for (final e in expenses) {
    if (e.pocketId == pocket.id) {
      if (e.isIncome) {
        income += e.amount;
      } else {
        spent += e.amount;
      }
    }
  }

  final available = pocket.initialAmount + income - spent;
  final progress = pocket.targetAmount > 0
      ? (available / pocket.targetAmount).clamp(0.0, 1.0)
      : null;

  return PocketMetrics(
    available: available,
    spent: spent,
    totalIncome: income,
    progress: progress,
  );
}

// ==========================================
// PINTOR DE COSTURAS ESTILO BOLSILLO REAL
// ==========================================
class PocketStitchPainter extends CustomPainter {
  final Color stitchColor;
  final double borderRadius;

  PocketStitchPainter({
    required this.stitchColor,
    this.borderRadius = 22.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = stitchColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const inset = 5.0;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - (inset * 2),
      size.height - (inset * 2),
    );

    final rrect = RRect.fromRectAndCorners(
      rect,
      topLeft: const Radius.circular(8),
      topRight: const Radius.circular(8),
      bottomLeft: Radius.circular(borderRadius - inset),
      bottomRight: Radius.circular(borderRadius - inset),
    );

    final path = Path()..addRRect(rrect);
    _drawDashedPath(canvas, path, paint, dashLength: 4.0, spaceLength: 3.5);
  }

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint, {
    required double dashLength,
    required double spaceLength,
  }) {
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0.0;
      bool draw = true;
      while (distance < metric.length) {
        final length = draw ? dashLength : spaceLength;
        if (draw) {
          final extractPath = metric.extractPath(
            distance,
            (distance + length).clamp(0.0, metric.length),
          );
          canvas.drawPath(extractPath, paint);
        }
        distance += length;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(covariant PocketStitchPainter oldDelegate) =>
      oldDelegate.stitchColor != stitchColor ||
      oldDelegate.borderRadius != borderRadius;
}

// ==========================================
// TARJETA DE BOLSILLO (CARRUSEL & LISTA)
// ==========================================
class PocketCard extends StatelessWidget {
  final Pocket pocket;
  final PocketMetrics metrics;
  final VoidCallback onTap;
  final double width;

  const PocketCard({
    super.key,
    required this.pocket,
    required this.metrics,
    required this.onTap,
    this.width = 175.0,
  });

  @override
  Widget build(BuildContext context) {
    final primaryPocketColor = Color(pocket.colorHex);
    final surface = context.nidoSurface;
    final textDark = context.nidoTextDark;
    final textMuted = context.nidoTextMuted;
    final border = context.nidoBorder;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: width,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
            bottomLeft: Radius.circular(26),
            bottomRight: Radius.circular(26),
          ),
          border: Border.all(
            color: primaryPocketColor.withValues(alpha: 0.35),
            width: 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: primaryPocketColor.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: CustomPaint(
          painter: PocketStitchPainter(
            stitchColor: primaryPocketColor.withValues(alpha: 0.35),
            borderRadius: 26.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Solapa superior del bolsillo con color y etiqueta
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryPocketColor.withValues(alpha: 0.22),
                      primaryPocketColor.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: primaryPocketColor.withValues(alpha: 0.25),
                      width: 1.0,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Badge circular de emoji
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: primaryPocketColor.withValues(alpha: 0.4),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primaryPocketColor.withValues(alpha: 0.15),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        pocket.emoji,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pocket.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: primaryPocketColor,
                    ),
                  ],
                ),
              ),

              // Cuerpo del bolsillo con Disponible y Gastado
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Disponible',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: textMuted,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: primaryPocketColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        formatCurrency(metrics.available),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: metrics.available < 0 ? kDangerColor : textDark,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Gastado
                    Row(
                      children: [
                        Icon(
                          Icons.arrow_downward_rounded,
                          size: 12,
                          color: kExpenseColor.withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Gastado: ',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: textMuted,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            formatCurrency(metrics.spent),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    // Barra de meta si aplica
                    if (pocket.targetAmount > 0) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: metrics.progress ?? 0.0,
                          backgroundColor: border,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            primaryPocketColor,
                          ),
                          minHeight: 4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Meta: ${formatCurrency(pocket.targetAmount)}',
                              style: TextStyle(
                                fontSize: 9.5,
                                color: textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${((metrics.progress ?? 0.0) * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: primaryPocketColor,
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.all_inclusive_rounded,
                            size: 12,
                            color: textMuted.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Gasto libre · Sin meta',
                            style: TextStyle(
                              fontSize: 9.5,
                              color: textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// TARJETA DE "CREAR NUEVO BOLSILLO"
// ==========================================
class NewPocketDashedCard extends StatelessWidget {
  final VoidCallback onTap;
  final double width;

  const NewPocketDashedCard({
    super.key,
    required this.onTap,
    this.width = 145.0,
  });

  @override
  Widget build(BuildContext context) {
    final border = context.nidoBorder;
    final textMuted = context.nidoTextMuted;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: context.nidoBg,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
            bottomLeft: Radius.circular(26),
            bottomRight: Radius.circular(26),
          ),
        ),
        child: CustomPaint(
          painter: PocketStitchPainter(
            stitchColor: border,
            borderRadius: 26.0,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: kPrimaryColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: kPrimaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Crear Bolsillo',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// DIÁLOGO / MODAL DE FORMULARIO DE BOLSILLO
// ==========================================
class PocketFormDialog extends StatefulWidget {
  final Pocket? pocketToEdit;
  final Function(Pocket pocket, double initialDeposit) onSave;

  const PocketFormDialog({
    super.key,
    this.pocketToEdit,
    required this.onSave,
  });

  @override
  State<PocketFormDialog> createState() => _PocketFormDialogState();
}

class _PocketFormDialogState extends State<PocketFormDialog> {
  late TextEditingController _nameController;
  late TextEditingController _emojiController;
  late TextEditingController _targetController;
  late TextEditingController _initialAmountController;
  late Color _currentColor;

  static const List<String> _presetEmojis = [
    '👛', '🛒', '🍽️', '🏖️', '💡', '🚗', '🏠', '🎁',
    '🎬', '📚', '🐾', '💊', '✈️', '💻', '👗', '💰',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.pocketToEdit;
    _nameController = TextEditingController(text: p?.name ?? '');
    _emojiController = TextEditingController(text: p?.emoji ?? '👛');
    _targetController = TextEditingController(
      text: p != null && p.targetAmount > 0
          ? p.targetAmount.toInt().toString()
          : '',
    );
    _initialAmountController = TextEditingController();

    _currentColor = p != null ? Color(p.colorHex) : const Color(0xFF0D9488);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emojiController.dispose();
    _targetController.dispose();
    _initialAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentColor = _currentColor;
    final surface = context.nidoSurface;
    final bg = context.nidoBg;
    final border = context.nidoBorder;
    final textDark = context.nidoTextDark;
    final textMuted = context.nidoTextMuted;
    final isEditing = widget.pocketToEdit != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      backgroundColor: surface,
      title: Text(
        isEditing ? 'Modificar Bolsillo' : 'Nuevo Bolsillo 👛',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color: textDark,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vista previa del bolsillo
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: currentColor.withValues(alpha: 0.12),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  border: Border.all(
                    color: currentColor.withValues(alpha: 0.4),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: currentColor.withValues(alpha: 0.5),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _emojiController.text.trim().isEmpty
                            ? '👛'
                            : _emojiController.text.trim(),
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _nameController.text.trim().isEmpty
                                ? 'Nombre del Bolsillo'
                                : _nameController.text.trim(),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: textDark,
                            ),
                          ),
                          Text(
                            'Color: #${currentColor.toARGB32().toRadixString(16).toUpperCase().padLeft(8, '0')}',
                            style: TextStyle(fontSize: 11, color: textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(color: textDark),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Nombre (ej: Mercado, Salidas, Viaje)',
                  labelStyle: TextStyle(color: textMuted),
                  prefixIcon: Icon(Icons.wallet_rounded, size: 20, color: textMuted),
                ),
              ),
              const SizedBox(height: 12),

              // Selección de Emoji
              Row(
                children: [
                  SizedBox(
                    width: 70,
                    child: TextField(
                      controller: _emojiController,
                      style: TextStyle(color: textDark, fontSize: 18),
                      textAlign: TextAlign.center,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Icono',
                        labelStyle: TextStyle(color: textMuted, fontSize: 11),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _presetEmojis.length,
                        itemBuilder: (context, index) {
                          final em = _presetEmojis[index];
                          return GestureDetector(
                            onTap: () {
                              setState(() => _emojiController.text = em);
                              HapticFeedback.selectionClick();
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: _emojiController.text == em
                                    ? currentColor.withValues(alpha: 0.2)
                                    : bg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _emojiController.text == em
                                      ? currentColor
                                      : border,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(em, style: const TextStyle(fontSize: 18)),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Meta o Presupuesto objetivo (opcional)
              TextField(
                controller: _targetController,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsSeparatorInputFormatter()],
                style: TextStyle(color: textDark),
                decoration: InputDecoration(
                  labelText: 'Meta o límite \$ (opcional)',
                  labelStyle: TextStyle(color: textMuted),
                  prefixIcon: Icon(Icons.flag_outlined, size: 20, color: textMuted),
                ),
              ),

              if (!isEditing) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _initialAmountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandsSeparatorInputFormatter()],
                  style: TextStyle(color: textDark),
                  decoration: InputDecoration(
                    labelText: 'Asignar de la cuenta principal \$ (opcional)',
                    helperText: 'Se apartará de tu saldo general para este bolsillo',
                    labelStyle: TextStyle(color: textMuted),
                    prefixIcon: Icon(Icons.savings_outlined, size: 20, color: textMuted),
                  ),
                ),
              ],

              const SizedBox(height: 16),
              Text(
                'Color del bolsillo:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
              const SizedBox(height: 10),
              NidoColorPicker(
                initialColor: _currentColor,
                onColorChanged: (newColor) {
                  setState(() => _currentColor = newColor);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar', style: TextStyle(color: textMuted)),
        ),
        ElevatedButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) return;

            final emoji = _emojiController.text.trim().isEmpty
                ? '👛'
                : _emojiController.text.trim();
            final targetAmount = parseFormattedAmount(_targetController.text);
            final initialDeposit = parseFormattedAmount(_initialAmountController.text);
            final colorHex = currentColor.toARGB32();

            final updated = Pocket(
              id: widget.pocketToEdit?.id ??
                  DateTime.now().millisecondsSinceEpoch.toString(),
              name: name,
              emoji: emoji,
              colorHex: colorHex,
              targetAmount: targetAmount,
              initialAmount: widget.pocketToEdit?.initialAmount ?? 0.0,
              createdBy: widget.pocketToEdit?.createdBy ?? '',
              createdAt: widget.pocketToEdit?.createdAt ?? DateTime.now(),
            );

            widget.onSave(updated, initialDeposit);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimaryColor,
            foregroundColor: Colors.white,
          ),
          child: Text(isEditing ? 'Guardar Cambios' : 'Crear Bolsillo'),
        ),
      ],
    );
  }
}
