import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import 'pocket_detail_screen.dart';
import '../widgets/pocket_widgets.dart';

// ==========================================
// PANTALLA: TODOS LOS BOLSILLOS (GESTIÓN GENERAL)
// ==========================================
class PocketsScreen extends StatefulWidget {
  final String coupleId;
  final String userName;
  final NidoUsageMode mode;

  const PocketsScreen({
    super.key,
    required this.coupleId,
    required this.userName,
    required this.mode,
  });

  @override
  State<PocketsScreen> createState() => _PocketsScreenState();
}

class _PocketsScreenState extends State<PocketsScreen> {
  List<Pocket> _guestPockets = [];
  List<Expense> _guestExpenses = [];
  Stream<List<Pocket>>? _pocketsStream;
  Stream<List<Expense>>? _expensesStream;

  @override
  void initState() {
    super.initState();
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
    });
  }

  @override
  void didUpdateWidget(covariant PocketsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coupleId != widget.coupleId || oldWidget.mode != widget.mode) {
      if (widget.mode == NidoUsageMode.guest) {
        _loadGuestData();
      } else {
        _initStreams();
      }
    }
  }

  Future<void> _loadGuestData() async {
    final rawPockets = await LocalGuestStorage.getPockets();
    final rawExpenses = await LocalGuestStorage.getExpenses();
    final cycleStart = await LocalGuestStorage.getCycleStartDate();

    if (mounted) {
      setState(() {
        _guestPockets = rawPockets.map((p) => Pocket.fromJson(p)).toList();
        final parsed = rawExpenses.map((e) => Expense.fromJson(e)).toList();
        _guestExpenses = parsed.where((e) => !e.date.isBefore(cycleStart)).toList();
      });
    }
  }

  void _openCreatePocketDialog() {
    showDialog(
      context: context,
      builder: (ctx) => PocketFormDialog(
        onSave: (newPocket, initialDeposit) async {
          final pocketToSave = newPocket.copyWith(
            initialAmount: initialDeposit > 0 ? initialDeposit : 0.0,
          );

          await NidoRepository.instance.addPocket(
            coupleId: widget.coupleId,
            mode: widget.mode,
            pocket: pocketToSave,
          );

          if (widget.mode == NidoUsageMode.guest) {
            _loadGuestData();
          }

          if (mounted) {
            HapticFeedback.mediumImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✨ Bolsillo "${newPocket.name}" creado con éxito'),
                backgroundColor: kSecondaryColor,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mode == NidoUsageMode.guest) {
      return _buildPocketsUI(_guestPockets, _guestExpenses);
    }

    return StreamBuilder<List<Pocket>>(
      stream: _pocketsStream,
      builder: (context, pocketSnap) {
        final pockets = pocketSnap.data ?? [];

        return StreamBuilder<List<Expense>>(
          stream: _expensesStream,
          builder: (context, expSnap) {
            final expenses = expSnap.data ?? [];
            return _buildPocketsUI(pockets, expenses);
          },
        );
      },
    );
  }

  Widget _buildPocketsUI(List<Pocket> pockets, List<Expense> expenses) {
    final bg = context.nidoBg;
    final textDark = context.nidoTextDark;
    final textMuted = context.nidoTextMuted;

    // Calcular el total disponible en todos los bolsillos
    double totalDisponibleBolsillos = 0.0;
    double totalGastadoBolsillos = 0.0;

    for (final p in pockets) {
      final m = calculatePocketMetrics(pocket: p, expenses: expenses);
      totalDisponibleBolsillos += m.available;
      totalGastadoBolsillos += m.spent;
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Mis Bolsillos 👛'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: _openCreatePocketDialog,
            tooltip: 'Crear nuevo bolsillo',
          ),
        ],
      ),
      body: pockets.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: kPrimaryColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Text('👛', style: TextStyle(fontSize: 40)),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No tienes bolsillos aún',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Separa tu dinero en bolsillos (Mercado, Salidas, Servicios, Viajes...) para no gastar lo que no debes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: textMuted),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _openCreatePocketDialog,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Crear mi primer bolsillo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : CustomScrollView(
              slivers: [
                // Resumen Global de Bolsillos
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0D9488), Color(0xFF00695C)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: kPrimaryColor.withValues(alpha: 0.25),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.account_balance_wallet_outlined,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Total en Bolsillos',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white70,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${pockets.length} ${pockets.length == 1 ? 'bolsillo' : 'bolsillos'}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              formatCurrency(totalDisponibleBolsillos),
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.8,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(
                                Icons.arrow_downward_rounded,
                                color: Color(0xFFFCA5A5),
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Gastado en bolsillos: ${formatCurrency(totalGastadoBolsillos)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Lista / Cuadrícula de Bolsillos
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 0.76,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index == pockets.length) {
                          return NewPocketDashedCard(
                            onTap: _openCreatePocketDialog,
                            width: double.infinity,
                          );
                        }

                        final p = pockets[index];
                        final m = calculatePocketMetrics(
                          pocket: p,
                          expenses: expenses,
                        );

                        return PocketCard(
                          pocket: p,
                          metrics: m,
                          width: double.infinity,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (ctx) => PocketDetailScreen(
                                  initialPocket: p,
                                  coupleId: widget.coupleId,
                                  userName: widget.userName,
                                  mode: widget.mode,
                                  onRefresh: () {
                                    if (widget.mode == NidoUsageMode.guest) {
                                      _loadGuestData();
                                    }
                                  },
                                ),
                              ),
                            );
                          },
                        );
                      },
                      childCount: pockets.length + 1,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
