import 'package:flutter/widgets.dart';

import '../../theme/tokens.dart';

/// The map pin from Figma ("Map pin" component, 28 × 36): a teardrop in
/// [color] with a white rim and a white dot. The tip is at the bottom centre.
class MapPin extends StatelessWidget {
  const MapPin({super.key, required this.color});

  final Color color;

  static const size = Size(28, 36);

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: size, painter: _PinPainter(color));
}

class _PinPainter extends CustomPainter {
  const _PinPainter(this.color);

  final Color color;

  // The Figma vector, in its 28 × 36 box.
  static final _body = Path()
    ..moveTo(14, 1)
    ..cubicTo(6.8, 1, 1, 6.7, 1, 13.7)
    ..cubicTo(1, 23.2, 14, 35, 14, 35)
    ..cubicTo(14, 35, 27, 23.2, 27, 13.7)
    ..cubicTo(27, 6.7, 21.2, 1, 14, 1)
    ..close();
  static const _dotCentre = Offset(14, 13.5);
  static const _dotRadius = 4.5;
  static const _rimWidth = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(
      size.width / MapPin.size.width,
      size.height / MapPin.size.height,
    );
    canvas.drawPath(_body, Paint()..color = color);
    canvas.drawPath(
      _body,
      Paint()
        ..color = AppColors.bgSurface
        ..style = PaintingStyle.stroke
        ..strokeWidth = _rimWidth,
    );
    canvas.drawCircle(
      _dotCentre,
      _dotRadius,
      Paint()..color = AppColors.bgSurface,
    );
  }

  @override
  bool shouldRepaint(_PinPainter old) => old.color != color;
}
