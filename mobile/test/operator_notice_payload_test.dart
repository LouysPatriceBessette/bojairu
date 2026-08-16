import 'package:compartarenta/notifications/operator_notice_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses FCM data and local tap payload', () {
    final parsed = OperatorNoticePayload.tryParse({
      'v': '1',
      'kind': 'operator_notice',
      'target_build': '39',
      'consult_site': '1',
    });
    expect(parsed, isNotNull);
    expect(parsed!.targetBuild, 39);
    expect(parsed.consultSite, isTrue);
    expect(parsed.showsUpdateAffordance(38), isTrue);
    expect(parsed.showsUpdateAffordance(39), isFalse);
    expect(parsed.showsUpdateAffordance(40), isFalse);
    expect(parsed.localTapPayload, 'operator_notice|39|1');
    final route = Uri.parse(parsed.routeLocation);
    expect(route.path, '/operator-notice');
    expect(route.queryParameters['consult_site'], '1');
    expect(route.queryParameters['target_build'], '39');

    final fromTap = OperatorNoticePayload.tryParseLocalPayload(
      parsed.localTapPayload,
    );
    expect(fromTap!.targetBuild, 39);
    expect(fromTap.consultSite, isTrue);
  });

  test('omits target build and consult_site false', () {
    final parsed = OperatorNoticePayload.tryParse({
      'kind': 'operator_notice',
      'consult_site': '0',
    });
    expect(parsed!.targetBuild, isNull);
    expect(parsed.consultSite, isFalse);
    expect(parsed.showsUpdateAffordance(38), isFalse);
    expect(parsed.localTapPayload, 'operator_notice||0');
    final route = Uri.parse(parsed.routeLocation);
    expect(route.path, '/operator-notice');
    expect(route.queryParameters['consult_site'], '0');
    expect(route.queryParameters.containsKey('target_build'), isFalse);
  });

  test('ignores other kinds', () {
    expect(
      OperatorNoticePayload.tryParse({'kind': 'wake_for_inbox'}),
      isNull,
    );
  });
}
