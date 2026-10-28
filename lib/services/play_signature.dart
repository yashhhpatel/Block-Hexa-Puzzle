import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Checks a Google Play purchase signature (SHA256withRSA) against the app's
/// base64 public key from Play Console. On-device check: it stops tampered
/// purchase data, but a server-side check with the Play Developer API is
/// stronger if you ever add a backend.
bool verifyPlaySignature({
  required String base64PublicKey,
  required String signedData,
  required String signature,
}) {
  try {
    final key = _parsePublicKey(base64Decode(base64PublicKey));
    final signer = RSASigner(SHA256Digest(), '0609608648016503040201')
      ..init(false, PublicKeyParameter<RSAPublicKey>(key));
    return signer.verifySignature(
      Uint8List.fromList(utf8.encode(signedData)),
      RSASignature(base64Decode(signature)),
    );
  } catch (_) {
    return false;
  }
}

/// Reads modulus and exponent from an X.509 SubjectPublicKeyInfo (DER).
RSAPublicKey _parsePublicKey(Uint8List der) {
  final r = _Der(der);
  r.enter(0x30); // SubjectPublicKeyInfo
  r.skip(0x30); // AlgorithmIdentifier
  r.enter(0x03); // BIT STRING
  r.pos++; // unused-bits byte
  r.enter(0x30); // RSAPublicKey
  final modulus = r.integer();
  final exponent = r.integer();
  return RSAPublicKey(modulus, exponent);
}

class _Der {
  final Uint8List b;
  int pos = 0;
  _Der(this.b);

  int _length() {
    var len = b[pos++];
    if (len & 0x80 == 0) return len;
    final n = len & 0x7f;
    len = 0;
    for (var i = 0; i < n; i++) {
      len = (len << 8) | b[pos++];
    }
    return len;
  }

  void _expect(int tag) {
    if (b[pos++] != tag) throw const FormatException('Unexpected DER tag');
  }

  /// Steps inside a constructed element (its contents follow).
  void enter(int tag) {
    _expect(tag);
    _length();
  }

  void skip(int tag) {
    _expect(tag);
    final len = _length(); // read first: it advances pos
    pos += len;
  }

  BigInt integer() {
    _expect(0x02);
    final len = _length();
    var v = BigInt.zero;
    for (var i = 0; i < len; i++) {
      v = (v << 8) | BigInt.from(b[pos++]);
    }
    return v;
  }
}
