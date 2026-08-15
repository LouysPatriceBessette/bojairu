import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// HTTP client for the entitlement service.
class EntitlementClient {
  EntitlementClient({
    required this.baseUrl,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 10),
  })  : _client = httpClient ?? http.Client(),
        _timeout = timeout;

  final Uri baseUrl;
  final http.Client _client;
  final Duration _timeout;

  void close() => _client.close();

  Future<void> registerInstallation(String participantInstallationId) async {
    final uri = baseUrl.resolve('/v1/installations/register');
    final res = await _client
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'participant_installation_id': participantInstallationId,
          }),
        )
        .timeout(_timeout);
    if (res.statusCode != 204) {
      throw EntitlementClientError._fromResponse('installations_register', res);
    }
  }

  Future<void> reportPlanRoster({
    required String planId,
    required String revisionId,
    required List<String> participantInstallationIds,
  }) async {
    final uri = baseUrl.resolve('/v1/housing/plan-roster');
    final res = await _client
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'plan_id': planId,
            'revision_id': revisionId,
            'participant_installation_ids': participantInstallationIds,
          }),
        )
        .timeout(_timeout);
    if (res.statusCode != 204) {
      throw EntitlementClientError._fromResponse('housing_plan_roster', res);
    }
  }

  Future<void> reportActiveUse({required String planId}) async {
    final uri = baseUrl.resolve('/v1/housing/active-use');
    final res = await _client
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'plan_id': planId}),
        )
        .timeout(_timeout);
    if (res.statusCode != 204) {
      throw EntitlementClientError._fromResponse('housing_active_use', res);
    }
  }

  Future<void> reportExpenseDecision({
    required String planId,
    required String expenseId,
    required String participantInstallationId,
    required String decisionKind,
  }) async {
    final uri = baseUrl.resolve('/v1/housing/expense-decision');
    final res = await _client
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'plan_id': planId,
            'expense_id': expenseId,
            'participant_installation_id': participantInstallationId,
            'decision_kind': decisionKind,
          }),
        )
        .timeout(_timeout);
    if (res.statusCode != 204) {
      throw EntitlementClientError._fromResponse('housing_expense_decision', res);
    }
  }

  /// Uploads a Google Play purchase token for server-side
  /// `purchases.subscriptionsv2.get`.
  Future<PlayTokenVerification> uploadPlayToken({
    required String participantInstallationId,
    required String productId,
    required String purchaseToken,
    String platform = 'google_play',
  }) async {
    final uri = baseUrl.resolve('/v1/licenses/play-token');
    final res = await _client
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'participant_installation_id': participantInstallationId,
            'product_id': productId,
            'purchase_token': purchaseToken,
            'platform': platform,
          }),
        )
        .timeout(_timeout);
    if (res.statusCode != 200) {
      throw EntitlementClientError._fromResponse('licenses_play_token', res);
    }
    return PlayTokenVerification.fromResponseBody(res.body);
  }
}

class EntitlementClientError implements Exception {
  EntitlementClientError({
    required this.endpoint,
    required this.statusCode,
    required this.code,
    required this.detail,
  });

  final String endpoint;
  final int statusCode;
  final String code;
  final String detail;

  factory EntitlementClientError._fromResponse(
    String endpoint,
    http.Response res,
  ) {
    String code = 'http_${res.statusCode}';
    String detail = res.reasonPhrase ?? '';
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      code = (body['error'] as String?) ?? (body['code'] as String?) ?? code;
      detail = (body['message'] as String?) ?? (body['detail'] as String?) ?? detail;
    } catch (_) {
      // Non-JSON body.
    }
    return EntitlementClientError(
      endpoint: endpoint,
      statusCode: res.statusCode,
      code: code,
      detail: detail,
    );
  }

  @override
  String toString() =>
      'EntitlementClientError($endpoint, status=$statusCode, code=$code, detail=$detail)';
}

/// Result of `POST /v1/licenses/play-token`.
class PlayTokenVerification {
  const PlayTokenVerification({
    required this.validationState,
    required this.productId,
    required this.grantedModules,
    this.expiresAt,
    this.subscriptionState,
    this.reason,
  });

  final String validationState;
  final String productId;
  final List<String> grantedModules;
  final DateTime? expiresAt;
  final String? subscriptionState;
  final String? reason;

  bool get isValid => validationState == 'valid';

  factory PlayTokenVerification.fromResponseBody(String body) {
    final json = jsonDecode(body);
    if (json is! Map) {
      throw const FormatException('play-token response is not a JSON object');
    }
    final map = Map<String, dynamic>.from(json);
    final modulesRaw = map['granted_modules'];
    final modules = <String>[];
    if (modulesRaw is List) {
      for (final item in modulesRaw) {
        if (item is String && item.isNotEmpty) modules.add(item);
      }
    }
    DateTime? expiresAt;
    final expiresRaw = map['expires_at'];
    if (expiresRaw is String && expiresRaw.isNotEmpty) {
      expiresAt = DateTime.tryParse(expiresRaw)?.toUtc();
    }
    return PlayTokenVerification(
      validationState: (map['validation_state'] as String?) ?? '',
      productId: (map['product_id'] as String?) ?? '',
      grantedModules: modules,
      expiresAt: expiresAt,
      subscriptionState: map['subscription_state'] as String?,
      reason: map['reason'] as String?,
    );
  }
}
