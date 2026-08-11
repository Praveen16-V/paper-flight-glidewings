import 'dart:async';
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
import '../models/save_data.dart';
import '../providers/save_data_provider.dart';
import '../services/ad_service.dart';
import '../services/analytics_service.dart';
import '../services/iap_service.dart';

/// Shop screen — IAP products + rewarded-ad earn flows.
/// Now with merchandising ribbons and illustrative paper chests/crates.
class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  StreamSubscription<PurchaseEvent>? _purchaseSub;
  Timer? _seasonalTicker;
  DateTime _seasonalNow = DateTime.now();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _purchaseSub = IapService.instance.purchaseStream.listen(_onPurchaseEvent);
    // Shop countdowns are calendar-facing, so refresh once a second without
    // touching game-loop state or any persistence.
    _seasonalTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seasonalNow = DateTime.now());
    });
    AnalyticsService.instance.logScreenView('shop');
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    _seasonalTicker?.cancel();
    super.dispose();
  }

  void _onPurchaseEvent(PurchaseEvent event) async {
    if (!mounted) return;
    setState(() => _loading = false);

    switch (event.type) {
      case PurchaseEventType.completed:
        await _deliverProduct(event.productId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Purchase complete!'),
            backgroundColor: AppColors.success,
          ));
        }
      case PurchaseEventType.failed:
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Purchase failed. Please try again.'),
            backgroundColor: AppColors.danger,
          ));
        }
      case PurchaseEventType.cancelled:
        break;
    }
  }

  Future<void> _deliverProduct(String productId) async {
    final notifier = ref.read(saveDataProvider.notifier);
    switch (productId) {
      case IapProductIds.removeAds:
        await notifier.setAdsRemoved();
      case IapProductIds.coins1000:
        await notifier.addCoins(1000, reason: 'iap_coins_1000');
      case IapProductIds.coins5000:
        await notifier.addCoins(5000, reason: 'iap_coins_5000');
      case IapProductIds.gems50:
        await notifier.addGems(50, reason: 'iap_gems_50');
      case IapProductIds.starterPack:
        await notifier.addCoins(500, reason: 'iap_starter_pack');
        await notifier.addGems(25, reason: 'iap_starter_pack');
        await notifier.setAdsRemoved();
      case IapProductIds.planeBundle:
        for (int i = 0; i < 3; i++) {
          await notifier.unlockPlane(i, 0);
        }
    }
    AnalyticsService.instance.logEvent('iap_delivered', params: {'product_id': productId});
  }

  void _buy(String productId) {
    setState(() => _loading = true);
    IapService.instance.buy(productId);
  }

  Future<void> _unlockSeasonalSkin(PaperSkin skin) async {
    final availability = skin.seasonalAvailability;
    if (availability == null || !availability.isAvailableOn(_seasonalNow)) {
      return;
    }
    final success = await ref.read(saveDataProvider.notifier).unlockSkin(
          skin.index,
          skin.unlockCostCoins,
          skin.unlockCostGems,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(success
          ? '${skin.displayName} unlocked!'
          : 'Not enough coins or gems.'),
      backgroundColor: success ? AppColors.success : AppColors.danger,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final save = ref.watch(saveDataProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.surfaceAlt, AppColors.background],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _TitleBar(coins: save.coins, gems: save.gems),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                    : ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          if (!save.adsRemoved) ...[
                            _SectionHeader(title: 'Ad-Free'),
                            const SizedBox(height: 12),
                            _IllustratedShopCard(
                              title: 'Remove Ads',
                              description: 'No more interstitials. Ever. Rewarded ads remain optional.',
                              sheet: AppColors.paperGreen,
                              priceLabel: _priceFor(IapProductIds.removeAds),
                              ribbon: const _RibbonTag(label: 'MOST POPULAR', color: Color(0xFF56CF87)),
                              illustration: const _IllustratedChest(kind: ChestKind.shield, accent: AppColors.success),
                              onTap: () => _buy(IapProductIds.removeAds),
                            ),
                            const SizedBox(height: 24),
                          ] else ...[
                            _SectionHeader(title: 'Ad-Free'),
                            const SizedBox(height: 12),
                            PaperCard(
                              color: AppColors.paperGreen,
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withOpacity(0.18),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.check_circle_rounded,
                                        color: AppColors.success, size: 26),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Ads Removed',
                                            style: AppTypography.bodyLarge.copyWith(
                                                color: AppColors.paperInk, fontSize: 15)),
                                        const SizedBox(height: 2),
                                        Text('You\'re flying ad-free. Thank you!',
                                            style: AppTypography.caption.copyWith(
                                                color: AppColors.paperInkSoft)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                          _SectionHeader(title: 'Deals'),
                          const SizedBox(height: 12),
                          _IllustratedShopCard(
                            title: 'Starter Pack',
                            description: '500 coins + 25 gems + Remove Ads. One-time offer.',
                            sheet: AppColors.paperGold,
                            priceLabel: _priceFor(IapProductIds.starterPack),
                            ribbon: const _RibbonTag(label: 'STARTER PACK', color: Color(0xFFF5A623)),
                            illustration: const _IllustratedChest(kind: ChestKind.starter, accent: AppColors.warning),
                            onTap: () => _buy(IapProductIds.starterPack),
                          ),
                          const SizedBox(height: 24),
                          _SectionHeader(title: 'Seasonal Rotation'),
                          const SizedBox(height: 12),
                          _SeasonalRotationSection(
                            now: _seasonalNow,
                            save: save,
                            onUnlock: _unlockSeasonalSkin,
                          ),
                          const SizedBox(height: 24),
                          _SectionHeader(title: 'Coins'),
                          const SizedBox(height: 12),
                          _CoinPackRow(
                            packs: [
                              _CoinPack(
                                label: '1,000',
                                sublabel: 'Pocketful',
                                price: _priceFor(IapProductIds.coins1000),
                                onTap: () => _buy(IapProductIds.coins1000),
                                kind: ChestKind.coinsSmall,
                              ),
                              _CoinPack(
                                label: '5,000',
                                sublabel: 'Treasure Crate',
                                price: _priceFor(IapProductIds.coins5000),
                                bonus: '+20%',
                                ribbonLabel: 'BEST VALUE',
                                onTap: () => _buy(IapProductIds.coins5000),
                                kind: ChestKind.coinsBig,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _SectionHeader(title: 'Gems'),
                          const SizedBox(height: 12),
                          _IllustratedShopCard(
                            title: '50 Gems',
                            description: 'Premium currency. Rare unlocks.',
                            sheet: AppColors.paperBlue,
                            priceLabel: _priceFor(IapProductIds.gems50),
                            ribbon: const _RibbonTag(label: 'MOST POPULAR', color: Color(0xFF54C8EC)),
                            illustration: const _IllustratedChest(kind: ChestKind.gems, accent: AppColors.gemBlue),
                            onTap: () => _buy(IapProductIds.gems50),
                          ),
                          const SizedBox(height: 24),
                          if (!save.adsRemoved) ...[
                            _SectionHeader(title: 'Earn Free'),
                            const SizedBox(height: 12),
                            _EarnCard(
                              title: 'Mystery Chest',
                              description: 'Watch a short ad for a bonus chest.',
                              icon: Icons.card_giftcard_rounded,
                              iconColor: AppColors.accent,
                              onTap: _showMysteryChestAd,
                            ),
                            const SizedBox(height: 10),
                            _EarnCard(
                              title: 'Refill Shield',
                              description: 'Start your next run with a free shield.',
                              icon: Icons.shield_rounded,
                              iconColor: AppColors.shieldBlue,
                              onTap: _showRefillShieldAd,
                            ),
                          ],
                          const SizedBox(height: 24),
                          Center(
                            child: TextButton(
                              onPressed: IapService.instance.restorePurchases,
                              child: Text('Restore Purchases',
                                  style: AppTypography.caption.copyWith(decoration: TextDecoration.underline)),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMysteryChestAd() {
    AdService.instance.showRewarded(
      placement: AdPlacement.mysteryChest,
      onRewarded: () async {
        final coins = 50 + (DateTime.now().millisecond % 100);
        await ref
            .read(saveDataProvider.notifier)
            .addCoins(coins, reason: 'rewarded_mystery_chest');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Mystery Chest: +$coins coins!'),
            backgroundColor: AppColors.success,
          ));
        }
      },
      onDismissed: () {},
    );
  }

  void _showRefillShieldAd() {
    AdService.instance.showRewarded(
      placement: AdPlacement.refillShield,
      onRewarded: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Shield ready for your next run!'),
            backgroundColor: AppColors.shieldBlue,
          ));
        }
      },
      onDismissed: () {},
    );
  }

  String _priceFor(String productId) {
    final product = IapService.instance.productById(productId);
    return product?.priceString ?? '...';
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _TitleBar extends StatelessWidget {
  const _TitleBar({required this.coins, required this.gems});
  final int coins;
  final int gems;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textLight),
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(child: Text('Shop', style: AppTypography.headline, textAlign: TextAlign.center)),
          CoinChip(coins, iconSize: 16, fontSize: 14),
          const SizedBox(width: 10),
          GemChip(gems, iconSize: 14, fontSize: 13),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(title.toUpperCase(), style: AppTypography.overline),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withOpacity(0.10),
          ),
        ),
      ],
    );
  }
}

// ── Limited-time seasonal skin rotation ───────────────────────────────────────

class _SeasonalRotationSection extends StatelessWidget {
  const _SeasonalRotationSection({
    required this.now,
    required this.save,
    required this.onUnlock,
  });

  final DateTime now;
  final SaveData save;
  final Future<void> Function(PaperSkin skin) onUnlock;

  @override
  Widget build(BuildContext context) {
    final skins = PaperSkin.values
        .where((skin) => skin.seasonalAvailability != null)
        .toList(growable: false);
    return Column(
      children: [
        for (var i = 0; i < skins.length; i++) ...[
          _SeasonalSkinCard(
            skin: skins[i],
            now: now,
            unlocked: save.unlockedSkinIndices.contains(skins[i].index),
            canAfford: save.coins >= skins[i].unlockCostCoins &&
                save.gems >= skins[i].unlockCostGems,
            onUnlock: () {
              onUnlock(skins[i]);
            },
          ),
          if (i < skins.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _SeasonalSkinCard extends StatelessWidget {
  const _SeasonalSkinCard({
    required this.skin,
    required this.now,
    required this.unlocked,
    required this.canAfford,
    required this.onUnlock,
  });

  final PaperSkin skin;
  final DateTime now;
  final bool unlocked;
  final bool canAfford;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final availability = skin.seasonalAvailability!;
    final active = availability.isAvailableOn(now);
    final transition = active
        ? availability.activeEndsAt(now)!
        : availability.nextStartsAt(now);
    final remaining = transition.difference(now);
    final countdown = _formatSeasonalCountdown(remaining);
    final status = unlocked
        ? 'OWNED • YOURS TO KEEP'
        : (active ? 'ENDS IN $countdown' : 'RETURNS IN $countdown');
    final seasonalColor = switch (availability.rotation) {
      SeasonalRotation.halloween => const Color(0xFFFF7043),
      SeasonalRotation.winter => const Color(0xFF80D8FF),
      SeasonalRotation.lunarNewYear => const Color(0xFFFF5252),
    };

    return PaperCard(
      color: active ? AppColors.paperWarm : AppColors.paper.withOpacity(.82),
      padding: const EdgeInsets.all(12),
      borderColor: active ? seasonalColor.withOpacity(.75) : null,
      borderWidth: active ? 1.5 : 1.0,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: seasonalColor.withOpacity(active ? .18 : .08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: seasonalColor.withOpacity(.45)),
            ),
            child: Text(availability.icon, style: const TextStyle(fontSize: 25)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  skin.displayName,
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.paperInk,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  availability.displayName,
                  style: AppTypography.caption.copyWith(
                    color: seasonalColor.withOpacity(active ? 1.0 : .68),
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: AppTypography.overline.copyWith(
                    color: active
                        ? AppColors.paperInkSoft
                        : AppColors.paperInkSoft.withOpacity(.72),
                    fontSize: 8,
                    letterSpacing: .8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (unlocked)
            const Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 26)
          else
            SizedBox(
              width: 98,
              child: PaperButton(
                label: active
                    ? '${skin.unlockCostCoins} ●'
                    : 'LOCKED',
                compact: true,
                color: active ? seasonalColor : AppColors.paperInkSoft,
                textColor: Colors.white,
                semanticLabel: active
                    ? 'Unlock ${skin.displayName}'
                    : '${skin.displayName} returns in $countdown',
                onPressed: active && canAfford ? onUnlock : null,
              ),
            ),
        ],
      ),
    );
  }
}

String _formatSeasonalCountdown(Duration duration) {
  if (duration.isNegative) return 'SOON';
  if (duration.inDays > 0) {
    return '${duration.inDays}D ${duration.inHours.remainder(24)}H';
  }
  if (duration.inHours > 0) {
    return '${duration.inHours}H ${duration.inMinutes.remainder(60)}M';
  }
  return '${duration.inMinutes.remainder(60)}M ${duration.inSeconds.remainder(60)}S';
}

// ── Ribbon tag ───────────────────────────────────────────────────────────────

class _RibbonTag extends StatelessWidget {
  const _RibbonTag({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withOpacity(0.92), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.16), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Text(label,
          style: AppTypography.overline.copyWith(color: Colors.white, fontSize: 8, letterSpacing: 1.0, height: 1)),
    );
  }
}

// ── Illustrative chest kinds ────────────────────────────────────────────────

enum ChestKind { shield, starter, coinsSmall, coinsBig, gems }

class _IllustratedChest extends StatelessWidget {
  const _IllustratedChest({required this.kind, required this.accent});
  final ChestKind kind;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    // size adapts to container but we fix 56
    return SizedBox(
      width: 64,
      height: 56,
      child: CustomPaint(painter: _ChestPainter(kind: kind, accent: accent)),
    );
  }
}

class _ChestPainter extends CustomPainter {
  _ChestPainter({required this.kind, required this.accent});
  final ChestKind kind;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // shadow
    final shadow = Path()
      ..moveTo(w * 0.18, h * 0.88)
      ..lineTo(w * 0.82, h * 0.88)
      ..quadraticBezierTo(w * 0.84, h * 0.94, w * 0.80, h * 0.96)
      ..lineTo(w * 0.20, h * 0.96)
      ..quadraticBezierTo(w * 0.16, h * 0.94, w * 0.18, h * 0.88)
      ..close();
    canvas.drawPath(shadow, Paint()..color = Colors.black.withOpacity(0.18)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));

    // crate base
    final baseRect = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.12, h * 0.42, w * 0.76, h * 0.46), const Radius.circular(6));
    final wood = Paint()..color = const Color(0xFF8D6E63);
    canvas.drawRRect(baseRect, wood);
    // wood planks lines
    final plank = Paint()..color = const Color(0xFF6D4C41).withOpacity(0.55)..strokeWidth = 1;
    canvas.drawLine(Offset(w * 0.14, h * 0.58), Offset(w * 0.86, h * 0.58), plank);
    canvas.drawLine(Offset(w * 0.14, h * 0.72), Offset(w * 0.86, h * 0.72), plank);
    // metal bands
    final band = Paint()..color = accent.withOpacity(0.85)..strokeWidth = 3;
    canvas.drawLine(Offset(w * 0.12, h * 0.52), Offset(w * 0.88, h * 0.52), band);
    canvas.drawLine(Offset(w * 0.12, h * 0.78), Offset(w * 0.88, h * 0.78), band);
    // vertical studs
    for (final x in [w * 0.24, w * 0.50, w * 0.76]) {
      canvas.drawCircle(Offset(x, h * 0.52), 1.6, Paint()..color = Colors.white.withOpacity(0.85));
      canvas.drawCircle(Offset(x, h * 0.78), 1.6, Paint()..color = Colors.white.withOpacity(0.85));
    }
    // lid (open)
    final lid = Path()
      ..moveTo(w * 0.12, h * 0.42)
      ..quadraticBezierTo(w * 0.50, h * 0.08, w * 0.88, h * 0.42)
      ..lineTo(w * 0.84, h * 0.48)
      ..quadraticBezierTo(w * 0.50, h * 0.20, w * 0.16, h * 0.48)
      ..close();
    final lidPaint = Paint()..color = const Color(0xFFA1887F);
    canvas.drawPath(lid, lidPaint);
    // lid band
    final lidBand = Path()
      ..moveTo(w * 0.14, h * 0.32)
      ..quadraticBezierTo(w * 0.50, h * 0.18, w * 0.86, h * 0.32)
      ..lineTo(w * 0.86, h * 0.38)
      ..quadraticBezierTo(w * 0.50, h * 0.24, w * 0.14, h * 0.38)
      ..close();
    canvas.drawPath(lidBand, Paint()..color = accent.withOpacity(0.92));

    // overflowing contents
    switch (kind) {
      case ChestKind.shield:
        // shield icon atop chest
        _drawShield(canvas, Offset(w * 0.50, h * 0.28), 16);
        break;
      case ChestKind.starter:
        // mix coins + gems
        _drawCoin(canvas, Offset(w * 0.38, h * 0.28), 9, AppColors.coinGold);
        _drawCoin(canvas, Offset(w * 0.56, h * 0.30), 7, AppColors.coinGold);
        _drawGem(canvas, Offset(w * 0.50, h * 0.22), 11);
        break;
      case ChestKind.coinsSmall:
        _drawCoin(canvas, Offset(w * 0.42, h * 0.30), 8, AppColors.coinGold);
        _drawCoin(canvas, Offset(w * 0.58, h * 0.32), 8, AppColors.coinGold);
        _drawCoin(canvas, Offset(w * 0.50, h * 0.20), 7, AppColors.coinGold);
        break;
      case ChestKind.coinsBig:
        // crate overflowing — pile higher
        for (final o in [Offset(w * 0.30, h * 0.36), Offset(w * 0.46, h * 0.30), Offset(w * 0.62, h * 0.34), Offset(w * 0.50, h * 0.22), Offset(w * 0.38, h * 0.42), Offset(w * 0.64, h * 0.42)]) {
          _drawCoin(canvas, o, 7 + (o.dx % 3), AppColors.coinGold);
        }
        // sparkle
        _drawSparkle(canvas, Offset(w * 0.72, h * 0.18), 5);
        break;
      case ChestKind.gems:
        _drawGem(canvas, Offset(w * 0.42, h * 0.30), 10);
        _drawGem(canvas, Offset(w * 0.60, h * 0.32), 9);
        _drawGem(canvas, Offset(w * 0.50, h * 0.20), 11);
        _drawCoin(canvas, Offset(w * 0.34, h * 0.38), 5, AppColors.coinGoldDeep.withOpacity(0.9));
        break;
    }
  }

  void _drawCoin(Canvas c, Offset o, double r, Color col) {
    final deep = HSLColor.fromColor(col).withLightness((HSLColor.fromColor(col).lightness - 0.18).clamp(0.0, 1.0)).toColor();
    c.drawCircle(o.translate(1, 1.4), r, Paint()..color = Colors.black.withOpacity(0.18));
    c.drawCircle(o, r, Paint()..color = col);
    c.drawCircle(o, r * 0.62, Paint()..color = Colors.white.withOpacity(0.22)..style = PaintingStyle.stroke..strokeWidth = 1);
    c.drawCircle(o.translate(-r * 0.22, -r * 0.24), r * 0.24, Paint()..color = Colors.white.withOpacity(0.55));
    // inner edge
    c.drawCircle(o, r * 0.92, Paint()..color = deep.withOpacity(0.35)..style = PaintingStyle.stroke..strokeWidth = 0.9);
  }

  void _drawGem(Canvas c, Offset o, double s) {
    final path = Path()
      ..moveTo(o.dx, o.dy - s * 0.62)
      ..lineTo(o.dx + s * 0.56, o.dy - s * 0.08)
      ..lineTo(o.dx, o.dy + s * 0.62)
      ..lineTo(o.dx - s * 0.56, o.dy - s * 0.08)
      ..close();
    c.drawPath(path.shift(const Offset(1, 1.4)), Paint()..color = Colors.black.withOpacity(0.18));
    final gem = Paint()
      ..shader = LinearGradient(colors: [const Color(0xFF7DD3FF), AppColors.gemBlue, const Color(0xFF2A86B5)], begin: Alignment.topLeft, end: Alignment.bottomRight)
          .createShader(Rect.fromCenter(center: o, width: s * 1.2, height: s * 1.2));
    c.drawPath(path, gem);
    c.drawPath(path, Paint()..color = Colors.white.withOpacity(0.12)..style = PaintingStyle.stroke..strokeWidth = 0.8);
    c.drawCircle(o.translate(-s * 0.18, -s * 0.18), s * 0.13, Paint()..color = Colors.white.withOpacity(0.85));
  }

  void _drawShield(Canvas c, Offset o, double s) {
    final path = Path()
      ..moveTo(o.dx, o.dy - s * 0.55)
      ..quadraticBezierTo(o.dx + s * 0.62, o.dy - s * 0.22, o.dx + s * 0.28, o.dy + s * 0.55)
      ..quadraticBezierTo(o.dx, o.dy + s * 0.68, o.dx - s * 0.28, o.dy + s * 0.55)
      ..quadraticBezierTo(o.dx - s * 0.62, o.dy - s * 0.22, o.dx, o.dy - s * 0.55)
      ..close();
    c.drawPath(path.shift(const Offset(1, 1)), Paint()..color = Colors.black.withOpacity(0.18));
    c.drawPath(path, Paint()..color = AppColors.shieldBlue);
    c.drawPath(path, Paint()..color = Colors.white.withOpacity(0.14)..style = PaintingStyle.stroke..strokeWidth = 1);
    c.drawCircle(o.translate(0, -1), 3, Paint()..color = Colors.white.withOpacity(0.9));
  }

  void _drawSparkle(Canvas c, Offset o, double s) {
    final p = Path()
      ..moveTo(o.dx, o.dy - s)
      ..lineTo(o.dx + s * 0.22, o.dy - s * 0.22)
      ..lineTo(o.dx + s, o.dy)
      ..lineTo(o.dx + s * 0.22, o.dy + s * 0.22)
      ..lineTo(o.dx, o.dy + s)
      ..lineTo(o.dx - s * 0.22, o.dy + s * 0.22)
      ..lineTo(o.dx - s, o.dy)
      ..lineTo(o.dx - s * 0.22, o.dy - s * 0.22)
      ..close();
    c.drawPath(p, Paint()..color = Colors.white.withOpacity(0.92));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Illustrative shop card with ribbon ───────────────────────────────────────

class _IllustratedShopCard extends StatelessWidget {
  const _IllustratedShopCard({
    required this.title,
    required this.description,
    required this.sheet,
    required this.priceLabel,
    required this.illustration,
    required this.onTap,
    this.ribbon,
  });
  final String title;
  final String description;
  final Color sheet;
  final String priceLabel;
  final Widget illustration;
  final VoidCallback onTap;
  final Widget? ribbon;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        PaperCard(
          onTap: onTap,
          color: sheet,
          elevation: 1.3,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 80,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.9), width: 1),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Center(child: illustration),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.bodyLarge.copyWith(color: AppColors.paperInk)),
                    const SizedBox(height: 3),
                    Text(description, style: AppTypography.caption.copyWith(color: AppColors.paperInkSoft, height: 1.4)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              PaperButton(label: priceLabel, compact: true, onPressed: onTap),
            ],
          ),
        ),
        if (ribbon != null) Positioned(top: -7, right: 12, child: ribbon!),
      ],
    );
  }
}

// ── Coin packs with illustration + BEST VALUE ─────────────────────────────────

class _CoinPack {
  const _CoinPack({required this.label, required this.sublabel, required this.price, required this.onTap, required this.kind, this.bonus, this.ribbonLabel});
  final String label;
  final String sublabel;
  final String price;
  final VoidCallback onTap;
  final ChestKind kind;
  final String? bonus;
  final String? ribbonLabel;
}

class _CoinPackRow extends StatelessWidget {
  const _CoinPackRow({required this.packs});
  final List<_CoinPack> packs;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < packs.length; i++) ...[
          Expanded(child: _CoinPackCard(pack: packs[i])),
          if (i < packs.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _CoinPackCard extends StatelessWidget {
  const _CoinPackCard({required this.pack});
  final _CoinPack pack;
  @override
  Widget build(BuildContext context) {
    final isBest = pack.ribbonLabel != null;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        PaperCard(
          onTap: pack.onTap,
          color: AppColors.paperGold,
          elevation: isBest ? 1.5 : 1.1,
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
          borderColor: isBest ? AppColors.success : null,
          borderWidth: isBest ? 1.5 : 1.2,
          child: Column(
            children: [
              SizedBox(width: 80, height: 70, child: CustomPaint(painter: _ChestPainter(kind: pack.kind, accent: AppColors.coinGold))),
              const SizedBox(height: 6),
              Text(pack.label, style: AppTypography.stat.copyWith(color: AppColors.paperInk, fontSize: 17)),
              Text(pack.sublabel, style: AppTypography.caption.copyWith(color: AppColors.paperInkSoft, fontSize: 10, fontStyle: FontStyle.italic)),
              // Always reserve bonus badge height for equal card heights
              const SizedBox(height: 4),
              if (pack.bonus != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(6)),
                  child: Text(pack.bonus!, style: AppTypography.overline.copyWith(color: Colors.white, fontSize: 9, letterSpacing: 0.8)),
                )
              else
                const SizedBox(height: 22), // same height as badge row
              const SizedBox(height: 10),
              PaperButton(label: pack.price, compact: true, expand: true, onPressed: pack.onTap),
            ],
          ),
        ),
        if (isBest)
          Positioned(top: -7, left: 0, right: 0, child: Center(child: _RibbonTag(label: pack.ribbonLabel!, color: const Color(0xFF56CF87)))),
      ],
    );
  }
}

// ── Earn free ─────────────────────────────────────────────────────────────────

class _EarnCard extends StatelessWidget {
  const _EarnCard({required this.title, required this.description, required this.icon, required this.iconColor, required this.onTap});
  final String title;
  final String description;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.success.withOpacity(0.35), width: 1.2),
          boxShadow: [
            BoxShadow(color: AppColors.success.withOpacity(0.08), blurRadius: 8, spreadRadius: 0),
          ],
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: iconColor.withOpacity(0.35)),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('FREE',
                        style: AppTypography.overline.copyWith(
                            color: Colors.white, fontSize: 7, letterSpacing: 0.8)),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    style: AppTypography.bodyLarge.copyWith(
                        color: AppColors.textLight, fontSize: 14)),
                Text(description,
                    style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
              ]),
            ),
            PaperButton(
                label: 'Watch',
                compact: true,
                color: AppColors.paperGreen,
                textColor: AppColors.paperInk,
                onPressed: onTap),
          ],
        ),
      ),
    );
  }
}
