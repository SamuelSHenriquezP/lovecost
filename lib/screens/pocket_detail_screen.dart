import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import 'add_expense_bottom_sheet.dart';
import '../widgets/pocket_widgets.dart';

// ==========================================
// PANTALLA: DETALLE DE UN BOLSILLO
// ==========================================
class PocketDetailScreen extends StatefulWidget {
  final Pocket initialPocket;
  final String coupleId;
  final String userName;
  final NidoUsageMode mode;
  final VoidCallback? onRefresh;

  const PocketDetailScreen({
    super.key,
    required this.initialPocket,
    required this.coupleId,
    required this.userName,
    required this.mode,
    this.onRefresh,
  });

  @override
  State<PocketDetailScreen> createState() => _PocketDetailScreenState();
}

class _PocketDetailScreenState extends State<PocketDetailScreen> {
  late Pocket _pocket;

  // Streams en caché para evitar lecturas y refrescos innecesarios en Firebase
  Stream<List<Pocket>>? _pocketsStream;
  Stream<List<Expense>>? _expensesStream;
  Stream<List<CustomCategory>>? _categoriesStream;

  // Para modo invitado
  List<Expense> _guestExpenses = [];
  List<CustomCategory> _guestCategories = [];

  @override
  void initState() {
    super.initState();
    _pocket = widget.initialPocket;
    if (widget.mode == NidoUsageMode.guest) {
      _loadGuestData();
    } else {
      _initStreams();
    }
  }

  void _initStreams() async {
    final cycleStart = await NidoRepository.instance.getCycleStartDate(
      coupleId: widget.coupleId,
      mode: widget.mode,
    );
    if (!mounted) return;
    setState(() {
      _pocketsStream = NidoRepository.instance.streamPockets(
        coupleId: widget.coupleId,
        mode: widget.mode,
      );
      _expensesStream = NidoRepository.instance.streamExpenses(
        coupleId: widget.coupleId,
        mode: widget.mode,
        cycleStartDate: cycleStart,
      );
      _categoriesStream = NidoRepository.instance.streamCategories(
        coupleId: widget.coupleId,
        mode: widget.mode,
      );
    });
  }

  Future<void> _loadGuestData() async {
    final rawExpenses = await LocalGuestStorage.getExpenses();
    final rawCats = await LocalGuestStorage.getCategories();
    final rawPockets = await LocalGuestStorage.getPockets();
    final cycleStart = await LocalGuestStorage.getCycleStartDate();

    if (mounted) {
      setState(() {
        final parsed = rawExpenses.map((e) => Expense.fromJson(e)).toList();
        _guestExpenses = parsed.where((e) => !e.date.isBefore(cycleStart)).toList();
        _guestExpenses.sort((a, b) => b.date.compareTo(a.date));
        _guestCategories =
            rawCats.map((c) => CustomCategory.fromJson(c)).toList();

        // Actualizar datos del bolsillo si cambió
        final pData = rawPockets.firstWhere(
          (p) => p['id'] == _pocket.id,
          orElse: () => _pocket.toJson(),
        );
        _pocket = Pocket.fromJson(pData);
      });
    }
  }

  void _openAddExpenseSheet({
    required String type,
    Expense? expenseToEdit,
    List<CustomCategory>? customCategories,
    List<Pocket>? allPockets,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddExpenseBottomSheet(
        coupleId: widget.coupleId,
        userName: widget.userName,
        mode: widget.mode,
        initialType: type,
        preselectedPocketId: _pocket.id,
        preselectedPocketName: _pocket.name,
        availablePockets: allPockets ?? [_pocket],
        expenseToEdit: expenseToEdit,
        onGuestRefresh: () {
          _loadGuestData();
          if (widget.onRefresh != null) widget.onRefresh!();
        },
        customCategories: customCategories ?? _guestCategories,
      ),
    );
  }

  void _showAddFundsDialog(Pocket pocket) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.nidoSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Text(pocket.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Cargar a "${pocket.name}"',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: context.nidoTextDark,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transfiere fondos de tu cuenta principal a este bolsillo. Se apartará de tu saldo general para este objetivo.',
              style: TextStyle(fontSize: 12.5, color: context.nidoTextMuted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsSeparatorInputFormatter()],
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.nidoTextDark,
              ),
              decoration: InputDecoration(
                labelText: 'Monto a transferir \$',
                labelStyle: TextStyle(color: context.nidoTextMuted),
                prefixIcon: const Icon(Icons.savings_outlined, color: kIncomeColor),
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
              final amount = parseFormattedAmount(controller.text);
              if (amount <= 0) return;
              Navigator.pop(ctx);
              final newAllocated = pocket.initialAmount + amount;
              final updated = pocket.copyWith(initialAmount: newAllocated);
              setState(() => _pocket = updated);
              await NidoRepository.instance.updatePocket(
                coupleId: widget.coupleId,
                mode: widget.mode,
                pocket: updated,
              );
              if (widget.mode == NidoUsageMode.guest) _loadGuestData();
              if (widget.onRefresh != null) widget.onRefresh!();
              if (mounted) {
                HapticFeedback.mediumImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✨ Se asignaron ${formatCurrency(amount)} a "${pocket.name}" desde tu cuenta principal'),
                    backgroundColor: kIncomeColor,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kIncomeColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Transferir al Bolsillo'),
          ),
        ],
      ),
    );
  }

  void _showWithdrawFundsDialog(Pocket pocket, double available) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.nidoSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Text(pocket.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Retirar a Principal',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: context.nidoTextDark,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Devuelve dinero disponible de este bolsillo a tu cuenta principal general.',
              style: TextStyle(fontSize: 12.5, color: context.nidoTextMuted),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: context.nidoBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.nidoBorder),
              ),
              child: Row(
                children: [
                  Text('Disponible en bolsillo:', style: TextStyle(fontSize: 12, color: context.nidoTextMuted)),
                  const Spacer(),
                  Text(formatCurrency(available), style: TextStyle(fontWeight: FontWeight.bold, color: context.nidoTextDark, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsSeparatorInputFormatter()],
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.nidoTextDark,
              ),
              decoration: InputDecoration(
                labelText: 'Monto a devolver \$',
                labelStyle: TextStyle(color: context.nidoTextMuted),
                prefixIcon: const Icon(Icons.arrow_outward_rounded, color: kSecondaryColor),
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
              final amount = parseFormattedAmount(controller.text);
              if (amount <= 0) return;
              if (amount > available && available > 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('El monto supera el disponible del bolsillo'),
                    backgroundColor: kDangerColor,
                  ),
                );
                return;
              }
              Navigator.pop(ctx);
              final newAllocated = (pocket.initialAmount - amount).clamp(0.0, double.infinity);
              final updated = pocket.copyWith(initialAmount: newAllocated);
              setState(() => _pocket = updated);
              await NidoRepository.instance.updatePocket(
                coupleId: widget.coupleId,
                mode: widget.mode,
                pocket: updated,
              );
              if (widget.mode == NidoUsageMode.guest) _loadGuestData();
              if (widget.onRefresh != null) widget.onRefresh!();
              if (mounted) {
                HapticFeedback.mediumImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✨ Se devolvieron ${formatCurrency(amount)} a tu cuenta principal'),
                    backgroundColor: kSecondaryColor,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kSecondaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Devolver Dinero'),
          ),
        ],
      ),
    );
  }

  void _editPocket() {
    showDialog(
      context: context,
      builder: (ctx) => PocketFormDialog(
        pocketToEdit: _pocket,
        onSave: (updated, _) async {
          setState(() => _pocket = updated);
          await NidoRepository.instance.updatePocket(
            coupleId: widget.coupleId,
            mode: widget.mode,
            pocket: updated,
          );
          if (widget.mode == NidoUsageMode.guest) {
            _loadGuestData();
          }
          if (widget.onRefresh != null) widget.onRefresh!();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✨ Bolsillo actualizado'),
                backgroundColor: kSecondaryColor,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _deletePocket() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.nidoSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '¿Eliminar "${_pocket.name}"?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: context.nidoTextDark,
          ),
        ),
        content: Text(
          'Los movimientos asociados no se borrarán de tu historial general, pero dejarán de pertenecer a este bolsillo.',
          style: TextStyle(color: context.nidoTextMuted, fontSize: 13.5),
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
            child: const Text('Eliminar Bolsillo'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await NidoRepository.instance.deletePocket(
      coupleId: widget.coupleId,
      mode: widget.mode,
      pocketId: _pocket.id,
    );

    if (widget.onRefresh != null) widget.onRefresh!();

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bolsillo "${_pocket.name}" eliminado'),
          backgroundColor: kDangerColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mode == NidoUsageMode.guest) {
      return _buildContent(
        allExpenses: _guestExpenses,
        customCats: _guestCategories,
        allPockets: [_pocket],
      );
    }

    return StreamBuilder<List<Pocket>>(
      stream: _pocketsStream,
      builder: (context, pocketSnap) {
        final pockets = pocketSnap.data ?? [_pocket];
        final current = pockets.firstWhere(
          (p) => p.id == _pocket.id,
          orElse: () => _pocket,
        );

        return StreamBuilder<List<Expense>>(
          stream: _expensesStream,
          builder: (context, expenseSnap) {
            final expenses = expenseSnap.data ?? [];

            return StreamBuilder<List<CustomCategory>>(
              stream: _categoriesStream,
              builder: (context, catSnap) {
                final cats = catSnap.data ?? [];
                return _buildContent(
                  pocketOverride: current,
                  allExpenses: expenses,
                  customCats: cats,
                  allPockets: pockets,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildContent({
    Pocket? pocketOverride,
    required List<Expense> allExpenses,
    required List<CustomCategory> customCats,
    required List<Pocket> allPockets,
  }) {
    final activePocket = pocketOverride ?? _pocket;
    final metrics = calculatePocketMetrics(
      pocket: activePocket,
      expenses: allExpenses,
    );

    final pocketExpenses = allExpenses
        .where((e) => e.pocketId == activePocket.id && !e.isIncome)
        .toList();

    final filteredExpenses = pocketExpenses;

    final primaryColor = Color(activePocket.colorHex);
    final surface = context.nidoSurface;
    final bg = context.nidoBg;
    final border = context.nidoBorder;
    final textDark = context.nidoTextDark;
    final textMuted = context.nidoTextMuted;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(activePocket.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              activePocket.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 22),
            onPressed: _editPocket,
            tooltip: 'Modificar bolsillo',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: kDangerColor, size: 22),
            onPressed: _deletePocket,
            tooltip: 'Eliminar bolsillo',
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // TARJETA PRINCIPAL ESTILO BOLSILLO GIGANTE
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.15),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: CustomPaint(
                  painter: PocketStitchPainter(
                    stitchColor: primaryColor.withValues(alpha: 0.4),
                    borderRadius: 32.0,
                  ),
                  child: Column(
                    children: [
                      // Cabecera del bolsillo
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              primaryColor.withValues(alpha: 0.25),
                              primaryColor.withValues(alpha: 0.08),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border(
                            bottom: BorderSide(
                              color: primaryColor.withValues(alpha: 0.25),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: surface,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: primaryColor.withValues(alpha: 0.5),
                                  width: 1.5,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                activePocket.emoji,
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    activePocket.name,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: textDark,
                                    ),
                                  ),
                                  Text(
                                    'Bolsillo Activo · Nido',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'En uso',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Cuerpo con Disponible y Métricas
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                        child: Column(
                          children: [
                            Text(
                              'Disponible en este bolsillo',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: textMuted,
                              ),
                            ),
                            const SizedBox(height: 6),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                formatCurrency(metrics.available),
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                  color: metrics.available < 0
                                      ? kDangerColor
                                      : textDark,
                                  letterSpacing: -1.0,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Métricas Ingresos y Gastos
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: kIncomeColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: primaryColor.withValues(
                                          alpha: 0.25,
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.account_balance_wallet_outlined,
                                              size: 14,
                                              color: primaryColor,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                'Total Asignado',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: primaryColor,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            formatCurrency(
                                              activePocket.initialAmount,
                                            ),
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: primaryColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: kExpenseColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: kExpenseColor.withValues(
                                          alpha: 0.2,
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Row(
                                          children: [
                                            Icon(
                                              Icons.arrow_downward_rounded,
                                              size: 14,
                                              color: kExpenseColor,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Total Gastado',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: kExpenseColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            formatCurrency(metrics.spent),
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: kExpenseColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // Meta del bolsillo si está fijada
                            if (activePocket.targetAmount > 0) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: bg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: border),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Meta: ${formatCurrency(activePocket.targetAmount)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: textDark,
                                          ),
                                        ),
                                        Text(
                                          '${((metrics.progress ?? 0.0) * 100).toInt()}% alcanzado',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: primaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: LinearProgressIndicator(
                                        value: metrics.progress ?? 0.0,
                                        backgroundColor: border,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          primaryColor,
                                        ),
                                        minHeight: 6,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ACCIONES RÁPIDAS (METER PLATA / GASTAR DE ESTE BOLSILLO)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showAddFundsDialog(activePocket),
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          label: const Text(
                            'Cargar Dinero',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _openAddExpenseSheet(
                            type: 'expense',
                            customCategories: customCats,
                            allPockets: allPockets,
                          ),
                          icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                          label: const Text(
                            'Gastar de Aquí',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kExpenseColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showWithdrawFundsDialog(
                        activePocket,
                        metrics.available,
                      ),
                      icon: const Icon(Icons.arrow_outward_rounded, size: 16),
                      label: const Text(
                        'Retirar dinero a la cuenta principal',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textMuted,
                        side: BorderSide(color: border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // SECCIÓN DE MOVIMIENTOS DENTRO DEL BOLSILLO
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Row(
                children: [
                  Text(
                    'Gastos del Bolsillo (${filteredExpenses.length})',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: textDark,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // LISTA DE MOVIMIENTOS
          if (filteredExpenses.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          activePocket.emoji,
                          style: const TextStyle(fontSize: 32),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Sin gastos registrados en este bolsillo',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Toca "Gastar de Aquí" para registrar un gasto realizado con este bolsillo.',
                        style: TextStyle(fontSize: 12, color: textMuted),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final exp = filteredExpenses[index];
                    return ExpenseCard(
                      expense: exp,
                      coupleId: widget.coupleId,
                      currentUserName: widget.userName,
                      mode: widget.mode,
                      onEdit: () => _openAddExpenseSheet(
                        type: exp.type,
                        expenseToEdit: exp,
                        customCategories: customCats,
                        allPockets: allPockets,
                      ),
                      onGuestRefresh: _loadGuestData,
                      customCategories: customCats,
                    );
                  },
                  childCount: filteredExpenses.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
