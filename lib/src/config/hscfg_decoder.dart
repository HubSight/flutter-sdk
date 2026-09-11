import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';
import 'package:yaml/yaml.dart';

import '../network/error_codes.dart';
import '../network/exceptions.dart';
import 'app_config.dart';

typedef HscfgDecoderException = HubSightConfigException;

/// Decoder for HubSight multi-layered secure container (.hscfg).
class HscfgDecoder {
  /// Magic Header: "HSCFG\x01" (6 bytes)
  static const List<int> magicHeader = [0x48, 0x53, 0x43, 0x46, 0x47, 0x01];

  /// Decrypts and parses the raw binary bytes of a `.hscfg` file using a 6-digit PIN.
  ///
  /// Optionally verifies the Ed25519 digital signature if [verifySignature] is true.
  static Future<HubSightAppConfig> decrypt({
    required Uint8List fileBytes,
    required String pin6Digits,
    bool verifySignature = true,
  }) async {
    final cleanPin = pin6Digits.trim();
    if (cleanPin.length != 6) {
      throw const HubSightConfigException(
        code: HubSightErrorCode.configInvalidPinFormat,
        developerMessage: 'Enrollment PIN must be exactly 6 digits.',
      );
    }

    // 1. Validate file size and Magic Header
    // Minimum size: 6 (magic) + 16 (salt) + 12 (nonce) + 16 (GCM auth tag) = 50 bytes
    if (fileBytes.length < 50) {
      throw const HubSightConfigException(
        code: HubSightErrorCode.configCorrupted,
        developerMessage:
            'Configuration file is corrupted or below minimum container size (50 bytes).',
      );
    }

    for (int i = 0; i < 6; i++) {
      if (fileBytes[i] != magicHeader[i]) {
        throw const HubSightConfigException(
          code: HubSightErrorCode.configInvalidHeader,
          developerMessage: 'Invalid magic header, expected binary HSCFG\\x01.',
        );
      }
    }

    // 2. Extract Salt, Nonce, Ciphertext and Auth Tag
    final salt = fileBytes.sublist(6, 22);
    final nonce = fileBytes.sublist(22, 34);
    final ciphertextWithTag = fileBytes.sublist(34);

    if (ciphertextWithTag.length < 16) {
      throw const HubSightConfigException(
        code: HubSightErrorCode.configCorrupted,
        developerMessage:
            'Ciphertext missing required 16-byte GCM authentication tag.',
      );
    }

    // 3. Derive 256-bit AES key using Argon2id
    final kdf = Argon2id(
      parallelism: 2,
      memory: 65536, // 64 MB
      iterations: 4,
      hashLength: 32,
    );

    final secretKey = await kdf.deriveKey(
      secretKey: SecretKey(utf8.encode(cleanPin)),
      nonce: salt,
    );

    // 4. Decrypt AES-256-GCM with AAD
    final aesGcm = AesGcm.with256bits();
    final cipherLen = ciphertextWithTag.length - 16;
    final cipherText = ciphertextWithTag.sublist(0, cipherLen);
    final macTag = ciphertextWithTag.sublist(cipherLen);

    final secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(macTag),
    );

    Uint8List decryptedZipBytes;
    try {
      final decrypted = await aesGcm.decrypt(
        secretBox,
        secretKey: secretKey,
        aad: magicHeader,
      );
      decryptedZipBytes = Uint8List.fromList(decrypted);
    } catch (e) {
      throw const HubSightConfigException(
        code: HubSightErrorCode.configDecryptionFailed,
        developerMessage:
            'AES-256-GCM decryption failed: incorrect PIN or tampered payload.',
      );
    }

    // 5. In-Memory ZIP Archive Decompression
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(decryptedZipBytes);
    } catch (e) {
      throw HubSightConfigException(
        code: HubSightErrorCode.configDecompressionFailed,
        developerMessage: 'Failed to decompress ZIP archive payload: $e',
      );
    }

    String? urlsYaml;
    String? keyYaml;
    String? metadataYaml;
    String? googleServices;
    String? googleServiceInfo;
    String? caCert;

    for (final file in archive) {
      if (!file.isFile) continue;
      final rawContent = file.content;
      final content = rawContent is List<int>
          ? utf8.decode(rawContent, allowMalformed: true)
          : rawContent.toString();

      switch (file.name) {
        case 'urls.yml':
          urlsYaml = content;
          break;
        case 'key.yml':
          keyYaml = content;
          break;
        case 'metadata.yml':
          metadataYaml = content;
          break;
        case 'google-services.json':
          googleServices = content;
          break;
        case 'GoogleService-Info.plist':
          googleServiceInfo = content;
          break;
        case 'ca_cert.pem':
          caCert = content;
          break;
      }
    }

    if (urlsYaml == null) {
      throw const HubSightConfigException(
        code: HubSightErrorCode.configMissingRequiredFiles,
        developerMessage: 'Missing urls.yml in decrypted container.',
      );
    }
    if (keyYaml == null) {
      throw const HubSightConfigException(
        code: HubSightErrorCode.configMissingRequiredFiles,
        developerMessage: 'Missing key.yml in decrypted container.',
      );
    }

    // 6. Parse YAML documents
    Map<String, dynamic> urlsMap;
    Map<String, dynamic> keyMap;
    Map<String, dynamic> metadataMap = {};

    try {
      urlsMap = _yamlToMap(loadYaml(urlsYaml));
      keyMap = _yamlToMap(loadYaml(keyYaml));
      if (metadataYaml != null) {
        metadataMap = _yamlToMap(loadYaml(metadataYaml));
      }
    } catch (e) {
      throw HubSightConfigException(
        code: HubSightErrorCode.configMalformedYaml,
        developerMessage: 'Failed to parse configuration YAML: $e',
      );
    }

    final metadata = HubSightConfigMetadata.fromMap(metadataMap);

    // 7. Optional Ed25519 signature verification
    if (verifySignature &&
        metadata.ed25519PublicKey != null &&
        metadata.signature != null &&
        metadata.ed25519PublicKey!.isNotEmpty &&
        metadata.signature!.isNotEmpty) {
      try {
        final pubKeyBytes = _hexDecode(metadata.ed25519PublicKey!);
        final sigBytes = _hexDecode(metadata.signature!);

        final algorithm = Ed25519();
        final isValid = await algorithm.verify(
          decryptedZipBytes,
          signature: Signature(
            sigBytes,
            publicKey: SimplePublicKey(pubKeyBytes, type: KeyPairType.ed25519),
          ),
        );

        if (!isValid) {
          throw const HubSightConfigException(
            code: HubSightErrorCode.configInvalidSignature,
            developerMessage:
                'Ed25519 digital signature mismatch: payload may have been tampered.',
          );
        }
      } catch (e) {
        if (e is HubSightConfigException) rethrow;
        throw HubSightConfigException(
          code: HubSightErrorCode.configInvalidSignature,
          developerMessage: 'Ed25519 digital signature verification error: $e',
        );
      }
    }

    return HubSightAppConfig(
      urls: HubSightUrls.fromMap(urlsMap),
      key: HubSightClientKey.fromMap(keyMap),
      metadata: metadata,
      googleServicesJson: googleServices,
      googleServiceInfoPlist: googleServiceInfo,
      caCertPem: caCert,
    );
  }

  static Map<String, dynamic> _yamlToMap(dynamic yamlNode) {
    if (yamlNode is YamlMap) {
      final map = <String, dynamic>{};
      for (final entry in yamlNode.entries) {
        map[entry.key.toString()] = _convertYamlValue(entry.value);
      }
      return map;
    } else if (yamlNode is Map) {
      return Map<String, dynamic>.from(yamlNode);
    }
    return {};
  }

  static dynamic _convertYamlValue(dynamic val) {
    if (val is YamlMap) {
      return _yamlToMap(val);
    } else if (val is YamlList) {
      return val.map((e) => _convertYamlValue(e)).toList();
    }
    return val;
  }

  static Uint8List _hexDecode(String hex) {
    final clean = hex.replaceAll(RegExp(r'\s+'), '');
    if (clean.length % 2 != 0) {
      throw FormatException('Invalid hex string length: ${clean.length}');
    }
    final bytes = Uint8List(clean.length ~/ 2);
    for (int i = 0; i < clean.length; i += 2) {
      bytes[i ~/ 2] = int.parse(clean.substring(i, i + 2), radix: 16);
    }
    return bytes;
  }
}
