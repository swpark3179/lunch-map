import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/location.dart';
import '../../providers/location_provider.dart';

/// 장소 목록 화면
class LocationListScreen extends ConsumerStatefulWidget {
  const LocationListScreen({super.key});

  @override
  ConsumerState<LocationListScreen> createState() => _LocationListScreenState();
}

class _LocationListScreenState extends ConsumerState<LocationListScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredLocations = ref.watch(filteredLocationListProvider);
    final currentFilter = ref.watch(locationFilterProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
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
          // ── 필터 칩 ──
          _FilterChips(
            currentFilter: currentFilter,
            onChanged: (filter) {
              ref.read(locationFilterProvider.notifier).state = filter;
            },
          ),

          // ── 목록 ──
          Expanded(
            child: filteredLocations.when(
              data: (locations) {
                if (locations.isEmpty) {
                  return _EmptyState(
                    filter: currentFilter,
                    onUpload: () => context.go('/upload'),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(locationListProvider.notifier).refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: locations.length,
                    itemBuilder: (context, index) => _LocationCard(
                      location: locations[index],
                      onTap: () => context.go(
                        '/location/${locations[index].id}',
                      ),
                      onFixLocation: () {
                        context.go(
                          '/map-picker?locationId=${locations[index].id}',
                        );
                      },
                      onDelete: () => _confirmDelete(
                        context,
                        ref,
                        locations[index],
                      ),
                    ),
                  ),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, _) => Center(
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
                      onPressed: () =>
                          ref.read(locationListProvider.notifier).refresh(),
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
      builder: (context) => AlertDialog(
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

    if (confirmed == true && mounted) {
      await ref.read(locationListProvider.notifier).deleteLocation(location.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${location.name}" 삭제됨')),
        );
      }
    }
  }
}

// ─── 필터 칩 ───
class _FilterChips extends StatelessWidget {
  final LocationFilter currentFilter;
  final ValueChanged<LocationFilter> onChanged;

  const _FilterChips({
    required this.currentFilter,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildChip(context, '전체', LocationFilter.all, Icons.apps_rounded),
          const SizedBox(width: 8),
          _buildChip(
              context, '확정', LocationFilter.fixed, Icons.check_circle),
          const SizedBox(width: 8),
          _buildChip(
              context, '미확정', LocationFilter.unfixed, Icons.pending),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
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
                  color: location.isFixed
                      ? AppTheme.pinFixed.withValues(alpha: 0.1)
                      : AppTheme.pinUnfixed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  location.isFixed
                      ? Icons.location_on_rounded
                      : Icons.location_off_rounded,
                  color:
                      location.isFixed ? AppTheme.pinFixed : AppTheme.pinUnfixed,
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
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
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
                            color: location.isFixed
                                ? AppTheme.pinFixed.withValues(alpha: 0.1)
                                : AppTheme.pinUnfixed.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            location.isFixed ? '확정' : '미확정',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: location.isFixed
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
                itemBuilder: (context) => [
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
                        Icon(Icons.delete_outline, size: 18, color: Colors.red),
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
  final VoidCallback onUpload;

  const _EmptyState({required this.filter, required this.onUpload});

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
          Text(
            '엑셀 파일로 장소를 업로드해보세요',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onUpload,
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('엑셀 업로드'),
          ),
        ],
      ),
    );
  }
}
