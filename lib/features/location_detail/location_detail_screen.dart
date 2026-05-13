import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/location.dart';
import '../../data/services/location_service.dart';
import '../../data/services/naver_search_service.dart';

/// 장소 상세 화면
class LocationDetailScreen extends ConsumerStatefulWidget {
  final String locationId;

  const LocationDetailScreen({super.key, required this.locationId});

  @override
  ConsumerState<LocationDetailScreen> createState() =>
      _LocationDetailScreenState();
}

class _LocationDetailScreenState extends ConsumerState<LocationDetailScreen> {
  Location? _location;
  bool _isLoading = true;
  String? _error;

  NaverPlaceInfo? _placeInfo;
  bool _isMenuLoading = false;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final location = await LocationService.getById(widget.locationId);
      setState(() {
        _location = location;
        _isLoading = false;
      });
      if (location != null) {
        _loadMenu(location.name, lat: location.lat, lng: location.lng);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMenu(
    String restaurantName, {
    double? lat,
    double? lng,
  }) async {
    setState(() => _isMenuLoading = true);
    try {
      final info = await NaverSearchService.fetchPlaceInfo(
        restaurantName,
        lat: lat,
        lng: lng,
      );
      if (mounted) {
        setState(() {
          _placeInfo = info;
          _isMenuLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isMenuLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('장소 상세')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _location == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('장소 상세')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(_error ?? '장소를 찾을 수 없습니다'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/locations'),
                child: const Text('목록으로 돌아가기'),
              ),
            ],
          ),
        ),
      );
    }

    final location = _location!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('장소 상세'),
        actions: [
          if (!location.isFixed)
            TextButton.icon(
              onPressed: () {
                context.go('/map-picker?locationId=${location.id}');
              },
              icon: const Icon(Icons.map_rounded),
              label: const Text('위치 설정'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 헤더 카드 ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors:
                      location.isFixed
                          ? [
                            const Color(0xFF10B981).withValues(alpha: 0.15),
                            const Color(0xFF059669).withValues(alpha: 0.05),
                          ]
                          : [
                            const Color(0xFFF59E0B).withValues(alpha: 0.15),
                            const Color(0xFFD97706).withValues(alpha: 0.05),
                          ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (location.isFixed
                          ? AppTheme.pinFixed
                          : AppTheme.pinUnfixed)
                      .withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (location.isFixed
                                  ? AppTheme.pinFixed
                                  : AppTheme.pinUnfixed)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          location.isFixed
                              ? Icons.location_on_rounded
                              : Icons.location_off_rounded,
                          color:
                              location.isFixed
                                  ? AppTheme.pinFixed
                                  : AppTheme.pinUnfixed,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              location.name,
                              style: theme.textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: (location.isFixed
                                        ? AppTheme.pinFixed
                                        : AppTheme.pinUnfixed)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                location.isFixed ? '✅ 위치 확정' : '⏳ 위치 미확정',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      location.isFixed
                                          ? AppTheme.pinFixed
                                          : AppTheme.pinUnfixed,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── 상세 정보 ──
            _DetailSection(
              title: '기본 정보',
              children: [
                _DetailRow(
                  icon: Icons.badge_outlined,
                  label: 'ID',
                  value: location.id,
                ),
                if (location.address != null) ...[
                  _DetailRow(
                    icon: Icons.place_outlined,
                    label: '주소',
                    value: location.address!,
                  ),
                ],
                _DetailRow(
                  icon: Icons.calendar_today_outlined,
                  label: '등록일',
                  value: _formatDate(location.createdAt),
                ),
              ],
            ),

            const SizedBox(height: 16),

            if (location.hasCoordinates)
              _DetailSection(
                title: '좌표 정보',
                children: [
                  _DetailRow(
                    icon: Icons.north_rounded,
                    label: '위도 (Latitude)',
                    value: location.lat!.toStringAsFixed(8),
                  ),
                  _DetailRow(
                    icon: Icons.east_rounded,
                    label: '경도 (Longitude)',
                    value: location.lng!.toStringAsFixed(8),
                  ),
                ],
              ),

            if (!location.hasCoordinates)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 40,
                      color: Color(0xFFD97706),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '좌표가 아직 설정되지 않았습니다',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF92400E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '지도에서 정확한 위치를 선택해주세요',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFB45309),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        context.go('/map-picker?locationId=${location.id}');
                      },
                      icon: const Icon(Icons.map_rounded),
                      label: const Text('지도에서 위치 설정'),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // ── 메뉴 정보 ──
            _MenuSection(
              isLoading: _isMenuLoading,
              placeInfo: _placeInfo,
              onRetry: () => _loadMenu(location.name, lat: location.lat, lng: location.lng),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}년 ${date.month}월 ${date.day}일 '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// ─── 메뉴 섹션 ───
class _MenuSection extends StatelessWidget {
  final bool isLoading;
  final NaverPlaceInfo? placeInfo;
  final VoidCallback onRetry;

  const _MenuSection({
    required this.isLoading,
    required this.placeInfo,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.restaurant_menu_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '메뉴 정보',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '출처: 네이버',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (placeInfo == null)
              _EmptyMenu(onRetry: onRetry)
            else
              _PlaceInfoContent(placeInfo: placeInfo!, onRetry: onRetry),
          ],
        ),
      ),
    );
  }
}

class _PlaceInfoContent extends StatelessWidget {
  final NaverPlaceInfo placeInfo;
  final VoidCallback onRetry;

  const _PlaceInfoContent({required this.placeInfo, required this.onRetry});

  Future<void> _openNaverPlace() async {
    final uri = Uri.parse(placeInfo.link);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      // 열기 실패 시 무시
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (placeInfo.category.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.category_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    placeInfo.category,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        if (placeInfo.telephone.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.phone_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    placeInfo.telephone,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        if (placeInfo.hasDescription) ...[
          const Divider(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.menu_book_outlined,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  placeInfo.description,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ] else
          Text(
            '메뉴 설명 정보가 없습니다',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        if (placeInfo.hasLink) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openNaverPlace,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('네이버지도에서 보기'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF03C75A),
                side: const BorderSide(color: Color(0xFF03C75A)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _EmptyMenu extends StatelessWidget {
  final VoidCallback onRetry;

  const _EmptyMenu({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(
          Icons.search_off_rounded,
          size: 40,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 8),
        Text(
          '메뉴 정보를 불러올 수 없습니다',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('다시 시도'),
        ),
      ],
    );
  }
}

// ─── 상세 섹션 ───
class _DetailSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DetailSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

// ─── 상세 행 ───
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
