import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../db/app_database.dart';
import '../../db/repositories/contacts_repository.dart';
import '../../db/repositories/vehicles_repository.dart';
import '../../housing/quiet_hours_week_grid.dart';
import '../../l10n/app_localizations.dart';
import '../../prefs/app_preferences.dart';
import '../../relay/handshake_orchestrator.dart';
import '../../relay/relay_client.dart';
import '../../util/format_money.dart';
import '../../vehicle/vehicle_module_access.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/screen_body_padding.dart';

/// Propriétaire invite form after contact selection.
class VehicleSharingInviteFormScreen extends StatefulWidget {
  const VehicleSharingInviteFormScreen({
    super.key,
    required this.vehicleId,
    required this.contactId,
    required this.prefs,
  });

  final String vehicleId;
  final String contactId;
  final AppPreferences prefs;

  @override
  State<VehicleSharingInviteFormScreen> createState() =>
      _VehicleSharingInviteFormScreenState();
}

class _VehicleSharingInviteFormScreenState
    extends State<VehicleSharingInviteFormScreen> {
  static const _zeroCents = '0';
  static const _kAvailabilityHPad = 12.0;

  final _access = const VehicleModuleAccess();
  final _rateController = TextEditingController(text: _zeroCents);
  final _rateFocus = FocusNode();
  final _rulesController = TextEditingController();
  final _availabilityGrid = quietHoursEmptyGrid();

  String? _contactLabel;
  int _availabilityUiDay = 0;
  bool _availabilityExpanded = false;
  bool _availabilityEditing = false;
  List<List<int>>? _availabilityEditSnapshot;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _rateFocus.addListener(_onRateFocusChange);
    _rateController.addListener(() => setState(() {}));
    _loadContact();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeShowTrackingDisclaimer());
    });
  }

  Future<void> _maybeShowTrackingDisclaimer() async {
    if (!mounted) return;
    if (widget.prefs.vehicleSharingInviteDisclaimerDismissed) return;
    final l10n = AppLocalizations.of(context);
    var doNotShowAgain = false;
    await showAppDialog<void>(
      context: context,
      guardKey: 'vehicle-sharing-invite-disclaimer',
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.vehicleSharingInviteDisclaimerBody1),
                  const SizedBox(height: 12),
                  Text(l10n.vehicleSharingInviteDisclaimerBody2),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                          value: doNotShowAgain,
                          onChanged: (v) {
                            setDialogState(() => doNotShowAgain = v ?? false);
                          },
                          title: Text(
                            l10n.vehicleSharingInviteDisclaimerDoNotShow,
                          ),
                        ),
                      ),
                      FilledButton(
                        onPressed: () async {
                          if (doNotShowAgain) {
                            await widget.prefs
                                .setVehicleSharingInviteDisclaimerDismissed(
                              true,
                            );
                          }
                          if (ctx.mounted) Navigator.of(ctx).pop();
                        },
                        child: Text(l10n.commonOk),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _rateFocus.removeListener(_onRateFocusChange);
    _rateFocus.dispose();
    _rateController.dispose();
    _rulesController.dispose();
    super.dispose();
  }

  void _onRateFocusChange() {
    if (_rateFocus.hasFocus) {
      if (_rateController.text.trim() == _zeroCents) {
        _rateController.clear();
      }
      return;
    }
    if (_rateController.text.trim().isEmpty) {
      _rateController.text = _zeroCents;
    }
  }

  /// Cents (sous) per km; empty field counts as 0.
  int get _rateCentsPerKm {
    final raw = _rateController.text.trim();
    if (raw.isEmpty) return 0;
    return int.tryParse(raw) ?? -1;
  }

  Future<void> _loadContact() async {
    final contact =
        await ContactsRepository(AppDatabase.processScope).get(widget.contactId);
    if (!mounted) return;
    setState(() {
      _contactLabel = contact?.displayName.trim().isNotEmpty == true
          ? contact!.displayName
          : widget.contactId;
    });
  }

  void _toggleAvailabilitySlot(int uiDay, int slot) {
    setState(() {
      final v = _availabilityGrid[uiDay][slot];
      _availabilityGrid[uiDay][slot] = v == 0 ? 1 : 0;
    });
  }

  bool get _availabilityEditHasChanges {
    if (!_availabilityEditing || _availabilityEditSnapshot == null) {
      return false;
    }
    return !quietHoursGridsEqual(
      _availabilityGrid,
      _availabilityEditSnapshot!,
    );
  }

  bool get _availabilityHasAnyMarked {
    for (final day in _availabilityGrid) {
      for (final slot in day) {
        if (slot != 0) return true;
      }
    }
    return false;
  }

  String _encodeAvailabilityWeekJson() {
    if (!_availabilityHasAnyMarked) return '';
    // Binary availability only (0 / 1).
    final normalized = [
      for (final day in _availabilityGrid)
        [for (final slot in day) slot == 0 ? 0 : 1],
    ];
    return jsonEncode(normalized);
  }

  Future<void> _showCopyAvailabilityDayDialog(AppLocalizations l10n) async {
    final firstDayOfWeekIndex = widget.prefs.resolvedFirstDayOfWeekIndex(
      Localizations.localeOf(context),
    );
    final sourceUiDay = _availabilityUiDay;
    final sourceDayName = quietHoursUiDayDisplayName(
      context,
      sourceUiDay,
      firstDayOfWeekIndex,
    );
    final selected = <int>{};

    final copied = await showAppDialog<bool>(
      context: context,
      guardKey: 'vehicleSharing.copyAvailabilityDay',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final targetDays = [
            for (var i = 0; i < kQuietHoursDays; i++)
              if (i != sourceUiDay) i,
          ];
          return AlertDialog(
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.housingQuietHoursCopyDayDialogMessage(sourceDayName),
                  ),
                  const SizedBox(height: 12),
                  for (final uiDay in targetDays)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        quietHoursUiDayDisplayName(
                          ctx,
                          uiDay,
                          firstDayOfWeekIndex,
                        ),
                      ),
                      value: selected.contains(uiDay),
                      onChanged: (v) {
                        setLocal(() {
                          if (v == true) {
                            selected.add(uiDay);
                          } else {
                            selected.remove(uiDay);
                          }
                        });
                      },
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.housingPlanCancel),
              ),
              FilledButton(
                onPressed: selected.isEmpty
                    ? null
                    : () => Navigator.pop(ctx, true),
                child: Text(l10n.commonCopy),
              ),
            ],
          );
        },
      ),
    );

    if (copied != true || !mounted || selected.isEmpty) return;
    setState(() {
      quietHoursCopyUiDay(_availabilityGrid, sourceUiDay, selected);
    });
  }

  int? _parseRateCentsPerKm() {
    final cents = _rateCentsPerKm;
    if (cents < 0) return null;
    return cents;
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!_access.canOfferSharing) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.vehicleSharingOfferBlocked)),
      );
      return;
    }
    if (_availabilityEditing) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.vehicleSharingInviteAvailabilitySaveFirst)),
      );
      return;
    }
    final rateCents = _parseRateCentsPerKm();
    if (rateCents == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.vehicleSharingInviteRateInvalid)),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final currency = widget.prefs.currency.trim().isEmpty
          ? 'CAD'
          : widget.prefs.currency.trim();
      final link =
          await VehiclesRepository(AppDatabase.processScope).createSharingOffer(
        vehicleId: widget.vehicleId,
        borrowerContactId: widget.contactId,
        ratePerKmMinor: rateCents,
        rateCurrency: currency,
        availabilityWeekJson: _encodeAvailabilityWeekJson(),
        ownerRulesText: _rulesController.text.trim(),
      );
      final orch = HandshakeOrchestrator.maybeInstance;
      if (orch != null) {
        try {
          await orch.sendVehicleSharingOffer(
            linkId: link.id,
            borrowerContactId: widget.contactId,
          );
        } on HandshakeOrchestratorError {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.vehicleSharingOfferRelayFailed)),
          );
          context.pop();
          return;
        } on RelayClientError {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.vehicleSharingOfferRelayFailed)),
          );
          context.pop();
          return;
        } on RelayUnreachableException {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.vehicleSharingOfferRelayFailed)),
          );
          context.pop();
          return;
        } on TimeoutException {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.vehicleSharingOfferRelayFailed)),
          );
          context.pop();
          return;
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.vehicleSharingOfferSent)),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
      setState(() => _submitting = false);
    }
  }

  Widget _availabilityActionRow(AppLocalizations l10n) {
    return Align(
      alignment: AlignmentDirectional.topEnd,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: l10n.housingQuietHoursCopyDayTooltip,
            icon: const Icon(Icons.content_paste),
            onPressed: _availabilityEditing && _availabilityEditHasChanges
                ? () => _showCopyAvailabilityDayDialog(l10n)
                : null,
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 2, 4),
            ),
          ),
          IconButton(
            tooltip: l10n.housingAgreementRuleEdit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: _availabilityEditing
                ? null
                : () => setState(() {
                      _availabilityEditSnapshot = quietHoursDeepCopy(
                        _availabilityGrid,
                      );
                      _availabilityEditing = true;
                      _availabilityExpanded = true;
                    }),
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 2, 4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _availabilityCard(AppLocalizations l10n, int firstDay) {
    void onHeaderTap() {
      if (_availabilityExpanded && _availabilityEditing) return;
      setState(() => _availabilityExpanded = !_availabilityExpanded);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onHeaderTap,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                _kAvailabilityHPad,
                4,
                _kAvailabilityHPad,
                4,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(child: Icon(Icons.event_available_outlined)),
                  ),
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(l10n.vehicleSharingInviteAvailabilitySection),
                    ),
                  ),
                  Icon(
                    _availabilityExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                  ),
                ],
              ),
            ),
          ),
          if (_availabilityExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _kAvailabilityHPad,
                0,
                _kAvailabilityHPad,
                12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _availabilityActionRow(l10n),
                  QuietHoursWeekDayEditor(
                    grid: _availabilityGrid,
                    uiSelectedDayIndex: _availabilityUiDay,
                    onSelectDay: (i) =>
                        setState(() => _availabilityUiDay = i),
                    editing: _availabilityEditing,
                    onToggleCell: _toggleAvailabilitySlot,
                    labelAbsolute: l10n.vehicleSharingAvailabilityLevelPrimary,
                    labelModerate: l10n.vehicleSharingAvailabilityLevelPrimary,
                    emptyDayLabel: l10n.housingQuietHoursNoneThisDay,
                    firstDayOfWeekIndex: firstDay,
                  ),
                  if (_availabilityEditing)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          TextButton(
                            onPressed: () => setState(() {
                              if (_availabilityEditSnapshot != null) {
                                quietHoursReplaceFrom(
                                  _availabilityGrid,
                                  _availabilityEditSnapshot!,
                                );
                              }
                              _availabilityEditSnapshot = null;
                              _availabilityEditing = false;
                            }),
                            child: Text(l10n.housingPlanCancel),
                          ),
                          FilledButton(
                            onPressed: () => setState(() {
                              _availabilityEditSnapshot = null;
                              _availabilityEditing = false;
                            }),
                            child: Text(l10n.housingPlanSave),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final firstDay = widget.prefs.resolvedFirstDayOfWeekIndex(
      Localizations.localeOf(context),
    );
    final currency = widget.prefs.currency.trim().isEmpty
        ? 'CAD'
        : widget.prefs.currency.trim();
    final centsPerKm = _rateCentsPerKm < 0 ? 0 : _rateCentsPerKm;
    final per100KmAmount = formatMinorAsMoney(
      context,
      centsPerKm * 100,
      currency,
    );
    final em = Theme.of(context).textTheme.bodyLarge?.fontSize ?? 14;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.vehicleSharingNewShareTitle)),
      body: ListView(
        padding: screenBodyScrollPadding(context),
        children: [
          if (_contactLabel != null) ...[
            Text(
              l10n.vehicleSharingInviteForContact(_contactLabel!),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
          ],
          Text(
            l10n.vehicleSharingInviteRateLabel,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.vehicleSharingInviteRateHelper,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  l10n.vehicleSharingInviteRatePer100Km(per100KmAmount),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 6 * em,
                child: AppTextField(
                  controller: _rateController,
                  focusNode: _rateFocus,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.end,
                  decoration: const InputDecoration(
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _availabilityCard(l10n, firstDay),
          const SizedBox(height: 12),
          AppTextField(
            controller: _rulesController,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: l10n.vehicleSharingInviteRulesLabel,
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: Text(l10n.vehicleSharingInviteSend),
          ),
        ],
      ),
    );
  }
}
