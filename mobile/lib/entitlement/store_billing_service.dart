import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'module_entitlement_controller.dart';
import 'store_product_catalog.dart';
import 'store_receipt_record.dart';
import 'subscription_product_line.dart';

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

  /// Serializes Play purchase queries so restore/stream upserts cannot race prune.
  Future<bool>? _syncInFlight;

  bool get isAvailable => _available;
  List<ProductDetails> get products =>
      List<ProductDetails>.unmodifiable(_products);
  String? get lastError => _lastError;

  /// Visible in release logcat (`debugPrint` is stripped from AAB release).
  static void _releaseLog(String message) {
    // ignore: avoid_print
    print('StoreBillingService: $message');
  }

  static String _tokenPreview(String token) {
    if (token.length <= 12) return token;
    return '${token.substring(0, 6)}…${token.substring(token.length - 4)}';
  }

  /// Ensures the purchase stream is listening, then refreshes from the store.
  /// Returns whether the Play-owned purchase query succeeded (see
  /// [refreshFromPlayStore]).
  Future<bool> start() async {
    if (!_started) {
      _started = true;
      _available = await _iap.isAvailable();
      if (!_available) {
        _lastError = 'store_unavailable';
        notifyListeners();
        return false;
      }
      _sub ??= _iap.purchaseStream.listen(
        (purchases) {
          unawaited(_onPurchases(purchases));
        },
        onError: (Object e, StackTrace st) {
          _releaseLog('purchaseStream error: $e\n$st');
          _lastError = e.toString();
          notifyListeners();
        },
      );
    }
    // Every start (including Licenses re-entry) re-queries Play — local cache
    // alone must not drive subscription UI.
    return refreshFromPlayStore();
  }

  /// Same as [refreshFromPlayStore] — call at each license access checkpoint
  /// (import, module hubs) so decisions are not based on a stale local cache.
  Future<bool> refreshForLicenseCheckpoint() => refreshFromPlayStore();

  /// Re-query the store for owned subscriptions and reconcile local receipts.
  ///
  /// On Android this calls Play Billing [queryPastPurchases], upserts live
  /// rows (including [autoRenewing]), and **drops** Google Play receipts whose
  /// purchase tokens Play no longer returns. Returns `false` if the Play query
  /// failed (local receipts are left unchanged).
  ///
  /// Android does **not** call [InAppPurchase.restorePurchases]: that API
  /// re-queries the same purchases and pushes them on [purchaseStream]
  /// asynchronously, which can re-upsert tokens after prune. Presence is
  /// decided only by [queryPastPurchases] + retain.
  Future<bool> refreshFromPlayStore() async {
    _lastError = null;
    notifyListeners();
    if (!_available) {
      _available = await _iap.isAvailable();
    }
    if (!_available) {
      _lastError = 'store_unavailable';
      notifyListeners();
      return false;
    }
    await queryProducts();
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _syncReceiptsFromPlayQuery();
    }
    try {
      await _iap.restorePurchases();
    } catch (e, st) {
      _releaseLog('restorePurchases: $e\n$st');
    }
    notifyListeners();
    return true;
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
    await refreshFromPlayStore();
  }

  /// Upserts current Play purchases and removes local Google Play receipts
  /// whose tokens are absent from the query (stale cancel/resubscribe rows).
  Future<bool> _syncReceiptsFromPlayQuery() async {
    final existing = _syncInFlight;
    if (existing != null) return existing;

    final done = _syncReceiptsFromPlayQueryBody();
    _syncInFlight = done;
    try {
      return await done;
    } finally {
      if (identical(_syncInFlight, done)) {
        _syncInFlight = null;
      }
    }
  }

  Future<bool> _syncReceiptsFromPlayQueryBody() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      notifyListeners();
      return true;
    }
    try {
      final addition =
          _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final response = await addition.queryPastPurchases();
      if (response.error != null) {
        _releaseLog(
          'queryPastPurchases error: ${response.error!.message}',
        );
        _lastError = response.error!.message;
        notifyListeners();
        return false;
      }
      final livePurchaseTokens = <String>{};
      for (final purchase in response.pastPurchases) {
        if (purchase.status == PurchaseStatus.error) continue;
        if (purchase.status == PurchaseStatus.canceled) continue;
        try {
          await _acknowledgeIfNeeded(purchase);
          final record = _toRecord(purchase);
          if (record == null) continue;
          livePurchaseTokens.add(record.purchaseTokenOrReceipt);
          await _entitlement.upsertReceipt(record);
          _releaseLog(
            'query sync productId=${record.productId} '
            'autoRenewing=${record.autoRenewing} '
            'token=${_tokenPreview(record.purchaseTokenOrReceipt)}',
          );
        } catch (e, st) {
          _releaseLog('query sync item failed: $e\n$st');
        }
      }
      await _entitlement.retainGooglePlayPurchaseTokens(livePurchaseTokens);
      _releaseLog(
        'Play reconcile liveTokens=${livePurchaseTokens.length} '
        'ok=true',
      );
      notifyListeners();
      return true;
    } catch (e, st) {
      _releaseLog('_syncReceiptsFromPlayQuery: $e\n$st');
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Opens the platform subscription management UI for [productId].
  ///
  /// Android: Play subscriptions deep link (cancel / manage happens in Play).
  /// iOS: not wired yet (tests deferred); returns false.
  Future<bool> openManageSubscription(String productId) async {
    _lastError = null;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // StoreKit cancel deep-link deferred with iOS QA.
      _lastError = 'manage_subscription_unsupported_ios';
      notifyListeners();
      return false;
    }
    if (defaultTargetPlatform != TargetPlatform.android) {
      _lastError = 'manage_subscription_unsupported';
      notifyListeners();
      return false;
    }
    try {
      final info = await PackageInfo.fromPlatform();
      final uri = playSubscriptionManagementUri(
        productId: productId,
        packageName: info.packageName,
      );
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        _lastError = 'manage_subscription_launch_failed';
        notifyListeners();
      }
      return ok;
    } catch (e, st) {
      _releaseLog('openManageSubscription: $e\n$st');
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      _releaseLog(
        'purchaseStream productId=${purchase.productID} '
        'status=${purchase.status} '
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
          _releaseLog(
            'receipt upserted productId=${record.productId} '
            'autoRenewing=${record.autoRenewing} '
            'token=${_tokenPreview(record.purchaseTokenOrReceipt)}',
          );
        }
      } catch (e, st) {
        _releaseLog('purchase handling failed: $e\n$st');
        _lastError = e.toString();
        // Still try acknowledge if upsert failed before we reordered callers.
        try {
          await _acknowledgeIfNeeded(purchase);
        } catch (ackError, ackSt) {
          _releaseLog(
            'acknowledge after error failed: $ackError\n$ackSt',
          );
        }
      }
    }
    // Re-query Play so a stream upsert cannot leave a token Play no longer owns.
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _syncReceiptsFromPlayQuery();
      return;
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

    _releaseLog('completePurchase: ${purchase.productID}');
    await _iap.completePurchase(purchase);
  }

  StoreReceiptRecord? _toRecord(PurchaseDetails purchase) {
    if (!StoreProductCatalog.byProductId.containsKey(purchase.productID)) {
      _releaseLog('unknown productId=${purchase.productID}');
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

    // Signup time from the store (does not move on renewal). Used to estimate
    // license-tester renewal boundaries when expiry is absent from the client JSON.
    var purchasedAt = DateTime.now().toUtc();

    if (purchase is GooglePlayPurchaseDetails) {
      platform = 'google_play';
      token = purchase.billingClientPurchase.purchaseToken;
      orderId = purchase.billingClientPurchase.orderId;
      autoRenewing = purchase.billingClientPurchase.isAutoRenewing;
      raw = purchase.billingClientPurchase.originalJson;
      // Subscription expiry is not always on PurchaseDetails; parse if present.
      expiresAt = _tryParseExpiryMs(raw);
      final purchaseTimeMs = purchase.billingClientPurchase.purchaseTime;
      if (purchaseTimeMs > 0) {
        purchasedAt = DateTime.fromMillisecondsSinceEpoch(
          purchaseTimeMs,
          isUtc: true,
        );
      }
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
      purchasedAt: purchasedAt,
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
