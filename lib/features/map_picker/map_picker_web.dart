import 'package:flutter/material.dart';

/// Web 환경용 지도 플레이스홀더
/// Web에서는 네이버 지도 SDK를 사용할 수 없으므로 안내 메시지를 표시
class MapPickerBody extends StatelessWidget {
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
              '웹 환경에서는 네이버 지도를\n사용할 수 없습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
