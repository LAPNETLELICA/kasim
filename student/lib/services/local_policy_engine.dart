class LocalPolicyEngine {
  final Map<String, dynamic> policyPayload;

  LocalPolicyEngine(this.policyPayload);

  String get defaultAction => policyPayload['default_action'] ?? 'DENY';
  List<dynamic> get registeredBrowsers => policyPayload['registered_browsers'] ?? [];
  List<dynamic> get registeredAi => policyPayload['registered_ai'] ?? [];
  List<String> get allowedBrowsers => List<String>.from(policyPayload['allowed_browsers'] ?? []);
  List<String> get allowedAi => List<String>.from(policyPayload['allowed_ai'] ?? []);
  Map<String, dynamic> get matrix => policyPayload['browser_ai_matrix'] ?? {};
  List<String> get allowedDesktopApps => List<String>.from(policyPayload['allowed_desktop_apps'] ?? []);

  /// Checks if a running executable process is an authorized browser.
  /// Returns (isAllowed: bool, browserName: String, reason: String).
  Map<String, dynamic> evaluateProcessExecutable(String exeName) {
    final exeLower = exeName.toLowerCase().trim();

    // 1. Check if desktop AI application
    for (final ai in registeredAi) {
      final desktopExecs = List<String>.from(ai['desktop_executables'] ?? []);
      for (final dExe in desktopExecs) {
        if (dExe.toLowerCase() == exeLower) {
          final isAllowed = allowedDesktopApps.contains(dExe);
          return {
            'permission': isAllowed ? 'ALLOW' : 'DENY',
            'resource_name': '${ai['name']} Desktop Application ($dExe)',
            'reason': isAllowed ? 'Explicitly authorized desktop app' : 'Unauthorized desktop AI application (Default Deny)',
            'type': 'DESKTOP_AI_APP'
          };
        }
      }
    }

    // 2. Check if browser executable
    Map<String, dynamic>? matchedBrowser;
    for (final b in registeredBrowsers) {
      final execs = List<String>.from(b['executables'] ?? []);
      for (final bExe in execs) {
        if (bExe.toLowerCase() == exeLower) {
          matchedBrowser = Map<String, dynamic>.from(b);
          break;
        }
      }
      if (matchedBrowser != null) break;
    }

    if (matchedBrowser == null) {
      // Process is not a registered browser. Under default-deny for browsers, unlisted browsers are blocked if browser_mode == ALLOW_SELECTED.
      return {
        'permission': 'ALLOW', // Non-browser OS process (e.g. Explorer, system services)
        'resource_name': exeName,
        'reason': 'System OS process',
        'type': 'SYSTEM_PROCESS'
      };
    }

    final browserId = matchedBrowser['id'] as String;
    final isAllowedBrowser = allowedBrowsers.contains(browserId);

    if (isAllowedBrowser) {
      return {
        'permission': 'ALLOW',
        'resource_name': matchedBrowser['name'],
        'reason': 'Explicitly authorized browser',
        'type': 'BROWSER'
      };
    } else {
      return {
        'permission': 'DENY',
        'resource_name': matchedBrowser['name'],
        'reason': 'Unauthorized browser (Default Deny)',
        'type': 'BROWSER'
      };
    }
  }

  /// Evaluates Browser + AI Domain request.
  /// Returns (permission: "ALLOW" | "DENY", reason: String).
  Map<String, dynamic> evaluateBrowserDomainAccess(String browserId, String domain) {
    if (!allowedBrowsers.contains(browserId)) {
      return {
        'permission': 'DENY',
        'reason': 'Browser is unauthorized',
      };
    }

    // Check if domain belongs to a registered AI service
    Map<String, dynamic>? matchedAi;
    for (final ai in registeredAi) {
      final doms = List<String>.from(ai['domains'] ?? []);
      for (final dom in doms) {
        if (domain.toLowerCase() == dom.toLowerCase() || domain.toLowerCase().endsWith('.' + dom.toLowerCase())) {
          matchedAi = Map<String, dynamic>.from(ai);
          break;
        }
      }
      if (matchedAi != null) break;
    }

    if (matchedAi == null) {
      return {
        'permission': 'ALLOW',
        'reason': 'Standard web traffic (Not an AI domain)',
      };
    }

    final aiId = matchedAi['id'] as String;
    if (!allowedAi.contains(aiId)) {
      return {
        'permission': 'DENY',
        'reason': 'AI service ${matchedAi['name']} is globally denied',
      };
    }

    final allowedMatrixForBrowser = List<String>.from(matrix[browserId] ?? []);
    if (!allowedMatrixForBrowser.contains(aiId)) {
      return {
        'permission': 'DENY',
        'reason': 'AI service ${matchedAi['name']} is denied for this browser in policy matrix',
      };
    }

    return {
      'permission': 'ALLOW',
      'reason': 'Authorized Browser + AI combination',
    };
  }
}
