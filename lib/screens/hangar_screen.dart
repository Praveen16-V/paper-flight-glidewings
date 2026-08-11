import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_typography.dart';
import '../core/constants/game_config.dart';
import '../core/enums/game_enums.dart';
import '../core/widgets/currency_chip.dart';
import '../core/widgets/custom_skin_workshop_dialog.dart';
import '../core/widgets/paper_button.dart';
import '../core/widgets/paper_card.dart';
import '../core/widgets/paper_icons.dart';
import '../providers/save_data_provider.dart';
import '../services/analytics_service.dart';

/// Hangar — browse, unlock and equip planes + paper skins.
///
/// Clean redesign: a calm showcase stage with the floating plane/skin,
/// one compact paper info panel (tier + stat bars + upgrade), and simple
/// single-row cards in the collection list. Every text row is flexible
/// (ellipsis) so nothing can overflow on narrow screens.
class HangarScreen extends ConsumerWidget {
  const HangarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final save = ref.watch(saveDataProvider);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.textLight,
          elevation: 0,
          title: Text('Hangar',
              style: AppTypography.title.copyWith(letterSpacing: 1)),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                children: [
                  CoinChip(save.coins, iconSize: 16, fontSize: 14),
                  const SizedBox(width: 10),
                  GemChip(save.gems, iconSize: 14, fontSize: 13),
                  const SizedBox(width: 6),
                ],
              ),
            ),
          ],
          bottom: TabBar(
            indicatorColor: AppColors.accent,
            labelColor: AppColors.accent,
            unselectedLabelColor: AppColors.textMuted,
            labelStyle: AppTypography.label
                .copyWith(fontSize: 13, letterSpacing: 1.2),
            tabs: const [
              Tab(text: 'PLANES'),
              Tab(text: 'SKINS'),
              Tab(text: 'POWER-UPS'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _PlanesTab(),
            _SkinsTab(),
            _PowerUpsTab(),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Planes Tab
// ════════════════════════════════════════════════════════════════════════════

class _PlanesTab extends ConsumerStatefulWidget {
  const _PlanesTab();

  @override
  ConsumerState<_PlanesTab> createState() => _PlanesTabState();
}

class _PlanesTabState extends ConsumerState<_PlanesTab> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final save = ref.watch(saveDataProvider);
    final notifier = ref.read(saveDataProvider.notifier);
    final equipped = save.equippedPlaneIndex;
    final selected = _selected ?? equipped;
    final plane =
        PlaneType.values[selected.clamp(0, PlaneType.values.length - 1)];
    final unlocked = notifier.isPlaneUnlocked(selected);
    final isEquipped = equipped == selected;

    return Column(
      children: [
        Expanded(
          flex: 4,
          child: _PlaneShowcaseStage(
            plane: plane,
            unlocked: unlocked,
            equipped: isEquipped,
            selectedIndex: selected,
          ),
        ),
        Expanded(
          flex: 6,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.backgroundDeep,
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              itemCount: PlaneType.values.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final p = PlaneType.values[index];
                final unl = notifier.isPlaneUnlocked(index);
                final equip = save.equippedPlaneIndex == index;
                final isSel = selected == index;
                final canAfford =
                    save.coins >= p.unlockCost && save.gems >= p.unlockGemCost;

                return _PlaneCard(
                  plane: p,
                  unlocked: unl,
                  equipped: equip,
                  selected: isSel,
                  level: save.getPlaneLevel(index),
                  canAfford: canAfford,
                  onSelect: () => setState(() => _selected = index),
                  onUnlock: () async {
                    final success = await notifier.unlockPlane(
                      index,
                      p.unlockCost,
                      gemCost: p.unlockGemCost,
                    );
                    if (success && context.mounted) {
                      AnalyticsService.instance.logPlaneUnlocked(p.assetName);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${p.displayName} unlocked!'),
                          backgroundColor: AppColors.success,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    } else if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Not enough coins or gems!'),
                          backgroundColor: AppColors.danger,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  onEquip: () {
                    notifier.equipPlane(index);
                    setState(() => _selected = index);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ── Plane showcase stage ────────────────────────────────────────────────────

class _PlaneShowcaseStage extends ConsumerStatefulWidget {
  const _PlaneShowcaseStage({
    required this.plane,
    required this.unlocked,
    required this.equipped,
    required this.selectedIndex,
  });
  final PlaneType plane;
  final bool unlocked;
  final bool equipped;
  final int selectedIndex;

  @override
  ConsumerState<_PlaneShowcaseStage> createState() =>
      _PlaneShowcaseStageState();
}

class _PlaneShowcaseStageState extends ConsumerState<_PlaneShowcaseStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatCtrl;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final save = ref.watch(saveDataProvider);
    final notifier = ref.read(saveDataProvider.notifier);
    final level = save.getPlaneLevel(widget.selectedIndex);
    final stats = _statsForPlane(widget.plane, level);
    final isMax = level >= 3;
    final nextCost = widget.plane.upgradeCost(level + 1);
    final canAffordUpgrade = save.coins >= nextCost;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1A2748),
            Color(0xFF131C38),
            Color(0xFF0F1A33),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(
          children: [
            // Header: status pill + plane name (flexible, never overflows).
            SizedBox(
              height: 24,
              child: Row(
                children: [
                  _StatusPill(
                    equipped: widget.equipped,
                    unlocked: widget.unlocked,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.plane.displayName.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: AppTypography.overline.copyWith(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 10,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Row(
                children: [
                  // Left: floating plane + pedestal.
                  Expanded(
                    flex: 5,
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 380),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 0.92, end: 1.0)
                                .animate(anim),
                            child: child,
                          ),
                        ),
                        child: AnimatedBuilder(
                          key: ValueKey(widget.selectedIndex),
                          animation: _floatCtrl,
                          builder: (context, child) {
                            final t = _floatCtrl.value;
                            final dy = math.sin(t * math.pi) * 6;
                            final shadowScale = 1.0 - (t * 0.12);
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Transform.translate(
                                  offset: Offset(0, dy - 2),
                                  child: Opacity(
                                    opacity: widget.unlocked ? 1 : 0.38,
                                    child: CustomPaint(
                                      size: const Size(126, 80),
                                      painter: _PlaneShowcasePainter(
                                          plane: widget.plane),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Transform.scale(
                                  scale: shadowScale,
                                  child: CustomPaint(
                                    size: const Size(72, 15),
                                    painter: _OrigamiShadowPainter(
                                        unlocked: widget.unlocked),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                CustomPaint(
                                  size: const Size(96, 17),
                                  painter: _PedestalPainter(),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Right: one clean info panel — tier, stats, upgrade.
                  Expanded(
                    flex: 5,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                      decoration: BoxDecoration(
                        color: AppColors.paper.withOpacity(0.96),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.28),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                        border: Border.all(
                            color: Colors.white.withOpacity(0.5), width: 1),
                      ),
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    'TIER $level/3',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.overline.copyWith(
                                      color: AppColors.paperInkSoft,
                                      fontSize: 9,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: List.generate(
                                    3,
                                    (i) => Icon(
                                      i < level
                                          ? Icons.star_rounded
                                          : Icons.star_outline_rounded,
                                      size: 12,
                                      color: i < level
                                          ? AppColors.coinGold
                                          : AppColors.paperInkSoft
                                              .withOpacity(0.35),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _AnimatedStatBar(
                              label: 'SPD',
                              value: stats[0],
                              color: const Color(0xFFFF6B6B),
                            ),
                            const SizedBox(height: 5),
                            _AnimatedStatBar(
                              label: 'GLD',
                              value: stats[1],
                              color: const Color(0xFF4FC3F7),
                            ),
                            const SizedBox(height: 5),
                            _AnimatedStatBar(
                              label: 'SHD',
                              value: stats[2],
                              color: const Color(0xFF56CF87),
                            ),
                            if (widget.unlocked) ...[
                              const SizedBox(height: 8),
                              if (!isMax)
                                PaperButton(
                                  label: 'UPGRADE • $nextCost',
                                  compact: true,
                                  expand: true,
                                  color: canAffordUpgrade
                                      ? AppColors.accent
                                      : AppColors.paperInk.withOpacity(0.4),
                                  textColor: Colors.white,
                                  onPressed: canAffordUpgrade
                                      ? () async {
                                          final success =
                                              await notifier.upgradePlane(
                                                  widget.selectedIndex,
                                                  nextCost);
                                          if (success && context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                    '${widget.plane.displayName} upgraded to Tier ${level + 1}!'),
                                                backgroundColor:
                                                    AppColors.success,
                                                duration:
                                                    const Duration(seconds: 2),
                                              ),
                                            );
                                          }
                                        }
                                      : null,
                                )
                              else
                                Center(
                                  child: Text(
                                    '★ MAX TIER ★',
                                    style: AppTypography.overline.copyWith(
                                      fontSize: 9,
                                      color: AppColors.accentDeep,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Plane card (simple single row) ──────────────────────────────────────────

class _PlaneCard extends StatelessWidget {
  const _PlaneCard({
    required this.plane,
    required this.unlocked,
    required this.equipped,
    required this.selected,
    required this.canAfford,
    required this.onSelect,
    required this.onUnlock,
    required this.onEquip,
    this.level = 1,
  });

  final PlaneType plane;
  final bool unlocked;
  final bool equipped;
  final bool selected;
  final bool canAfford;
  final int level;
  final VoidCallback onSelect;
  final VoidCallback onUnlock;
  final VoidCallback onEquip;

  @override
  Widget build(BuildContext context) {
    final borderColor = equipped
        ? AppColors.success
        : (selected ? AppColors.accent.withOpacity(0.7) : null);
    final bg = equipped ? const Color(0xFFE9F7EE) : AppColors.paper;

    return PaperCard(
      onTap: onSelect,
      color: bg,
      elevation: equipped ? 1.6 : (selected ? 1.3 : 1.0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderColor: borderColor,
      borderWidth: equipped ? 2.2 : 1.2,
      child: Row(
        children: [
          _PlanePreview(plane: plane, unlocked: unlocked, size: 46),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        plane.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppColors.paperInk,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (unlocked) ...[
                      const SizedBox(width: 6),
                      Text(
                        'Lv.$level',
                        style: AppTypography.overline.copyWith(
                          color: AppColors.paperInkSoft,
                          fontSize: 9,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  plane.tagline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.paperInkSoft,
                    fontSize: 10.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _ActionChip(
            unlocked: unlocked,
            equipped: equipped,
            costCoins: plane.unlockCost,
            costGems: plane.unlockGemCost,
            canAfford: canAfford,
            onUnlock: onUnlock,
            onEquip: onEquip,
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Skins Tab
// ════════════════════════════════════════════════════════════════════════════

class _SkinsTab extends ConsumerStatefulWidget {
  const _SkinsTab();

  @override
  ConsumerState<_SkinsTab> createState() => _SkinsTabState();
}

class _SkinsTabState extends ConsumerState<_SkinsTab> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final save = ref.watch(saveDataProvider);
    final notifier = ref.read(saveDataProvider.notifier);
    final equipped = save.equippedSkinIndex;
    final selected = _selected ?? equipped;
    final skin =
        PaperSkin.values[selected.clamp(0, PaperSkin.values.length - 1)];
    final unlocked = notifier.isSkinUnlocked(selected);
    final isEquipped = equipped == selected;

    return Column(
      children: [
        Expanded(
          flex: 4,
          child: _SkinShowcaseStage(
            skin: skin,
            unlocked: unlocked,
            equipped: isEquipped,
            selectedIndex: selected,
          ),
        ),
        Expanded(
          flex: 6,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.backgroundDeep,
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              itemCount: PaperSkin.values.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final s = PaperSkin.values[index];
                final unl = notifier.isSkinUnlocked(index);
                final equip = save.equippedSkinIndex == index;
                final isSel = selected == index;
                final seasonOpen = s.isAvailableForPurchaseAt(DateTime.now());
                final canAfford = save.coins >= s.unlockCostCoins &&
                    save.gems >= s.unlockCostGems &&
                    seasonOpen;
                return _SkinCard(
                  skin: s,
                  swatchColor: s == PaperSkin.customCraft
                      ? Color(save.customSkinPrimaryHex)
                      : Color(s.baseColorHex),
                  unlocked: unl,
                  equipped: equip,
                  selected: isSel,
                  canAfford: canAfford,
                  onSelect: () => setState(() => _selected = index),
                  onUnlock: () async {
                    final success = await notifier.unlockSkin(
                        index, s.unlockCostCoins, s.unlockCostGems);
                    if (success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${s.displayName} unlocked!'),
                          backgroundColor: AppColors.success,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    } else if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Not enough coins or gems!'),
                          backgroundColor: AppColors.danger,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  onEquip: () {
                    notifier.equipSkin(index);
                    setState(() => _selected = index);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _SkinShowcaseStage extends ConsumerStatefulWidget {
  const _SkinShowcaseStage({
    required this.skin,
    required this.unlocked,
    required this.equipped,
    required this.selectedIndex,
  });
  final PaperSkin skin;
  final bool unlocked;
  final bool equipped;
  final int selectedIndex;

  @override
  ConsumerState<_SkinShowcaseStage> createState() => _SkinShowcaseStageState();
}

class _SkinShowcaseStageState extends ConsumerState<_SkinShowcaseStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatCtrl;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final save = ref.watch(saveDataProvider);
    final rarity = widget.skin.rarity;
    final swatchColor = widget.skin == PaperSkin.customCraft
        ? Color(save.customSkinPrimaryHex)
        : Color(widget.skin.baseColorHex);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A2748), Color(0xFF131C38), Color(0xFF0F1A33)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(
          children: [
            SizedBox(
              height: 24,
              child: Row(
                children: [
                  _StatusPill(
                    equipped: widget.equipped,
                    unlocked: widget.unlocked,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.skin.displayName.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: AppTypography.overline.copyWith(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 10,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Row(
                children: [
                  // Left: floating skin sheet + pedestal.
                  Expanded(
                    flex: 5,
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 380),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 0.92, end: 1.0)
                                .animate(anim),
                            child: child,
                          ),
                        ),
                        child: AnimatedBuilder(
                          key: ValueKey(widget.selectedIndex),
                          animation: _floatCtrl,
                          builder: (context, child) {
                            final t = _floatCtrl.value;
                            final dy = math.sin(t * math.pi) * 6;
                            final shadowScale = 1.0 - (t * 0.12);
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Transform.translate(
                                  offset: Offset(0, dy),
                                  child: Opacity(
                                    opacity: widget.unlocked ? 1 : 0.40,
                                    child: Container(
                                      width: 128,
                                      height: 82,
                                      decoration: BoxDecoration(
                                        color: swatchColor,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: rarity.color.withOpacity(
                                            rarity == SkinRarity.common
                                                ? .45
                                                : .86,
                                          ),
                                          width: rarity == SkinRarity.mythic
                                              ? 2.2
                                              : 1.4,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.28),
                                            blurRadius: 12,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(13),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            CustomPaint(
                                              painter: _SkinPatternPainter(
                                                  skin: widget.skin),
                                            ),
                                            Center(
                                              child: CustomPaint(
                                                size: const Size(56, 38),
                                                painter: _PlaneShowcasePainter(
                                                  plane: PlaneType.dart,
                                                  tint: Colors.white
                                                      .withOpacity(0.94),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Transform.scale(
                                  scale: shadowScale,
                                  child: CustomPaint(
                                    size: const Size(74, 16),
                                    painter: _OrigamiShadowPainter(
                                        unlocked: widget.unlocked),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                CustomPaint(
                                  size: const Size(100, 18),
                                  painter: _PedestalPainter(),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Right: one clean info panel.
                  Expanded(
                    flex: 5,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                      decoration: BoxDecoration(
                        color: AppColors.paper.withOpacity(0.96),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.28),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                        border: Border.all(
                            color: Colors.white.withOpacity(0.5), width: 1),
                      ),
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    widget.skin.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.bodyLarge.copyWith(
                                      color: AppColors.paperInk,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                _SkinRarityBadge(rarity: rarity),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.skin.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.paperInkSoft,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                if (widget.skin.unlockCostCoins > 0)
                                  CoinChip(widget.skin.unlockCostCoins,
                                      iconSize: 13, fontSize: 12, spacing: 4),
                                if (widget.skin.unlockCostGems > 0) ...[
                                  if (widget.skin.unlockCostCoins > 0)
                                    const SizedBox(width: 8),
                                  GemChip(widget.skin.unlockCostGems,
                                      iconSize: 12, fontSize: 12, spacing: 4),
                                ],
                                if (widget.skin.unlockCostCoins == 0 &&
                                    widget.skin.unlockCostGems == 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.success,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'FREE',
                                      style: AppTypography.overline.copyWith(
                                        color: Colors.white,
                                        fontSize: 10,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (widget.skin == PaperSkin.customCraft &&
                                widget.unlocked) ...[
                              const SizedBox(height: 10),
                              PaperButton(
                                label: 'OPEN WORKSHOP',
                                compact: true,
                                expand: true,
                                color: AppColors.accent,
                                textColor: Colors.white,
                                onPressed: () {
                                  showCustomSkinWorkshopDialog(context);
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Skin card (simple single row) ───────────────────────────────────────────

class _SkinCard extends StatelessWidget {
  const _SkinCard({
    required this.skin,
    required this.swatchColor,
    required this.unlocked,
    required this.equipped,
    required this.selected,
    required this.canAfford,
    required this.onSelect,
    required this.onUnlock,
    required this.onEquip,
  });

  final PaperSkin skin;
  final Color swatchColor;
  final bool unlocked;
  final bool equipped;
  final bool selected;
  final bool canAfford;
  final VoidCallback onSelect;
  final VoidCallback onUnlock;
  final VoidCallback onEquip;

  @override
  Widget build(BuildContext context) {
    final rarity = skin.rarity;
    final borderColor = equipped
        ? AppColors.success
        : (selected
            ? AppColors.accent.withOpacity(0.7)
            : rarity.color
                .withOpacity(rarity == SkinRarity.common ? .35 : .72));
    final bg = equipped ? const Color(0xFFE9F7EE) : AppColors.paper;

    return PaperCard(
      onTap: onSelect,
      color: bg,
      elevation: equipped ? 1.6 : (selected ? 1.3 : 1.0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderColor: borderColor,
      borderWidth: equipped ? 2.2 : 1.2,
      child: Row(
        children: [
          _SkinSwatch(
            skin: skin,
            unlocked: unlocked,
            color: swatchColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        skin.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyLarge.copyWith(
                            color: AppColors.paperInk, fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _SkinRarityBadge(rarity: rarity),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  skin.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                      color: AppColors.paperInkSoft, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _ActionChip(
            unlocked: unlocked,
            equipped: equipped,
            costCoins: skin.unlockCostCoins,
            costGems: skin.unlockCostGems,
            canAfford: canAfford,
            onUnlock: onUnlock,
            onEquip: onEquip,
            showFreeButton: true,
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Power-Ups Tab
// ════════════════════════════════════════════════════════════════════════════

class _PowerUpsTab extends ConsumerWidget {
  const _PowerUpsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final save = ref.watch(saveDataProvider);
    final notifier = ref.read(saveDataProvider.notifier);
    const evolvable = [PowerUpType.magnet, PowerUpType.shield];

    return Container(
      color: AppColors.backgroundDeep,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
        children: [
          Text('POWER-UP EVOLUTION', style: AppTypography.headline),
          const SizedBox(height: 6),
          Text(
            'Permanent Hangar research. Timed bursts inherit these upgrades in every run.',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 18),
          for (final type in evolvable) ...[
            _PowerUpEvolutionCard(
              type: type,
              level: save.getPowerUpLevel(type.index),
              canAfford: save.coins >= type.evolutionCost(
                  save.getPowerUpLevel(type.index) + 1),
              onUpgrade: () async {
                final success = await notifier.upgradePowerUp(type);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(success
                      ? '${type.displayName} evolved to Lv2!'
                      : 'Not enough coins or already at max level.'),
                  backgroundColor:
                      success ? AppColors.success : AppColors.danger,
                ));
              },
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _PowerUpEvolutionCard extends StatelessWidget {
  const _PowerUpEvolutionCard({
    required this.type,
    required this.level,
    required this.canAfford,
    required this.onUpgrade,
  });

  final PowerUpType type;
  final int level;
  final bool canAfford;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final isMax = level >= GameConfig.powerUpEvolutionMaxLevel;
    final color = type == PowerUpType.magnet
        ? const Color(0xFFAB47BC)
        : const Color(0xFF64B5F6);
    final icon = type == PowerUpType.magnet
        ? Icons.my_location_rounded
        : Icons.shield_rounded;
    final cost = type.evolutionCost(level + 1);

    return PaperCard(
      color: AppColors.paper,
      padding: const EdgeInsets.all(16),
      borderColor: color.withOpacity(.62),
      borderWidth: 1.4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyLarge.copyWith(
                            color: AppColors.paperInk, fontSize: 16)),
                    const SizedBox(height: 3),
                    Text(
                      type.evolutionDescription(level),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.paperInkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'LV $level',
                style: AppTypography.overline.copyWith(fontSize: 10),
              ),
            ],
          ),
          if (!isMax) ...[
            const SizedBox(height: 12),
            PaperButton(
              label: 'EVOLVE • $cost',
              compact: true,
              expand: true,
              color: canAfford ? color : AppColors.paperInkSoft,
              textColor: Colors.white,
              onPressed: canAfford ? onUpgrade : null,
            ),
          ] else ...[
            const SizedBox(height: 10),
            Center(
              child: Text(
                '★ EVOLUTION COMPLETE ★',
                style: AppTypography.overline.copyWith(
                  fontSize: 9,
                  color: color,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Shared widgets
// ════════════════════════════════════════════════════════════════════════════

/// Speed, Glide, Shield normalized 0..1 for each plane (scales with tier).
List<double> _statsForPlane(PlaneType p, [int level = 1]) {
  final boost = (level - 1) * 0.05;
  switch (p) {
    case PlaneType.dart:
      return [
        (0.68 + boost).clamp(0.0, 1.0),
        (0.62 + boost).clamp(0.0, 1.0),
        (0.55 + boost * 0.5).clamp(0.0, 1.0),
      ];
    case PlaneType.glider:
      return [
        (0.42 + boost * 0.5).clamp(0.0, 1.0),
        (0.96 + boost).clamp(0.0, 1.0),
        (0.45 + boost).clamp(0.0, 1.0),
      ];
    case PlaneType.stuntFold:
      return [
        (0.88 + boost).clamp(0.0, 1.0),
        (0.38 + boost * 0.5).clamp(0.0, 1.0),
        (0.40 + boost).clamp(0.0, 1.0),
      ];
    case PlaneType.crane:
      return [
        (0.50 + boost * 0.5).clamp(0.0, 1.0),
        (0.84 + boost).clamp(0.0, 1.0),
        (0.78 + boost).clamp(0.0, 1.0),
      ];
    case PlaneType.stealthJet:
      return [
        (0.82 + boost).clamp(0.0, 1.0),
        (0.58 + boost).clamp(0.0, 1.0),
        (0.90 + boost).clamp(0.0, 1.0),
      ];
    case PlaneType.butterfly:
      return [
        (0.45 + boost * 0.5).clamp(0.0, 1.0),
        (0.95 + boost).clamp(0.0, 1.0),
        (0.60 + boost).clamp(0.0, 1.0),
      ];
    case PlaneType.bomber:
      return [
        (0.40 + boost * 0.5).clamp(0.0, 1.0),
        (0.50 + boost * 0.5).clamp(0.0, 1.0),
        (0.98 + boost).clamp(0.0, 1.0),
      ];
    case PlaneType.interceptor:
      return [
        (0.96 + boost).clamp(0.0, 1.0),
        (0.48 + boost * 0.5).clamp(0.0, 1.0),
        (0.42 + boost).clamp(0.0, 1.0),
      ];
    case PlaneType.albatross:
      return [
        (0.46 + boost * 0.5).clamp(0.0, 1.0),
        (0.98 + boost).clamp(0.0, 1.0),
        (0.52 + boost).clamp(0.0, 1.0),
      ];
    case PlaneType.biplane:
      return [
        (0.65 + boost).clamp(0.0, 1.0),
        (0.75 + boost).clamp(0.0, 1.0),
        (0.70 + boost).clamp(0.0, 1.0),
      ];
    case PlaneType.ninjaStar:
      return [
        (0.92 + boost).clamp(0.0, 1.0),
        (0.45 + boost * 0.5).clamp(0.0, 1.0),
        (0.50 + boost).clamp(0.0, 1.0),
      ];
    case PlaneType.rocket:
      return [
        (0.95 + boost).clamp(0.0, 1.0),
        (0.50 + boost * 0.5).clamp(0.0, 1.0),
        (0.75 + boost).clamp(0.0, 1.0),
      ];
  }
}

class _AnimatedStatBar extends StatelessWidget {
  const _AnimatedStatBar({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final double value; // 0..1
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 34,
          child: Text(label,
              style: AppTypography.overline.copyWith(
                  color: AppColors.paperInkSoft,
                  fontSize: 9,
                  letterSpacing: 0.9)),
        ),
        Expanded(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, animVal, _) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  height: 8,
                  color: AppColors.paperWarm,
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: animVal,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          color.withOpacity(0.85),
                          color,
                        ]),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Single status pill: EQUIPPED / LOCKED / READY.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.equipped, required this.unlocked});
  final bool equipped;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final String label;
    final IconData icon;
    if (equipped) {
      bg = AppColors.success;
      label = 'EQUIPPED';
      icon = Icons.check_circle;
    } else if (!unlocked) {
      bg = Colors.white.withOpacity(0.14);
      label = 'LOCKED';
      icon = Icons.lock;
    } else {
      bg = Colors.white.withOpacity(0.12);
      label = 'READY TO EQUIP';
      icon = Icons.flight_takeoff_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: equipped
            ? null
            : Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 11,
              color: equipped
                  ? Colors.white
                  : Colors.white.withOpacity(unlocked ? 0.85 : 0.7)),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.overline.copyWith(
              color: equipped
                  ? Colors.white
                  : Colors.white.withOpacity(unlocked ? 0.85 : 0.7),
              fontSize: 9,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

/// Right-hand action for list cards: EQUIPPED chip / Equip button / price.
class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.unlocked,
    required this.equipped,
    required this.costCoins,
    required this.costGems,
    required this.canAfford,
    required this.onUnlock,
    required this.onEquip,
    this.showFreeButton = false,
  });
  final bool unlocked;
  final bool equipped;
  final int costCoins;
  final int costGems;
  final bool canAfford;
  final VoidCallback onUnlock;
  final VoidCallback onEquip;
  final bool showFreeButton;

  @override
  Widget build(BuildContext context) {
    if (equipped) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.success,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check, size: 13, color: Colors.white),
            const SizedBox(width: 4),
            Text('EQUIPPED',
                style: AppTypography.label.copyWith(
                    color: Colors.white, fontSize: 10, letterSpacing: 0.6)),
          ],
        ),
      );
    }
    if (unlocked) {
      return PaperButton(
        label: 'Equip',
        compact: true,
        color: AppColors.success,
        textColor: Colors.white,
        onPressed: onEquip,
      );
    }
    if (showFreeButton && costCoins == 0 && costGems == 0) {
      return PaperButton(
        label: 'Free',
        compact: true,
        color: AppColors.success,
        textColor: Colors.white,
        onPressed: onUnlock,
      );
    }
    return _HighContrastPurchaseButton(
      costCoins: costCoins,
      costGems: costGems,
      canAfford: canAfford,
      onUnlock: onUnlock,
    );
  }
}

/// High-contrast dark purchase button with coin/gem chips inside.
class _HighContrastPurchaseButton extends StatelessWidget {
  const _HighContrastPurchaseButton({
    required this.costCoins,
    required this.costGems,
    required this.canAfford,
    required this.onUnlock,
  });
  final int costCoins;
  final int costGems;
  final bool canAfford;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final hasPrice = costCoins > 0 || costGems > 0;
    if (!hasPrice) {
      return PaperButton(
          label: 'Free',
          compact: true,
          color: AppColors.success,
          textColor: Colors.white,
          onPressed: onUnlock);
    }
    return Opacity(
      opacity: canAfford ? 1 : 0.55,
      child: GestureDetector(
        onTap: canAfford ? onUnlock : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: canAfford
                ? AppColors.paperInk
                : AppColors.paperInk.withOpacity(0.55),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: canAfford
                    ? AppColors.coinGold.withOpacity(0.9)
                    : Colors.white.withOpacity(0.22),
                width: 1.4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (costCoins > 0) ...[
                PaperIcon(PaperIconData.coin,
                    size: 13, color: AppColors.coinGold),
                const SizedBox(width: 4),
                Text('$costCoins',
                    style: TextStyle(
                        fontFamily: AppTypography.mono,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: canAfford
                            ? AppColors.coinGold
                            : AppColors.coinGold.withOpacity(0.55))),
              ],
              if (costGems > 0) ...[
                if (costCoins > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                      width: 1,
                      height: 12,
                      color: Colors.white.withOpacity(0.22)),
                  const SizedBox(width: 6),
                ],
                PaperIcon(PaperIconData.gem,
                    size: 12, color: AppColors.gemBlue),
                const SizedBox(width: 4),
                Text('$costGems',
                    style: TextStyle(
                        fontFamily: AppTypography.mono,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: canAfford
                            ? AppColors.gemBlue
                            : AppColors.gemBlue.withOpacity(0.55))),
              ],
              const SizedBox(width: 6),
              Icon(Icons.lock_open_rounded,
                  size: 12,
                  color: canAfford
                      ? Colors.white.withOpacity(0.9)
                      : Colors.white.withOpacity(0.45)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Small shared pieces ─────────────────────────────────────────────────────

class _SkinRarityBadge extends StatelessWidget {
  const _SkinRarityBadge({required this.rarity});
  final SkinRarity rarity;

  @override
  Widget build(BuildContext context) {
    final isMythic = rarity == SkinRarity.mythic;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        gradient: isMythic
            ? const LinearGradient(
                colors: [
                  Color(0xFFFF80AB),
                  Color(0xFF80D8FF),
                  Color(0xFFB9F6CA),
                  Color(0xFFFFD740),
                ],
              )
            : null,
        color: isMythic ? null : rarity.color.withOpacity(.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isMythic ? Colors.white.withOpacity(.8) : rarity.color,
        ),
      ),
      child: Text(
        rarity.label,
        style: AppTypography.overline.copyWith(
          color: isMythic ? AppColors.paperInk : rarity.color,
          fontSize: 7,
          letterSpacing: .5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _PlanePreview extends StatelessWidget {
  const _PlanePreview(
      {required this.plane, required this.unlocked, this.size = 46});
  final PlaneType plane;
  final bool unlocked;
  final double size;

  @override
  Widget build(BuildContext context) {
    final w = size;
    final h = size * 0.72;
    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(
          opacity: unlocked ? 1.0 : 0.32,
          child: CustomPaint(
            size: Size(w, h),
            painter: _PlaneMiniPainter(plane: plane),
          ),
        ),
        if (!unlocked)
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: AppColors.paperInk.withOpacity(0.82),
              shape: BoxShape.circle,
              border:
                  Border.all(color: Colors.white.withOpacity(0.9), width: 1.2),
            ),
            child: const Icon(Icons.lock, size: 11, color: Colors.white),
          ),
      ],
    );
  }
}

class _SkinSwatch extends StatelessWidget {
  const _SkinSwatch({
    required this.skin,
    required this.unlocked,
    required this.color,
  });
  final PaperSkin skin;
  final bool unlocked;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const double w = 52;
    const double h = 38;
    final rarity = skin.rarity;
    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(
          opacity: unlocked ? 1.0 : 0.42,
          child: Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: rarity.color.withOpacity(
                  rarity == SkinRarity.common ? .42 : .82,
                ),
                width: rarity == SkinRarity.mythic ? 1.8 : 1.1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: CustomPaint(painter: _SkinPatternPainter(skin: skin)),
            ),
          ),
        ),
        if (!unlocked)
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: AppColors.paperInk.withOpacity(0.84),
              shape: BoxShape.circle,
              border:
                  Border.all(color: Colors.white.withOpacity(0.9), width: 1.1),
            ),
            child: const Icon(Icons.lock, size: 11, color: Colors.white),
          ),
      ],
    );
  }
}

// ── Painters ────────────────────────────────────────────────────────────────

class _PlaneMiniPainter extends CustomPainter {
  const _PlaneMiniPainter({required this.plane});
  final PlaneType plane;

  @override
  void paint(Canvas canvas, Size size) {
    final color = _colorForPlane(plane);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;
    canvas.drawPath(_pathForPlane(w, h), paint);
    final foldPaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(w * 0.08, h / 2), Offset(w * 0.65, h / 2), foldPaint);
    if (plane == PlaneType.crane) {
      final neckPaint = Paint()
        ..color = Colors.white.withOpacity(0.18)
        ..strokeWidth = 0.9
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
          Offset(w * 0.45, h * 0.3), Offset(w * 0.45, h * 0.7), neckPaint);
    }
  }

  Path _pathForPlane(double w, double h) {
    if (plane == PlaneType.glider) {
      return Path()
        ..moveTo(w, h / 2)
        ..lineTo(w * 0.15, h * 0.08)
        ..lineTo(w * 0.28, h / 2)
        ..lineTo(w * 0.15, h * 0.92)
        ..close();
    }
    if (plane == PlaneType.stealthJet) {
      return Path()
        ..moveTo(w, h / 2)
        ..lineTo(w * 0.35, h * 0.12)
        ..lineTo(w * 0.22, h / 2)
        ..lineTo(w * 0.35, h * 0.88)
        ..close();
    }
    if (plane == PlaneType.crane) {
      return Path()
        ..moveTo(w, h / 2)
        ..lineTo(w * 0.05, h * 0.15)
        ..lineTo(w * 0.32, h / 2)
        ..lineTo(w * 0.05, h * 0.85)
        ..close();
    }
    if (plane == PlaneType.butterfly) {
      return Path()
        ..moveTo(w * 0.9, h / 2)
        ..lineTo(w * 0.3, h * 0.05)
        ..lineTo(w * 0.1, h * 0.35)
        ..lineTo(w * 0.35, h / 2)
        ..lineTo(w * 0.1, h * 0.65)
        ..lineTo(w * 0.3, h * 0.95)
        ..close();
    }
    if (plane == PlaneType.bomber) {
      return Path()
        ..moveTo(w * 0.95, h / 2)
        ..lineTo(w * 0.45, h * 0.08)
        ..lineTo(w * 0.1, h * 0.12)
        ..lineTo(w * 0.2, h / 2)
        ..lineTo(w * 0.1, h * 0.88)
        ..lineTo(w * 0.45, h * 0.92)
        ..close();
    }
    if (plane == PlaneType.interceptor) {
      return Path()
        ..moveTo(w, h / 2)
        ..lineTo(w * 0.55, h * 0.28)
        ..lineTo(0, h * 0.15)
        ..lineTo(w * 0.15, h / 2)
        ..lineTo(0, h * 0.85)
        ..lineTo(w * 0.55, h * 0.72)
        ..close();
    }
    if (plane == PlaneType.albatross) {
      return Path()
        ..moveTo(w, h / 2)
        ..lineTo(w * 0.05, 0)
        ..lineTo(w * 0.18, h / 2)
        ..lineTo(w * 0.05, h)
        ..close();
    }
    if (plane == PlaneType.biplane) {
      return Path()
        ..moveTo(w * 0.92, h / 2)
        ..lineTo(w * 0.2, h * 0.12)
        ..lineTo(w * 0.2, h * 0.88)
        ..close();
    }
    if (plane == PlaneType.ninjaStar) {
      return Path()
        ..moveTo(w, h / 2)
        ..lineTo(w * 0.65, h * 0.2)
        ..lineTo(w / 2, 0)
        ..lineTo(w * 0.35, h * 0.35)
        ..lineTo(0, h / 2)
        ..lineTo(w * 0.35, h * 0.8)
        ..lineTo(w / 2, h)
        ..lineTo(w * 0.65, h * 0.65)
        ..close();
    }
    if (plane == PlaneType.rocket) {
      return Path()
        ..moveTo(w, h / 2)
        ..lineTo(w * 0.2, h * 0.22)
        ..lineTo(w * 0.05, h * 0.05)
        ..lineTo(w * 0.15, h / 2)
        ..lineTo(w * 0.05, h * 0.95)
        ..lineTo(w * 0.2, h * 0.78)
        ..close();
    }
    return Path()
      ..moveTo(w, h / 2)
      ..lineTo(0, 0)
      ..lineTo(w * 0.25, h / 2)
      ..lineTo(0, h)
      ..close();
  }

  @override
  bool shouldRepaint(_PlaneMiniPainter old) => old.plane != plane;
}

Color _colorForPlane(PlaneType p) {
  switch (p) {
    case PlaneType.dart:
      return AppColors.accent;
    case PlaneType.glider:
      return AppColors.accentAlt;
    case PlaneType.stuntFold:
      return AppColors.danger;
    case PlaneType.crane:
      return const Color(0xFF81C784);
    case PlaneType.stealthJet:
      return const Color(0xFF90A4AE);
    case PlaneType.butterfly:
      return const Color(0xFFCE93D8);
    case PlaneType.bomber:
      return const Color(0xFF8D6E63);
    case PlaneType.interceptor:
      return const Color(0xFF00E5FF);
    case PlaneType.albatross:
      return const Color(0xFF4DB6AC);
    case PlaneType.biplane:
      return const Color(0xFFFFB74D);
    case PlaneType.ninjaStar:
      return const Color(0xFFEF5350);
    case PlaneType.rocket:
      return const Color(0xFF42A5F5);
  }
}

class _PlaneShowcasePainter extends CustomPainter {
  _PlaneShowcasePainter({required this.plane, this.tint});
  final PlaneType plane;
  final Color? tint;

  @override
  void paint(Canvas canvas, Size size) {
    final color = tint ?? _colorForPlane(plane);
    final w = size.width;
    final h = size.height;
    final path = _pathForPlane(w, h);
    // soft ambient shadow under plane (for depth)
    canvas.drawPath(
        path.shift(const Offset(3, 4)),
        Paint()
          ..color = Colors.black.withOpacity(0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);

    // top highlight fold
    final fold = Paint()
      ..color = Colors.white.withOpacity(tint != null ? 0.55 : 0.22)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(w * 0.10, h / 2), Offset(w * 0.62, h / 2), fold);

    if (tint == null) {
      final deep = HSLColor.fromColor(color)
          .withLightness(
              (HSLColor.fromColor(color).lightness - 0.22).clamp(0.0, 1.0))
          .toColor();
      final folded = Path()
        ..moveTo(w, h / 2)
        ..lineTo(w * 0.28, h / 2)
        ..lineTo(w * 0.10, h * 0.82)
        ..close();
      canvas.drawPath(folded, Paint()..color = deep.withOpacity(0.92));
    }
  }

  Path _pathForPlane(double w, double h) {
    if (plane == PlaneType.glider) {
      return Path()
        ..moveTo(w, h / 2)
        ..lineTo(w * 0.15, h * 0.08)
        ..lineTo(w * 0.28, h / 2)
        ..lineTo(w * 0.15, h * 0.92)
        ..close();
    }
    if (plane == PlaneType.stealthJet) {
      return Path()
        ..moveTo(w, h / 2)
        ..lineTo(w * 0.35, h * 0.12)
        ..lineTo(w * 0.22, h / 2)
        ..lineTo(w * 0.35, h * 0.88)
        ..close();
    }
    if (plane == PlaneType.crane) {
      return Path()
        ..moveTo(w, h / 2)
        ..lineTo(w * 0.05, h * 0.15)
        ..lineTo(w * 0.32, h / 2)
        ..lineTo(w * 0.05, h * 0.85)
        ..close();
    }
    if (plane == PlaneType.butterfly) {
      return Path()
        ..moveTo(w * 0.9, h / 2)
        ..lineTo(w * 0.3, h * 0.05)
        ..lineTo(w * 0.1, h * 0.35)
        ..lineTo(w * 0.35, h / 2)
        ..lineTo(w * 0.1, h * 0.65)
        ..lineTo(w * 0.3, h * 0.95)
        ..close();
    }
    if (plane == PlaneType.bomber) {
      return Path()
        ..moveTo(w * 0.95, h / 2)
        ..lineTo(w * 0.45, h * 0.08)
        ..lineTo(w * 0.1, h * 0.12)
        ..lineTo(w * 0.2, h / 2)
        ..lineTo(w * 0.1, h * 0.88)
        ..lineTo(w * 0.45, h * 0.92)
        ..close();
    }
    if (plane == PlaneType.interceptor) {
      return Path()
        ..moveTo(w, h / 2)
        ..lineTo(w * 0.55, h * 0.28)
        ..lineTo(0, h * 0.15)
        ..lineTo(w * 0.15, h / 2)
        ..lineTo(0, h * 0.85)
        ..lineTo(w * 0.55, h * 0.72)
        ..close();
    }
    if (plane == PlaneType.albatross) {
      return Path()
        ..moveTo(w, h / 2)
        ..lineTo(w * 0.05, 0)
        ..lineTo(w * 0.18, h / 2)
        ..lineTo(w * 0.05, h)
        ..close();
    }
    if (plane == PlaneType.biplane) {
      return Path()
        ..moveTo(w * 0.92, h / 2)
        ..lineTo(w * 0.2, h * 0.12)
        ..lineTo(w * 0.2, h * 0.88)
        ..close();
    }
    if (plane == PlaneType.ninjaStar) {
      return Path()
        ..moveTo(w, h / 2)
        ..lineTo(w * 0.65, h * 0.2)
        ..lineTo(w / 2, 0)
        ..lineTo(w * 0.35, h * 0.35)
        ..lineTo(0, h / 2)
        ..lineTo(w * 0.35, h * 0.8)
        ..lineTo(w / 2, h)
        ..lineTo(w * 0.65, h * 0.65)
        ..close();
    }
    if (plane == PlaneType.rocket) {
      return Path()
        ..moveTo(w, h / 2)
        ..lineTo(w * 0.2, h * 0.22)
        ..lineTo(w * 0.05, h * 0.05)
        ..lineTo(w * 0.15, h / 2)
        ..lineTo(w * 0.05, h * 0.95)
        ..lineTo(w * 0.2, h * 0.78)
        ..close();
    }
    return Path()
      ..moveTo(w, h / 2)
      ..lineTo(0, 0)
      ..lineTo(w * 0.25, h / 2)
      ..lineTo(0, h)
      ..close();
  }

  @override
  bool shouldRepaint(covariant _PlaneShowcasePainter old) =>
      old.plane != plane || old.tint != tint;
}

class _OrigamiShadowPainter extends CustomPainter {
  _OrigamiShadowPainter({required this.unlocked});
  final bool unlocked;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final base = Paint()
      ..color = Colors.black.withOpacity(unlocked ? 0.38 : 0.18);
    final diamond = Path()
      ..moveTo(w / 2, 0)
      ..lineTo(w, h / 2)
      ..lineTo(w / 2, h)
      ..lineTo(0, h / 2)
      ..close();
    canvas.drawPath(diamond, base);
    final inner = Paint()
      ..color = Colors.black.withOpacity(unlocked ? 0.22 : 0.10);
    final innerPath = Path()
      ..moveTo(w / 2, h * 0.15)
      ..lineTo(w * 0.82, h / 2)
      ..lineTo(w / 2, h * 0.85)
      ..lineTo(w * 0.18, h / 2)
      ..close();
    canvas.drawPath(innerPath, inner);
  }

  @override
  bool shouldRepaint(covariant _OrigamiShadowPainter old) =>
      old.unlocked != unlocked;
}

class _PedestalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final topW = w * 0.78;
    final leftTop = (w - topW) / 2;
    final path = Path()
      ..moveTo(leftTop, 0)
      ..lineTo(leftTop + topW, 0)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
        path.shift(const Offset(0, 2)),
        Paint()
          ..color = Colors.black.withOpacity(0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    final facePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xFFF6EEDC), const Color(0xFFE3CFA6)],
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, facePaint);
    canvas.drawPath(
        Path()
          ..moveTo(leftTop, 0)
          ..lineTo(leftTop + topW, 0)
          ..lineTo(leftTop + topW - 6, 3)
          ..lineTo(leftTop + 6, 3)
          ..close(),
        Paint()..color = Colors.white.withOpacity(0.55));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _SkinPatternPainter extends CustomPainter {
  _SkinPatternPainter({required this.skin});
  final PaperSkin skin;

  @override
  void paint(Canvas canvas, Size size) {
    switch (skin) {
      case PaperSkin.plain:
        break;
      case PaperSkin.newspaper:
        final p = Paint()
          ..color = const Color(0xFF5D4037).withOpacity(0.35)
          ..strokeWidth = 1;
        canvas.drawLine(
            Offset(4, 8), Offset(size.width - 4, 8), p..strokeWidth = 2);
        for (double y = 14; y < size.height - 4; y += 4.5) {
          canvas.drawLine(
              Offset(4, y), Offset(size.width * 0.48, y), p..strokeWidth = 0.8);
          canvas.drawLine(Offset(size.width * 0.52, y),
              Offset(size.width - 4, y), p..strokeWidth = 0.8);
        }
        break;
      case PaperSkin.graphPaper:
        final p = Paint()
          ..color = const Color(0xFF0288D1).withOpacity(0.35)
          ..strokeWidth = 0.6;
        for (double x = 6; x < size.width; x += 7) {
          canvas.drawLine(Offset(x, 3), Offset(x, size.height - 3), p);
        }
        for (double y = 5; y < size.height; y += 7) {
          canvas.drawLine(Offset(4, y), Offset(size.width - 4, y), p);
        }
        break;
      case PaperSkin.notebookDoodle:
        final line = Paint()
          ..color = const Color(0xFF4FC3F7).withOpacity(0.45)
          ..strokeWidth = 0.7;
        for (double y = 8; y < size.height - 5; y += 6) {
          canvas.drawLine(Offset(5, y), Offset(size.width - 5, y), line);
        }
        final margin = Paint()
          ..color = const Color(0xFFFF5252).withOpacity(0.55)
          ..strokeWidth = 1.0;
        canvas.drawLine(Offset(12, 3), Offset(12, size.height - 3), margin);
        break;
      case PaperSkin.holographicFoil:
      case PaperSkin.animatedHologram:
      case PaperSkin.flipbook:
        final foil = Paint()
          ..shader = LinearGradient(
                  colors: [
                    const Color(0xFFE040FB),
                    const Color(0xFF00E5FF),
                    const Color(0xFF76FF03),
                    const Color(0xFFFFD740),
                    const Color(0xFFE040FB),
                  ],
                  stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight)
              .createShader(Rect.fromLTWH(0, 0, size.width, size.height))
          ..style = PaintingStyle.fill;
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), foil);
        final sweep = Paint()
          ..color = Colors.white.withOpacity(0.35)
          ..style = PaintingStyle.fill;
        final sweepPath = Path()
          ..moveTo(size.width * 0.1, 0)
          ..lineTo(size.width * 0.35, 0)
          ..lineTo(size.width * 0.65, size.height)
          ..lineTo(size.width * 0.4, size.height)
          ..close();
        canvas.drawPath(sweepPath, sweep);
        break;
      case PaperSkin.watercolorWash:
        final wash = Paint()
          ..color = const Color(0xFF4FC3F7).withOpacity(0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        final washB = Paint()
          ..color = const Color(0xFFFF80AB).withOpacity(0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawCircle(
            Offset(size.width * 0.45, size.height * 0.45), 12, wash);
        canvas.drawCircle(
            Offset(size.width * 0.65, size.height * 0.6), 8, washB);
        break;
      case PaperSkin.goldLeaf:
        final g = Paint()..color = const Color(0xFFFFD700).withOpacity(0.5);
        canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.45), 2.5, g);
        canvas.drawCircle(Offset(size.width * 0.6, size.height * 0.55), 2.0, g);
        canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.3), 1.6, g);
        break;
      case PaperSkin.blueprint:
        final bp = Paint()
          ..color = Colors.white.withOpacity(0.4)
          ..strokeWidth = 0.8
          ..style = PaintingStyle.stroke;
        canvas.drawRect(
            Rect.fromLTWH(6, 6, size.width - 12, size.height - 12), bp);
        canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.5), 6, bp);
        break;
      case PaperSkin.receipt:
        final b = Paint()..color = const Color(0xFF212121).withOpacity(0.35);
        for (double x = 8; x < size.width - 8; x += 3.5) {
          canvas.drawRect(
              Rect.fromLTWH(
                  x, 10, (x * 3).toInt() % 2 == 0 ? 1.8 : 0.9, 14),
              b);
        }
        break;
      case PaperSkin.carbonFiber:
        final c1 = Paint()
          ..color = const Color(0xFF424242).withOpacity(0.5)
          ..strokeWidth = 1;
        final c2 = Paint()
          ..color = const Color(0xFF1E1E1E).withOpacity(0.5)
          ..strokeWidth = 1;
        for (double d = -size.width; d < size.width * 2; d += 4) {
          canvas.drawLine(Offset(d, 0), Offset(d + size.height, size.height), c1);
          canvas.drawLine(Offset(d, size.height), Offset(d + size.height, 0), c2);
        }
        break;
      case PaperSkin.mangaHalftone:
        final dot = Paint()..color = const Color(0xFF212121).withOpacity(0.25);
        for (double x = 6; x < size.width - 6; x += 4) {
          for (double y = 6; y < size.height - 6; y += 4) {
            canvas.drawCircle(Offset(x, y), 0.8, dot);
          }
        }
        break;
      case PaperSkin.kraftEnvelope:
        final red = Paint()
          ..color = const Color(0xFFD32F2F).withOpacity(0.6)
          ..strokeWidth = 1.5;
        final blue = Paint()
          ..color = const Color(0xFF1976D2).withOpacity(0.6)
          ..strokeWidth = 1.5;
        for (double x = 4; x < size.width - 4; x += 8) {
          canvas.drawLine(Offset(x, 4), Offset(x + 4, 4), red);
          canvas.drawLine(Offset(x + 4, 4), Offset(x + 8, 4), blue);
        }
        break;
      case PaperSkin.prideGradient:
        final p = Paint()
          ..shader = LinearGradient(
            colors: const [
              Color(0xFFFF1744),
              Color(0xFFFF9100),
              Color(0xFFFFEA00),
              Color(0xFF00E676),
              Color(0xFF2979FF),
              Color(0xFFAA00FF),
            ],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
          ..style = PaintingStyle.fill;
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), p);
        break;
      case PaperSkin.dragonScales:
        final s = Paint()
          ..color = const Color(0xFF00E676).withOpacity(0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8;
        for (double x = 8; x < size.width - 8; x += 6) {
          for (double y = 8; y < size.height - 8; y += 5) {
            final p = Path()
              ..moveTo(x, y)
              ..lineTo(x + 3, y + 3)
              ..lineTo(x, y + 6)
              ..lineTo(x - 3, y + 3)
              ..close();
            canvas.drawPath(p, s);
          }
        }
        break;
      case PaperSkin.snowflake:
        final snow = Paint()
          ..color = Colors.white.withOpacity(0.7)
          ..strokeWidth = 0.8;
        final c = Offset(size.width * 0.5, size.height * 0.5);
        for (int i = 0; i < 6; i++) {
          final ang = i * math.pi / 3;
          canvas.drawLine(
              c,
              Offset(c.dx + math.cos(ang) * 8, c.dy + math.sin(ang) * 8),
              snow);
        }
        break;
      case PaperSkin.pumpkin:
        final pump = Paint()
          ..color = const Color(0xFFFFD54F).withOpacity(0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(size.width * 0.5, size.height * 0.5),
                width: 14,
                height: 10),
            pump);
        break;
      case PaperSkin.cherryBlossom:
        final pet = Paint()..color = const Color(0xFFF48FB1).withOpacity(0.6);
        canvas.drawCircle(Offset(size.width * 0.4, size.height * 0.4), 2.5, pet);
        canvas.drawCircle(Offset(size.width * 0.6, size.height * 0.55), 2.2, pet);
        break;
      case PaperSkin.lavaLamp:
        final l1 = Paint()
          ..color = const Color(0xFFFF4081).withOpacity(0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        final l2 = Paint()
          ..color = const Color(0xFF00E5FF).withOpacity(0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawCircle(Offset(size.width * 0.4, size.height * 0.45), 7, l1);
        canvas.drawCircle(Offset(size.width * 0.65, size.height * 0.55), 8, l2);
        break;
      case PaperSkin.customCraft:
        final st = Paint()
          ..color = Colors.white.withOpacity(0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8;
        canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.5), 5, st);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _SkinPatternPainter old) => old.skin != skin;
}
