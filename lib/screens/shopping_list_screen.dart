import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';

// ==========================================
// PANTALLA 3: LISTA DE COMPRAS
// ==========================================
class ShoppingListScreen extends StatefulWidget {
  final String coupleId;
  final String userId;
  final NidoUsageMode mode;

  const ShoppingListScreen({
    super.key,
    required this.coupleId,
    required this.userId,
    required this.mode,
  });

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  final _itemController = TextEditingController();
  bool _isAdding = false;
  List<Map<String, dynamic>> _guestShopping = [];

  @override
  void initState() {
    super.initState();
    if (widget.mode == NidoUsageMode.guest) {
      _loadGuestShopping();
    }
  }

  Future<void> _loadGuestShopping() async {
    final list = await LocalGuestStorage.getShoppingList();
    if (mounted) setState(() => _guestShopping = list);
  }

  @override
  void dispose() {
    _itemController.dispose();
    super.dispose();
  }

  Future<void> _addItem() async {
    final text = _itemController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isAdding = true);
    try {
      if (widget.mode == NidoUsageMode.guest) {
        _guestShopping.add({
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'name': text,
          'isBought': false,
          'date': DateTime.now().toIso8601String(),
        });
        await LocalGuestStorage.saveShoppingList(_guestShopping);
        _loadGuestShopping();
      } else {
        await FirebaseFirestore.instance
            .collection('couples')
            .doc(widget.coupleId)
            .collection('shopping_list')
            .add({
              'name': text,
              'title': text,
              'item': text,
              'isBought': false,
              'date': Timestamp.now(),
              'addedBy': widget.userId,
            });
      }
      _itemController.clear();
      HapticFeedback.lightImpact();
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _editarItem(String docId, String currentName) async {
    final editCtrl = TextEditingController(text: currentName);
    final surface = context.nidoSurface;
    final textDark = context.nidoTextDark;
    final textMuted = context.nidoTextMuted;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Modificar Artículo',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark),
        ),
        content: TextField(
          controller: editCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Nombre del artículo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newText = editCtrl.text.trim();
              if (newText.isNotEmpty) {
                if (widget.mode == NidoUsageMode.guest) {
                  final idx = _guestShopping.indexWhere(
                    (i) => i['id'] == docId,
                  );
                  if (idx != -1) {
                    _guestShopping[idx]['name'] = newText;
                    await LocalGuestStorage.saveShoppingList(_guestShopping);
                    _loadGuestShopping();
                  }
                } else {
                  await FirebaseFirestore.instance
                      .collection('couples')
                      .doc(widget.coupleId)
                      .collection('shopping_list')
                      .doc(docId)
                      .update({
                        'name': newText,
                        'title': newText,
                        'item': newText,
                      });
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
              editCtrl.dispose();
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

  Future<void> _eliminarItem(String docId, String name) async {
    final surface = context.nidoSurface;
    final textDark = context.nidoTextDark;
    final textMuted = context.nidoTextMuted;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '¿Eliminar artículo?',
          style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text(
          '¿Seguro que quieres borrar "$name" de la lista?',
          style: TextStyle(color: textMuted, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kDangerColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (widget.mode == NidoUsageMode.guest) {
        _guestShopping.removeWhere((i) => i['id'] == docId);
        await LocalGuestStorage.saveShoppingList(_guestShopping);
        _loadGuestShopping();
      } else {
        await FirebaseFirestore.instance
            .collection('couples')
            .doc(widget.coupleId)
            .collection('shopping_list')
            .doc(docId)
            .delete();
      }
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _toggleItem(String id, bool currentValue, String name) async {
    if (!currentValue) {
      _preguntarConvertirAGasto(id, name);
    } else {
      if (widget.mode == NidoUsageMode.guest) {
        final idx = _guestShopping.indexWhere((i) => i['id'] == id);
        if (idx != -1) {
          _guestShopping[idx]['isBought'] = false;
          await LocalGuestStorage.saveShoppingList(_guestShopping);
          _loadGuestShopping();
        }
      } else {
        await FirebaseFirestore.instance
            .collection('couples')
            .doc(widget.coupleId)
            .collection('shopping_list')
            .doc(id)
            .update({'isBought': false});
      }
    }
  }

  void _preguntarConvertirAGasto(String itemId, String name) {
    final amountController = TextEditingController();
    final surface = context.nidoSurface;
    final textDark = context.nidoTextDark;
    final textMuted = context.nidoTextMuted;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: surface,
        title: Text(
          '¿Compraste "$name"?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textDark,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ingresa el monto para registrarlo automáticamente en gastos.',
              style: TextStyle(fontSize: 13, color: textMuted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsSeparatorInputFormatter()],
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Monto \$',
                prefixIcon: Icon(
                  Icons.attach_money,
                  size: 20,
                  color: textMuted,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (widget.mode == NidoUsageMode.guest) {
                final idx = _guestShopping.indexWhere((i) => i['id'] == itemId);
                if (idx != -1) {
                  _guestShopping[idx]['isBought'] = true;
                  await LocalGuestStorage.saveShoppingList(_guestShopping);
                  _loadGuestShopping();
                }
              } else {
                await FirebaseFirestore.instance
                    .collection('couples')
                    .doc(widget.coupleId)
                    .collection('shopping_list')
                    .doc(itemId)
                    .update({'isBought': true});
              }
              if (ctx.mounted) Navigator.pop(ctx);
              amountController.dispose();
            },
            child: Text(
              'Solo marcar comprado',
              style: TextStyle(color: textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = parseFormattedAmount(amountController.text);
              if (val > 0) {
                if (widget.mode == NidoUsageMode.guest) {
                  final expList = await LocalGuestStorage.getExpenses();
                  expList.add(
                    Expense(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      amount: val,
                      description: 'Supermercado: $name',
                      category: 'Supermercado',
                      createdBy: 'Invitado',
                      date: DateTime.now(),
                      type: 'expense',
                    ).toJson(),
                  );
                  await LocalGuestStorage.saveExpenses(expList);

                  _guestShopping.removeWhere((i) => i['id'] == itemId);
                  await LocalGuestStorage.saveShoppingList(_guestShopping);
                  _loadGuestShopping();
                } else {
                  final batch = FirebaseFirestore.instance.batch();
                  final expenseRef = FirebaseFirestore.instance
                      .collection('couples')
                      .doc(widget.coupleId)
                      .collection('expenses')
                      .doc();
                  batch.set(expenseRef, {
                    'amount': val,
                    'description': 'Supermercado: $name',
                    'category': 'Supermercado',
                    'createdBy': widget.userId,
                    'date': Timestamp.now(),
                    'type': 'expense',
                  });
                  final itemRef = FirebaseFirestore.instance
                      .collection('couples')
                      .doc(widget.coupleId)
                      .collection('shopping_list')
                      .doc(itemId);
                  batch.delete(itemRef);
                  await batch.commit();
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
            child: const Text('Registrar Gasto'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textMuted = context.nidoTextMuted;

    return Scaffold(
      appBar: AppBar(title: const Text('Lista de Compras')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _itemController,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _addItem(),
                    decoration: InputDecoration(
                      labelText: 'Añadir artículo…',
                      prefixIcon: Icon(
                        Icons.add_shopping_cart_outlined,
                        size: 20,
                        color: textMuted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isAdding ? null : _addItem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kSecondaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size(52, 52),
                  ),
                  child: _isAdding
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.add),
                ),
              ],
            ),
          ),

          Expanded(
            child: widget.mode == NidoUsageMode.guest
                ? _buildShoppingListUI(
                    _guestShopping
                        .map(
                          (data) => _ShoppingItemWrapper(
                            id: (data['id'] as String?) ?? '',
                            name: (data['name'] as String?) ?? 'Artículo',
                            isBought: (data['isBought'] as bool?) ?? false,
                          ),
                        )
                        .toList(),
                  )
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('couples')
                        .doc(widget.coupleId)
                        .collection('shopping_list')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: kPrimaryColor,
                          ),
                        );
                      }

                      final docs = snapshot.data?.docs ?? [];
                      final items = docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return _ShoppingItemWrapper(
                          id: doc.id,
                          name:
                              (data['name'] as String?) ??
                              (data['title'] as String?) ??
                              'Artículo',
                          isBought: (data['isBought'] as bool?) ?? false,
                        );
                      }).toList();

                      return _buildShoppingListUI(items);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildShoppingListUI(List<_ShoppingItemWrapper> items) {
    final bg = context.nidoBg;
    final surface = context.nidoSurface;
    final border = context.nidoBorder;
    final textDark = context.nidoTextDark;
    final textMuted = context.nidoTextMuted;

    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.shopping_cart_outlined,
        title: 'Lista vacía',
        subtitle: 'Añade los artículos que necesitan comprar.',
      );
    }

    return ListView.builder(
      itemCount: items.length,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8.0),
          decoration: BoxDecoration(
            color: item.isBought ? bg : surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: item.isBought
                  ? border.withValues(alpha: 0.5)
                  : border,
              width: 1.0,
            ),
          ),
          child: ListTile(
            title: Text(
              item.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                decoration: item.isBought ? TextDecoration.lineThrough : null,
                color: item.isBought ? textMuted : textDark,
              ),
            ),
            leading: Checkbox(
              value: item.isBought,
              activeColor: kSecondaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              onChanged: (_) => _toggleItem(item.id, item.isBought, item.name),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: textMuted,
                  ),
                  onPressed: () => _editarItem(item.id, item.name),
                  tooltip: 'Modificar',
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: kDangerColor,
                  ),
                  onPressed: () => _eliminarItem(item.id, item.name),
                  tooltip: 'Eliminar',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ShoppingItemWrapper {
  final String id;
  final String name;
  final bool isBought;

  _ShoppingItemWrapper({
    required this.id,
    required this.name,
    required this.isBought,
  });
}
