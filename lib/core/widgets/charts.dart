import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:media_crm/core/analytics/analytics_calculator.dart';
import 'package:media_crm/core/theme/app_theme.dart';
import 'package:media_crm/core/utils/formatters.dart';

class ChartSeries {
  const ChartSeries({
    required this.label,
    required this.color,
    required this.points,
    this.filled = false,
  });

  final String label;
  final Color color;
  final List<MetricPoint> points;
  final bool filled;
}

class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key, required this.items, this.compact = false});

  final List<({String label, Color color})> items;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Wrap(
      spacing: compact ? 10 : 16,
      runSpacing: 6,
      children: [
        for (final item in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: compact ? 7 : 8,
                height: compact ? 7 : 8,
                decoration: BoxDecoration(
                  color: item.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                item.label,
                style: TextStyle(
                  color: colors.muted,
                  fontSize: compact ? 10.5 : 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Multi-series line/area chart with hover tooltip. Deliberately built with a
/// CustomPainter so it works on every platform without any native dependency.
class TimeSeriesChart extends StatefulWidget {
  const TimeSeriesChart({
    super.key,
    required this.series,
    this.height = 230,
    this.valueFormatter,
    this.showLegend = true,
    this.showArea = true,
    this.emptyLabel = 'Нет данных за выбранный период',
  });

  final List<ChartSeries> series;
  final double height;
  final String Function(double)? valueFormatter;
  final bool showLegend;
  final bool showArea;
  final String emptyLabel;

  @override
  State<TimeSeriesChart> createState() => _TimeSeriesChartState();
}

class _TimeSeriesChartState extends State<TimeSeriesChart> {
  int? _hoverIndex;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final series = widget.series
        .where((s) => s.points.isNotEmpty)
        .toList(growable: false);
    if (series.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Text(
            widget.emptyLabel,
            style: TextStyle(color: colors.muted, fontSize: 12.5),
          ),
        ),
      );
    }
    final format = widget.valueFormatter ??
        (value) => value.abs() >= 10000
            ? value.formatCompact()
            : value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showLegend && series.isNotEmpty) ...[
          ChartLegend(items: [
            for (final s in series) (label: s.label, color: s.color),
          ]),
          const SizedBox(height: 10),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, widget.height);
            final painter = _LineChartPainter(
              series: series,
              colors: colors,
              hoverIndex: _hoverIndex,
              showArea: widget.showArea,
              format: format,
            );
            final primary = series.first.points;
            return MouseRegion(
              onHover: (event) {
                const plotLeft = _LineChartPainter.leftAxis;
                final plotWidth = size.width - plotLeft - _LineChartPainter.rightAxis;
                if (plotWidth <= 0) return;
                final normalized =
                    (event.localPosition.dx - plotLeft) / plotWidth;
                final index = (normalized * (primary.length - 1))
                    .round()
                    .clamp(0, primary.length - 1);
                if (index != _hoverIndex) {
                  setState(() => _hoverIndex = index);
                }
              },
              onExit: (_) => setState(() => _hoverIndex = null),
              child: GestureDetector(
                onTapDown: (details) {
                  const plotLeft = _LineChartPainter.leftAxis;
                  final plotWidth = size.width - plotLeft - _LineChartPainter.rightAxis;
                  if (plotWidth <= 0) return;
                  final normalized =
                      (details.localPosition.dx - plotLeft) / plotWidth;
                  final index = (normalized * (primary.length - 1))
                      .round()
                      .clamp(0, primary.length - 1);
                  setState(() => _hoverIndex = index);
                },
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(painter: painter),
                      ),
                      if (_hoverIndex != null &&
                          _hoverIndex! < primary.length)
                        _buildTooltip(
                          context,
                          size,
                          painter,
                          primary[_hoverIndex!].date,
                          [
                            for (final s in series)
                              (
                                label: s.label,
                                color: s.color,
                                value: _hoverIndex! < s.points.length
                                    ? s.points[_hoverIndex!].value
                                    : 0.0,
                              ),
                          ],
                          format,
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTooltip(
    BuildContext context,
    Size size,
    _LineChartPainter painter,
    DateTime date,
    List<({String label, Color color, double value})> values,
    String Function(double) format,
  ) {
    final colors = context.colors;
    final index = _hoverIndex!;
    const plotLeft = _LineChartPainter.leftAxis;
    final plotWidth = size.width - plotLeft - _LineChartPainter.rightAxis;
    final count = math.max(1, painter.pointsCount - 1);
    final dx = plotLeft + plotWidth * (index / count);
    const tooltipWidth = 190.0;
    final left = (dx + 12 + tooltipWidth > size.width)
        ? (dx - tooltipWidth - 12).clamp(4.0, size.width - tooltipWidth - 4)
        : dx + 12;
    return Positioned(
      left: left,
      top: 6,
      child: IgnorePointer(
        child: Container(
          width: tooltipWidth,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colors.panel.withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.line),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: 0.3),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                date.formatShort(),
                style: TextStyle(
                  color: colors.muted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              for (final value in values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: value.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          value.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.muted,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                      Text(
                        format(value.value),
                        style: TextStyle(
                          color: colors.text,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.series,
    required this.colors,
    required this.hoverIndex,
    required this.showArea,
    required this.format,
  });

  final List<ChartSeries> series;
  final AppColors colors;
  final int? hoverIndex;
  final bool showArea;
  final String Function(double) format;

  static const double leftAxis = 44;
  static const double rightAxis = 10;
  static const double topAxis = 10;
  static const double bottomAxis = 24;

  int get pointsCount => series.first.points.length;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(
      leftAxis,
      topAxis,
      size.width - rightAxis,
      size.height - bottomAxis,
    );
    if (plot.width <= 0 || plot.height <= 0) return;

    var minValue = double.infinity;
    var maxValue = -double.infinity;
    var maxPoints = 0;
    for (final s in series) {
      maxPoints = math.max(maxPoints, s.points.length);
      for (final point in s.points) {
        if (point.value < minValue) minValue = point.value;
        if (point.value > maxValue) maxValue = point.value;
      }
    }
    if (!minValue.isFinite || !maxValue.isFinite) {
      minValue = 0;
      maxValue = 1;
    }
    if (minValue > 0) minValue = 0;
    if (maxValue == minValue) maxValue = minValue + 1;
    final span = maxValue - minValue;

    final gridPaint = Paint()
      ..color = colors.line.withValues(alpha: 0.65)
      ..strokeWidth = 1;
    const gridLines = 4;
    for (var i = 0; i <= gridLines; i++) {
      final y = plot.top + plot.height * i / gridLines;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      final value = maxValue - span * i / gridLines;
      _text(
        canvas,
        format(value),
        Offset(plot.left - 8, y),
        color: colors.muted,
        fontSize: 9.5,
        align: TextAlign.right,
        anchor: Alignment.centerRight,
      );
    }

    final points = series.first.points;
    final labelCount = math.min(6, points.length);
    if (labelCount > 1) {
      for (var i = 0; i < labelCount; i++) {
        final index =
            (i * (points.length - 1) / (labelCount - 1)).round();
        final x = plot.left + plot.width * index / math.max(1, points.length - 1);
        _text(
          canvas,
          points[index].date.formatDayMonth(),
          Offset(x, plot.bottom + 6),
          color: colors.muted,
          fontSize: 9.5,
          anchor: Alignment.topCenter,
        );
      }
    } else if (points.length == 1) {
      _text(
        canvas,
        points.first.date.formatDayMonth(),
        Offset(plot.left + plot.width / 2, plot.bottom + 6),
        color: colors.muted,
        fontSize: 9.5,
        anchor: Alignment.topCenter,
      );
    }

    double xFor(int index, int total) {
      if (total <= 1) return plot.left + plot.width / 2;
      return plot.left + plot.width * index / (total - 1);
    }

    double yFor(double value) =>
        plot.bottom - plot.height * (value - minValue) / span;

    for (final line in series) {
      if (line.points.isEmpty) continue;
      final count = line.points.length;
      final offsets = <Offset>[
        for (var i = 0; i < count; i++)
          Offset(xFor(i, count), yFor(line.points[i].value)),
      ];

      if (showArea && line.filled) {
        final fillPath = Path()..moveTo(offsets.first.dx, plot.bottom);
        _addSmoothPath(fillPath, offsets, startWithMove: false);
        fillPath
          ..lineTo(offsets.last.dx, plot.bottom)
          ..close();
        final gradient = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            line.color.withValues(alpha: 0.24),
            line.color.withValues(alpha: 0.01),
          ],
        );
        canvas.drawPath(
          fillPath,
          Paint()
            ..shader = gradient.createShader(plot)
            ..style = PaintingStyle.fill,
        );
      }

      final path = Path();
      _addSmoothPath(path, offsets);
      canvas.drawPath(
        path,
        Paint()
          ..color = line.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    if (hoverIndex != null && hoverIndex! < points.length) {
      final index = hoverIndex!;
      final x = xFor(index, points.length);
      canvas.drawLine(
        Offset(x, plot.top),
        Offset(x, plot.bottom),
        Paint()
          ..color = colors.muted.withValues(alpha: 0.45)
          ..strokeWidth = 1,
      );
      for (final line in series) {
        if (index >= line.points.length) continue;
        final point = Offset(xFor(index, line.points.length),
            yFor(line.points[index].value));
        canvas.drawCircle(point, 4.5, Paint()..color = colors.panel);
        canvas.drawCircle(point, 3, Paint()..color = line.color);
      }
    }
  }

  void _addSmoothPath(Path path, List<Offset> offsets,
      {bool startWithMove = true}) {
    if (offsets.isEmpty) return;
    if (startWithMove) path.moveTo(offsets.first.dx, offsets.first.dy);
    if (offsets.length == 1) {
      path.lineTo(offsets.first.dx, offsets.first.dy);
      return;
    }
    for (var i = 0; i < offsets.length - 1; i++) {
      final current = offsets[i];
      final next = offsets[i + 1];
      final controlX = (current.dx + next.dx) / 2;
      path.cubicTo(
        controlX,
        current.dy,
        controlX,
        next.dy,
        next.dx,
        next.dy,
      );
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset position, {
    required Color color,
    double fontSize = 10,
    TextAlign align = TextAlign.left,
    Alignment anchor = Alignment.centerLeft,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout();
    final offset = Offset(
      position.dx - painter.width * (anchor.x + 1) / 2,
      position.dy - painter.height * (anchor.y + 1) / 2,
    );
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) =>
      old.hoverIndex != hoverIndex ||
      old.series != series ||
      old.colors != colors;
}

class BarChartView extends StatelessWidget {
  const BarChartView({
    super.key,
    required this.items,
    this.height = 210,
    this.valueFormatter,
  });

  final List<({String label, double value, Color color})> items;
  final double height;
  final String Function(double)? valueFormatter;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (items.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text('Нет данных',
              style: TextStyle(color: colors.muted, fontSize: 12)),
        ),
      );
    }
    final maxValue =
        math.max(1.0, items.map((e) => e.value).fold<double>(0, math.max));
    final format = valueFormatter ??
        (value) => value.abs() >= 10000
            ? value.formatCompact()
            : value.toStringAsFixed(0);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final item in items)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      format(item.value),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor:
                              (item.value.abs() / maxValue).clamp(0.015, 1.0),
                          child: Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(maxWidth: 46),
                            decoration: BoxDecoration(
                              color: item.color.withValues(alpha: 0.82),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class DonutSegment {
  const DonutSegment({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;
}

class DonutChartView extends StatelessWidget {
  const DonutChartView({
    super.key,
    required this.segments,
    this.size = 168,
    this.centerLabel,
    this.centerValue,
    this.valueFormatter,
    this.legendOnRight = true,
  });

  final List<DonutSegment> segments;
  final double size;
  final String? centerLabel;
  final String? centerValue;
  final String Function(double)? valueFormatter;
  final bool legendOnRight;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final visible = segments.where((s) => s.value > 0).toList();
    final total = visible.fold<double>(0, (sum, s) => sum + s.value);
    final format = valueFormatter ??
        (value) => value.abs() >= 10000
            ? value.formatCompact()
            : value.toStringAsFixed(0);
    final chart = SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _DonutPainter(
              segments: visible,
              total: total,
              trackColor: colors.panelAlt,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (centerValue != null)
                Text(
                  centerValue!,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              if (centerLabel != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    centerLabel!,
                    style: TextStyle(color: colors.muted, fontSize: 10.5),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
    final legend = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final segment in visible)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: segment.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 7),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(
                    segment.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.muted, fontSize: 11.5),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  total == 0
                      ? '0%'
                      : '${(segment.value / total * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  format(segment.value),
                  style: TextStyle(color: colors.muted, fontSize: 10.5),
                ),
              ],
            ),
          ),
        if (visible.isEmpty)
          Text('Нет данных',
              style: TextStyle(color: colors.muted, fontSize: 12)),
      ],
    );
    if (!legendOnRight) {
      return Column(
        children: [
          chart,
          const SizedBox(height: 12),
          Center(child: legend),
        ],
      );
    }
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 22,
      runSpacing: 12,
      children: [chart, legend],
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.segments,
    required this.total,
    required this.trackColor,
  });

  final List<DonutSegment> segments;
  final double total;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = size.width * 0.135;
    final inner = rect.deflate(stroke / 2 + 2);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = trackColor;
    canvas.drawArc(inner, 0, math.pi * 2, false, track);
    if (total <= 0) return;
    var start = -math.pi / 2;
    const gap = 0.035;
    for (final segment in segments) {
      final sweep = segment.value / total * math.pi * 2;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = segment.color;
      final drawSweep = math.max(0.0, sweep - gap);
      if (drawSweep > 0) {
        canvas.drawArc(inner, start + gap / 2, drawSweep, false, paint);
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.segments != segments || old.total != total;
}

class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.points,
    required this.color,
    this.height = 38,
    this.width = 120,
  });

  final List<MetricPoint> points;
  final Color color;
  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _SparklinePainter(points: points, color: color),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.points, required this.color});

  final List<MetricPoint> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    var min = points.first.value;
    var max = points.first.value;
    for (final p in points) {
      if (p.value < min) min = p.value;
      if (p.value > max) max = p.value;
    }
    if (max == min) max = min + 1;
    final span = max - min;
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = size.width * i / (points.length - 1);
      final y = size.height - 2 - (size.height - 4) * (points[i].value - min) / span;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.points != points || old.color != color;
}

class HBarChart extends StatelessWidget {
  const HBarChart({
    super.key,
    required this.items,
    this.valueFormatter,
    this.maxRows = 8,
  });

  final List<({String label, double value, Color color})> items;
  final String Function(double)? valueFormatter;
  final int maxRows;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (items.isEmpty) {
      return Text('Нет данных',
          style: TextStyle(color: colors.muted, fontSize: 12.5));
    }
    final sorted = [...items]..sort((a, b) => b.value.compareTo(a.value));
    final maxValue =
        math.max(0.0001, sorted.map((e) => e.value.abs()).fold<double>(0, math.max));
    final format = valueFormatter ??
        (value) => value.abs() >= 10000
            ? value.formatCompact()
            : value.toStringAsFixed(0);
    return Column(
      children: [
        for (final item in sorted.take(maxRows))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 104,
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.muted, fontSize: 11.5),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 9,
                      child: Row(
                        children: [
                          Expanded(
                            flex: math.max(1, (item.value.abs() / maxValue * 1000).round()),
                            child: Container(
                              decoration: BoxDecoration(
                                color: item.color.withValues(alpha: 0.78),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          if (item.value.abs() < maxValue)
                            Expanded(
                              flex: math.max(
                                1,
                                ((1 - item.value.abs() / maxValue) * 1000)
                                    .round(),
                              ),
                              child: Container(color: colors.panelAlt),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 72,
                  child: Text(
                    format(item.value),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
