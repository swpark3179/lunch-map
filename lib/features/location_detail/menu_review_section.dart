import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/opus_tokens.dart';
import '../../data/models/menu.dart';
import '../../data/models/review.dart';
import '../../data/services/menu_service.dart';
import '../redesign/widgets/opus_widgets.dart';

/// 식당 상세 화면용 "메뉴 · 후기" 섹션 — OPUS-X redesign.
///
/// 디자인 mock 의 `screen-detail` 메뉴 리스트와 동일하게,
/// 행을 탭하면 후기 목록이 펼쳐지고, 후기 추가 버튼이 노출된다.
class MenuReviewSection extends StatefulWidget {
  final String locationId;

  const MenuReviewSection({super.key, required this.locationId});

  @override
  State<MenuReviewSection> createState() => _MenuReviewSectionState();
}

class _MenuReviewSectionState extends State<MenuReviewSection> {
  late Future<List<MenuItem>> _future = MenuService.getByLocation(widget.locationId);
  String? _expandedId;
  String? _editingId;
  bool _editMode = false;

  void _reload() {
    setState(() {
      _future = MenuService.getByLocation(widget.locationId);
    });
  }

  Future<void> _addMenu() async {
    final result = await showModalBottomSheet<({String name, int price})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _MenuEditSheet(),
    );
    if (result == null) return;
    await MenuService.insert(
      locationId: widget.locationId,
      name: result.name,
      price: result.price,
    );
    _reload();
  }

  Future<void> _editMenu(MenuItem m) async {
    final result = await showModalBottomSheet<({String name, int price})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _MenuEditSheet(initialName: m.name, initialPrice: m.price),
    );
    if (result == null) return;
    await MenuService.update(m.id, name: result.name, price: result.price);
    _reload();
  }

  Future<void> _deleteMenu(MenuItem m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('메뉴 삭제'),
        content: Text('"${m.name}" 메뉴를 삭제하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('삭제',
                  style: TextStyle(color: OpusColors.red600))),
        ],
      ),
    );
    if (ok != true) return;
    await MenuService.delete(m.id);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(OpusRadius.xl2),
        border: Border.all(color: OpusColors.gray100),
      ),
      child: FutureBuilder<List<MenuItem>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final menus = snap.data ?? const <MenuItem>[];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Text('메뉴',
                        style: GoogleFonts.notoSansKr(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: OpusColors.gray900,
                        )),
                    const SizedBox(width: 8),
                    Text('${menus.length}개',
                        style: GoogleFonts.robotoMono(
                          fontSize: 12,
                          color: OpusColors.gray500,
                        )),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () =>
                          setState(() => _editMode = !_editMode),
                      icon: Icon(
                          _editMode
                              ? Icons.check_rounded
                              : Icons.edit_rounded,
                          size: 16),
                      label: Text(_editMode ? '완료' : '편집'),
                    ),
                  ],
                ),
              ),
              if (menus.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      '등록된 메뉴가 없어요',
                      style: GoogleFonts.notoSansKr(
                        fontSize: 13,
                        color: OpusColors.gray500,
                      ),
                    ),
                  ),
                )
              else
                for (var i = 0; i < menus.length; i++)
                  _MenuRow(
                    menu: menus[i],
                    isFirst: i == 0,
                    isLast: i == menus.length - 1,
                    expanded: _expandedId == menus[i].id,
                    editMode: _editMode,
                    onToggle: () => setState(() {
                      _expandedId = _expandedId == menus[i].id ? null : menus[i].id;
                    }),
                    onEdit: () => _editMenu(menus[i]),
                    onDelete: () => _deleteMenu(menus[i]),
                    onReviewAdded: _reload,
                  ),
              if (_editMode)
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: OpusColors.purple700,
                      backgroundColor: OpusColors.purple50,
                      side: const BorderSide(
                          color: OpusColors.purple300,
                          style: BorderStyle.solid),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _addMenu,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('메뉴 추가'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final MenuItem menu;
  final bool isFirst;
  final bool isLast;
  final bool expanded;
  final bool editMode;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onReviewAdded;

  const _MenuRow({
    required this.menu,
    required this.isFirst,
    required this.isLast,
    required this.expanded,
    required this.editMode,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onReviewAdded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isFirst ? OpusColors.gray100 : Colors.transparent,
          ),
          bottom: BorderSide(
            color: isLast ? Colors.transparent : OpusColors.gray100,
          ),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  if (editMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: onDelete,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: OpusColors.red500,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.remove_rounded,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          menu.name,
                          style: GoogleFonts.notoSansKr(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: OpusColors.gray900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            if (menu.avgStars > 0) ...[
                              StarsView(
                                  value: menu.avgStars,
                                  size: 10,
                                  showNum: false),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              '후기 ${menu.reviewCount}',
                              style: GoogleFonts.notoSansKr(
                                fontSize: 11,
                                color: OpusColors.gray500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PriceText(won: menu.price, size: 15),
                  if (editMode)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: InkWell(
                        onTap: onEdit,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: OpusColors.gray100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.edit_rounded,
                              size: 14, color: OpusColors.gray700),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (expanded && !editMode)
            _ReviewList(
                menuId: menu.id, onChanged: onReviewAdded),
        ],
      ),
    );
  }
}

class _ReviewList extends StatefulWidget {
  final String menuId;
  final VoidCallback onChanged;
  const _ReviewList({required this.menuId, required this.onChanged});

  @override
  State<_ReviewList> createState() => _ReviewListState();
}

class _ReviewListState extends State<_ReviewList> {
  late Future<List<Review>> _future = ReviewService.getByMenu(widget.menuId);
  bool _adding = false;
  final _textController = TextEditingController();
  int _stars = 5;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    await ReviewService.add(
      menuId: widget.menuId,
      userName: '익명',
      stars: _stars,
      comment: text,
    );
    _textController.clear();
    setState(() {
      _adding = false;
      _future = ReviewService.getByMenu(widget.menuId);
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: OpusColors.gray25,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: FutureBuilder<List<Review>>(
        future: _future,
        builder: (context, snap) {
          final reviews = snap.data ?? const <Review>[];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (reviews.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      '아직 후기가 없어요. 첫 후기를 남겨주세요.',
                      style: GoogleFonts.notoSansKr(
                        fontSize: 13,
                        color: OpusColors.gray400,
                      ),
                    ),
                  ),
                )
              else
                for (final r in reviews)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: OpusColors.purple100,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            r.userName.characters.first,
                            style: GoogleFonts.notoSansKr(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: OpusColors.purple700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(r.userName,
                                      style: GoogleFonts.notoSansKr(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: OpusColors.gray900,
                                      )),
                                  const SizedBox(width: 6),
                                  StarsView(
                                      value: r.stars.toDouble(),
                                      size: 9,
                                      showNum: false),
                                ],
                              ),
                              if (r.comment != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    '"${r.comment!}"',
                                    style: GoogleFonts.notoSansKr(
                                      fontSize: 13,
                                      color: OpusColors.gray700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              const SizedBox(height: 8),
              if (_adding)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        for (var i = 1; i <= 5; i++)
                          InkWell(
                            onTap: () => setState(() => _stars = i),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 2),
                              child: Icon(
                                i <= _stars
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                color: OpusColors.yellow500,
                                size: 22,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            decoration: InputDecoration(
                              hintText: '짧은 후기를 남겨주세요',
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide:
                                    const BorderSide(color: OpusColors.gray200),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide:
                                    const BorderSide(color: OpusColors.gray200),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Material(
                          color: OpusColors.purple600,
                          borderRadius: BorderRadius.circular(18),
                          child: InkWell(
                            onTap: _submit,
                            borderRadius: BorderRadius.circular(18),
                            child: const SizedBox(
                              width: 36,
                              height: 36,
                              child: Icon(Icons.send_rounded,
                                  color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              else
                OutlinedButton.icon(
                  onPressed: () => setState(() => _adding = true),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: OpusColors.gray500,
                    backgroundColor: Colors.white,
                    side: const BorderSide(
                        color: OpusColors.gray300, style: BorderStyle.solid),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    shape: const StadiumBorder(),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 14),
                  label: const Text('후기 남기기'),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MenuEditSheet extends StatefulWidget {
  final String? initialName;
  final int? initialPrice;

  const _MenuEditSheet({this.initialName, this.initialPrice});

  @override
  State<_MenuEditSheet> createState() => _MenuEditSheetState();
}

class _MenuEditSheetState extends State<_MenuEditSheet> {
  late final _nameCtrl = TextEditingController(text: widget.initialName ?? '');
  late final _priceCtrl = TextEditingController(
      text: widget.initialPrice == null ? '' : widget.initialPrice.toString());

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: padding),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.initialName == null ? '메뉴 추가' : '메뉴 편집',
                style: GoogleFonts.notoSansKr(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: OpusColors.gray900,
                )),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: '메뉴 이름'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '가격 (원)',
                prefixText: '₩ ',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final name = _nameCtrl.text.trim();
                  final price = int.tryParse(_priceCtrl.text.trim()) ?? 0;
                  if (name.isEmpty) return;
                  Navigator.pop(context, (name: name, price: price));
                },
                child: const Text('저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
