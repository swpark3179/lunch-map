import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/opus_tokens.dart';
import '../../data/models/location.dart';
import '../../data/models/menu.dart';
import '../../data/services/menu_service.dart';
import '../../providers/location_provider.dart';
import '../redesign/widgets/opus_widgets.dart';

/// 홈 (Map) 화면 — OPUS-X redesign.
///
/// 디자인 mock 의 `screen-map` 을 Flutter 로 옮긴 것. 전체 화면 지도 위에
/// 검색바, 카테고리 칩, 예산 추천 CTA, 선택된 식당의 바텀시트를 표시한다.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _filter = 'all';
  String? _selectedId;

  static const _categories = [
    ['all', '전체'],
    ['kr', '한식'],
    ['jp', '일식'],
    ['cn', '중식'],
    ['wt', '양식'],
    ['as', '아시안'],
    ['cf', '카페'],
  ];

  @override
  Widget build(BuildContext context) {
    final locations = ref.watch(locationListProvider);
    final canRegisterOnMap =
        !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    return Scaffold(
      backgroundColor: const Color(0xFFEEF1F5),
      body: locations.when(
        data: (all) {
          final filtered = _filter == 'all'
              ? all
              : all.where((l) => l.category == _filter).toList();
          final selected = filtered.firstWhere(
            (l) => l.id == _selectedId,
            orElse: () => filtered.isEmpty ? _placeholder() : filtered.first,
          );
          return _Body(
            allLocations: all,
            filteredLocations: filtered,
            selected: filtered.isEmpty ? null : selected,
            filter: _filter,
            categories: _categories,
            onFilterChange: (k) => setState(() => _filter = k),
            onSelect: (id) => setState(() => _selectedId = id),
            onOpenList: () => context.go('/locations'),
            onOpenRegister: () => canRegisterOnMap
                ? context.go('/map-picker')
                : ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('지도 등록은 모바일 앱에서 가능합니다.')),
                  ),
            onOpenBudget: () => context.go('/budget'),
            onOpenDetail: (id) => context.go('/location/$id'),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorBlock(
          message: '데이터를 불러오지 못했습니다',
          detail: e.toString(),
          onRetry: () => ref.read(locationListProvider.notifier).refresh(),
        ),
      ),
    );
  }

  Location _placeholder() => Location(
        id: 'placeholder',
        name: '아직 등록된 식당이 없어요',
        createdAt: DateTime.now(),
      );
}

class _Body extends StatelessWidget {
  final List<Location> allLocations;
  final List<Location> filteredLocations;
  final Location? selected;
  final String filter;
  final List<List<String>> categories;
  final ValueChanged<String> onFilterChange;
  final ValueChanged<String> onSelect;
  final VoidCallback onOpenList;
  final VoidCallback onOpenRegister;
  final VoidCallback onOpenBudget;
  final ValueChanged<String> onOpenDetail;

  const _Body({
    required this.allLocations,
    required this.filteredLocations,
    required this.selected,
    required this.filter,
    required this.categories,
    required this.onFilterChange,
    required this.onSelect,
    required this.onOpenList,
    required this.onOpenRegister,
    required this.onOpenBudget,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    // 핀 좌표 — 위치가 있는 식당만 정규화해서 표시한다.
    final geo = filteredLocations
        .where((l) => l.hasCoordinates)
        .toList(growable: false);
    final pins = _normalizePins(geo);
    final selectedIndex = selected == null
        ? null
        : geo.indexWhere((l) => l.id == selected!.id);

    return Stack(
      children: [
        Positioned.fill(
          child: StaticMapPreview(
            pins: pins,
            selectedIndex:
                (selectedIndex != null && selectedIndex >= 0) ? selectedIndex : null,
            onPinTap: (i) => onSelect(geo[i].id),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          top: MediaQuery.of(context).padding.top + 8,
          child: _TopBar(
            filter: filter,
            categories: categories,
            onFilterChange: onFilterChange,
            onOpenList: onOpenList,
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 232,
          child: _BudgetCta(onTap: onOpenBudget),
        ),
        Positioned(
          right: 16,
          bottom: 308,
          child: Column(
            children: [
              _FabIcon(icon: Icons.add_rounded, onTap: onOpenRegister),
              const SizedBox(height: 10),
              _FabIcon(
                icon: Icons.near_me_rounded,
                onTap: () {},
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _BottomSheet(
            selected: selected,
            onOpenDetail: onOpenDetail,
          ),
        ),
      ],
    );
  }

  List<Offset> _normalizePins(List<Location> geo) {
    if (geo.isEmpty) return const [];
    final lats = geo.map((l) => l.lat!).toList();
    final lngs = geo.map((l) => l.lng!).toList();
    final minLat = lats.reduce((a, b) => a < b ? a : b);
    final maxLat = lats.reduce((a, b) => a > b ? a : b);
    final minLng = lngs.reduce((a, b) => a < b ? a : b);
    final maxLng = lngs.reduce((a, b) => a > b ? a : b);
    double rangeLat = (maxLat - minLat).abs();
    double rangeLng = (maxLng - minLng).abs();
    if (rangeLat < 0.0001) rangeLat = 0.0001;
    if (rangeLng < 0.0001) rangeLng = 0.0001;
    return [
      for (final l in geo)
        Offset(
          ((l.lng! - minLng) / rangeLng).clamp(0.05, 0.95),
          // 위도는 위쪽이 큰 값이므로 반전
          (1 - (l.lat! - minLat) / rangeLat).clamp(0.1, 0.85),
        ),
    ];
  }
}

class _TopBar extends StatelessWidget {
  final String filter;
  final List<List<String>> categories;
  final ValueChanged<String> onFilterChange;
  final VoidCallback onOpenList;

  const _TopBar({
    required this.filter,
    required this.categories,
    required this.onFilterChange,
    required this.onOpenList,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: OpusShadow.md,
            border: Border.all(color: OpusColors.gray100),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.search_rounded,
                  size: 18, color: OpusColors.gray500),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '식당, 메뉴 검색',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: OpusColors.gray400,
                  ),
                ),
              ),
              Material(
                color: OpusColors.gray100,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: onOpenList,
                  borderRadius: BorderRadius.circular(8),
                  child: const SizedBox(
                    width: 32,
                    height: 32,
                    child: Icon(Icons.list_rounded,
                        size: 18, color: OpusColors.gray700),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 32,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final k = categories[i][0];
              final label = categories[i][1];
              return OpusChip(
                label: label,
                active: filter == k,
                onTap: () => onFilterChange(k),
                leading: k == 'all' ? null : CategoryDot(categoryKey: k, size: 6),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FabIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _FabIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: OpusColors.gray700, size: 22),
        ),
      ),
    );
  }
}

class _BudgetCta extends StatelessWidget {
  final VoidCallback onTap;
  const _BudgetCta({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: OpusColors.gray900,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: OpusColors.purple500,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.account_balance_wallet_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '예산으로 메뉴 추천받기',
                      style: GoogleFonts.notoSansKr(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '오늘 점심값을 입력하세요',
                      style: GoogleFonts.notoSansKr(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: OpusColors.gray400, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomSheet extends StatelessWidget {
  final Location? selected;
  final ValueChanged<String> onOpenDetail;

  const _BottomSheet({required this.selected, required this.onOpenDetail});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(OpusRadius.xl3)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14101828),
            blurRadius: 30,
            offset: Offset(0, -8),
          ),
        ],
      ),
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: OpusColors.gray200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          if (selected == null)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                '카테고리에 해당하는 식당이 없어요.',
                style: GoogleFonts.notoSansKr(
                  fontSize: 13,
                  color: OpusColors.gray500,
                ),
              ),
            )
          else
            _SelectedCard(selected: selected!, onOpenDetail: onOpenDetail),
        ],
      ),
    );
  }
}

class _SelectedCard extends StatelessWidget {
  final Location selected;
  final ValueChanged<String> onOpenDetail;

  const _SelectedCard({required this.selected, required this.onOpenDetail});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: selected.id == 'placeholder' ? null : () => onOpenDetail(selected.id),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (selected.category != null)
                  OpusBadge(
                    text: OpusColors.categoryLabel(selected.category!),
                    variant: BadgeVariant.primary,
                    dot: true,
                  ),
                const SizedBox(width: 6),
                if (selected.isFixed)
                  const OpusBadge(
                      text: '위치 확정', variant: BadgeVariant.success),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              selected.name,
              style: GoogleFonts.notoSansKr(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: OpusColors.gray900,
                letterSpacing: -0.2,
              ),
            ),
            if (selected.address != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  selected.address!,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 12,
                    color: OpusColors.gray500,
                  ),
                ),
              ),
            if (selected.id != 'placeholder')
              _MenuPreview(locationId: selected.id),
          ],
        ),
      ),
    );
  }
}

class _MenuPreview extends StatefulWidget {
  final String locationId;
  const _MenuPreview({required this.locationId});

  @override
  State<_MenuPreview> createState() => _MenuPreviewState();
}

class _MenuPreviewState extends State<_MenuPreview> {
  late Future<List<MenuItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = MenuService.getByLocation(widget.locationId);
  }

  @override
  void didUpdateWidget(covariant _MenuPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.locationId != widget.locationId) {
      _future = MenuService.getByLocation(widget.locationId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MenuItem>>(
      future: _future,
      builder: (context, snap) {
        final menus = snap.data ?? const <MenuItem>[];
        if (menus.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final m in menus.take(3))
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: OpusColors.gray50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: OpusColors.gray100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        m.name,
                        style: GoogleFonts.notoSansKr(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: OpusColors.gray700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      PriceText(won: m.price, size: 11),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  final String message;
  final String detail;
  final VoidCallback onRetry;

  const _ErrorBlock(
      {required this.message, required this.detail, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 48, color: OpusColors.red500),
          const SizedBox(height: 12),
          Text(message, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(detail,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
}
