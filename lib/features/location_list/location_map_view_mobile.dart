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
        await _redrawMarkers(controller);
      },
    );
  }

  Future<void> _redrawMarkers(NaverMapController controller) async {
    await controller.clearOverlays();
    await addSamsungRearGateOverlay(controller);

    if (!mounted) return;

    final fixedIcon = await _restaurantIcon(AppTheme.pinFixed);
    final unfixedIcon = await _restaurantIcon(AppTheme.pinUnfixed);

    final markers = <NMarker>{};
    for (final loc in widget.locations) {
      if (!loc.hasCoordinates) continue;
      final marker = NMarker(
        id: 'location_${loc.id}',
        position: NLatLng(loc.lat!, loc.lng!),
        icon: loc.isFixed ? fixedIcon : unfixedIcon,
        caption: NOverlayCaption(
          text: loc.name,
          textSize: 12,
          color: const Color(0xFF0F172A),
          haloColor: Colors.white,
        ),
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

  Future<NOverlayImage> _restaurantIcon(Color color) {
    return NOverlayImage.fromWidget(
      widget: _RestaurantMarkerIcon(color: color),
      size: const Size(36, 44),
      context: context,
    );
  }
}

class _RestaurantMarkerIcon extends StatelessWidget {
  final Color color;

  const _RestaurantMarkerIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MarkerTailPainter(color: color),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: const Icon(
            Icons.restaurant,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _MarkerTailPainter extends CustomPainter {
  final Color color;

  _MarkerTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width / 2 - 6, size.height - 10)
      ..lineTo(size.width / 2 + 6, size.height - 10)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MarkerTailPainter oldDelegate) =>
      oldDelegate.color != color;
}
