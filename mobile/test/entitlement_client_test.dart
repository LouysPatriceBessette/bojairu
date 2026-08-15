import 'dart:convert';

import 'package:compartarenta/entitlement/entitlement_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('EntitlementClient', () {
    test('registerInstallation posts participant_installation_id', () async {
      String? capturedBody;
      final client = EntitlementClient(
        baseUrl: Uri.parse('http://127.0.0.1:8081'),
        httpClient: MockClient((request) async {
          capturedBody = request.body;
          expect(request.url.path, '/v1/installations/register');
          return http.Response('', 204);
        }),
      );
      addTearDown(client.close);

      await client.registerInstallation('inst-test-device');

      final json = jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(json['participant_installation_id'], 'inst-test-device');
    });

    test('reportPlanRoster posts roster payload', () async {
      String? capturedBody;
      final client = EntitlementClient(
        baseUrl: Uri.parse('http://127.0.0.1:8081'),
        httpClient: MockClient((request) async {
          capturedBody = request.body;
          expect(request.url.path, '/v1/housing/plan-roster');
          return http.Response('', 204);
        }),
      );
      addTearDown(client.close);

      await client.reportPlanRoster(
        planId: 'plan-1',
        revisionId: 'rev-1',
        participantInstallationIds: ['a', 'b'],
      );

      final json = jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(json['plan_id'], 'plan-1');
      expect(json['revision_id'], 'rev-1');
      expect(json['participant_installation_ids'], ['a', 'b']);
    });

    test('uploadPlayToken posts token and parses server expiry', () async {
      String? capturedBody;
      final client = EntitlementClient(
        baseUrl: Uri.parse('http://127.0.0.1:8081'),
        httpClient: MockClient((request) async {
          capturedBody = request.body;
          expect(request.url.path, '/v1/licenses/play-token');
          expect(request.method, 'POST');
          return http.Response(
            jsonEncode({
              'validation_state': 'valid',
              'product_id': 'bojairu.housing',
              'granted_modules': ['housing'],
              'subscription_state': 'SUBSCRIPTION_STATE_ACTIVE',
              'expires_at': '2026-09-15T10:00:00Z',
              'reason': 'active',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.close);

      final got = await client.uploadPlayToken(
        participantInstallationId: 'inst-alpha-device-001',
        productId: 'bojairu.housing',
        purchaseToken: 'play-token-1',
      );

      final json = jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(json['participant_installation_id'], 'inst-alpha-device-001');
      expect(json['product_id'], 'bojairu.housing');
      expect(json['purchase_token'], 'play-token-1');
      expect(json['platform'], 'google_play');
      expect(got.isValid, isTrue);
      expect(got.expiresAt, DateTime.utc(2026, 9, 15, 10));
      expect(got.grantedModules, ['housing']);
    });

    test('uploadPlayToken throws on 503', () async {
      final client = EntitlementClient(
        baseUrl: Uri.parse('http://127.0.0.1:8081'),
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'error': 'play_verifier_unconfigured',
              'message': 'Play purchase verification is not configured',
            }),
            503,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.close);

      try {
        await client.uploadPlayToken(
          participantInstallationId: 'inst-alpha-device-001',
          productId: 'bojairu.housing',
          purchaseToken: 'tok',
        );
        fail('expected EntitlementClientError');
      } on EntitlementClientError catch (e) {
        expect(e.statusCode, 503);
        expect(e.code, 'play_verifier_unconfigured');
      }
    });
  });
}
