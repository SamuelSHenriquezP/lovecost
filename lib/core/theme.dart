import 'package:flutter/material.dart';

// ==========================================
// SISTEMA DE DISEÑO — PALETA DE COLORES VIVOS
// ==========================================
const Color kBackgroundColor = Color(0xFFF6F4F0);
const Color kPrimaryColor = Color(0xFF0D9488); // Teal sobrio y elegante
const Color kSecondaryColor = Color(0xFF00897B); // Verde esmeralda vivo
const Color kAccentColor = Color(0xFF6366F1); // Índigo elegante (cero naranja)
const Color kSurfaceColor = Color(0xFFFFFFFF);
const Color kTextDark = Color(0xFF1E1917);
const Color kTextMuted = Color(0xFF6B6361);
const Color kBorderColor = Color(0xFFE2DDD7);
const Color kDangerColor = Color(0xFFE53935); // Rojo vivo

const Color kExpenseColor = Color(0xFFE53935); // ROJO VIVO para gastos
const Color kIncomeColor = Color(0xFF10B981); // VERDE VIVO para ingresos
const Color kDisponibleColor = Color(
  0xFF334155,
); // Slate sobrio y elegante para Disponible Real

// Dark palette constants
const Color kDarkBackground = Color(0xFF0F172A);
const Color kDarkSurface = Color(0xFF1E293B);
const Color kDarkBorder = Color(0xFF334155);
const Color kDarkTextDark = Color(0xFFF1F5F9);
const Color kDarkTextMuted = Color(0xFF94A3B8);

// Dark mode notifier
final ValueNotifier<ThemeMode> nidoThemeMode = ValueNotifier(ThemeMode.light);

// ==========================================
// EXTENSIÓN DE CONTEXTO — COLORES ADAPTATIVOS
// ==========================================
extension NidoTheme on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get nidoBg => isDark ? kDarkBackground : kBackgroundColor;
  Color get nidoSurface => isDark ? kDarkSurface : kSurfaceColor;
  Color get nidoBorder => isDark ? kDarkBorder : kBorderColor;
  Color get nidoTextDark => isDark ? kDarkTextDark : kTextDark;
  Color get nidoTextMuted => isDark ? kDarkTextMuted : kTextMuted;
}

