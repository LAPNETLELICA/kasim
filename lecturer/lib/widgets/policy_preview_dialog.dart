import 'package:flutter/material.dart';
import '../main.dart';
import '../models/policy.dart';

class PolicyPreviewDialog extends StatelessWidget {
  final PolicyPreviewResponse preview;

  const PolicyPreviewDialog({Key? key, required this.preview}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.cardWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: AppTheme.softGreen, shape: BoxShape.circle),
            child: const Icon(Icons.shield_outlined, color: AppTheme.primaryGreen, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Policy Simulation: ${preview.policyTitle}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 760,
        height: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Default-Deny Alert Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.softGreen,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.paleGreen),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline, color: AppTheme.primaryGreen, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'DEFAULT-DENY ENFORCEMENT: Any resource, browser, or domain not explicitly marked as ALLOW is strictly BLOCKED on student endpoints.',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryGreen),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 1. Browsers Overview
              const Text('Browser Authorization', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textDark)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: preview.browserSummary.map((b) {
                  final isAllow = b['status'] == 'ALLOW';
                  return Chip(
                    avatar: Icon(isAllow ? Icons.check_circle : Icons.cancel, color: isAllow ? AppTheme.successGreen : AppTheme.errorMuted, size: 16),
                    label: Text('${b['name']}: ${b['status']}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isAllow ? AppTheme.successGreen : AppTheme.errorMuted)),
                    backgroundColor: isAllow ? AppTheme.softGreen : const Color(0xFFFDE8E8),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // 2. AI Services Overview
              const Text('AI Services Authorization', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textDark)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: preview.aiSummary.map((a) {
                  final isAllow = a['status'] == 'ALLOW';
                  return Chip(
                    avatar: Icon(isAllow ? Icons.check_circle : Icons.cancel, color: isAllow ? const Color(0xFF6B4C9A) : AppTheme.textMuted, size: 16),
                    label: Text('${a['name']}: ${a['status']}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isAllow ? const Color(0xFF6B4C9A) : AppTheme.textMuted)),
                    backgroundColor: isAllow ? const Color(0xFFF3E8FF) : AppTheme.creamBg,
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // 3. Matrix Rules Breakdown Table
              const Text('Permutation Evaluation Table', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textDark)),
              const SizedBox(height: 8),
              Table(
                border: TableBorder.all(color: AppTheme.borderGray, width: 1),
                columnWidths: const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(2),
                  2: FlexColumnWidth(2),
                  3: FlexColumnWidth(4),
                },
                children: [
                  TableRow(
                    decoration: const BoxDecoration(color: AppTheme.creamBg),
                    children: const [
                      Padding(padding: EdgeInsets.all(8.0), child: Text('Browser', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textDark))),
                      Padding(padding: EdgeInsets.all(8.0), child: Text('AI Resource', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textDark))),
                      Padding(padding: EdgeInsets.all(8.0), child: Text('Result', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textDark))),
                      Padding(padding: EdgeInsets.all(8.0), child: Text('Rationale', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textDark))),
                    ],
                  ),
                  ...preview.matrixRules.map((rule) {
                    final isAllow = rule.pairPermission == 'ALLOW' || rule.pairPermission == 'ALLOW_BROWSER_NO_AI';
                    return TableRow(
                      children: [
                        Padding(padding: const EdgeInsets.all(8.0), child: Text(rule.browserName, style: const TextStyle(fontSize: 12))),
                        Padding(padding: const EdgeInsets.all(8.0), child: Text(rule.aiName, style: const TextStyle(fontSize: 12))),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isAllow ? AppTheme.softGreen : const Color(0xFFFDE8E8),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              rule.pairPermission,
                              style: TextStyle(
                                color: isAllow ? AppTheme.primaryGreen : AppTheme.errorMuted,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                        Padding(padding: const EdgeInsets.all(8.0), child: Text(rule.reason, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted))),
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
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryGreen,
            elevation: 0,
          ),
          child: const Text('Close Simulation', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
