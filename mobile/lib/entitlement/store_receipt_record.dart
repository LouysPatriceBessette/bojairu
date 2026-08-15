import 'dart:convert';

/// Locally persisted store purchase metadata.
///
/// Google Play tokens are also POSTed to the entitlement server when HTTP is
/// enabled; [expiresAt] is then the server `expiryTime` when verification
/// succeeds.
class StoreReceiptRecord {
  const StoreReceiptRecord({
    required this.productId,
    required this.platform,
    required this.purchaseTokenOrReceipt,
    required this.purchasedAt,
    this.orderId,
    this.expiresAt,
    this.autoRenewing = true,
    this.acknowledged = false,
    this.rawJson,
  });

  final String productId;
  final String platform; // google_play | app_store
  final String purchaseTokenOrReceipt;
  final DateTime purchasedAt;
  final String? orderId;
  final DateTime? expiresAt;
  final bool autoRenewing;
  final bool acknowledged;
  final String? rawJson;

  bool isValidAt(DateTime now) {
    final exp = expiresAt;
    if (exp == null) return true;
    return !exp.isBefore(now);
  }

  StoreReceiptRecord copyWith({
    DateTime? purchasedAt,
    String? orderId,
    DateTime? expiresAt,
    bool? autoRenewing,
    bool? acknowledged,
    String? rawJson,
  }) {
    return StoreReceiptRecord(
      productId: productId,
      platform: platform,
      purchaseTokenOrReceipt: purchaseTokenOrReceipt,
      purchasedAt: purchasedAt ?? this.purchasedAt,
      orderId: orderId ?? this.orderId,
      expiresAt: expiresAt ?? this.expiresAt,
      autoRenewing: autoRenewing ?? this.autoRenewing,
      acknowledged: acknowledged ?? this.acknowledged,
      rawJson: rawJson ?? this.rawJson,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'productId': productId,
        'platform': platform,
        'purchaseTokenOrReceipt': purchaseTokenOrReceipt,
        'purchasedAt': purchasedAt.toUtc().toIso8601String(),
        'orderId': orderId,
        'expiresAt': expiresAt?.toUtc().toIso8601String(),
        'autoRenewing': autoRenewing,
        'acknowledged': acknowledged,
        'rawJson': rawJson,
      };

  factory StoreReceiptRecord.fromJson(Map<String, Object?> json) {
    DateTime? parseDt(Object? v) {
      if (v is! String || v.isEmpty) return null;
      return DateTime.tryParse(v)?.toUtc();
    }

    return StoreReceiptRecord(
      productId: json['productId']! as String,
      platform: json['platform']! as String,
      purchaseTokenOrReceipt: json['purchaseTokenOrReceipt']! as String,
      purchasedAt: parseDt(json['purchasedAt']) ?? DateTime.now().toUtc(),
      orderId: json['orderId'] as String?,
      expiresAt: parseDt(json['expiresAt']),
      autoRenewing: json['autoRenewing'] as bool? ?? true,
      acknowledged: json['acknowledged'] as bool? ?? false,
      rawJson: json['rawJson'] as String?,
    );
  }

  static String encodeList(List<StoreReceiptRecord> rows) =>
      jsonEncode(rows.map((r) => r.toJson()).toList());

  static List<StoreReceiptRecord> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return <StoreReceiptRecord>[];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return <StoreReceiptRecord>[];
    return decoded
        .whereType<Map>()
        .map(
          (m) => StoreReceiptRecord.fromJson(
            Map<String, Object?>.from(m),
          ),
        )
        .toList();
  }
}
