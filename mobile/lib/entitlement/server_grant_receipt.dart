import 'app_module_id.dart';
import 'entitlement_client.dart';
import 'store_receipt_record.dart';

const kServerGrantPlatform = 'server_grant';
const kAllModulesProductId = 'bojairu.bundle.all_modules';
const kLicenseReceiptChangedKind = 'license_receipt_changed';

const _requiredModules = <String>{'housing', 'vehicle', 'vehicle-sharing'};

StoreReceiptRecord? storeReceiptFromServerGrant(
  ServerLicenseReceipt row, {
  required DateTime now,
}) {
  if (row.platform != kServerGrantPlatform ||
      row.productId != kAllModulesProductId ||
      row.validationState != 'valid' ||
      row.purchaseToken.isEmpty ||
      row.purchasedAt == null ||
      row.expiresAt == null ||
      row.expiresAt!.isBefore(now.toUtc()) ||
      !row.grantedModules.toSet().containsAll(_requiredModules)) {
    return null;
  }
  return StoreReceiptRecord(
    productId: row.productId,
    platform: row.platform,
    purchaseTokenOrReceipt: row.purchaseToken,
    purchasedAt: row.purchasedAt!,
    expiresAt: row.expiresAt!,
    autoRenewing: false,
    acknowledged: true,
  );
}

StoreReceiptRecord? storeReceiptFromLicensePush(
  Map<String, dynamic> data, {
  required String installationId,
  required DateTime now,
}) {
  if (data['kind'] != kLicenseReceiptChangedKind ||
      data['action'] != 'grant' ||
      data['installation_id'] != installationId ||
      data['product_id'] != kAllModulesProductId ||
      data['platform'] != kServerGrantPlatform) {
    return null;
  }
  final token = data['purchase_token'] as String? ?? '';
  final purchasedAt = DateTime.tryParse(
    data['purchased_at'] as String? ?? '',
  )?.toUtc();
  final expiresAt = DateTime.tryParse(
    data['expires_at'] as String? ?? '',
  )?.toUtc();
  if (token.isEmpty ||
      purchasedAt == null ||
      expiresAt == null ||
      expiresAt.isBefore(now.toUtc())) {
    return null;
  }
  return StoreReceiptRecord(
    productId: kAllModulesProductId,
    platform: kServerGrantPlatform,
    purchaseTokenOrReceipt: token,
    purchasedAt: purchasedAt,
    expiresAt: expiresAt,
    autoRenewing: false,
    acknowledged: true,
  );
}

bool isServerGrantRevokePush(
  Map<String, dynamic> data, {
  required String installationId,
}) {
  return data['kind'] == kLicenseReceiptChangedKind &&
      data['action'] == 'revoke' &&
      data['installation_id'] == installationId &&
      data['product_id'] == kAllModulesProductId &&
      data['platform'] == kServerGrantPlatform;
}

List<StoreReceiptRecord> reconcileServerGrantReceipts({
  required Iterable<StoreReceiptRecord> local,
  StoreReceiptRecord? serverGrant,
}) {
  return <StoreReceiptRecord>[
    for (final row in local)
      if (row.platform != kServerGrantPlatform) row,
    ?serverGrant,
  ];
}

bool hasActiveServerGrant(
  Iterable<StoreReceiptRecord> receipts, {
  required AppModuleId module,
  required DateTime now,
}) {
  if (!_requiredModules.contains(module.wire)) return false;
  return receipts.any(
    (row) =>
        row.platform == kServerGrantPlatform &&
        row.productId == kAllModulesProductId &&
        row.isValidAt(now.toUtc()),
  );
}
