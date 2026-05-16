import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/opus_tokens.dart';
import '../../data/models/location.dart';
import '../../data/services/location_service.dart';
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

  Future<void> _callPhone(String phone) async {
    final digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: digits);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('전화 앱을 열 수 없습니다')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
          const SizedBox(height: 16),
          MenuListSection(
            locationId: location.id,
            editMode: _editMode,
          ),
          const SizedBox(height: 16),
          CommentListSection(
            locationId: location.id,
            editMode: _editMode,
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
