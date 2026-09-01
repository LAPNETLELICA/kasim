import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models/exam.dart';
import '../services/api_service.dart';


class _PolicyOption {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool needsBrowser;
  final bool needsAi;

  const _PolicyOption({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.needsBrowser = false,
    this.needsAi = false,
  });
}


const _policyOptions = [
  _PolicyOption(
    id: 'SPECIFIC_BROWSER',
    title: 'Specific browser',
    description: 'Only one named browser can run. Web access is otherwise unrestricted.',
    icon: Icons.language_outlined,
    needsBrowser: true,
  ),
  _PolicyOption(
    id: 'SPECIFIC_AI',
    title: 'Specific AI only',
    description: 'Any browser may open one named AI service. Standard websites are blocked.',
    icon: Icons.auto_awesome_outlined,
    needsAi: true,
  ),
  _PolicyOption(
    id: 'SPECIFIC_BROWSER_NO_AI',
    title: 'Browser without AI',
    description: 'One named browser may browse standard websites; AI destinations are blocked.',
    icon: Icons.block_outlined,
    needsBrowser: true,
  ),
  _PolicyOption(
    id: 'ANY_BROWSER_NO_AI',
    title: 'Any browser, no AI',
    description: 'Students may use any installed browser for standard browsing only.',
    icon: Icons.public_outlined,
  ),
  _PolicyOption(
    id: 'SPECIFIC_BROWSER_AND_AI',
    title: 'Browser + specific AI',
    description: 'One named browser is allowed, together with exactly one named AI service.',
    icon: Icons.hub_outlined,
    needsBrowser: true,
    needsAi: true,
  ),
];


class CreateExamSessionDialog extends StatefulWidget {
  final VoidCallback onSessionCreated;

  const CreateExamSessionDialog({
    super.key,
    required this.onSessionCreated,
  });

  @override
  State<CreateExamSessionDialog> createState() => _CreateExamSessionDialogState();
}


class _CreateExamSessionDialogState extends State<CreateExamSessionDialog> {
  int step = 0;
  String selectedMode = 'SPECIFIC_BROWSER_NO_AI';
  bool cameraRequired = false;
  bool submissionsEnabled = true;
  bool submitting = false;
  String? error;
  ExamSession? createdExam;

  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final durationController = TextEditingController(text: '60');
  final browserNameController = TextEditingController();
  final browserExecutablesController = TextEditingController();
  final aiNameController = TextEditingController();
  final aiDomainsController = TextEditingController();
  final aiDesktopController = TextEditingController();

  _PolicyOption get policy => _policyOptions.firstWhere((item) => item.id == selectedMode);

  List<String> _csv(TextEditingController controller) => controller.text
      .split(',')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList();

  bool _validateStep() {
    if (step == 0) {
      final duration = int.tryParse(durationController.text.trim());
      if (titleController.text.trim().length < 3) {
        error = 'Enter a clear exam title.';
        return false;
      }
      if (duration == null || duration < 1 || duration > 1440) {
        error = 'Duration must be between 1 and 1,440 minutes.';
        return false;
      }
    }
    if (step == 1) {
      if (policy.needsBrowser && browserNameController.text.trim().length < 2) {
        error = 'Enter the browser name for this policy.';
        return false;
      }
      if (policy.needsAi && aiNameController.text.trim().length < 2) {
        error = 'Enter the AI service name for this policy.';
        return false;
      }
      if (policy.needsAi && _csv(aiDomainsController).isEmpty) {
        error = 'Enter at least one AI domain, such as assistant.example.com.';
        return false;
      }
    }
    error = null;
    return true;
  }

  Future<void> _createSession() async {
    if (!_validateStep()) {
      setState(() {});
      return;
    }
    setState(() {
      submitting = true;
      error = null;
    });
    try {
      final exam = await ApiService.createExam(
        title: titleController.text.trim(),
        description: descriptionController.text.trim(),
        durationMinutes: int.parse(durationController.text.trim()),
        policyMode: selectedMode,
        browserName: policy.needsBrowser ? browserNameController.text.trim() : null,
        browserExecutables: _csv(browserExecutablesController),
        aiName: policy.needsAi ? aiNameController.text.trim() : null,
        aiDomains: _csv(aiDomainsController),
        aiDesktopExecutables: _csv(aiDesktopController),
        cameraRequired: cameraRequired,
        submissionsEnabled: submissionsEnabled,
      );
      widget.onSessionCreated();
      if (mounted) setState(() => createdExam = exam);
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    durationController.dispose();
    browserNameController.dispose();
    browserExecutablesController.dispose();
    aiNameController.dispose();
    aiDomainsController.dispose();
    aiDesktopController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 820,
        constraints: const BoxConstraints(maxHeight: 760),
        decoration: BoxDecoration(
          color: AppTheme.cardWhite,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.borderGray),
          boxShadow: const [BoxShadow(color: Color(0x1A1E2D24), blurRadius: 36, offset: Offset(0, 16))],
        ),
        child: createdExam != null ? _buildSuccess() : _buildWizard(),
      ),
    );
  }

  Widget _buildWizard() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 20, 18),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: AppTheme.softGreen, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.add_moderator_outlined, color: AppTheme.primaryGreen),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Create exam session', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
                    SizedBox(height: 2),
                    Text('Configure the waiting room, device policy, and evidence settings.', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  ],
                ),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: AppTheme.textMuted)),
            ],
          ),
        ),
        const Divider(height: 1, color: AppTheme.borderGray),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 18, 28, 12),
          child: Row(
            children: [
              _stepIndicator(0, 'Session'),
              _stepLine(0),
              _stepIndicator(1, 'Access policy'),
              _stepLine(1),
              _stepIndicator(2, 'Monitoring & review'),
            ],
          ),
        ),
        if (error != null)
          Container(
            margin: const EdgeInsets.fromLTRB(28, 4, 28, 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(color: const Color(0xFFFDECEC), borderRadius: BorderRadius.circular(9), border: Border.all(color: const Color(0xFFF4CACA))),
            child: Row(children: [
              const Icon(Icons.error_outline, color: AppTheme.errorMuted, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(error!, style: const TextStyle(color: AppTheme.errorMuted, fontSize: 12, fontWeight: FontWeight.w600))),
            ]),
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
            child: [
              _buildSessionStep(),
              _buildPolicyStep(),
              _buildReviewStep(),
            ][step],
          ),
        ),
        const Divider(height: 1, color: AppTheme.borderGray),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              if (step > 0)
                OutlinedButton.icon(
                  onPressed: submitting ? null : () => setState(() { step--; error = null; }),
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Back'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.textDark, side: const BorderSide(color: AppTheme.borderGray), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13)),
                ),
              const Spacer(),
              TextButton(onPressed: submitting ? null : () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted))),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: submitting ? null : () {
                  if (!_validateStep()) {
                    setState(() {});
                  } else if (step < 2) {
                    setState(() { step++; error = null; });
                  } else {
                    _createSession();
                  }
                },
                icon: submitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Icon(step == 2 ? Icons.check : Icons.arrow_forward, size: 16, color: Colors.white),
                label: Text(step == 2 ? 'Create waiting room' : 'Continue', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepIndicator(int index, String label) {
    final active = step == index;
    final done = step > index;
    return Row(children: [
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(color: active || done ? AppTheme.primaryGreen : AppTheme.creamBg, shape: BoxShape.circle, border: Border.all(color: active || done ? AppTheme.primaryGreen : AppTheme.borderGray)),
        child: Center(child: done ? const Icon(Icons.check, size: 15, color: Colors.white) : Text('${index + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: active ? Colors.white : AppTheme.textMuted))),
      ),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(fontSize: 12, fontWeight: active ? FontWeight.w800 : FontWeight.w600, color: active ? AppTheme.textDark : AppTheme.textMuted)),
    ]);
  }

  Widget _stepLine(int index) => Expanded(child: Container(margin: const EdgeInsets.symmetric(horizontal: 12), height: 1, color: step > index ? AppTheme.primaryGreen : AppTheme.borderGray));

  Widget _buildSessionStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Session details', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
      const SizedBox(height: 5),
      const Text('Students will see these details in the desktop waiting room.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
      const SizedBox(height: 22),
      TextField(controller: titleController, decoration: _input('Exam title', 'e.g. Data Structures · Final Examination')),
      const SizedBox(height: 14),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 2, child: TextField(controller: descriptionController, maxLines: 3, decoration: _input('Instructions (optional)', 'Short instructions visible before the exam begins'))),
        const SizedBox(width: 14),
        Expanded(child: TextField(controller: durationController, keyboardType: TextInputType.number, decoration: _input('Duration', '60', suffix: 'minutes'))),
      ]),
      const SizedBox(height: 18),
      _infoCard(Icons.vpn_key_outlined, 'A six-character session code is generated after creation. Students enter it with their name in the desktop client.'),
    ]);
  }

  Widget _buildPolicyStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Choose one access policy', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
      const SizedBox(height: 5),
      const Text('Kasim keeps no default browser or AI list. Enter only the resources required by this session.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
      const SizedBox(height: 16),
      ..._policyOptions.map((option) => _policyCard(option)),
      const SizedBox(height: 18),
      if (policy.needsBrowser) ...[
        const Text('Browser identity', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(controller: browserNameController, decoration: _input('Browser name', 'e.g. Vivaldi'))),
          const SizedBox(width: 12),
          Expanded(child: TextField(controller: browserExecutablesController, decoration: _input('Executable aliases (optional)', 'vivaldi.exe, vivaldi'))),
        ]),
        const SizedBox(height: 16),
      ],
      if (policy.needsAi) ...[
        const Text('AI identity', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(controller: aiNameController, decoration: _input('AI service name', 'e.g. University Tutor AI'))),
          const SizedBox(width: 12),
          Expanded(child: TextField(controller: aiDomainsController, decoration: _input('Domains', 'tutor.example.edu, api.example.edu'))),
        ]),
        const SizedBox(height: 12),
        TextField(controller: aiDesktopController, decoration: _input('Desktop executable aliases (optional)', 'TutorAI.exe')),
      ],
    ]);
  }

  Widget _policyCard(_PolicyOption option) {
    final selected = selectedMode == option.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        onTap: () => setState(() { selectedMode = option.id; error = null; }),
        borderRadius: BorderRadius.circular(11),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: selected ? AppTheme.softGreen : AppTheme.cardWhite, borderRadius: BorderRadius.circular(11), border: Border.all(color: selected ? AppTheme.primaryGreen : AppTheme.borderGray, width: selected ? 1.5 : 1)),
          child: Row(children: [
            Container(width: 38, height: 38, decoration: BoxDecoration(color: selected ? Colors.white : AppTheme.creamBg, borderRadius: BorderRadius.circular(9)), child: Icon(option.icon, color: selected ? AppTheme.primaryGreen : AppTheme.textMuted, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(option.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
              const SizedBox(height: 2),
              Text(option.description, style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted, height: 1.3)),
            ])),
            const SizedBox(width: 12),
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? AppTheme.primaryGreen : AppTheme.borderGray, size: 21),
          ]),
        ),
      ),
    );
  }

  Widget _buildReviewStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Monitoring & collection', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
      const SizedBox(height: 5),
      const Text('Choose what the desktop client activates when a student joins.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
      const SizedBox(height: 18),
      _settingTile(
        icon: Icons.videocam_outlined,
        title: 'Camera monitoring',
        description: 'Request camera access and show the latest live frame for each connected student.',
        value: cameraRequired,
        onChanged: (value) => setState(() => cameraRequired = value),
      ),
      const SizedBox(height: 10),
      _settingTile(
        icon: Icons.upload_file_outlined,
        title: 'Student document uploads',
        description: 'Allow common document, spreadsheet, image, archive, and source-code files.',
        value: submissionsEnabled,
        onChanged: (value) => setState(() => submissionsEnabled = value),
      ),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: AppTheme.creamBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.borderGray)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Session summary', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
          const SizedBox(height: 12),
          _summaryRow('Exam', titleController.text.trim()),
          _summaryRow('Duration', '${durationController.text.trim()} minutes'),
          _summaryRow('Access policy', policy.title),
          if (policy.needsBrowser) _summaryRow('Browser', browserNameController.text.trim()),
          if (policy.needsAi) _summaryRow('AI service', aiNameController.text.trim()),
          _summaryRow('Camera', cameraRequired ? 'Required' : 'Off'),
          _summaryRow('Documents', submissionsEnabled ? 'Accepted' : 'Disabled', isLast: true),
        ]),
      ),
      const SizedBox(height: 14),
      _infoCard(Icons.shield_outlined, 'The session opens in waiting mode. The countdown and device policy begin only when you launch it from the monitor.'),
    ]);
  }

  Widget _settingTile({required IconData icon, required String title, required String description, required bool value, required ValueChanged<bool> onChanged}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.cardWhite, borderRadius: BorderRadius.circular(11), border: Border.all(color: AppTheme.borderGray)),
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: AppTheme.softGreen, borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: AppTheme.primaryGreen, size: 21)),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
          const SizedBox(height: 2),
          Text(description, style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted, height: 1.3)),
        ])),
        Switch(value: value, onChanged: onChanged, activeColor: AppTheme.primaryGreen),
      ]),
    );
  }

  Widget _summaryRow(String label, String value, {bool isLast = false}) => Padding(
        padding: EdgeInsets.only(bottom: isLast ? 0 : 9),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted))),
          Expanded(child: Text(value.isEmpty ? 'Not provided' : value, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.textDark))),
        ]),
      );

  Widget _infoCard(IconData icon, String text) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: AppTheme.softGreen, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.paleGreen)),
        child: Row(children: [
          Icon(icon, color: AppTheme.primaryGreen, size: 19),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 11.5, color: AppTheme.primaryGreen, height: 1.35, fontWeight: FontWeight.w600))),
        ]),
      );

  InputDecoration _input(String label, String hint, {String? suffix}) => InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffix,
        labelStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
        hintStyle: const TextStyle(color: Color(0xFF9AA79F), fontSize: 12),
        filled: true,
        fillColor: AppTheme.creamBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppTheme.borderGray), borderRadius: BorderRadius.circular(9)),
        focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 1.5), borderRadius: BorderRadius.circular(9)),
      );

  Widget _buildSuccess() {
    final exam = createdExam!;
    return Padding(
      padding: const EdgeInsets.all(34),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 64, height: 64, decoration: const BoxDecoration(color: AppTheme.softGreen, shape: BoxShape.circle), child: const Icon(Icons.check_circle_outline, color: AppTheme.primaryGreen, size: 34)),
        const SizedBox(height: 18),
        const Text('Waiting room created', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.textDark)),
        const SizedBox(height: 6),
        Text(exam.title, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
        const SizedBox(height: 26),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: AppTheme.creamBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.borderGray)),
          child: Column(children: [
            const Text('STUDENT JOIN CODE', style: TextStyle(fontSize: 10, letterSpacing: 1.3, fontWeight: FontWeight.w800, color: AppTheme.textMuted)),
            const SizedBox(height: 8),
            SelectableText(exam.examCode, style: const TextStyle(fontSize: 40, letterSpacing: 7, fontWeight: FontWeight.w900, color: AppTheme.primaryGreen)),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: exam.examCode));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session code copied')));
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy code'),
              style: TextButton.styleFrom(foregroundColor: AppTheme.primaryGreen),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        const Text('Students can join now. Open the session monitor when you are ready to start the countdown.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, height: 1.4, color: AppTheme.textMuted)),
        const SizedBox(height: 26),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
            child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ),
      ]),
    );
  }
}
