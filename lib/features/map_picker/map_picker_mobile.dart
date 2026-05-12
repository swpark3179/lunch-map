import 'dart:io';
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
    if (!Platform.isAndroid && !Platform.isIOS) {
      return Container(
        color: const Color(0xFFF1F5F9),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_outlined, size: 80, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                '현재 플랫폼에서는 네이버 지도를\n사용할 수 없습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }
    return NaverMap(
      options: NaverMapViewOptions(
        initialCameraPosition: NCameraPosition(
          target: NLatLng(widget.initialLat, widget.initialLng),
          zoom: kDefaultZoom,
        ),
        mapType: NMapType.basic,
        activeLayerGroups: const [NLayerGroup.building, NLayerGroup.transit],
        locationButtonEnable: true,
        consumeSymbolTapEvents: false,
      ),
      onMapReady: (controller) {
        _controller = controller;
        addSamsungRearGateOverlay(controller);
      },
      onCameraIdle: () async {
        if (_controller != null) {
          final position = await _controller!.getCameraPosition();
          if (mounted) {
            widget.onCameraIdle(
              position.target.latitude,
              position.target.longitude,
            );
          }
        }
      },
    );
  }
}

/// "삼성중공업 후문" 영역 + 기본 경로 영역을 지도 위에 표시
Future<void> addSamsungRearGateOverlay(NaverMapController controller) async {
  if (!Platform.isAndroid && !Platform.isIOS) return;

  // NPolygonOverlay 대신 NCircleOverlay 사용: iOS 측 NPolygonOverlay
  // createMapOverlay()가 NMFPolygonOverlay 초기화 결과를 강제 언래핑(`!`)하다
  // nil이 반환되면 앱이 죽는 이슈를 회피한다.
  final area = NCircleOverlay(
    id: 'samsung_rear_gate_area',
    center: const NLatLng(kSamsungRearGateLat, kSamsungRearGateLng),
    radius: kSamsungRearGateRadiusMeters,
    color: const Color(0x332563EB),
    outlineColor: const Color(0xFF2563EB),
    outlineWidth: 2,
  );

  // 기본 경로 영역: 지정 좌표를 순서대로 이은 뒤 후문 영역 중심과 자연스럽게 연결
  final pathwayCoords = <NLatLng>[
    for (final p in kDefaultPathwayCoords) NLatLng(p[0], p[1]),
    const NLatLng(kSamsungRearGateLat, kSamsungRearGateLng),
  ];
  final pathway = NPathOverlay(
    id: 'default_pathway_area',
    coords: pathwayCoords,
    color: const Color(0x552563EB),
    outlineColor: const Color(0x552563EB),
    width: 10,
    outlineWidth: 0,
  );

  await controller.addOverlay(pathway);
  await controller.addOverlay(area);
}
