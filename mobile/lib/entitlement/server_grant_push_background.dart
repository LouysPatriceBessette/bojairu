import 'local_store_receipt_store.dart';
import 'participant_installation_store.dart';
import 'server_grant_receipt.dart';

Future<bool> applyServerGrantPushInBackground(Map<String, dynamic> data) async {
  final installationId = await ParticipantInstallationStore.secureStorage()
      .loadOrCreateId();
  final receiptStore = LocalStoreReceiptStore();
  final local = await receiptStore.loadAll();

  if (isServerGrantRevokePush(data, installationId: installationId)) {
    await receiptStore.saveAll(reconcileServerGrantReceipts(local: local));
    return true;
  }
  final grant = storeReceiptFromLicensePush(
    data,
    installationId: installationId,
    now: DateTime.now().toUtc(),
  );
  if (grant == null) return false;
  await receiptStore.saveAll(
    reconcileServerGrantReceipts(local: local, serverGrant: grant),
  );
  return true;
}
