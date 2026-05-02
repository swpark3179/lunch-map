import 'package:flutter/material.dart';

import '../../data/models/location.dart';

/// 비지원 플랫폼(Windows 등)용 지도뷰 플레이스홀더
class LocationMapView extends StatelessWidget {
  final List<Location> locations;
  final void Function(Location location) onMarkerTap;

  const LocationMapView({
    super.key,
    required this.locations,
    required this.onMarkerTap,
  });

  @override
  Widget build(BuildContext context) {
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
}
