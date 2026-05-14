import 'package:flutter/material.dart';

/// OPUS-X Design System — Flutter port of `styles/opus-x-tokens.css`.
///
/// 색·타이포·스페이싱·라운드·그림자·모션 토큰을 한 곳에 모아둔다.
/// 위젯 코드에서는 `OpusColors.purple600`, `OpusRadius.lg` 처럼 호출한다.
class OpusColors {
  OpusColors._();

  // Purple — primary brand
  static const purple25  = Color(0xFFFAFAFF);
  static const purple50  = Color(0xFFF4F3FF);
  static const purple100 = Color(0xFFEBE9FE);
  static const purple200 = Color(0xFFD9D6FE);
  static const purple300 = Color(0xFFBDB4FE);
  static const purple400 = Color(0xFF9B8AFB);
  static const purple500 = Color(0xFF7F56D9);
  static const purple600 = Color(0xFF6941C6);
  static const purple700 = Color(0xFF53389E);
  static const purple800 = Color(0xFF42307D);
  static const purple900 = Color(0xFF2F1C6A);

  // Gray modern — neutral
  static const gray25  = Color(0xFFFCFCFD);
  static const gray50  = Color(0xFFF9FAFB);
  static const gray100 = Color(0xFFF2F4F7);
  static const gray200 = Color(0xFFEAECF0);
  static const gray300 = Color(0xFFD0D5DD);
  static const gray400 = Color(0xFF98A2B3);
  static const gray500 = Color(0xFF667085);
  static const gray600 = Color(0xFF475467);
  static const gray700 = Color(0xFF344054);
  static const gray800 = Color(0xFF1D2939);
  static const gray900 = Color(0xFF101828);

  // Yellow — highlight / warn
  static const yellow50  = Color(0xFFFEFBE8);
  static const yellow300 = Color(0xFFFDE272);
  static const yellow500 = Color(0xFFEAAA08);
  static const yellow600 = Color(0xFFA15C07);
  static const yellow700 = Color(0xFF854A0E);

  // Blue
  static const blue50  = Color(0xFFEFF8FF);
  static const blue500 = Color(0xFF2E90FA);
  static const blue600 = Color(0xFF1570EF);
  static const blue700 = Color(0xFF175CD3);

  // Green
  static const green50  = Color(0xFFECFDF3);
  static const green500 = Color(0xFF12B76A);
  static const green600 = Color(0xFF039855);
  static const green700 = Color(0xFF027A48);

  // Red
  static const red50  = Color(0xFFFEF3F2);
  static const red500 = Color(0xFFF04438);
  static const red600 = Color(0xFFD92D20);
  static const red700 = Color(0xFFB42318);

  // Teal
  static const teal500 = Color(0xFF15B79E);
  static const teal600 = Color(0xFF0E9384);

  // Semantic surfaces
  static const bgCanvas = Color(0xFFF8F9FC);
  static const bgBase   = Colors.white;

  // 카테고리 키 → 컬러
  static Color category(String key) {
    switch (key) {
      case 'kr': return purple500;
      case 'jp': return red500;
      case 'cn': return yellow500;
      case 'wt': return green500;
      case 'as': return blue500;
      case 'cf': return teal500;
      default:   return gray400;
    }
  }

  static String categoryLabel(String key) {
    switch (key) {
      case 'kr': return '한식';
      case 'jp': return '일식';
      case 'cn': return '중식';
      case 'wt': return '양식';
      case 'as': return '아시안';
      case 'cf': return '카페';
      default:   return '기타';
    }
  }
}

class OpusRadius {
  OpusRadius._();
  static const xs   = 2.0;
  static const sm   = 4.0;
  static const md   = 6.0;
  static const lg   = 8.0;
  static const xl   = 12.0;
  static const xl2  = 16.0;
  static const xl3  = 20.0;
  static const full = 1000.0;
}

class OpusSpace {
  OpusSpace._();
  static const xs2 = 2.0;
  static const xs  = 4.0;
  static const sm  = 8.0;
  static const md  = 12.0;
  static const lg  = 16.0;
  static const xl  = 24.0;
  static const xl2 = 32.0;
  static const xl3 = 40.0;
  static const xl4 = 48.0;
}

class OpusShadow {
  OpusShadow._();

  static List<BoxShadow> get xs => const [
        BoxShadow(color: Color(0x0D101828), blurRadius: 2, offset: Offset(0, 1)),
      ];
  static List<BoxShadow> get sm => const [
        BoxShadow(color: Color(0x1A101828), blurRadius: 3, offset: Offset(0, 1)),
        BoxShadow(color: Color(0x0F101828), blurRadius: 2, offset: Offset(0, 1)),
      ];
  static List<BoxShadow> get md => const [
        BoxShadow(color: Color(0x1A101828), blurRadius: 8, offset: Offset(0, 4), spreadRadius: -2),
        BoxShadow(color: Color(0x0F101828), blurRadius: 4, offset: Offset(0, 2), spreadRadius: -2),
      ];
  static List<BoxShadow> get lg => const [
        BoxShadow(color: Color(0x14101828), blurRadius: 16, offset: Offset(0, 12), spreadRadius: -4),
        BoxShadow(color: Color(0x08101828), blurRadius: 6, offset: Offset(0, 4), spreadRadius: -2),
      ];
}
