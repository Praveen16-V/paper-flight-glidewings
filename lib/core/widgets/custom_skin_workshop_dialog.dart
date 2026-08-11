import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../widgets/paper_button.dart';
import '../../providers/save_data_provider.dart';
import '../../services/custom_skin_manager.dart';

/// Opens the Custom Craft Workshop from the Hangar.
Future<void> showCustomSkinWorkshopDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (_) => const _CustomSkinWorkshopDialog(),
  );
}

class _CustomSkinWorkshopDialog extends ConsumerStatefulWidget {
  const _CustomSkinWorkshopDialog();

  @override
  ConsumerState<_CustomSkinWorkshopDialog> createState() =>
      _CustomSkinWorkshopDialogState();
}

class _CustomSkinWorkshopDialogState
    extends ConsumerState<_CustomSkinWorkshopDialog> {
  final _patternController = TextEditingController();
  final _nameController = TextEditingController();
  Future<List<CommunitySkinEntry>>? _galleryFuture;
  Uint8List? _previewBytes;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final save = ref.read(saveDataProvider);
    _patternController.text = save.customSkinPatternBase64;
    _nameController.text = save.customSkinPatternName;
    _previewBytes = _decodePreview(save.customSkinPatternBase64);
    _galleryFuture = CustomSkinManager.instance.loadGallery();
  }

  @override
  void dispose() {
    _patternController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Uint8List? _decodePreview(String source) {
    try {
      if (source.isEmpty) return null;
      return base64Decode(source);
    } catch (_) {
      return null;
    }
  }

  Future<void> _importPattern() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final manager = CustomSkinManager.instance;
      final normalized = manager.normalizePatternImport(_patternController.text);
      final save = ref.read(saveDataProvider);
      await manager.importPattern(
        notifier: ref.read(saveDataProvider.notifier),
        currentSave: save,
        source: normalized,
        patternName: _nameController.text,
      );
      if (!mounted) return;
      setState(() {
        _patternController.text = normalized;
        _previewBytes = _decodePreview(normalized);
      });
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not import that pattern image.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearPattern() async {
    await ref.read(saveDataProvider.notifier).updateCustomSkin(
          patternBase64: '',
          patternName: '',
        );
    await CustomSkinManager.instance
        .syncCurrentDraft(ref.read(saveDataProvider));
    if (!mounted) return;
    setState(() {
      _patternController.clear();
      _nameController.clear();
      _previewBytes = null;
      _error = null;
    });
  }

  Future<void> _updatePalette({int? primaryHex, int? accentHex}) async {
    await ref.read(saveDataProvider.notifier).updateCustomSkin(
          primaryHex: primaryHex,
          accentHex: accentHex,
        );
    await CustomSkinManager.instance
        .syncCurrentDraft(ref.read(saveDataProvider));
  }

  Future<void> _publish() async {
    setState(() => _busy = true);
    try {
      await ref.read(saveDataProvider.notifier).updateCustomSkin(
            patternName: _nameController.text.trim(),
          );
      final save = ref.read(saveDataProvider);
      await CustomSkinManager.instance.publishCurrent(save);
      if (!mounted) return;
      setState(() {
        _galleryFuture = CustomSkinManager.instance.loadGallery();
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Custom Craft published to the gallery!'),
        backgroundColor: AppColors.success,
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _vote(String id) async {
    await CustomSkinManager.instance.vote(id);
    if (mounted) {
      setState(() => _galleryFuture = CustomSkinManager.instance.loadGallery());
    }
  }

  @override
  Widget build(BuildContext context) {
    final save = ref.watch(saveDataProvider);
    final draft = CustomSkinManager.instance.draftFromSave(save);
    final previewColor = Color(draft.primaryHex);
    final accentColor = Color(draft.accentHex);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
        child: Material(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(22),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: previewColor.withOpacity(.18),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(Icons.brush_rounded, color: previewColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CUSTOM CRAFT WORKSHOP',
                              style: AppTypography.bodyLarge.copyWith(
                                  color: AppColors.paperInk, fontSize: 16)),
                          Text('Import, publish, and vote on paper patterns',
                              style: AppTypography.caption.copyWith(
                                  color: AppColors.paperInkSoft)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close workshop',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('YOUR PATTERN', style: AppTypography.overline),
                      const SizedBox(height: 8),
                      _PatternPreview(
                        bytes: _previewBytes,
                        primary: previewColor,
                        accent: accentColor,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nameController,
                        maxLength: 28,
                        decoration: const InputDecoration(
                          labelText: 'Pattern name',
                          hintText: 'e.g. Chennai Monsoon Fold',
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _patternController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Import pattern image',
                          hintText: 'Paste a base64 PNG/JPEG/WebP or data:image URI',
                          alignLabelWithHint: true,
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 6),
                        Text(_error!,
                            style: AppTypography.caption.copyWith(
                                color: AppColors.danger)),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          PaperButton(
                            label: _busy ? 'IMPORTING…' : 'IMPORT PATTERN',
                            compact: true,
                            color: AppColors.accent,
                            textColor: Colors.white,
                            onPressed: _busy ? null : _importPattern,
                          ),
                          PaperButton(
                            label: 'CLEAR',
                            compact: true,
                            color: AppColors.paperInkSoft,
                            textColor: Colors.white,
                            onPressed: _busy ? null : _clearPattern,
                          ),
                          PaperButton(
                            label: 'PUBLISH',
                            compact: true,
                            color: AppColors.success,
                            textColor: Colors.white,
                            onPressed: _busy ? null : _publish,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text('PALETTE', style: AppTypography.overline),
                      const SizedBox(height: 8),
                      _PaletteRow(
                        label: 'BASE',
                        selected: previewColor,
                        onSelect: (color) {
                          _updatePalette(primaryHex: color.value);
                        },
                      ),
                      const SizedBox(height: 8),
                      _PaletteRow(
                        label: 'ACCENT',
                        selected: accentColor,
                        onSelect: (color) {
                          _updatePalette(accentHex: color.value);
                        },
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Text('COMMUNITY GALLERY',
                              style: AppTypography.overline),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Refresh gallery',
                            icon: const Icon(Icons.refresh_rounded, size: 19),
                            onPressed: () => setState(() {
                              _galleryFuture =
                                  CustomSkinManager.instance.loadGallery();
                            }),
                          ),
                        ],
                      ),
                      FutureBuilder<List<CommunitySkinEntry>>(
                        future: _galleryFuture,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          return Column(
                            children: [
                              for (final entry in snapshot.data!)
                                _CommunitySkinTile(
                                  entry: entry,
                                  onVote: () => _vote(entry.id),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PatternPreview extends StatelessWidget {
  const _PatternPreview({
    required this.bytes,
    required this.primary,
    required this.accent,
  });

  final Uint8List? bytes;
  final Color primary;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 104,
      decoration: BoxDecoration(
        color: primary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(.7), width: 1.4),
      ),
      clipBehavior: Clip.antiAlias,
      child: bytes == null
          ? CustomPaint(painter: _FallbackPatternPainter(accent: accent))
          : Image.memory(
              bytes!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  CustomPaint(painter: _FallbackPatternPainter(accent: accent)),
            ),
    );
  }
}

class _FallbackPatternPainter extends CustomPainter {
  const _FallbackPatternPainter({required this.accent});
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accent.withOpacity(.64)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var x = -size.height; x < size.width + size.height; x += 15) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), paint);
    }
    canvas.drawCircle(
      Offset(size.width * .62, size.height * .45),
      14,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _FallbackPatternPainter old) =>
      old.accent != accent;
}

class _PaletteRow extends StatelessWidget {
  const _PaletteRow({
    required this.label,
    required this.selected,
    required this.onSelect,
  });

  final String label;
  final Color selected;
  final ValueChanged<Color> onSelect;

  @override
  Widget build(BuildContext context) {
    const colors = [
      Color(0xFF4FC3F7),
      Color(0xFFFF80AB),
      Color(0xFF00E676),
      Color(0xFFFFD54F),
      Color(0xFFCE93D8),
      Color(0xFF7C4DFF),
    ];
    return Row(
      children: [
        SizedBox(
          width: 54,
          child: Text(label,
              style: AppTypography.overline.copyWith(fontSize: 9)),
        ),
        for (final color in colors)
          Padding(
            padding: const EdgeInsets.only(right: 7),
            child: GestureDetector(
              onTap: () => onSelect(color),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.value == selected.value
                        ? Colors.black
                        : Colors.white,
                    width: color.value == selected.value ? 2.2 : 1.0,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CommunitySkinTile extends StatelessWidget {
  const _CommunitySkinTile({required this.entry, required this.onVote});

  final CommunitySkinEntry entry;
  final VoidCallback onVote;

  @override
  Widget build(BuildContext context) {
    final base = Color(entry.primaryHex);
    final accent = Color(entry.accentHex);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.paperWarm,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(.45)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 32,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: accent),
            ),
            child: CustomPaint(painter: _FallbackPatternPainter(accent: accent)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title,
                    style: AppTypography.bodyLarge.copyWith(fontSize: 13)),
                Text('by ${entry.authorAlias}',
                    style: AppTypography.caption.copyWith(
                        color: AppColors.paperInkSoft, fontSize: 10)),
              ],
            ),
          ),
          Text('${entry.votes}', style: AppTypography.caption),
          IconButton(
            tooltip: 'Vote for ${entry.title}',
            onPressed: onVote,
            icon: const Icon(Icons.favorite_border_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}
