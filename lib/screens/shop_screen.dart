import 'dart:async';

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
import '../services/ad_service.dart';
import '../services/analytics_service.dart';
import '../services/iap_service.dart';

/// Shop screen — IAP products + rewarded-ad earn flows.
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
        await notifier.addCoins(500);
        await notifier.addGems(25);
        await notifier.setAdsRemoved();
      case IapProductIds.planeBundle:
        for (int i = 0; i < 3; i++) {
          await notifier.unlockPlane(i, 0);
        }
    }
    AnalyticsService.instance
        .logEvent('iap_delivered', params: {'product_id': productId});
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
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.accent))
                    : ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          if (!save.adsRemoved) ...[
                            _SectionHeader(title: 'Ad-Free'),
                            const SizedBox(height: 12),
                            _ShopCard(
                              title: 'Remove Ads',
                              description:
                                  'No more interstitials. Ever. Rewarded ads remain optional.',
                              icon: Icons.block_outlined,
                              iconColor: AppColors.success,
                              sheet: AppColors.paperGreen,
                              dogEar: 'VALUE',
                              actionLabel: _priceFor(IapProductIds.removeAds),
                              onTap: () => _buy(IapProductIds.removeAds),
                            ),
                            const SizedBox(height: 24),
                          ],
                          _SectionHeader(title: 'Deals'),
                          const SizedBox(height: 12),
                          _ShopCard(
                            title: 'Starter Pack',
                            description:
                                '500 coins + 25 gems + Remove Ads included. One-time offer.',
                            icon: Icons.card_giftcard_outlined,
                            iconColor: AppColors.warning,
                            sheet: AppColors.paperGold,
                            dogEar: '1X',
                            actionLabel: _priceFor(IapProductIds.starterPack),
                            onTap: () => _buy(IapProductIds.starterPack),
                          ),
                          const SizedBox(height: 24),
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
                          _SectionHeader(title: 'Gems'),
                          const SizedBox(height: 12),
                          _ShopCard(
                            title: '50 Gems',
                            description:
                                'Premium currency. Use for rare unlocks.',
                            leading: PaperIcon(PaperIconData.gem,
                                size: 28, color: AppColors.gemBlue),
                            iconColor: AppColors.gemBlue,
                            sheet: AppColors.paperBlue,
                            actionLabel: _priceFor(IapProductIds.gems50),
                            onTap: () => _buy(IapProductIds.gems50),
                          ),
                          const SizedBox(height: 24),
                          if (!save.adsRemoved) ...[
                            _SectionHeader(title: 'Earn Free'),
                            const SizedBox(height: 12),
                            _EarnCard(
                              title: 'Mystery Chest',
                              description: 'Watch a short ad for a bonus chest.',
                              icon: Icons.card_giftcard_outlined,
                              iconColor: AppColors.accent,
                              onTap: _showMysteryChestAd,
                            ),
                            const SizedBox(height: 10),
                            _EarnCard(
                              title: 'Refill Shield',
                              description:
                                  'Start your next run with a free shield.',
                              icon: Icons.shield_outlined,
                              iconColor: AppColors.shieldBlue,
                              onTap: _showRefillShieldAd,
                            ),
                          ],
                          const SizedBox(height: 24),
                          Center(
                            child: TextButton(
                              onPressed: IapService.instance.restorePurchases,
                              child: Text(
                                'Restore Purchases',
                                style: AppTypography.caption.copyWith(
                                  decoration: TextDecoration.underline,
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
      ),
    );
  }

  void _showMysteryChestAd() {
    AdService.instance.showRewarded(
      placement: AdPlacement.mysteryChest,
      onRewarded: () async {
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

// ── Sub-widgets ───────────────────────────────────────────────────────────────

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
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
              child: Text('Shop',
                  style: AppTypography.headline,
                  textAlign: TextAlign.center)),
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
    return Text(title.toUpperCase(), style: AppTypography.overline);
  }
}

class _ShopCard extends StatelessWidget {
  const _ShopCard({
    required this.title,
    required this.description,
    this.icon,
    this.leading,
    required this.iconColor,
    required this.actionLabel,
    required this.onTap,
    this.badge,
    this.dogEar,
    this.sheet,
  });

  final String title;
  final String description;
  final IconData? icon;
  final Widget? leading;
  final Color iconColor;
  final String actionLabel;
  final VoidCallback onTap;
  final String? badge;
  final String? dogEar;
  final Color? sheet;

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      onTap: onTap,
      color: sheet ?? AppColors.paper,
      elevation: 1.2,
      padding: const EdgeInsets.all(16),
      dogEar: dogEar != null
          ? DogEar(label: dogEar!, color: AppColors.accent, size: 58)
          : null,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: leading ??
                  Icon(icon, color: iconColor, size: 24),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTypography.bodyLarge
                        .copyWith(color: AppColors.paperInk)),
                const SizedBox(height: 3),
                Text(description,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.paperInkSoft, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          PaperButton(
            label: actionLabel,
            compact: true,
            onPressed: onTap,
          ),
        ],
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
    return PaperCard(
      onTap: onTap,
      color: AppColors.paperBright,
      elevation: 1.0,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTypography.bodyLarge
                        .copyWith(color: AppColors.paperInk, fontSize: 15)),
                Text(description,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.paperInkSoft)),
              ],
            ),
          ),
          PaperButton(
            label: 'Watch',
            compact: true,
            color: AppColors.paperGreen,
            textColor: AppColors.paperInk,
            onPressed: onTap,
          ),
        ],
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
      children: [
        for (int i = 0; i < packs.length; i++) ...[
          Expanded(child: _CoinPackCard(pack: packs[i])),
          if (i < packs.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _CoinPack {
  const _CoinPack(
      {required this.label, required this.price, required this.onTap, this.bonus});
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
    return PaperCard(
      onTap: pack.onTap,
      color: AppColors.paperGold,
      elevation: 1.1,
      padding: const EdgeInsets.all(14),
      dogEar: pack.bonus != null
          ? const DogEar(label: 'BONUS', color: AppColors.success, size: 52)
          : null,
      child: Column(
        children: [
          PaperIcon(PaperIconData.coin, size: 30, color: AppColors.coinGold),
          const SizedBox(height: 6),
          Text(pack.label,
              style: AppTypography.stat
                  .copyWith(color: AppColors.paperInk, fontSize: 17)),
          if (pack.bonus != null) ...[
            const SizedBox(height: 2),
            Text(pack.bonus!,
                style: AppTypography.caption.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                    fontSize: 11)),
          ],
          const SizedBox(height: 10),
          PaperButton(
            label: pack.price,
            compact: true,
            expand: true,
            onPressed: pack.onTap,
          ),
        ],
      ),
    );
  }
}
