import 'package:material_ui/material_ui.dart';

/// Welcome's picture: a sun coming up over three lines of a page, drawn in
/// the theme's own colours so it follows light and dark. Decoration only;
/// assistive technology skips it.
class const SunriseArt({super.key}) extends StatelessWidget {
  static const size = Size(200, 160);

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: size,
      painter: _SunrisePainter(Theme.of(context).colorScheme),
    ),
  );
}

class const _SunrisePainter(final ColorScheme colors) extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final horizon = size.height * 0.7;
    final centre = Offset(size.width / 2, horizon);
    canvas
      ..save()
      ..clipRect(Rect.fromLTRB(0, 0, size.width, horizon));
    for (final (radius, color) in [
      (72.0, colors.primaryContainer),
      (46.0, colors.primary.withValues(alpha: 0.55)),
      (22.0, colors.primary),
    ]) {
      canvas.drawCircle(centre, radius, Paint()..color = color);
    }
    canvas.restore();
    final line = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final (inset, dy, color) in [
      (20.0, 0.0, colors.primary),
      (44.0, 14.0, colors.outlineVariant),
      (70.0, 28.0, colors.outlineVariant),
    ]) {
      canvas.drawLine(
        Offset(inset, horizon + dy),
        Offset(size.width - inset, horizon + dy),
        line..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_SunrisePainter oldDelegate) =>
      oldDelegate.colors != colors;
}

/// The skipped name's picture: a smiling pebble, for a user who would
/// rather stay mysterious. Decoration only.
class const PebbleArt({super.key}) extends StatelessWidget {
  static const size = Size(96, 72);

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: size,
      painter: _PebblePainter(Theme.of(context).colorScheme),
    ),
  );
}

class const _PebblePainter(final ColorScheme colors) extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final face = Paint()..color = colors.onPrimaryContainer;
    canvas
      ..drawOval(
        Rect.fromCenter(center: const Offset(48, 44), width: 88, height: 52),
        Paint()..color = colors.primaryContainer,
      )
      ..drawOval(
        Rect.fromCenter(center: const Offset(40, 36), width: 28, height: 12),
        Paint()..color = colors.surface.withValues(alpha: 0.6),
      )
      ..drawCircle(const Offset(36, 46), 3, face)
      ..drawCircle(const Offset(58, 46), 3, face)
      ..drawPath(
        Path()
          ..moveTo(42, 55)
          ..quadraticBezierTo(47, 59, 52, 55),
        Paint()
          ..color = colors.onPrimaryContainer
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
  }

  @override
  bool shouldRepaint(_PebblePainter oldDelegate) =>
      oldDelegate.colors != colors;
}
