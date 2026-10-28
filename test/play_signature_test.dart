import 'package:block_hexa_puzzle/services/play_signature.dart';
import 'package:flutter_test/flutter_test.dart';

// Test key pair generated with OpenSSL; the private half was thrown away.
const _pub = 'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEArQZmUKiKEuZPDjPSydgIsanb+4Mi/GP53PGCIxjuTj3r0P0TjYm8j6ACwar0oOUONfxyD2XHf7UmA5WNqSl7eVPraQS4W/h7JxNgYhzhxsLsrPTSrrExja06En4zbiA88cJdPziUpGZclEQ9xtx9otuYyvv9K9nuJuuX9efDkCvFjjLr0Pkof9rS9iGRAOGIVLEvXz0Eq6x0ynaemH1uSW2BcIodjZL1YXGh7vK9dECcZ8QIvmDaGpmBtPtRgwi+0Maxip+y+G215Pkbx24FhlLIJKWjtViVnfSkOcSkataunQBtwmbSRRz+Gw8W+VkbHx9FNjz4mox/v3x1YAvTmQIDAQAB';
const _data = r'{"orderId":"GPA.1234","packageName":"com.yashpatel.block_hexa_puzzle","productId":"remove_ads_monthly","purchaseState":0}';
const _sig = 'OBfbQSJrkOLeoZHbJAtEYFLbG46y/wmEn4OAFjzoeaMj/eUiNlOSC/nW1MA3QwoW3/y/wy0hkYQpHibUvN19CYEyE1mDhwJR5a6dhphnQPNh0z+0kOR0WDwwNcDs1du2rs60tdciRSs222oc7hLGGTX3dQ2RfXxRhrhBLFHHs9Ti33pOICtd/wlXxAEH+/xIU2bR2mbgP6tRPLtqI1VWCue4vRKMteWZZFEH2GQ/x0b0CdZlh1ppS4t/SZziwTPlb1IgIxeUV2k39gbTYOU1IDMwotKnlBXa03+1tmvvHR1NBlIvd372icXvPvRYM8VLQg/6rgQcAMWXbTgfGollrA==';

void main() {
  test('accepts a genuine Google Play style signature', () {
    expect(verifyPlaySignature(base64PublicKey: _pub, signedData: _data, signature: _sig),
        isTrue);
  });

  test('rejects tampered purchase data', () {
    final forged = _data.replaceAll('remove_ads_monthly', 'something_else');
    expect(verifyPlaySignature(base64PublicKey: _pub, signedData: forged, signature: _sig),
        isFalse);
  });

  test('rejects garbage keys and signatures without throwing', () {
    expect(verifyPlaySignature(base64PublicKey: 'bm90IGEga2V5', signedData: _data, signature: _sig),
        isFalse);
    expect(verifyPlaySignature(base64PublicKey: _pub, signedData: _data, signature: 'AAAA'),
        isFalse);
  });
}
