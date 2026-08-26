import 'package:flutter/material.dart';
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Browser Authorization Selection
        const Text(
          '1. Select Authorized Browsers',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: widget.browsers.map((b) {
            final isSelected = _allowedBrowsers.contains(b.id);
            return FilterChip(
              label: Text(b.name),
              selected: isSelected,
              selectedColor: Colors.blue.withOpacity(0.2),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _allowedBrowsers.add(b.id);
                    _matrix.putIfAbsent(b.id, () => []);
                  } else {
                    _allowedBrowsers.remove(b.id);
                    _matrix.remove(b.id);
                  }
                  _notify();
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // 2. AI Services Authorization Selection
        const Text(
          '2. Select Authorized AI Services',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: widget.aiServices.map((a) {
            final isSelected = _allowedAi.contains(a.id);
            return FilterChip(
              label: Text(a.name),
              selected: isSelected,
              selectedColor: Colors.purple.withOpacity(0.2),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _allowedAi.add(a.id);
                  } else {
                    _allowedAi.remove(a.id);
                    // Remove from all matrix mappings
                    _matrix.forEach((k, v) => v.remove(a.id));
                  }
                  _notify();
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 24),

        // 3. Browser ↔ AI Permission Matrix Table
        const Text(
          '3. Configure Browser ↔ AI Permission Matrix',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(
          'Check specific AI services allowed for each browser. Unchecked pairs or browsers with "AI: NONE" deny AI access.',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        const SizedBox(height: 12),

        if (_allowedBrowsers.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning, color: Colors.red),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'DEFAULT DENY: No browsers selected. All browser access on student desktops will be BLOCKED.',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
              columns: [
                const DataColumn(label: Text('Browser', style: TextStyle(fontWeight: FontWeight.bold))),
                const DataColumn(label: Text('Browser Status', style: TextStyle(fontWeight: FontWeight.bold))),
                ...widget.aiServices.map((a) => DataColumn(
                  label: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(a.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(_allowedAi.contains(a.id) ? '(Allowed)' : '(Denied)',
                          style: TextStyle(fontSize: 10, color: _allowedAi.contains(a.id) ? Colors.green : Colors.red)),
                    ],
                  ),
                )),
              ],
              rows: widget.browsers.where((b) => _allowedBrowsers.contains(b.id)).map((b) {
                final allowedForBrowser = _matrix[b.id] ?? [];
                final hasNoAi = allowedForBrowser.isEmpty;

                return DataRow(
                  cells: [
                    DataCell(Text(b.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(
                      Chip(
                        label: Text(hasNoAi ? 'ALLOW (AI: NONE)' : 'ALLOW'),
                        backgroundColor: hasNoAi ? Colors.orange[100] : Colors.green[100],
                        labelStyle: TextStyle(
                          color: hasNoAi ? Colors.orange[900] : Colors.green[900],
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ...widget.aiServices.map((a) {
                      final isAiGloballyAllowed = _allowedAi.contains(a.id);
                      final isChecked = allowedForBrowser.contains(a.id);

                      return DataCell(
                        Checkbox(
                          value: isChecked && isAiGloballyAllowed,
                          onChanged: isAiGloballyAllowed
                              ? (val) {
                                  setState(() {
                                    if (val == true) {
                                      if (!_matrix.containsKey(b.id)) {
                                        _matrix[b.id] = [];
                                      }
                                      if (!_matrix[b.id]!.contains(a.id)) {
                                        _matrix[b.id]!.add(a.id);
                                      }
                                    } else {
                                      _matrix[b.id]?.remove(a.id);
                                    }
                                    _notify();
                                  });
                                }
                              : null, // Disabled if AI is globally denied
                        ),
                      );
                    }).toList(),
                  ],
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
