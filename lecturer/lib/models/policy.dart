class AccessPolicy {
  final String id;
  final String title;
  final String? description;
  final int version;
  final String defaultAction;
  final String browserMode;
  final String aiMode;
  final String desktopAppMode;
  final List<String> allowedBrowsers;
  final List<String> allowedAi;
  final Map<String, List<String>> browserAiMatrix;
  final List<String> allowedDesktopApps;
  final String? signature;
  final String lecturerId;

  AccessPolicy({
    required this.id,
    required this.title,
    this.description,
    required this.version,
    this.defaultAction = 'DENY',
    this.browserMode = 'ALLOW_SELECTED',
    this.aiMode = 'ALLOW_SELECTED',
    this.desktopAppMode = 'BLOCK_ALL_UNAUTHORIZED',
    required this.allowedBrowsers,
    required this.allowedAi,
    required this.browserAiMatrix,
    required this.allowedDesktopApps,
    this.signature,
    required this.lecturerId,
  });

  factory AccessPolicy.fromJson(Map<String, dynamic> json) {
    Map<String, List<String>> matrix = {};
    if (json['browser_ai_matrix'] != null) {
      (json['browser_ai_matrix'] as Map<String, dynamic>).forEach((key, value) {
        matrix[key] = List<String>.from(value ?? []);
      });
    }

    return AccessPolicy(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      version: json['version'] ?? 1,
      defaultAction: json['default_action'] ?? 'DENY',
      browserMode: json['browser_mode'] ?? 'ALLOW_SELECTED',
      aiMode: json['ai_mode'] ?? 'ALLOW_SELECTED',
      desktopAppMode: json['desktop_app_mode'] ?? 'BLOCK_ALL_UNAUTHORIZED',
      allowedBrowsers: List<String>.from(json['allowed_browsers'] ?? []),
      allowedAi: List<String>.from(json['allowed_ai'] ?? []),
      browserAiMatrix: matrix,
      allowedDesktopApps: List<String>.from(json['allowed_desktop_apps'] ?? []),
      signature: json['signature'],
      lecturerId: json['lecturer_id'] ?? '',
    );
  }
}

class PreviewMatrixItem {
  final String browserName;
  final String browserStatus;
  final String aiName;
  final String aiStatus;
  final String pairPermission;
  final String reason;

  PreviewMatrixItem({
    required this.browserName,
    required this.browserStatus,
    required this.aiName,
    required this.aiStatus,
    required this.pairPermission,
    required this.reason,
  });

  factory PreviewMatrixItem.fromJson(Map<String, dynamic> json) {
    return PreviewMatrixItem(
      browserName: json['browser_name'] ?? '',
      browserStatus: json['browser_status'] ?? 'DENY',
      aiName: json['ai_name'] ?? '',
      aiStatus: json['ai_status'] ?? 'DENY',
      pairPermission: json['pair_permission'] ?? 'DENY',
      reason: json['reason'] ?? '',
    );
  }
}

class PolicyPreviewResponse {
  final String policyTitle;
  final String defaultAction;
  final List<Map<String, dynamic>> browserSummary;
  final List<Map<String, dynamic>> aiSummary;
  final List<PreviewMatrixItem> matrixRules;
  final List<Map<String, dynamic>> desktopAppSummary;

  PolicyPreviewResponse({
    required this.policyTitle,
    this.defaultAction = 'DENY',
    required this.browserSummary,
    required this.aiSummary,
    required this.matrixRules,
    required this.desktopAppSummary,
  });

  factory PolicyPreviewResponse.fromJson(Map<String, dynamic> json) {
    var rawRules = json['matrix_rules'] as List? ?? [];
    List<PreviewMatrixItem> rules = rawRules.map((item) => PreviewMatrixItem.fromJson(item)).toList();

    return PolicyPreviewResponse(
      policyTitle: json['policy_title'] ?? '',
      defaultAction: json['default_action'] ?? 'DENY',
      browserSummary: List<Map<String, dynamic>>.from(json['browser_summary'] ?? []),
      aiSummary: List<Map<String, dynamic>>.from(json['ai_summary'] ?? []),
      matrixRules: rules,
      desktopAppSummary: List<Map<String, dynamic>>.from(json['desktop_app_summary'] ?? []),
    );
  }
}
