import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/map_constants.dart';
import '../../data/models/location.dart';
import '../../data/services/location_service.dart';
import '../../data/services/naver_search_service.dart';
import '../../providers/location_provider.dart';

import 'map_picker_mobile.dart' if (dart.library.html) 'map_picker_web.dart';

/// 장소 등록 / 위치 설정 통합 화면.
///
/// - `locationId == null` 신규 등록 모드: 네이버 검색 결과를 골라 자동 입력하거나,
///   지도 중심 핀으로 임의 위치를 지정하고 이름/주소를 직접 입력해 등록한다.
/// - `locationId != null` 좌표 갱신 모드: 기존 장소의 좌표만 업데이트한다.
class MapPickerScreen extends ConsumerStatefulWidget {
  final String? locationId;
  const MapPickerScreen({super.key, this.locationId});

  @override
  ConsumerState<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends ConsumerState<MapPickerScreen> {
  // ── 공통 상태 ────────────────────────────────────────────
  Location? _targetLocation;
  bool _isLoading = false;
  bool _isSaving = false;
  double _currentLat = kDefaultLat;
  double _currentLng = kDefaultLng;

  /// 모바일 지도 카메라 이동 명령 채널 (Naver 검색 결과 선택 시 사용)
  final ValueNotifier<({double lat, double lng})?> _cameraTarget =
      ValueNotifier(null);

  // ── 신규 등록 모드 입력 ──────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  /// 네이버 검색 결과를 통해 좌표를 받았는지 여부.
  /// 모바일에서 지도를 한 번도 움직이지 않은 상태에서도 좌표를 사용할 수 있다.
  bool _hasCoordsFromNaver = false;

  /// 네이버 지도 POI 심볼을 탭해 선택한 식당 정보(중복 방지를 위해 좌표는 네이버
  /// POI 좌표를 그대로 사용한다).
  String? _linkedNaverPlaceName;

  // ── 네이버 검색 상태 ────────────────────────────────────
  final _searchCtrl = TextEditingController();
  List<NaverPlaceInfo> _naverResults = const [];
  bool _isSearching = false;
  bool _hasSearched = false;
  bool _searchHadError = false;
  bool _resultsExpanded = true;

  bool get _isFixMode => widget.locationId != null;
  bool get _canUseMap =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  void initState() {
    super.initState();
    if (_isFixMode) _loadLocation();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _searchCtrl.dispose();
    _cameraTarget.dispose();
    super.dispose();
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
    setState(() {
      _currentLat = lat;
      _currentLng = lng;
    });
  }

  // ── 네이버 검색 ────────────────────────────────────────
  Future<void> _runSearch() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _isSearching = true;
      _hasSearched = false;
      _searchHadError = false;
      _naverResults = const [];
      _resultsExpanded = true;
    });
    try {
      final results = await NaverSearchService.searchAll(q);
      if (!mounted) return;
      setState(() {
        _naverResults = results;
        _isSearching = false;
        _hasSearched = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _hasSearched = true;
        _searchHadError = true;
      });
    }
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() {
      _naverResults = const [];
      _hasSearched = false;
      _searchHadError = false;
    });
  }

  /// 네이버 지도 위의 식당 POI 심볼을 탭했을 때 호출.
  /// 좌표는 네이버 POI의 좌표를 그대로 사용해 중복 등록(같은 식당을 다른
  /// 좌표로 수동 등록)을 방지한다. 이름은 심볼 캡션을 즉시 채우고,
  /// 주소/전화번호는 네이버 Local Search로 비동기 보강한다.
  void _onNaverSymbolTap(String caption, double lat, double lng) {
    if (_isFixMode) return;
    final name = caption.trim();
    if (name.isEmpty) return;

    _nameCtrl.text = name;
    _currentLat = lat;
    _currentLng = lng;
    _hasCoordsFromNaver = true;
    _cameraTarget.value = (lat: lat, lng: lng);

    setState(() {
      _linkedNaverPlaceName = name;
      _resultsExpanded = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"$name" 네이버 지도와 연결됨. 정보를 확인하고 등록하세요.'),
        backgroundColor: const Color(0xFF03C75A),
      ),
    );

    // 주소/전화번호 보강 (실패해도 등록은 가능)
    _enrichFromNaverSearch(name, lat, lng);
  }

  Future<void> _enrichFromNaverSearch(
    String name,
    double lat,
    double lng,
  ) async {
    try {
      final info = await NaverSearchService.fetchPlaceInfo(
        name,
        lat: lat,
        lng: lng,
      );
      if (info == null || !mounted) return;
      // 사용자가 그 사이 다른 식당을 다시 탭했으면 무시
      if (_linkedNaverPlaceName != name) return;
      if (_addressCtrl.text.isEmpty && info.roadAddress.isNotEmpty) {
        _addressCtrl.text = info.roadAddress;
      }
      if (_phoneCtrl.text.isEmpty && info.telephone.isNotEmpty) {
        _phoneCtrl.text = info.telephone;
      }
      setState(() {});
    } catch (_) {
      // 보강 실패는 무시
    }
  }

  /// 네이버 검색 결과를 선택하면 이름/주소/전화/좌표를 자동 채운다.
  void _pickNaverResult(NaverPlaceInfo place) {
    _nameCtrl.text = place.title;
    _addressCtrl.text = place.roadAddress;
    _phoneCtrl.text = place.telephone;

    final hasCoords = place.placeLat != null && place.placeLng != null;
    if (hasCoords) {
      _currentLat = place.placeLat!;
      _currentLng = place.placeLng!;
      _hasCoordsFromNaver = true;
      // 모바일 지도 카메라 이동 (web 에선 무시됨)
      _cameraTarget.value = (lat: _currentLat, lng: _currentLng);
    }

    setState(() {
      _resultsExpanded = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          hasCoords
              ? '"${place.title}" 정보를 불러왔어요. 위치를 확인하고 등록하세요.'
              : '"${place.title}" 정보를 불러왔어요. 좌표는 직접 지정해 주세요.',
        ),
      ),
    );
  }

  // ── 저장 ──────────────────────────────────────────────
  Future<void> _save() async {
    if (_isSaving) return;

    if (_isFixMode) {
      await _saveFixCoords();
      return;
    }

    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('식당 이름을 입력하세요')),
      );
      return;
    }

    // 좌표 사용 여부: 모바일 지도 사용 가능하거나, 네이버 결과로 좌표를 받은 경우만.
    final hasCoords = _canUseMap || _hasCoordsFromNaver;
    final address = _addressCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    final loc = Location(
      id: '',
      name: name,
      address: address.isEmpty ? null : address,
      phone: phone.isEmpty ? null : phone,
      lat: hasCoords ? _currentLat : null,
      lng: hasCoords ? _currentLng : null,
      isFixed: hasCoords,
      createdAt: DateTime.now(),
    );

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      await ref.read(locationListProvider.notifier).addLocation(loc);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '"$name" 등록됨${hasCoords ? "" : " (위치 미확정)"}',
          ),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      router.go('/locations');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('등록 실패: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _saveFixCoords() async {
    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      await ref
          .read(locationListProvider.notifier)
          .updateCoordinates(widget.locationId!, _currentLat, _currentLng);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('✅ 위치가 업데이트되었습니다!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      router.go('/locations');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('오류: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ── UI ───────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('장소 등록')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final title = _isFixMode
        ? '${_targetLocation?.name ?? "장소"} 위치 설정'
        : '장소 등록';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.go('/locations'),
        ),
      ),
      body: _canUseMap ? _buildMobileLayout() : _buildWebLayout(),
    );
  }

  /// 모바일: 위에서부터 검색 패널 → 지도(+핀) → 하단 입력/등록 패널.
  Widget _buildMobileLayout() {
    return Column(
      children: [
        if (!_isFixMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: _NaverSearchPanel(
              controller: _searchCtrl,
              results: _naverResults,
              isLoading: _isSearching,
              searched: _hasSearched,
              hasError: _searchHadError,
              expanded: _resultsExpanded,
              onSearch: _runSearch,
              onClear: _clearSearch,
              onToggleExpand: () =>
                  setState(() => _resultsExpanded = !_resultsExpanded),
              onPick: _pickNaverResult,
            ),
          ),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: MapPickerBody(
                  initialLat: _currentLat,
                  initialLng: _currentLng,
                  onCameraIdle: _onCameraMove,
                  cameraTarget: _cameraTarget,
                  onSymbolTap: _isFixMode ? null : _onNaverSymbolTap,
                ),
              ),
              const Center(child: _CenterPin()),
              if (!_isFixMode)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: _LinkHintBanner(
                    linkedName: _linkedNaverPlaceName,
                    onClear: _linkedNaverPlaceName == null
                        ? null
                        : () => setState(() => _linkedNaverPlaceName = null),
                  ),
                ),
            ],
          ),
        ),
        _BottomPanel(
          isFixMode: _isFixMode,
          targetName: _targetLocation?.name,
          currentLat: _currentLat,
          currentLng: _currentLng,
          hasCoords: true, // 모바일에서는 항상 지도 좌표 사용
          isSaving: _isSaving,
          nameCtrl: _nameCtrl,
          phoneCtrl: _phoneCtrl,
          onSubmit: _save,
        ),
      ],
    );
  }

  /// 웹/데스크탑: 지도 사용 불가 → 네이버 검색 + 폼.
  Widget _buildWebLayout() {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 18, color: Color(0xFF64748B)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '웹에서는 지도 미리보기가 제공되지 않아요. '
                  '네이버 검색으로 좌표를 가져오거나, 좌표 없이 등록 후 모바일에서 확정할 수 있습니다.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF334155)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (!_isFixMode) ...[
          _NaverSearchPanel(
            controller: _searchCtrl,
            results: _naverResults,
            isLoading: _isSearching,
            searched: _hasSearched,
            hasError: _searchHadError,
            expanded: _resultsExpanded,
            onSearch: _runSearch,
            onClear: _clearSearch,
            onToggleExpand: () =>
                setState(() => _resultsExpanded = !_resultsExpanded),
            onPick: _pickNaverResult,
          ),
          const SizedBox(height: 16),
          _BottomPanelInline(
            isFixMode: _isFixMode,
            targetName: _targetLocation?.name,
            currentLat: _currentLat,
            currentLng: _currentLng,
            hasCoords: _hasCoordsFromNaver,
            isSaving: _isSaving,
            nameCtrl: _nameCtrl,
            phoneCtrl: _phoneCtrl,
            onSubmit: _save,
          ),
        ] else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                '좌표 설정은 모바일 앱에서 가능합니다.',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── 중앙 고정 핀 ───────────────────────────────────────
class _CenterPin extends StatelessWidget {
  const _CenterPin();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.location_on_rounded,
              size: 40,
              color: Colors.white,
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 네이버 검색 패널 ─────────────────────────────────────
class _NaverSearchPanel extends StatelessWidget {
  final TextEditingController controller;
  final List<NaverPlaceInfo> results;
  final bool isLoading;
  final bool searched;
  final bool hasError;
  final bool expanded;
  final VoidCallback onSearch;
  final VoidCallback onClear;
  final VoidCallback onToggleExpand;
  final ValueChanged<NaverPlaceInfo> onPick;

  const _NaverSearchPanel({
    required this.controller,
    required this.results,
    required this.isLoading,
    required this.searched,
    required this.hasError,
    required this.expanded,
    required this.onSearch,
    required this.onClear,
    required this.onToggleExpand,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.white,
      elevation: 4,
      borderRadius: BorderRadius.circular(14),
      shadowColor: Colors.black.withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListenableBuilder(
              listenable: controller,
              builder: (context, _) => TextField(
                controller: controller,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => onSearch(),
                decoration: InputDecoration(
                  hintText: '네이버에서 식당 검색 (예: 거북이식당)',
                  prefixIcon: const Icon(Icons.storefront_rounded),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (controller.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: onClear,
                        ),
                      IconButton(
                        icon: const Icon(Icons.search_rounded, size: 20),
                        onPressed: onSearch,
                      ),
                    ],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  isDense: true,
                ),
              ),
            ),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            if (!isLoading && searched && hasError)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  '검색 중 오류가 발생했습니다. 다시 시도해주세요.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            if (!isLoading && searched && !hasError && results.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  '검색 결과가 없습니다',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (!isLoading && results.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.place_rounded,
                    size: 14,
                    color: const Color(0xFF03C75A),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '검색 결과 ${results.length}건',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: onToggleExpand,
                    icon: Icon(
                      expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 18,
                    ),
                    label: Text(expanded ? '접기' : '펼치기'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ],
              ),
              if (expanded)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) => _NaverResultTile(
                      place: results[i],
                      onPick: () => onPick(results[i]),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NaverResultTile extends StatelessWidget {
  final NaverPlaceInfo place;
  final VoidCallback onPick;

  const _NaverResultTile({required this.place, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
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
      isThreeLine: place.category.isNotEmpty && place.roadAddress.isNotEmpty,
      trailing: TextButton(
        onPressed: onPick,
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF03C75A),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        child: const Text(
          '선택',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ─── 하단 패널 (모바일: floating sheet) ──────────────────
class _BottomPanel extends StatelessWidget {
  final bool isFixMode;
  final String? targetName;
  final double currentLat;
  final double currentLng;
  final bool hasCoords;
  final bool isSaving;
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final VoidCallback onSubmit;

  const _BottomPanel({
    required this.isFixMode,
    required this.targetName,
    required this.currentLat,
    required this.currentLng,
    required this.hasCoords,
    required this.isSaving,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // 아래로 쓸어내리면 키보드를 닫는다.
      onVerticalDragUpdate: (details) {
        if (details.primaryDelta != null && details.primaryDelta! > 6) {
          FocusManager.instance.primaryFocus?.unfocus();
        }
      },
      child: Container(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.of(context).padding.bottom + 16,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isFixMode && targetName != null) ...[
              Text(
                targetName!,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
            ],
            if (!isFixMode) ...[
              TextField(
                controller: nameCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '식당 이름 *',
                  prefixIcon: Icon(Icons.restaurant),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: '전화번호 (선택)',
                  prefixIcon: Icon(Icons.phone_outlined),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
            ],
            _CoordsRow(lat: currentLat, lng: currentLng, hasCoords: hasCoords),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: isSaving ? null : onSubmit,
                icon: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(
                  isSaving
                      ? '저장 중...'
                      : isFixMode
                          ? '이 위치로 확정'
                          : '이 위치로 등록',
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 웹/데스크탑: 카드 형태로 인라인 배치 (지도 없음)
class _BottomPanelInline extends StatelessWidget {
  final bool isFixMode;
  final String? targetName;
  final double currentLat;
  final double currentLng;
  final bool hasCoords;
  final bool isSaving;
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final VoidCallback onSubmit;

  const _BottomPanelInline({
    required this.isFixMode,
    required this.targetName,
    required this.currentLat,
    required this.currentLng,
    required this.hasCoords,
    required this.isSaving,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isFixMode && targetName != null) ...[
            Text(
              targetName!,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: '식당 이름 *',
              prefixIcon: Icon(Icons.restaurant),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: '전화번호 (선택)',
              prefixIcon: Icon(Icons.phone_outlined),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          _CoordsRow(lat: currentLat, lng: currentLng, hasCoords: hasCoords),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: isSaving ? null : onSubmit,
              icon: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(
                isSaving ? '저장 중...' : '등록',
                style: const TextStyle(fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 지도 위에 떠 있는 안내 배너.
/// - 평소: "지도의 식당을 탭하면 자동으로 연결돼요"
/// - 연결 후: "네이버: 식당이름 (연결됨)"
class _LinkHintBanner extends StatelessWidget {
  final String? linkedName;
  final VoidCallback? onClear;

  const _LinkHintBanner({required this.linkedName, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final linked = linkedName != null;
    return Material(
      color: linked ? const Color(0xFF03C75A) : Colors.white,
      elevation: 4,
      borderRadius: BorderRadius.circular(10),
      shadowColor: Colors.black.withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          children: [
            Icon(
              linked ? Icons.link_rounded : Icons.touch_app_outlined,
              size: 18,
              color: linked ? Colors.white : const Color(0xFF03C75A),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                linked
                    ? '네이버 POI 연결됨: ${linkedName!}'
                    : '지도의 식당을 탭하면 네이버 POI와 연결해 등록할 수 있어요',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: linked ? Colors.white : const Color(0xFF0F172A),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onClear != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                tooltip: '연결 해제',
                onPressed: onClear,
              ),
          ],
        ),
      ),
    );
  }
}

class _CoordsRow extends StatelessWidget {
  final double lat;
  final double lng;
  final bool hasCoords;

  const _CoordsRow({
    required this.lat,
    required this.lng,
    required this.hasCoords,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasCoords
            ? primary.withValues(alpha: 0.06)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            hasCoords ? Icons.gps_fixed_rounded : Icons.gps_off_rounded,
            size: 18,
            color: hasCoords ? primary : const Color(0xFF94A3B8),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hasCoords
                  ? '위도: ${lat.toStringAsFixed(6)}  |  경도: ${lng.toStringAsFixed(6)}'
                  : '좌표 미지정 — 모바일 앱에서 확정할 수 있어요',
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w500,
                color: hasCoords
                    ? const Color(0xFF0F172A)
                    : const Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
