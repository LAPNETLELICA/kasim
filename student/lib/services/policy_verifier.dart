import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

class PolicyVerifier {
  static const String secretKey = 'kasim_policy_signing_secret_key_production_grade';
  static const String cacheFileName = '.policy_cache';

  static String generateHmacSignature(Map<String, dynamic> data) {
    final copy = Map<String, dynamic>.from(data);
    copy.remove('signature');
    
    // Sort keys canonically
    final sortedKeys = copy.keys.toList()..sort();
    final sortedMap = {for (var k in sortedKeys) k: copy[k]};
    final jsonStr = jsonEncode(sortedMap);

    final hmacSha256 = Hmac(sha256, utf8.encode(secretKey));
    final digest = hmacSha256.convert(utf8.encode(jsonStr));
    return digest.toString();
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
