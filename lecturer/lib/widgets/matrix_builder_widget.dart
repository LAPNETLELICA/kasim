import 'package:flutter/material.dart';
import '../main.dart';
import '../models/resource.dart';

class MatrixBuilderWidget extends StatefulWidget {
  final List<BrowserResource> browsers;
  final List<AIResource> aiServices;
  final List<String> selectedBrowserIds;
  final List<String> selectedAiIds;
  final Map<String, List<String>> browserAiMatrix;
  final Function(List<String> allowedBrowsers, List<String> allowedAi, Map<String, List<String>> matrix) onChanged;

  const MatrixBuilderWidget({
    Key? key,
    required this.browsers,
    required this.aiServices,
    required this.selectedBrowserIds,
    required this.selectedAiIds,
    required this.browserAiMatrix,
    required this.onChanged,
  }) : super(key: key);

  @override
  _MatrixBuilderWidgetState createState() => _MatrixBuilderWidgetState();
}

class _MatrixBuilderWidgetState extends State<MatrixBuilderWidget> {
  late List<String> _allowedBrowsers;
  late List<String> _allowedAi;
  late Map<String, List<String>> _matrix;

  @override
  void initState() {
    super.initState();
    _allowedBrowsers = List.from(widget.selectedBrowserIds);
    _allowedAi = List.from(widget.selectedAiIds);
    _matrix = Map.from(widget.browserAiMatrix);
  }

  void _notify() {
    widget.onChanged(_allowedBrowsers, _allowedAi, _matrix);
  }

  @override
  Widget build(BuildContext context) {
    if (_allowedBrowsers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFDE8E8),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFF8B4B4)),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.errorMuted),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'DEFAULT DENY: No browsers authorized in Step 2. All browser activity will be blocked on student endpoints.',
                style: TextStyle(color: AppTheme.errorMuted, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderGray),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppTheme.creamBg),
          dataRowColor: WidgetStateProperty.all(AppTheme.cardWhite),
          columns: [
            const DataColumn(label: Text('Authorized Browser', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark))),
            const DataColumn(label: Text('Mode', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark))),
            ...widget.aiServices.where((a) => _allowedAi.contains(a.id)).map((a) => DataColumn(
              label: Text(a.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6B4C9A))),
            )),
          ],
          rows: widget.browsers.where((b) => _allowedBrowsers.contains(b.id)).map((b) {
            final allowedForBrowser = _matrix[b.id] ?? [];
            final hasNoAi = allowedForBrowser.isEmpty;

            return DataRow(
              cells: [
                DataCell(
                  Row(
                    children: [
                      const Icon(Icons.language, color: AppTheme.primaryGreen, size: 16),
                      const SizedBox(width: 8),
                      Text(b.name, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textDark)),
                    ],
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: hasNoAi ? const Color(0xFFFEF3C7) : AppTheme.softGreen,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      hasNoAi ? 'NO AI (WEB ONLY)' : 'AI AUTHORIZED',
                      style: TextStyle(
                        color: hasNoAi ? AppTheme.warningAmber : AppTheme.primaryGreen,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                ...widget.aiServices.where((a) => _allowedAi.contains(a.id)).map((a) {
                  final isChecked = allowedForBrowser.contains(a.id);
                  return DataCell(
                    Checkbox(
                      value: isChecked,
                      activeColor: AppTheme.primaryGreen,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _matrix.putIfAbsent(b.id, () => []);
                            if (!_matrix[b.id]!.contains(a.id)) {
                              _matrix[b.id]!.add(a.id);
                            }
                          } else {
                            _matrix[b.id]?.remove(a.id);
                          }
                          _notify();
                        });
                      },
                    ),
                  );
                }).toList(),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
