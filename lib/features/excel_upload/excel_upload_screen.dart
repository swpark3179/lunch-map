import 'dart:typed_data';

import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/location.dart';
import '../../providers/location_provider.dart';

/// PC용 엑셀 대량 업로드 화면
class ExcelUploadScreen extends ConsumerStatefulWidget {
  const ExcelUploadScreen({super.key});

  @override
  ConsumerState<ExcelUploadScreen> createState() => _ExcelUploadScreenState();
}

class _ExcelUploadScreenState extends ConsumerState<ExcelUploadScreen> {
  List<_ParsedRow>? _parsedRows;
  String? _fileName;
  bool _isParsing = false;
  bool _isUploading = false;
  String? _error;

  // 컬럼 매핑
  int _nameCol = 0;
  int _addressCol = 1;
  int _latCol = 2;
  int _lngCol = 3;
  bool _hasHeader = true;

  Future<void> _pickFile() async {
    setState(() {
      _error = null;
      _parsedRows = null;
    });

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) {
      setState(() => _error = '파일을 읽을 수 없습니다.');
      return;
    }

    setState(() {
      _fileName = file.name;
      _isParsing = true;
    });

    try {
      _parseExcel(file.bytes!);
    } catch (e) {
      setState(() => _error = '파일 파싱 오류: $e');
    } finally {
      setState(() => _isParsing = false);
    }
  }

  void _parseExcel(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables[excel.tables.keys.first];
    if (sheet == null) {
      setState(() => _error = '시트를 찾을 수 없습니다.');
      return;
    }

    final rows = <_ParsedRow>[];
    final startRow = _hasHeader ? 1 : 0;

    for (var i = startRow; i < sheet.maxRows; i++) {
      final row = sheet.row(i);
      if (row.isEmpty) continue;

      final name = _getCellValue(row, _nameCol);
      if (name.isEmpty) continue;

      final address = _getCellValue(row, _addressCol);
      final latStr = _getCellValue(row, _latCol);
      final lngStr = _getCellValue(row, _lngCol);

      final lat = double.tryParse(latStr);
      final lng = double.tryParse(lngStr);

      rows.add(
        _ParsedRow(
          name: name,
          address: address.isEmpty ? null : address,
          lat: lat,
          lng: lng,
          isValid: name.isNotEmpty,
        ),
      );
    }

    setState(() => _parsedRows = rows);
  }

  String _getCellValue(List<Data?> row, int index) {
    if (index >= row.length || row[index] == null) return '';
    final cell = row[index]!;
    return cell.value?.toString().trim() ?? '';
  }

  Future<void> _uploadAll() async {
    if (_parsedRows == null || _parsedRows!.isEmpty) return;

    setState(() => _isUploading = true);
    try {
      final locations =
          _parsedRows!
              .where((r) => r.isValid)
              .map(
                (r) => Location(
                  id: '',
                  name: r.name,
                  address: r.address,
                  lat: r.lat,
                  lng: r.lng,
                  isFixed: r.lat != null && r.lng != null,
                  createdAt: DateTime.now(),
                ),
              )
              .toList();

      final count = await ref
          .read(locationListProvider.notifier)
          .addLocationsBatch(locations);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $count개 장소가 성공적으로 업로드되었습니다!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        setState(() {
          _parsedRows = null;
          _fileName = null;
        });
        context.go('/locations');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('업로드 오류: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('엑셀 대량 업로드')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 안내 카드 ──
            _InfoCard(),
            const SizedBox(height: 20),

            // ── 컬럼 매핑 설정 ──
            _ColumnMappingSection(
              nameCol: _nameCol,
              addressCol: _addressCol,
              latCol: _latCol,
              lngCol: _lngCol,
              hasHeader: _hasHeader,
              onNameColChanged: (v) => setState(() => _nameCol = v),
              onAddressColChanged: (v) => setState(() => _addressCol = v),
              onLatColChanged: (v) => setState(() => _latCol = v),
              onLngColChanged: (v) => setState(() => _lngCol = v),
              onHasHeaderChanged: (v) => setState(() => _hasHeader = v),
            ),
            const SizedBox(height: 20),

            // ── 파일 선택 ──
            Center(
              child: Column(
                children: [
                  SizedBox(
                    width: 280,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _isParsing ? null : _pickFile,
                      icon:
                          _isParsing
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : const Icon(Icons.file_open_rounded, size: 24),
                      label: Text(
                        _isParsing ? '파싱 중...' : '.xlsx 파일 선택',
                        style: const TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  if (_fileName != null) ...[
                    const SizedBox(height: 10),
                    Text('📄 $_fileName', style: theme.textTheme.bodyMedium),
                  ],
                ],
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── 미리보기 테이블 ──
            if (_parsedRows != null) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '📋 미리보기 (${_parsedRows!.length}건)',
                    style: theme.textTheme.titleLarge,
                  ),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: _isUploading ? null : _uploadAll,
                      icon:
                          _isUploading
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : const Icon(Icons.cloud_upload_rounded),
                      label: Text(_isUploading ? '업로드 중...' : '전체 업로드'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _PreviewTable(rows: _parsedRows!),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── 안내 카드 ───
class _InfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF7C3AED).withValues(alpha: 0.1),
            const Color(0xFF7C3AED).withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF7C3AED),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '엑셀 파일 형식 안내',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text('• 지원 형식: .xlsx'),
          const SizedBox(height: 4),
          const Text('• 필수 컬럼: 장소 이름'),
          const SizedBox(height: 4),
          const Text('• 선택 컬럼: 주소, 위도(lat), 경도(lng)'),
          const SizedBox(height: 4),
          const Text('• 좌표가 없는 데이터는 "위치 미확정" 상태로 등록됩니다.'),
        ],
      ),
    );
  }
}

// ─── 컬럼 매핑 ───
class _ColumnMappingSection extends StatelessWidget {
  final int nameCol, addressCol, latCol, lngCol;
  final bool hasHeader;
  final ValueChanged<int> onNameColChanged,
      onAddressColChanged,
      onLatColChanged,
      onLngColChanged;
  final ValueChanged<bool> onHasHeaderChanged;

  const _ColumnMappingSection({
    required this.nameCol,
    required this.addressCol,
    required this.latCol,
    required this.lngCol,
    required this.hasHeader,
    required this.onNameColChanged,
    required this.onAddressColChanged,
    required this.onLatColChanged,
    required this.onLngColChanged,
    required this.onHasHeaderChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '⚙️ 컬럼 매핑',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            CheckboxListTile(
              title: const Text('첫 번째 행이 헤더입니다'),
              value: hasHeader,
              onChanged: (v) => onHasHeaderChanged(v ?? true),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                _colDropdown('이름 (필수)', nameCol, onNameColChanged),
                _colDropdown('주소', addressCol, onAddressColChanged),
                _colDropdown('위도', latCol, onLatColChanged),
                _colDropdown('경도', lngCol, onLngColChanged),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _colDropdown(String label, int value, ValueChanged<int> onChanged) {
    final letters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J'];
    return SizedBox(
      width: 140,
      child: DropdownButtonFormField<int>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
        ),
        items: List.generate(
          letters.length,
          (i) => DropdownMenuItem(
            value: i,
            child: Text('${letters[i]}열 (${i + 1})'),
          ),
        ),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

// ─── 미리보기 테이블 ───
class _PreviewTable extends StatelessWidget {
  final List<_ParsedRow> rows;
  const _PreviewTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateColor.resolveWith(
            (_) =>
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
          ),
          columns: const [
            DataColumn(label: Text('#')),
            DataColumn(label: Text('장소 이름')),
            DataColumn(label: Text('주소')),
            DataColumn(label: Text('위도')),
            DataColumn(label: Text('경도')),
            DataColumn(label: Text('상태')),
          ],
          rows:
              rows.asMap().entries.map((e) {
                final i = e.key;
                final r = e.value;
                final hasCoords = r.lat != null && r.lng != null;
                return DataRow(
                  cells: [
                    DataCell(Text('${i + 1}')),
                    DataCell(
                      Text(
                        r.name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    DataCell(Text(r.address ?? '-')),
                    DataCell(Text(r.lat?.toStringAsFixed(4) ?? '-')),
                    DataCell(Text(r.lng?.toStringAsFixed(4) ?? '-')),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color:
                              hasCoords
                                  ? const Color(
                                    0xFF10B981,
                                  ).withValues(alpha: 0.1)
                                  : const Color(
                                    0xFFF59E0B,
                                  ).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          hasCoords ? '확정' : '미확정',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color:
                                hasCoords
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
        ),
      ),
    );
  }
}

// ─── 파싱 결과 ───
class _ParsedRow {
  final String name;
  final String? address;
  final double? lat;
  final double? lng;
  final bool isValid;

  const _ParsedRow({
    required this.name,
    this.address,
    this.lat,
    this.lng,
    this.isValid = true,
  });
}
