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
      backgroundColor: kSurfaceColor,
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
        backgroundColor: kSurfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Gestionar Categorías', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<QuerySnapshot>(
            stream: widget.mode == NidoUsageMode.guest 
                ? null 
                : FirebaseFirestore.instance.collection('couples').doc(widget.coupleId).collection('categories').snapshots(),
            builder: (context, snapshot) {
              if (widget.mode == NidoUsageMode.guest) {
                return FutureBuilder<List<Map<String, dynamic>>>(
                  future: LocalGuestStorage.getCategories(),
                  builder: (ctx, snap) {
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                    final cats = snap.data!.map((e) => CustomCategory.fromJson(e)).toList();
                    if (cats.isEmpty) return const Text('No hay categorías personalizadas', style: TextStyle(color: kTextMuted));
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: cats.length,
                      itemBuilder: (context, index) {
                        final cat = cats[index];
                        return ListTile(
                          leading: Text(cat.emoji, style: const TextStyle(fontSize: 20)),
                          title: Text(cat.name),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: kDangerColor),
                            onPressed: () async {
                              final rawCats = await LocalGuestStorage.getCategories();
                              rawCats.removeWhere((c) => c['id'] == cat.id);
                              await LocalGuestStorage.saveCategories(rawCats);
                              if (ctx.mounted) Navigator.pop(ctx);
                              _gestionarCategorias();
                            },
                          ),
                        );
                      }
                    );
                  }
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) return const Text('No hay categorías personalizadas', style: TextStyle(color: kTextMuted));
              return ListView.builder(
                shrinkWrap: true,
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final cat = CustomCategory.fromFirestore(docs[index]);
                  return ListTile(
                    leading: Text(cat.emoji, style: const TextStyle(fontSize: 20)),
                    title: Text(cat.name),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: kDangerColor),
                      onPressed: () {
                         FirebaseFirestore.instance.collection('couples').doc(widget.coupleId).collection('categories').doc(cat.id).delete();
                      }
                    ),
                  );
                }
              );
            }
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar', style: TextStyle(color: kTextDark))),
        ]
      )
    );
  }

  void _crearNuevaCategoria() {
    final nameCtrl = TextEditingController();
    final emojiCtrl = TextEditingController(text: '🏷️');
    final hexCtrl = TextEditingController();
    int selectedColor = 0xFF00897B;
    String selectedType = 'expense';

    final List<int> colorOptions = [
      0xFF0D9488,
      0xFF00897B,
      0xFF2563EB,
      0xFF6366F1,
      0xFF9333EA,
      0xFFDB2777,
      0xFF059669,
      0xFF475569,
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          backgroundColor: kSurfaceColor,
          title: const Text(
            'Nueva Categoría Personalizada',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre (ej: Mascotas, Cine)',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: emojiCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Emoji (ej: 🐶)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: hexCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Color Hex (Opcional)',
                          hintText: 'ej: FF5733',
                          prefixText: '#',
                        ),
                        maxLength: 6,
                        onChanged: (val) {
                          if (val.length == 6) {
                            final parsed = int.tryParse(val, radix: 16);
                            if (parsed != null) {
                              setDialogState(() => selectedColor = 0xFF000000 | parsed);
                            }
                          }
                        },
                      ),
                    ),
                  ],
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
                            : kTextDark,
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
                            : kTextDark,
                      ),
                      onSelected: (_) =>
                          setDialogState(() => selectedType = 'income'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Color identificador (Predefinidos):',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: kTextMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: colorOptions.map((c) {
                    final isSel = selectedColor == c;
                    return GestureDetector(
                      onTap: () {
                        hexCtrl.clear();
                        setDialogState(() => selectedColor = c);
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: isSel
                              ? Border.all(color: kTextDark, width: 3)
                              : null,
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
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final emoji = emojiCtrl.text.trim();
                if (name.isNotEmpty) {
                  if (widget.mode == NidoUsageMode.guest) {
                    final cats = await LocalGuestStorage.getCategories();
                    cats.add(
                      CustomCategory(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: name,
                        emoji: emoji.isEmpty ? '🏷️' : emoji,
                        colorHex: selectedColor,
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
                          'colorHex': selectedColor,
                          'type': selectedType,
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                  }
                }
                if (ctx.mounted) Navigator.pop(ctx);
                nameCtrl.dispose();
                emojiCtrl.dispose();
                hexCtrl.dispose();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                const Text(
                  'Menú & Ajustes ⚙️',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: kTextDark,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kBackgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kBorderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.calendar_month_outlined,
                        size: 18,
                        color: kPrimaryColor,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Ciclo de Presupuesto',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: kTextDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Elige cuándo se reinician los montos o comienza la quincena:',
                    style: TextStyle(fontSize: 12, color: kTextMuted),
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
                              : kTextDark,
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
                              : kTextDark,
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
              title: const Text(
                'Crear Categoría Personalizada',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: const Text(
                'Añade un icono y color a tus categorías',
                style: TextStyle(fontSize: 12, color: kTextMuted),
              ),
              trailing: const Icon(
                Icons.add_circle_outline_rounded,
                color: kSecondaryColor,
              ),
              onTap: _crearNuevaCategoria,
            ),
            const Divider(color: kBorderColor, height: 1),

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
              title: const Text(
                'Gestionar Categorías',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: const Text(
                'Edita o elimina categorías agregadas por ti',
                style: TextStyle(fontSize: 12, color: kTextMuted),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: kTextMuted,
              ),
              onTap: _gestionarCategorias,
            ),
            const Divider(color: kBorderColor, height: 1),

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
              title: const Text(
                'Histórico de Periodos',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: const Text(
                'Ver resúmenes archivados de meses anteriores',
                style: TextStyle(fontSize: 12, color: kTextMuted),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: kTextMuted,
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
            const Divider(color: kBorderColor, height: 1),

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
              title: const Text(
                'Archivar Periodo Actual',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: const Text(
                'Guarda el resumen y reinicia el saldo para un nuevo ciclo',
                style: TextStyle(fontSize: 12, color: kTextMuted),
              ),
              trailing: const Icon(
                Icons.archive_outlined,
                color: kPrimaryColor,
              ),
              onTap: _cerrarPeriodoYArchivar,
            ),
            const Divider(color: kBorderColor, height: 1),

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
                  title: const Text(
                    'Modo Oscuro',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    isDark ? 'Tema oscuro activo' : 'Tema claro activo',
                    style: const TextStyle(fontSize: 12, color: kTextMuted),
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
            const Divider(color: kBorderColor, height: 1),

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
