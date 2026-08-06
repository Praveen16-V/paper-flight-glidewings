import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import 'analytics_service.dart';

/// Product IDs — must match App Store Connect / Google Play Console exactly.
abstract class IapProductIds {
  static const String removeAds = 'com.paperflight.remove_ads';
  static const String coins1000 = 'com.paperflight.coins_1000';
  static const String coins5000 = 'com.paperflight.coins_5000';
  static const String gems50 = 'com.paperflight.gems_50';
  static const String starterPack = 'com.paperflight.starter_pack';
  static const String planeBundle = 'com.paperflight.plane_bundle';

  static const Set<String> all = {
    removeAds,
    coins1000,
    coins5000,
    gems50,
    starterPack,
    planeBundle,
  };
}

/// Product metadata returned to UI for display.
class IapProduct {
  const IapProduct({
    required this.id,
    required this.title,
    required this.description,
    required this.priceString,
    required this.rawProduct,
  });

  final String id;
  final String title;
  final String description;
  final String priceString;
  final ProductDetails rawProduct;
}

/// Centralised in-app purchase wrapper.
///
/// Usage:
///   1. Call [IapService.instance.initialize()] at app start.
///   2. Listen to [purchaseStream] for completed/failed purchases.
///   3. Call [buy(id)] to initiate a purchase.
///   4. Call [restorePurchases()] on the restore button.
class IapService {
  IapService._();
  static final IapService instance = IapService._();

  final InAppPurchase _iap = InAppPurchase.instance;

  // Exposed so UI can listen.
  final StreamController<PurchaseEvent> _eventController =
      StreamController.broadcast();
  Stream<PurchaseEvent> get purchaseStream => _eventController.stream;

  List<IapProduct> _products = [];
  List<IapProduct> get products => List.unmodifiable(_products);

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  bool _available = false;
  bool get isAvailable => _available;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    _available = await _iap.isAvailable();
    if (!_available) return;

    // Listen for purchase updates (completions, errors, restorations).
    _purchaseSub = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (_) {},
    );

    await _loadProducts();
  }

  void dispose() {
    _purchaseSub?.cancel();
    _eventController.close();
  }

  // ── Products ──────────────────────────────────────────────────────────────

  Future<void> _loadProducts() async {
    final response = await _iap.queryProductDetails(IapProductIds.all);
    _products = response.productDetails
        .map((p) => IapProduct(
              id: p.id,
              title: p.title,
              description: p.description,
              priceString: p.price,
              rawProduct: p,
            ))
        .toList();
  }

  IapProduct? productById(String id) {
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  // ── Purchase ──────────────────────────────────────────────────────────────

  Future<void> buy(String productId) async {
    if (!_available) return;
    final product = productById(productId);
    if (product == null) return;

    final param = PurchaseParam(productDetails: product.rawProduct);

    // Non-consumables (Remove Ads, plane bundles).
    if (productId == IapProductIds.removeAds ||
        productId == IapProductIds.planeBundle) {
      await _iap.buyNonConsumable(purchaseParam: param);
    } else {
      // Consumables (coins, gems, starter pack).
      await _iap.buyConsumable(purchaseParam: param);
    }

    AnalyticsService.instance.logEvent(
      'iap_initiated',
      params: {'product_id': productId},
    );
  }

  Future<void> restorePurchases() async {
    if (!_available) return;
    await _iap.restorePurchases();
  }

  // ── Purchase handler ──────────────────────────────────────────────────────

  void _handlePurchaseUpdates(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _verifyAndDeliver(purchase);
        case PurchaseStatus.error:
          _eventController.add(PurchaseEvent.failed(purchase.productID));
          if (purchase.pendingCompletePurchase) {
            _iap.completePurchase(purchase);
          }
        case PurchaseStatus.canceled:
          _eventController.add(PurchaseEvent.cancelled(purchase.productID));
        case PurchaseStatus.pending:
          break;
      }
    }
  }

  Future<void> _verifyAndDeliver(PurchaseDetails purchase) async {
    // In production: verify receipt server-side before granting.
    // For scaffold: trust the SDK and deliver immediately.
    _eventController.add(PurchaseEvent.completed(purchase.productID));

    AnalyticsService.instance.logEvent(
      'iap_completed',
      params: {'product_id': purchase.productID},
    );

    if (purchase.pendingCompletePurchase) {
      await _iap.completePurchase(purchase);
    }
  }
}

// ── Purchase event ────────────────────────────────────────────────────────────

enum PurchaseEventType { completed, failed, cancelled }

class PurchaseEvent {
  const PurchaseEvent.completed(this.productId)
      : type = PurchaseEventType.completed;
  const PurchaseEvent.failed(this.productId)
      : type = PurchaseEventType.failed;
  const PurchaseEvent.cancelled(this.productId)
      : type = PurchaseEventType.cancelled;

  final String productId;
  final PurchaseEventType type;
}
