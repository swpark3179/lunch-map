import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../../core/constants/map_constants.dart';

/// 모바일용 네이버 지도 위젯
class MapPickerBody extends StatefulWidget {
  final double initialLat;
  final double initialLng;
  final void Function(double lat, double lng) onCameraIdle;

  const MapPickerBody({
    super.key,
    required this.initialLat,
    required this.initialLng,
    required this.onCameraIdle,
  });

  @override
  State<MapPickerBody> createState() => _MapPickerBodyState();
}

class _MapPickerBodyState extends State<MapPickerBody> {
  NaverMapController? _controller;

  @override
  Widget build(BuildContext context) {
    return NaverMap(
      options: NaverMapViewOptions(
        initialCameraPosition: NCameraPosition(
          target: NLatLng(widget.initialLat, widget.initialLng),
          zoom: kDefaultZoom,
        ),
        mapType: NMapType.basic,
        activeLayerGroups: [NLayerGroup.building, NLayerGroup.transit],
        locationButtonEnable: true,
        consumeSymbolTapEvents: false,
      ),
      onMapReady: (controller) {
        _controller = controller;
        addSamsungRearGateOverlay(controller);
      },
      onCameraIdle: () {
        if (_controller != null) {
          final position = _controller!.nowCameraPosition;
          widget.onCameraIdle(
            position.target.latitude,
            position.target.longitude,
          );
        }
      },
    );
  }
}

/// "삼성중공업 후문" 사각형 영역 + 라벨을 지도 위에 표시
Future<void> addSamsungRearGateOverlay(NaverMapController controller) async {
  final south = kSamsungRearGateLat - kSamsungRearGateHalfDeltaLat;
  final north = kSamsungRearGateLat + kSamsungRearGateHalfDeltaLat;
  final west = kSamsungRearGateLng - kSamsungRearGateHalfDeltaLng;
  final east = kSamsungRearGateLng + kSamsungRearGateHalfDeltaLng;

  final polygon = NPolygonOverlay(
    id: 'samsung_rear_gate_area',
    coords: [
      NLatLng(north, west),
      NLatLng(north, east),
      NLatLng(south, east),
      NLatLng(south, west),
    ],
    color: const Color(0x332563EB),
    outlineColor: const Color(0xFF2563EB),
    outlineWidth: 2,
  );

  final marker = NMarker(
    id: 'samsung_rear_gate_marker',
    position: const NLatLng(kSamsungRearGateLat, kSamsungRearGateLng),
    caption: const NOverlayCaption(
      text: kSamsungRearGateLabel,
      textSize: 14,
      color: Color(0xFF0F172A),
      haloColor: Colors.white,
    ),
    iconTintColor: const Color(0xFF2563EB),
  );

  await controller.addOverlayAll({polygon, marker});
}
