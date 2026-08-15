import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../navigation/app_navigation.dart';

/// Grace or read-only status on the housing hub (OpenSpec 2.2 / 2.3).
class HousingLicenseStatusBanner extends StatelessWidget {
  const HousingLicenseStatusBanner({
    super.key,
    required this.readonly,
    required this.body,
  });

  final bool readonly;
  final String body;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final background = readonly
        ? scheme.errorContainer
        : scheme.tertiaryContainer;
    final foreground = readonly
        ? scheme.onErrorContainer
        : scheme.onTertiaryContainer;
    final title = readonly
        ? l10n.housingLicenseReadonlyBannerTitle
        : l10n.housingLicenseGraceBannerTitle;
    final card = Card(
      color: background,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: Icon(
          readonly ? Icons.lock_outline : Icons.schedule_outlined,
          color: foreground,
        ),
        title: Text(title, style: TextStyle(color: foreground)),
        subtitle: Text(body, style: TextStyle(color: foreground)),
        trailing: Icon(Icons.chevron_right, color: foreground),
        onTap: () => navigateToChild(context, '/licenses'),
      ),
    );
    if (!kDebugMode) return card;
    return Semantics(
      identifier: readonly
          ? 'qa-housing-license-readonly-banner'
          : 'qa-housing-license-grace-banner',
      label: '$title $body',
      child: card,
    );
  }
}
