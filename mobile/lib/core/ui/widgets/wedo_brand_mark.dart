import 'package:flutter/material.dart';

/// Compact monochrome rendition of the connected-people weDO mark.
class WeDoBrandMark extends StatelessWidget {
  final double size;
  const WeDoBrandMark({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Logo weDO',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.onSurface,
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: EdgeInsets.all(size * .18),
            child: CustomPaint(painter: _BrandPainter(colors.surface)),
          ),
        ),
      ),
    );
  }
}

class _BrandPainter extends CustomPainter {
  final Color color;
  const _BrandPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 100);
    final paint = Paint()..color = color;
    canvas.drawCircle(const Offset(13, 32), 7, paint);
    canvas.drawCircle(const Offset(42, 32), 7, paint);
    canvas.drawCircle(const Offset(69, 18), 7, paint);
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(13, 51)
        ..lineTo(27, 84)
        ..lineTo(41, 51)
        ..quadraticBezierTo(64, 83, 68, 42),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(84, 18)
        ..cubicTo(111, 41, 104, 85, 73, 85)
        ..lineTo(52, 85),
      paint,
    );
  }

  @override
  bool shouldRepaint(_BrandPainter oldDelegate) => oldDelegate.color != color;
}
