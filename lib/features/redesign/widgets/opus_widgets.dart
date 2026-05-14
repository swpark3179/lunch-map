import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/opus_tokens.dart';

/// OPUS-X 디자인 시스템 공통 위젯 모음 (Badge / Chip / Stars / CatDot)

enum BadgeVariant { primary, neutral, success, warning, error, info }

class OpusBadge extends StatelessWidget {
  final String text;
  final BadgeVariant variant;
  final bool dot;

  const OpusBadge({
    super.key,
    required this.text,
    this.variant = BadgeVariant.neutral,
    this.dot = false,
  });

  @override
  Widget build(BuildContext context) {
    late Color bg;
    late Color fg;
    switch (variant) {
      case BadgeVariant.primary:
        bg = OpusColors.purple50;
        fg = OpusColors.purple700;
        break;
      case BadgeVariant.neutral:
        bg = OpusColors.gray100;
        fg = OpusColors.gray700;
        break;
      case BadgeVariant.success:
        bg = OpusColors.green50;
        fg = OpusColors.green700;
        break;
      case BadgeVariant.warning:
        bg = OpusColors.yellow50;
        fg = OpusColors.yellow700;
        break;
      case BadgeVariant.error:
        bg = OpusColors.red50;
        fg = OpusColors.red700;
        break;
      case BadgeVariant.info:
        bg = OpusColors.blue50;
        fg = OpusColors.blue700;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(OpusRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: GoogleFonts.notoSansKr(
              fontSize: 11,
              height: 14 / 11,
              fontWeight: FontWeight.w500,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class OpusChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback? onTap;
  final Widget? leading;

  const OpusChip({
    super.key,
    required this.label,
    this.active = false,
    this.onTap,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(OpusRadius.full),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? OpusColors.purple600 : Colors.white,
          borderRadius: BorderRadius.circular(OpusRadius.full),
          border: Border.all(
            color: active ? OpusColors.purple600 : OpusColors.gray200,
          ),
          boxShadow: active ? OpusShadow.xs : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.notoSansKr(
                fontSize: 13,
                height: 16 / 13,
                fontWeight: FontWeight.w500,
                color: active ? Colors.white : OpusColors.gray700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryDot extends StatelessWidget {
  final String? categoryKey;
  final double size;
  const CategoryDot({super.key, required this.categoryKey, this.size = 8});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: OpusColors.category(categoryKey ?? ''),
        shape: BoxShape.circle,
      ),
    );
  }
}

class StarsView extends StatelessWidget {
  final double value;
  final double size;
  final bool showNum;

  const StarsView({
    super.key,
    required this.value,
    this.size = 12,
    this.showNum = true,
  });

  @override
  Widget build(BuildContext context) {
    final int full = value.floor();
    final bool half = (value - full) >= 0.4 && full < 5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++)
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Icon(
              i < full
                  ? Icons.star_rounded
                  : (i == full && half
                      ? Icons.star_half_rounded
                      : Icons.star_outline_rounded),
              size: size + 2,
              color: i < full || (i == full && half)
                  ? OpusColors.yellow500
                  : OpusColors.gray300,
            ),
          ),
        if (showNum) ...[
          const SizedBox(width: 2),
          Text(
            value.toStringAsFixed(1),
            style: GoogleFonts.robotoMono(
              fontSize: size - 1,
              fontWeight: FontWeight.w700,
              color: OpusColors.gray900,
            ),
          ),
        ],
      ],
    );
  }
}

class PriceText extends StatelessWidget {
  final int won;
  final double size;
  final Color color;
  const PriceText({
    super.key,
    required this.won,
    this.size = 14,
    this.color = OpusColors.gray900,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      '₩${_format(won)}',
      style: GoogleFonts.robotoMono(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );
  }

  static String _format(int won) => formatKrw(won);
}

/// 원화 천단위 콤마 포맷.
String formatKrw(int won) {
  final s = won.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// 디자인 mock 의 정적 지도 — 위경도 박스 안에 핀들을 점으로 표시한다.
class StaticMapPreview extends StatelessWidget {
  final List<Offset> pins; // 0~1 정규화 좌표
  final int? selectedIndex;
  final ValueChanged<int>? onPinTap;

  const StaticMapPreview({
    super.key,
    required this.pins,
    this.selectedIndex,
    this.onPinTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      return Stack(
        children: [
          // 배경 그라데이션 + 그리드 라인
          Positioned.fill(
            child: CustomPaint(painter: _MapBackgroundPainter()),
          ),
          for (var i = 0; i < pins.length; i++)
            Positioned(
              left: pins[i].dx * c.maxWidth - 18,
              top:  pins[i].dy * c.maxHeight - 36,
              child: GestureDetector(
                onTap: () => onPinTap?.call(i),
                child: _MapPin(active: i == selectedIndex),
              ),
            ),
        ],
      );
    });
  }
}

class _MapPin extends StatelessWidget {
  final bool active;
  const _MapPin({required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? OpusColors.purple600 : Colors.white;
    final fg = active ? Colors.white : OpusColors.purple600;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: OpusColors.purple600, width: 2),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Icon(Icons.restaurant_rounded, size: 18, color: fg),
        ),
      ],
    );
  }
}

class _MapBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    final grid = Paint()
      ..color = const Color(0x14101828)
      ..strokeWidth = 1;
    const step = 32.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
