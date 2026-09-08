import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../main.dart';

// ==========================================
// PUNTO DE DATOS PARA LA GRÁFICA
// ==========================================
class ChartPoint {
  final DateTime date;
  final double value;
  final double income;
  final double expense;

  const ChartPoint({
    required this.date,
    required this.value,
    this.income = 0.0,
    this.expense = 0.0,
  });
}

// ==========================================
// GRÁFICA ESTILO MERCADO DE ACCIONES
// ==========================================
class StockLineChart extends StatefulWidget {
  final List<ChartPoint> points;
  final double height;
  final String title;
  final String Function(double) currencyFormatter;
  final Color? positiveColor;
  final Color? negativeColor;
  final Widget? belowHeader;

  const StockLineChart({
    super.key,
    required this.points,
    this.height = 240,
    this.title = 'Balance',
    required this.currencyFormatter,
    this.positiveColor,
    this.negativeColor,
    this.belowHeader,
  });

  @override
  State<StockLineChart> createState() => _StockLineChartState();
}

class _StockLineChartState extends State<StockLineChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _animation;
  int? _selectedIndex;
  int? _lastHapticIndex;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _animation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void didUpdateWidget(covariant StockLineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points) {
      _selectedIndex = null;
      _lastHapticIndex = null;
      _animController.reset();
      _animController.forward();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleTouch(Offset localPosition, double width) {
    if (widget.points.isEmpty || width <= 0) return;

    final count = widget.points.length;
    if (count == 1) {
      if (_selectedIndex != 0) {
        setState(() => _selectedIndex = 0);
        HapticFeedback.selectionClick();
      }
      return;
    }

    final ratio = (localPosition.dx / width).clamp(0.0, 1.0);
    final index = (ratio * (count - 1)).round().clamp(0, count - 1);

    if (index != _selectedIndex) {
      setState(() => _selectedIndex = index);
      if (index != _lastHapticIndex) {
        _lastHapticIndex = index;
        HapticFeedback.selectionClick();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textDark = context.nidoTextDark;
    final textMuted = context.nidoTextMuted;
    final border = context.nidoBorder;

    final posColor = widget.positiveColor ?? const Color(0xFF10B981);
    final negColor = widget.negativeColor ?? const Color(0xFFEF4444);

    if (widget.points.isEmpty) {
      return Container(
        height: widget.height,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart_rounded, size: 40, color: border),
            const SizedBox(height: 8),
            Text(
              'Sin datos para graficar en este periodo',
              style: TextStyle(color: textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    // Determinar tendencia general del periodo
    final firstPoint = widget.points.first;
    final lastPoint = widget.points.last;
    final overallDelta = lastPoint.value - firstPoint.value;
    final isOverallPositive = overallDelta >= 0;
    final trendColor = isOverallPositive ? posColor : negColor;

    // Punto activo seleccionado o el último punto por defecto
    final activePoint = _selectedIndex != null
        ? widget.points[_selectedIndex!]
        : lastPoint;
    final isScrubbing = _selectedIndex != null;

    final deltaFromStart = activePoint.value - firstPoint.value;

    final dateFormatter = DateFormat('EEEE, d MMM y', 'es');
    final activeDateStr = dateFormatter.format(activePoint.date);
    final formattedDate = activeDateStr.isNotEmpty
        ? activeDateStr[0].toUpperCase() + activeDateStr.substring(1)
        : activeDateStr;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabecera interactiva del gráfico
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isScrubbing ? 'Balance en fecha' : widget.title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textMuted,
                        ),
                      ),
                      if (isScrubbing) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: trendColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Explorando',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: trendColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.currencyFormatter(activePoint.value),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: activePoint.value < 0 ? negColor : textDark,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // Indicador de variación en el periodo
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: (deltaFromStart >= 0 ? posColor : negColor)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (deltaFromStart >= 0 ? posColor : negColor)
                       .withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    deltaFromStart >= 0
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    size: 14,
                    color: deltaFromStart >= 0 ? posColor : negColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${deltaFromStart >= 0 ? '+' : ''}${widget.currencyFormatter(deltaFromStart)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: deltaFromStart >= 0 ? posColor : negColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (widget.belowHeader != null) ...[
          const SizedBox(height: 16),
          widget.belowHeader!,
        ],
        const SizedBox(height: 14),

        // Lienzo táctil del gráfico de acciones
        LayoutBuilder(
          builder: (context, constraints) {
            final chartWidth = constraints.maxWidth;
            const chartHeight = 150.0;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (details) =>
                  _handleTouch(details.localPosition, chartWidth),
              onHorizontalDragUpdate: (details) =>
                  _handleTouch(details.localPosition, chartWidth),
              onHorizontalDragEnd: (_) {},
              onTapDown: (details) =>
                  _handleTouch(details.localPosition, chartWidth),
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, _) {
                  return CustomPaint(
                    size: Size(chartWidth, chartHeight),
                    painter: _StockLinePainter(
                      points: widget.points,
                      selectedIndex: _selectedIndex,
                      trendColor: trendColor,
                      progress: _animation.value,
                      gridColor: border.withValues(alpha: 0.6),
                    ),
                  );
                },
              ),
            );
          },
        ),
        const SizedBox(height: 8),

        // Eje X: Etiquetas de fechas equidistantes
        _buildDateLabels(context, textMuted),
      ],
    );
  }

  Widget _buildDateLabels(BuildContext context, Color textColor) {
    if (widget.points.length < 2) return const SizedBox.shrink();

    final count = widget.points.length;
    final indicesToShow = <int>[];
    if (count <= 4) {
      indicesToShow.addAll(List.generate(count, (i) => i));
    } else {
      indicesToShow.add(0);
      indicesToShow.add((count * 0.33).round());
      indicesToShow.add((count * 0.66).round());
      indicesToShow.add(count - 1);
    }

    final format = DateFormat('d MMM', 'es');

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: indicesToShow.map((idx) {
        final pt = widget.points[idx];
        final isSelected = _selectedIndex == idx;
        return Text(
          format.format(pt.date),
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? kPrimaryColor : textColor,
          ),
        );
      }).toList(),
    );
  }
}

// ==========================================
// PAINTER: CURVA BÉZIER Y GRADIENTE DE BOLSA
// ==========================================
class _StockLinePainter extends CustomPainter {
  final List<ChartPoint> points;
  final int? selectedIndex;
  final Color trendColor;
  final double progress;
  final Color gridColor;

  _StockLinePainter({
    required this.points,
    required this.selectedIndex,
    required this.trendColor,
    required this.progress,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final count = points.length;
    final w = size.width;
    final h = size.height;

    double minY = points.first.value;
    double maxY = points.first.value;
    for (final p in points) {
      if (p.value < minY) minY = p.value;
      if (p.value > maxY) maxY = p.value;
    }

    double range = maxY - minY;
    if (range <= 0) range = 1.0;
    final paddedMin = minY - range * 0.15;
    final paddedMax = maxY + range * 0.15;
    final paddedRange = paddedMax - paddedMin;

    double toScreenX(int i) => count > 1 ? (i / (count - 1)) * w : w / 2;
    double toScreenY(double val) =>
        h - ((val - paddedMin) / paddedRange) * h;

    // 1. Líneas de cuadrícula horizontales punteadas
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    for (final frac in [0.2, 0.5, 0.8]) {
      final y = h * frac;
      _drawDashedHorizontalLine(canvas, 0, w, y, gridPaint);
    }

    // 2. Mapear coordenadas de los puntos
    final offsets = <Offset>[];
    for (int i = 0; i < count; i++) {
      offsets.add(Offset(toScreenX(i), toScreenY(points[i].value)));
    }

    if (count == 1) {
      final center = offsets.first;
      final dotPaint = Paint()..color = trendColor;
      canvas.drawCircle(center, 5, dotPaint);
      return;
    }

    // 3. Crear curva suave cúbica continua (Cubic Bézier)
    final linePath = Path();
    linePath.moveTo(offsets[0].dx, offsets[0].dy);

    for (int i = 0; i < count - 1; i++) {
      final curr = offsets[i];
      final next = offsets[i + 1];

      final controlX1 = curr.dx + (next.dx - curr.dx) / 2;
      final controlY1 = curr.dy;
      final controlX2 = curr.dx + (next.dx - curr.dx) / 2;
      final controlY2 = next.dy;

      linePath.cubicTo(controlX1, controlY1, controlX2, controlY2, next.dx, next.dy);
    }

    // Aplicar animación de entrada proporcional al ancho
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, w * progress, h + 20));

    // 4. Relleno con gradiente bajo la curva (Area chart)
    final fillPath = Path.from(linePath);
    fillPath.lineTo(offsets.last.dx, h);
    fillPath.lineTo(offsets.first.dx, h);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          trendColor.withValues(alpha: 0.32),
          trendColor.withValues(alpha: 0.08),
          trendColor.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.65, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(fillPath, fillPaint);

    // 5. Línea de cotización principal
    final strokePaint = Paint()
      ..color = trendColor
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(linePath, strokePaint);
    canvas.restore();

    // 6. Interacción táctil (Scrubber con cursor y punto luminoso)
    if (selectedIndex != null && selectedIndex! < count) {
      final selectedOffset = offsets[selectedIndex!];

      final cursorPaint = Paint()
        ..color = trendColor.withValues(alpha: 0.6)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      _drawDashedVerticalLine(canvas, selectedOffset.dx, 0, h, cursorPaint);

      // Halo brillante exterior
      final glowPaint = Paint()
        ..color = trendColor.withValues(alpha: 0.28)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(selectedOffset, 9, glowPaint);

      // Borde blanco exterior
      final ringPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(selectedOffset, 5.5, ringPaint);

      // Punto central del color de tendencia
      final centerPaint = Paint()
        ..color = trendColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(selectedOffset, 3.5, centerPaint);
    } else {
      final lastOffset = offsets.last;
      final glowPaint = Paint()
        ..color = trendColor.withValues(alpha: 0.22)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(lastOffset, 6.5, glowPaint);

      final dotPaint = Paint()
        ..color = trendColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(lastOffset, 3.5, dotPaint);
    }
  }

  void _drawDashedHorizontalLine(
    Canvas canvas,
    double xStart,
    double xEnd,
    double y,
    Paint paint,
  ) {
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    double currentX = xStart;
    while (currentX < xEnd) {
      canvas.drawLine(
        Offset(currentX, y),
        Offset(math.min(currentX + dashWidth, xEnd), y),
        paint,
      );
      currentX += dashWidth + dashSpace;
    }
  }

  void _drawDashedVerticalLine(
    Canvas canvas,
    double x,
    double yStart,
    double yEnd,
    Paint paint,
  ) {
    const dashHeight = 4.0;
    const dashSpace = 3.5;
    double currentY = yStart;
    while (currentY < yEnd) {
      canvas.drawLine(
        Offset(x, currentY),
        Offset(x, math.min(currentY + dashHeight, yEnd)),
        paint,
      );
      currentY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _StockLinePainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.progress != progress ||
        oldDelegate.points != points ||
        oldDelegate.trendColor != trendColor;
  }
}

