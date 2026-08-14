import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';

// ==========================================
// REGISTRAR GASTO / INGRESO (BOTTOM SHEET)
// ==========================================
class AddExpenseBottomSheet extends StatefulWidget {
  final String coupleId;
  final String userName;
  final NidoUsageMode mode;
  final Expense? expenseToEdit;
  final VoidCallback? onGuestRefresh;
  final List<CustomCategory>? customCategories;

  const AddExpenseBottomSheet({
    super.key,
    required this.coupleId,
    required this.userName,
    required this.mode,
    this.expenseToEdit,
    this.onGuestRefresh,
    this.customCategories,
  });

  @override
  State<AddExpenseBottomSheet> createState() => _AddExpenseBottomSheetState();
}

class _AddExpenseBottomSheetState extends State<AddExpenseBottomSheet> {
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;
  late TextEditingController _sourceController;
  late String _transactionType;
  late String _selectedCategory;
  bool _isSaving = false;

  static const List<Map<String, dynamic>> _defaultExpenseCategories = [
    {'name': 'Supermercado', 'emoji': '🛒'},
    {'name': 'Restaurante / Salidas', 'emoji': '🍕'},
    {'name': 'Servicios (Luz/Agua/Internet)', 'emoji': '💡'},
    {'name': 'Arriendo / Vivienda', 'emoji': '🏠'},
    {'name': 'Transporte / Gasolina', 'emoji': '🚗'},
    {'name': 'Salud / Farmacia', 'emoji': '💊'},
    {'name': 'Entretenimiento / Ocio', 'emoji': '🎬'},
    {'name': 'Mascotas', 'emoji': '🐾'},
    {'name': 'Ropa / Compras', 'emoji': '🛍️'},
    {'name': 'Viajes', 'emoji': '✈️'},
    {'name': 'Educación', 'emoji': '📚'},
    {'name': 'Cuidado Personal', 'emoji': '✨'},
    {'name': 'Gatos', 'emoji': '🐱'},
    {'name': 'Construcción / Hogar', 'emoji': '🧱'},
    {'name': 'Citas & Salidas', 'emoji': '👩‍❤️‍👨'},
    {'name': 'Muebles / Decó', 'emoji': '🪑'},
    {'name': 'Ahorro Nido', 'emoji': '🐷'},
    {'name': 'Otros', 'emoji': '📦'},
  ];

  static const List<Map<String, dynamic>> _defaultIncomeCategories = [
    {'name': 'Sueldo / Nómina', 'emoji': '💼'},
    {'name': 'Freelance / Negocio', 'emoji': '💻'},
    {'name': 'Venta', 'emoji': '🏷️'},
    {'name': 'Inversiones', 'emoji': '📈'},
    {'name': 'Regalo / Bonificación', 'emoji': '🎁'},
    {'name': 'Reembolso', 'emoji': '🔄'},
    {'name': 'Otros Ingresos', 'emoji': '💰'},
  ];

  @override
  void initState() {
    super.initState();
    final ex = widget.expenseToEdit;
    _transactionType = ex?.type ?? 'expense';
    _amountController = TextEditingController(
      text: ex != null ? ex.amount.toInt().toString() : '',
    );
    _descriptionController = TextEditingController(text: ex?.description ?? '');
    _sourceController = TextEditingController(
      text: ex?.sourceOrDestination ?? '',
    );
    _selectedCategory = ex?.category ?? _defaultCategoryName(_transactionType == 'income');

    if (ex != null && ex.category.isNotEmpty) {
      _selectedCategory = ex.category;
    }
  }

  List<Map<String, dynamic>> _buildCategoryOptions(bool isIncome) {
    final defaults = isIncome
        ? _defaultIncomeCategories
        : _defaultExpenseCategories;
    final custom = (widget.customCategories ?? [])
        .where((category) => category.type == (isIncome ? 'income' : 'expense'))
        .map(
          (category) => {
            'name': category.name,
            'emoji': category.emoji,
            'icon': Icons.category_outlined,
          },
        )
        .toList();

    // Priorizar recencia: categorías personalizadas (más recientes primero) seguidas de las predeterminadas
    final combined = [...custom.reversed, ...defaults];
    return combined;
  }

  String _defaultCategoryName(bool isIncome) {
    final categories = _buildCategoryOptions(isIncome);
    if (categories.isEmpty) {
      return isIncome ? 'Sueldo / Nómina' : 'Citas & Salidas';
    }
    return categories.first['name'] as String;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  Future<void> _guardarMovimiento() async {
    final amount = parseFormattedAmount(_amountController.text);
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Ingresa un monto válido'),
          backgroundColor: kDangerColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (widget.mode == NidoUsageMode.guest) {
        final list = await LocalGuestStorage.getExpenses();
        final exp = Expense(
          id:
              widget.expenseToEdit?.id ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          type: _transactionType,
          amount: amount,
          description: _descriptionController.text.trim(),
          category: _selectedCategory,
          sourceOrDestination: _sourceController.text.trim().isEmpty
              ? 'General'
              : _sourceController.text.trim(),
          createdBy: widget.userName,
          date: widget.expenseToEdit?.date ?? DateTime.now(),
        );

        if (widget.expenseToEdit != null) {
          final idx = list.indexWhere(
            (i) => i['id'] == widget.expenseToEdit!.id,
          );
          if (idx != -1) list[idx] = exp.toJson();
        } else {
          list.add(exp.toJson());
        }
        await LocalGuestStorage.saveExpenses(list);
        if (widget.onGuestRefresh != null) widget.onGuestRefresh!();
      } else {
        final collectionRef = FirebaseFirestore.instance
            .collection('couples')
            .doc(widget.coupleId)
            .collection('expenses');

        final data = {
          'type': _transactionType,
          'amount': amount,
          'description': _descriptionController.text.trim(),
          'category': _selectedCategory,
          'sourceOrDestination': _sourceController.text.trim().isEmpty
              ? 'General'
              : _sourceController.text.trim(),
          'createdBy': widget.userName,
          'date': widget.expenseToEdit != null
              ? Timestamp.fromDate(widget.expenseToEdit!.date)
              : Timestamp.now(),
        };

        if (widget.expenseToEdit != null) {
          await collectionRef.doc(widget.expenseToEdit!.id).update(data);
        } else {
          await collectionRef.add(data);
        }
      }

      HapticFeedback.lightImpact();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al guardar. Intenta de nuevo.'),
            backgroundColor: kDangerColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardPadding = MediaQuery.of(context).viewInsets.bottom;
    final isIncome = _transactionType == 'income';
    final categories = _buildCategoryOptions(isIncome);
    final bg = context.nidoBg;
    final surface = context.nidoSurface;
    final border = context.nidoBorder;
    final textDark = context.nidoTextDark;
    final textMuted = context.nidoTextMuted;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: 24 + keyboardPadding,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.center,
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Container(
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: border),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _transactionType = 'expense';
                          _selectedCategory = _defaultCategoryName(false);
                        });
                        HapticFeedback.selectionClick();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !isIncome ? kExpenseColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '➖ Registrar Gasto',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: !isIncome ? Colors.white : textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _transactionType = 'income';
                          _selectedCategory = _defaultCategoryName(true);
                        });
                        HapticFeedback.selectionClick();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isIncome ? kIncomeColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '➕ Añadir Ingreso',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isIncome ? Colors.white : textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _amountController,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsSeparatorInputFormatter()],
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                color: isIncome ? kIncomeColor : kExpenseColor,
                letterSpacing: -1.5,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: border,
                  letterSpacing: -1.5,
                ),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                prefixText: isIncome ? '+ ' : '- ',
                prefixStyle: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: isIncome ? kIncomeColor : kExpenseColor,
                ),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _descriptionController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: isIncome
                    ? '¿De qué es este ingreso?'
                    : '¿En qué se gastó?',
                prefixIcon: Icon(
                  Icons.notes_outlined,
                  size: 20,
                  color: textMuted,
                ),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _sourceController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: isIncome
                    ? 'Origen (ej: Cuenta Nómina, Efectivo)'
                    : 'Método / Cuenta (ej: Tarjeta, Efectivo)',
                prefixIcon: Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 20,
                  color: textMuted,
                ),
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  final isSelected = _selectedCategory == cat['name'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      showCheckmark: false,
                      label: Text(
                        cat['name'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : textDark,
                        ),
                      ),
                      avatar: cat.containsKey('emoji')
                          ? Text(
                              cat['emoji'] as String,
                              style: const TextStyle(fontSize: 14),
                            )
                          : Icon(
                              cat['icon'] as IconData,
                              size: 14,
                              color: isSelected ? Colors.white : textMuted,
                            ),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(
                          () => _selectedCategory = cat['name'] as String,
                        );
                        HapticFeedback.selectionClick();
                      },
                      selectedColor: isIncome ? kIncomeColor : kExpenseColor,
                      backgroundColor: surface,
                      side: BorderSide(
                        color: isSelected
                            ? (isIncome ? kIncomeColor : kExpenseColor)
                            : border,
                        width: 1.0,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isSaving ? null : _guardarMovimiento,
              style: ElevatedButton.styleFrom(
                backgroundColor: isIncome ? kIncomeColor : kExpenseColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    (isIncome ? kIncomeColor : kExpenseColor).withValues(
                      alpha: 0.5,
                    ),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      widget.expenseToEdit != null
                          ? 'Guardar Cambios'
                          : (isIncome ? 'Guardar Ingreso' : 'Registrar Gasto'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
