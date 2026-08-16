import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../notifications/operator_notice_payload.dart';
import '../../util/product_legal_urls.dart';
import '../../widgets/screen_body_padding.dart';

typedef OperatorNoticeUriLauncher = Future<bool> Function(Uri uri);

/// Message manuel — in-app page opened from an operator FCM notice.
///
/// User-facing AppBar title is localized (French: « Message du développeur »).
class OperatorNoticeScreen extends StatefulWidget {
  const OperatorNoticeScreen({
    super.key,
    this.targetBuild,
    this.consultSite = false,
    this.installedBuildNumber,
    this.siteUri,
    this.playStoreUri,
    this.launchUri,
  });

  static const playBadgeKey = Key('manual-message-play-badge');

  final int? targetBuild;
  final bool consultSite;

  /// When null, loaded from [PackageInfo.fromPlatform].
  final int? installedBuildNumber;

  final Uri? siteUri;
  final Uri? playStoreUri;
  final OperatorNoticeUriLauncher? launchUri;

  @override
  State<OperatorNoticeScreen> createState() => _OperatorNoticeScreenState();
}

class _OperatorNoticeScreenState extends State<OperatorNoticeScreen> {
  int? _installed;

  @override
  void initState() {
    super.initState();
    final given = widget.installedBuildNumber;
    if (given != null) {
      _installed = given;
      return;
    }
    if (widget.targetBuild == null) {
      _installed = 0;
      return;
    }
    PackageInfo.fromPlatform().then((info) {
      if (!mounted) return;
      setState(() => _installed = int.tryParse(info.buildNumber.trim()) ?? 0);
    });
  }

  Future<void> _open(Uri uri) async {
    final launcher =
        widget.launchUri ??
        (u) => launchUrl(u, mode: LaunchMode.externalApplication);
    await launcher(uri);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final installed = _installed;
    final payload = OperatorNoticePayload(
      targetBuild: widget.targetBuild,
      consultSite: widget.consultSite,
    );
    final showUpdate =
        installed != null && payload.showsUpdateAffordance(installed);
    final waitingForBuild =
        widget.targetBuild != null && installed == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.operatorNoticeScreenTitle),
        leading: canPop ? null : BackButton(onPressed: () => context.go('/')),
      ),
      body: ListView(
        padding: screenBodyScrollPadding(context),
        children: [
          if (waitingForBuild)
            const Center(child: CircularProgressIndicator())
          else if (showUpdate) ...[
            Text(l10n.operatorNoticeNewVersionAvailable),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                key: OperatorNoticeScreen.playBadgeKey,
                onTap: () =>
                    _open(widget.playStoreUri ?? googlePlayStoreListingUri),
                child: SvgPicture.asset(
                  googlePlayBadgeAssetForLocale(locale),
                  height: 48,
                  semanticsLabel: l10n.operatorNoticeUpdateTapHint,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(l10n.operatorNoticeUpdateTapHint),
            if (widget.consultSite) const SizedBox(height: 24),
          ],
          if (widget.consultSite) ...[
            Text(l10n.operatorNoticeDeveloperMessagePublished),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _open(
                widget.siteUri ?? developerMessageUrlForLocale(locale),
              ),
              child: Text(l10n.operatorNoticeReadMessage),
            ),
          ],
        ],
      ),
    );
  }
}
