import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/location.dart';
import '../../data/services/naver_search_service.dart';
import '../../providers/location_provider.dart';

import 'location_map_view_stub.dart'
    if (dart.library.html) 'location_map_view_web.dart'
    if (dart.library.io) 'location_map_view_mobile.dart';

enum _ViewMode { map, list }

/// 장소 목록 화면 (지도뷰 / 리스트뷰)
class LocationListScreen extends ConsumerStatefulWidget {
  const LocationListScreen({super.key});

  @override
  ConsumerState<LocationListScreen> createState() => _LocationListScreenState();
}

class _LocationListScreenState extends ConsumerState<LocationListScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;
  // 기본은 지도뷰. (단, Web 환경에서는 네이버 지도를 사용할 수 없으므로 리스트뷰로 시작)
  _ViewMode _viewMode =
      (kIsWeb || (!Platform.isAndroid && !Platform.isIOS))
          ? _ViewMode.list
          : _ViewMode.map;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addFromNaver(NaverPlaceInfo place) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('식당 추가'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('"${place.title}"을(를) 목록에 추가하시겠습니까?'),
                if (place.roadAddress.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    place.roadAddress,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
                if (place.placeLat != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.my_location_rounded,
                        size: 14,
                        color: Colors.green[700],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '위치 좌표 자동 설정됨',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('추가'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    final hasCoords = place.placeLat != null && place.placeLng != null;
    final location = Location(
      id: '',
      name: place.title,
      address: place.roadAddress.isNotEmpty ? place.roadAddress : null,
      lat: place.placeLat,
      lng: place.placeLng,
      isFixed: hasCoords,
      createdAt: DateTime.now(),
    );

    await ref.read(locationListProvider.notifier).addLocation(location);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '"${place.title}" 추가됨${hasCoords ? " (위치 자동 설정)" : ""}',
        ),
        backgroundColor: Colors.green[700],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredLocations = ref.watch(filteredLocationListProvider);
    final currentFilter = ref.watch(locationFilterProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title:
            _isSearching
                ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: '장소 검색...',
                    border: InputBorder.none,
                    filled: false,
                  ),
                  onChanged: (value) {
                    ref.read(locationSearchProvider.notifier).state = value;
                  },
                )
                : const Text('장소 목록'),
        actions: [
          IconButton(
            tooltip: _viewMode == _ViewMode.map ? '리스트로 보기' : '지도로 보기',
            icon: Icon(
              _viewMode == _ViewMode.map
                  ? Icons.list_alt_rounded
                  : Icons.map_rounded,
            ),
            onPressed: () {
              setState(() {
                _viewMode =
                    _viewMode == _ViewMode.map ? _ViewMode.list : _ViewMode.map;
              });
            },
          ),
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search_rounded),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  ref.read(locationSearchProvider.notifier).state = '';
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.read(locationListProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── 네이버 식당 검색 패널 ──
          _NaverSearchPanel(onAdd: _addFromNaver),

          // ── 필터 칩 ──
          _FilterChips(
            currentFilter: currentFilter,
            onChanged: (filter) {
              ref.read(locationFilterProvider.notifier).state = filter;
            },
          ),

          // ── 본문 (지도 / 리스트) ──
          Expanded(
            child: filteredLocations.when(
              data: (locations) {
                if (_viewMode == _ViewMode.map) {
                  return _MapBody(
                    locations: locations,
                    onMarkerTap: (loc) => context.go('/location/${loc.id}'),
                  );
                }
                if (locations.isEmpty) {
                  return _EmptyState(
                    filter: currentFilter,
                    onAdd: () => context.go('/map-picker'),
                  );
                }
                return RefreshIndicator(
                  onRefresh:
                      () => ref.read(locationListProvider.notifier).refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: locations.length,
                    itemBuilder:
                        (context, index) => _LocationCard(
                          location: locations[index],
                          onTap:
                              () => context.go(
                                '/location/${locations[index].id}',
                              ),
                          onFixLocation: () {
                            context.go(
                              '/map-picker?locationId=${locations[index].id}',
                            );
                          },
                          onDelete:
                              () => _confirmDelete(
                                context,
                                ref,
                                locations[index],
                              ),
                        ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (error, _) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 64,
                          color: Colors.red[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '데이터를 불러오지 못했습니다',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          error.toString(),
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed:
                              () =>
                                  ref
                                      .read(locationListProvider.notifier)
                                      .refresh(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('다시 시도'),
                        ),
                      ],
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Location location,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('장소 삭제'),
            content: Text('"${location.name}" 장소를 삭제하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('삭제'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await ref.read(locationListProvider.notifier).deleteLocation(location.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('"${location.name}" 삭제됨')));
    }
  }
}

// ─── 네이버 식당 검색 패널 ───
class _NaverSearchPanel extends StatefulWidget {
  final Future<void> Function(NaverPlaceInfo) onAdd;

  const _NaverSearchPanel({required this.onAdd});

  @override
  State<_NaverSearchPanel> createState() => _NaverSearchPanelState();
}

class _NaverSearchPanelState extends State<_NaverSearchPanel> {
  final _controller = TextEditingController();
  List<NaverPlaceInfo> _results = [];
  bool _isLoading = false;
  bool _searched = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _isLoading = true;
      _searched = false;
      _results = [];
    });
    try {
      final results = await NaverSearchService.searchAll(q);
      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
          _searched = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clear() {
    _controller.clear();
    setState(() {
      _results = [];
      _searched = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        children: [
          // ── 검색창 ──
          TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: '네이버에서 식당 검색 후 추가 (예: 거북이식당)',
              prefixIcon: const Icon(Icons.storefront_rounded),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_controller.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: _clear,
                    ),
                  IconButton(
                    icon: const Icon(Icons.search_rounded, size: 20),
                    onPressed: _search,
                  ),
                ],
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),

          // ── 로딩 ──
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),

          // ── 검색 결과 없음 ──
          if (!_isLoading && _searched && _results.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '검색 결과가 없습니다',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),

          // ── 검색 결과 목록 ──
          if (!_isLoading && _results.isNotEmpty)
            Card(
              margin: const EdgeInsets.only(top: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 결과 헤더
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 12, 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.place_rounded,
                          size: 14,
                          color: const Color(0xFF03C75A),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '네이버 검색 결과 ${_results.length}건',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          onPressed: _clear,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // 결과 리스트 (최대 300px)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder:
                          (_, i) => _NaverResultTile(
                            place: _results[i],
                            onAdd: () async {
                              await widget.onAdd(_results[i]);
                              _clear();
                            },
                          ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── 네이버 검색 결과 타일 ───
class _NaverResultTile extends StatelessWidget {
  final NaverPlaceInfo place;
  final VoidCallback onAdd;

  const _NaverResultTile({required this.place, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      title: Row(
        children: [
          Expanded(
            child: Text(
              place.title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (place.placeLat != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Text(
                '📍 좌표',
                style: TextStyle(fontSize: 10, color: Colors.green[700]),
              ),
            ),
          ],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (place.category.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              place.category,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (place.roadAddress.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              place.roadAddress,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
      isThreeLine:
          place.category.isNotEmpty && place.roadAddress.isNotEmpty,
      trailing: TextButton(
        onPressed: onAdd,
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF03C75A),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: const Text(
          '추가',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ─── 지도뷰 본문 ───
class _MapBody extends StatelessWidget {
  final List<Location> locations;
  final void Function(Location location) onMarkerTap;

  const _MapBody({required this.locations, required this.onMarkerTap});

  @override
  Widget build(BuildContext context) {
    return LocationMapView(locations: locations, onMarkerTap: onMarkerTap);
  }
}

// ─── 필터 칩 ───
class _FilterChips extends StatelessWidget {
  final LocationFilter currentFilter;
  final ValueChanged<LocationFilter> onChanged;

  const _FilterChips({required this.currentFilter, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildChip(context, '전체', LocationFilter.all, Icons.apps_rounded),
          const SizedBox(width: 8),
          _buildChip(context, '확정', LocationFilter.fixed, Icons.check_circle),
          const SizedBox(width: 8),
          _buildChip(context, '미확정', LocationFilter.unfixed, Icons.pending),
        ],
      ),
    );
  }

  Widget _buildChip(
    BuildContext context,
    String label,
    LocationFilter filter,
    IconData icon,
  ) {
    final isSelected = currentFilter == filter;
    final theme = Theme.of(context);

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : theme.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (_) => onChanged(filter),
      selectedColor: theme.colorScheme.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : theme.colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      showCheckmark: false,
    );
  }
}

// ─── 장소 카드 ───
class _LocationCard extends StatelessWidget {
  final Location location;
  final VoidCallback onTap;
  final VoidCallback onFixLocation;
  final VoidCallback onDelete;

  const _LocationCard({
    required this.location,
    required this.onTap,
    required this.onFixLocation,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 상태 아이콘
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color:
                      location.isFixed
                          ? AppTheme.pinFixed.withValues(alpha: 0.1)
                          : AppTheme.pinUnfixed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  location.isFixed
                      ? Icons.location_on_rounded
                      : Icons.location_off_rounded,
                  color:
                      location.isFixed
                          ? AppTheme.pinFixed
                          : AppTheme.pinUnfixed,
                ),
              ),
              const SizedBox(width: 14),

              // 장소 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            location.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color:
                                location.isFixed
                                    ? AppTheme.pinFixed.withValues(alpha: 0.1)
                                    : AppTheme.pinUnfixed.withValues(
                                      alpha: 0.1,
                                    ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            location.isFixed ? '확정' : '미확정',
                            style: TextStyle(
                              fontSize: 11,
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
                    if (location.address != null &&
                        location.address!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        location.address!,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (location.hasCoordinates) ...[
                      const SizedBox(height: 2),
                      Text(
                        '📍 ${location.lat!.toStringAsFixed(6)}, ${location.lng!.toStringAsFixed(6)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[500],
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // 액션 메뉴
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 20),
                itemBuilder:
                    (context) => [
                      if (!location.isFixed)
                        const PopupMenuItem(
                          value: 'fix',
                          child: Row(
                            children: [
                              Icon(Icons.map_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('위치 설정'),
                            ],
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Colors.red,
                            ),
                            SizedBox(width: 8),
                            Text('삭제', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                onSelected: (value) {
                  switch (value) {
                    case 'fix':
                      onFixLocation();
                      break;
                    case 'delete':
                      onDelete();
                      break;
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 빈 상태 ───
class _EmptyState extends StatelessWidget {
  final LocationFilter filter;
  final VoidCallback onAdd;

  const _EmptyState({required this.filter, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String message;
    IconData icon;

    switch (filter) {
      case LocationFilter.fixed:
        message = '위치가 확정된 장소가 없습니다';
        icon = Icons.check_circle_outline;
        break;
      case LocationFilter.unfixed:
        message = '위치 미확정 장소가 없습니다';
        icon = Icons.pending_outlined;
        break;
      default:
        message = '등록된 장소가 없습니다';
        icon = Icons.place_outlined;
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 56, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 20),
          Text(message, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('지도에서 장소를 추가해보세요', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_location_alt_rounded),
            label: const Text('지도에서 등록'),
          ),
        ],
      ),
    );
  }
}
