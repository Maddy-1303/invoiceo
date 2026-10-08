// Owner-only helper for the "Forgot password?" flow.
//
//   dart run tool/reset_code_tool.dart keygen
//       Makes the key pair once. The PRIVATE key is saved to
//       ~/.invoiceo/reset_private_key.txt (outside the project, never commit
//       it). Only the PUBLIC key is printed, to paste into
//       lib/utils/reset_code_verifier.dart.
//
//   dart run tool/reset_code_tool.dart sign <installation-id> <username>
//       Prints the Response Code for that Installation ID and username
//       (valid ~3 days). The code only works for that username, so check
//       the person really owns it, especially for 'admin'. Quote a username
//       that has spaces.
//
// The signed text must match ResetCodeVerifier:
// '<installationId>:<username trimmed and lowercased>:<utcDay>'.
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

File get _keyFile {
  final home = Platform.environment['HOME'] ?? '.';
  return File('$home/.invoiceo/reset_private_key.txt');
}

Future<void> main(List<String> args) async {
  final algorithm = Ed25519();
  if (args.isEmpty) return _usage();

  switch (args[0]) {
    case 'keygen':
      if (_keyFile.existsSync()) {
        stderr.writeln('A private key already exists at ${_keyFile.path}.\n'
            'Not overwriting it: a new key would stop every code from working.');
        exit(1);
      }
      final pair = await algorithm.newKeyPair();
      final seed = await pair.extractPrivateKeyBytes();
      final pub = (await pair.extractPublicKey()).bytes;
      _keyFile.parent.createSync(recursive: true);
      _keyFile.writeAsStringSync(base64.encode(seed));
      Process.runSync('chmod', ['600', _keyFile.path]);
      stdout.writeln('Private key saved to ${_keyFile.path} (keep it secret, back it up).');
      stdout.writeln('Public key bytes for reset_code_verifier.dart:');
      stdout.writeln(pub.join(', '));
    case 'sign':
      if (args.length < 3 || args[2].trim().isEmpty) return _usage();
      if (!_keyFile.existsSync()) {
        stderr.writeln('No private key at ${_keyFile.path}. Run keygen first.');
        exit(1);
      }
      final seed = base64.decode(_keyFile.readAsStringSync().trim());
      final pair = await algorithm.newKeyPairFromSeed(seed);
      final id = args[1].trim();
      final user = args[2].trim().toLowerCase();
      final day = DateTime.now().toUtc().millisecondsSinceEpoch ~/
          Duration.millisecondsPerDay;
      final sig =
          await algorithm.sign(utf8.encode('$id:$user:$day'), keyPair: pair);
      stdout.writeln(base64.encode(sig.bytes));
    default:
      _usage();
  }
}

void _usage() {
  stderr.writeln(
      'usage: dart run tool/reset_code_tool.dart keygen | sign <installation-id> <username>');
  exit(64);
}
