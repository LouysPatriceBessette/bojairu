import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../relay/envelopes.dart';
import '../relay/relay_client.dart';

const _kHeldKey = 'licensing.vehicleSharing.heldBorrowerEnvelopes.v1';

/// Borrower→owner envelopes received while sharing is not writable.
class HeldBorrowerVehicleEnvelope {
  const HeldBorrowerVehicleEnvelope({
    required this.envelopeId,
    required this.kind,
    required this.senderContactId,
    required this.ciphertext,
    required this.createdAt,
  });

  final String envelopeId;
  final int kind;
  final String senderContactId;
  final Uint8List ciphertext;
  final DateTime createdAt;

  Map<String, Object> toJson() => {
        'envelopeId': envelopeId,
        'kind': kind,
        'senderContactId': senderContactId,
        'ciphertext': base64Encode(ciphertext),
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  static HeldBorrowerVehicleEnvelope? fromJson(Map<String, dynamic> json) {
    final id = json['envelopeId'] as String?;
    final kind = json['kind'] as int?;
    final sender = json['senderContactId'] as String?;
    final cipher = json['ciphertext'] as String?;
    final createdRaw = json['createdAt'] as String?;
    if (id == null ||
        kind == null ||
        sender == null ||
        cipher == null ||
        createdRaw == null) {
      return null;
    }
    final created = DateTime.tryParse(createdRaw);
    if (created == null) return null;
    return HeldBorrowerVehicleEnvelope(
      envelopeId: id,
      kind: kind,
      senderContactId: sender,
      ciphertext: base64Decode(cipher),
      createdAt: created.toUtc(),
    );
  }

  RelayEnvelopeView asRelayView({
    required Uint8List senderIdentity,
    required Uint8List recipientIdentity,
  }) {
    return RelayEnvelopeView(
      envelopeId: envelopeId,
      senderIdentity: senderIdentity,
      recipientIdentity: recipientIdentity,
      ciphertext: ciphertext,
      kind: kind,
      createdAt: createdAt,
      ttlExpiresAt: createdAt.add(const Duration(days: 7)),
    );
  }
}

abstract final class HeldBorrowerVehicleInbox {
  static bool isBorrowerToOwnerKind(int kind) {
    return kind == EnvelopeKind.vehicleSharingOfferAccept ||
        kind == EnvelopeKind.vehicleUseSessionStart ||
        kind == EnvelopeKind.vehicleUseSessionEnd ||
        kind == EnvelopeKind.vehicleFuelPurchase ||
        kind == EnvelopeKind.vehicleMaintenance ||
        kind == EnvelopeKind.vehicleTrafficViolation ||
        kind == EnvelopeKind.vehicleSharingReactivateAccept;
  }

  static Future<List<HeldBorrowerVehicleEnvelope>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kHeldKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final out = <HeldBorrowerVehicleEnvelope>[];
      for (final item in list) {
        if (item is! Map) continue;
        final parsed = HeldBorrowerVehicleEnvelope.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (parsed != null) out.add(parsed);
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  static Future<void> enqueue({
    required RelayEnvelopeView envelope,
    required String senderContactId,
  }) async {
    final current = [...await loadAll()];
    if (current.any((e) => e.envelopeId == envelope.envelopeId)) return;
    current.add(
      HeldBorrowerVehicleEnvelope(
        envelopeId: envelope.envelopeId,
        kind: envelope.kind,
        senderContactId: senderContactId,
        ciphertext: envelope.ciphertext,
        createdAt: envelope.createdAt.toUtc(),
      ),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kHeldKey,
      jsonEncode(current.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> remove(String envelopeId) async {
    final next = [
      for (final e in await loadAll())
        if (e.envelopeId != envelopeId) e,
    ];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kHeldKey,
      jsonEncode(next.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> clearForTesting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kHeldKey);
  }
}
