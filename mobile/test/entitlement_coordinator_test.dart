import 'dart:convert';

import 'package:compartarenta/config/app_config.dart';
import 'package:compartarenta/entitlement/entitlement_client.dart';
import 'package:compartarenta/entitlement/entitlement_coordinator.dart';
import 'package:compartarenta/entitlement/entitlement_plan_id.dart';
import 'package:compartarenta/entitlement/participant_installation_store.dart';
import 'package:compartarenta/entitlement/plan_participant_installation_registry.dart';
import 'package:compartarenta/entitlement/store_receipt_record.dart';
import 'package:compartarenta/relay/envelopes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('resolvePlanParticipantId', () {
    test('maps import tails to full participant ids', () {
      const planId = 'received:pkg-housing-default';
      expect(resolvePlanParticipantId(planId, 'self'),
          '$planId:self');
      expect(resolvePlanParticipantId(planId, 'p0'), '$planId:p0');
      expect(
        resolvePlanParticipantId(planId, '$planId:p1'),
        '$planId:p1',
      );
      expect(
        resolvePlanParticipantId(planId, 'housing:default:p0'),
        'housing:default:p0',
      );
    });
  });

  group('EntitlementCoordinator', () {
    late PlanParticipantInstallationRegistry registry;
    late EntitlementCoordinator coordinator;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      registry = PlanParticipantInstallationRegistry(prefs);
      coordinator = EntitlementCoordinator(
        config: AppConfig(
          environment: AppEnvironment.dev,
          apiBaseUrl: Uri.parse('https://sync.incoherences.org'),
        ),
        installationStore: _FakeInstallationStore('inst-author'),
        registry: registry,
      );
    });

    test('ingestSnapshotsFromPayload stores full participant ids for roster', () async {
      const planId = 'received:pkg-housing-default';
      await coordinator.ingestSnapshotsFromPayload(
        planId: planId,
        payload: {
          'participantSnapshots': [
            {
              'id': 'housing:default:self',
              'participantInstallationId': 'inst-monica',
            },
            {
              'id': 'housing:default:p0',
              'participantInstallationId': 'inst-roberr',
            },
            {
              'id': 'housing:default:p1',
              'participantInstallationId': 'inst-louys',
            },
          ],
        },
        sourceToLocalParticipant: {
          'housing:default:p1': 'self',
          'housing:default:self': 'p0',
          'housing:default:p0': 'p1',
        },
      );

      expect(
        registry.rosterInstallationIds(
          planId: planId,
          participantIds: [
            '$planId:self',
            '$planId:p0',
            '$planId:p1',
          ],
        ),
        ['inst-louys', 'inst-monica', 'inst-roberr'],
      );
    });

    test('ingestParticipantSnapshot uses full participant id keys', () async {
      const planId = 'received:pkg-housing-default';
      await coordinator.ingestParticipantSnapshot(
        planId: planId,
        participantId: '$planId:p1',
        installationId: 'inst-roberr',
      );

      expect(
        registry.installationIdFor(
          planId: planId,
          participantId: '$planId:p1',
        ),
        'inst-roberr',
      );
    });

    test('proposal plus accept responses yield complete roster', () async {
      const planId = 'received:pkg-housing-default';
      await coordinator.ingestSnapshotsFromPayload(
        planId: planId,
        payload: {
          'participantSnapshots': [
            {
              'id': 'housing:default:self',
              'participantInstallationId': 'inst-monica',
            },
          ],
        },
        sourceToLocalParticipant: {
          'housing:default:p1': 'self',
          'housing:default:self': 'p0',
          'housing:default:p0': 'p1',
        },
      );
      await coordinator.ingestParticipantSnapshot(
        planId: planId,
        participantId: '$planId:p1',
        installationId: 'inst-roberr',
      );
      await coordinator.bindSelfParticipant(
        planId: planId,
        selfParticipantId: '$planId:self',
      );

      expect(
        registry.rosterInstallationIds(
          planId: planId,
          participantIds: [
            '$planId:self',
            '$planId:p0',
            '$planId:p1',
          ],
        ),
        ['inst-author', 'inst-monica', 'inst-roberr'],
      );
    });

    test('gateFor uses stable uuid plan id for author plan', () async {
      const localPlanId = 'housing:66666666-6666-4666-8666-666666666666';
      final gate = await coordinator.gateFor(
        planId: localPlanId,
        selfParticipantId: '$localPlanId:self',
        kind: EnvelopeKind.housingRealizedExpensePropose,
      );

      expect(gate, isNotNull);
      expect(gate!.planId, '66666666-6666-4666-8666-666666666666');
      expect(gate.toJson()['plan_id'], '66666666-6666-4666-8666-666666666666');
    });

    test('gateFor passes through non-uuid local plan id', () async {
      const localPlanId = 'housing:default';
      final gate = await coordinator.gateFor(
        planId: localPlanId,
        selfParticipantId: '$localPlanId:self',
        kind: EnvelopeKind.housingRealizedExpensePropose,
      );

      expect(gate, isNotNull);
      expect(
        gate!.planId,
        entitlementPlanIdForLocalPlan(localPlanId),
      );
      expect(
        gate.toJson()['plan_id'],
        'housing:default',
      );
    });

    test('installationIdForSnapshot binds only self participant', () async {
      const planId = 'housing:default';
      final selfId = await coordinator.installationIdForSnapshot(
        planId: planId,
        participantId: '$planId:self',
      );
      expect(selfId, 'inst-author');

      final peerId = await coordinator.installationIdForSnapshot(
        planId: planId,
        participantId: '$planId:p0',
      );
      expect(peerId, isEmpty);

      await registry.setInstallationId(
        planId: planId,
        participantId: '$planId:p0',
        installationId: 'inst-peer-known',
      );
      expect(
        await coordinator.installationIdForSnapshot(
          planId: planId,
          participantId: '$planId:p0',
        ),
        'inst-peer-known',
      );
    });

    test('uploadGooglePlayReceipt returns server expiry', () async {
      final httpClient = MockClient((request) async {
        if (request.url.path.endsWith('/v1/installations/register')) {
          return http.Response('', 204);
        }
        expect(request.url.path, '/v1/licenses/play-token');
        return http.Response(
          jsonEncode({
            'validation_state': 'valid',
            'product_id': 'bojairu.housing',
            'granted_modules': ['housing'],
            'expires_at': '2026-09-15T10:00:00Z',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final coord = EntitlementCoordinator(
        config: AppConfig(
          environment: AppEnvironment.dev,
          apiBaseUrl: Uri.parse('https://sync.incoherences.org'),
          entitlementBaseUrl: Uri.parse('http://127.0.0.1:8081'),
        ),
        installationStore: _FakeInstallationStore('inst-author'),
        registry: registry,
        client: EntitlementClient(
          baseUrl: Uri.parse('http://127.0.0.1:8081'),
          httpClient: httpClient,
        ),
      );
      addTearDown(coord.close);

      final exp = await coord.uploadGooglePlayReceipt(
        StoreReceiptRecord(
          productId: 'bojairu.housing',
          platform: 'google_play',
          purchaseTokenOrReceipt: 'tok',
          purchasedAt: DateTime.utc(2026, 8, 15),
        ),
      );
      expect(exp, DateTime.utc(2026, 9, 15, 10));
    });
  });
}

class _FakeInstallationStore implements ParticipantInstallationStore {
  _FakeInstallationStore(this.id);

  final String id;

  @override
  Future<String> loadOrCreateId() async => id;

  @override
  Future<void> deleteForTesting() async {}
}
