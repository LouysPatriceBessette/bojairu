import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../debug/qa_e2e_meter_photo.dart';
import '../../debug/qa_vehicle_sale_portability_io.dart';
import '../../debug/qa_vehicle_semantics.dart';
import '../../db/app_database.dart';
import '../../db/repositories/vehicles_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../prefs/app_preferences.dart';
import '../../util/display_units.dart';
import '../../util/vehicle_meter_display.dart';
import '../../vehicle/portability/vehicle_sale_bundle.dart';
import '../../vehicle/portability/vehicle_sale_import_service.dart';
import '../../vehicle/portability/vehicle_sale_portability_dialogs.dart';
import '../../vehicle/vehicle_kind.dart';
import '../../vehicle/vehicle_meter_photo_picker.dart';
import '../../vehicle/vehicle_oil_change_interval.dart';
import '../../vehicle/vehicle_owned_active_cap.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/screen_body_padding.dart';
import '../../widgets/vehicle_meter_photo_button.dart';
import '../../widgets/vehicle_narrow_unit_field.dart';
import '../../vehicle/vehicle_consumption_estimation_mode.dart';
import '../../widgets/vehicle_consumption_estimation_mode_fields.dart';
import 'vehicle_add_gallery_section.dart';

class VehicleAddScreen extends StatefulWidget {
  const VehicleAddScreen({super.key, required this.prefs});

  final AppPreferences prefs;

  @override
  State<VehicleAddScreen> createState() => _VehicleAddScreenState();
}

class _VehicleAddScreenState extends State<VehicleAddScreen> {
  final _label = TextEditingController();
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _color = TextEditingController();
  final _year = TextEditingController();
  final _meter = TextEditingController();
  final _tankCapacity = TextEditingController();
  final _oilChangeInterval = TextEditingController();
  final _oilChangeIntervalFocus = FocusNode();
  final _licensePlate = TextEditingController();
  final _vin = TextEditingController();
  VehicleKind _kind = VehicleKind.car;
  VehicleConsumptionEstimationMode _consumptionMode =
      VehicleConsumptionEstimationMode.detailed;
  String? _meterPhotoPath;
  final _galleries = <VehicleGalleryDraft>[];
  bool _saving = false;
  bool _importing = false;
  bool _oilChangeIntervalBlurred = false;

  @override
  void initState() {
    super.initState();
    _oilChangeIntervalFocus.addListener(_onOilChangeIntervalFocus);
    for (final c in [
      _label,
      _make,
      _model,
      _color,
      _year,
      _meter,
      _tankCapacity,
      _oilChangeInterval,
      _licensePlate,
      _vin,
    ]) {
      c.addListener(_refresh);
    }
  }

  void _onOilChangeIntervalFocus() {
    if (!_oilChangeIntervalFocus.hasFocus && mounted) {
      setState(() => _oilChangeIntervalBlurred = true);
    }
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _oilChangeIntervalFocus
      ..removeListener(_onOilChangeIntervalFocus)
      ..dispose();
    for (final c in [
      _label,
      _make,
      _model,
      _color,
      _year,
      _meter,
      _tankCapacity,
      _oilChangeInterval,
      _licensePlate,
      _vin,
    ]) {
      c
        ..removeListener(_refresh)
        ..dispose();
    }
    super.dispose();
  }

  int? get _parsedMeter => parseMeterInputToStoredTenths(
        _meter.text,
        usesHorometer: _kind.usesHorometer,
        distanceUnit: resolveDistanceUnit(widget.prefs),
      );

  int? get _parsedOilChangeInterval => parseOilChangeIntervalToStoredTenths(
        text: _oilChangeInterval.text,
        usesHorometer: _kind.usesHorometer,
        distanceUnit: resolveDistanceUnit(widget.prefs),
      );

  double? get _parsedTankCapacityLiters {
    final tankText = _tankCapacity.text.trim();
    if (tankText.isEmpty) return null;
    final parsed = double.tryParse(tankText.replaceAll(',', '.'));
    if (parsed == null || parsed <= 0) return null;
    return displayVolumeToLiters(
      parsed,
      resolveLiquidVolumeUnit(widget.prefs),
    );
  }

  String? _oilChangeIntervalError(AppLocalizations l10n) {
    if (!_oilChangeIntervalBlurred) return null;
    final issue = oilChangeIntervalValidationIssue(
      text: _oilChangeInterval.text,
      usesHorometer: _kind.usesHorometer,
    );
    return switch (issue) {
      OilChangeIntervalValidationIssue.empty =>
        l10n.vehicleOilChangeIntervalRequired,
      OilChangeIntervalValidationIssue.invalid =>
        l10n.vehicleOilChangeIntervalInvalid,
      OilChangeIntervalValidationIssue.landBelowMin =>
        l10n.vehicleOilChangeIntervalLandMin,
      OilChangeIntervalValidationIssue.landAboveMax =>
        l10n.vehicleOilChangeIntervalLandMax,
      OilChangeIntervalValidationIssue.boatBelowMin =>
        l10n.vehicleOilChangeIntervalBoatMin,
      OilChangeIntervalValidationIssue.boatAboveMax =>
        l10n.vehicleOilChangeIntervalBoatMax,
      null => null,
    };
  }

  bool get _canSave {
    if (_saving) return false;
    if (_label.text.trim().isEmpty) return false;
    if (_make.text.trim().isEmpty) return false;
    if (_model.text.trim().isEmpty) return false;
    if (_color.text.trim().isEmpty) return false;
    final yearText = _year.text.trim();
    if (yearText.length != 4) return false;
    final year = int.tryParse(yearText);
    if (year == null || year < 1900 || year > DateTime.now().year + 1) {
      return false;
    }
    if (_parsedMeter == null) return false;
    if (_parsedTankCapacityLiters == null) return false;
    if (_parsedOilChangeInterval == null) return false;
    if (qaE2eMeterPhotoRequired(otherwiseRequired: true)) {
      if (_meterPhotoPath == null || _meterPhotoPath!.isEmpty) return false;
    }
    return true;
  }

  Future<void> _pickMeterPhoto() async {
    final path = await pickVehicleMeterPhotoSource(context);
    if (path != null && mounted) setState(() => _meterPhotoPath = path);
  }

  Future<void> _confirmImport() async {
    final l10n = AppLocalizations.of(context);
    if (!vehicleSalePortabilitySupportedOnPlatform()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.vehicleImportFailOther)),
      );
      return;
    }
    final confirmed = await showVehicleSaleImportConfirmDialog(context);
    if (!confirmed || !mounted) return;

    final qaBytes = await qaReadVehicleSaleImportZipBytes();
    List<int>? bytes = qaBytes;
    if (bytes == null) {
      final pick = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['zip'],
        withData: true,
      );
      if (pick == null || pick.files.isEmpty || !mounted) return;
      bytes = pick.files.single.bytes;
      if (bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.vehicleImportFailCorrupt)),
        );
        return;
      }
    }

    setState(() => _importing = true);
    try {
      await VehicleSaleImportService(AppDatabase.processScope)
          .importZipBytes(bytes);
      if (!mounted) return;
      context.pop(true);
    } on VehicleActiveCapExceededException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.vehicleOwnedActiveLimitReached)),
      );
    } on VehicleSaleImportException catch (e) {
      if (!mounted) return;
      final message = switch (e.kind) {
        VehicleSaleImportFailureKind.invalidBundle =>
          l10n.vehicleImportFailInvalid,
        VehicleSaleImportFailureKind.corruptArchive =>
          l10n.vehicleImportFailCorrupt,
        VehicleSaleImportFailureKind.other => l10n.vehicleImportFailOther,
      };
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.commonDone),
            ),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(l10n.vehicleImportFailOther),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.commonDone),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    final tankLiters = _parsedTankCapacityLiters!;
    final repo = VehiclesRepository(AppDatabase.processScope);
    final photoPath = qaE2eEffectiveMeterPhotoPath(_meterPhotoPath);
    if (photoPath == null) {
      setState(() => _saving = false);
      return;
    }
    try {
      await repo.createVehicle(
        kind: _kind,
        displayLabel: _label.text.trim(),
        make: _make.text.trim(),
        model: _model.text.trim(),
        color: _color.text.trim(),
        modelYear: int.parse(_year.text.trim()),
        licensePlate: _licensePlate.text.trim(),
        vin: _vin.text.trim(),
        fuelTankCapacityLiters: tankLiters,
        oilChangeIntervalAmount: _parsedOilChangeInterval!,
        initialMeterValue: _parsedMeter!,
        initialMeterPhotoPath: photoPath,
        consumptionEstimationMode: _kind.usesHorometer
            ? VehicleConsumptionEstimationMode.simple
            : _consumptionMode,
        galleries: _galleries.where((g) => g.photos.isNotEmpty).toList(),
      );
    } on VehicleActiveCapExceededException {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).vehicleOwnedActiveLimitReached,
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    context.pop(true);
  }

  String _initialMeterLabel(AppLocalizations l10n) =>
      _kind.usesHorometer
          ? l10n.vehicleFieldInitialHorometer
          : l10n.vehicleFieldInitialOdometer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final distanceUnit = resolveDistanceUnit(widget.prefs);
    final distanceUnitLabel = distanceUnitAbbrev(distanceUnit);
    final volumeUnit =
        liquidVolumeUnitAbbrev(resolveLiquidVolumeUnit(widget.prefs));
    final oilIntervalUnit = oilChangeIntervalUnitSuffix(
      usesHorometer: _kind.usesHorometer,
      distanceUnit: distanceUnit,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.vehicleAddVehicle),
        actions: [
          // Outside the body ListView/ScrollView: Maestro taps on a full-width
          // Semantics child of a scrollable often COMPLETE without firing the
          // action (parent wins / bounds stay max-width). AppBar.actions sizes
          // to the TextButton (2026-07-14 hierarchy: ScrollView ancestor).
          Semantics(
            identifier: kDebugMode ? kQaVehicleImportAction : null,
            button: true,
            onTap: (_saving || _importing) ? null : _confirmImport,
            excludeSemantics: true,
            child: TextButton(
              onPressed: (_saving || _importing) ? null : _confirmImport,
              child: Text(l10n.vehicleImportAction),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: screenBodyScrollPadding(context),
        children: [
          qaVehicleSemantics(
            identifier: kQaVehicleFieldLabel,
            child: AppTextField(
              controller: _label,
              decoration: InputDecoration(labelText: l10n.vehicleFieldLabel),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<VehicleKind>(
            initialValue: _kind,
            decoration: InputDecoration(labelText: l10n.vehicleFieldKind),
            items: VehicleKind.userSelectableKinds
                .map(
                  (k) => DropdownMenuItem(
                    value: k,
                    child: Text(_kindLabel(l10n, k)),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  _kind = v;
                  _oilChangeIntervalBlurred = false;
                  if (v.usesHorometer) {
                    _consumptionMode =
                        VehicleConsumptionEstimationMode.simple;
                  }
                });
              }
            },
          ),
          const SizedBox(height: 12),
          qaVehicleSemantics(
            identifier: kQaVehicleFieldMake,
            child: AppTextField(
              controller: _make,
              decoration: InputDecoration(labelText: l10n.vehicleFieldMake),
            ),
          ),
          const SizedBox(height: 12),
          qaVehicleSemantics(
            identifier: kQaVehicleFieldModel,
            child: AppTextField(
              controller: _model,
              decoration: InputDecoration(labelText: l10n.vehicleFieldModel),
            ),
          ),
          const SizedBox(height: 12),
          qaVehicleSemantics(
            identifier: kQaVehicleFieldColor,
            child: AppTextField(
              controller: _color,
              decoration: InputDecoration(labelText: l10n.vehicleFieldColor),
            ),
          ),
          const SizedBox(height: 12),
          qaVehicleSemantics(
            identifier: kQaVehicleFieldYear,
            child: AppTextField(
              controller: _year,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              decoration: InputDecoration(labelText: l10n.vehicleFieldYear),
            ),
          ),
          const SizedBox(height: 12),
          qaVehicleSemantics(
            identifier: kQaVehicleFieldMeter,
            child: VehicleNarrowUnitField(
              controller: _meter,
              label: _initialMeterLabel(l10n),
              unitSuffix: _kind.usesHorometer ? 'h' : distanceUnitLabel,
              decimal: true,
              meterUsesHorometer: _kind.usesHorometer,
              meterDistanceUnit: distanceUnit,
              onChanged: (_) => _refresh(),
            ),
          ),
          const SizedBox(height: 8),
          VehicleMeterPhotoButton(
            attached:
                _meterPhotoPath != null && _meterPhotoPath!.isNotEmpty,
            onPressed: _pickMeterPhoto,
            label: _meterPhotoPath == null
                ? l10n.vehicleOdometerPhotoLabel
                : l10n.vehicleMeterPhotoAttached,
          ),
          const SizedBox(height: 12),
          qaVehicleSemantics(
            identifier: kQaVehicleFieldTankCapacity,
            child: VehicleNarrowUnitField(
              controller: _tankCapacity,
              label: l10n.vehicleFieldFuelTankCapacity,
              unitSuffix: volumeUnit,
              decimal: true,
              onChanged: (_) => _refresh(),
            ),
          ),
          const SizedBox(height: 12),
          qaVehicleSemantics(
            identifier: kQaVehicleFieldOilInterval,
            child: VehicleNarrowUnitField(
              controller: _oilChangeInterval,
              focusNode: _oilChangeIntervalFocus,
              label: l10n.vehicleFieldFluidChangeFrequency,
              unitSuffix: oilIntervalUnit,
              allowDecimalWithoutDecimalKeyboard: !_kind.usesHorometer,
              errorText: _oilChangeIntervalError(l10n),
              onChanged: (_) => _refresh(),
              onEditingComplete: () =>
                  setState(() => _oilChangeIntervalBlurred = true),
            ),
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _licensePlate,
            decoration: InputDecoration(
              labelText: l10n.vehicleFieldLicensePlate,
              helperText: l10n.vehicleFieldOptional,
            ),
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _vin,
            decoration: InputDecoration(
              labelText: l10n.vehicleFieldVin,
              helperText: l10n.vehicleFieldOptional,
            ),
          ),
          const SizedBox(height: 24),
          VehicleAddGallerySection(
            galleries: _galleries,
            onChanged: _refresh,
          ),
          if (!_kind.usesHorometer) ...[
            const SizedBox(height: 24),
            VehicleConsumptionEstimationModeFields(
              mode: _consumptionMode,
              onModeChanged: (m) => setState(() => _consumptionMode = m),
              prefs: widget.prefs,
              simpleModeSemanticsId: kQaVehicleConsumptionModeSimple,
            ),
          ],
          const SizedBox(height: 24),
          qaVehicleSemantics(
            identifier: kQaVehicleSave,
            child: FilledButton(
              onPressed: _canSave ? _save : null,
              child: Text(l10n.commonSave),
            ),
          ),
        ],
      ),
    );
  }

  String _kindLabel(AppLocalizations l10n, VehicleKind k) => switch (k) {
        VehicleKind.car => l10n.vehicleKindCar,
        VehicleKind.truck => l10n.vehicleKindTruck,
        VehicleKind.motorcycle => l10n.vehicleKindMotorcycle,
        VehicleKind.boat => l10n.vehicleKindBoat,
      };
}
