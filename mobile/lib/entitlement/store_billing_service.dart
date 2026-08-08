import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'module_entitlement_controller.dart';
import 'store_product_catalog.dart';
import 'store_receipt_record.dart';

/// Play Billing (and StoreKit when available) bridge — local persistence only.
class StoreBillingService {
  StoreBillingService({
    required ModuleEntitlementController entitlement,
    InAppPurchase? iap,
  })  : _entitlement = entitlement,
        _iap = iap ?? InAppPurchase.instance;

  final ModuleEntitlementController _entitlement;
  final InAppPurchase _iap;

  StreamSubscription<List<PurchaseDetails>>? _sub;
  List<ProductDetails> _products = const <ProductDetails>[];
  bool _available = false;
  String? _lastError;

  bool get isAvailable => _available;
  List<ProductDetails> get products =>
      List<ProductDetails>.unmodifiable(_products);
  String? get lastError => _lastError;

  Future<void> start() async {
    _available = await _iap.isAvailable();
    if (!_available) {
      _lastError = 'store_unavailable';
      return;
    }
    _sub ??= _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object e, StackTrace st) {
        debugPrint('StoreBillingService purchaseStream error: $e\n$st');
        _lastError = e.toString();
      },
    );
    await queryProducts();
  }

  void dispose() {
    unawaited(_sub?.cancel() ?? Future<void>.value());
    _sub = null;
  }

  Future<void> queryProducts() async {
    if (!_available) {
      _available = await _iap.isAvailable();
    }
    if (!_available) {
      _products = const <ProductDetails>[];
      _lastError = 'store_unavailable';
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
  }

  Future<bool> buy(ProductDetails product) async {
    _lastError = null;
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
    await _iap.restorePurchases();
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) continue;
      if (purchase.status == PurchaseStatus.error) {
        _lastError = purchase.error?.message ?? 'purchase_error';
        continue;
      }
      if (purchase.status == PurchaseStatus.canceled) continue;

      final record = _toRecord(purchase);
      if (record != null) {
        await _entitlement.upsertReceipt(record);
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  StoreReceiptRecord? _toRecord(PurchaseDetails purchase) {
    if (!StoreProductCatalog.byProductId.containsKey(purchase.productID)) {
      return null;
    }
    String token = purchase.purchaseID ?? purchase.verificationData.serverVerificationData;
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
