import 'dart:convert';
import 'package:cryptography/cryptography.dart';

/// Verifies developer-issued password reset codes.
///
/// Challenge-response: the locked-out user shares their installationId and
/// username out-of-band; the developer signs
/// `installationId:username:utcDayBucket` (username trimmed and lowercased)
/// with a private Ed25519 key (never shipped with the app) and returns the
/// base64 signature as the "response code". A code only works for the
/// username it was made for. This file only holds the public key, so it
/// can't be used to forge codes even if decompiled.
class ResetCodeVerifier {
  ResetCodeVerifier._();

  /// Ed25519 public key bytes. Safe to ship - cannot sign, only verify.
  /// Matches the private key made by `tool/reset_code_tool.dart keygen`.
  static const List<int> _publicKeyBytes = [
    167, 135, 251, 247, 98, 187, 171, 5, 183, 188, 137, 135, 192, 1, 31, 184,
    106, 60, 34, 20, 70, 14, 233, 94, 82, 10, 110, 149, 116, 83, 14, 163,
  ];

  /// Days since Unix epoch, computed from UTC. Must match the signer
  /// script's formula exactly.
  static int utcDayBucket([DateTime? now]) {
    final utcNow = (now ?? DateTime.now()).toUtc();
    return utcNow.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
  }

  /// The username as it is signed: trimmed and lowercased. Must match the
  /// signer script.
  static String _normalizeUsername(String username) =>
      username.trim().toLowerCase();

  /// Verifies [responseCode] (base64 Ed25519 signature) against
  /// [installationId] and [username], trying today/yesterday/day-before UTC
  /// day buckets for ~3 day validity. Returns false on any mismatch or
  /// malformed input.
  static Future<bool> verifyResetCode({
    required String installationId,
    required String username,
    required String responseCode,
  }) async {
    late final List<int> signatureBytes;
    try {
      signatureBytes = base64.decode(responseCode.trim());
    } catch (_) {
      return false;
    }

    final algorithm = Ed25519();
    final publicKey = SimplePublicKey(_publicKeyBytes, type: KeyPairType.ed25519);
    final today = utcDayBucket();
    final user = _normalizeUsername(username);
    if (user.isEmpty) return false;

    for (final offset in [0, -1, -2]) {
      final bucket = today + offset;
      final payload = utf8.encode('$installationId:$user:$bucket');
      final signature = Signature(signatureBytes, publicKey: publicKey);
      try {
        final valid = await algorithm.verify(payload, signature: signature);
        if (valid) return true;
      } catch (_) {
        // Malformed signature bytes - treat as invalid, keep trying offsets.
      }
    }
    return false;
  }
}
