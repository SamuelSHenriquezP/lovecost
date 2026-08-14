import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';

Future<void> showProfileModal(
  BuildContext context,
  String userId,
  String coupleId,
  String userName,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ProfileBottomSheet(
      userId: userId,
      coupleId: coupleId,
      currentUserName: userName,
    ),
  );
}

void showSendPingModalGlobal(
  BuildContext context,
  String coupleId,
  String userName,
) {
  final pings = [
    '❤️ Te quiero mucho',
    '☕ ¿Un cafecito juntos?',
    '🥰 Te extraño mi amor',
    '🍕 ¿Qué cenamos hoy?',
    '✈️ Pensando en nuestras vacaciones',
    '🤗 Un abrazo apretado',
    '🥂 ¡Salud por nuestro nido!',
    '🌹 Gracias por estar a mi lado',
  ];

  final customPingController = TextEditingController();
  final surface = context.nidoSurface;
  final bg = context.nidoBg;
  final border = context.nidoBorder;
  final textDark = context.nidoTextDark;
  final textMuted = context.nidoTextMuted;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    backgroundColor: surface,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.favorite, color: kPrimaryColor, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Enviar Guiño de Amor 💕',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textDark,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, size: 20, color: textMuted),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Selecciona un mensaje rápido o escribe tu guiño personalizado:',
              style: TextStyle(color: textMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: pings
                  .map(
                    (p) => ActionChip(
                      avatar: const Icon(
                        Icons.favorite_rounded,
                        size: 14,
                        color: kPrimaryColor,
                      ),
                      label: Text(
                        p,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                          color: textDark,
                        ),
                      ),
                      backgroundColor: bg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: border),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await FirebaseFirestore.instance
                            .collection('couples')
                            .doc(coupleId)
                            .collection('pings')
                            .add({
                              'message': p,
                              'createdBy': userName,
                              'date': Timestamp.now(),
                            });
                        HapticFeedback.mediumImpact();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✨ Guiño enviado: $p'),
                              backgroundColor: kSecondaryColor,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              margin: const EdgeInsets.all(16),
                            ),
                          );
                        }
                      },
                    ),
                  )
                  .toList(),
            ),

            const SizedBox(height: 16),
            Divider(color: border),
            const SizedBox(height: 12),

            Text(
              '✍️ Escribir guiño personalizado:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: customPingController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Ej: ¡Te amo mucho! Pasa un hermoso día 💕',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final text = customPingController.text.trim();
                    if (text.isEmpty) return;

                    Navigator.pop(ctx);
                    await FirebaseFirestore.instance
                        .collection('couples')
                        .doc(coupleId)
                        .collection('pings')
                        .add({
                          'message': text,
                          'createdBy': userName,
                          'date': Timestamp.now(),
                        });
                    HapticFeedback.mediumImpact();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✨ Guiño enviado: $text'),
                          backgroundColor: kSecondaryColor,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          margin: const EdgeInsets.all(16),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Icon(Icons.send_rounded, size: 18),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class ProfileBottomSheet extends StatefulWidget {
  final String userId;
  final String coupleId;
  final String currentUserName;

  const ProfileBottomSheet({
    super.key,
    required this.userId,
    required this.coupleId,
    required this.currentUserName,
  });

  @override
  State<ProfileBottomSheet> createState() => _ProfileBottomSheetState();
}

class _ProfileBottomSheetState extends State<ProfileBottomSheet> {
  late TextEditingController _aliasController;
  late TextEditingController _birthdayController;
  late TextEditingController _noteController;
  String _selectedEmoji = '🦊';
  String? _localPhotoPath;
  bool _isSaving = false;
  bool _loaded = false;

  final List<String> _emojis = [
    '🦊', '🐱', '🐰', '🐼', '🐻', '🦁', '🐨', '🦄',
    '🐯', '🐸', '🐣', '🌸', '💖', '👑', '⭐', '🍀',
  ];

  @override
  void initState() {
    super.initState();
    _aliasController = TextEditingController();
    _birthdayController = TextEditingController();
    _noteController = TextEditingController();
    _loadData();
  }

  Future<void> _loadData() async {
    final photo = await LocalProfilePhoto.getPhotoPath();
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();

    if (doc.exists && mounted) {
      final data = doc.data()!;
      setState(() {
        _selectedEmoji = (data['avatarEmoji'] as String?) ?? '🦊';
        _aliasController.text = (data['alias'] as String?) ?? '';
        _birthdayController.text = (data['birthday'] as String?) ?? '';
        _noteController.text = (data['statusNote'] as String?) ?? '';
        _localPhotoPath = photo;
        _loaded = true;
      });
    } else if (mounted) {
      setState(() {
        _localPhotoPath = photo;
        _loaded = true;
      });
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .set({
        'avatarEmoji': _selectedEmoji,
        'alias': _aliasController.text.trim(),
        'birthday': _birthdayController.text.trim(),
        'statusNote': _noteController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      HapticFeedback.lightImpact();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al guardar perfil'),
            backgroundColor: kDangerColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _aliasController.dispose();
    _birthdayController.dispose();
    _noteController.dispose();
    super.dispose();
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
      child: !_loaded
          ? const SizedBox(
              height: 200,
              child: Center(
                child: CircularProgressIndicator(color: kPrimaryColor),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        color: kPrimaryColor,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Perfil de ${widget.currentUserName}',
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

                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: kPrimaryColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: kPrimaryColor.withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          alignment: Alignment.center,
                          child: _localPhotoPath != null
                              ? Image.file(
                                  File(_localPhotoPath!),
                                  fit: BoxFit.cover,
                                  width: 84,
                                  height: 84,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Text(
                                        _selectedEmoji,
                                        style: const TextStyle(fontSize: 42),
                                      ),
                                )
                              : Text(
                                  _selectedEmoji,
                                  style: const TextStyle(fontSize: 42),
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.center,
                    child: Text(
                      'Toca la foto o elige un avatar emoji arriba 👆',
                      style: TextStyle(fontSize: 11, color: textMuted),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'Elige tu Avatar Emoji:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 48,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _emojis.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final emoji = _emojis[index];
                        final isSelected = emoji == _selectedEmoji;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedEmoji = emoji);
                            HapticFeedback.selectionClick();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? kPrimaryColor.withValues(alpha: 0.2)
                                  : bg,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? kPrimaryColor
                                    : border,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  TextField(
                    controller: _aliasController,
                    decoration: InputDecoration(
                      labelText: 'Apodo cariñoso 💕 (Opcional)',
                      hintText: 'Ej: Mi amor, Osito, Reina...',
                      prefixIcon: Icon(
                        Icons.favorite_outline,
                        size: 20,
                        color: textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _birthdayController,
                    decoration: InputDecoration(
                      labelText: 'Cumpleaños 🎂 (Opcional)',
                      hintText: 'Ej: 14 de Febrero',
                      prefixIcon: Icon(
                        Icons.cake_outlined,
                        size: 20,
                        color: textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _noteController,
                    maxLength: 60,
                    decoration: InputDecoration(
                      labelText: 'Estado o Nota de Amor 💬 (Opcional)',
                      hintText: 'Ej: ¡Pensando en nuestras vacaciones! 🌴',
                      prefixIcon: Icon(
                        Icons.chat_bubble_outline,
                        size: 20,
                        color: textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        foregroundColor: Colors.white,
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
                          : const Text(
                              'Guardar Perfil',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class PartnerHeaderCard extends StatefulWidget {
  final String coupleId;
  final String userId;
  final String userName;
  final String inviteCode;
  final NidoUsageMode mode;

  const PartnerHeaderCard({
    super.key,
    required this.coupleId,
    required this.userId,
    required this.userName,
    required this.inviteCode,
    required this.mode,
  });

  @override
  State<PartnerHeaderCard> createState() => _PartnerHeaderCardState();
}

class _PartnerHeaderCardState extends State<PartnerHeaderCard> {
  String? _localPhotoPath;

  @override
  void initState() {
    super.initState();
    _loadLocalPhoto();
  }

  Future<void> _loadLocalPhoto() async {
    final path = await LocalProfilePhoto.getPhotoPath();
    if (mounted) setState(() => _localPhotoPath = path);
  }

  @override
  Widget build(BuildContext context) {
    final surface = context.nidoSurface;
    final bg = context.nidoBg;
    final border = context.nidoBorder;
    final textDark = context.nidoTextDark;
    final textMuted = context.nidoTextMuted;

    if (widget.mode == NidoUsageMode.guest) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border, width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: kSecondaryColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_pin_outlined,
                color: kSecondaryColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Modo Invitado (Local, sin guardado en la nube)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tus datos se guardan únicamente en tu dispositivo 📱',
                    style: TextStyle(fontSize: 11, color: textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (widget.mode == NidoUsageMode.individual) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border, width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: kSecondaryColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_rounded,
                color: kSecondaryColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Finanzas de ${widget.userName} 👤',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Modo Personal en la Nube ☁️',
                    style: TextStyle(fontSize: 11, color: textMuted),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.person_outline,
                color: textMuted,
                size: 22,
              ),
              tooltip: 'Mi Perfil',
              onPressed: () => showProfileModal(
                context,
                widget.userId,
                widget.coupleId,
                widget.userName,
              ),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('coupleId', isEqualTo: widget.coupleId)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final myDoc = docs.where((d) => d.id == widget.userId).firstOrNull;
        final partnerDoc = docs.where((d) => d.id != widget.userId).firstOrNull;

        final myData = myDoc?.data() as Map<String, dynamic>?;
        final partnerData = partnerDoc?.data() as Map<String, dynamic>?;

        final myEmoji = (myData?['avatarEmoji'] as String?) ?? '🦊';
        final partnerName = (partnerData?['name'] as String?);
        final partnerEmoji = (partnerData?['avatarEmoji'] as String?) ?? '🌸';
        final partnerNote = (partnerData?['statusNote'] as String?);

        final bool isPaired = partnerName != null && partnerName.isNotEmpty;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              SizedBox(
                width: 62,
                height: 42,
                child: Stack(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        await showProfileModal(
                          context,
                          widget.userId,
                          widget.coupleId,
                          widget.userName,
                        );
                        _loadLocalPhoto();
                      },
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: kPrimaryColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        clipBehavior: Clip.antiAlias,
                        alignment: Alignment.center,
                        child: _localPhotoPath != null
                            ? Image.file(
                                File(_localPhotoPath!),
                                fit: BoxFit.cover,
                                width: 38,
                                height: 38,
                                errorBuilder: (context, error, stackTrace) =>
                                    Text(
                                      myEmoji,
                                      style: const TextStyle(fontSize: 20),
                                    ),
                              )
                            : Text(
                                myEmoji,
                                style: const TextStyle(fontSize: 20),
                              ),
                      ),
                    ),
                    Positioned(
                      left: 22,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isPaired
                              ? kSecondaryColor.withValues(alpha: 0.18)
                              : bg,
                          shape: BoxShape.circle,
                          border: Border.all(color: surface, width: 2),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          isPaired ? partnerEmoji : '❓',
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            isPaired
                                ? '${widget.userName} & $partnerName'
                                : 'Tú & Tu Pareja',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: textDark,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isPaired
                                ? Colors.green.shade600
                                : Colors.amber.shade600,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isPaired
                          ? (partnerNote != null && partnerNote.isNotEmpty
                                ? partnerNote
                                : 'Conectados en Nido 💚')
                          : 'Esperando que tu pareja se una…',
                      style: TextStyle(
                        fontSize: 11,
                        color: isPaired ? textMuted : Colors.amber.shade800,
                        fontWeight: isPaired
                            ? FontWeight.w500
                            : FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.favorite_rounded,
                  color: kPrimaryColor,
                  size: 22,
                ),
                tooltip: 'Enviar Guiño 💕',
                onPressed: () => showSendPingModalGlobal(
                  context,
                  widget.coupleId,
                  widget.userName,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.person_outline,
                  color: textMuted,
                  size: 22,
                ),
                tooltip: 'Mi Perfil 👤',
                onPressed: () async {
                  await showProfileModal(
                    context,
                    widget.userId,
                    widget.coupleId,
                    widget.userName,
                  );
                  _loadLocalPhoto();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
