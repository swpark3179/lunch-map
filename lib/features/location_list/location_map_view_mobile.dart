import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';

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
  bool _isLocating = false;

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
    return Stack(
      children: [
        NaverMap(
          options: NaverMapViewOptions(
            initialCameraPosition: const NCameraPosition(
              target: NLatLng(kDefaultLat, kDefaultLng),
              zoom: kDefaultZoom,
            ),
            mapType: NMapType.basic,
            activeLayerGroups: const [NLayerGroup.building, NLayerGroup.transit],
            locationButtonEnable: false,
            consumeSymbolTapEvents: false,
          ),
          onMapReady: (controller) async {
            _controller = controller;
            await _redrawMarkers(controller);
          },
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'my_location_btn',
            backgroundColor: Colors.white,
            foregroundColor: Theme.of(context).colorScheme.primary,
            onPressed: _isLocating ? null : _moveToMyLocation,
            tooltip: '내 위치',
            child:
                _isLocating
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.my_location_rounded),
          ),
        ),
      ],
    );
  }

  Future<void> _moveToMyLocation() async {
    final controller = _controller;
    if (controller == null) return;

    setState(() => _isLocating = true);
    try {
      final position = await _resolveCurrentPosition();
      if (position == null) return;

      final target = NLatLng(position.latitude, position.longitude);
      await controller.updateCamera(
        NCameraUpdate.withParams(target: target, zoom: kDefaultZoom),
      );

      final marker = NCircleOverlay(
        id: 'my_location',
        center: target,
        radius: 8,
        color: const Color(0xFF2563EB),
        outlineColor: Colors.white,
        outlineWidth: 3,
      );
      await controller.deleteOverlay(
        NOverlayInfo(type: NOverlayType.circleOverlay, id: 'my_location'),
      );
      await controller.addOverlay(marker);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('현재 위치를 가져오지 못했습니다: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<Position?> _resolveCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치 서비스를 켜주세요.')),
        );
      }
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치 권한이 필요합니다.')),
        );
      }
      return null;
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
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
