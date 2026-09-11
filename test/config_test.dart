import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hubsight_sdk/hubsight_sdk.dart';

void main() {
  group('HscfgDecoder Tests', () {
    const testPin = '123456';
    late Uint8List validHscfgBytes;

    setUpAll(() async {
      // Create test ZIP archive containing urls.yml, key.yml, metadata.yml
      final archive = Archive();

      const urlsContent = '''
gateway_url: "https://cctv.quoctran.space"
api_base_url: "https://cctv.quoctran.space/api"
relay_ws_url: "wss://cctv.quoctran.space/relay"
webrtc_base_url: "https://cctv.quoctran.space:8555"
''';
      final urlsFile =
          ArchiveFile('urls.yml', urlsContent.length, utf8.encode(urlsContent));
      archive.addFile(urlsFile);

      const keyContent = '''
client_id: "hs_mob_test_client"
client_secret: "sec_test_secret_key"
client_name: "Test Mobile App"
allowed_scopes:
  - "cameras:view"
  - "playback:view"
''';
      final keyFile =
          ArchiveFile('key.yml', keyContent.length, utf8.encode(keyContent));
      archive.addFile(keyFile);

      const metaContent = '''
format_version: "1.0"
config_id: "cfg_test_12345"
name: "Test Config HQ"
description: "Cấu hình thử nghiệm"
created_by: "admin"
''';
      final metaFile = ArchiveFile(
          'metadata.yml', metaContent.length, utf8.encode(metaContent));
      archive.addFile(metaFile);

      final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive)!);

      // Generate Salt (16 bytes) and Nonce (12 bytes)
      final salt = Uint8List.fromList(List.generate(16, (i) => i + 1));
      final nonce = Uint8List.fromList(List.generate(12, (i) => i + 10));

      // Derive key using Argon2id
      final kdf = Argon2id(
        parallelism: 2,
        memory: 65536,
        iterations: 4,
        hashLength: 32,
      );
      final secretKey = await kdf.deriveKey(
        secretKey: SecretKey(utf8.encode(testPin)),
        nonce: salt,
      );

      // Encrypt with AES-256-GCM and AAD
      final magicHeader =
          Uint8List.fromList([0x48, 0x53, 0x43, 0x46, 0x47, 0x01]);
      final aesGcm = AesGcm.with256bits();
      final secretBox = await aesGcm.encrypt(
        zipBytes,
        secretKey: secretKey,
        nonce: nonce,
        aad: magicHeader,
      );

      // Assemble full .hscfg binary: Magic(6) + Salt(16) + Nonce(12) + Ciphertext + Tag(16)
      final builder = BytesBuilder();
      builder.add(magicHeader);
      builder.add(salt);
      builder.add(nonce);
      builder.add(secretBox.cipherText);
      builder.add(secretBox.mac.bytes);

      validHscfgBytes = builder.toBytes();
    });

    test('decrypts valid .hscfg container with correct PIN', () async {
      final config = await HscfgDecoder.decrypt(
        fileBytes: validHscfgBytes,
        pin6Digits: testPin,
        verifySignature: false,
      );

      expect(config.urls.gatewayUrl, equals('https://cctv.quoctran.space'));
      expect(config.urls.relayWsUrl, equals('wss://cctv.quoctran.space/relay'));
      expect(config.key.clientId, equals('hs_mob_test_client'));
      expect(config.key.clientName, equals('Test Mobile App'));
      expect(config.key.allowedScopes, contains('cameras:view'));
      expect(config.metadata.name, equals('Test Config HQ'));
      expect(config.apiKey, equals('hs_mob_test_client'));
    });

    test(
        'fails decryption when wrong PIN is supplied with configDecryptionFailed code',
        () async {
      try {
        await HscfgDecoder.decrypt(
          fileBytes: validHscfgBytes,
          pin6Digits: '654321',
          verifySignature: false,
        );
        fail('Should fail decryption');
      } on HubSightConfigException catch (e) {
        expect(e.code, equals(HubSightErrorCode.configDecryptionFailed));
        expect(e.wireCode, equals('CONFIG_DECRYPTION_FAILED'));
      }
    });

    test('fails when PIN is not 6 digits with configInvalidPinFormat code',
        () async {
      try {
        await HscfgDecoder.decrypt(
          fileBytes: validHscfgBytes,
          pin6Digits: '123',
        );
        fail('Should fail PIN validation');
      } on HubSightConfigException catch (e) {
        expect(e.code, equals(HubSightErrorCode.configInvalidPinFormat));
        expect(e.wireCode, equals('CONFIG_INVALID_PIN_FORMAT'));
      }
    });

    test('fails when magic header is invalid with configInvalidHeader code',
        () async {
      final corrupted = Uint8List.fromList(validHscfgBytes);
      corrupted[0] = 0x00; // corrupt magic header

      try {
        await HscfgDecoder.decrypt(
          fileBytes: corrupted,
          pin6Digits: testPin,
        );
        fail('Should fail header validation');
      } on HubSightConfigException catch (e) {
        expect(e.code, equals(HubSightErrorCode.configInvalidHeader));
        expect(e.wireCode, equals('CONFIG_INVALID_HEADER'));
      }
    });
  });

  group('HubSightQRPayload Tests', () {
    test('parses QR code JSON payload correctly', () {
      const qrJson = '''
{
  "v": 1,
  "config_id": "cfg_998877",
  "name": "Production QR",
  "download_url": "https://cctv.quoctran.space/api/storage/presigned/123",
  "sha256": "abcdef0123456789"
}
''';
      final payload = HubSightQRPayload.fromString(qrJson);
      expect(payload.version, equals(1));
      expect(payload.configId, equals('cfg_998877'));
      expect(payload.name, equals('Production QR'));
      expect(payload.downloadUrl, contains('presigned/123'));
      expect(payload.sha256, equals('abcdef0123456789'));
    });
  });
}
