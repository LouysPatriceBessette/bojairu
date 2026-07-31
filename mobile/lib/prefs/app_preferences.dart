import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/app_database.dart';
import '../debug/local_storage_startup_log.dart';
import '../debug/web_dev_host_session.dart';
import 'regional_unit_choices.dart';
import 'time_zone_policy_field.dart';
import 'week_start.dart';

enum DistanceUnit { km, miles }

enum LiquidVolumeUnit { liter, usGallon, imperialGallon }

enum PlanType { housing }

class AppPreferences extends ChangeNotifier {
  AppPreferences._(this._prefs);

  final SharedPreferences _prefs;

  static const _kOnboardingComplete = 'onboarding.complete';
  static const _kOnboardingStep = 'onboarding.step';
  static const _kOnboardingLanguageDone = 'onboarding.languageDone';
  static const _kOnboardingWelcomeDone = 'onboarding.welcomeDone';

  static const _kDisplayName = 'profile.displayName';
  static const _kAvatarId = 'profile.avatarId';

  static const _kPlanTypes = 'plans.enabled';

  static const _kCurrency = 'prefs.currency';
  static const _kDateFormat = 'prefs.dateFormat';
  static const _kDistanceUnit = 'prefs.distanceUnit';
  static const _kLiquidVolumeUnit = 'prefs.liquidVolumeUnit';
  static const _kTimeZonePolicy = 'prefs.timeZonePolicy';
  static const _kTimeZoneId = 'prefs.timeZoneId';
  static const _kWeekStart = 'prefs.weekStart';
  static const _kLanguageCode = 'prefs.languageCode';

  static const _kNotificationsEnabled = 'notifications.enabled';
  static const _kNotificationsContactAddRequests =
      'notifications.contacts.addRequests';
  static const _kNotificationsContactDisconnection =
      'notifications.contacts.disconnection';
  static const _kNotificationsContactInvitationExpiration =
      'notifications.contacts.invitationExpiration';
  static const _kNotificationsHousingPlanSubmission =
      'notifications.housing.planSubmission';
  static const _kNotificationsHousingDecisionChange =
      'notifications.housing.decisionChange';
  static const _kNotificationsHousingOfferExpiration =
      'notifications.housing.offerExpiration';
  static const _kNotificationsHousingPaymentReminders =
      'notifications.housing.paymentReminders';
  static const _kNotificationsSoundEnabled = 'notifications.sound.enabled';
  static const _kNotificationsCountryStatsEnabled =
      'notifications.countryStats.enabled';
  static const _kNotificationsCountryStatsCode =
      'notifications.countryStats.isoCode';

  /// Default housing draft plan reached the post-wizard summary at least once.
  static const _kHousingDefaultSummaryReached =
      'housing.default.summaryReached';

  /// Vehicle sharing invite form: user dismissed the tracking disclaimer.
  static const _kVehicleSharingInviteDisclaimerDismissed =
      'vehicleSharing.invite.disclaimerDismissed';

  static const _kSandboxMode = 'sandbox.mode';
  static const _kSandboxEnteredAtMs = 'sandbox.enteredAtMs';
  static const _kSandboxInvitedBotCount = 'sandbox.invitedBotCount';
  static const _kSandboxEightHourNudgeShownForEntryMs =
      'sandbox.eightHourNudgeShownForEntryMs';
  static const _kSandboxShowHomeWelcome = 'sandbox.showHomeWelcome';

  /// Legacy single-plan backup key (v1); migrated on read for [housing:default].
  static const _kHousingDefaultPlanDraftBackupLegacy =
      'housing.default.planDraftBackupJson';

  static String _housingPlanDraftBackupKey(String planId) =>
      'housing.planDraftBackup.$planId';

  static String _housingPlanActiveUseStartedKey(String planId) =>
      'licensing.housing.planActiveUseStarted.$planId';

  static Future<AppPreferences> load() async {
    final prefs = await _loadSharedPreferencesWithRetry();
    final appPrefs = AppPreferences._(prefs);
    await appPrefs._reconcileOnboardingAfterProfileOnly();
    return appPrefs;
  }

  static Future<SharedPreferences> _loadSharedPreferencesWithRetry() async {
    const delays = <Duration>[
      Duration.zero,
      Duration(milliseconds: 120),
      Duration(milliseconds: 250),
      Duration(milliseconds: 500),
      Duration(seconds: 1),
    ];
    Object? lastError;
    StackTrace? lastStack;
    for (var i = 0; i < delays.length; i++) {
      if (delays[i] > Duration.zero) {
        await Future<void>.delayed(delays[i]);
      }
      try {
        return await SharedPreferences.getInstance();
      } on MissingPluginException catch (e, st) {
        lastError = e;
        lastStack = st;
      }
    }
    Error.throwWithStackTrace(
      lastError ??
          MissingPluginException(
            'shared_preferences plugin was unavailable after retries',
          ),
      lastStack ?? StackTrace.current,
    );
  }

  bool get onboardingComplete => _prefs.getBool(_kOnboardingComplete) ?? false;

  String? get onboardingStep => _prefs.getString(_kOnboardingStep);
  Future<void> setOnboardingStep(String? value) async {
    if (value == null) {
      await _prefs.remove(_kOnboardingStep);
    } else {
      await _prefs.setString(_kOnboardingStep, value);
    }
    notifyListeners();
  }

  bool get onboardingLanguageDone =>
      _prefs.getBool(_kOnboardingLanguageDone) ?? false;
  Future<void> setOnboardingLanguageDone(bool value) async {
    await _prefs.setBool(_kOnboardingLanguageDone, value);
    notifyListeners();
  }

  bool get onboardingWelcomeDone =>
      _prefs.getBool(_kOnboardingWelcomeDone) ?? false;
  Future<void> setOnboardingWelcomeDone(bool value) async {
    await _prefs.setBool(_kOnboardingWelcomeDone, value);
    notifyListeners();
  }

  String get displayName => _prefs.getString(_kDisplayName) ?? '';
  Future<void> setDisplayName(String value) async {
    await _prefs.setString(_kDisplayName, value.trim());
    notifyListeners();
  }

  String get avatarId => _prefs.getString(_kAvatarId) ?? '';
  Future<void> setAvatarId(String value) async {
    await _prefs.setString(_kAvatarId, value);
    notifyListeners();
  }

  bool get sandboxMode => _prefs.getBool(_kSandboxMode) ?? false;

  Future<void> setSandboxMode(bool value) async {
    await _prefs.setBool(_kSandboxMode, value);
    notifyListeners();
  }

  DateTime? get sandboxEnteredAt {
    final ms = _prefs.getInt(_kSandboxEnteredAtMs);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  Future<void> setSandboxEnteredAt(DateTime? value) async {
    if (value == null) {
      await _prefs.remove(_kSandboxEnteredAtMs);
    } else {
      await _prefs.setInt(
        _kSandboxEnteredAtMs,
        value.toUtc().millisecondsSinceEpoch,
      );
    }
    notifyListeners();
  }

  int get sandboxInvitedBotCount =>
      _prefs.getInt(_kSandboxInvitedBotCount) ?? 0;

  Future<void> setSandboxInvitedBotCount(int value) async {
    await _prefs.setInt(_kSandboxInvitedBotCount, value);
    notifyListeners();
  }

  int? get sandboxEightHourNudgeShownForEntryMs =>
      _prefs.getInt(_kSandboxEightHourNudgeShownForEntryMs);

  Future<void> setSandboxEightHourNudgeShownForEntryMs(int? value) async {
    if (value == null) {
      await _prefs.remove(_kSandboxEightHourNudgeShownForEntryMs);
    } else {
      await _prefs.setInt(_kSandboxEightHourNudgeShownForEntryMs, value);
    }
    notifyListeners();
  }

  bool get sandboxShowHomeWelcome =>
      _prefs.getBool(_kSandboxShowHomeWelcome) ?? false;

  Future<void> setSandboxShowHomeWelcome(bool value) async {
    await _prefs.setBool(_kSandboxShowHomeWelcome, value);
    notifyListeners();
  }

  bool get vehicleSharingInviteDisclaimerDismissed =>
      _prefs.getBool(_kVehicleSharingInviteDisclaimerDismissed) ?? false;

  Future<void> setVehicleSharingInviteDisclaimerDismissed(bool value) async {
    await _prefs.setBool(_kVehicleSharingInviteDisclaimerDismissed, value);
    notifyListeners();
  }

  Future<void> clearSandboxLifecyclePrefs() async {
    await _prefs.remove(_kSandboxMode);
    await _prefs.remove(_kSandboxEnteredAtMs);
    await _prefs.remove(_kSandboxInvitedBotCount);
    await _prefs.remove(_kSandboxEightHourNudgeShownForEntryMs);
    await _prefs.remove(_kSandboxShowHomeWelcome);
    notifyListeners();
  }

  /// Sets display name and avatar in one step with a single [notifyListeners]
  /// so router listeners do not rebuild twice (avoids visible flicker).
  Future<void> setProfileIdentity({
    required String displayName,
    required String avatarId,
  }) async {
    await _prefs.setString(_kDisplayName, displayName.trim());
    await _prefs.setString(_kAvatarId, avatarId);
    notifyListeners();
  }

  Set<PlanType> get planTypes {
    final raw = _prefs.getStringList(_kPlanTypes) ?? const <String>[];
    return raw
        .map((e) => PlanType.values.where((p) => p.name == e).firstOrNull)
        .whereType<PlanType>()
        .toSet();
  }

  Future<void> setPlanTypes(Set<PlanType> value) async {
    await _prefs.setStringList(_kPlanTypes, value.map((e) => e.name).toList());
    notifyListeners();
  }

  String get currency => _prefs.getString(_kCurrency) ?? '';
  Future<void> setCurrency(String value) async {
    await _prefs.setString(_kCurrency, value);
    notifyListeners();
  }

  String get dateFormat => _prefs.getString(_kDateFormat) ?? '';
  Future<void> setDateFormat(String value) async {
    await _prefs.setString(_kDateFormat, value);
    notifyListeners();
  }

  DistanceUnit? get distanceUnit {
    final raw = _prefs.getString(_kDistanceUnit);
    return DistanceUnit.values.where((u) => u.name == raw).firstOrNull;
  }

  Future<void> setDistanceUnit(DistanceUnit value) async {
    await _prefs.setString(_kDistanceUnit, value.name);
    notifyListeners();
  }

  LiquidVolumeUnit? get liquidVolumeUnit {
    final raw = _prefs.getString(_kLiquidVolumeUnit);
    return LiquidVolumeUnit.values.where((u) => u.name == raw).firstOrNull;
  }

  Future<void> setLiquidVolumeUnit(LiquidVolumeUnit value) async {
    await _prefs.setString(_kLiquidVolumeUnit, value.name);
    notifyListeners();
  }

  String get timeZonePolicy => _prefs.getString(_kTimeZonePolicy) ?? 'device';
  Future<void> setTimeZonePolicy(String value) async {
    await _prefs.setString(_kTimeZonePolicy, value);
    notifyListeners();
  }

  /// IANA id when [timeZonePolicy] is explicit (e.g. `America/Toronto`).
  String get timeZoneId => _prefs.getString(_kTimeZoneId) ?? '';

  Future<void> setTimeZoneId(String? ianaId) async {
    if (ianaId == null || ianaId.isEmpty) {
      await _prefs.remove(_kTimeZoneId);
    } else {
      await _prefs.setString(_kTimeZoneId, ianaId);
    }
    notifyListeners();
  }

  /// Persists policy + IANA id in one write and a single [notifyListeners].
  Future<void> applyTimeZonePreference({
    required String policy,
    String? ianaId,
  }) async {
    await _prefs.setString(_kTimeZonePolicy, policy);
    if (ianaId == null || ianaId.isEmpty) {
      await _prefs.remove(_kTimeZoneId);
    } else {
      await _prefs.setString(_kTimeZoneId, ianaId);
    }
    notifyListeners();
  }

  WeekStart? get weekStart =>
      weekStartFromStored(_prefs.getString(_kWeekStart));

  Future<void> setWeekStart(WeekStart value) async {
    await _prefs.setString(_kWeekStart, value.name);
    notifyListeners();
  }

  /// Stored week start, or [defaultWeekStartForLocale] when unset.
  WeekStart resolveWeekStart(Locale locale) {
    return weekStart ?? defaultWeekStartForLocale(locale);
  }

  /// [MaterialLocalizations.firstDayOfWeekIndex] for week grids and pickers.
  int resolvedFirstDayOfWeekIndex(Locale locale) {
    return firstDayOfWeekIndexFor(resolveWeekStart(locale));
  }

  String? get languageCode => _prefs.getString(_kLanguageCode);
  Future<void> setLanguageCode(String? value) async {
    if (value == null || value.isEmpty) {
      await _prefs.remove(_kLanguageCode);
    } else {
      await _prefs.setString(_kLanguageCode, value);
    }
    notifyListeners();
  }

  bool _notificationBool(String key, {bool defaultValue = true}) =>
      _prefs.getBool(key) ?? defaultValue;

  Future<void> _setNotificationBool(String key, bool value) async {
    await _prefs.setBool(key, value);
    notifyListeners();
  }

  bool get notificationsEnabled =>
      _notificationBool(_kNotificationsEnabled, defaultValue: false);
  Future<void> setNotificationsEnabled(bool value) =>
      _setNotificationBool(_kNotificationsEnabled, value);

  bool get notificationContactAddRequests =>
      _notificationBool(_kNotificationsContactAddRequests);
  Future<void> setNotificationContactAddRequests(bool value) =>
      _setNotificationBool(_kNotificationsContactAddRequests, value);

  bool get notificationContactDisconnection =>
      _notificationBool(_kNotificationsContactDisconnection);
  Future<void> setNotificationContactDisconnection(bool value) =>
      _setNotificationBool(_kNotificationsContactDisconnection, value);

  bool get notificationContactInvitationExpiration =>
      _notificationBool(_kNotificationsContactInvitationExpiration);
  Future<void> setNotificationContactInvitationExpiration(bool value) =>
      _setNotificationBool(_kNotificationsContactInvitationExpiration, value);

  bool get notificationHousingPlanSubmission =>
      _notificationBool(_kNotificationsHousingPlanSubmission);
  Future<void> setNotificationHousingPlanSubmission(bool value) =>
      _setNotificationBool(_kNotificationsHousingPlanSubmission, value);

  bool get notificationHousingDecisionChange =>
      _notificationBool(_kNotificationsHousingDecisionChange);
  Future<void> setNotificationHousingDecisionChange(bool value) =>
      _setNotificationBool(_kNotificationsHousingDecisionChange, value);

  bool get notificationHousingOfferExpiration =>
      _notificationBool(_kNotificationsHousingOfferExpiration);
  Future<void> setNotificationHousingOfferExpiration(bool value) =>
      _setNotificationBool(_kNotificationsHousingOfferExpiration, value);

  bool get notificationHousingPaymentReminders =>
      _notificationBool(_kNotificationsHousingPaymentReminders);
  Future<void> setNotificationHousingPaymentReminders(bool value) =>
      _setNotificationBool(_kNotificationsHousingPaymentReminders, value);

  bool get notificationSoundEnabled =>
      _notificationBool(_kNotificationsSoundEnabled);
  Future<void> setNotificationSoundEnabled(bool value) =>
      _setNotificationBool(_kNotificationsSoundEnabled, value);

  /// When true, the user allows sending a two-letter country code with
  /// routing push registration for aggregated relay statistics.
  bool get notificationCountryStatisticsEnabled =>
      _prefs.getBool(_kNotificationsCountryStatsEnabled) ?? false;

  Future<void> setNotificationCountryStatisticsEnabled(bool value) async {
    await _prefs.setBool(_kNotificationsCountryStatsEnabled, value);
    if (!value) {
      await _prefs.remove(_kNotificationsCountryStatsCode);
    }
    notifyListeners();
  }

  /// Two-letter ISO 3166-1 alpha-2 code when [notificationCountryStatisticsEnabled].
  String? get notificationCountryStatisticsCode =>
      _prefs.getString(_kNotificationsCountryStatsCode);

  Future<void> setNotificationCountryStatisticsCode(String? isoAlpha2) async {
    if (isoAlpha2 == null || isoAlpha2.isEmpty) {
      await _prefs.remove(_kNotificationsCountryStatsCode);
    } else {
      await _prefs.setString(
        _kNotificationsCountryStatsCode,
        isoAlpha2.trim().toUpperCase(),
      );
    }
    notifyListeners();
  }

  /// Value sent on routing push registration (`UNDISCLOSED` when disabled).
  String get countryCodeForRoutingPushRegistration {
    if (!notificationCountryStatisticsEnabled) {
      return 'UNDISCLOSED';
    }
    final raw = notificationCountryStatisticsCode;
    if (raw == null || raw.length != 2) {
      return 'UNDISCLOSED';
    }
    return raw.toUpperCase();
  }

  /// At least one category that uses closed-app wake delivery must be on
  /// before the client registers routing push tokens on the relay.
  bool get hasWakeEligibleCategoryEnabled =>
      notificationContactAddRequests ||
      notificationHousingPaymentReminders ||
      notificationHousingPlanSubmission ||
      notificationHousingDecisionChange;

  bool get hasProfile => displayName.isNotEmpty && avatarId.isNotEmpty;
  bool get hasPlanSelection => planTypes.isNotEmpty;

  /// Regional defaults used when onboarding completes (see [applyDefaultRegionalPrefsIfUnset]).
  Future<void> applyDefaultRegionalPrefsIfUnset() async {
    if (currency.isEmpty) {
      await setCurrency(kDefaultCurrencyCode);
    }
    if (dateFormat.isEmpty) {
      await setDateFormat(kDefaultDateFormat);
    }
    if (distanceUnit == null) {
      await setDistanceUnit(DistanceUnit.km);
    }
    if (liquidVolumeUnit == null) {
      await setLiquidVolumeUnit(LiquidVolumeUnit.liter);
    }
    if (weekStart == null) {
      await setWeekStart(WeekStart.sunday);
    }
    if (_prefs.getString(_kTimeZonePolicy) == null) {
      await setTimeZonePolicy(kTimeZonePolicyDevice);
      await setTimeZoneId(null);
    }
  }

  /// Users who finished profile before the removed preferences step.
  Future<void> _reconcileOnboardingAfterProfileOnly() async {
    if (onboardingComplete || !hasProfile) return;
    await completeOnboarding();
  }

  bool get housingDefaultPlanSummaryReached =>
      _prefs.getBool(_kHousingDefaultSummaryReached) ?? false;

  Future<void> setHousingDefaultPlanSummaryReached(bool value) async {
    await _prefs.setBool(_kHousingDefaultSummaryReached, value);
    notifyListeners();
  }

  String? housingPlanDraftBackupJson(String planId) =>
      _prefs.getString(_housingPlanDraftBackupKey(planId));

  Future<void> setHousingPlanDraftBackupJson(
    String planId,
    String? value,
  ) async {
    final key = _housingPlanDraftBackupKey(planId);
    if (value == null || value.isEmpty) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, value);
    }
  }

  /// One-time read of the pre–per-plan backup key (housing:default only).
  String? get housingDefaultPlanDraftBackupJsonLegacy =>
      _prefs.getString(_kHousingDefaultPlanDraftBackupLegacy);

  Future<void> clearHousingDefaultPlanDraftBackupLegacy() async {
    await _prefs.remove(_kHousingDefaultPlanDraftBackupLegacy);
  }

  /// Removes all per-plan housing draft mirror keys (dev database reset).
  Future<void> clearHousingPlanDraftBackupMirrors() async {
    await clearHousingDefaultPlanDraftBackupLegacy();
    for (final key in _prefs.getKeys()) {
      if (key.startsWith('housing.planDraftBackup.')) {
        await _prefs.remove(key);
      }
    }
  }

  Future<void> completeOnboarding() async {
    await applyDefaultRegionalPrefsIfUnset();
    await _prefs.setBool(_kOnboardingComplete, true);
    await _prefs.remove(_kOnboardingStep);
    await _prefs.remove(_kOnboardingLanguageDone);
    await _prefs.remove(_kOnboardingWelcomeDone);
    notifyListeners();
    await _syncWebStorageAfterPrefsWrite();
    if (kDebugMode) {
      try {
        await logLocalStorageCheckpoint(
          AppDatabase.processScope,
          'onboarding-complete',
        );
      } on StateError {
        // Tests / bootstrap ordering.
      }
    }
  }

  Future<void> _syncWebStorageAfterPrefsWrite() async {
    if (!kIsWeb) return;
    try {
      final db = AppDatabase.processScope;
      await db.syncWebStorageToDisk();
      if (kDebugMode) {
        scheduleDevHostSessionSave(db);
      }
    } on StateError {
      // Tests / bootstrap ordering.
    }
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    if (kDebugMode && kIsWeb) {
      unawaited(_syncWebStorageAfterPrefsWrite());
    }
  }

  /// All [SharedPreferences] keys for web dev host session backup.
  Map<String, dynamic> exportDevHostSnapshot() {
    final out = <String, dynamic>{};
    for (final key in _prefs.getKeys()) {
      final value = _prefs.get(key);
      if (value != null) {
        out[key] = value;
      }
    }
    return out;
  }

  /// Restores prefs from [exportDevHostSnapshot] JSON (debug web host session).
  Future<void> importDevHostSnapshot(Map<String, dynamic> snapshot) async {
    for (final entry in snapshot.entries) {
      final key = entry.key;
      final value = entry.value;
      if (value is bool) {
        await _prefs.setBool(key, value);
      } else if (value is int) {
        await _prefs.setInt(key, value);
      } else if (value is double) {
        await _prefs.setDouble(key, value);
      } else if (value is String) {
        await _prefs.setString(key, value);
      } else if (value is List) {
        await _prefs.setStringList(
          key,
          value.map((e) => e.toString()).toList(),
        );
      }
    }
    notifyListeners();
    await _syncWebStorageAfterPrefsWrite();
  }

  /// Development convenience: clears onboarding and user preferences.
  ///
  /// When the housing plan first participated in realized-expense sync (trial clock).
  DateTime? housingPlanActiveUseStartedAt(String planId) {
    final raw = _prefs.getString(_housingPlanActiveUseStartedKey(planId));
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  bool isHousingPlanActiveUseStarted(String planId) =>
      housingPlanActiveUseStartedAt(planId) != null;

  Future<void> markHousingPlanActiveUseStarted(String planId) async {
    final key = _housingPlanActiveUseStartedKey(planId);
    if (_prefs.containsKey(key)) return;
    await _prefs.setString(key, DateTime.now().toUtc().toIso8601String());
    notifyListeners();
  }

  /// This is meant to help iterate during development. It MUST NOT be triggered
  /// automatically in release builds.
  Future<void> resetOnboardingAndPreferences() async {
    await _prefs.remove(_kOnboardingComplete);
    await _prefs.remove(_kOnboardingStep);
    await _prefs.remove(_kOnboardingLanguageDone);
    await _prefs.remove(_kOnboardingWelcomeDone);

    await _prefs.remove(_kDisplayName);
    await _prefs.remove(_kAvatarId);
    await _prefs.remove(_kPlanTypes);

    await _prefs.remove(_kCurrency);
    await _prefs.remove(_kDateFormat);
    await _prefs.remove(_kDistanceUnit);
    await _prefs.remove(_kTimeZonePolicy);
    await _prefs.remove(_kTimeZoneId);
    await _prefs.remove(_kWeekStart);
    await _prefs.remove(_kLanguageCode);

    await _prefs.remove(_kNotificationsEnabled);
    await _prefs.remove(_kNotificationsContactAddRequests);
    await _prefs.remove(_kNotificationsContactDisconnection);
    await _prefs.remove(_kNotificationsContactInvitationExpiration);
    await _prefs.remove(_kNotificationsHousingPlanSubmission);
    await _prefs.remove(_kNotificationsHousingDecisionChange);
    await _prefs.remove(_kNotificationsHousingOfferExpiration);
    await _prefs.remove(_kNotificationsHousingPaymentReminders);
    await _prefs.remove(_kNotificationsSoundEnabled);
    await _prefs.remove(_kNotificationsCountryStatsEnabled);
    await _prefs.remove(_kNotificationsCountryStatsCode);

    await _prefs.remove(_kHousingDefaultSummaryReached);

    notifyListeners();
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
