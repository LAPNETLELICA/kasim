class BrowserResource {
  final String id;
  final String name;
  final List<String> executables;
  final String? description;
  final bool isCustom;

  BrowserResource({
    required this.id,
    required this.name,
    required this.executables,
    this.description,
    this.isCustom = true,
  });

  factory BrowserResource.fromJson(Map<String, dynamic> json) {
    return BrowserResource(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      executables: List<String>.from(json['executables'] ?? []),
      description: json['description'],
      isCustom: json['is_custom'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'executables': executables,
    'description': description,
    'is_custom': isCustom,
  };
}

class AIResource {
  final String id;
  final String name;
  final List<String> domains;
  final List<String> desktopExecutables;
  final String? description;
  final bool isCustom;

  AIResource({
    required this.id,
    required this.name,
    required this.domains,
    required this.desktopExecutables,
    this.description,
    this.isCustom = true,
  });

  factory AIResource.fromJson(Map<String, dynamic> json) {
    return AIResource(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      domains: List<String>.from(json['domains'] ?? []),
      desktopExecutables: List<String>.from(json['desktop_executables'] ?? []),
      description: json['description'],
      isCustom: json['is_custom'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'domains': domains,
    'desktop_executables': desktopExecutables,
    'description': description,
    'is_custom': isCustom,
  };
}
