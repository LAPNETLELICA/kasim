import 'dart:io';


class BrowserPolicyGuard {
  // These are enforcement adapters, not a browser catalogue. A path is used
  // only when the lecturer has entered a matching browser resource.
  static const Map<String, String> _chromiumPolicyRoots = {
    'chrome': r'HKCU\Software\Policies\Google\Chrome',
    'edge': r'HKCU\Software\Policies\Microsoft\Edge',
    'brave': r'HKCU\Software\Policies\BraveSoftware\Brave',
    'vivaldi': r'HKCU\Software\Policies\Vivaldi',
  };

  static Future<void> applyManagedBrowserPolicies(Map<String, dynamic> policy) async {
    if (!Platform.isWindows) return;
    try {
      final registeredAi = List<dynamic>.from(policy['registered_ai'] ?? const []);
      final allowedAi = List<String>.from(policy['allowed_ai'] ?? const []);
      final registeredBrowsers = List<dynamic>.from(policy['registered_browsers'] ?? const []);
      final allowedBrowsers = List<String>.from(policy['allowed_browsers'] ?? const []);
      final browserMode = policy['browser_mode'] ?? 'ALLOW_SELECTED';
      final aiMode = policy['ai_mode'] ?? 'BLOCK_ALL';
      final webScope = policy['web_access_scope'] ?? 'ANY_SITE';

      final blocked = <String>[];
      final allowed = <String>[];
      if (webScope == 'AI_ONLY') blocked.add('*');

      for (final raw in registeredAi) {
        final ai = Map<String, dynamic>.from(raw as Map);
        final aiId = ai['id']?.toString() ?? '';
        final domains = List<String>.from(ai['domains'] ?? const []);
        final aiAllowed = aiMode == 'ALLOW_ANY' || allowedAi.contains(aiId);
        for (final domain in domains) {
          final patterns = ['*$domain*', '*.$domain', 'https://*.$domain/*', 'http://*.$domain/*'];
          if (aiAllowed) {
            allowed.addAll(patterns);
          } else {
            blocked.addAll(patterns);
          }
        }
      }

      if (blocked.isEmpty && allowed.isEmpty) return;
      final targetRoots = <String>{};
      if (browserMode == 'ALLOW_ANY') {
        targetRoots.addAll(_chromiumPolicyRoots.values);
      }
      for (final raw in registeredBrowsers) {
        final browser = Map<String, dynamic>.from(raw as Map);
        final browserId = browser['id']?.toString() ?? '';
        if (browserMode != 'ALLOW_ANY' && !allowedBrowsers.contains(browserId)) continue;
        final name = browser['name']?.toString().toLowerCase() ?? '';
        String? root;
        for (final adapter in _chromiumPolicyRoots.entries) {
          if (name.contains(adapter.key)) {
            root = adapter.value;
            break;
          }
        }
        if (root != null) targetRoots.add(root);
      }
      for (final root in targetRoots) {
        await _writeRegistryPolicies(root, blocked, allowed);
      }
    } catch (_) {}
  }

  static Future<void> clearManagedBrowserPolicies() async {
    if (!Platform.isWindows) return;
    for (final root in _chromiumPolicyRoots.values) {
      try {
        await Process.run('reg', ['delete', '$root\\URLBlocklist', '/f']);
        await Process.run('reg', ['delete', '$root\\URLAllowlist', '/f']);
      } catch (_) {}
    }
  }

  static Future<void> _writeRegistryPolicies(
    String root,
    List<String> blocklist,
    List<String> allowlist,
  ) async {
    final blockPath = '$root\\URLBlocklist';
    final allowPath = '$root\\URLAllowlist';
    await Process.run('reg', ['delete', blockPath, '/f']);
    await Process.run('reg', ['delete', allowPath, '/f']);
    for (var i = 0; i < blocklist.length; i++) {
      await Process.run('reg', [
        'add', blockPath, '/v', '${i + 1}', '/t', 'REG_SZ', '/d', blocklist[i], '/f',
      ]);
    }
    for (var i = 0; i < allowlist.length; i++) {
      await Process.run('reg', [
        'add', allowPath, '/v', '${i + 1}', '/t', 'REG_SZ', '/d', allowlist[i], '/f',
      ]);
    }
  }
}
