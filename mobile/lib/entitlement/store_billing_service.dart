import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'module_entitlement_controller.dart';
import 'store_product_catalog.dart';
import 'store_receipt_record.dart';

/// Play Billing (and StoreKit when available) bridge — local persistence only.
///
/// Must stay alive for the app process (listen to [InAppPurchase.purchaseStream]
/// from bootstrap). Creating/disposing this only while [LicensesScreen] is open
/// misses purchase updates — and without [InAppPurchase.completePurchase]
/// (Play acknowledge), Google cancels test purchases within minutes.
class StoreBillingService extends ChangeNotifier {
  StoreBillingService({
    required ModuleEntitlementController entitlement,
    InAppPurchase? iap,
  })  : _entitlement = entitlement,
        _iap = iap ?? InAppPurchase.instance;

  static StoreBillingService? _instance;

  static StoreBillingService? get maybeInstance => _instance;

  static void install(StoreBillingService service) {
    _instance = service;
  }

  static void uninstall() {
    _instance = null;
  }

  final ModuleEntitlementController _entitlement;
  final InAppPurchase _iap;

  StreamSubscription<List<PurchaseDetails>>? _sub;
  List<ProductDetails> _products = const <ProductDetails>[];
  bool _available = false;
  String? _lastError;
  var _started = false;

  bool get isAvailable => _available;
  List<ProductDetails> get products =>
      List<ProductDetails>.unmodifiable(_products);
  String? get lastError => _lastError;

  Future<void> start() async {
    if (_started) {
      await queryProducts();
      // Re-query owned purchases so unacknowledged ones still get completed.
      await restore();
      return;
    }
    _started = true;
    _available = await _iap.isAvailable();
    if (!_available) {
      _lastError = 'store_unavailable';
      notifyListeners();
      return;
    }
    _sub ??= _iap.purchaseStream.listen(
      (purchases) {
        unawaited(_onPurchases(purchases));
      },
      onError: (Object e, StackTrace st) {
        debugPrint('StoreBillingService purchaseStream error: $e\n$st');
        _lastError = e.toString();
        notifyListeners();
      },
    );
    await queryProducts();
    // Immediate restore: acknowledges any purchase Play already granted but
    // that we never completed (required for license-tester accelerated refunds).
    await restore();
  }

  /// Cancels the purchase stream. Only for tests / process teardown.
  @override
  void dispose() {
    unawaited(_sub?.cancel() ?? Future<void>.value());
    _sub = null;
    _started = false;
    super.dispose();
  }

  Future<void> queryProducts() async {
    if (!_available) {
      _available = await _iap.isAvailable();
    }
    if (!_available) {
      _products = const <ProductDetails>[];
      _lastError = 'store_unavailable';
      notifyListeners();
      return;
    }
    final response = await _iap.queryProductDetails(
      StoreProductCatalog.allProductIds,
    );
    if (response.error != null) {
      _lastError = response.error!.message;
    }
    final byId = <String, ProductDetails>{
      for (final p in response.productDetails) p.id: p,
    };
    // Stable order matching catalog.
    _products = <ProductDetails>[
      for (final e in StoreProductCatalog.entries)
        if (byId.containsKey(e.productId)) byId[e.productId]!,
    ];
    notifyListeners();
  }

  Future<bool> buy(ProductDetails product) async {
    _lastError = null;
    notifyListeners();
    final PurchaseParam param;
    if (product is GooglePlayProductDetails) {
      param = GooglePlayPurchaseParam(
        productDetails: product,
        offerToken: product.offerToken,
      );
    } else {
      param = PurchaseParam(productDetails: product);
    }
    return _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> restore() async {
    _lastError = null;
    notifyListeners();
    await _iap.restorePurchases();
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      debugPrint(
        'StoreBillingService purchaseStream: '
        'productId=${purchase.productID} status=${purchase.status} '
        'pendingComplete=${purchase.pendingCompletePurchase}',
      );
      if (purchase.status == PurchaseStatus.pending) continue;
      if (purchase.status == PurchaseStatus.error) {
        _lastError = purchase.error?.message ?? 'purchase_error';
        notifyListeners();
        continue;
      }
      if (purchase.status == PurchaseStatus.canceled) continue;

      try {
        // Acknowledge first: local persistence must not block Play's deadline
        // (test purchases are refunded within minutes if unacked).
        await _acknowledgeIfNeeded(purchase);

        final record = _toRecord(purchase);
        if (record != null) {
          await _entitlement.upsertReceipt(record);
          debugPrint(
            'StoreBillingService receipt upserted: ${record.productId}',
          );
        }
      } catch (e, st) {
        debugPrint('StoreBillingService purchase handling failed: $e\n$st');
        _lastError = e.toString();
        // Still try acknowledge if upsert failed before we reordered callers.
        try {
          await _acknowledgeIfNeeded(purchase);
        } catch (ackError, ackSt) {
          debugPrint(
            'StoreBillingService acknowledge after error failed: '
            '$ackError\n$ackSt',
          );
        }
      }
    }
    notifyListeners();
  }

  /// Google Play cancels (and refunds) purchases that are never acknowledged.
  /// Test / license-tester purchases are revoked within minutes.
  Future<void> _acknowledgeIfNeeded(PurchaseDetails purchase) async {
    final needsAck = purchase.pendingCompletePurchase ||
        (purchase is GooglePlayPurchaseDetails &&
            !purchase.billingClientPurchase.isAcknowledged);
    if (!needsAck) return;

    debugPrint(
      'StoreBillingService completePurchase: ${purchase.productID}',
    );
    await _iap.completePurchase(purchase);
  }

  StoreReceiptRecord? _toRecord(PurchaseDetails purchase) {
    if (!StoreProductCatalog.byProductId.containsKey(purchase.productID)) {
      debugPrint(
        'StoreBillingService unknown productId=${purchase.productID}',
      );
      _lastError = 'unknown_product:${purchase.productID}';
      return null;
    }
    String token =
        purchase.purchaseID ?? purchase.verificationData.serverVerificationData;
    String platform = 'unknown';
    DateTime? expiresAt;
    bool autoRenewing = true;
    String? orderId = purchase.purchaseID;
    String? raw;

    if (purchase is GooglePlayPurchaseDetails) {
      platform = 'google_play';
      token = purchase.billingClientPurchase.purchaseToken;
      orderId = purchase.billingClientPurchase.orderId;
      autoRenewing = purchase.billingClientPurchase.isAutoRenewing;
      raw = purchase.billingClientPurchase.originalJson;
      // Subscription expiry is not always on PurchaseDetails; parse if present.
      expiresAt = _tryParseExpiryMs(raw);
    } else {
      platform = defaultTargetPlatform == TargetPlatform.iOS
          ? 'app_store'
          : platform;
      raw = purchase.verificationData.localVerificationData;
    }

    return StoreReceiptRecord(
      productId: purchase.productID,
      platform: platform,
      purchaseTokenOrReceipt: token,
      purchasedAt: DateTime.now().toUtc(),
      orderId: orderId,
      expiresAt: expiresAt,
      autoRenewing: autoRenewing,
      acknowledged: purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored,
      rawJson: raw,
    );
  }

  static DateTime? _tryParseExpiryMs(String? originalJson) {
    if (originalJson == null || originalJson.isEmpty) return null;
    try {
      final map = jsonDecode(originalJson);
      if (map is! Map) return null;
      final ms = map['expiryTimeMillis'] ?? map['expiryTime'];
      if (ms is String) {
        final n = int.tryParse(ms);
        if (n != null) {
          return DateTime.fromMillisecondsSinceEpoch(n, isUtc: true);
        }
      }
      if (ms is int) {
        return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
