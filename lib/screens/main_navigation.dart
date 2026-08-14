import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../main.dart';

class MainNavigation extends StatefulWidget {
  final String coupleId;
  final String userId;
  final String userName;
  final NidoUsageMode mode;

  const MainNavigation({
    super.key,
    required this.coupleId,
    required this.userId,
    required this.userName,
    this.mode = NidoUsageMode.couple,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  String? _lastHandledPingId;

  @override
  void initState() {
    super.initState();
    if (widget.mode == NidoUsageMode.couple) {
      _listenToLovePings();
    }
  }

  void _listenToLovePings() {
    FirebaseFirestore.instance
        .collection('couples')
        .doc(widget.coupleId)
        .collection('pings')
        .orderBy('date', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.docs.isEmpty) return;
          final doc = snapshot.docs.first;
          if (doc.id == _lastHandledPingId) return;
          _lastHandledPingId = doc.id;

          final data = doc.data();
          final createdBy = (data['createdBy'] as String?) ?? '';
          final message = (data['message'] as String?) ?? '';
          final date = (data['date'] as Timestamp?)?.toDate();

          if (createdBy.isNotEmpty &&
              createdBy != widget.userName &&
              date != null) {
            if (DateTime.now().difference(date).inSeconds < 45) {
              HapticFeedback.heavyImpact();
              showLocalNotification('💕 Guiño de Amor de $createdBy', message);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(
                          Icons.favorite,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '$createdBy te envió: "$message"',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: kPrimaryColor,
                    duration: const Duration(seconds: 5),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    margin: const EdgeInsets.all(16),
                  ),
                );
              }
            }
          }
        });
  }

  void _openOptionsMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => NidoOptionsMenu(
        coupleId: widget.coupleId,
        userId: widget.userId,
        userName: widget.userName,
        mode: widget.mode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      DashboardScreen(
        coupleId: widget.coupleId,
        userId: widget.userId,
        userName: widget.userName,
        mode: widget.mode,
        onOpenMenu: _openOptionsMenu,
      ),
      AnalyticsScreen(
        coupleId: widget.coupleId,
        userName: widget.userName,
        mode: widget.mode,
      ),
      ShoppingListScreen(
        coupleId: widget.coupleId,
        userId: widget.userId,
        mode: widget.mode,
      ),
      SavingsGoalsScreen(coupleId: widget.coupleId, mode: widget.mode),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: kBorderColor, width: 1.2)),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) =>
              setState(() => _currentIndex = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(
                Icons.account_balance_wallet_outlined,
                color: kTextMuted,
              ),
              selectedIcon: Icon(
                Icons.account_balance_wallet,
                color: kPrimaryColor,
              ),
              label: 'Resumen',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined, color: kTextMuted),
              selectedIcon: Icon(Icons.bar_chart_rounded, color: kPrimaryColor),
              label: 'Análisis',
            ),
            NavigationDestination(
              icon: Icon(Icons.shopping_bag_outlined, color: kTextMuted),
              selectedIcon: Icon(Icons.shopping_bag, color: kPrimaryColor),
              label: 'Compras',
            ),
            NavigationDestination(
              icon: Icon(Icons.savings_outlined, color: kTextMuted),
              selectedIcon: Icon(Icons.savings_rounded, color: kPrimaryColor),
              label: 'Ahorros',
            ),
          ],
        ),
      ),
    );
  }
}

class NidoOptionsMenu extends StatefulWidget {
  final String coupleId;
  final String userId;
  final String userName;
  final NidoUsageMode mode;

  const NidoOptionsMenu({
    super.key,
    required this.coupleId,
    required this.userId,
    required this.userName,
    required this.mode,
  });

  @override
  State<NidoOptionsMenu> createState() => _NidoOptionsMenuState();
}

class _NidoOptionsMenuState extends State<NidoOptionsMenu> {
  int _resetDay = 1;
  String _resetMode = 'monthly';

  @override
  void initState() {
    super.initState();
    _loadCoupleSettings();
  }

  Future<void> _loadCoupleSettings() async {
    if (widget.mode != NidoUsageMode.guest) {
      final doc = await FirebaseFirestore.instance
          .collection('couples')
          .doc(widget.coupleId)
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (mounted) {
          setState(() {
            _resetDay = (data['resetDay'] as num?)?.toInt() ?? 1;
            _resetMode = (data['resetMode'] as String?) ?? 'monthly';
          });
        }
      }
    }
  }

  Future<void> _updateResetSettings(int day, String mode) async {
    setState(() {
      _resetDay = day;
      _resetMode = mode;
    });
    if (widget.mode != NidoUsageMode.guest) {
      await FirebaseFirestore.instance
          .collection('couples')
          .doc(widget.coupleId)
          .update({'resetDay': day, 'resetMode': mode});
    }
    HapticFeedback.lightImpact();
  }

  Future<void> _cerrarPeriodoYArchivar() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Cerrar y archivar periodo actual?'),
        content: const Text(
          'Esto guardará un resumen completo de los gastos e ingresos actuales en el Histórico de Periodos de Nido.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Archivar Periodo'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);

      double totalIncome = 0;
      double totalExpense = 0;

      if (widget.mode == NidoUsageMode.guest) {
        final list = await LocalGuestStorage.getExpenses();
        for (var item in list) {
          final isInc = item['type'] == 'income';
          final amt = (item['amount'] as num?)?.toDouble() ?? 0.0;
          if (isInc) {
            totalIncome += amt;
          } else {
            totalExpense += amt;
          }
        }

        final periodTitle = _resetMode == 'biweekly'
            ? 'Quincena - ${DateFormat('MMMM yyyy', 'es').format(now).capitalize()}'
            : DateFormat('MMMM yyyy', 'es').format(now).capitalize();

        final historyList = await LocalGuestStorage.getHistory();
        historyList.add(
          HistoryPeriod(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: periodTitle,
            startDate: startOfMonth,
            endDate: now,
            totalIncome: totalIncome,
            totalExpense: totalExpense,
            balance: totalIncome - totalExpense,
            closedBy: widget.userName,
            createdAt: now,
          ).toJson(),
        );
        await LocalGuestStorage.saveHistory(historyList);
      } else {
        final snapshot = await FirebaseFirestore.instance
            .collection('couples')
            .doc(widget.coupleId)
            .collection('expenses')
            .where(
              'date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
            )
            .get();

        final expenses = snapshot.docs
            .map((d) => Expense.fromFirestore(d))
            .toList();
        for (var e in expenses) {
          if (e.isIncome) {
            totalIncome += e.amount;
          } else {
            totalExpense += e.amount;
          }
        }

        final periodTitle = _resetMode == 'biweekly'
            ? 'Quincena - ${DateFormat('MMMM yyyy', 'es').format(now).capitalize()}'
            : DateFormat('MMMM yyyy', 'es').format(now).capitalize();

        await FirebaseFirestore.instance
            .collection('couples')
            .doc(widget.coupleId)
            .collection('history_periods')
            .add({
              'title': periodTitle,
              'startDate': Timestamp.fromDate(startOfMonth),
              'endDate': Timestamp.fromDate(now),
              'totalIncome': totalIncome,
              'totalExpense': totalExpense,
              'balance': totalIncome - totalExpense,
              'closedBy': widget.userName,
              'createdAt': FieldValue.serverTimestamp(),
            });
        await FirebaseFirestore.instance
            .collection('couples')
            .doc(widget.coupleId)
            .update({'cycle_start_date': FieldValue.serverTimestamp()});
      }

      if (widget.mode == NidoUsageMode.guest) {
        await LocalGuestStorage.setCycleStartDate(now);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✨ Periodo archivado e iniciado nuevo ciclo'),
            backgroundColor: kSecondaryColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al archivar periodo'),
            backgroundColor: kDangerColor,
          ),
        );
      }
    }
  }

  void _gestionarCategorias() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.nidoSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Gestionar Categorías',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: context.nidoTextDark,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<QuerySnapshot>(
            stream: widget.mode == NidoUsageMode.guest
                ? null
                : FirebaseFirestore.instance
                    .collection('couples')
                    .doc(widget.coupleId)
                    .collection('categories')
                    .snapshots(),
            builder: (context, snapshot) {
              if (widget.mode == NidoUsageMode.guest) {
                return FutureBuilder<List<Map<String, dynamic>>>(
                  future: LocalGuestStorage.getCategories(),
                  builder: (ctx, snap) {
                    if (!snap.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: kPrimaryColor),
                      );
                    }
                    final cats = snap.data!
                        .map((e) => CustomCategory.fromJson(e))
                        .toList();
                    if (cats.isEmpty) {
                      return Text(
                        'No hay categorías personalizadas',
                        style: TextStyle(color: context.nidoTextMuted),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: cats.length,
                      itemBuilder: (context, index) {
                        final cat = cats[index];
                        return ListTile(
                          leading: Text(
                            cat.emoji,
                            style: const TextStyle(fontSize: 20),
                          ),
                          title: Text(
                            cat.name,
                            style: TextStyle(color: context.nidoTextDark),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: kDangerColor,
                            ),
                            onPressed: () async {
                              final rawCats =
                                  await LocalGuestStorage.getCategories();
                              rawCats.removeWhere((c) => c['id'] == cat.id);
                              await LocalGuestStorage.saveCategories(rawCats);
                              if (ctx.mounted) Navigator.pop(ctx);
                              _gestionarCategorias();
                            },
                          ),
                        );
                      },
                    );
                  },
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: kPrimaryColor),
                );
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Text(
                  'No hay categorías personalizadas',
                  style: TextStyle(color: context.nidoTextMuted),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final cat = CustomCategory.fromFirestore(docs[index]);
                  return ListTile(
                    leading: Text(
                      cat.emoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                    title: Text(
                      cat.name,
                      style: TextStyle(color: context.nidoTextDark),
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: kDangerColor,
                      ),
                      onPressed: () {
                        FirebaseFirestore.instance
                            .collection('couples')
                            .doc(widget.coupleId)
                            .collection('categories')
                            .doc(cat.id)
                            .delete();
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cerrar',
              style: TextStyle(color: context.nidoTextDark),
            ),
          ),
        ],
      ),
    );
  }

  void _crearNuevaCategoria() {
    final nameCtrl = TextEditingController();
    final emojiCtrl = TextEditingController(text: '🏷️');
    int red = 13;
    int green = 148;
    int blue = 136;
    double alpha = 1.0;
    String selectedType = 'expense';

    final List<Color> presetColors = [
      const Color(0xFF0D9488),
      const Color(0xFF00897B),
      const Color(0xFF2563EB),
      const Color(0xFF6366F1),
      const Color(0xFF9333EA),
      const Color(0xFFDB2777),
      const Color(0xFF059669),
      const Color(0xFFE53935),
      const Color(0xFFF59E0B),
      const Color(0xFF475569),
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final currentColor = Color.fromARGB(
            (alpha * 255).round(),
            red,
            green,
            blue,
          );

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: context.nidoSurface,
            title: Text(
              'Nueva Categoría Personalizada',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: context.nidoTextDark,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    style: TextStyle(color: context.nidoTextDark),
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Nombre (ej: Mascotas, Cine)',
                      labelStyle: TextStyle(color: context.nidoTextMuted),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emojiCtrl,
                    style: TextStyle(color: context.nidoTextDark),
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Emoji (ej: 🐶)',
                      labelStyle: TextStyle(color: context.nidoTextMuted),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('➖ Gasto'),
                        selected: selectedType == 'expense',
                        selectedColor: kExpenseColor,
                        labelStyle: TextStyle(
                          color: selectedType == 'expense'
                              ? Colors.white
                              : context.nidoTextDark,
                        ),
                        onSelected: (_) =>
                            setDialogState(() => selectedType = 'expense'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('➕ Ingreso'),
                        selected: selectedType == 'income',
                        selectedColor: kIncomeColor,
                        labelStyle: TextStyle(
                          color: selectedType == 'income'
                              ? Colors.white
                              : context.nidoTextDark,
                        ),
                        onSelected: (_) =>
                            setDialogState(() => selectedType = 'income'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // VISTA PREVIA DEL COLOR Y BADGE
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.nidoBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.nidoBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: currentColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: context.nidoBorder,
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            emojiCtrl.text.trim().isEmpty
                                ? '🏷️'
                                : emojiCtrl.text.trim(),
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nameCtrl.text.trim().isEmpty
                                    ? 'Nombre Categoría'
                                    : nameCtrl.text.trim(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: context.nidoTextDark,
                                ),
                              ),
                              Text(
                                'HEX: #${currentColor.toARGB32().toRadixString(16).toUpperCase().padLeft(8, '0')}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: context.nidoTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'Selector de Color (RGBA libre):',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: context.nidoTextDark,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Slider Rojo
                  Row(
                    children: [
                      const Text('🔴', style: TextStyle(fontSize: 12)),
                      Expanded(
                        child: Slider(
                          value: red.toDouble(),
                          min: 0,
                          max: 255,
                          activeColor: Colors.red,
                          onChanged: (val) =>
                              setDialogState(() => red = val.round()),
                        ),
                      ),
                      Text(
                        '$red',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.nidoTextMuted,
                        ),
                      ),
                    ],
                  ),

                  // Slider Verde
                  Row(
                    children: [
                      const Text('🟢', style: TextStyle(fontSize: 12)),
                      Expanded(
                        child: Slider(
                          value: green.toDouble(),
                          min: 0,
                          max: 255,
                          activeColor: Colors.green,
                          onChanged: (val) =>
                              setDialogState(() => green = val.round()),
                        ),
                      ),
                      Text(
                        '$green',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.nidoTextMuted,
                        ),
                      ),
                    ],
                  ),

                  // Slider Azul
                  Row(
                    children: [
                      const Text('🔵', style: TextStyle(fontSize: 12)),
                      Expanded(
                        child: Slider(
                          value: blue.toDouble(),
                          min: 0,
                          max: 255,
                          activeColor: Colors.blue,
                          onChanged: (val) =>
                              setDialogState(() => blue = val.round()),
                        ),
                      ),
                      Text(
                        '$blue',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.nidoTextMuted,
                        ),
                      ),
                    ],
                  ),

                  // Slider Transparencia / Alpha
                  Row(
                    children: [
                      const Text('💧', style: TextStyle(fontSize: 12)),
                      Expanded(
                        child: Slider(
                          value: alpha,
                          min: 0.1,
                          max: 1.0,
                          activeColor: kPrimaryColor,
                          onChanged: (val) => setDialogState(() => alpha = val),
                        ),
                      ),
                      Text(
                        '${(alpha * 100).round()}%',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.nidoTextMuted,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  Text(
                    'Colores rápidos:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: context.nidoTextMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: presetColors.map((c) {
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            red = c.r.toInt();
                            green = c.g.toInt();
                            blue = c.b.toInt();
                            alpha = 1.0;
                          });
                        },
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: context.nidoBorder,
                              width: 1,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Cancelar',
                  style: TextStyle(color: context.nidoTextMuted),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  final emoji = emojiCtrl.text.trim();
                  if (name.isNotEmpty) {
                    final colorValue = currentColor.toARGB32();
                    if (widget.mode == NidoUsageMode.guest) {
                      final cats = await LocalGuestStorage.getCategories();
                      cats.add(
                        CustomCategory(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          name: name,
                          emoji: emoji.isEmpty ? '🏷️' : emoji,
                          colorHex: colorValue,
                          type: selectedType,
                        ).toJson(),
                      );
                      await LocalGuestStorage.saveCategories(cats);
                    } else {
                      await FirebaseFirestore.instance
                          .collection('couples')
                          .doc(widget.coupleId)
                          .collection('categories')
                          .add({
                            'name': name,
                            'emoji': emoji.isEmpty ? '🏷️' : emoji,
                            'colorHex': colorValue,
                            'type': selectedType,
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                    }
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  nameCtrl.dispose();
                  emojiCtrl.dispose();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surface = context.nidoSurface;
    final bg = context.nidoBg;
    final border = context.nidoBorder;
    final textDark = context.nidoTextDark;
    final textMuted = context.nidoTextMuted;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.settings_outlined,
                  color: kPrimaryColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Menú & Ajustes ⚙️',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textDark,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, size: 20, color: textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_outlined,
                        size: 18,
                        color: kPrimaryColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Ciclo de Presupuesto',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: textDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Elige cuándo se reinician los montos o comienza la quincena:',
                    style: TextStyle(fontSize: 12, color: textMuted),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Mensual'),
                        selected: _resetMode == 'monthly',
                        selectedColor: kPrimaryColor,
                        labelStyle: TextStyle(
                          color: _resetMode == 'monthly'
                              ? Colors.white
                              : textDark,
                          fontSize: 12,
                        ),
                        onSelected: (_) =>
                            _updateResetSettings(_resetDay, 'monthly'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Quincenal (Día 1 y 16)'),
                        selected: _resetMode == 'biweekly',
                        selectedColor: kPrimaryColor,
                        labelStyle: TextStyle(
                          color: _resetMode == 'biweekly'
                              ? Colors.white
                              : textDark,
                          fontSize: 12,
                        ),
                        onSelected: (_) => _updateResetSettings(1, 'biweekly'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kSecondaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.category_outlined,
                  color: kSecondaryColor,
                  size: 20,
                ),
              ),
              title: Text(
                'Crear Categoría Personalizada',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: textDark,
                ),
              ),
              subtitle: Text(
                'Añade un icono y color a tus categorías',
                style: TextStyle(fontSize: 12, color: textMuted),
              ),
              trailing: const Icon(
                Icons.add_circle_outline_rounded,
                color: kSecondaryColor,
              ),
              onTap: _crearNuevaCategoria,
            ),
            Divider(color: border, height: 1),

            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.edit_note_rounded,
                  color: kPrimaryColor,
                  size: 20,
                ),
              ),
              title: Text(
                'Gestionar Categorías',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: textDark,
                ),
              ),
              subtitle: Text(
                'Edita o elimina categorías agregadas por ti',
                style: TextStyle(fontSize: 12, color: textMuted),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: textMuted,
              ),
              onTap: _gestionarCategorias,
            ),
            Divider(color: border, height: 1),

            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kSecondaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: kSecondaryColor,
                  size: 20,
                ),
              ),
              title: Text(
                'Histórico de Periodos',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: textDark,
                ),
              ),
              subtitle: Text(
                'Ver resúmenes archivados de meses anteriores',
                style: TextStyle(fontSize: 12, color: textMuted),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: textMuted,
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) => HistoryScreen(
                      coupleId: widget.coupleId,
                      mode: widget.mode,
                    ),
                  ),
                );
              },
            ),
            Divider(color: border, height: 1),

            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: kPrimaryColor,
                  size: 20,
                ),
              ),
              title: Text(
                'Archivar Periodo Actual',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: textDark,
                ),
              ),
              subtitle: Text(
                'Guarda el resumen y reinicia el saldo para un nuevo ciclo',
                style: TextStyle(fontSize: 12, color: textMuted),
              ),
              trailing: const Icon(
                Icons.archive_outlined,
                color: kPrimaryColor,
              ),
              onTap: _cerrarPeriodoYArchivar,
            ),
            Divider(color: border, height: 1),

            ValueListenableBuilder<ThemeMode>(
              valueListenable: nidoThemeMode,
              builder: (context, currentMode, child) {
                final isDark = currentMode == ThemeMode.dark;
                return SwitchListTile(
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.amber : kPrimaryColor).withValues(
                        alpha: 0.12,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isDark
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      color: isDark ? Colors.amber : kPrimaryColor,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Modo Oscuro',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: textDark,
                    ),
                  ),
                  subtitle: Text(
                    isDark ? 'Tema oscuro activo' : 'Tema claro activo',
                    style: TextStyle(fontSize: 12, color: textMuted),
                  ),
                  value: isDark,
                  activeThumbColor: kPrimaryColor,
                  onChanged: (val) {
                    nidoThemeMode.value =
                        val ? ThemeMode.dark : ThemeMode.light;
                    LocalGuestStorage.saveThemeMode(
                      val ? ThemeMode.dark : ThemeMode.light,
                    );
                    HapticFeedback.lightImpact();
                  },
                );
              },
            ),
            Divider(color: border, height: 1),

            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kDangerColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: kDangerColor,
                  size: 20,
                ),
              ),
              title: const Text(
                'Cerrar Sesión',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: kDangerColor,
                ),
              ),
              onTap: () async {
                Navigator.pop(context);
                if (widget.mode == NidoUsageMode.couple) {
                  await FirebaseAuth.instance.signOut();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
