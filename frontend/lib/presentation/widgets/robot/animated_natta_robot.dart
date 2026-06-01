import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/presentation/widgets/robot/robot_personality.dart';

/// Robot Natta full-body — đồng bộ phong cách với web (SVG chibi, màn hình, tai, đuôi, tay vẫy).
class AnimatedNattaRobot extends StatefulWidget {
  final double size;
  final PersonalityType personality;
  final bool isSelected;
  final bool animated;

  const AnimatedNattaRobot({
    super.key,
    required this.size,
    this.personality = PersonalityType.happy,
    this.isSelected = false,
    this.animated = true,
  });

  @override
  State<AnimatedNattaRobot> createState() => _AnimatedNattaRobotState();
}

class _AnimatedNattaRobotState extends State<AnimatedNattaRobot>
    with TickerProviderStateMixin {
  static const _vbW = 100.0;
  static const _vbH = 128.0;

  late AnimationController _floatCtrl;
  late AnimationController _waveCtrl;
  late AnimationController _tailCtrl;
  late AnimationController _blinkCtrl;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _tailCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    );
    if (widget.animated) {
      _floatCtrl.repeat();
      _waveCtrl.repeat(reverse: true);
      _tailCtrl.repeat(reverse: true);
      _blinkCtrl.repeat();
    }
  }

  @override
  void didUpdateWidget(AnimatedNattaRobot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animated != oldWidget.animated) {
      if (widget.animated) {
        _floatCtrl.repeat();
        _waveCtrl.repeat(reverse: true);
        _tailCtrl.repeat(reverse: true);
        _blinkCtrl.repeat();
      } else {
        _floatCtrl.stop();
        _waveCtrl.stop();
        _tailCtrl.stop();
        _blinkCtrl.stop();
      }
    }
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    _waveCtrl.dispose();
    _tailCtrl.dispose();
    _blinkCtrl.dispose();
    super.dispose();
  }

  Color _accent() {
    final sel = widget.isSelected;
    switch (widget.personality) {
      case PersonalityType.angry:
        return sel ? const Color(0xFFFF6B6B) : const Color(0xFFFF8A80);
      case PersonalityType.sad:
        return sel ? const Color(0xFF9FA8DA) : const Color(0xFFB4B9F5);
      case PersonalityType.happy:
        return sel ? const Color(0xFF6EC8FF) : AppColors.primaryLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.size * (_vbW / _vbH);
    final h = widget.size;
    final accent = _accent();
    return AnimatedBuilder(
      animation: Listenable.merge([_floatCtrl, _waveCtrl, _tailCtrl, _blinkCtrl]),
      builder: (context, _) {
        final scale = h / _vbH;
        final floatY = widget.animated ? -6 * scale * math.sin(math.pi * _floatCtrl.value) : 0.0;
        final armT = widget.animated ? _waveCtrl.value : 0.0;
        final armAngle = -0.31 + (0.38 - (-0.31)) * armT;
        final tailT = widget.animated ? _tailCtrl.value : 0.5;
        final tailAngle = -0.10 + (0.17 - (-0.10)) * tailT;
        final blinkT = widget.animated ? _blinkCtrl.value : 0.0;
        final eyeOpacity = _blinkOpacity(blinkT);

        return Transform.translate(
          offset: Offset(0, floatY),
          child: CustomPaint(
            size: Size(w, h),
            painter: _NattaRobotPainter(
              accent: accent,
              personality: widget.personality,
              isSelected: widget.isSelected,
              armAngleRad: armAngle,
              tailAngleRad: tailAngle,
              eyeOpen: eyeOpacity,
            ),
          ),
        );
      },
    );
  }

  /// Giống keyframes web: phần lớn thời gian mắt mở, chớp nhanh giữa chu kỳ.
  double _blinkOpacity(double t) {
    if (t < 0.45 || t > 0.55) return 1;
    if (t < 0.48) return 1 - (t - 0.45) / 0.03 * 0.88;
    if (t < 0.52) return 0.12;
    return 0.12 + (t - 0.52) / 0.03 * 0.88;
  }
}

class _NattaRobotPainter extends CustomPainter {
  _NattaRobotPainter({
    required this.accent,
    required this.personality,
    required this.isSelected,
    required this.armAngleRad,
    required this.tailAngleRad,
    required this.eyeOpen,
  });

  final Color accent;
  final PersonalityType personality;
  final bool isSelected;
  final double armAngleRad;
  final double tailAngleRad;
  final double eyeOpen;

  static const _vbW = 100.0;
  static const _vbH = 128.0;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / _vbW;
    final sy = size.height / _vbH;

    void scaleCanvas(void Function(Canvas c) draw) {
      canvas.save();
      canvas.scale(sx, sy);
      draw(canvas);
      canvas.restore();
    }

    scaleCanvas((c) {
      c.drawOval(
        const Rect.fromLTWH(28, 118, 44, 8),
        Paint()..color = const Color(0x140F172A),
      );
    });

    // Đuôi
    scaleCanvas((c) {
      c.save();
      c.translate(80, 88);
      c.rotate(tailAngleRad);
      c.translate(-80, -88);
      final tailPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..shader = ui.Gradient.linear(
          const Offset(79, 87),
          const Offset(96, 40),
          [accent.withOpacity(0.95), accent.withOpacity(0.55)],
        );
      final tailPath = Path()
        ..moveTo(79, 87)
        ..cubicTo(88, 82, 94, 72, 96, 60)
        ..cubicTo(97, 52, 95, 44, 91, 40);
      c.drawPath(tailPath, tailPaint);
      c.drawCircle(const Offset(91, 40), 3.5, Paint()..color = accent.withOpacity(0.85));
      c.restore();
    });

    // Chân
    scaleCanvas((c) {
      final bodyGrad = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFFFFF), Color(0xFFEEF2F7)],
      );
      void boot(Path p) {
        c.drawPath(
          p,
          Paint()
            ..shader = bodyGrad.createShader(p.getBounds())
            ..style = PaintingStyle.fill,
        );
        c.drawPath(
          p,
          Paint()
            ..color = const Color(0xFFE2E8F0)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.6,
        );
      }

      boot(Path()
        ..moveTo(30, 98)
        ..lineTo(30, 112)
        ..quadraticBezierTo(30, 118, 41, 118)
        ..quadraticBezierTo(48, 118, 48, 112)
        ..lineTo(48, 98)
        ..quadraticBezierTo(41, 96, 30, 98)
        ..close());
      boot(Path()
        ..moveTo(52, 98)
        ..lineTo(52, 112)
        ..quadraticBezierTo(52, 118, 59, 118)
        ..quadraticBezierTo(70, 118, 70, 112)
        ..lineTo(70, 98)
        ..quadraticBezierTo(59, 96, 52, 98)
        ..close());
      c.drawOval(
        const Rect.fromLTWH(36, 112, 10, 5),
        Paint()..color = accent.withOpacity(0.35),
      );
      c.drawOval(
        const Rect.fromLTWH(54, 112, 10, 5),
        Paint()..color = accent.withOpacity(0.35),
      );
    });

    // Thân
    scaleCanvas((c) {
      final bodyPath = Path()
        ..moveTo(50, 52)
        ..cubicTo(28, 52, 18, 68, 18, 78)
        ..cubicTo(18, 92, 32, 102, 50, 102)
        ..cubicTo(68, 102, 82, 92, 82, 78)
        ..cubicTo(82, 66, 72, 52, 50, 52)
        ..close();
      final g = const LinearGradient(
        colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC), Color(0xFFEEF2F7)],
      ).createShader(bodyPath.getBounds());
      c.drawPath(bodyPath, Paint()..shader = g);
      c.drawPath(
        bodyPath,
        Paint()
          ..color = const Color(0xFFE2E8F0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7,
      );
      c.drawOval(
        const Rect.fromLTWH(30, 70.5, 40, 5),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = accent.withOpacity(0.35)
          ..strokeWidth = 0.9,
      );
    });

    // Tay trái (viewer left)
    scaleCanvas((c) {
      final arm = Path()
        ..moveTo(24, 58)
        ..cubicTo(14, 64, 10, 76, 11, 86);
      c.drawPath(
        arm,
        Paint()
          ..color = const Color(0xFFF1F5F9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 11
          ..strokeCap = StrokeCap.round,
      );
      c.drawPath(
        arm,
        Paint()
          ..color = accent.withOpacity(0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round,
      );
      c.drawCircle(
        const Offset(11, 88),
        5,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFEEF2F7)],
          ).createShader(Rect.fromCircle(center: const Offset(11, 88), radius: 5)),
      );
      c.drawCircle(
        const Offset(11, 88),
        5,
        Paint()
          ..color = const Color(0xFFE2E8F0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5,
      );
    });

    // Tay phải + vẫy
    scaleCanvas((c) {
      c.save();
      c.translate(76, 56);
      c.rotate(armAngleRad);
      c.translate(-76, -56);
      final arm = Path()
        ..moveTo(76, 56)
        ..cubicTo(86, 52, 92, 62, 93, 72)
        ..cubicTo(94, 82, 90, 90, 85, 94);
      c.drawPath(
        arm,
        Paint()
          ..color = const Color(0xFFF1F5F9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 11
          ..strokeCap = StrokeCap.round,
      );
      c.drawPath(
        Path()..moveTo(76, 56)..cubicTo(86, 52, 92, 62, 93, 72),
        Paint()
          ..color = accent.withOpacity(0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round,
      );
      c.drawCircle(
        const Offset(85, 95),
        5,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFEEF2F7)],
          ).createShader(Rect.fromCircle(center: const Offset(85, 95), radius: 5)),
      );
      c.drawCircle(
        const Offset(85, 95),
        5,
        Paint()
          ..color = const Color(0xFFE2E8F0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5,
      );
      c.restore();
    });

    // Cổ
    scaleCanvas((c) {
      final r = RRect.fromRectAndRadius(
        const Rect.fromLTWH(43, 48, 14, 11),
        const Radius.circular(5),
      );
      c.drawRRect(r, Paint()..color = const Color(0xFFF1F5F9));
      c.drawRRect(
        r,
        Paint()
          ..color = const Color(0xFFE2E8F0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5,
      );
    });

    // Tai
    scaleCanvas((c) {
      final earPink = const LinearGradient(
        colors: [Color(0xFFFFD6E8), Color(0xFFFFB8D9)],
      );
      void leftEar() {
        final p = Path()
          ..moveTo(26, 24)
          ..quadraticBezierTo(22, 10, 28, 6)
          ..quadraticBezierTo(34, 4, 38, 16)
          ..close();
        c.drawPath(
          p,
          Paint()
            ..shader = const LinearGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFFF1F5F9)],
            ).createShader(p.getBounds()),
        );
        c.drawPath(
          p,
          Paint()
            ..color = const Color(0xFFE2E8F0)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.55,
        );
        final inner = Path()
          ..moveTo(32, 14)
          ..quadraticBezierTo(30, 10, 33, 9)
          ..quadraticBezierTo(36, 10, 35, 14)
          ..close();
        c.drawPath(inner, Paint()..shader = earPink.createShader(inner.getBounds()));
      }

      void rightEar() {
        final p = Path()
          ..moveTo(74, 24)
          ..quadraticBezierTo(78, 10, 72, 6)
          ..quadraticBezierTo(66, 4, 62, 16)
          ..close();
        c.drawPath(
          p,
          Paint()
            ..shader = const LinearGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFFF1F5F9)],
            ).createShader(p.getBounds()),
        );
        c.drawPath(
          p,
          Paint()
            ..color = const Color(0xFFE2E8F0)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.55,
        );
        final inner = Path()
          ..moveTo(68, 14)
          ..quadraticBezierTo(70, 10, 67, 9)
          ..quadraticBezierTo(64, 10, 65, 14)
          ..close();
        c.drawPath(inner, Paint()..shader = earPink.createShader(inner.getBounds()));
      }

      leftEar();
      rightEar();
    });

    // Đầu
    scaleCanvas((c) {
      final head = RRect.fromRectAndRadius(
        const Rect.fromLTWH(18, 12, 64, 50),
        const Radius.circular(16),
      );
      c.drawRRect(
        head,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFF1F5F9)],
          ).createShader(head.outerRect),
      );
      c.drawRRect(
        head,
        Paint()
          ..color = const Color(0xFFE2E8F0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.75,
      );
      final shine = RRect.fromRectAndRadius(
        const Rect.fromLTWH(19, 13, 62, 48),
        const Radius.circular(15),
      );
      c.drawRRect(
        shine,
        Paint()
          ..color = Colors.white.withOpacity(0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6,
      );
    });

    // Màn hình
    scaleCanvas((c) {
      final scr = RRect.fromRectAndRadius(
        const Rect.fromLTWH(23, 26, 54, 30),
        const Radius.circular(8),
      );
      c.drawRRect(
        scr,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F2744), Color(0xFF0A1628), Color(0xFF060D18)],
          ).createShader(scr.outerRect),
      );
      c.drawRRect(
        scr,
        Paint()
          ..color = const Color(0xFF1E3A5F)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5,
      );
      final shineRect = Rect.fromLTWH(23, 26, 54, 14);
      c.drawRRect(
        RRect.fromRectAndRadius(shineRect, const Radius.circular(8)),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF38BDF8).withOpacity(0.22),
              Colors.transparent,
            ],
          ).createShader(shineRect),
      );
    });

    // Mặt
    scaleCanvas((c) => _drawFace(c));

    // Viền accent
    scaleCanvas((c) {
      final head = RRect.fromRectAndRadius(
        const Rect.fromLTWH(18, 12, 64, 50),
        const Radius.circular(16),
      );
      c.drawRRect(
        head,
        Paint()
          ..color = accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSelected ? 1.6 : 1,
      );
    });
  }

  void _drawFace(Canvas c) {
    switch (personality) {
      case PersonalityType.angry:
        _drawAngryFace(c);
        break;
      case PersonalityType.sad:
        _drawSadFace(c);
        break;
      case PersonalityType.happy:
        _drawHappyFace(c);
        break;
    }
  }

  void _drawAngryFace(Canvas c) {
    final pink = const Color(0xFFFB7185);
    c.drawLine(const Offset(32, 34), const Offset(40, 38), Paint()..color = const Color(0xFFFCA5A5)..strokeWidth = 2.2..strokeCap = StrokeCap.round);
    c.drawLine(const Offset(68, 34), const Offset(60, 38), Paint()..color = const Color(0xFFFCA5A5)..strokeWidth = 2.2..strokeCap = StrokeCap.round);
    c.save();
    c.translate(37, 42);
    c.rotate(0.12);
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-4, -5, 8, 10),
        const Radius.circular(2),
      ),
      Paint()..color = pink,
    );
    c.restore();
    c.save();
    c.translate(63, 42);
    c.rotate(-0.12);
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-4, -5, 8, 10),
        const Radius.circular(2),
      ),
      Paint()..color = pink,
    );
    c.restore();
    final mouth = Path()
      ..moveTo(45, 51)
      ..quadraticBezierTo(50, 47, 55, 51);
    c.drawPath(
      mouth,
      Paint()
        ..color = pink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawSadFace(Canvas c) {
    final eye = const Color(0xFF99F6E4);
    c.drawPath(
      Path()
        ..moveTo(36, 41)
        ..quadraticBezierTo(38, 39, 40, 41),
      Paint()
        ..color = eye
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
    c.drawPath(
      Path()
        ..moveTo(60, 41)
        ..quadraticBezierTo(62, 39, 64, 41),
      Paint()
        ..color = eye
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
    c.drawPath(
      Path()
        ..moveTo(43, 51)
        ..quadraticBezierTo(50, 48, 57, 51),
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
    final cheek = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFDA4C4).withOpacity(0.65),
          const Color(0xFFFDA4C4).withOpacity(0),
        ],
      ).createShader(Rect.fromCircle(center: const Offset(33, 44), radius: 6));
    c.drawCircle(const Offset(33, 44), 5, cheek);
    c.drawCircle(
      const Offset(67, 44),
      5,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFDA4C4).withOpacity(0.65),
            const Color(0xFFFDA4C4).withOpacity(0),
          ],
        ).createShader(Rect.fromCircle(center: const Offset(67, 44), radius: 6)),
    );
  }

  void _drawHappyFace(Canvas c) {
    const core = Color(0xFF5EEAD4);
    const hi = Color(0xFF99F6E4);
    final o = eyeOpen;
    c.drawOval(
      const Rect.fromLTWH(32.8, 34.2, 10.4, 11.6),
      Paint()..color = core.withOpacity(o),
    );
    c.drawOval(
      const Rect.fromLTWH(56.8, 34.2, 10.4, 11.6),
      Paint()..color = core.withOpacity(o),
    );
    c.drawOval(
      const Rect.fromLTWH(34.5, 32.5, 3.6, 4),
      Paint()..color = Colors.white.withOpacity(0.95 * o),
    );
    c.drawOval(
      const Rect.fromLTWH(58.5, 32.5, 3.6, 4),
      Paint()..color = Colors.white.withOpacity(0.95 * o),
    );
    c.drawCircle(
      const Offset(36.8, 41.5),
      1,
      Paint()..color = const Color(0xFF134E4A).withOpacity(0.35 * o),
    );
    c.drawCircle(
      const Offset(60.8, 41.5),
      1,
      Paint()..color = const Color(0xFF134E4A).withOpacity(0.35 * o),
    );
    c.drawPath(
      Path()
        ..moveTo(43, 52)
        ..quadraticBezierTo(50, 58.5, 57, 52),
      Paint()
        ..color = hi
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
    final blush = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFDA4C4).withOpacity(0.65),
          const Color(0xFFFDA4C4).withOpacity(0),
        ],
      ).createShader(Rect.fromCircle(center: const Offset(31, 45), radius: 8));
    c.drawCircle(const Offset(31, 45), 6.5, blush);
    c.drawCircle(
      const Offset(69, 45),
      6.5,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFDA4C4).withOpacity(0.65),
            const Color(0xFFFDA4C4).withOpacity(0),
          ],
        ).createShader(Rect.fromCircle(center: const Offset(69, 45), radius: 8)),
    );
    c.drawPath(
      Path()
        ..moveTo(33, 34)
        ..cubicTo(31, 32, 29, 33, 28, 35),
      Paint()
        ..color = hi.withOpacity(0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round,
    );
    c.drawPath(
      Path()
        ..moveTo(67, 34)
        ..cubicTo(69, 32, 71, 33, 72, 35),
      Paint()
        ..color = hi.withOpacity(0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _NattaRobotPainter oldDelegate) {
    return oldDelegate.accent != accent ||
        oldDelegate.personality != personality ||
        oldDelegate.isSelected != isSelected ||
        oldDelegate.armAngleRad != armAngleRad ||
        oldDelegate.tailAngleRad != tailAngleRad ||
        oldDelegate.eyeOpen != eyeOpen;
  }
}
