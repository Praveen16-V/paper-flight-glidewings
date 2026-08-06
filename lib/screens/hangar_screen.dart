import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/enums/game_enums.dart';
import '../providers/save_data_provider.dart';
import '../services/analytics_service.dart';

/// Plane hangar — browse, unlock (spend coins), and equip the 3 MVP planes.
class HangarScreen extends ConsumerWidget {
  const HangarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final save = ref.watch(saveDataProvider);
    final notifier = ref.read(saveDataProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textLight,
        elevation: 0,
        title: const Text('Hangar',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                const Text('●',
                    style: TextStyle(color: AppColors.coinGold, fontSize: 12)),
                const SizedBox(width: 4),
                Text(
                  '${save.coins}',
                  style: const TextStyle(
                    color: AppColors.coinGold,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: PlaneType.values.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final plane = PlaneType.values[index];
          final unlocked = notifier.isPlaneUnlocked(index);
          final equipped = save.equippedPlaneIndex == index;

          return _PlaneCard(
            plane: plane,
            unlocked: unlocked,
            equipped: equipped,
            canAfford: save.coins >= plane.unlockCost,
            onUnlock: () async {
              final success =
                  await notifier.unlockPlane(index, plane.unlockCost);
              if (success && context.mounted) {
                AnalyticsService.instance
                    .logPlaneUnlocked(plane.assetName);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${plane.displayName} unlocked!'),
                    backgroundColor: AppColors.success,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            onEquip: () => notifier.equipPlane(index),
          );
        },
      ),
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: equipped ? AppColors.accent : AppColors.divider,
          width: equipped ? 2 : 1,
        ),
        boxShadow: equipped
            ? [
                BoxShadow(
                  color: AppColors.accent.withOpacity(0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // ── Plane preview ────────────────────────────────────────────
            _PlanePreview(
              plane: plane,
              unlocked: unlocked,
            ),
            const SizedBox(width: 12),

            // ── Info ─────────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + equipped badge — badge wraps below if no room
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Text(
                        plane.displayName,
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (equipped)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'EQUIPPED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _StatBadge(
                    label: 'Turn',
                    value: plane.turnSpeedMultiplier,
                  ),
                  const SizedBox(height: 3),
                  _StatBadge(
                    label: 'Fall',
                    value: plane.fallSpeedMultiplier,
                  ),
                ],
              ),
            ),

            // ── Action ───────────────────────────────────────────────────
            const SizedBox(width: 8),
            _ActionChip(
              unlocked: unlocked,
              equipped: equipped,
              cost: plane.unlockCost,
              canAfford: canAfford,
              onUnlock: onUnlock,
              onEquip: onEquip,
            ),
          ],
        ),
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
        size: const Size(56, 38),
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

    final path = Path()
      ..moveTo(w, h / 2)
      ..lineTo(0, 0)
      ..lineTo(w * 0.25, h / 2)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(path, paint);

    // Wing fold line
    final foldPaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
        Offset(w * 0.08, h / 2), Offset(w * 0.65, h / 2), foldPaint);
  }

  Color _colorForPlane(PlaneType p) {
    switch (p) {
      case PlaneType.dart:
        return AppColors.accent;
      case PlaneType.glider:
        return AppColors.accentAlt;
      case PlaneType.stuntFold:
        return AppColors.danger;
    }
  }

  @override
  bool shouldRepaint(_PlaneMiniPainter old) => old.plane != plane;
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({required this.label, required this.value});
  final String label;
  final double value; // 1.0 = baseline

  @override
  Widget build(BuildContext context) {
    final delta = value - 1.0;
    final positive = delta >= 0;
    final display = delta == 0
        ? 'Baseline'
        : '${positive ? '+' : ''}${(delta * 100).toStringAsFixed(0)}%';

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 3,
      children: [
        Text(
          '$label:',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
        Text(
          display,
          style: TextStyle(
            color: delta == 0
                ? AppColors.textMuted
                : (positive ? AppColors.success : AppColors.warning),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.unlocked,
    required this.equipped,
    required this.cost,
    required this.canAfford,
    required this.onUnlock,
    required this.onEquip,
  });
  final bool unlocked;
  final bool equipped;
  final int cost;
  final bool canAfford;
  final VoidCallback onUnlock;
  final VoidCallback onEquip;

  @override
  Widget build(BuildContext context) {
    if (equipped) {
      return const SizedBox(width: 80);
    }

    if (unlocked) {
      return GestureDetector(
        onTap: onEquip,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.accentAlt.withOpacity(0.15),
            border: Border.all(color: AppColors.accentAlt),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Equip',
            style: TextStyle(
              color: AppColors.accentAlt,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: canAfford ? onUnlock : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: canAfford ? 1.0 : 0.4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.coinGold.withOpacity(0.12),
            border: Border.all(color: AppColors.coinGold),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('●',
                  style:
                      TextStyle(color: AppColors.coinGold, fontSize: 10)),
              Text(
                '$cost',
                style: const TextStyle(
                  color: AppColors.coinGold,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
