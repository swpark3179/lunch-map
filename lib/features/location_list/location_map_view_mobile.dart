import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../../core/constants/map_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/location.dart';
import '../map_picker/map_picker_mobile.dart' show addSamsungRearGateOverlay;
import 'location_map_view_stub.dart' as stub;

/// 모바일용 장소 목록 지도뷰
class LocationMapView extends StatefulWidget {
  final List<Location> locations;
  final void Function(Location location) onMarkerTap;

  const LocationMapView({
    super.key,
    required this.locations,
    required this.onMarkerTap,
  });

  @override
  State<LocationMapView> createState() => _LocationMapViewState();
}

class _LocationMapViewState extends State<LocationMapView> {
  NaverMapController? _controller;

  @override
  void didUpdateWidget(covariant LocationMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller != null && oldWidget.locations != widget.locations) {
      if (Platform.isAndroid || Platform.isIOS) {
        _redrawMarkers(_controller!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return stub.LocationMapView(
        locations: widget.locations,
        onMarkerTap: widget.onMarkerTap,
      );
    }
    return NaverMap(
      options: NaverMapViewOptions(
        initialCameraPosition: const NCameraPosition(
          target: NLatLng(kDefaultLat, kDefaultLng),
          zoom: kDefaultZoom,
        ),
        mapType: NMapType.basic,
        activeLayerGroups: const [NLayerGroup.building, NLayerGroup.transit],
        locationButtonEnable: true,
        consumeSymbolTapEvents: false,
      ),
      onMapReady: (controller) async {
        _controller = controller;
        await addSamsungRearGateOverlay(controller);
        await _redrawMarkers(controller);
      },
    );
  }

  Future<void> _redrawMarkers(NaverMapController controller) async {
    await controller.clearOverlays(type: NOverlayType.marker);
    // 삼성중공업 후문 마커는 별도 id 라 다시 그려야 함
    await addSamsungRearGateOverlay(controller);

    final markers = <NMarker>{};
    for (final loc in widget.locations) {
      if (!loc.hasCoordinates) continue;
      final marker = NMarker(
        id: 'location_${loc.id}',
        position: NLatLng(loc.lat!, loc.lng!),
        caption: NOverlayCaption(
          text: loc.name,
          textSize: 12,
          color: const Color(0xFF0F172A),
          haloColor: Colors.white,
        ),
        iconTintColor: loc.isFixed ? AppTheme.pinFixed : AppTheme.pinUnfixed,
      );
      marker.setOnTapListener((overlay) {
        widget.onMarkerTap(loc);
      });
      markers.add(marker);
    }
    if (markers.isNotEmpty) {
      await controller.addOverlayAll(markers);
    }
  }
}
