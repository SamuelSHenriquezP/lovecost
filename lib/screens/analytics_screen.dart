import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../widgets/stock_line_chart.dart';

// ==========================================
// PERIODOS DE ANÁLISIS FINANCIERO
// ==========================================
enum AnalyticsPeriod {
  last7Days,
  currentMonth,
  last30Days,
  last3Months,
  thisYear,
  custom,
}

// ==========================================
// PANTALLA 2: ANÁLISIS FINANCIERO
// ==========================================
class AnalyticsScreen extends StatefulWidget {
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
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  AnalyticsPeriod _selectedPeriod = AnalyticsPeriod.currentMonth;
  late DateTime _startDate;
  late DateTime _endDate;
  Stream<List<Expense>>? _expensesStream;
  List<Expense> _guestExpenses = [];

  @override
  void initState() {
    super.initState();
    _applyPeriodDates(_selectedPeriod);
    _initStream();
  }

  @override
  void didUpdateWidget(covariant AnalyticsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coupleId != widget.coupleId ||
        oldWidget.mode != widget.mode) {
      _initStream();
    }
  }

  void _applyPeriodDates(AnalyticsPeriod period) {
    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (period) {
      case AnalyticsPeriod.last7Days:
        _startDate = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 6));
        _endDate = todayEnd;
        break;
      case AnalyticsPeriod.currentMonth:
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = todayEnd;
        break;
      case AnalyticsPeriod.last30Days:
        _startDate = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 29));
        _endDate = todayEnd;
        break;
      case AnalyticsPeriod.last3Months:
        _startDate = DateTime(now.year, now.month - 2, 1);
        _endDate = todayEnd;
        break;
      case AnalyticsPeriod.thisYear:
        _startDate = DateTime(now.year, 1, 1);
        _endDate = todayEnd;
        break;
      case AnalyticsPeriod.custom:
        // Las fechas son elegidas manualmente por el usuario
        break;
    }
  }

  void _selectPeriod(AnalyticsPeriod period) async {
    if (period == AnalyticsPeriod.custom) {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
        builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: kPrimaryColor,
              onPrimary: Colors.white,
              surface: context.nidoSurface,
              onSurface: context.nidoTextDark,
            ),
          ),
          child: child!,
        ),
      );

      if (picked != null) {
        setState(() {
          _selectedPeriod = AnalyticsPeriod.custom;
          _startDate = DateTime(
            picked.start.year,
            picked.start.month,
            picked.start.day,
            0,
            0,
            0,
          );
          _endDate = DateTime(
            picked.end.year,
            picked.end.month,
            picked.end.day,
            23,
            59,
            59,
          );
          _initStream();
        });
      }
      return;
    }

    setState(() {
      _selectedPeriod = period;
      _applyPeriodDates(period);
      _initStream();
    });
  }

  void _initStream() {
    if (widget.mode == NidoUsageMode.guest) {
      _loadGuestData();
    } else {
      _expensesStream = NidoRepository.instance.streamExpenses(
        coupleId: widget.coupleId,
        mode: widget.mode,
        cycleStartDate: _startDate,
        cycleEndDate: _endDate,
      );
    }
  }

  Future<void> _loadGuestData() async {
    final raw = await LocalGuestStorage.getExpenses();
    final parsed = raw.map((e) => Expense.fromJson(e)).toList();
    final filtered = parsed.where((e) {
      if (e.date.isBefore(_startDate)) return false;
      if (e.date.isAfter(_endDate)) return false;
      return true;
    }).toList();

    if (mounted) {
      setState(() {
        _guestExpenses = filtered;
      });
    }
  }

  List<ChartPoint> _buildStockChartPoints(List<Expense> transactions) {
    if (transactions.isEmpty) {
      return [
        ChartPoint(date: _startDate, value: 0.0),
        ChartPoint(date: _endDate, value: 0.0),
      ];
    }

    // Ordenar de más antiguo a más reciente
    final sorted = List<Expense>.from(transactions)
      ..sort((a, b) => a.date.compareTo(b.date));

    // Determinar la cantidad de días del periodo seleccionado
    final totalDays = _endDate.difference(_startDate).inDays + 1;
    final Map<String, List<Expense>> dayMap = {};
    final dayFormat = DateFormat('yyyy-MM-dd');

    for (var i = 0; i < totalDays; i++) {
      final day = _startDate.add(Duration(days: i));
      dayMap[dayFormat.format(day)] = [];
    }

    for (var exp in sorted) {
      final key = dayFormat.format(exp.date);
      if (dayMap.containsKey(key)) {
        dayMap[key]!.add(exp);
      }
    }

    final points = <ChartPoint>[];
    double runningNetBalance = 0.0;

    for (var i = 0; i < totalDays; i++) {
      final day = _startDate.add(Duration(days: i));
      final key = dayFormat.format(day);
      final dayExpenses = dayMap[key] ?? [];

      double dayIncome = 0.0;
      double dayExpense = 0.0;

      for (var e in dayExpenses) {
        if (e.isIncome) {
          dayIncome += e.amount;
        } else {
          dayExpense += e.amount;
        }
      }

      runningNetBalance += (dayIncome - dayExpense);

      points.add(
        ChartPoint(
          date: day,
          value: runningNetBalance,
          income: dayIncome,
          expense: dayExpense,
        ),
      );
    }

    if (points.length == 1) {
      points.insert(0, ChartPoint(date: _startDate, value: 0.0));
    }

    return points;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mode == NidoUsageMode.guest) {
      return _buildAnalyticsContent(context, _guestExpenses);
    }

    return StreamBuilder<List<Expense>>(
      stream: _expensesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: kPrimaryColor),
            ),
          );
        }

        final transactions = snapshot.data ?? [];
        return _buildAnalyticsContent(context, transactions);
      },
    );
  }

  Widget _buildAnalyticsContent(
    BuildContext context,
    List<Expense> transactions,
  ) {
    final surface = context.nidoSurface;
    final border = context.nidoBorder;
    final textDark = context.nidoTextDark;
    final textMuted = context.nidoTextMuted;
    final bg = context.nidoBg;

    final expensesOnly = transactions.where((t) => !t.isIncome).toList();
    final incomesOnly = transactions.where((t) => t.isIncome).toList();

    final totalIngresos =
        incomesOnly.fold<double>(0, (acc, t) => acc + t.amount);
    final totalGastos =
        expensesOnly.fold<double>(0, (acc, t) => acc + t.amount);
    final ahorroNeto = totalIngresos - totalGastos;

    final Map<String, double> gastosPorCategoria = {};
    for (var e in expensesOnly) {
      gastosPorCategoria[e.category] =
          (gastosPorCategoria[e.category] ?? 0) + e.amount;
    }
    final sortedCategories = gastosPorCategoria.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final Map<String, double> ingresosPorMiembro = {};
    for (var i in incomesOnly) {
      final user = i.createdBy.isNotEmpty ? i.createdBy : 'Usuario';
      ingresosPorMiembro[user] = (ingresosPorMiembro[user] ?? 0) + i.amount;
    }

    final stockPoints = _buildStockChartPoints(transactions);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/nido_icon.png',
                width: 28,
                height: 28,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.favorite, color: kPrimaryColor, size: 24),
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
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 100),
        children: [
          // 1. Selector de Periodos Rápido (7D, Este Mes, 30D, 3M, Este Año, Personalizado)
          _buildPeriodSelector(context),
          const SizedBox(height: 8),

          // Subtítulo con rango de fechas exactas
          _buildDateRangeBadge(context),
          const SizedBox(height: 14),

          // 2. Tarjeta Principal: Balance Financiero y Gráfica Estilo Mercado de Acciones
          AnimatedListItem(
            index: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: border, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: kPrimaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.insights_rounded,
                          size: 16,
                          color: kPrimaryColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Balance Financiero',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
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
                          color: (ahorroNeto >= 0 ? kIncomeColor : kExpenseColor)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          ahorroNeto >= 0 ? 'Superávit' : 'Déficit',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color:
                                ahorroNeto >= 0 ? kIncomeColor : kExpenseColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Gráfica Interactiva Estilo Mercado de Acciones con Métricas Simétricas Integradas
                  StockLineChart(
                    points: stockPoints,
                    title: 'Balance Neto Acumulado',
                    currencyFormatter: formatCurrency,
                    positiveColor: const Color(0xFF10B981),
                    negativeColor: const Color(0xFFEF4444),
                    belowHeader: Row(
                      children: [
                        _buildMetricTile(
                          label: 'Ingresos (+)',
                          value: formatCurrency(totalIngresos),
                          color: kIncomeColor,
                          icon: Icons.arrow_upward_rounded,
                          textMuted: textMuted,
                          bg: bg,
                          border: border,
                        ),
                        const SizedBox(width: 10),
                        _buildMetricTile(
                          label: 'Gastos (-)',
                          value: formatCurrency(totalGastos),
                          color: kExpenseColor,
                          icon: Icons.arrow_downward_rounded,
                          textMuted: textMuted,
                          bg: bg,
                          border: border,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 3. Distribución de Gastos por Categoría
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
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: kPrimaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.pie_chart_rounded,
                          size: 16,
                          color: kPrimaryColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Distribución de Gastos',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: textDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (sortedCategories.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Text(
                        'No hay gastos registrados en el periodo seleccionado.',
                        style: TextStyle(color: textMuted, fontSize: 13),
                      ),
                    )
                  else
                    ...sortedCategories.map((entry) {
                      final porcentaje =
                          totalGastos > 0 ? (entry.value / totalGastos) : 0.0;
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
                              key: ValueKey('${entry.key}_${_selectedPeriod.name}'),
                              tween: Tween(begin: 0.0, end: porcentaje),
                              duration: const Duration(milliseconds: 750),
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

          // 4. Aportantes al Fondo en el Periodo
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
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: kSecondaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.group_rounded,
                          size: 16,
                          color: kSecondaryColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Aportantes al Fondo',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: textDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (ingresosPorMiembro.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Text(
                        'No hay ingresos registrados en el periodo seleccionado.',
                        style: TextStyle(color: textMuted, fontSize: 13),
                      ),
                    )
                  else
                    ...ingresosPorMiembro.entries.map((e) {
                      final pct =
                          totalIngresos > 0 ? (e.value / totalIngresos) : 0.0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor:
                                  kSecondaryColor.withValues(alpha: 0.2),
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
                                    key: ValueKey('${e.key}_${_selectedPeriod.name}'),
                                    tween: Tween(begin: 0.0, end: pct),
                                    duration: const Duration(milliseconds: 750),
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

  Widget _buildPeriodSelector(BuildContext context) {
    final surface = context.nidoSurface;
    final border = context.nidoBorder;
    final textMuted = context.nidoTextMuted;

    final periods = [
      {'label': '7D', 'period': AnalyticsPeriod.last7Days},
      {'label': 'Este Mes', 'period': AnalyticsPeriod.currentMonth},
      {'label': '30D', 'period': AnalyticsPeriod.last30Days},
      {'label': '3M', 'period': AnalyticsPeriod.last3Months},
      {'label': 'Este Año', 'period': AnalyticsPeriod.thisYear},
      {'label': '📅 Rango', 'period': AnalyticsPeriod.custom},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1.0),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: periods.map((p) {
            final period = p['period'] as AnalyticsPeriod;
            final label = p['label'] as String;
            final isSelected = _selectedPeriod == period;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: InkWell(
                onTap: () => _selectPeriod(period),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected ? kPrimaryColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: kPrimaryColor.withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? Colors.white : textMuted,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDateRangeBadge(BuildContext context) {
    final textMuted = context.nidoTextMuted;
    final textDark = context.nidoTextDark;
    final surface = context.nidoSurface;
    final border = context.nidoBorder;
    final dateFormat = DateFormat('d MMM y', 'es');
    final startStr = dateFormat.format(_startDate);
    final endStr = dateFormat.format(_endDate);
    final days = _endDate.difference(_startDate).inDays + 1;

    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: border, width: 1.0),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today_rounded, size: 12, color: textMuted),
                const SizedBox(width: 6),
                Text(
                  '$startStr — $endStr',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: textDark,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$days ${days == 1 ? 'día' : 'días'}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: kPrimaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
    required Color textMuted,
    required Color bg,
    required Color border,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 1.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
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
                    fontSize: 15,
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
