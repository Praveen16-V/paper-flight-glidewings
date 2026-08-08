import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_typography.dart';
import '../core/enums/game_enums.dart';
import '../core/widgets/currency_chip.dart';
import '../core/widgets/paper_button.dart';
import '../core/widgets/paper_card.dart';
import '../core/widgets/paper_icons.dart';
import '../providers/save_data_provider.dart';
import '../services/analytics_service.dart';

/// Hangar — browse, unlock and equip planes + paper skins.
///
/// Redesign (spec):
/// - Top 40 % is a **Hangar Showcase Stage**: spotlighted paper pedestal,
///   floating plane/skin at large scale with origami shadow.
/// - **Visual stat comparisons**: animated stat bars + 3-axis radar triangle
///   for Speed / Glide / Shield so Dart / Glider / Stunt Fold trade-offs are instant.
/// - **Equipped vs Locked hierarchy**: vibrant green outline + checkmark badge
///   for EQUIPPED, padlock + high-contrast coin button for locked.
class HangarScreen extends ConsumerWidget {
  const HangarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final save = ref.watch(saveDataProvider);
    return DefaultTabController(
      length: 2,
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
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _PlanesTab(),
            _SkinsTab(),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Planes Tab — Stage + stats + list
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
    final plane = PlaneType.values[selected.clamp(0, PlaneType.values.length - 1)];
    final unlocked = notifier.isPlaneUnlocked(selected);
    final isEquipped = equipped == selected;

    return Column(
      children: [
        // ── 40% Showcase Stage ──
        Expanded(
          flex: 4,
          child: _PlaneShowcaseStage(
            plane: plane,
            unlocked: unlocked,
            equipped: isEquipped,
            selectedIndex: selected,
          ),
        ),
        // ── Stats + list ──
        Expanded(
          flex: 6,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.backgroundDeep,
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Column(
              children: [
                // drag handle — tapping scrolls list to top
                Center(
                  child: Tooltip(
                    message: 'Scroll to top',
                    child: GestureDetector(
                      onTap: () {
                        // scroll controller access via PrimaryScrollController
                        PrimaryScrollController.of(context).animateTo(
                          0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(top: 10, bottom: 8),
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.28),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text('PLANE COLLECTION',
                          style: AppTypography.overline.copyWith(
                              color: Colors.white.withOpacity(0.55),
                              fontSize: 10,
                              letterSpacing: 1.3)),
                      const Spacer(),
                      Text('${PlaneType.values.length} PLANES',
                          style: AppTypography.caption.copyWith(
                              color: Colors.white.withOpacity(0.35),
                              fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: PlaneType.values.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final p = PlaneType.values[index];
                      final unl = notifier.isPlaneUnlocked(index);
                      final equip = save.equippedPlaneIndex == index;
                      final isSel = selected == index;
                      final canAffordCoins = save.coins >= p.unlockCost;
                      final canAffordGems = save.gems >= p.unlockGemCost;
                      final canAfford = canAffordCoins && canAffordGems;

                      return _PlaneCard(
                        plane: p,
                        unlocked: unl,
                        equipped: equip,
                        selected: isSel,
                        canAfford: canAfford,
                        onSelect: () => setState(() => _selected = index),
                        onUnlock: () async {
                          final success = await notifier.unlockPlane(
                            index,
                            p.unlockCost,
                            gemCost: p.unlockGemCost,
                          );
                          if (success && context.mounted) {
                            AnalyticsService.instance
                                .logPlaneUnlocked(p.assetName);
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
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Planes Showcase Stage ──────────────────────────────────────────────────

class _PlaneShowcaseStage extends StatefulWidget {
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
  State<_PlaneShowcaseStage> createState() => _PlaneShowcaseStageState();
}

class _PlaneShowcaseStageState extends State<_PlaneShowcaseStage>
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
    final stats = _statsForPlane(widget.plane);
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
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Spotlight beam
          CustomPaint(painter: _SpotlightPainter()),
          // subtle paper grain
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.06,
                child: CustomPaint(painter: _GrainPainter()),
              ),
            ),
          ),
          // Stage content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                // Left: floating plane + pedestal
                Expanded(
                  flex: 5,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // top badge row
                      SizedBox(
                        height: 22,
                        child: Row(
                          children: [
                            if (widget.equipped)
                              const _EquippedPill()
                            else if (!widget.unlocked)
                              const _LockedPill()
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.18)),
                                ),
                                child: Text('READY TO EQUIP',
                                    style: AppTypography.overline.copyWith(
                                        color: Colors.white.withOpacity(0.85),
                                        fontSize: 9,
                                        letterSpacing: 1.1)),
                              ),
                            const Spacer(),
                            // plane name small
                            Flexible(
                              child: Text(widget.plane.displayName.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.overline.copyWith(
                                      color: Colors.white.withOpacity(0.55),
                                      fontSize: 9,
                                      letterSpacing: 1.0)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 380),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child: ScaleTransition(
                                scale: Tween<double>(begin: 0.92, end: 1.0)
                                    .animate(anim),
                                child: child),
                          ),
                          child: AnimatedBuilder(
                            key: ValueKey(widget.selectedIndex),
                            animation: _floatCtrl,
                            builder: (context, child) {
                              final t = _floatCtrl.value; // 0..1
                              final dy = math.sin(t * math.pi) * 6;
                              final shadowScale = 1.0 - (t * 0.12);
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Transform.translate(
                                    offset: Offset(0, dy - 2),
                                    child: Opacity(
                                      opacity: widget.unlocked ? 1 : 0.38,
                                      child: CustomPaint(
                                        size: const Size(142, 96),
                                        painter: _PlaneShowcasePainter(
                                            plane: widget.plane),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // Origami shadow — sharp diamond, not soft blur
                                  Transform.scale(
                                    scale: shadowScale,
                                    child: CustomPaint(
                                      size: const Size(78, 18),
                                      painter: _OrigamiShadowPainter(
                                          unlocked: widget.unlocked),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  // Paper pedestal
                                  CustomPaint(
                                    size: const Size(110, 22),
                                    painter: _PedestalPainter(),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // tap hint
                      Text(widget.plane.tagline,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                              color: Colors.white.withOpacity(0.55),
                              fontSize: 10,
                              fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Right: radar + animated bars
                Expanded(
                  flex: 5,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: AppColors.paper.withOpacity(0.96),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.28),
                            blurRadius: 12,
                            offset: const Offset(0, 6)),
                      ],
                      border: Border.all(
                          color: Colors.white.withOpacity(0.5), width: 1),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Text('STATS',
                                style: AppTypography.overline.copyWith(
                                    color: AppColors.paperInkSoft,
                                    fontSize: 10,
                                    letterSpacing: 1.4)),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.backgroundDeep,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(widget.plane.signatureActionLabel,
                                  style: AppTypography.caption.copyWith(
                                      color: AppColors.accent,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Radar triangle
                        Center(
                          child: SizedBox(
                            width: 120,
                            height: 108,
                            child: _RadarChart(values: stats, animate: true),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _AnimatedStatBar(
                            label: 'SPEED',
                            value: stats[0],
                            color: const Color(0xFFFF6B6B)),
                        const SizedBox(height: 6),
                        _AnimatedStatBar(
                            label: 'GLIDE',
                            value: stats[1],
                            color: const Color(0xFF4FC3F7)),
                        const SizedBox(height: 6),
                        _AnimatedStatBar(
                            label: 'SHIELD',
                            value: stats[2],
                            color: const Color(0xFF56CF87)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Skins Tab — Stage + list
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
    final skin = PaperSkin.values[selected.clamp(0, PaperSkin.values.length - 1)];
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
            child: Column(
              children: [
                Center(
                  child: Tooltip(
                    message: 'Scroll to top',
                    child: GestureDetector(
                      onTap: () {
                        PrimaryScrollController.of(context).animateTo(
                          0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(top: 10, bottom: 8),
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.28),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text('PAPER COLLECTION',
                          style: AppTypography.overline.copyWith(
                              color: Colors.white.withOpacity(0.55),
                              fontSize: 10,
                              letterSpacing: 1.3)),
                      const Spacer(),
                      Text('${PaperSkin.values.length} SKINS',
                          style: AppTypography.caption.copyWith(
                              color: Colors.white.withOpacity(0.35),
                              fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: PaperSkin.values.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final s = PaperSkin.values[index];
                      final unl = notifier.isSkinUnlocked(index);
                      final equip = save.equippedSkinIndex == index;
                      final isSel = selected == index;
                      final canAffordCoins = save.coins >= s.unlockCostCoins;
                      final canAffordGems = save.gems >= s.unlockCostGems;
                      final canAfford = canAffordCoins && canAffordGems;
                      return _SkinCard(
                        skin: s,
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
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SkinShowcaseStage extends StatefulWidget {
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
  State<_SkinShowcaseStage> createState() => _SkinShowcaseStageState();
}

class _SkinShowcaseStageState extends State<_SkinShowcaseStage>
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
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A2748), Color(0xFF131C38), Color(0xFF0F1A33)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _SpotlightPainter()),
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.06,
                child: CustomPaint(painter: _GrainPainter()),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 22,
                        child: Row(
                          children: [
                            if (widget.equipped)
                              const _EquippedPill()
                            else if (!widget.unlocked)
                              const _LockedPill()
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.18)),
                                ),
                                child: Text('READY TO EQUIP',
                                    style: AppTypography.overline.copyWith(
                                        color: Colors.white.withOpacity(0.85),
                                        fontSize: 9,
                                        letterSpacing: 1.1)),
                              ),
                            const Spacer(),
                            Flexible(
                              child: Text(widget.skin.displayName.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.overline.copyWith(
                                      color: Colors.white.withOpacity(0.55),
                                      fontSize: 9,
                                      letterSpacing: 1.0)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 380),
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child: ScaleTransition(
                                scale: Tween<double>(begin: 0.92, end: 1.0)
                                    .animate(anim),
                                child: child),
                          ),
                          child: AnimatedBuilder(
                            key: ValueKey(widget.selectedIndex),
                            animation: _floatCtrl,
                            builder: (context, child) {
                              final t = _floatCtrl.value;
                              final dy = math.sin(t * math.pi) * 6;
                              final shadowScale = 1.0 - (t * 0.12);
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Transform.translate(
                                    offset: Offset(0, dy),
                                    child: Opacity(
                                      opacity: widget.unlocked ? 1 : 0.40,
                                      child: Container(
                                        width: 136,
                                        height: 86,
                                        decoration: BoxDecoration(
                                          color: Color(widget.skin.baseColorHex),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(
                                              color: Colors.white
                                                  .withOpacity(0.28),
                                              width: 1.4),
                                          boxShadow: [
                                            BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.28),
                                                blurRadius: 12,
                                                offset: const Offset(0, 6)),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(13),
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              CustomPaint(
                                                  painter:
                                                      _SkinPatternPainter(
                                                          skin: widget.skin)),
                                              // paper plane silhouette centered
                                              Center(
                                                child: CustomPaint(
                                                  size: const Size(58, 40),
                                                  painter: _PlaneShowcasePainter(
                                                      plane: PlaneType.dart,
                                                      tint: Colors.white
                                                          .withOpacity(0.94)),
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
                                      size: const Size(78, 18),
                                      painter: _OrigamiShadowPainter(
                                          unlocked: widget.unlocked),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  CustomPaint(
                                    size: const Size(110, 22),
                                    painter: _PedestalPainter(),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(widget.skin.description,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                              color: Colors.white.withOpacity(0.55),
                              fontSize: 10,
                              fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 5,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.paper.withOpacity(0.96),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.28),
                            blurRadius: 12,
                            offset: const Offset(0, 6)),
                      ],
                      border: Border.all(
                          color: Colors.white.withOpacity(0.5), width: 1),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('SKIN PREVIEW',
                            style: AppTypography.overline.copyWith(
                                color: AppColors.paperInkSoft,
                                fontSize: 10,
                                letterSpacing: 1.4)),
                        const SizedBox(height: 10),
                        // large swatch again + info
                        Container(
                          height: 64,
                          decoration: BoxDecoration(
                            color: Color(widget.skin.baseColorHex),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.black.withOpacity(0.08)),
                          ),
                          child: CustomPaint(
                              painter:
                                  _SkinPatternPainter(skin: widget.skin)),
                        ),
                        const SizedBox(height: 10),
                        Text(widget.skin.displayName,
                            style: AppTypography.bodyLarge.copyWith(
                                color: AppColors.paperInk, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(widget.skin.description,
                            style: AppTypography.caption.copyWith(
                                color: AppColors.paperInkSoft, fontSize: 11)),
                        const SizedBox(height: 10),
                        // price preview row
                        if (widget.skin.unlockCostCoins > 0 ||
                            widget.skin.unlockCostGems > 0)
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
                            ],
                          )
                        else
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.success,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('FREE',
                                    style: AppTypography.overline.copyWith(
                                        color: Colors.white,
                                        fontSize: 10,
                                        letterSpacing: 1.2)),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Shared helpers — stats
// ════════════════════════════════════════════════════════════════════════════

/// Speed, Glide, Shield normalized 0..1 for each plane.
/// Tuned to make Dart / Glider / Stunt Fold instantly distinct on the radar.
List<double> _statsForPlane(PlaneType p) {
  switch (p) {
    case PlaneType.dart:
      return [0.68, 0.62, 0.55];
    case PlaneType.glider:
      return [0.42, 0.96, 0.45];
    case PlaneType.stuntFold:
      return [0.88, 0.38, 0.40];
    case PlaneType.crane:
      return [0.50, 0.84, 0.78];
    case PlaneType.stealthJet:
      return [0.82, 0.58, 0.90];
  }
}

class _RadarChart extends StatelessWidget {
  const _RadarChart(
      {required this.values, this.animate = true, this.small = false});
  final List<double> values; // 3 values 0..1
  final bool animate;
  final bool small;

  @override
  Widget build(BuildContext context) {
    if (animate) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) {
          final v = values.map((e) => e * t).toList();
          return CustomPaint(
              painter: _RadarPainter(v, small: small), size: Size.infinite);
        },
      );
    }
    return CustomPaint(
        painter: _RadarPainter(values, small: small), size: Size.infinite);
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.values, {this.small = false});
  final List<double> values;
  final bool small;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + (small ? 2 : 4);
    final r = math.min(size.width, size.height) * 0.42;
    final center = Offset(cx, cy);

    // axes: top (Speed), bottom-right (Glide), bottom-left (Shield)
    const angles = [
      -math.pi / 2, // top
      math.pi / 6, // bottom right 30deg
      5 * math.pi / 6, // bottom left 150deg
    ];

    // grid triangles
    final gridPaint = Paint()
      ..color = AppColors.paperInk.withOpacity(small ? 0.10 : 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = small ? 0.8 : 1.0;
    for (final frac in [0.33, 0.66, 1.0]) {
      final path = Path();
      for (var i = 0; i < 3; i++) {
        final a = angles[i];
        final p = Offset(cx + math.cos(a) * r * frac,
            cy + math.sin(a) * r * frac);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // axes lines
    final axisPaint = Paint()
      ..color = AppColors.paperInk.withOpacity(0.18)
      ..strokeWidth = 0.9;
    for (final a in angles) {
      final end = Offset(cx + math.cos(a) * r, cy + math.sin(a) * r);
      canvas.drawLine(center, end, axisPaint);
    }

    // data polygon
    final dataPath = Path();
    for (var i = 0; i < 3; i++) {
      final v = values[i].clamp(0.0, 1.0);
      final a = angles[i];
      final p = Offset(
          cx + math.cos(a) * r * v, cy + math.sin(a) * r * v);
      if (i == 0) {
        dataPath.moveTo(p.dx, p.dy);
      } else {
        dataPath.lineTo(p.dx, p.dy);
      }
    }
    dataPath.close();

    // fill
    final fill = Paint()
      ..color = const Color(0xFFF5A623).withOpacity(0.26)
      ..style = PaintingStyle.fill;
    canvas.drawPath(dataPath, fill);

    // stroke
    final stroke = Paint()
      ..color = const Color(0xFFF5A623)
      ..style = PaintingStyle.stroke
      ..strokeWidth = small ? 1.6 : 2.4
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(dataPath, stroke);

    // dots
    for (var i = 0; i < 3; i++) {
      final v = values[i].clamp(0.0, 1.0);
      final a = angles[i];
      final p = Offset(
          cx + math.cos(a) * r * v, cy + math.sin(a) * r * v);
      final dotColor = [
        const Color(0xFFFF6B6B),
        const Color(0xFF4FC3F7),
        const Color(0xFF56CF87)
      ][i];
      canvas.drawCircle(p, small ? 3.0 : 5.0, Paint()..color = Colors.white);
      canvas.drawCircle(
          p, small ? 2.0 : 3.2, Paint()..color = dotColor);
    }

    if (small) return;
    // labels
    const labels = ['SPEED', 'GLIDE', 'SHIELD'];
    for (var i = 0; i < 3; i++) {
      final a = angles[i];
      final lp = Offset(
          cx + math.cos(a) * (r + 16), cy + math.sin(a) * (r + 14));
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            fontFamily: AppTypography.body,
            fontSize: 9.0,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
            color: AppColors.paperInk.withOpacity(0.72),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, lp - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) =>
      old.values != values || old.small != small;
}

class _AnimatedStatBar extends StatelessWidget {
  const _AnimatedStatBar(
      {required this.label, required this.value, required this.color});
  final String label;
  final double value; // 0..1
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 44,
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
        const SizedBox(width: 6),
        SizedBox(
          width: 28,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Text('${(v * 100).toStringAsFixed(0)}',
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontFamily: AppTypography.mono,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.paperInk)),
          ),
        ),
      ],
    );
  }
}

// ── Plane preview / cards ───────────────────────────────────────────────────

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
  });

  final PlaneType plane;
  final bool unlocked;
  final bool equipped;
  final bool selected;
  final bool canAfford;
  final VoidCallback onSelect;
  final VoidCallback onUnlock;
  final VoidCallback onEquip;

  @override
  Widget build(BuildContext context) {
    // Hierarchy: EQUIPPED = vibrant green outline + check badge, distinct bg
    // LOCKED = padlock badge + high-contrast purchase button
    final isLocked = !unlocked;
    final borderColor = equipped
        ? AppColors.success
        : (selected
            ? AppColors.accent.withOpacity(0.7)
            : null);
    final borderWidth = equipped ? 2.6 : 1.4;
    final bg = equipped ? const Color(0xFFE9F7EE) : AppColors.paper;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        PaperCard(
          onTap: () {
            onSelect();
            if (unlocked && !equipped) {
              // feedback: selecting also previews; equip via button
            }
          },
          color: bg,
          elevation: equipped ? 1.6 : (selected ? 1.3 : 1.0),
          padding: const EdgeInsets.all(12),
          borderColor: borderColor,
          borderWidth: borderWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PlanePreview(plane: plane, unlocked: unlocked, size: 56),
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
                                style: AppTypography.bodyLarge.copyWith(
                                  color: AppColors.paperInk,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (selected) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withOpacity(0.16),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('SELECTED',
                                    style: AppTypography.overline.copyWith(
                                        color: AppColors.accentDeep,
                                        fontSize: 8,
                                        letterSpacing: 0.9)),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          plane.tagline,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.paperInkSoft,
                            fontSize: 10.5,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 5,
                          runSpacing: 4,
                          children: plane.traitBullets
                              .map((t) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.paperWarm,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: AppColors.paperInkSoft
                                              .withOpacity(0.18)),
                                    ),
                                    child: Text(
                                      t,
                                      style: AppTypography.caption.copyWith(
                                          color: AppColors.paperInkSoft,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 7),
                        // inline mini bars for glance
                        _MiniStatRow(plane: plane),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _PlaneActionChip(
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
            ],
          ),
        ),
        // Badges overlay — unmistakable hierarchy
        if (equipped)
          Positioned(
            top: -6,
            right: -6,
            child: _CheckBadge(),
          ),
        if (isLocked)
          Positioned(
            top: -6,
            right: -6,
            child: _PadlockBadge(),
          ),
        if (equipped)
          Positioned(
            top: 8,
            left: 8,
            child: IgnorePointer(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 4,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check, size: 11, color: Colors.white),
                    const SizedBox(width: 3),
                    Text('EQUIPPED',
                        style: AppTypography.overline.copyWith(
                            color: Colors.white,
                            fontSize: 8,
                            letterSpacing: 1.0)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MiniStatRow extends StatelessWidget {
  const _MiniStatRow({required this.plane});
  final PlaneType plane;
  @override
  Widget build(BuildContext context) {
    final vals = _statsForPlane(plane);
    const labels = ['SPD', 'GLD', 'SHD'];
    const colors = [
      Color(0xFFFF6B6B),
      Color(0xFF4FC3F7),
      Color(0xFF56CF87),
    ];
    return Row(
      children: List.generate(3, (i) {
        final v = vals[i];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == 2 ? 0 : 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(labels[i],
                    style: AppTypography.overline.copyWith(
                        color: AppColors.paperInkSoft,
                        fontSize: 7,
                        letterSpacing: 0.7)),
                const SizedBox(height: 2),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Container(
                    height: 4,
                    color: AppColors.paperWarm,
                    child: FractionallySizedBox(
                      widthFactor: v,
                      alignment: Alignment.centerLeft,
                      child: Container(color: colors[i]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _PlanePreview extends StatelessWidget {
  const _PlanePreview(
      {required this.plane, required this.unlocked, this.size = 52});
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
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: AppColors.paperInk.withOpacity(0.82),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.2),
            ),
            child: const Icon(Icons.lock, size: 12, color: Colors.white),
          ),
      ],
    );
  }
}

class _PlaneMiniPainter extends CustomPainter {
  const _PlaneMiniPainter({required this.plane});
  final PlaneType plane;

  @override
  void paint(Canvas canvas, Size size) {
    final color = _colorForPlane(plane);
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;
    Path path;
    if (plane == PlaneType.glider) {
      path = Path()
        ..moveTo(w, h / 2)
        ..lineTo(w * 0.15, h * 0.08)
        ..lineTo(w * 0.28, h / 2)
        ..lineTo(w * 0.15, h * 0.92)
        ..close();
    } else if (plane == PlaneType.stealthJet) {
      path = Path()
        ..moveTo(w, h / 2)
        ..lineTo(w * 0.35, h * 0.12)
        ..lineTo(w * 0.22, h / 2)
        ..lineTo(w * 0.35, h * 0.88)
        ..close();
    } else if (plane == PlaneType.crane) {
      path = Path()
        ..moveTo(w, h / 2)
        ..lineTo(w * 0.05, h * 0.15)
        ..lineTo(w * 0.32, h / 2)
        ..lineTo(w * 0.05, h * 0.85)
        ..close();
    } else {
      path = Path()
        ..moveTo(w, h / 2)
        ..lineTo(0, 0)
        ..lineTo(w * 0.25, h / 2)
        ..lineTo(0, h)
        ..close();
    }
    canvas.drawPath(path, paint);
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
    }
  }

  @override
  bool shouldRepaint(_PlaneMiniPainter old) => old.plane != plane;
}

// ── Showcase painters ───────────────────────────────────────────────────────

class _PlaneShowcasePainter extends CustomPainter {
  _PlaneShowcasePainter({required this.plane, this.tint});
  final PlaneType plane;
  final Color? tint;

  @override
  void paint(Canvas canvas, Size size) {
    final color = tint ?? _colorForPlane(plane);
    final w = size.width;
    final h = size.height;
    // soft ambient shadow under plane (for depth)
    final shadowPath = _pathForPlane(w, h);
    canvas.drawPath(
        shadowPath.shift(const Offset(3, 4)),
        Paint()
          ..color = Colors.black.withOpacity(0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final path = _pathForPlane(w, h);
    canvas.drawPath(path, paint);

    // top highlight fold
    final fold = Paint()
      ..color = Colors.white.withOpacity(tint != null ? 0.55 : 0.22)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(w * 0.10, h / 2), Offset(w * 0.62, h / 2), fold);

    if (tint == null) {
      final deep = _darken(color, 0.22);
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
    return Path()
      ..moveTo(w, h / 2)
      ..lineTo(0, 0)
      ..lineTo(w * 0.25, h / 2)
      ..lineTo(0, h)
      ..close();
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
    }
  }

  Color _darken(Color c, double amt) =>
      HSLColor.fromColor(c)
          .withLightness((HSLColor.fromColor(c).lightness - amt).clamp(0.0, 1.0))
          .toColor();

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
    final base = Paint()..color = Colors.black.withOpacity(unlocked ? 0.38 : 0.18);
    // origami diamond — two sharp triangles instead of soft ellipse
    final diamond = Path()
      ..moveTo(w / 2, 0)
      ..lineTo(w, h / 2)
      ..lineTo(w / 2, h)
      ..lineTo(0, h / 2)
      ..close();
    canvas.drawPath(diamond, base);
    // inner lighter fold
    final inner = Paint()..color = Colors.black.withOpacity(unlocked ? 0.22 : 0.10);
    final innerPath = Path()
      ..moveTo(w / 2, h * 0.15)
      ..lineTo(w * 0.82, h / 2)
      ..lineTo(w / 2, h * 0.85)
      ..lineTo(w * 0.18, h / 2)
      ..close();
    canvas.drawPath(innerPath, inner);
    // crease line
    canvas.drawLine(
        Offset(w * 0.22, h / 2),
        Offset(w * 0.78, h / 2),
        Paint()
          ..color = Colors.white.withOpacity(0.18)
          ..strokeWidth = 0.8);
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
    // trapezoid paper pedestal with thickness
    final topW = w * 0.78;
    final bottomW = w;
    final leftTop = (w - topW) / 2;
    final path = Path()
      ..moveTo(leftTop, 0)
      ..lineTo(leftTop + topW, 0)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    // base shadow
    canvas.drawPath(
        path.shift(const Offset(0, 2)),
        Paint()
          ..color = Colors.black.withOpacity(0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    // face
    final facePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xFFF6EEDC), const Color(0xFFE3CFA6)],
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, facePaint);
    // top sheen
    canvas.drawPath(
        Path()
          ..moveTo(leftTop, 0)
          ..lineTo(leftTop + topW, 0)
          ..lineTo(leftTop + topW - 6, 3)
          ..lineTo(leftTop + 6, 3)
          ..close(),
        Paint()..color = Colors.white.withOpacity(0.55));
    // edge line
    canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF2A3354).withOpacity(0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _SpotlightPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // warm conical beam from top center down
    final beam = Path()
      ..moveTo(size.width * 0.5 - 18, 0)
      ..lineTo(size.width * 0.5 + 18, 0)
      ..lineTo(size.width * 0.78, size.height * 0.78)
      ..lineTo(size.width * 0.22, size.height * 0.78)
      ..close();
    canvas.drawPath(
        beam,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withOpacity(0.18),
              Colors.white.withOpacity(0.06),
              Colors.transparent,
            ],
          ).createShader(Offset.zero & size));

    // radial glow at center
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withOpacity(0.14),
          Colors.transparent,
        ],
      ).createShader(
          Rect.fromCircle(center: Offset(size.width * 0.5, size.height * 0.42), radius: 120));
    canvas.drawCircle(
        Offset(size.width * 0.5, size.height * 0.42), 120, glow);

    // vignette
    final vig = Paint()
      ..shader = RadialGradient(
        colors: [Colors.transparent, Colors.black.withOpacity(0.22)],
        stops: const [0.65, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vig);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _GrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final p = Paint()..color = Colors.white.withOpacity(0.5);
    for (var i = 0; i < 120; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), rnd.nextDouble() * 0.6 + 0.2, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Badges ───────────────────────────────────────────────────────────────────

class _EquippedPill extends StatelessWidget {
  const _EquippedPill();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.success,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: AppColors.success.withOpacity(0.45),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text('EQUIPPED',
              style: AppTypography.overline.copyWith(
                  color: Colors.white, fontSize: 9, letterSpacing: 1.0)),
        ],
      ),
    );
  }
}

class _LockedPill extends StatelessWidget {
  const _LockedPill();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock, size: 10, color: Colors.white.withOpacity(0.85)),
          const SizedBox(width: 4),
          Text('LOCKED',
              style: AppTypography.overline.copyWith(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 9,
                  letterSpacing: 1.0)),
        ],
      ),
    );
  }
}

class _CheckBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: AppColors.success,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.22),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: const Icon(Icons.check, size: 16, color: Colors.white),
    );
  }
}

class _PadlockBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: AppColors.paperInk,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.92), width: 1.8),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.28),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: const Icon(Icons.lock, size: 14, color: Colors.white),
    );
  }
}

// ── Skins card ───────────────────────────────────────────────────────────────

class _SkinCard extends StatelessWidget {
  const _SkinCard({
    required this.skin,
    required this.unlocked,
    required this.equipped,
    required this.selected,
    required this.canAfford,
    required this.onSelect,
    required this.onUnlock,
    required this.onEquip,
  });

  final PaperSkin skin;
  final bool unlocked;
  final bool equipped;
  final bool selected;
  final bool canAfford;
  final VoidCallback onSelect;
  final VoidCallback onUnlock;
  final VoidCallback onEquip;

  @override
  Widget build(BuildContext context) {
    final isLocked = !unlocked;
    final borderColor = equipped
        ? AppColors.success
        : (selected ? AppColors.accent.withOpacity(0.7) : null);
    final borderWidth = equipped ? 2.6 : 1.4;
    final bg = equipped ? const Color(0xFFE9F7EE) : AppColors.paper;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        PaperCard(
          onTap: onSelect,
          color: bg,
          elevation: equipped ? 1.6 : (selected ? 1.3 : 1.0),
          padding: const EdgeInsets.all(12),
          borderColor: borderColor,
          borderWidth: borderWidth,
          child: Row(
            children: [
              _SkinSwatch(skin: skin, unlocked: unlocked, compact: true),
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
                            style: AppTypography.bodyLarge.copyWith(
                                color: AppColors.paperInk, fontSize: 14),
                          ),
                        ),
                        if (selected) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(0.16),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('SELECTED',
                                style: AppTypography.overline.copyWith(
                                    color: AppColors.accentDeep,
                                    fontSize: 8,
                                    letterSpacing: 0.9)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      skin.description,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.paperInkSoft, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _SkinActionChip(
                unlocked: unlocked,
                equipped: equipped,
                costCoins: skin.unlockCostCoins,
                costGems: skin.unlockCostGems,
                canAfford: canAfford,
                onUnlock: onUnlock,
                onEquip: onEquip,
              ),
            ],
          ),
        ),
        if (equipped)
          Positioned(top: -6, right: -6, child: _CheckBadge()),
        if (isLocked)
          Positioned(top: -6, right: -6, child: _PadlockBadge()),
        if (equipped)
          Positioned(
            top: 8,
            left: 8,
            child: IgnorePointer(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 4,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check, size: 11, color: Colors.white),
                    const SizedBox(width: 3),
                    Text('EQUIPPED',
                        style: AppTypography.overline.copyWith(
                            color: Colors.white,
                            fontSize: 8,
                            letterSpacing: 1.0)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SkinSwatch extends StatelessWidget {
  const _SkinSwatch(
      {required this.skin, required this.unlocked, this.compact = false});
  final PaperSkin skin;
  final bool unlocked;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final w = compact ? 52.0 : 52.0;
    final h = compact ? 38.0 : 38.0;
    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(
          opacity: unlocked ? 1.0 : 0.42,
          child: Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              color: Color(skin.baseColorHex),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 6,
                    offset: const Offset(0, 2))
              ],
            ),
            child: CustomPaint(painter: _SkinPatternPainter(skin: skin)),
          ),
        ),
        if (!unlocked)
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: AppColors.paperInk.withOpacity(0.84),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.1),
            ),
            child: const Icon(Icons.lock, size: 11, color: Colors.white),
          ),
      ],
    );
  }
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
          ..color = const Color(0xFF5D4037).withOpacity(0.28)
          ..strokeWidth = 1;
        for (double y = 6; y < size.height - 4; y += 4) {
          canvas.drawLine(Offset(4, y), Offset(size.width - 4, y), p);
        }
        break;
      case PaperSkin.graphPaper:
        final p = Paint()
          ..color = const Color(0xFF0288D1).withOpacity(0.35)
          ..strokeWidth = 0.6;
        for (double x = 6; x < size.width; x += 8) {
          canvas.drawLine(Offset(x, 3), Offset(x, size.height - 3), p);
        }
        for (double y = 5; y < size.height; y += 8) {
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
        // Full-fill rainbow gradient + diagonal shimmer + sparkle dots
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
        // white shimmer sweep
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
        // sparkle dots
        final sp = Paint()..color = Colors.white.withOpacity(0.9);
        for (final offset in [
          Offset(size.width * 0.2, size.height * 0.2),
          Offset(size.width * 0.7, size.height * 0.35),
          Offset(size.width * 0.45, size.height * 0.72),
        ]) {
          canvas.drawCircle(offset, 1.8, sp);
          canvas.drawLine(Offset(offset.dx - 4, offset.dy), Offset(offset.dx + 4, offset.dy), sp..strokeWidth = 0.8..style = PaintingStyle.stroke);
          canvas.drawLine(Offset(offset.dx, offset.dy - 4), Offset(offset.dx, offset.dy + 4), sp);
        }
        break;
      case PaperSkin.watercolorWash:
        final wash = Paint()
          ..color = const Color(0xFF4FC3F7).withOpacity(0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        canvas.drawCircle(
            Offset(size.width * 0.5, size.height * 0.5), 10, wash);
        canvas.drawCircle(
            Offset(size.width * 0.35, size.height * 0.4), 6, wash);
        break;
      case PaperSkin.goldLeaf:
        final g = Paint()..color = const Color(0xFFFFD700).withOpacity(0.35);
        canvas.drawCircle(
            Offset(size.width * 0.3, size.height * 0.45), 2.5, g);
        canvas.drawCircle(
            Offset(size.width * 0.6, size.height * 0.55), 2.0, g);
        canvas.drawCircle(
            Offset(size.width * 0.5, size.height * 0.3), 1.6, g);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _SkinPatternPainter old) => old.skin != skin;
}

// ── Action chips — hierarchy ────────────────────────────────────────────────

class _PlaneActionChip extends StatelessWidget {
  const _PlaneActionChip({
    required this.unlocked,
    required this.equipped,
    required this.costCoins,
    required this.costGems,
    required this.canAfford,
    required this.onUnlock,
    required this.onEquip,
  });
  final bool unlocked;
  final bool equipped;
  final int costCoins;
  final int costGems;
  final bool canAfford;
  final VoidCallback onUnlock;
  final VoidCallback onEquip;

  @override
  Widget build(BuildContext context) {
    if (equipped) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.success,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.2),
          boxShadow: [
            BoxShadow(
                color: AppColors.success.withOpacity(0.35),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check, size: 14, color: Colors.white),
            const SizedBox(width: 4),
            Text('EQUIPPED',
                style: AppTypography.label.copyWith(
                    color: Colors.white, fontSize: 11, letterSpacing: 0.6)),
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
    // Locked — high-contrast coin button + padlock hint
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _HighContrastPurchaseButton(
          costCoins: costCoins,
          costGems: costGems,
          canAfford: canAfford,
          onUnlock: onUnlock,
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock,
                size: 10, color: AppColors.paperInkSoft.withOpacity(0.7)),
            const SizedBox(width: 3),
            Text('LOCKED',
                style: AppTypography.overline.copyWith(
                    color: AppColors.paperInkSoft.withOpacity(0.7),
                    fontSize: 8,
                    letterSpacing: 0.8)),
          ],
        ),
      ],
    );
  }
}

class _SkinActionChip extends StatelessWidget {
  const _SkinActionChip({
    required this.unlocked,
    required this.equipped,
    required this.costCoins,
    required this.costGems,
    required this.canAfford,
    required this.onUnlock,
    required this.onEquip,
  });
  final bool unlocked;
  final bool equipped;
  final int costCoins;
  final int costGems;
  final bool canAfford;
  final VoidCallback onUnlock;
  final VoidCallback onEquip;

  @override
  Widget build(BuildContext context) {
    if (equipped) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.success,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.2),
          boxShadow: [
            BoxShadow(
                color: AppColors.success.withOpacity(0.35),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check, size: 14, color: Colors.white),
            const SizedBox(width: 4),
            Text('EQUIPPED',
                style: AppTypography.label.copyWith(
                    color: Colors.white, fontSize: 11, letterSpacing: 0.6)),
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
    if (costCoins == 0 && costGems == 0) {
      return PaperButton(
        label: 'Free',
        compact: true,
        color: AppColors.success,
        textColor: Colors.white,
        onPressed: onUnlock,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _HighContrastPurchaseButton(
          costCoins: costCoins,
          costGems: costGems,
          canAfford: canAfford,
          onUnlock: onUnlock,
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock,
                size: 10, color: AppColors.paperInkSoft.withOpacity(0.7)),
            const SizedBox(width: 3),
            Text('LOCKED',
                style: AppTypography.overline.copyWith(
                    color: AppColors.paperInkSoft.withOpacity(0.7),
                    fontSize: 8,
                    letterSpacing: 0.8)),
          ],
        ),
      ],
    );
  }
}

/// High-contrast dark purchase button with coin/gem chips inside.
/// Meets the spec: “high-contrast purchase button (`1,000 ●`)” for locked items.
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
            color: canAfford ? AppColors.paperInk : AppColors.paperInk.withOpacity(0.55),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: canAfford
                    ? AppColors.coinGold.withOpacity(0.9)
                    : Colors.white.withOpacity(0.22),
                width: 1.4),
            boxShadow: canAfford
                ? [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.22),
                        blurRadius: 6,
                        offset: const Offset(0, 3)),
                  ]
                : null,
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
                PaperIcon(PaperIconData.gem, size: 12, color: AppColors.gemBlue),
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
