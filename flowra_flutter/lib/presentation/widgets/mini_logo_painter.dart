import 'package:flutter/material.dart';

class MiniLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final cx = s.width / 2, cy = s.height / 2;
    final path = Path()
      ..moveTo(cx, cy + 7)
      ..cubicTo(cx - 6, cy + 2, cx - 7, cy - 4, cx, cy - 7)
      ..cubicTo(cx + 7, cy - 4, cx + 6, cy + 2, cx, cy + 7);
    canvas.drawPath(
        path,
        paint
          ..style = PaintingStyle.fill
          ..color = Colors.white.withOpacity(0.2));
    canvas.drawPath(
        path,
        paint
          ..style = PaintingStyle.stroke
          ..color = Colors.white.withOpacity(0.8));
    canvas.drawLine(
        Offset(cx, cy + 5),
        Offset(cx, cy - 5),
        paint
          ..color = Colors.white
          ..strokeWidth = 1.4);
    canvas.drawLine(Offset(cx, cy - 5), Offset(cx - 3, cy - 1), paint);
    canvas.drawLine(Offset(cx, cy - 5), Offset(cx + 3, cy - 1), paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
