import 'package:flutter/material.dart';

import '../../activity/relay_activity_log_service.dart';
import '../../db/app_database.dart';
import '../../l10n/app_localizations.dart';
import '../../util/display_date.dart';
import '../../prefs/app_preferences.dart';
import '../../theme/app_theme.dart';
import '../../widgets/screen_body_padding.dart';

class ActivityLogSettingsScreen extends StatefulWidget {
  const ActivityLogSettingsScreen({super.key, required this.prefs});

  final AppPreferences prefs;

  @override
  State<ActivityLogSettingsScreen> createState() =>
      _ActivityLogSettingsScreenState();
}

class _ActivityLogSettingsScreenState extends State<ActivityLogSettingsScreen> {
  final _db = AppDatabase.processScope;
  late Future<List<RelayActivityLogEntry>> _load = _fetch();

  String _emitterFilterKey = RelayActivityLogService.emitterFilterAll;
  DateTime? _fromUtc;
  DateTime? _toUtc;
  bool _emitterFilterEnabled = false;
  bool _dateFilterEnabled = false;

  List<ActivityLogEmitterFilterOption> _emitterOptions = const [];
  bool _emitterOptionsLoading = true;
  bool _emitterOptionsRequested = false;

  bool get _emitterFilterActive =>
      _emitterFilterEnabled &&
      _emitterFilterKey != RelayActivityLogService.emitterFilterAll;

  bool get _dateFilterActive =>
      _dateFilterEnabled && _fromUtc != null && _toUtc != null;

  bool get _hasActiveFilters => _emitterFilterActive || _dateFilterActive;

  Future<List<RelayActivityLogEntry>> _fetch() {
    return RelayActivityLogService(_db).listFiltered(
      fromUtc: _dateFilterActive ? _fromUtc : null,
      toUtc: _dateFilterActive ? _toUtc : null,
      emitterFilterKey: _emitterFilterActive
          ? _emitterFilterKey
          : RelayActivityLogService.emitterFilterAll,
    );
  }

  void _refreshList() {
    setState(() {
      _load = _fetch();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_emitterOptionsRequested) return;
    _emitterOptionsRequested = true;
    _loadEmitterOptions();
  }

  Future<void> _loadEmitterOptions() async {
    final l10n = AppLocalizations.of(context);
    final options = await RelayActivityLogService(_db).emitterFilterOptions(
      selfDisplayName: widget.prefs.displayName,
      allLabel: l10n.activityLogFilterEmitterAll,
      systemLabel: l10n.activityLogFilterEmitterSystem,
      selfFallbackLabel: l10n.activityLogFilterInitiatorSelf,
    );
    if (!mounted) return;
    setState(() {
      _emitterOptions = options;
      _emitterOptionsLoading = false;
      if (!options.any((o) => o.key == _emitterFilterKey)) {
        _emitterFilterKey = RelayActivityLogService.emitterFilterAll;
      }
    });
  }

  String _emptyMessage(AppLocalizations l10n) {
    if (_hasActiveFilters) return l10n.activityLogEmpty;
    return l10n.activityLogNoEntries;
  }

  String _kindLabel(AppLocalizations l10n, String kind) => switch (kind) {
        RelayActivityLogKinds.contactHandshakeReceived =>
          l10n.activityLogKindContactHandshakeReceived,
        RelayActivityLogKinds.contactDisconnected =>
          l10n.activityLogKindContactDisconnected,
        RelayActivityLogKinds.contactDeleted =>
          l10n.activityLogKindContactDeleted,
        RelayActivityLogKinds.housingProposalSent =>
          l10n.activityLogKindHousingProposalSent,
        RelayActivityLogKinds.housingProposalReceived =>
          l10n.activityLogKindHousingProposalReceived,
        RelayActivityLogKinds.housingProposalResponse =>
          l10n.activityLogKindHousingProposalResponse,
        RelayActivityLogKinds.housingProposalInvalidated =>
          l10n.activityLogKindHousingProposalInvalidated,
        RelayActivityLogKinds.housingProposalExpired =>
          l10n.activityLogKindHousingProposalExpired,
        RelayActivityLogKinds.housingProposalForkCreated =>
          l10n.activityLogKindHousingProposalForkCreated,
        RelayActivityLogKinds.housingAgreementActivated =>
          l10n.activityLogKindHousingAgreementActivated,
        RelayActivityLogKinds.housingProposalAgreementExpired =>
          l10n.activityLogKindHousingProposalAgreementExpired,
        RelayActivityLogKinds.housingParticipationChangeAgreementExpired =>
          l10n.activityLogKindHousingParticipationChangeAgreementExpired,
        _ => kind,
      };

  String _emitterLabel(AppLocalizations l10n, RelayActivityLogEntry row) {
    return switch (row.initiatorKind) {
      RelayActivityLogService.initiatorSelf =>
        row.initiatorDisplayName.trim().isNotEmpty
            ? row.initiatorDisplayName.trim()
            : (widget.prefs.displayName.trim().isNotEmpty
                ? widget.prefs.displayName.trim()
                : l10n.activityLogFilterInitiatorSelf),
      RelayActivityLogService.initiatorSystem =>
        l10n.activityLogFilterEmitterSystem,
      RelayActivityLogService.initiatorContact =>
        row.initiatorDisplayName.trim().isNotEmpty
            ? row.initiatorDisplayName.trim()
            : (row.initiatorContactId ??
                l10n.activityLogFilterInitiatorContact),
      _ => row.initiatorDisplayName.trim().isNotEmpty
          ? row.initiatorDisplayName.trim()
          : row.initiatorKind,
    };
  }

  Future<void> _pickDate({required bool isFrom}) async {
    if (!_dateFilterEnabled) return;
    final initial = (isFrom ? _fromUtc : _toUtc)?.toLocal() ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _fromUtc = DateTime.utc(picked.year, picked.month, picked.day);
      } else {
        _toUtc = DateTime.utc(
          picked.year,
          picked.month,
          picked.day,
          23,
          59,
          59,
        );
      }
    });
    _refreshList();
  }

  Widget _filterCheckbox({
    required bool value,
    required String label,
    required ValueChanged<bool?> onChanged,
  }) {
    return Row(
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  Widget _dateChip({
    required String label,
    required VoidCallback? onPressed,
  }) {
    final style = Theme.of(context).textTheme.bodySmall;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dateFmt = effectiveDateFormat(widget.prefs);
    final datePlaceholder = dateFmt;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsActivityLogTitle)),
      body: Column(
        children: [
          ExpansionTile(
            initiallyExpanded: false,
            title: Row(
              children: [
                Text(
                  l10n.activityLogFiltersTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (_hasActiveFilters) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.check_circle,
                    color: AppBrandColors.moneyGreen,
                    size: 20,
                    semanticLabel: l10n.activityLogFiltersTitle,
                  ),
                ],
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 132,
                          child: _filterCheckbox(
                            value: _emitterFilterEnabled,
                            label: l10n.activityLogFilterEmitterLabel,
                            onChanged: (enabled) {
                              if (enabled == null) return;
                              setState(() => _emitterFilterEnabled = enabled);
                              _refreshList();
                            },
                          ),
                        ),
                        Expanded(
                          child: _emitterOptionsLoading
                              ? const LinearProgressIndicator()
                              : DropdownButtonFormField<String>(
                                  key: ValueKey(_emitterFilterKey),
                                  isExpanded: true,
                                  initialValue: _emitterFilterKey,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  items: [
                                    for (final option in _emitterOptions)
                                      DropdownMenuItem(
                                        value: option.key,
                                        child: Text(
                                          option.label,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                  onChanged: _emitterFilterEnabled
                                      ? (key) {
                                          if (key == null) return;
                                          setState(
                                            () => _emitterFilterKey = key,
                                          );
                                          _refreshList();
                                        }
                                      : null,
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 132,
                          child: _filterCheckbox(
                            value: _dateFilterEnabled,
                            label: l10n.activityLogFilterDatesLabel,
                            onChanged: (enabled) {
                              if (enabled == null) return;
                              setState(() => _dateFilterEnabled = enabled);
                              _refreshList();
                            },
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: _dateChip(
                                  label: _fromUtc == null
                                      ? datePlaceholder
                                      : formatPreferenceDate(
                                          _fromUtc,
                                          dateFmt,
                                        ),
                                  onPressed: _dateFilterEnabled
                                      ? () => _pickDate(isFrom: true)
                                      : null,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Text(
                                  '–',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                              Expanded(
                                child: _dateChip(
                                  label: _toUtc == null
                                      ? datePlaceholder
                                      : formatPreferenceDate(
                                          _toUtc,
                                          dateFmt,
                                        ),
                                  onPressed: _dateFilterEnabled
                                      ? () => _pickDate(isFrom: false)
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<RelayActivityLogEntry>>(
              future: _load,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rows = snap.data!;
                if (rows.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _emptyMessage(l10n),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: screenBodyScrollPadding(
                    context,
                    content: EdgeInsets.zero,
                  ),
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    final when = formatPreferenceDateTime(
                      row.occurredAt,
                      dateFmt,
                    );
                    return ListTile(
                      title: Text(_kindLabel(l10n, row.kind)),
                      subtitle: Text(
                        '${_emitterLabel(l10n, row)}\n$when',
                      ),
                      isThreeLine: true,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
