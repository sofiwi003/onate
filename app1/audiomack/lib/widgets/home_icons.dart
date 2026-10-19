import 'package:app1/theme/theme.dart';
import 'package:flutter/material.dart';

class WaveLogoPainter extends CustomPainter {
  const WaveLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 32, size.height / 24);
    final paint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(3, 13)
      ..lineTo(5, 13.5)
      ..lineTo(8, 10)
      ..lineTo(9, 15)
      ..lineTo(13, 7)
      ..lineTo(14, 17)
      ..lineTo(20, 4)
      ..lineTo(19, 22)
      ..lineTo(26, 1)
      ..lineTo(25, 17)
      ..lineTo(28, 13)
      ..lineTo(31, 14);
    canvas.drawPath(path, paint);
    canvas.drawCircle(
      const Offset(0.8, 13),
      0.7,
      Paint()..color = AppColors.primary,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant WaveLogoPainter oldDelegate) => false;
}

class NavIconPainter extends CustomPainter {
  const NavIconPainter({required this.library, required this.color});
  final bool library;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()..color = color;
    if (library) {
      canvas.drawRect(const Rect.fromLTWH(1, 2, 4, 21), paint);
      canvas.drawRect(const Rect.fromLTWH(7, 0, 4, 23), paint);
      canvas.drawPath(
        Path()
          ..moveTo(13, 3)
          ..lineTo(17, 2)
          ..lineTo(23, 22)
          ..lineTo(18, 23)
          ..close(),
        paint,
      );
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(5, 0, 14, 2),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(3, 3, 18, 2),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.drawPath(
        Path()
          ..moveTo(2, 7)
          ..quadraticBezierTo(12, 4, 22, 7)
          ..lineTo(20, 20)
          ..quadraticBezierTo(19, 23, 16, 23)
          ..lineTo(8, 23)
          ..quadraticBezierTo(5, 23, 4, 20)
          ..close(),
        paint,
      );
      final note = Paint()..color = AppColors.neutral.shade900;
      canvas.drawOval(const Rect.fromLTWH(8, 15, 5, 5), note);
      canvas.drawRect(const Rect.fromLTWH(12, 10, 1.8, 8), note);
      canvas.drawPath(
        Path()
          ..moveTo(13, 9)
          ..quadraticBezierTo(20, 10, 16, 15)
          ..lineTo(13, 12)
          ..close(),
        note,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant NavIconPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.library != library;
}
