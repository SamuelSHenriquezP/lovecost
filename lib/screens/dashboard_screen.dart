import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import 'add_expense_bottom_sheet.dart';

// ==========================================
// PANTALLA 1: DASHBOARD DE MOVIMIENTOS
// ==========================================
class DashboardScreen extends StatefulWidget {
  final String coupleId;
  final String userId;
  final String userName;
  final NidoUsageMode mode;
  final VoidCallback onOpenMenu;

  const DashboardScreen({
    super.key,
    required this.coupleId,
    required this.userId,
    required this.userName,
    required this.mode,
    required this.onOpenMenu,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _filterType = 'all'; // 'all', 'expense', 'income'
  String _selectedCategoryFilter = 'all';
  bool _disponibleExpanded = true;
  bool _movimientosExpanded = true;

  // ESTADO MODO INVITADO
  List<Expense> _guestExpenses = [];
  double _guestBudget = 2000.0;
  List<CustomCategory> _guestCategories = [];

  @override
  void initState() {
    super.initState();
    if (widget.mode == NidoUsageMode.guest) {
      _loadGuestData();
    }
  }

  Future<void> _loadGuestData() async {
    final rawExpenses = await LocalGuestStorage.getExpenses();
    final budget = await LocalGuestStorage.getBudget();
    final rawCats = await LocalGuestStorage.getCategories();
    final cycleStart = await LocalGuestStorage.getCycleStartDate();

    if (mounted) {
      setState(() {
        final parsed = rawExpenses.map((e) => Expense.fromJson(e)).toList();
        _guestExpenses = parsed
            .where((e) => !e.date.isBefore(cycleStart))
            .toList();
        _guestExpenses.sort((a, b) => b.date.compareTo(a.date));
        _guestBudget = budget;
        _guestCategories = rawCats
            .map((c) => CustomCategory.fromJson(c))
            .toList();
      });
    }
  }

  void _openAddExpenseSheet({
    Expense? expenseToEdit,
    List<CustomCategory>? customCategories,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddExpenseBottomSheet(
        coupleId: widget.coupleId,
        userName: widget.userName,
        mode: widget.mode,
        expenseToEdit: expenseToEdit,
        onGuestRefresh: _loadGuestData,
        customCategories: customCategories ?? _guestCategories,
      ),
    );
  }

  Stream<List<Expense>> _streamExpenses(DateTime cycleStartDate) {
    return FirebaseFirestore.instance
        .collection('couples')
        .doc(widget.coupleId)
        .collection('expenses')
        .where(
          'date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(cycleStartDate),
        )
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs
              .map((doc) => Expense.fromFirestore(doc))
              .toList();
          items.sort((a, b) => b.date.compareTo(a.date));
          return items;
        });
  }

  Stream<List<CustomCategory>> _streamCustomCategories() {
    return FirebaseFirestore.instance
        .collection('couples')
        .doc(widget.coupleId)
        .collection('categories')
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => CustomCategory.fromFirestore(d)).toList(),
        );
  }

  void _showEditBudgetDialog(BuildContext context, double currentBudget) {
    final controller = TextEditingController(
      text: currentBudget.toInt().toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: context.nidoSurface,
        title: Text(
          'Editar límite mensual',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: context.nidoTextDark,
          ),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [ThousandsSeparatorInputFormatter()],
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Límite \$',
            prefixIcon: Icon(
              Icons.account_balance_wallet_outlined,
              size: 20,
              color: kTextMuted,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: kTextMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = parseFormattedAmount(controller.text);
              if (val > 0) {
                if (widget.mode == NidoUsageMode.guest) {
                  await LocalGuestStorage.setBudget(val);
                  _loadGuestData();
                } else {
                  await FirebaseFirestore.instance
                      .collection('couples')
                      .doc(widget.coupleId)
                      .update({'budget_limit': val});
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
              controller.dispose();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mode == NidoUsageMode.guest) {
      return _buildDashboardBody(
        budgetLimit: _guestBudget,
        inviteCode: '',
        members: [widget.userId],
        allTransactions: _guestExpenses,
        customCats: _guestCategories,
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('couples')
          .doc(widget.coupleId)
          .snapshots(),
      builder: (context, coupleSnapshot) {
        if (coupleSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: kPrimaryColor),
            ),
          );
        }

        final coupleData = coupleSnapshot.data?.data() as Map<String, dynamic>?;
        final double budgetLimit =
            ((coupleData?['budget_limit'] as num?) ?? 2000.0).toDouble();
        final String inviteCode = (coupleData?['invite_code'] as String?) ?? '';
        final members = List<String>.from(
          coupleData?['members'] as List? ?? [],
        );

        final cycleStartTimestamp =
            coupleData?['cycle_start_date'] as Timestamp?;
        final cycleStartDate =
            cycleStartTimestamp?.toDate() ??
            DateTime(DateTime.now().year, DateTime.now().month, 1);

        return StreamBuilder<List<Expense>>(
          stream: _streamExpenses(cycleStartDate),
          builder: (context, expensesSnapshot) {
            final allTransactions = expensesSnapshot.data ?? [];

            return StreamBuilder<List<CustomCategory>>(
              stream: _streamCustomCategories(),
              builder: (context, customCatSnap) {
                final customCats = customCatSnap.data ?? [];
                return _buildDashboardBody(
                  budgetLimit: budgetLimit,
                  inviteCode: inviteCode,
                  members: members,
                  allTransactions: allTransactions,
                  customCats: customCats,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildDashboardBody({
    required double budgetLimit,
    required String inviteCode,
    required List<String> members,
    required List<Expense> allTransactions,
    required List<CustomCategory> customCats,
  }) {
    final surface = context.nidoSurface;
    final border = context.nidoBorder;
    final bg = context.nidoBg;
    final textDark = context.nidoTextDark;
    final textMuted = context.nidoTextMuted;
    double totalIngresos = 0;
    double totalGastos = 0;

    for (var t in allTransactions) {
      if (t.isIncome) {
        totalIngresos += t.amount;
      } else {
        totalGastos += t.amount;
      }
    }

    final disponibleReal =
        (totalIngresos > 0 ? totalIngresos : budgetLimit) - totalGastos;
    final porcentajeGastado = totalIngresos > 0
        ? (totalGastos / totalIngresos).clamp(0.0, 1.0)
        : (totalGastos / budgetLimit).clamp(0.0, 1.0);

    final filtered = allTransactions.where((t) {
      if (_filterType == 'income' && !t.isIncome) return false;
      if (_filterType == 'expense' && t.isIncome) return false;
      if (_selectedCategoryFilter != 'all' &&
          t.category != _selectedCategoryFilter) {
        return false;
      }
      return true;
    }).toList();

    final waitingForPartner =
        widget.mode == NidoUsageMode.couple && members.length < 2;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/nido_icon.png',
                height: 28,
                width: 28,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.favorite, color: kPrimaryColor, size: 24),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Nido · ${DateFormat('MMMM', 'es').format(DateTime.now()).capitalize()}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.settings_outlined,
              size: 22,
              color: textDark,
            ),
            onPressed: widget.onOpenMenu,
            tooltip: 'Menú de opciones',
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: PartnerHeaderCard(
                coupleId: widget.coupleId,
                userId: widget.userId,
                userName: widget.userName,
                inviteCode: inviteCode,
                mode: widget.mode,
              ),
            ),
          ),
          if (waitingForPartner && inviteCode.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: InviteCodeCard(inviteCode: inviteCode),
              ),
            ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  18,
                  16,
                  18,
                  _disponibleExpanded ? 18 : 14,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF334155), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: kDisponibleColor.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(
                          () => _disponibleExpanded = !_disponibleExpanded,
                        );
                        HapticFeedback.selectionClick();
                      },
                      child: Row(
                        children: [
                          const Icon(
                            Icons.account_balance_wallet,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Disponible Real',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () =>
                                _showEditBudgetDialog(context, budgetLimit),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Meta: ${formatCurrency(budgetLimit)}',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  const Icon(
                                    Icons.edit_outlined,
                                    size: 10,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (!_disponibleExpanded)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: SmoothCurrencyText(
                                value: disponibleReal,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          Icon(
                            _disponibleExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                    AnimatedCrossFade(
                      firstCurve: Curves.easeOutCubic,
                      secondCurve: Curves.easeOutCubic,
                      sizeCurve: Curves.easeOutCubic,
                      crossFadeState: _disponibleExpanded
                          ? CrossFadeState.showFirst
                          : CrossFadeState.showSecond,
                      duration: const Duration(milliseconds: 220),
                      firstChild: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: SmoothCurrencyText(
                              value: disponibleReal,
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: disponibleReal < 0
                                    ? const Color(0xFFFF8A80)
                                    : Colors.white,
                                letterSpacing: -1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TweenAnimationBuilder<double>(
                            key: ValueKey(porcentajeGastado),
                            tween: Tween(begin: 0.0, end: porcentajeGastado),
                            duration: const Duration(milliseconds: 1000),
                            curve: Curves.easeOutCubic,
                            builder: (context, val, child) => ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: val,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.25,
                                ),
                                color: porcentajeGastado >= 0.9
                                    ? const Color(0xFFFF5252)
                                    : porcentajeGastado > 0.75
                                    ? Colors.amber.shade300
                                    : const Color(0xFF6EE7B7),
                                minHeight: 8,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white.withValues(
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
                                            Icons.arrow_upward_rounded,
                                            size: 16,
                                            color: Color(0xFF6EE7B7),
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Ingresos (+)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        formatCurrency(totalIngresos),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white.withValues(
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
                                            size: 16,
                                            color: Color(0xFFFCA5A5),
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Gastos (-)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        formatCurrency(totalGastos),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      secondChild: const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          setState(
                            () => _movimientosExpanded = !_movimientosExpanded,
                          );
                          HapticFeedback.selectionClick();
                        },
                        child: Row(
                          children: [
                            Text(
                              'Movimientos${filtered.isNotEmpty ? ' (${filtered.length})' : ''}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: textDark,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _movimientosExpanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              color: textMuted,
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () =>
                            _openAddExpenseSheet(customCategories: customCats),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text(
                          'Añadir',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (_movimientosExpanded) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: border, width: 1.0),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              _buildInlineTypeOption(
                                'Todos',
                                'all',
                                Icons.format_list_bulleted_rounded,
                                kTextMuted,
                              ),
                              const SizedBox(width: 6),
                              _buildInlineTypeOption(
                                'Gastos',
                                'expense',
                                Icons.remove_circle_outline,
                                kExpenseColor,
                              ),
                              const SizedBox(width: 6),
                              _buildInlineTypeOption(
                                'Ingresos',
                                'income',
                                Icons.add_circle_outline,
                                kIncomeColor,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => _openCategoryFilterSheet(customCats),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: _selectedCategoryFilter != 'all'
                                    ? kPrimaryColor.withValues(alpha: 0.10)
                                    : bg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _selectedCategoryFilter != 'all'
                                      ? kPrimaryColor
                                      : border,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.category_outlined,
                                    size: 16,
                                    color: _selectedCategoryFilter != 'all'
                                        ? kPrimaryColor
                                        : textMuted,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _selectedCategoryFilter == 'all'
                                          ? 'Filtrar por Categoría: (Todas)'
                                          : 'Categoría: $_selectedCategoryFilter',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        color: _selectedCategoryFilter != 'all'
                                            ? kPrimaryColor
                                            : textDark,
                                      ),
                                    ),
                                  ),
                                  if (_selectedCategoryFilter != 'all')
                                    GestureDetector(
                                      onTap: () {
                                        setState(
                                          () => _selectedCategoryFilter = 'all',
                                        );
                                        HapticFeedback.selectionClick();
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        child: Icon(
                                          Icons.close_rounded,
                                          size: 16,
                                          color: kDangerColor,
                                        ),
                                      ),
                                    )
                                  else
                                    const Icon(
                                      Icons.arrow_drop_down_rounded,
                                      color: kTextMuted,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          if (_movimientosExpanded)
            filtered.isEmpty
                ? const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'Sin movimientos registrados',
                        subtitle:
                            'Usa "Añadir" para registrar un ingreso o un gasto.',
                      ),
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final ex = filtered[index];
                        return AnimatedListItem(
                          index: index,
                          child: ExpenseCard(
                            expense: ex,
                            coupleId: widget.coupleId,
                            currentUserName: widget.userName,
                            mode: widget.mode,
                            onEdit: () => _openAddExpenseSheet(
                              expenseToEdit: ex,
                              customCategories: customCats,
                            ),
                            onGuestRefresh: _loadGuestData,
                            customCategories: customCats,
                          ),
                        );
                      }, childCount: filtered.length),
                    ),
                  )
          else
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildInlineTypeOption(
    String label,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    final isSelected = _filterType == value;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          setState(() {
            _filterType = value;
            _selectedCategoryFilter = 'all';
          });
          HapticFeedback.selectionClick();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? kPrimaryColor.withValues(alpha: 0.10)
                : kBackgroundColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? kPrimaryColor : kBorderColor,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: iconColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? kPrimaryColor : kTextDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openCategoryFilterSheet(List<CustomCategory> customCats) {
    final defaultExpenseCats = defaultExpenseCategories
        .map((c) => c['name'] as String)
        .toList();
    final defaultIncomeCats = defaultIncomeCategories
        .map((c) => c['name'] as String)
        .toList();

    final customExpenseCats = customCats
        .where((c) => c.type == 'expense')
        .map((c) => c.name)
        .toList();
    final customIncomeCats = customCats
        .where((c) => c.type == 'income')
        .map((c) => c.name)
        .toList();

    final allExpenses = [...defaultExpenseCats, ...customExpenseCats];
    final allIncomes = [...defaultIncomeCats, ...customIncomeCats];

    showModalBottomSheet(
      context: context,
      backgroundColor: kSurfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setFilterState) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.category_outlined,
                      color: kPrimaryColor,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Filtrar por Categoría',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: kTextDark,
                      ),
                    ),
                    const Spacer(),
                    if (_selectedCategoryFilter != 'all')
                      TextButton(
                        onPressed: () {
                          setState(() => _selectedCategoryFilter = 'all');
                          setFilterState(() {});
                          HapticFeedback.selectionClick();
                        },
                        child: const Text(
                          'Ver todas',
                          style: TextStyle(
                            color: kDangerColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ChoiceChip(
                          label: const Text('✨ Todas las categorías'),
                          selected: _selectedCategoryFilter == 'all',
                          selectedColor: kPrimaryColor.withValues(alpha: 0.15),
                          backgroundColor: kBackgroundColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          side: BorderSide(
                            color: _selectedCategoryFilter == 'all'
                                ? kPrimaryColor
                                : kBorderColor,
                            width: _selectedCategoryFilter == 'all' ? 1.5 : 1.0,
                          ),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: _selectedCategoryFilter == 'all'
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: _selectedCategoryFilter == 'all'
                                ? kPrimaryColor
                                : kTextDark,
                          ),
                          onSelected: (_) {
                            setState(() => _selectedCategoryFilter = 'all');
                            setFilterState(() {});
                            HapticFeedback.selectionClick();
                          },
                        ),
                        const SizedBox(height: 14),

                        if (_filterType == 'all' ||
                            _filterType == 'expense') ...[
                          const Row(
                            children: [
                              Icon(
                                Icons.remove_circle_outline,
                                size: 14,
                                color: kExpenseColor,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Categorías de Gastos',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: kExpenseColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: allExpenses.map((cat) {
                              final isSel = _selectedCategoryFilter == cat;
                              return ChoiceChip(
                                label: Text(cat),
                                selected: isSel,
                                selectedColor: kExpenseColor.withValues(
                                  alpha: 0.15,
                                ),
                                backgroundColor: kBackgroundColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                side: BorderSide(
                                  color: isSel ? kExpenseColor : kBorderColor,
                                  width: isSel ? 1.5 : 1.0,
                                ),
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSel
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSel ? kExpenseColor : kTextDark,
                                ),
                                onSelected: (_) {
                                  setState(() => _selectedCategoryFilter = cat);
                                  setFilterState(() {});
                                  HapticFeedback.selectionClick();
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                        ],

                        if (_filterType == 'all' ||
                            _filterType == 'income') ...[
                          const Row(
                            children: [
                              Icon(
                                Icons.add_circle_outline,
                                size: 14,
                                color: kIncomeColor,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Categorías de Ingresos',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: kIncomeColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: allIncomes.map((cat) {
                              final isSel = _selectedCategoryFilter == cat;
                              return ChoiceChip(
                                label: Text(cat),
                                selected: isSel,
                                selectedColor: kIncomeColor.withValues(
                                  alpha: 0.15,
                                ),
                                backgroundColor: kBackgroundColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                side: BorderSide(
                                  color: isSel ? kIncomeColor : kBorderColor,
                                  width: isSel ? 1.5 : 1.0,
                                ),
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSel
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSel ? kIncomeColor : kTextDark,
                                ),
                                onSelected: (_) {
                                  setState(() => _selectedCategoryFilter = cat);
                                  setFilterState(() {});
                                  HapticFeedback.selectionClick();
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Aplicar Filtro',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
