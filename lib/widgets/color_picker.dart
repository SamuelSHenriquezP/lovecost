import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';

// ==========================================
// SELECTOR DE COLOR COMPLETO (ESTILO DISEÑO)
// ==========================================
class NidoColorPicker extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onColorChanged;

  const NidoColorPicker({
    super.key,
    required this.initialColor,
    required this.onColorChanged,
  });

  @override
  State<NidoColorPicker> createState() => _NidoColorPickerState();
}

class _NidoColorPickerState extends State<NidoColorPicker> {
  late double _hue; // 0 a 360
  late double _saturation; // 0 a 1
  late double _value; // 0 a 1
  late TextEditingController _hexController;

  static const List<Color> presetColors = [
    Color(0xFF0D9488), // Teal
    Color(0xFF00897B), // Esmeralda
    Color(0xFF2563EB), // Azul Eléctrico
    Color(0xFF6366F1), // Índigo
    Color(0xFF9333EA), // Violeta
    Color(0xFFDB2777), // Rosa Fucsia
    Color(0xFF059669), // Verde Jade
    Color(0xFFE53935), // Rojo Coral
    Color(0xFFF59E0B), // Ámbar / Oro
    Color(0xFFEA580C), // Naranja Intenso
    Color(0xFF0284C7), // Azul Cielo
    Color(0xFF334155), // Slate / Pizarra
  ];

  @override
  void initState() {
    super.initState();
    final hsv = HSVColor.fromColor(widget.initialColor);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = hsv.value;
    _hexController = TextEditingController(text: _colorToHex(widget.initialColor));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  Color get _currentColor {
    return HSVColor.fromAHSV(1.0, _hue, _saturation, _value).toColor();
  }

  String _colorToHex(Color color) {
    final argb = color.toARGB32();
    return (argb & 0x00FFFFFF).toRadixString(16).toUpperCase().padLeft(6, '0');
  }

  void _setColorFromColor(Color c) {
    final hsv = HSVColor.fromColor(c);
    setState(() {
      _hue = hsv.hue;
      _saturation = hsv.saturation;
      _value = hsv.value;
      _hexController.text = _colorToHex(c);
    });
    widget.onColorChanged(_currentColor);
  }

  void _updateFromHex(String text) {
    final clean = text.replaceAll('#', '').trim();
    if (clean.length == 6) {
      final intVal = int.tryParse(clean, radix: 16);
      if (intVal != null) {
        final c = Color(0xFF000000 | intVal);
        final hsv = HSVColor.fromColor(c);
        setState(() {
          _hue = hsv.hue;
          _saturation = hsv.saturation;
          _value = hsv.value;
        });
        widget.onColorChanged(_currentColor);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentColor;
    final bg = context.nidoBg;
    final border = context.nidoBorder;
    final textDark = context.nidoTextDark;
    final textMuted = context.nidoTextMuted;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tarjeta de Vista Previa con Código HEX y Muestra
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              // Muestra circular con sombra del color
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: current,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: current.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Color Seleccionado',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '#',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: textMuted,
                          ),
                        ),
                        SizedBox(
                          width: 85,
                          height: 30,
                          child: TextField(
                            controller: _hexController,
                            maxLength: 6,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: textDark,
                              letterSpacing: 1.0,
                            ),
                            decoration: const InputDecoration(
                              counterText: '',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 6,
                              ),
                              border: OutlineInputBorder(),
                            ),
                            onChanged: _updateFromHex,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 1. SLIDER DE MATIZ (HUE - ARCOÍRIS)
        Row(
          children: [
            Text('Tono (Matiz):', style: TextStyle(fontSize: 11, color: textMuted, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('${_hue.round()}°', style: TextStyle(fontSize: 11, color: textMuted)),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 28,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [
                Color(0xFFFF0000),
                Color(0xFFFFFF00),
                Color(0xFF00FF00),
                Color(0xFF00FFFF),
                Color(0xFF0000FF),
                Color(0xFFFF00FF),
                Color(0xFFFF0000),
              ],
            ),
            border: Border.all(color: border),
          ),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 0,
              thumbColor: Colors.white,
              overlayColor: Colors.white.withValues(alpha: 0.2),
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 11,
                elevation: 3,
              ),
            ),
            child: Slider(
              value: _hue,
              min: 0.0,
              max: 360.0,
              onChanged: (val) {
                setState(() {
                  _hue = val;
                  _hexController.text = _colorToHex(_currentColor);
                });
                widget.onColorChanged(_currentColor);
              },
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 2. SLIDER DE SATURACIÓN
        Row(
          children: [
            Text('Saturación:', style: TextStyle(fontSize: 11, color: textMuted, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('${(_saturation * 100).round()}%', style: TextStyle(fontSize: 11, color: textMuted)),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 28,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: [
                HSVColor.fromAHSV(1.0, _hue, 0.0, _value).toColor(),
                HSVColor.fromAHSV(1.0, _hue, 1.0, _value).toColor(),
              ],
            ),
            border: Border.all(color: border),
          ),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 0,
              thumbColor: Colors.white,
              overlayColor: Colors.white.withValues(alpha: 0.2),
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 11,
                elevation: 3,
              ),
            ),
            child: Slider(
              value: _saturation,
              min: 0.0,
              max: 1.0,
              onChanged: (val) {
                setState(() {
                  _saturation = val;
                  _hexController.text = _colorToHex(_currentColor);
                });
                widget.onColorChanged(_currentColor);
              },
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 3. SLIDER DE BRILLO / INTENSIDAD
        Row(
          children: [
            Text('Brillo:', style: TextStyle(fontSize: 11, color: textMuted, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('${(_value * 100).round()}%', style: TextStyle(fontSize: 11, color: textMuted)),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 28,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: [
                Colors.black,
                HSVColor.fromAHSV(1.0, _hue, _saturation, 1.0).toColor(),
              ],
            ),
            border: Border.all(color: border),
          ),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 0,
              thumbColor: Colors.white,
              overlayColor: Colors.white.withValues(alpha: 0.2),
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 11,
                elevation: 3,
              ),
            ),
            child: Slider(
              value: _value,
              min: 0.1,
              max: 1.0,
              onChanged: (val) {
                setState(() {
                  _value = val;
                  _hexController.text = _colorToHex(_currentColor);
                });
                widget.onColorChanged(_currentColor);
              },
            ),
          ),
        ),
        const SizedBox(height: 14),

        // 4. PALETA DE COLORES PREDEFINIDOS (RÁPIDOS)
        Text(
          'Paleta rápida:',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: textDark,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: presetColors.map((c) {
            final isSelected =
                (c.toARGB32() & 0x00FFFFFF) == (current.toARGB32() & 0x00FFFFFF);
            return GestureDetector(
              onTap: () {
                _setColorFromColor(c);
                HapticFeedback.selectionClick();
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.white : border,
                    width: isSelected ? 2.8 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: c.withValues(alpha: 0.6),
                            blurRadius: 8,
                            spreadRadius: 1.5,
                          ),
                        ]
                      : null,
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

