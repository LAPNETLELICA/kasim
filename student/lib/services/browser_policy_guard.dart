import 'dart:io';

class BrowserPolicyGuard {
  /// Enforces managed browser policy keys on Windows for Chrome and Edge.
  static Future<void> applyManagedBrowserPolicies(Map<String, dynamic> policyPayload) async {
    if (!Platform.isWindows) return;

    try {
      final registeredAi = List<dynamic>.from(policyPayload['registered_ai'] ?? []);
      final allowedAi = List<String>.from(policyPayload['allowed_ai'] ?? []);
      final matrix = Map<String, dynamic>.from(policyPayload['browser_ai_matrix'] ?? {});
      final allowedBrowsers = List<String>.from(policyPayload['allowed_browsers'] ?? []);

      // Chrome Browser ID match
      String? chromeId;
      for (final b in List<dynamic>.from(policyPayload['registered_browsers'] ?? [])) {
        if (b['name'].toString().toLowerCase().contains('chrome')) {
          chromeId = b['id'];
          break;
        }
      }

      if (chromeId != null && allowedBrowsers.contains(chromeId)) {
        final allowedMatrixAi = List<String>.from(matrix[chromeId] ?? []);

        List<String> blocklistDomains = [];
        List<String> allowlistDomains = [];

        for (final ai in registeredAi) {
          final aiId = ai['id'] as String;
          final domains = List<String>.from(ai['domains'] ?? []);

          if (allowedAi.contains(aiId) && allowedMatrixAi.contains(aiId)) {
            for (final d in domains) {
              allowlistDomains.add("https://*.$d/*");
              allowlistDomains.add("http://*.$d/*");
              allowlistDomains.add("*.$d");
            }
          } else {
            for (final d in domains) {
              blocklistDomains.add("https://*.$d/*");
              blocklistDomains.add("http://*.$d/*");
              blocklistDomains.add("*.$d");
            }
          }
        }

        // Inject Chrome Registry URLBlocklist policies if blocklist contains entries
        if (blocklistDomains.isNotEmpty) {
          await _writeChromeRegistryPolicies(blocklistDomains, allowlistDomains);
        }
      }
    } catch (_) {}
  }

  static Future<void> clearManagedBrowserPolicies() async {
    if (!Platform.isWindows) return;
    try {
      await Process.run('reg', ['delete', r'HKCU\Software\Policies\Google\Chrome\URLBlocklist', '/f']);
      await Process.run('reg', ['delete', r'HKCU\Software\Policies\Google\Chrome\URLAllowlist', '/f']);
    } catch (_) {}
  }

  static Future<void> _writeChromeRegistryPolicies(List<String> blocklist, List<String> allowlist) async {
    try {
      // Clear existing blocklist/allowlist keys
      await Process.run('reg', ['delete', r'HKCU\Software\Policies\Google\Chrome\URLBlocklist', '/f']);
      await Process.run('reg', ['delete', r'HKCU\Software\Policies\Google\Chrome\URLAllowlist', '/f']);

      // Add URLBlocklist entries
      for (int i = 0; i < blocklist.length; i++) {
        await Process.run('reg', [
          'add', r'HKCU\Software\Policies\Google\Chrome\URLBlocklist',
          '/v', '${i + 1}',
          '/t', 'REG_SZ',
          '/d', blocklist[i],
          '/f'
        ]);
      }

      // Add URLAllowlist entries
      for (int i = 0; i < allowlist.length; i++) {
        await Process.run('reg', [
          'add', r'HKCU\Software\Policies\Google\Chrome\URLAllowlist',
          '/v', '${i + 1}',
          '/t', 'REG_SZ',
          '/d', allowlist[i],
          '/f'
        ]);
      }
    } catch (_) {}
  }
}
