import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_typography.dart';
import '../core/enums/game_enums.dart';
import '../core/widgets/currency_chip.dart';
import '../core/widgets/paper_button.dart';
import '../core/widgets/paper_card.dart';
import '../providers/save_data_provider.dart';
import '../services/analytics_service.dart';

/// Hangar — browse, unlock and equip planes + paper skins.
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
        body: TabBarView(
          children: [
            _PlanesTab(),
            _SkinsTab(),
          ],
        ),
      ),
    );
  }
}

// ── Planes Tab ────────────────────────────────────────────────────────────────

class _PlanesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final save = ref.watch(saveDataProvider);
    final notifier = ref.read(saveDataProvider.notifier);

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: PlaneType.values.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final plane = PlaneType.values[index];
        final unlocked = notifier.isPlaneUnlocked(index);
        final equipped = save.equippedPlaneIndex == index;
        final canAffordCoins = save.coins >= plane.unlockCost;
        final canAffordGems = save.gems >= plane.unlockGemCost;
        final canAfford = canAffordCoins && canAffordGems;

        return _PlaneCard(
          plane: plane,
          unlocked: unlocked,
          equipped: equipped,
          canAfford: canAfford,
          onUnlock: () async {
            final success = await notifier.unlockPlane(
              index,
              plane.unlockCost,
              gemCost: plane.unlockGemCost,
            );
            if (success && context.mounted) {
              AnalyticsService.instance.logPlaneUnlocked(plane.assetName);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${plane.displayName} unlocked!'),
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
          onEquip: () => notifier.equipPlane(index),
        );
      },
    );
  }
}

class _PlaneCard extends StatelessWidget {
  const _PlaneCard({
    required this.plane,
    required this.unlocked,
    required this.equipped,
    required this.canAfford,
    required this.onUnlock,
    required this.onEquip,
  });

  final PlaneType plane;
  final bool unlocked;
  final bool equipped;
  final bool canAfford;
  final VoidCallback onUnlock;
  final VoidCallback onEquip;

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      onTap: unlocked && !equipped ? onEquip : null,
      color: equipped ? AppColors.paperGold : AppColors.paper,
      elevation: equipped ? 1.5 : 1.0,
      padding: const EdgeInsets.all(14),
      borderColor: equipped ? AppColors.accent : null,
      dogEar: equipped
          ? const DogEar(label: 'OWNED', color: AppColors.accent, size: 56)
          : (!unlocked && plane.unlockGemCost > 0
              ? const DogEar(
                  label: 'PRO', color: AppColors.gemBlue, size: 56)
              : null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PlanePreview(plane: plane, unlocked: unlocked),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Text(
                          plane.displayName,
                          style: AppTypography.bodyLarge.copyWith(
                            color: AppColors.paperInk,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      plane.tagline,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.paperInkSoft,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: plane.traitBullets
                          .map((t) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.paperWarm,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: AppColors.paperInkSoft
                                          .withOpacity(0.25)),
                                ),
                                child: Text(
                                  t,
                                  style: AppTypography.caption.copyWith(
                                      color: AppColors.paperInkSoft,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700),
                                ),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _StatBadge(
                            label: 'Turn', value: plane.turnSpeedMultiplier),
                        const SizedBox(width: 10),
                        _StatBadge(
                            label: 'Fall', value: plane.fallSpeedMultiplier),
                        const SizedBox(width: 10),
                        _PowerUpBadge(plane: plane),
                      ],
                    ),
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
    );
  }
}

class _PlanePreview extends StatelessWidget {
  const _PlanePreview({required this.plane, required this.unlocked});
  final PlaneType plane;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: unlocked ? 1.0 : 0.35,
      child: CustomPaint(
        size: const Size(56, 44),
        painter: _PlaneMiniPainter(plane: plane),
      ),
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

    // Variant silhouettes for visual distinction
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

    // Wing fold line + variant accent
    final foldPaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(w * 0.08, h / 2), Offset(w * 0.65, h / 2), foldPaint);

    // Crane has a subtle neck fold hint
    if (plane == PlaneType.crane) {
      final neckPaint = Paint()
        ..color = Colors.white.withOpacity(0.18)
        ..strokeWidth = 0.9
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(w * 0.45, h * 0.3), Offset(w * 0.45, h * 0.7), neckPaint);
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
        return const Color(0xFF81C784); // crane green/organic
      case PlaneType.stealthJet:
        return const Color(0xFF90A4AE); // stealth grey
    }
  }

  @override
  bool shouldRepaint(_PlaneMiniPainter old) => old.plane != plane;
}

// ── Skins Tab ─────────────────────────────────────────────────────────────────

class _SkinsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final save = ref.watch(saveDataProvider);
    final notifier = ref.read(saveDataProvider.notifier);

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: PaperSkin.values.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final skin = PaperSkin.values[index];
        final unlocked = notifier.isSkinUnlocked(index);
        final equipped = save.equippedSkinIndex == index;
        final canAffordCoins = save.coins >= skin.unlockCostCoins;
        final canAffordGems = save.gems >= skin.unlockCostGems;
        final canAfford = canAffordCoins && canAffordGems;

        return _SkinCard(
          skin: skin,
          unlocked: unlocked,
          equipped: equipped,
          canAfford: canAfford,
          onUnlock: () async {
            final success = await notifier.unlockSkin(index, skin.unlockCostCoins, skin.unlockCostGems);
            if (success && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${skin.displayName} unlocked!'),
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
          onEquip: () => notifier.equipSkin(index),
        );
      },
    );
  }
}

class _SkinCard extends StatelessWidget {
  const _SkinCard({
    required this.skin,
    required this.unlocked,
    required this.equipped,
    required this.canAfford,
    required this.onUnlock,
    required this.onEquip,
  });

  final PaperSkin skin;
  final bool unlocked;
  final bool equipped;
  final bool canAfford;
  final VoidCallback onUnlock;
  final VoidCallback onEquip;

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      onTap: unlocked && !equipped ? onEquip : null,
      color: equipped ? AppColors.paperGold : AppColors.paper,
      elevation: equipped ? 1.4 : 1.0,
      padding: const EdgeInsets.all(14),
      borderColor: equipped ? AppColors.accent : null,
      child: Row(
        children: [
          _SkinSwatch(skin: skin, unlocked: unlocked),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  skin.displayName,
                  style: AppTypography.bodyLarge
                      .copyWith(color: AppColors.paperInk, fontSize: 15),
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
    );
  }
}

class _SkinSwatch extends StatelessWidget {
  const _SkinSwatch({required this.skin, required this.unlocked});
  final PaperSkin skin;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: unlocked ? 1.0 : 0.45,
      child: Container(
        width: 52,
        height: 38,
        decoration: BoxDecoration(
          color: Color(skin.baseColorHex),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: CustomPaint(painter: _SkinPatternPainter(skin: skin)),
      ),
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
        final foil = Paint()
          ..shader = const LinearGradient(colors: [Color(0xFFE040FB), Color(0xFF00E5FF), Color(0xFF76FF03)])
              .createShader(Rect.fromLTWH(0, 0, size.width, size.height))
          ..style = PaintingStyle.fill;
        canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(4, 6, size.width - 8, size.height - 12), const Radius.circular(4)), foil);
        break;
      case PaperSkin.watercolorWash:
        final wash = Paint()
          ..color = const Color(0xFF4FC3F7).withOpacity(0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.5), 10, wash);
        canvas.drawCircle(Offset(size.width * 0.35, size.height * 0.4), 6, wash);
        break;
      case PaperSkin.goldLeaf:
        final g = Paint()..color = const Color(0xFFFFD700).withOpacity(0.35);
        canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.45), 2.5, g);
        canvas.drawCircle(Offset(size.width * 0.6, size.height * 0.55), 2.0, g);
        canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.3), 1.6, g);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _SkinPatternPainter old) => old.skin != skin;
}

// ── Shared Sub-widgets ────────────────────────────────────────────────────────

class _StatBadge extends StatelessWidget {
  const _StatBadge({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final delta = value - 1.0;
    final positive = delta >= 0;
    final display = delta == 0
        ? 'Baseline'
        : '${positive ? '+' : ''}${(delta * 100).toStringAsFixed(0)}%';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label:',
            style: AppTypography.caption
                .copyWith(color: AppColors.paperInkSoft, fontSize: 11)),
        const SizedBox(width: 3),
        Text(display,
            style: AppTypography.caption.copyWith(
              color: delta == 0
                  ? AppColors.paperInkSoft
                  : (positive ? AppColors.success : AppColors.warning),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            )),
      ],
    );
  }
}

class _PowerUpBadge extends StatelessWidget {
  const _PowerUpBadge({required this.plane});
  final PlaneType plane;

  @override
  Widget build(BuildContext context) {
    final text = plane.signatureActionLabel;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Power:',
            style: AppTypography.caption
                .copyWith(color: AppColors.paperInkSoft, fontSize: 11)),
        const SizedBox(width: 3),
        Text(text,
            style: AppTypography.caption.copyWith(
                color: AppColors.accentDeep,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}

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
    if (equipped) return const SizedBox(width: 76);
    if (unlocked) {
      return PaperButton(
        label: 'Equip',
        compact: true,
        color: AppColors.accentAlt,
        textColor: Colors.white,
        onPressed: onEquip,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Opacity(
          opacity: canAfford ? 1 : 0.45,
          child: PaperButton(
            label: 'Unlock',
            compact: true,
            onPressed: canAfford ? onUnlock : null,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CoinChip(costCoins, iconSize: 11, fontSize: 11, spacing: 3),
            if (costGems > 0) ...[
              const SizedBox(width: 6),
              GemChip(costGems, iconSize: 10, fontSize: 11, spacing: 3),
            ],
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
    if (equipped) return const SizedBox(width: 76);
    if (unlocked) {
      return PaperButton(
        label: 'Equip',
        compact: true,
        color: AppColors.accentAlt,
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
        Opacity(
          opacity: canAfford ? 1 : 0.45,
          child: PaperButton(
            label: 'Unlock',
            compact: true,
            onPressed: canAfford ? onUnlock : null,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (costCoins > 0) ...[
              CoinChip(costCoins, iconSize: 11, fontSize: 11, spacing: 3),
            ],
            if (costGems > 0) ...[
              if (costCoins > 0) const SizedBox(width: 6),
              GemChip(costGems, iconSize: 10, fontSize: 11, spacing: 3),
            ],
          ],
        ),
      ],
    );
  }
}
