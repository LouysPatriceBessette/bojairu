import 'dart:convert';

import 'vehicle_usage_balance.dart';

/// Local / wire status for [VehicleUsageBalanceFreezes].
abstract final class UsageBalanceFreezeStatus {
  static const pending = 'pending';
  static const acceptedAwaitingCatchUp = 'acceptedAwaitingCatchUp';
  static const confirmed = 'confirmed';
  static const rejected = 'rejected';
}

/// Local / wire status for [VehicleUsageTransfers].
abstract final class UsageBalanceTransferStatus {
  static const pending = 'pending';
  static const confirmed = 'confirmed';
  static const rejected = 'rejected';
}

/// Serializes / deserializes [VehicleUsageBalanceBreakdown] for freeze rows.
abstract final class UsageBalanceBreakdownCodec {
  static String encode(VehicleUsageBalanceBreakdown b) {
    return jsonEncode({
      'litersPer100Km': b.litersPer100Km,
      'distanceKm': b.distanceKm,
      'pricePerLiterMinor': b.pricePerLiterMinor,
      'fuelPurchasesInAverage': b.fuelPurchasesInAverage,
      'borrowerFuelCostMinor': b.borrowerFuelCostMinor,
      'borrowerMaintenanceCostMinor': b.borrowerMaintenanceCostMinor,
      'ratePerKmMinor': b.ratePerKmMinor,
      'estimatedFuelCostMinor': b.estimatedFuelCostMinor,
      'compensationMinor': b.compensationMinor,
      'balanceMinor': b.balanceMinor,
      'windowStart': b.windowStart.toUtc().toIso8601String(),
      'windowEnd': b.windowEnd.toUtc().toIso8601String(),
      'distanceLineItems': b.distanceLineItems.map(_encodeDistance).toList(),
      'borrowerFuelLineItems': b.borrowerFuelLineItems.map(_encodeCost).toList(),
      'borrowerMaintenanceLineItems':
          b.borrowerMaintenanceLineItems.map(_encodeCost).toList(),
    });
  }

  static VehicleUsageBalanceBreakdown decode(String json) {
    final root = jsonDecode(json) as Map<String, dynamic>;
    return VehicleUsageBalanceBreakdown(
      litersPer100Km: (root['litersPer100Km'] as num).toDouble(),
      distanceKm: (root['distanceKm'] as num).toDouble(),
      pricePerLiterMinor: (root['pricePerLiterMinor'] as num).toDouble(),
      fuelPurchasesInAverage: root['fuelPurchasesInAverage'] as int,
      borrowerFuelCostMinor: root['borrowerFuelCostMinor'] as int,
      borrowerMaintenanceCostMinor: root['borrowerMaintenanceCostMinor'] as int,
      ratePerKmMinor: root['ratePerKmMinor'] as int,
      estimatedFuelCostMinor: root['estimatedFuelCostMinor'] as int,
      compensationMinor: root['compensationMinor'] as int,
      balanceMinor: root['balanceMinor'] as int,
      windowStart: DateTime.parse(root['windowStart'] as String).toUtc(),
      windowEnd: DateTime.parse(root['windowEnd'] as String).toUtc(),
      distanceLineItems: (root['distanceLineItems'] as List<dynamic>)
          .map((e) => _decodeDistance(e as Map<String, dynamic>))
          .toList(),
      borrowerFuelLineItems: (root['borrowerFuelLineItems'] as List<dynamic>)
          .map((e) => _decodeCost(e as Map<String, dynamic>))
          .toList(),
      borrowerMaintenanceLineItems:
          (root['borrowerMaintenanceLineItems'] as List<dynamic>)
              .map((e) => _decodeCost(e as Map<String, dynamic>))
              .toList(),
    );
  }

  static Map<String, dynamic> _encodeDistance(UsageBalanceDistanceFact f) => {
        'attributedContactId': f.attributedContactId,
        'distanceTenths': f.distanceTenths,
        'at': f.at.toUtc().toIso8601String(),
      };

  static UsageBalanceDistanceFact _decodeDistance(Map<String, dynamic> m) =>
      UsageBalanceDistanceFact(
        attributedContactId: m['attributedContactId'] as String,
        distanceTenths: m['distanceTenths'] as int,
        at: DateTime.parse(m['at'] as String).toUtc(),
      );

  static Map<String, dynamic> _encodeCost(UsageBalanceCostFact f) => {
        'recordedByContactId': f.recordedByContactId,
        'costMinor': f.costMinor,
        'at': f.at.toUtc().toIso8601String(),
      };

  static UsageBalanceCostFact _decodeCost(Map<String, dynamic> m) =>
      UsageBalanceCostFact(
        recordedByContactId: m['recordedByContactId'] as String,
        costMinor: m['costMinor'] as int,
        at: DateTime.parse(m['at'] as String).toUtc(),
      );
}

/// Ledger delta for a confirmed transfer in the « Solde reporté » total.
///
/// Borrower→owner payments reduce the carried owed-to-owner balance; owner→
/// borrower payments increase it (settle a credit to the Emprunteur).
int usageBalanceTransferLedgerDeltaMinor({
  required int amountMinor,
  required bool paidToOwner,
}) {
  final abs = amountMinor.abs();
  return paidToOwner ? -abs : abs;
}

/// Carried-forward total: confirmed freezes plus signed transfer ledger deltas.
int usageBalanceCarriedForwardMinor({
  required Iterable<int> confirmedFreezeBalanceMinors,
  required Iterable<int> confirmedTransferLedgerDeltas,
}) {
  var sum = 0;
  for (final b in confirmedFreezeBalanceMinors) {
    sum += b;
  }
  for (final t in confirmedTransferLedgerDeltas) {
    sum += t;
  }
  return sum;
}
