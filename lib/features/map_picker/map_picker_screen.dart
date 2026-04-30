import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/location.dart';
import '../../data/services/location_service.dart';
import '../../providers/location_provider.dart';

import 'map_picker_mobile.dart' if (dart.library.html) 'map_picker_web.dart';

/// 지도 기반 위치 선택 화면
class MapPickerScreen extends ConsumerStatefulWidget {
  final String? locationId;
  const MapPickerScreen({super.key, this.locationId});

  @override
  ConsumerState<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends ConsumerState<MapPickerScreen> {
  Location? _targetLocation;
  bool _isLoading = false;
  bool _isSaving = false;
  double _currentLat = 37.5665;
  double _currentLng = 126.9780;

  @override
  void initState() {
    super.initState();
    if (widget.locationId != null) _loadLocation();
  }

  Future<void> _loadLocation() async {
    setState(() => _isLoading = true);
    try {
      final loc = await LocationService.getById(widget.locationId!);
      if (loc != null && mounted) {
        setState(() {
          _targetLocation = loc;
          if (loc.hasCoordinates) {
            _currentLat = loc.lat!;
            _currentLng = loc.lng!;
          }
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  void _onCameraMove(double lat, double lng) {
    setState(() { _currentLat = lat; _currentLng = lng; });
  }

  Future<void> _saveLocation() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      if (widget.locationId != null) {
        await ref.read(locationListProvider.notifier)
            .updateCoordinates(widget.locationId!, _currentLat, _currentLng);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ 위치가 업데이트되었습니다!'), backgroundColor: Color(0xFF10B981)),
          );
          context.go('/locations');
        }
      } else {
        _showNewLocationDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  void _showNewLocationDialog() {
    final nameCtl = TextEditingController();
    final addrCtl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('새 장소 등록'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtl, decoration: const InputDecoration(labelText: '장소 이름 *', prefixIcon: Icon(Icons.restaurant)), autofocus: true),
            const SizedBox(height: 12),
            TextField(controller: addrCtl, decoration: const InputDecoration(labelText: '주소 (선택)', prefixIcon: Icon(Icons.place))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              final loc = Location(id: '', name: nameCtl.text.trim(), address: addrCtl.text.trim().isEmpty ? null : addrCtl.text.trim(), lat: _currentLat, lng: _currentLng, isFixed: true, createdAt: DateTime.now());
              await ref.read(locationListProvider.notifier).addLocation(loc);
              if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ "${nameCtl.text.trim()}" 등록됨'), backgroundColor: const Color(0xFF10B981))); context.go('/locations'); }
            },
            child: const Text('등록'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: const Text('지도 위치 선택')),
        body: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.map_rounded, size: 80, color: Colors.grey), SizedBox(height: 20), Text('네이버 지도는 모바일에서만\n사용 가능합니다.', textAlign: TextAlign.center, style: TextStyle(fontSize: 18))])),
      );
    }
    if (_isLoading) {
      return Scaffold(appBar: AppBar(title: const Text('지도 위치 선택')), body: const Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_targetLocation != null ? '${_targetLocation!.name} 위치 설정' : '새 장소 등록'),
        leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => context.go('/locations')),
      ),
      body: Stack(
        children: [
          MapPickerBody(initialLat: _currentLat, initialLng: _currentLng, onCameraIdle: _onCameraMove),
          // 중앙 고정 핀
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))]),
                    child: const Icon(Icons.location_on_rounded, size: 40, color: Colors.white),
                  ),
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.2), shape: BoxShape.circle)),
                ],
              ),
            ),
          ),
          // 하단 패널
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, -4))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                  if (_targetLocation?.name != null) ...[Text(_targetLocation!.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)), const SizedBox(height: 8)],
                  Container(
                    width: double.infinity, padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [Icon(Icons.gps_fixed_rounded, size: 20, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 10), Expanded(child: Text('위도: ${_currentLat.toStringAsFixed(6)}  |  경도: ${_currentLng.toStringAsFixed(6)}', style: const TextStyle(fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.w500)))]),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity, height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveLocation,
                      icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_rounded),
                      label: Text(_isSaving ? '저장 중...' : _targetLocation != null ? '이 위치로 확정' : '이 위치로 등록', style: const TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
