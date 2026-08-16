/// Data-only FCM `kind=operator_notice` (VPS CLI → Message manuel).
/// Long copy is not in the payload.
class OperatorNoticePayload {
  static const kind = 'operator_notice';
  static const localTapPrefix = 'operator_notice|';

  const OperatorNoticePayload({this.targetBuild, required this.consultSite});

  final int? targetBuild;
  final bool consultSite;

  static OperatorNoticePayload? tryParse(Map<String, dynamic> data) {
    if (data['kind']?.toString() != kind) return null;
    return OperatorNoticePayload(
      targetBuild: _parseBuild(data['target_build']),
      consultSite: _parseConsultSite(data['consult_site']),
    );
  }

  static OperatorNoticePayload? tryParseLocalPayload(String payload) {
    if (!payload.startsWith(localTapPrefix)) return null;
    final parts = payload.split('|');
    if (parts.length < 3) {
      return const OperatorNoticePayload(consultSite: false);
    }
    return OperatorNoticePayload(
      targetBuild: _parseBuild(parts[1]),
      consultSite: _parseConsultSite(parts[2]),
    );
  }

  String get localTapPayload {
    final build = targetBuild == null ? '' : '$targetBuild';
    return '$localTapPrefix$build|${consultSite ? '1' : '0'}';
  }

  String get routeLocation {
    final params = <String, String>{
      'consult_site': consultSite ? '1' : '0',
    };
    if (targetBuild != null) {
      params['target_build'] = '$targetBuild';
    }
    return Uri(path: '/operator-notice', queryParameters: params).toString();
  }

  /// Update affordance: installed Play/app build number is strictly below target.
  bool showsUpdateAffordance(int installedBuild) {
    return targetBuild != null && installedBuild < targetBuild!;
  }

  static int? _parseBuild(Object? raw) {
    final s = raw?.toString().trim() ?? '';
    if (s.isEmpty) return null;
    return int.tryParse(s);
  }

  static bool _parseConsultSite(Object? raw) {
    final s = raw?.toString().trim().toLowerCase() ?? '';
    return s == '1' || s == 'true' || s == 'yes';
  }
}
