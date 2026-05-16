import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/opus_tokens.dart';
import '../../data/models/comment.dart';
import '../../data/models/menu.dart';
import '../../data/services/menu_service.dart';
import '../redesign/widgets/opus_widgets.dart';

/// 메뉴 목록 섹션 — 식당 상세 화면용.
///
/// 편집 모드에서 메뉴 추가/수정/삭제가 동작한다. 부모(상세 화면)에서
/// 편집 토글 상태를 주입한다.
class MenuListSection extends StatefulWidget {
  final String locationId;
  final bool editMode;

  const MenuListSection({
    super.key,
    required this.locationId,
    required this.editMode,
  });

  @override
  State<MenuListSection> createState() => _MenuListSectionState();
}

class _MenuListSectionState extends State<MenuListSection> {
  late Future<List<MenuItem>> _future =
      MenuService.getByLocation(widget.locationId);

  void _reload() {
    setState(() {
      _future = MenuService.getByLocation(widget.locationId);
    });
  }

  Future<void> _addMenu() async {
    final result = await _openEditor();
    if (result == null) return;
    try {
      await MenuService.insert(
        locationId: widget.locationId,
        name: result.name,
        price: result.price,
      );
      _reload();
    } catch (e) {
      _showError('메뉴 추가 실패: $e');
    }
  }

  Future<void> _editMenu(MenuItem m) async {
    final result =
        await _openEditor(initialName: m.name, initialPrice: m.price);
    if (result == null) return;
    try {
      await MenuService.update(m.id, name: result.name, price: result.price);
      _reload();
    } catch (e) {
      _showError('메뉴 수정 실패: $e');
    }
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
    try {
      await MenuService.delete(m.id);
      _reload();
    } catch (e) {
      _showError('메뉴 삭제 실패: $e');
    }
  }

  Future<({String name, int price})?> _openEditor({
    String? initialName,
    int? initialPrice,
  }) {
    return showModalBottomSheet<({String name, int price})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _MenuEditSheet(initialName: initialName, initialPrice: initialPrice),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: FutureBuilder<List<MenuItem>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snap.hasError) {
            return _ErrorRow(message: '메뉴를 불러오지 못했습니다', onRetry: _reload);
          }
          final menus = snap.data ?? const <MenuItem>[];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionHeader(
                icon: Icons.restaurant_menu_rounded,
                title: '메뉴',
                count: menus.length,
              ),
              if (menus.isEmpty)
                _EmptyHint(
                  text: widget.editMode
                      ? '아래 “메뉴 추가” 버튼으로 등록하세요'
                      : '등록된 메뉴가 없어요',
                )
              else
                for (var i = 0; i < menus.length; i++)
                  _MenuRow(
                    menu: menus[i],
                    showDivider: i != menus.length - 1,
                    editMode: widget.editMode,
                    onEdit: () => _editMenu(menus[i]),
                    onDelete: () => _deleteMenu(menus[i]),
                  ),
              if (widget.editMode)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: OpusColors.purple700,
                      backgroundColor: OpusColors.purple50,
                      side: const BorderSide(color: OpusColors.purple300),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _addMenu,
                    icon: const Icon(Icons.add_rounded, size: 18),
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
  final bool showDivider;
  final bool editMode;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MenuRow({
    required this.menu,
    required this.showDivider,
    required this.editMode,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: showDivider ? OpusColors.gray100 : Colors.transparent,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            if (editMode) ...[
              _IconAction(
                icon: Icons.remove_rounded,
                background: OpusColors.red500,
                foreground: Colors.white,
                onTap: onDelete,
                shape: BoxShape.circle,
                size: 28,
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                menu.name,
                style: GoogleFonts.notoSansKr(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: OpusColors.gray900,
                ),
              ),
            ),
            PriceText(won: menu.price, size: 15),
            if (editMode) ...[
              const SizedBox(width: 10),
              _IconAction(
                icon: Icons.edit_rounded,
                background: OpusColors.gray100,
                foreground: OpusColors.gray700,
                onTap: onEdit,
                shape: BoxShape.rectangle,
                size: 32,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;
  final BoxShape shape;
  final double size;

  const _IconAction({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
    required this.shape,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius =
        shape == BoxShape.rectangle ? BorderRadius.circular(8) : null;
    return InkWell(
      onTap: onTap,
      borderRadius: borderRadius,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: background,
          borderRadius: borderRadius,
          shape: shape,
        ),
        child: Icon(icon, size: size * 0.55, color: foreground),
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
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final name = _nameCtrl.text.trim();
    final price = int.tryParse(_priceCtrl.text.trim()) ?? 0;
    Navigator.pop(context, (name: name, price: price));
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
        child: Form(
          key: _formKey,
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
              Text(widget.initialName == null ? '메뉴 추가' : '메뉴 편집',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: OpusColors.gray900,
                  )),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                autofocus: widget.initialName == null,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '메뉴 이름',
                  hintText: '예: 김치찌개',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '메뉴 이름을 입력하세요' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: '가격 (원)',
                  prefixText: '₩ ',
                ),
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim());
                  if (n == null) return '숫자만 입력하세요';
                  if (n < 0) return '0 이상의 값이어야 합니다';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: const Text('저장'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 댓글 섹션 ──────────────────────────────────────────────

class CommentListSection extends StatefulWidget {
  final String locationId;
  final bool editMode;

  const CommentListSection({
    super.key,
    required this.locationId,
    required this.editMode,
  });

  @override
  State<CommentListSection> createState() => _CommentListSectionState();
}

class _CommentListSectionState extends State<CommentListSection> {
  late Future<List<LocationComment>> _future =
      CommentService.getByLocation(widget.locationId);

  final _textController = TextEditingController();
  bool _composing = false;
  bool _submitting = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = CommentService.getByLocation(widget.locationId);
    });
  }

  Future<void> _submit() async {
    final body = _textController.text.trim();
    if (body.isEmpty) return;
    setState(() => _submitting = true);
    try {
      await CommentService.add(
        locationId: widget.locationId,
        userName: '익명',
        body: body,
      );
      _textController.clear();
      setState(() {
        _composing = false;
        _submitting = false;
        _future = CommentService.getByLocation(widget.locationId);
      });
    } catch (e) {
      setState(() => _submitting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('댓글 등록 실패: $e')),
      );
    }
  }

  Future<void> _delete(LocationComment c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('댓글 삭제'),
        content: const Text('이 댓글을 삭제하시겠습니까?'),
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
    try {
      await CommentService.delete(c.id);
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('댓글 삭제 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: FutureBuilder<List<LocationComment>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snap.hasError) {
            return _ErrorRow(message: '댓글을 불러오지 못했습니다', onRetry: _reload);
          }
          final comments = snap.data ?? const <LocationComment>[];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionHeader(
                icon: Icons.forum_rounded,
                title: '댓글',
                count: comments.length,
              ),
              if (comments.isEmpty)
                const _EmptyHint(text: '아직 댓글이 없어요. 첫 댓글을 남겨주세요.')
              else
                for (var i = 0; i < comments.length; i++)
                  _CommentTile(
                    comment: comments[i],
                    showDivider: i != comments.length - 1,
                    editMode: widget.editMode,
                    onDelete: () => _delete(comments[i]),
                  ),
              const Divider(height: 1, color: OpusColors.gray100),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: _composing
                    ? _Composer(
                        controller: _textController,
                        submitting: _submitting,
                        onCancel: () {
                          _textController.clear();
                          setState(() => _composing = false);
                        },
                        onSubmit: _submit,
                      )
                    : OutlinedButton.icon(
                        onPressed: () => setState(() => _composing = true),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: OpusColors.purple700,
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: OpusColors.gray300),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.edit_note_rounded, size: 18),
                        label: const Text('댓글 작성'),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final LocationComment comment;
  final bool showDivider;
  final bool editMode;
  final VoidCallback onDelete;

  const _CommentTile({
    required this.comment,
    required this.showDivider,
    required this.editMode,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: showDivider ? OpusColors.gray100 : Colors.transparent,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: OpusColors.purple100,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              comment.userName.isEmpty ? '?' : comment.userName.characters.first,
              style: GoogleFonts.notoSansKr(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: OpusColors.purple700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.userName,
                      style: GoogleFonts.notoSansKr(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: OpusColors.gray900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _relativeTime(comment.createdAt),
                      style: GoogleFonts.notoSansKr(
                        fontSize: 11,
                        color: OpusColors.gray400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  comment.body,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 14,
                    height: 1.4,
                    color: OpusColors.gray700,
                  ),
                ),
              ],
            ),
          ),
          if (editMode)
            IconButton(
              tooltip: '댓글 삭제',
              onPressed: onDelete,
              icon: const Icon(Icons.close_rounded, size: 18),
              color: OpusColors.gray500,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
        ],
      ),
    );
  }

  String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${t.year}.${t.month.toString().padLeft(2, '0')}.${t.day.toString().padLeft(2, '0')}';
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool submitting;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  const _Composer({
    required this.controller,
    required this.submitting,
    required this.onCancel,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          minLines: 2,
          maxLength: 500,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            hintText: '이 식당에 대한 의견을 남겨주세요',
            filled: true,
            fillColor: OpusColors.gray25,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: OpusColors.gray200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: OpusColors.gray200),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: submitting ? null : onCancel,
              child: const Text('취소'),
            ),
            const SizedBox(width: 4),
            ElevatedButton.icon(
              onPressed: submitting ? null : onSubmit,
              icon: submitting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, size: 16),
              label: const Text('등록'),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── 공통 보조 위젯 ─────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(OpusRadius.xl2),
        border: Border.all(color: OpusColors.gray100),
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: OpusColors.purple600),
          const SizedBox(width: 8),
          Text(title,
              style: GoogleFonts.notoSansKr(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: OpusColors.gray900,
              )),
          const SizedBox(width: 6),
          Text('$count',
              style: GoogleFonts.robotoMono(
                fontSize: 12,
                color: OpusColors.gray500,
              )),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: Text(
          text,
          style: GoogleFonts.notoSansKr(
            fontSize: 13,
            color: OpusColors.gray500,
          ),
        ),
      ),
    );
  }
}

class _ErrorRow extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorRow({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded,
              size: 18, color: OpusColors.red600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: GoogleFonts.notoSansKr(
                  fontSize: 13,
                  color: OpusColors.gray700,
                )),
          ),
          TextButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}
