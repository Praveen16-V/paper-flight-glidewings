import 'dart:convert';
import 'dart:typed_data';

import '../models/save_data.dart';
import '../providers/save_data_provider.dart';

/// Editable state for the Custom Craft paper skin.
class CustomSkinDraft {
  const CustomSkinDraft({
    required this.primaryHex,
    required this.accentHex,
    required this.stampIndex,
    required this.patternBase64,
    required this.patternName,
  });

  final int primaryHex;
  final int accentHex;
  final int stampIndex;

  /// Normalized image bytes encoded without a `data:image/...` URI prefix.
  final String patternBase64;
  final String patternName;

  bool get hasImportedPattern => patternBase64.isNotEmpty;

  factory CustomSkinDraft.fromSave(SaveData save) => CustomSkinDraft(
        primaryHex: save.customSkinPrimaryHex,
        accentHex: save.customSkinAccentHex,
        stampIndex: save.customSkinStamp,
        patternBase64: save.customSkinPatternBase64,
        patternName: save.customSkinPatternName,
      );
}

/// Community gallery record. A production app can attach user identity and
/// moderation metadata in its cloud implementation without changing the UI.
class CommunitySkinEntry {
  const CommunitySkinEntry({
    required this.id,
    required this.title,
    required this.authorAlias,
    required this.primaryHex,
    required this.accentHex,
    required this.stampIndex,
    required this.patternBase64,
    required this.votes,
  });

  final String id;
  final String title;
  final String authorAlias;
  final int primaryHex;
  final int accentHex;
  final int stampIndex;
  final String patternBase64;
  final int votes;

  CommunitySkinEntry copyWith({int? votes}) => CommunitySkinEntry(
        id: id,
        title: title,
        authorAlias: authorAlias,
        primaryHex: primaryHex,
        accentHex: accentHex,
        stampIndex: stampIndex,
        patternBase64: patternBase64,
        votes: votes ?? this.votes,
      );
}

/// Pluggable cloud contract. Replace [LocalCustomSkinCloudRepository] with a
/// Firebase/REST implementation to synchronize drafts and community voting.
abstract class CustomSkinCloudRepository {
  Future<void> syncDraft(CustomSkinDraft draft);
  Future<List<CommunitySkinEntry>> fetchGallery();
  Future<void> publish(CommunitySkinEntry entry);
  Future<void> vote(String entryId);
}

/// Offline-friendly default used until a real cloud provider is wired in.
/// It mirrors the cloud contract and keeps the Workshop fully testable/local.
class LocalCustomSkinCloudRepository implements CustomSkinCloudRepository {
  final List<CommunitySkinEntry> _gallery = [
    const CommunitySkinEntry(
      id: 'aurora-fold',
      title: 'Aurora Fold',
      authorAlias: 'SkyFold',
      primaryHex: 0xFF80DEEA,
      accentHex: 0xFFCE93D8,
      stampIndex: 0,
      patternBase64: '',
      votes: 128,
    ),
    const CommunitySkinEntry(
      id: 'sunset-grid',
      title: 'Sunset Grid',
      authorAlias: 'PaperPilot',
      primaryHex: 0xFFFFAB91,
      accentHex: 0xFFFFD740,
      stampIndex: 1,
      patternBase64: '',
      votes: 84,
    ),
    const CommunitySkinEntry(
      id: 'midnight-bloom',
      title: 'Midnight Bloom',
      authorAlias: 'OrigamiFox',
      primaryHex: 0xFF3949AB,
      accentHex: 0xFFF48FB1,
      stampIndex: 2,
      patternBase64: '',
      votes: 61,
    ),
  ];

  CustomSkinDraft? latestDraft;

  @override
  Future<void> syncDraft(CustomSkinDraft draft) async {
    latestDraft = draft;
  }

  @override
  Future<List<CommunitySkinEntry>> fetchGallery() async {
    final sorted = List<CommunitySkinEntry>.from(_gallery)
      ..sort((a, b) => b.votes.compareTo(a.votes));
    return sorted;
  }

  @override
  Future<void> publish(CommunitySkinEntry entry) async {
    _gallery.removeWhere((existing) => existing.id == entry.id);
    _gallery.add(entry);
  }

  @override
  Future<void> vote(String entryId) async {
    final index = _gallery.indexWhere((entry) => entry.id == entryId);
    if (index < 0) return;
    _gallery[index] = _gallery[index].copyWith(
      votes: _gallery[index].votes + 1,
    );
  }
}

/// Validates pattern imports, persists the draft, and delegates optional cloud
/// synchronization. Image bytes stay in the player's save as base64 so patterns
/// survive offline and can later be uploaded by a cloud repository.
class CustomSkinManager {
  CustomSkinManager({CustomSkinCloudRepository? cloudRepository})
      : _cloudRepository =
            cloudRepository ?? LocalCustomSkinCloudRepository();

  static final CustomSkinManager instance = CustomSkinManager();

  static const int maxPatternBytes = 256 * 1024;
  final CustomSkinCloudRepository _cloudRepository;

  CustomSkinDraft draftFromSave(SaveData save) => CustomSkinDraft.fromSave(save);

  /// Imports a base64 string or `data:image/...;base64,...` URI. The normalized
  /// base64 string is returned so UI previews and the in-flight overlay use the
  /// exact same bytes.
  String normalizePatternImport(String source) {
    var normalized = source.trim();
    if (normalized.startsWith('data:')) {
      final comma = normalized.indexOf(',');
      if (comma < 0 || !normalized.substring(0, comma).contains(';base64')) {
        throw const FormatException('Use a base64 PNG, JPEG, or WebP image.');
      }
      normalized = normalized.substring(comma + 1);
    }
    normalized = normalized.replaceAll(RegExp(r'\s+'), '');
    if (normalized.isEmpty) return '';

    final bytes = base64Decode(normalized);
    if (bytes.lengthInBytes > maxPatternBytes) {
      throw const FormatException('Pattern image must be 256 KB or smaller.');
    }
    if (!_isSupportedImage(bytes)) {
      throw const FormatException('Pattern must be a PNG, JPEG, or WebP image.');
    }
    return base64Encode(bytes);
  }

  Future<CustomSkinDraft> importPattern({
    required SaveDataNotifier notifier,
    required SaveData currentSave,
    required String source,
    required String patternName,
  }) async {
    final normalized = normalizePatternImport(source);
    final name = normalized.isEmpty ? '' : patternName.trim();
    await notifier.updateCustomSkin(
      patternBase64: normalized,
      patternName: name,
    );
    final draft = CustomSkinDraft(
      primaryHex: currentSave.customSkinPrimaryHex,
      accentHex: currentSave.customSkinAccentHex,
      stampIndex: currentSave.customSkinStamp,
      patternBase64: normalized,
      patternName: name,
    );
    await _cloudRepository.syncDraft(draft);
    return draft;
  }

  Future<void> syncCurrentDraft(SaveData save) =>
      _cloudRepository.syncDraft(draftFromSave(save));

  Future<List<CommunitySkinEntry>> loadGallery() =>
      _cloudRepository.fetchGallery();

  Future<void> vote(String entryId) => _cloudRepository.vote(entryId);

  Future<void> publishCurrent(SaveData save) async {
    final draft = draftFromSave(save);
    final entry = CommunitySkinEntry(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      title: draft.patternName.isEmpty ? 'Untitled Craft' : draft.patternName,
      authorAlias: 'You',
      primaryHex: draft.primaryHex,
      accentHex: draft.accentHex,
      stampIndex: draft.stampIndex,
      patternBase64: draft.patternBase64,
      votes: 0,
    );
    await _cloudRepository.publish(entry);
    await _cloudRepository.syncDraft(draft);
  }

  bool _isSupportedImage(Uint8List bytes) {
    final isPng = bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47;
    final isJpeg = bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF;
    final isWebp = bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50;
    return isPng || isJpeg || isWebp;
  }
}
