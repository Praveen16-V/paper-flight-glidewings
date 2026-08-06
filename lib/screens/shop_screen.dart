import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/enums/game_enums.dart';
import '../providers/save_data_provider.dart';
import '../services/ad_service.dart';
import '../services/analytics_service.dart';
import '../services/iap_service.dart';

/// Shop screen — IAP products + rewarded-ad earn flows.
///
/// IAP products are fetched from the store at build time via [IapService].
/// Rewarded ad flows (mystery chest, pre-run shield refill) are shown here
/// as opt-in earn actions for non-paying players.
class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  StreamSubscription<PurchaseEvent>? _purchaseSub;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _purchaseSub = IapService.instance.purchaseStream.listen(_onPurchaseEvent);
    AnalyticsService.instance.logScreenView('shop');
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }

  void _onPurchaseEvent(PurchaseEvent event) async {
    if (!mounted) return;
    setState(() => _loading = false);

    switch (event.type) {
      case PurchaseEventType.completed:
        await _deliverProduct(event.productId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Purchase complete!'),
            backgroundColor: AppColors.success,
          ));
        }
      case PurchaseEventType.failed:
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Purchase failed. Please try again.'),
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
        await notifier.addCoins(1000);
      case IapProductIds.coins5000:
        await notifier.addCoins(5000);
      case IapProductIds.gems50:
        await notifier.addGems(50);
      case IapProductIds.starterPack:
        // Starter pack: 500 coins + 25 gems + remove ads trial.
        await notifier.addCoins(500);
        await notifier.addGems(25);
        await notifier.setAdsRemoved();
      case IapProductIds.planeBundle:
        // Unlock all planes.
        for (int i = 0; i < 3; i++) {
          await notifier.unlockPlane(i, 0);
        }
    }

    AnalyticsService.instance.logEvent(
      'iap_delivered',
      params: {'product_id': productId},
    );
  }

  void _buy(String productId) {
    setState(() => _loading = true);
    IapService.instance.buy(productId);
  }

  @override
  Widget build(BuildContext context) {
    final save = ref.watch(saveDataProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textLight,
        elevation: 0,
        title: const Text('Shop',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _CurrencyRow(coins: save.coins, gems: save.gems),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ── Remove Ads ─────────────────────────────────────────────
                if (!save.adsRemoved) ...[
                  _SectionHeader(title: 'Ad-Free'),
                  const SizedBox(height: 12),
                  _ShopCard(
                    title: 'Remove Ads',
                    description:
                        'No more interstitials. Ever. Rewarded ads remain '
                        'optional.',
                    icon: Icons.block_outlined,
                    iconColor: AppColors.success,
                    badge: 'BEST VALUE',
                    actionLabel: _priceFor(IapProductIds.removeAds),
                    onTap: () => _buy(IapProductIds.removeAds),
                  ),
                  const SizedBox(height: 24),
                ],

                // ── Starter pack ───────────────────────────────────────────
                _SectionHeader(title: 'Deals'),
                const SizedBox(height: 12),
                _ShopCard(
                  title: 'Starter Pack',
                  description:
                      '500 coins + 25 gems + Remove Ads included. '
                      'One-time offer.',
                  icon: Icons.card_giftcard_outlined,
                  iconColor: AppColors.warning,
                  badge: 'ONE-TIME',
                  actionLabel: _priceFor(IapProductIds.starterPack),
                  onTap: () => _buy(IapProductIds.starterPack),
                ),
                const SizedBox(height: 24),

                // ── Coins ──────────────────────────────────────────────────
                _SectionHeader(title: 'Coins'),
                const SizedBox(height: 12),
                _CoinPackRow(
                  packs: [
                    _CoinPack(
                      label: '1,000',
                      price: _priceFor(IapProductIds.coins1000),
                      onTap: () => _buy(IapProductIds.coins1000),
                    ),
                    _CoinPack(
                      label: '5,000',
                      price: _priceFor(IapProductIds.coins5000),
                      bonus: '+20%',
                      onTap: () => _buy(IapProductIds.coins5000),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Gems ───────────────────────────────────────────────────
                _SectionHeader(title: 'Gems'),
                const SizedBox(height: 12),
                _ShopCard(
                  title: '50 Gems',
                  description: 'Premium currency. Use for rare unlocks.',
                  icon: Icons.diamond_outlined,
                  iconColor: AppColors.gemBlue,
                  actionLabel: _priceFor(IapProductIds.gems50),
                  onTap: () => _buy(IapProductIds.gems50),
                ),
                const SizedBox(height: 24),

                // ── Earn free items ────────────────────────────────────────
                if (!save.adsRemoved) ...[
                  _SectionHeader(title: 'Earn Free'),
                  const SizedBox(height: 12),
                  _EarnCard(
                    title: 'Mystery Chest',
                    description: 'Watch a short ad for a bonus chest.',
                    icon: Icons.card_giftcard_outlined,
                    iconColor: AppColors.accent,
                    onTap: () => _showMysteryChestAd(),
                  ),
                  const SizedBox(height: 10),
                  _EarnCard(
                    title: 'Refill Shield',
                    description:
                        'Start your next run with a free shield.',
                    icon: Icons.shield_outlined,
                    iconColor: AppColors.shieldBlue,
                    onTap: () => _showRefillShieldAd(),
                  ),
                ],

                const SizedBox(height: 24),
                _RestoreButton(onTap: IapService.instance.restorePurchases),
              ],
            ),
    );
  }

  // ── Rewarded ad flows ─────────────────────────────────────────────────────

  void _showMysteryChestAd() {
    AdService.instance.showRewarded(
      placement: AdPlacement.mysteryChest,
      onRewarded: () async {
        // Award random chest: 50–150 coins + maybe 1 gem.
        final coins = 50 + (DateTime.now().millisecond % 100);
        await ref.read(saveDataProvider.notifier).addCoins(coins);
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
      onRewarded: () async {
        await ref.read(saveDataProvider.notifier).setPendingStartShield(true);
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

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.5,
      ),
    );
  }
}

class _ShopCard extends StatelessWidget {
  const _ShopCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.actionLabel,
    required this.onTap,
    this.badge,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color iconColor;
  final String actionLabel;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.warning,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge!,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF5A623), Color(0xFFFF6B35)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EarnCard extends StatelessWidget {
  const _EarnCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      )),
                  Text(description,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.play_circle_outline,
                color: AppColors.accent, size: 28),
          ],
        ),
      ),
    );
  }
}

class _CoinPackRow extends StatelessWidget {
  const _CoinPackRow({required this.packs});
  final List<_CoinPack> packs;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: packs
          .map((p) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: packs.indexOf(p) < packs.length - 1 ? 10 : 0,
                  ),
                  child: _CoinPackCard(pack: p),
                ),
              ))
          .toList(),
    );
  }
}

class _CoinPack {
  const _CoinPack({
    required this.label,
    required this.price,
    required this.onTap,
    this.bonus,
  });
  final String label;
  final String price;
  final VoidCallback onTap;
  final String? bonus;
}

class _CoinPackCard extends StatelessWidget {
  const _CoinPackCard({required this.pack});
  final _CoinPack pack;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: pack.onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            const Text('●', style: TextStyle(color: AppColors.coinGold, fontSize: 24)),
            const SizedBox(height: 4),
            Text(
              pack.label,
              style: const TextStyle(
                color: AppColors.textLight,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (pack.bonus != null) ...[
              const SizedBox(height: 2),
              Text(
                pack.bonus!,
                style: const TextStyle(
                  color: AppColors.success,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF5A623), Color(0xFFFF6B35)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                pack.price,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrencyRow extends StatelessWidget {
  const _CurrencyRow({required this.coins, required this.gems});
  final int coins;
  final int gems;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('● $coins',
            style: const TextStyle(
                color: AppColors.coinGold,
                fontWeight: FontWeight.w700,
                fontSize: 14)),
        const SizedBox(width: 10),
        Text('◆ $gems',
            style: const TextStyle(
                color: AppColors.gemBlue,
                fontWeight: FontWeight.w700,
                fontSize: 14)),
      ],
    );
  }
}

class _RestoreButton extends StatelessWidget {
  const _RestoreButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: onTap,
        child: const Text(
          'Restore Purchases',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 13,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}
