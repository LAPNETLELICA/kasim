import 'package:flutter/material.dart';
import '../models/policy.dart';

class PolicyPreviewDialog extends StatelessWidget {
  final PolicyPreviewResponse preview;

  const PolicyPreviewDialog({Key? key, required this.preview}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.preview, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Policy Preview: ${preview.policyTitle}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 800,
        height: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Default-Deny Alert Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blueGrey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blueGrey[200]!),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, color: Colors.blueGrey),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'DEFAULT RULE = DENY. Anything not explicitly marked as ALLOW below will be automatically blocked on student devices.',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 1. Browsers Overview
              const Text('Browser Authorization Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: preview.browserSummary.map((b) {
                  final isAllow = b['status'] == 'ALLOW';
                  return Chip(
                    avatar: Icon(isAllow ? Icons.check_circle : Icons.cancel, color: isAllow ? Colors.green : Colors.red, size: 18),
                    label: Text('${b['name']}: ${b['status']}'),
                    backgroundColor: isAllow ? Colors.green[50] : Colors.red[50],
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // 2. AI Services Overview
              const Text('AI Services Authorization Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: preview.aiSummary.map((a) {
                  final isAllow = a['status'] == 'ALLOW';
                  return Chip(
                    avatar: Icon(isAllow ? Icons.check_circle : Icons.cancel, color: isAllow ? Colors.purple : Colors.grey, size: 18),
                    label: Text('${a['name']}: ${a['status']}'),
                    backgroundColor: isAllow ? Colors.purple[50] : Colors.grey[100],
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // 3. Matrix Rules Breakdown Table
              const Text('Browser ↔ AI Matrix Permutations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              Table(
                border: TableBorder.all(color: Colors.grey[300]!, width: 1),
                columnWidths: const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(2),
                  2: FlexColumnWidth(2),
                  3: FlexColumnWidth(4),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey[200]),
                    children: const [
                      Padding(padding: EdgeInsets.all(8.0), child: Text('Browser', style: TextStyle(fontWeight: FontWeight.bold))),
                      Padding(padding: EdgeInsets.all(8.0), child: Text('AI Service', style: TextStyle(fontWeight: FontWeight.bold))),
                      Padding(padding: EdgeInsets.all(8.0), child: Text('Permission', style: TextStyle(fontWeight: FontWeight.bold))),
                      Padding(padding: EdgeInsets.all(8.0), child: Text('Evaluation Rationale', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  ),
                  ...preview.matrixRules.map((rule) {
                    final isAllow = rule.pairPermission == 'ALLOW' || rule.pairPermission == 'ALLOW_BROWSER_NO_AI';
                    return TableRow(
                      children: [
                        Padding(padding: const EdgeInsets.all(8.0), child: Text(rule.browserName)),
                        Padding(padding: const EdgeInsets.all(8.0), child: Text(rule.aiName)),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isAllow ? Colors.green[100] : Colors.red[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              rule.pairPermission,
                              style: TextStyle(
                                color: isAllow ? Colors.green[900] : Colors.red[900],
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        Padding(padding: const EdgeInsets.all(8.0), child: Text(rule.reason, style: const TextStyle(fontSize: 12))),
                      ],
                    );
                  }).toList(),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close Preview'),
        ),
      ],
    );
  }
}
