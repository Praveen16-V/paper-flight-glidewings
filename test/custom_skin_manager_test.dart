import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:paper_flight/models/save_data.dart';
import 'package:paper_flight/services/custom_skin_manager.dart';

void main() {
  const pngHeader = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

  group('CustomSkinManager', () {
    test('normalizes a data URI into persistent base64 image bytes', () {
      final manager = CustomSkinManager();
      final raw = 'data:image/png;base64,${base64Encode(pngHeader)}';
      final normalized = manager.normalizePatternImport(raw);

      expect(normalized, base64Encode(pngHeader));
    });

    test('rejects non-image base64 input', () {
      final manager = CustomSkinManager();
      expect(
        () => manager.normalizePatternImport(base64Encode([1, 2, 3, 4])),
        throwsA(isA<FormatException>()),
      );
    });

    test('gallery voting follows the pluggable cloud contract', () async {
      final cloud = LocalCustomSkinCloudRepository();
      final manager = CustomSkinManager(cloudRepository: cloud);
      final before = await manager.loadGallery();
      final target = before.first;

      await manager.vote(target.id);
      final after = await manager.loadGallery();
      final updated = after.firstWhere((entry) => entry.id == target.id);
      expect(updated.votes, target.votes + 1);
    });

    test('draft exposes palette and imported pattern from save data', () {
      final save = SaveData(
        customSkinPrimaryHex: 0xFF123456,
        customSkinAccentHex: 0xFFABCDEF,
        customSkinStamp: 2,
        customSkinPatternBase64: base64Encode(pngHeader),
        customSkinPatternName: 'Test Fold',
      );
      final draft = CustomSkinManager().draftFromSave(save);

      expect(draft.hasImportedPattern, isTrue);
      expect(draft.patternName, 'Test Fold');
      expect(draft.stampIndex, 2);
    });
  });
}
