import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_routes.dart';
import '../core/enums/game_enums.dart';
import '../models/trial_definition.dart';
import '../providers/game_session_provider.dart';
import 'game_screen.dart';

/// Route args for the trial results screen.
class TrialResultArgs {
  const TrialResultArgs({this.outcome});
  final TrialOutcome? outcome;
}

/// Results screen shown after a Precision Trial finishes — stars, stats,
/// retry / next-trial / menu actions.
class TrialResultsScreen extends StatefulWidget {
  const TrialResultsScreen({super.key, required this.args});
  final TrialResultArgs args;

  @override
  State<TrialResultsScreen> createState() => _TrialResultsScreenState();
}

class _TrialResultsScreenState extends State<TrialResultsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  TrialOutcome? get _outcome => widget.args.outcome;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outcome = _outcome;
    final trial = outcome == null
        ? null
        : TrialPool.byId(outcome.trialId);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _anim, curve: Curves.easeIn),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 40),

                // ── Header ───────────────────────────────────────────────
                Text(
                  outcome == null
                      ? 'TRIAL'
                      : outcome.completed
                          ? 'COURSE COMPLETE'
                          : outcome.timedOut
                              ? 'TIME UP'
                              : 'CRASHED',
                  style: TextStyle(
                    color: outcome?.completed == true
                        ? AppColors.success
                        : AppColors.danger,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  trial?.title ?? '',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),

                // ── Stars ───────────────────────────────────────────────
                if (outcome != null) ...[
                  _StarsRow(stars: outcome.stars, anim: _anim),
                  if (outcome.isNewBestStars) ...[
                    const SizedBox(height: 10),
                    const Text(
                      '★ NEW BEST!',
                      style: TextStyle(
                        color: AppColors.warning,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                  if (!outcome.completed) ...[
                    const SizedBox(height: 10),
                    Text(
                      outcome.timedOut
                          ? 'The clock ran out — fly faster!'
                          : 'One touch ends the run — try again!',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),

                  // ── Stats card ────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      children: [
                        _StatRow(
                          label: 'Time',
                          value:
                              '${outcome.timeUsedSeconds.toStringAsFixed(1)} s',
                        ),
                        const Divider(color: AppColors.divider, height: 18),
                        _StatRow(
                          label: 'Coins',
                          value:
                              '${outcome.coinsCollected}/${outcome.totalCoins}',
                          valueColor: AppColors.coinGold,
                        ),
                        if (trial?.parSeconds != null) ...[
                          const Divider(color: AppColors.divider, height: 18),
                          _StatRow(
                            label: 'Par',
                            value:
                                '${trial!.parSeconds!.toStringAsFixed(0)} s',
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                const Spacer(),

                // ── Actions ─────────────────────────────────────────────
                if (trial != null) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _retry(trial),
                      child: const Text('FLY AGAIN'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _GhostButton(
                          label: 'MENU',
                          onTap: () => Navigator.of(context)
                              .pushReplacementNamed(AppRoutes.trials),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _GhostButton(
                          label: 'TRIALS',
                          onTap: () => Navigator.of(context)
                              .pushReplacementNamed(AppRoutes.trials),
                        ),
                      ),
                    ],
                  ),
                  // Next course unlocks with a star on this one.
                  if (outcome?.completed == true && outcome!.stars >= 1) ...[
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => _nextTrial(trial),
                      child: const Text(
                        'NEXT TRIAL →',
                        style: TextStyle(
                          color: AppColors.gemBlue,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _retry(TrialDefinition trial) {
    Navigator.of(context).pushReplacementNamed(
      AppRoutes.game,
      arguments: GameScreenArgs(mode: GameMode.trial, trialId: trial.id),
    );
  }

  void _nextTrial(TrialDefinition trial) {
    final next = TrialPool.byId(trial.id + 1);
    if (next == null) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.trials);
      return;
    }
    Navigator.of(context).pushReplacementNamed(
      AppRoutes.game,
      arguments: GameScreenArgs(mode: GameMode.trial, trialId: next.id),
    );
  }
}

class _StarsRow extends StatelessWidget {
  const _StarsRow({required this.stars, required this.anim});
  final int stars;
  final Animation<double> anim;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int s = 1; s <= 3; s++)
          ScaleTransition(
            scale: Tween<double>(begin: 0, end: 1).animate(
              CurvedAnimation(
                parent: anim,
                curve: Interval(
                  (s - 1) * 0.22,
                  0.2 + s * 0.22,
                  curve: Curves.elasticOut,
                ),
              ),
            ),
            child: Icon(
              s <= stars ? Icons.star : Icons.star_border,
              size: 54,
              color: s <= stars ? AppColors.warning : AppColors.divider,
            ),
          ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppColors.textLight,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textLight,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}
