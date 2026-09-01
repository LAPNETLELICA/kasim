import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

class PolicyVerifier {
  static const String secretKey = 'kasim-local-development-signing-key';
  static const String cacheFileName = '.policy_cache';

  static String generateHmacSignature(Map<String, dynamic> data) {
    final copy = Map<String, dynamic>.from(data);
    copy.remove('signature');
    
    final jsonStr = jsonEncode(_canonicalize(copy));

    final hmacSha256 = Hmac(sha256, utf8.encode(secretKey));
    final digest = hmacSha256.convert(utf8.encode(jsonStr));
    return digest.toString();
  }

  static dynamic _canonicalize(dynamic value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return {for (final key in keys) key: _canonicalize(value[key])};
    }
    if (value is List) return value.map(_canonicalize).toList();
    return value;
  }

  static bool verifyPolicyPayload(Map<String, dynamic> payload) {
    final signature = payload['signature'] as String?;
    if (signature == null || signature.isEmpty) return false;

    final expectedSig = generateHmacSignature(payload);
    return signature == expectedSig;
  }

  static Future<void> savePolicyToCache(Map<String, dynamic> signedPolicy) async {
    try {
      final file = File(cacheFileName);
      await file.writeAsString(jsonEncode(signedPolicy));
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> loadPolicyFromCache() async {
    try {
      final file = File(cacheFileName);
      if (await file.exists()) {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        if (verifyPolicyPayload(json)) {
          // Check expires_at timestamp
          final expiresAtStr = json['expires_at'] as String?;
          if (expiresAtStr != null) {
            final expiresAt = DateTime.parse(expiresAtStr).toUtc();
            if (DateTime.now().toUtc().isBefore(expiresAt)) {
              return json;
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }
}
