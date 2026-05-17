import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/opus_tokens.dart';
import '../../data/models/location.dart';
import '../../data/services/location_service.dart';
import '../../data/services/naver_search_service.dart';
import 'detail_sections.dart';

/// 장소 상세 화면 — 식당 이름, 전화번호, 메뉴 목록, 댓글 목록만 표시한다.
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

  bool _editMode = false;
  bool _savingInfo = false;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLocation() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final location = await LocationService.getById(widget.locationId);
      if (!mounted) return;
      setState(() {
        _location = location;
        _isLoading = false;
        if (location != null) {
          _nameCtrl.text = location.name;
          _phoneCtrl.text = location.phone ?? '';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleEdit() async {
    if (!_editMode) {
      setState(() => _editMode = true);
      return;
    }
    final location = _location;
    if (location == null) return;
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('식당 이름은 비울 수 없습니다')),
      );
      return;
    }
    final changed = name != location.name || phone != (location.phone ?? '');
    if (!changed) {
      setState(() => _editMode = false);
      return;
    }
    setState(() => _savingInfo = true);
    try {
      final updated = await LocationService.updateInfo(
        location.id,
        name: name,
        phone: phone,
      );
      if (!mounted) return;
      setState(() {
        _location = updated;
        _editMode = false;
        _savingInfo = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingInfo = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    }
  }

  void _cancelEdit() {
    final location = _location;
    if (location != null) {
      _nameCtrl.text = location.name;
      _phoneCtrl.text = location.phone ?? '';
    }
    setState(() => _editMode = false);
  }

  Future<void> _relinkNaverPoi() async {
    final location = _location;
    if (location == null) return;
    final picked = await showModalBottomSheet<NaverPlaceInfo>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NaverRelinkSheet(initialQuery: location.name),
    );
    if (picked == null || !mounted) return;
    setState(() => _savingInfo = true);
    try {
      final updated = await LocationService.updateNaverLink(
        location.id,
        linked: true,
        link: picked.link,
        category: picked.category,
        name: picked.title,
        address: picked.roadAddress.isEmpty ? null : picked.roadAddress,
        phone: picked.telephone.isEmpty ? null : picked.telephone,
        lat: picked.placeLat,
        lng: picked.placeLng,
      );
      if (!mounted) return;
      setState(() {
        _location = updated;
        _nameCtrl.text = updated.name;
        _phoneCtrl.text = updated.phone ?? '';
        _savingInfo = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${picked.title}" 와(과) 연결되었습니다')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingInfo = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('연결 실패: $e')),
      );
    }
  }

  Future<void> _unlinkNaverPoi() async {
    final location = _location;
    if (location == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('네이버 POI 연결 해제'),
        content: const Text('네이버 POI 와의 연결을 해제하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('해제',
                  style: TextStyle(color: OpusColors.red600))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _savingInfo = true);
    try {
      final updated = await LocationService.updateNaverLink(
        location.id,
        linked: false,
      );
      if (!mounted) return;
      setState(() {
        _location = updated;
        _savingInfo = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingInfo = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('해제 실패: $e')),
      );
    }
  }

  Future<void> _callPhone(String phone) async {
    final digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.isEmpty) return;
    final uri = Uri.parse('tel:$digits');
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!ok && mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('전화 앱을 열 수 없습니다')),
        );
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('전화 앱을 열 수 없습니다')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          leading: const _BackToListButton(),
          title: const Text('장소 상세'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _location == null) {
      return Scaffold(
        appBar: AppBar(
          leading: const _BackToListButton(),
          title: const Text('장소 상세'),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 56, color: OpusColors.red500),
              const SizedBox(height: 12),
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
      backgroundColor: OpusColors.bgCanvas,
      appBar: AppBar(
        leading: _BackToListButton(),
        title: const Text('장소 상세'),
        actions: [
          if (_editMode)
            TextButton(
              onPressed: _savingInfo ? null : _cancelEdit,
              child: const Text('취소'),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _savingInfo ? null : _toggleEdit,
              icon: _savingInfo
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(_editMode
                      ? Icons.check_rounded
                      : Icons.edit_rounded),
              label: Text(_editMode ? '완료' : '편집'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _HeaderCard(
            location: location,
            editMode: _editMode,
            nameController: _nameCtrl,
            phoneController: _phoneCtrl,
            onCall: () => _callPhone(location.phone ?? ''),
          ),
          if (location.naverLinked || _editMode) ...[
            const SizedBox(height: 16),
            _NaverLinkCard(
              location: location,
              editMode: _editMode,
              busy: _savingInfo,
              onRelink: _relinkNaverPoi,
              onUnlink: _unlinkNaverPoi,
            ),
          ],
          const SizedBox(height: 16),
          MenuListSection(
            locationId: location.id,
            locationName: location.name,
            lat: location.lat,
            lng: location.lng,
            editMode: _editMode,
            naverLinked: location.naverLinked,
            naverLink: location.naverLink,
          ),
          const SizedBox(height: 16),
          CommentListSection(
            locationId: location.id,
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final Location location;
  final bool editMode;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final VoidCallback onCall;

  const _HeaderCard({
    required this.location,
    required this.editMode,
    required this.nameController,
    required this.phoneController,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(OpusRadius.xl2),
        border: Border.all(color: OpusColors.gray100),
      ),
      child: editMode
          ? _EditingHeader(
              nameController: nameController,
              phoneController: phoneController,
            )
          : _DisplayHeader(location: location, onCall: onCall),
    );
  }
}

class _DisplayHeader extends StatelessWidget {
  final Location location;
  final VoidCallback onCall;

  const _DisplayHeader({required this.location, required this.onCall});

  @override
  Widget build(BuildContext context) {
    final phone = location.phone;
    final hasPhone = phone != null && phone.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          location.name,
          style: GoogleFonts.notoSansKr(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            height: 1.25,
            color: OpusColors.gray900,
          ),
        ),
        const SizedBox(height: 14),
        if (hasPhone)
          InkWell(
            onTap: onCall,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: OpusColors.purple50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.phone_rounded,
                        size: 18, color: OpusColors.purple600),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      phone,
                      style: GoogleFonts.robotoMono(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: OpusColors.gray900,
                      ),
                    ),
                  ),
                  Text(
                    '전화 걸기',
                    style: GoogleFonts.notoSansKr(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: OpusColors.purple600,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      size: 12, color: OpusColors.purple600),
                ],
              ),
            ),
          )
        else
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: OpusColors.gray100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.phone_disabled_rounded,
                    size: 18, color: OpusColors.gray400),
              ),
              const SizedBox(width: 12),
              Text(
                '전화번호 미등록',
                style: GoogleFonts.notoSansKr(
                  fontSize: 14,
                  color: OpusColors.gray500,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _EditingHeader extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController phoneController;

  const _EditingHeader({
    required this.nameController,
    required this.phoneController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('기본 정보',
            style: GoogleFonts.notoSansKr(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: OpusColors.gray500,
            )),
        const SizedBox(height: 12),
        TextField(
          controller: nameController,
          textInputAction: TextInputAction.next,
          style: GoogleFonts.notoSansKr(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: OpusColors.gray900,
          ),
          decoration: const InputDecoration(
            labelText: '식당 이름',
            prefixIcon: Icon(Icons.storefront_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]')),
          ],
          decoration: const InputDecoration(
            labelText: '전화번호 (선택)',
            prefixIcon: Icon(Icons.phone_rounded),
            hintText: '예: 02-1234-5678',
          ),
        ),
      ],
    );
  }
}

/// 상세 → 장소 목록(지도 뷰)로 이동하는 뒤로가기 버튼.
class _BackToListButton extends StatelessWidget {
  const _BackToListButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '장소 목록으로',
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () => context.go('/locations'),
    );
  }
}

class _NaverLinkCard extends StatelessWidget {
  final Location location;
  final bool editMode;
  final bool busy;
  final VoidCallback onRelink;
  final VoidCallback onUnlink;

  const _NaverLinkCard({
    required this.location,
    required this.editMode,
    required this.busy,
    required this.onRelink,
    required this.onUnlink,
  });

  Future<void> _openLink() async {
    final url = location.naverLink;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final linked = location.naverLinked;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(OpusRadius.xl2),
        border: Border.all(color: OpusColors.gray100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                linked ? Icons.link_rounded : Icons.link_off_rounded,
                size: 18,
                color: linked
                    ? const Color(0xFF03C75A)
                    : OpusColors.gray400,
              ),
              const SizedBox(width: 8),
              Text(
                linked ? "네이버 POI 연결됨" : "네이버 POI 미연결",
                style: GoogleFonts.notoSansKr(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: linked
                      ? const Color(0xFF03C75A)
                      : OpusColors.gray500,
                ),
              ),
              const Spacer(),
              if (linked && (location.naverLink?.isNotEmpty ?? false))
                IconButton(
                  tooltip: "네이버에서 열기",
                  onPressed: _openLink,
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  color: const Color(0xFF03C75A),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          if (linked &&
              location.naverCategory != null &&
              location.naverCategory!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 26),
              child: Text(
                location.naverCategory!,
                style: GoogleFonts.notoSansKr(
                  fontSize: 13,
                  color: OpusColors.gray700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          if (linked &&
              location.address != null &&
              location.address!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 26),
              child: Text(
                location.address!,
                style: GoogleFonts.notoSansKr(
                  fontSize: 12,
                  color: OpusColors.gray500,
                ),
              ),
            ),
          if (editMode) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF03C75A),
                      backgroundColor: const Color(0xFFF0FBF4),
                      side: const BorderSide(color: Color(0xFF03C75A)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: busy ? null : onRelink,
                    icon: const Icon(Icons.search_rounded, size: 18),
                    label: Text(
                      linked ? "다시 연결" : "POI 연결",
                      style: GoogleFonts.notoSansKr(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                if (linked) ...[
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: OpusColors.red600,
                      side: const BorderSide(color: OpusColors.red500),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                    onPressed: busy ? null : onUnlink,
                    child: Text(
                      "해제",
                      style: GoogleFonts.notoSansKr(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _NaverRelinkSheet extends StatefulWidget {
  final String initialQuery;
  const _NaverRelinkSheet({required this.initialQuery});

  @override
  State<_NaverRelinkSheet> createState() => _NaverRelinkSheetState();
}

class _NaverRelinkSheetState extends State<_NaverRelinkSheet> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initialQuery);
  List<NaverPlaceInfo> _results = const [];
  bool _loading = false;
  bool _searched = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // 자동 1회 검색
    WidgetsBinding.instance.addPostFrameCallback((_) => _search());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _loading = true;
      _searched = false;
      _error = null;
    });
    try {
      final results = await NaverSearchService.searchAll(q);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
        _searched = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _searched = true;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: OpusColors.gray200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "네이버 POI 다시 연결",
              style: GoogleFonts.notoSansKr(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: OpusColors.gray900,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: "식당 이름으로 검색",
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send_rounded, size: 20),
                  onPressed: _search,
                ),
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  "검색 오류: $_error",
                  style: GoogleFonts.notoSansKr(
                    fontSize: 12,
                    color: OpusColors.red600,
                  ),
                ),
              )
            else if (_searched && _results.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  "검색 결과가 없습니다",
                  style: GoogleFonts.notoSansKr(
                    fontSize: 13,
                    color: OpusColors.gray500,
                  ),
                ),
              )
            else if (_results.isNotEmpty)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: OpusColors.gray100),
                  itemBuilder: (_, i) {
                    final p = _results[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        p.title,
                        style: GoogleFonts.notoSansKr(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: OpusColors.gray900,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (p.category.isNotEmpty)
                            Text(
                              p.category,
                              style: GoogleFonts.notoSansKr(
                                fontSize: 12,
                                color: const Color(0xFF15803D),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          if (p.roadAddress.isNotEmpty)
                            Text(
                              p.roadAddress,
                              style: GoogleFonts.notoSansKr(
                                fontSize: 11,
                                color: OpusColors.gray500,
                              ),
                            ),
                        ],
                      ),
                      trailing: TextButton(
                        onPressed: () => Navigator.pop(context, p),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF03C75A),
                        ),
                        child: const Text("선택"),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

