import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('fr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Bojairũ'**
  String get appTitle;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @commonFinishSetup.
  ///
  /// In en, this message translates to:
  /// **'Finish setup'**
  String get commonFinishSetup;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get commonRestart;

  /// No description provided for @commonComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get commonComingSoon;

  /// No description provided for @commonNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get commonNotSet;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get commonSend;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get commonNo;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get commonCopy;

  /// No description provided for @commonPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get commonPaste;

  /// No description provided for @commonBlock.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get commonBlock;

  /// No description provided for @commonUnblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get commonUnblock;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageTitle;

  /// No description provided for @settingsLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Change the app language'**
  String get settingsLanguageSubtitle;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageFrench.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get languageFrench;

  /// No description provided for @languageSpanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get languageSpanish;

  /// No description provided for @settingsProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get settingsProfileTitle;

  /// No description provided for @settingsCurrencyTitle.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get settingsCurrencyTitle;

  /// No description provided for @settingsDateFormatTitle.
  ///
  /// In en, this message translates to:
  /// **'Date format'**
  String get settingsDateFormatTitle;

  /// No description provided for @settingsDistanceUnitTitle.
  ///
  /// In en, this message translates to:
  /// **'Distance unit'**
  String get settingsDistanceUnitTitle;

  /// No description provided for @settingsPrivacyPolicyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get settingsPrivacyPolicyTitle;

  /// No description provided for @settingsAppVersionTitle.
  ///
  /// In en, this message translates to:
  /// **'App version'**
  String get settingsAppVersionTitle;

  /// No description provided for @settingsEnvironmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Environment'**
  String get settingsEnvironmentTitle;

  /// No description provided for @settingsApiBaseUrlTitle.
  ///
  /// In en, this message translates to:
  /// **'API base URL'**
  String get settingsApiBaseUrlTitle;

  /// No description provided for @settingsNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotificationsTitle;

  /// No description provided for @settingsNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Permissions, categories, and sound'**
  String get settingsNotificationsSubtitle;

  /// No description provided for @settingsUnitsTitle.
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get settingsUnitsTitle;

  /// No description provided for @settingsUnitsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Various unit formats'**
  String get settingsUnitsSubtitle;

  /// No description provided for @settingsAboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAboutTitle;

  /// No description provided for @settingsAboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Environment, API URL, and app version'**
  String get settingsAboutSubtitle;

  /// No description provided for @settingsExportImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export / import data'**
  String get settingsExportImportTitle;

  /// No description provided for @settingsExportImportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Full-device security backup and restore'**
  String get settingsExportImportSubtitle;

  /// No description provided for @deviceDataExportSecurityWarning.
  ///
  /// In en, this message translates to:
  /// **'The backup file is unencrypted JSON. Store it securely and do not share it over untrusted channels.'**
  String get deviceDataExportSecurityWarning;

  /// No description provided for @deviceDataExportAction.
  ///
  /// In en, this message translates to:
  /// **'Export all data'**
  String get deviceDataExportAction;

  /// No description provided for @deviceDataImportAction.
  ///
  /// In en, this message translates to:
  /// **'Import backup'**
  String get deviceDataImportAction;

  /// No description provided for @deviceDataExportCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Backup JSON copied to clipboard.'**
  String get deviceDataExportCopiedToClipboard;

  /// No description provided for @deviceDataExportLastSavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved file'**
  String get deviceDataExportLastSavedTitle;

  /// No description provided for @deviceDataExportSavedLocation.
  ///
  /// In en, this message translates to:
  /// **'Documents/Bojairũ/{fileName}'**
  String deviceDataExportSavedLocation(String fileName);

  /// No description provided for @deviceDataExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String deviceDataExportFailed(String error);

  /// No description provided for @deviceDataImportDisabledNoSubscription.
  ///
  /// In en, this message translates to:
  /// **'Import requires an active paid housing subscription on this device.'**
  String get deviceDataImportDisabledNoSubscription;

  /// No description provided for @deviceDataImportDisabledWeb.
  ///
  /// In en, this message translates to:
  /// **'Import is not available on web (development only).'**
  String get deviceDataImportDisabledWeb;

  /// No description provided for @deviceDataReplaceConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace all local data?'**
  String get deviceDataReplaceConfirmTitle;

  /// No description provided for @deviceDataReplaceConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This backup will replace every piece of operational data on this device. This is intended mainly for device replacement.'**
  String get deviceDataReplaceConfirmBody;

  /// No description provided for @deviceDataImportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Backup restored. Relay sync is available again.'**
  String get deviceDataImportSuccess;

  /// No description provided for @deviceDataImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String deviceDataImportFailed(String error);

  /// No description provided for @deviceDataImportValidationFailed.
  ///
  /// In en, this message translates to:
  /// **'Invalid backup file ({code}).'**
  String deviceDataImportValidationFailed(String code);

  /// No description provided for @deviceDataMigrationNetworkFailure.
  ///
  /// In en, this message translates to:
  /// **'Local data was restored but the relay could not be reached. Check your connection and retry migration.'**
  String get deviceDataMigrationNetworkFailure;

  /// No description provided for @deviceDataMigrationFailed.
  ///
  /// In en, this message translates to:
  /// **'Server identity update failed ({code}).'**
  String deviceDataMigrationFailed(String code);

  /// No description provided for @deviceDataMigrationPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Server sync pending'**
  String get deviceDataMigrationPendingTitle;

  /// No description provided for @deviceDataMigrationPendingBody.
  ///
  /// In en, this message translates to:
  /// **'Your data is on this device but the server still needs to link your new installation identity.'**
  String get deviceDataMigrationPendingBody;

  /// No description provided for @deviceDataRetryMigrationAction.
  ///
  /// In en, this message translates to:
  /// **'Retry server sync'**
  String get deviceDataRetryMigrationAction;

  /// No description provided for @deviceDataCanonicalRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore data for which participant?'**
  String get deviceDataCanonicalRestoreTitle;

  /// No description provided for @settingsNotificationsGeneralSection.
  ///
  /// In en, this message translates to:
  /// **'General permission'**
  String get settingsNotificationsGeneralSection;

  /// No description provided for @settingsNotificationsSystemPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'System permission'**
  String get settingsNotificationsSystemPermissionTitle;

  /// No description provided for @settingsNotificationsSystemPermissionBody.
  ///
  /// In en, this message translates to:
  /// **'The app will ask after a relevant action, such as inviting someone.'**
  String get settingsNotificationsSystemPermissionBody;

  /// No description provided for @settingsNotificationsSystemPermissionChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking permission…'**
  String get settingsNotificationsSystemPermissionChecking;

  /// No description provided for @settingsNotificationsSystemPermissionUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Not supported on this platform'**
  String get settingsNotificationsSystemPermissionUnsupported;

  /// No description provided for @settingsNotificationsSystemPermissionUnknown.
  ///
  /// In en, this message translates to:
  /// **'Not requested yet'**
  String get settingsNotificationsSystemPermissionUnknown;

  /// No description provided for @settingsNotificationsSystemPermissionGranted.
  ///
  /// In en, this message translates to:
  /// **'Allowed by the system'**
  String get settingsNotificationsSystemPermissionGranted;

  /// No description provided for @settingsNotificationsSystemPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Blocked by the system'**
  String get settingsNotificationsSystemPermissionDenied;

  /// No description provided for @settingsNotificationsSystemPermissionProvisional.
  ///
  /// In en, this message translates to:
  /// **'Allowed quietly'**
  String get settingsNotificationsSystemPermissionProvisional;

  /// No description provided for @settingsNotificationsRequestAction.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get settingsNotificationsRequestAction;

  /// No description provided for @settingsNotificationsGeneralSwitchTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow app notifications'**
  String get settingsNotificationsGeneralSwitchTitle;

  /// No description provided for @settingsNotificationsGeneralSwitchBody.
  ///
  /// In en, this message translates to:
  /// **'Master switch for notification categories in this app.'**
  String get settingsNotificationsGeneralSwitchBody;

  /// No description provided for @settingsNotificationsWakeFromSleepBody.
  ///
  /// In en, this message translates to:
  /// **'When allowed, the app can register with the relay so a closed app may wake briefly to check for new contact or payment reminders—without showing message content in the push itself.'**
  String get settingsNotificationsWakeFromSleepBody;

  /// No description provided for @settingsNotificationsContactsSection.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get settingsNotificationsContactsSection;

  /// No description provided for @settingsNotificationsContactAddRequest.
  ///
  /// In en, this message translates to:
  /// **'Add requests/confirmations'**
  String get settingsNotificationsContactAddRequest;

  /// No description provided for @settingsNotificationsContactDisconnection.
  ///
  /// In en, this message translates to:
  /// **'Disconnection notices'**
  String get settingsNotificationsContactDisconnection;

  /// No description provided for @settingsNotificationsContactInvitationExpiration.
  ///
  /// In en, this message translates to:
  /// **'Unconsumed invitation expiration'**
  String get settingsNotificationsContactInvitationExpiration;

  /// No description provided for @settingsNotificationsCountryStatsSection.
  ///
  /// In en, this message translates to:
  /// **'User statistics'**
  String get settingsNotificationsCountryStatsSection;

  /// No description provided for @settingsNotificationsCountryStatsSwitchTitle.
  ///
  /// In en, this message translates to:
  /// **'Which country are you located in?'**
  String get settingsNotificationsCountryStatsSwitchTitle;

  /// No description provided for @settingsNotificationsCountryStatsSwitchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Allow sharing your country name. No other personal content will be used. The data is compiled into a per-country user total.'**
  String get settingsNotificationsCountryStatsSwitchSubtitle;

  /// No description provided for @settingsNotificationsCountryStatsPickerLabel.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get settingsNotificationsCountryStatsPickerLabel;

  /// No description provided for @settingsNotificationsCountryStatsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name'**
  String get settingsNotificationsCountryStatsSearchHint;

  /// No description provided for @settingsNotificationsCountryStatsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No matching country'**
  String get settingsNotificationsCountryStatsEmpty;

  /// No description provided for @settingsNotificationsHousingSection.
  ///
  /// In en, this message translates to:
  /// **'Housing'**
  String get settingsNotificationsHousingSection;

  /// No description provided for @settingsNotificationsHousingPlanSubmission.
  ///
  /// In en, this message translates to:
  /// **'Plan submission received'**
  String get settingsNotificationsHousingPlanSubmission;

  /// No description provided for @settingsNotificationsHousingDecisionChange.
  ///
  /// In en, this message translates to:
  /// **'Participant decision status changes'**
  String get settingsNotificationsHousingDecisionChange;

  /// No description provided for @settingsNotificationsHousingOfferExpiration.
  ///
  /// In en, this message translates to:
  /// **'Plan offer expiration without unanimous acceptance'**
  String get settingsNotificationsHousingOfferExpiration;

  /// No description provided for @settingsNotificationsSoundSection.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get settingsNotificationsSoundSection;

  /// No description provided for @settingsNotificationsSoundSwitchTitle.
  ///
  /// In en, this message translates to:
  /// **'Play a sound'**
  String get settingsNotificationsSoundSwitchTitle;

  /// No description provided for @settingsNotificationsSoundSwitchBody.
  ///
  /// In en, this message translates to:
  /// **'Show notifications silently when this is off.'**
  String get settingsNotificationsSoundSwitchBody;

  /// No description provided for @settingsNotificationsSoundPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification sound'**
  String get settingsNotificationsSoundPickerTitle;

  /// No description provided for @settingsNotificationsSoundPickerBody.
  ///
  /// In en, this message translates to:
  /// **'Device sound selection will be added later where platforms allow it safely.'**
  String get settingsNotificationsSoundPickerBody;

  /// No description provided for @settingsNotificationsEnableBlocked.
  ///
  /// In en, this message translates to:
  /// **'System notification permission is not granted.'**
  String get settingsNotificationsEnableBlocked;

  /// No description provided for @notificationFlowPermissionPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable useful notifications?'**
  String get notificationFlowPermissionPromptTitle;

  /// No description provided for @notificationFlowPermissionPromptBody.
  ///
  /// In en, this message translates to:
  /// **'The app can enable the notification permissions needed for what you are about to do.'**
  String get notificationFlowPermissionPromptBody;

  /// No description provided for @notificationFlowPermissionEnableAction.
  ///
  /// In en, this message translates to:
  /// **'Yes, enable them and continue'**
  String get notificationFlowPermissionEnableAction;

  /// No description provided for @notificationFlowPermissionReviewAction.
  ///
  /// In en, this message translates to:
  /// **'I want to check myself'**
  String get notificationFlowPermissionReviewAction;

  /// No description provided for @notificationFlowPermissionNoAction.
  ///
  /// In en, this message translates to:
  /// **'No, continue'**
  String get notificationFlowPermissionNoAction;

  /// No description provided for @onboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'Setup'**
  String get onboardingTitle;

  /// No description provided for @onboardingLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get onboardingLanguageTitle;

  /// No description provided for @onboardingLanguageBody.
  ///
  /// In en, this message translates to:
  /// **'Choose the app language. You can change it anytime in Settings.'**
  String get onboardingLanguageBody;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeIntro.
  ///
  /// In en, this message translates to:
  /// **'Bojairũ is an app developed to help roommates get along better.\n\nBy using this app, you will avoid misunderstandings, oversights, and calculation errors that often lead to conflict. To get the most out of it, enter data as it becomes known.'**
  String get onboardingWelcomeIntro;

  /// No description provided for @onboardingWelcomeConfidentialTitle.
  ///
  /// In en, this message translates to:
  /// **'Confidential'**
  String get onboardingWelcomeConfidentialTitle;

  /// No description provided for @onboardingWelcomeConfidentialBody.
  ///
  /// In en, this message translates to:
  /// **'Finally, real privacy. You can enter your data without any worry. No one other than you and your roommates will have access. This is not just a promise—it is a demonstrable fact. All of the app’s code is public and can be inspected and audited.\n\nThis does imply an important trade-off: there is no way to recover your data if you lose it (loss, theft, or breakage of your device). The app includes an import/export feature that is strongly suggested to use periodically to keep a backup. You are free to put the exported file wherever you want. Securing that backup is your responsibility.'**
  String get onboardingWelcomeConfidentialBody;

  /// No description provided for @onboardingOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get onboardingOk;

  /// No description provided for @onboardingProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Your profile'**
  String get onboardingProfileTitle;

  /// No description provided for @onboardingNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get onboardingNameLabel;

  /// No description provided for @onboardingNameHint.
  ///
  /// In en, this message translates to:
  /// **'Your display name'**
  String get onboardingNameHint;

  /// No description provided for @onboardingAvatarTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose an avatar'**
  String get onboardingAvatarTitle;

  /// No description provided for @onboardingPreferencesTitle.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get onboardingPreferencesTitle;

  /// No description provided for @prefsCurrencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get prefsCurrencyLabel;

  /// No description provided for @prefsCurrencySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by code or name'**
  String get prefsCurrencySearchHint;

  /// No description provided for @prefsDateFormatLabel.
  ///
  /// In en, this message translates to:
  /// **'Date format'**
  String get prefsDateFormatLabel;

  /// No description provided for @prefsDistanceUnitLabel.
  ///
  /// In en, this message translates to:
  /// **'Distance unit'**
  String get prefsDistanceUnitLabel;

  /// No description provided for @prefsDistanceUnitKm.
  ///
  /// In en, this message translates to:
  /// **'Kilometers (km)'**
  String get prefsDistanceUnitKm;

  /// No description provided for @prefsDistanceUnitMiles.
  ///
  /// In en, this message translates to:
  /// **'Miles'**
  String get prefsDistanceUnitMiles;

  /// No description provided for @prefsLiquidVolumeUnitLabel.
  ///
  /// In en, this message translates to:
  /// **'Liquid volume unit'**
  String get prefsLiquidVolumeUnitLabel;

  /// No description provided for @prefsLiquidVolumeUnitLiter.
  ///
  /// In en, this message translates to:
  /// **'Liter'**
  String get prefsLiquidVolumeUnitLiter;

  /// No description provided for @prefsLiquidVolumeUnitUsGallon.
  ///
  /// In en, this message translates to:
  /// **'US gallon (3.785 L)'**
  String get prefsLiquidVolumeUnitUsGallon;

  /// No description provided for @prefsLiquidVolumeUnitImperialGallon.
  ///
  /// In en, this message translates to:
  /// **'Imperial gallon (4.546 L)'**
  String get prefsLiquidVolumeUnitImperialGallon;

  /// No description provided for @prefsWeekStartLabel.
  ///
  /// In en, this message translates to:
  /// **'Week starts on'**
  String get prefsWeekStartLabel;

  /// No description provided for @prefsWeekStartSunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get prefsWeekStartSunday;

  /// No description provided for @prefsWeekStartMonday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get prefsWeekStartMonday;

  /// No description provided for @prefsTimeZoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Time zone'**
  String get prefsTimeZoneLabel;

  /// No description provided for @prefsTimeZoneDevice.
  ///
  /// In en, this message translates to:
  /// **'Use device local time'**
  String get prefsTimeZoneDevice;

  /// No description provided for @prefsTimeZoneSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search time zones'**
  String get prefsTimeZoneSearchHint;

  /// No description provided for @errorSomethingWentWrongTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorSomethingWentWrongTitle;

  /// No description provided for @errorSomethingWentWrongBody.
  ///
  /// In en, this message translates to:
  /// **'Please take a screenshot now and send it with a short description of the steps that led to this error.'**
  String get errorSomethingWentWrongBody;

  /// No description provided for @errorReportBugLink.
  ///
  /// In en, this message translates to:
  /// **'Report this error'**
  String get errorReportBugLink;

  /// No description provided for @errorUnknownOnboardingStep.
  ///
  /// In en, this message translates to:
  /// **'Unknown onboarding step.'**
  String get errorUnknownOnboardingStep;

  /// No description provided for @homeHousingPlan.
  ///
  /// In en, this message translates to:
  /// **'Housing plan'**
  String get homeHousingPlan;

  /// No description provided for @homeModuleContacts.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get homeModuleContacts;

  /// No description provided for @homeModuleHousing.
  ///
  /// In en, this message translates to:
  /// **'Housing'**
  String get homeModuleHousing;

  /// No description provided for @homeModuleVehicle.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get homeModuleVehicle;

  /// No description provided for @homeModuleVehicleSharing.
  ///
  /// In en, this message translates to:
  /// **'Vehicle sharing'**
  String get homeModuleVehicleSharing;

  /// No description provided for @housingPlanSummaryMonthlyTotal.
  ///
  /// In en, this message translates to:
  /// **'Monthly total'**
  String get housingPlanSummaryMonthlyTotal;

  /// No description provided for @housingPlanLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load plan data.\n{error}'**
  String housingPlanLoadError(String error);

  /// No description provided for @housingPlanStepParticipants.
  ///
  /// In en, this message translates to:
  /// **'Participants'**
  String get housingPlanStepParticipants;

  /// No description provided for @housingPlanStepPlanDates.
  ///
  /// In en, this message translates to:
  /// **'Plan dates'**
  String get housingPlanStepPlanDates;

  /// No description provided for @housingPlanStepExpenseCategories.
  ///
  /// In en, this message translates to:
  /// **'Expense categories'**
  String get housingPlanStepExpenseCategories;

  /// No description provided for @housingPlanStepExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get housingPlanStepExpenses;

  /// No description provided for @housingPlanStepSplit.
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get housingPlanStepSplit;

  /// No description provided for @housingPlanStepAgreementRules.
  ///
  /// In en, this message translates to:
  /// **'Agreement rules'**
  String get housingPlanStepAgreementRules;

  /// No description provided for @housingAgreementRulesIntro.
  ///
  /// In en, this message translates to:
  /// **'Turn rules on or off. Fixed rules stay listed even when off so everyone sees what was negotiated. You can add your own rules and remove them until a proposal has been accepted.'**
  String get housingAgreementRulesIntro;

  /// No description provided for @housingAgreementRulesAmendmentIntro.
  ///
  /// In en, this message translates to:
  /// **'Turn optional rules on or off, edit them, add new ones, or remove them. Fixed rules (curfew, early withdrawal, building) stay listed even when off. New rules must be enabled to be included in the proposal.'**
  String get housingAgreementRulesAmendmentIntro;

  /// No description provided for @housingAgreementRuleCurfewTitle.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours calendar'**
  String get housingAgreementRuleCurfewTitle;

  /// No description provided for @housingAgreementRuleCurfewPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Indicative week (no dates): tap a day letter, then use the grid. In edit mode, tap a 30-minute cell to cycle no rule → absolute quiet (red) → moderate quiet (yellow).'**
  String get housingAgreementRuleCurfewPlaceholder;

  /// No description provided for @housingQuietHoursAbsolute.
  ///
  /// In en, this message translates to:
  /// **'Absolute quiet'**
  String get housingQuietHoursAbsolute;

  /// No description provided for @housingQuietHoursModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate quiet'**
  String get housingQuietHoursModerate;

  /// No description provided for @housingQuietHoursNoneThisDay.
  ///
  /// In en, this message translates to:
  /// **'No quiet hours'**
  String get housingQuietHoursNoneThisDay;

  /// No description provided for @housingQuietHoursCopyDayTooltip.
  ///
  /// In en, this message translates to:
  /// **'Copy this day to other days'**
  String get housingQuietHoursCopyDayTooltip;

  /// No description provided for @housingQuietHoursCopyDayDialogMessage.
  ///
  /// In en, this message translates to:
  /// **'Copy the schedule for {sourceDay} to which other days?'**
  String housingQuietHoursCopyDayDialogMessage(String sourceDay);

  /// No description provided for @housingAgreementRuleEarlyWithdrawalTitle.
  ///
  /// In en, this message translates to:
  /// **'Early withdrawal'**
  String get housingAgreementRuleEarlyWithdrawalTitle;

  /// No description provided for @housingAgreementRuleBuildingTitle.
  ///
  /// In en, this message translates to:
  /// **'Building / household rules'**
  String get housingAgreementRuleBuildingTitle;

  /// No description provided for @housingAgreementRuleBuildingHint.
  ///
  /// In en, this message translates to:
  /// **'Suggested topics you can copy or adapt:\nNon-smoking\nNo pets\nNothing stored in hallways\n…'**
  String get housingAgreementRuleBuildingHint;

  /// No description provided for @housingAgreementRuleEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get housingAgreementRuleEdit;

  /// No description provided for @housingAgreementRuleFinishEditing.
  ///
  /// In en, this message translates to:
  /// **'Done editing'**
  String get housingAgreementRuleFinishEditing;

  /// No description provided for @housingAgreementRuleTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a title for this rule.'**
  String get housingAgreementRuleTitleRequired;

  /// No description provided for @housingAgreementSuggestionLabel.
  ///
  /// In en, this message translates to:
  /// **'Suggestion'**
  String get housingAgreementSuggestionLabel;

  /// No description provided for @housingAgreementSuggestionCleanlinessTitle.
  ///
  /// In en, this message translates to:
  /// **'Common area cleanliness'**
  String get housingAgreementSuggestionCleanlinessTitle;

  /// No description provided for @housingAgreementSuggestionCleanlinessBody.
  ///
  /// In en, this message translates to:
  /// **'Keep clothing in assigned storage only.\nClean the shower and toilet after each use.\nWipe kitchen counters after cooking.'**
  String get housingAgreementSuggestionCleanlinessBody;

  /// No description provided for @housingAgreementSuggestionFridgeTitle.
  ///
  /// In en, this message translates to:
  /// **'Fridge management'**
  String get housingAgreementSuggestionFridgeTitle;

  /// No description provided for @housingAgreementSuggestionFridgeBody.
  ///
  /// In en, this message translates to:
  /// **'Label food you do not want to share.\nThrow away expired items regularly.\nKeep shelves and door clean.'**
  String get housingAgreementSuggestionFridgeBody;

  /// No description provided for @housingAgreementRuleRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove rule'**
  String get housingAgreementRuleRemove;

  /// No description provided for @housingAgreementRuleDismissSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Remove from list'**
  String get housingAgreementRuleDismissSuggestion;

  /// No description provided for @housingAgreementRuleAdd.
  ///
  /// In en, this message translates to:
  /// **'Add rule'**
  String get housingAgreementRuleAdd;

  /// No description provided for @housingAgreementRuleAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add agreement rule'**
  String get housingAgreementRuleAddTitle;

  /// No description provided for @housingAgreementRuleCustomTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get housingAgreementRuleCustomTitleLabel;

  /// No description provided for @housingAgreementRuleCustomBodyLabel.
  ///
  /// In en, this message translates to:
  /// **'Details (optional)'**
  String get housingAgreementRuleCustomBodyLabel;

  /// No description provided for @housingAgreementRulesRemovalLockedHint.
  ///
  /// In en, this message translates to:
  /// **'Rules that were part of an accepted proposal cannot be removed; you can still turn them off.'**
  String get housingAgreementRulesRemovalLockedHint;

  /// No description provided for @housingAgreementRuleEarlyWithdrawalDisabledHint.
  ///
  /// In en, this message translates to:
  /// **'Turn this rule on to set minimum notice and penalty.'**
  String get housingAgreementRuleEarlyWithdrawalDisabledHint;

  /// No description provided for @housingPlanParticipantsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} participants'**
  String housingPlanParticipantsCount(int count);

  /// No description provided for @housingPlanFewerParticipantsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Fewer participants'**
  String get housingPlanFewerParticipantsTooltip;

  /// No description provided for @housingPlanMoreParticipantsTooltip.
  ///
  /// In en, this message translates to:
  /// **'More participants'**
  String get housingPlanMoreParticipantsTooltip;

  /// No description provided for @housingPlanAddCategoryTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add expense category'**
  String get housingPlanAddCategoryTooltip;

  /// No description provided for @housingPlanAddExpenseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get housingPlanAddExpenseTooltip;

  /// No description provided for @housingPlanBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get housingPlanBack;

  /// No description provided for @housingPlanNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get housingPlanNext;

  /// No description provided for @housingPlanFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get housingPlanFinish;

  /// No description provided for @housingPlanSplitValidationMessage.
  ///
  /// In en, this message translates to:
  /// **'Each expense or category must total 100% across participants.'**
  String get housingPlanSplitValidationMessage;

  /// No description provided for @housingPlanCouldNotContinue.
  ///
  /// In en, this message translates to:
  /// **'Could not continue: {error}'**
  String housingPlanCouldNotContinue(String error);

  /// No description provided for @housingPlanInviteComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Invite participants (coming soon)'**
  String get housingPlanInviteComingSoon;

  /// No description provided for @housingPlanPreviousPerson.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get housingPlanPreviousPerson;

  /// No description provided for @housingPlanNextPerson.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get housingPlanNextPerson;

  /// No description provided for @housingPlanParticipantNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get housingPlanParticipantNameLabel;

  /// No description provided for @housingPlanChooseContactAction.
  ///
  /// In en, this message translates to:
  /// **'Choose contact'**
  String get housingPlanChooseContactAction;

  /// No description provided for @housingPlanChangeContactAction.
  ///
  /// In en, this message translates to:
  /// **'Change contact'**
  String get housingPlanChangeContactAction;

  /// No description provided for @housingPlanRemoveParticipantHint.
  ///
  /// In en, this message translates to:
  /// **'Drag and drop a contact here to remove it.'**
  String get housingPlanRemoveParticipantHint;

  /// No description provided for @housingPlanContactRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose a contact for each participant before continuing.'**
  String get housingPlanContactRequired;

  /// No description provided for @housingPlanParticipantsMustBeConnected.
  ///
  /// In en, this message translates to:
  /// **'Each co-participant must be a connected contact (they use the app on their own account). Invite them from Contacts first, then select them here.'**
  String get housingPlanParticipantsMustBeConnected;

  /// No description provided for @housingPlanParticipantsPlaceholderNote.
  ///
  /// In en, this message translates to:
  /// **'Co-participants must be connected contacts. The plan keeps a name and avatar snapshot for historical readability.'**
  String get housingPlanParticipantsPlaceholderNote;

  /// No description provided for @housingPlanYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get housingPlanYou;

  /// No description provided for @housingPlanCoParticipantUnnamed.
  ///
  /// In en, this message translates to:
  /// **'Co-participant {index}'**
  String housingPlanCoParticipantUnnamed(int index);

  /// No description provided for @housingPlanPlanStart.
  ///
  /// In en, this message translates to:
  /// **'Plan start'**
  String get housingPlanPlanStart;

  /// No description provided for @housingPlanPlanEnd.
  ///
  /// In en, this message translates to:
  /// **'Plan end'**
  String get housingPlanPlanEnd;

  /// No description provided for @housingPlanDurationLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get housingPlanDurationLabel;

  /// No description provided for @housingPlanEndDateError.
  ///
  /// In en, this message translates to:
  /// **'End date must be after start date (by at least one calendar day).'**
  String get housingPlanEndDateError;

  /// No description provided for @housingPlanCategoriesEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add a category. On the next step you can assign each expense to a category so related items stay together.'**
  String get housingPlanCategoriesEmptyHint;

  /// No description provided for @housingPlanDeleteCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete category'**
  String get housingPlanDeleteCategoryTitle;

  /// No description provided for @housingPlanDeleteCategoryBody.
  ///
  /// In en, this message translates to:
  /// **'Expenses in this category will be unassigned from it. This does not delete the expenses.'**
  String get housingPlanDeleteCategoryBody;

  /// No description provided for @housingPlanCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get housingPlanCancel;

  /// No description provided for @housingPlanDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get housingPlanDelete;

  /// No description provided for @housingPlanTapToAddExpense.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add an expense.'**
  String get housingPlanTapToAddExpense;

  /// No description provided for @housingPlanAddExpensesFirst.
  ///
  /// In en, this message translates to:
  /// **'Add expenses first.'**
  String get housingPlanAddExpensesFirst;

  /// No description provided for @housingPlanAddAtLeastOneExpense.
  ///
  /// In en, this message translates to:
  /// **'Add at least one expense!'**
  String get housingPlanAddAtLeastOneExpense;

  /// No description provided for @housingPlanExpenseAmountsIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Each expense must have an amount greater than zero.'**
  String get housingPlanExpenseAmountsIncomplete;

  /// No description provided for @housingPlanExpenseRecurrenceIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Set recurrence for every recurring expense.'**
  String get housingPlanExpenseRecurrenceIncomplete;

  /// No description provided for @housingPlanExpenseSplitsIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Each expense split must total 100%.'**
  String get housingPlanExpenseSplitsIncomplete;

  /// No description provided for @housingPlanExpenseParticipantsMissing.
  ///
  /// In en, this message translates to:
  /// **'Participants are missing; expenses cannot be validated.'**
  String get housingPlanExpenseParticipantsMissing;

  /// No description provided for @housingPlanSplitNoCategory.
  ///
  /// In en, this message translates to:
  /// **'No category'**
  String get housingPlanSplitNoCategory;

  /// No description provided for @housingPlanWithdrawalIntro.
  ///
  /// In en, this message translates to:
  /// **'Early withdrawal rules.'**
  String get housingPlanWithdrawalIntro;

  /// No description provided for @housingPlanWithdrawalSameForAll.
  ///
  /// In en, this message translates to:
  /// **'Same rule for all participants'**
  String get housingPlanWithdrawalSameForAll;

  /// No description provided for @housingPlanMinimumNoticeDays.
  ///
  /// In en, this message translates to:
  /// **'Minimum notice (days)'**
  String get housingPlanMinimumNoticeDays;

  /// No description provided for @housingPlanPenaltyAmount.
  ///
  /// In en, this message translates to:
  /// **'Penalty amount'**
  String get housingPlanPenaltyAmount;

  /// No description provided for @housingPlanSummaryMissingAgreement.
  ///
  /// In en, this message translates to:
  /// **'Missing agreement'**
  String get housingPlanSummaryMissingAgreement;

  /// No description provided for @housingPlanSummaryMissingParticipants.
  ///
  /// In en, this message translates to:
  /// **'No participants found for this plan. Edit the plan to set them up again.'**
  String get housingPlanSummaryMissingParticipants;

  /// No description provided for @housingPlanSummaryEditPlan.
  ///
  /// In en, this message translates to:
  /// **'Edit plan'**
  String get housingPlanSummaryEditPlan;

  /// No description provided for @housingPlanSummaryInvite.
  ///
  /// In en, this message translates to:
  /// **'Submit my plan'**
  String get housingPlanSummaryInvite;

  /// No description provided for @housingWorkbenchTitle.
  ///
  /// In en, this message translates to:
  /// **'Housing plans'**
  String get housingWorkbenchTitle;

  /// No description provided for @housingWorkbenchDraftsSection.
  ///
  /// In en, this message translates to:
  /// **'Draft(s)'**
  String get housingWorkbenchDraftsSection;

  /// No description provided for @housingWorkbenchPendingSection.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get housingWorkbenchPendingSection;

  /// No description provided for @housingWorkbenchArchivedSection.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get housingWorkbenchArchivedSection;

  /// No description provided for @housingWorkbenchActiveSection.
  ///
  /// In en, this message translates to:
  /// **'Active plans'**
  String get housingWorkbenchActiveSection;

  /// No description provided for @housingWorkbenchSettlementSection.
  ///
  /// In en, this message translates to:
  /// **'Settlement in progress'**
  String get housingWorkbenchSettlementSection;

  /// No description provided for @housingWorkbenchSettlementOpenLabel.
  ///
  /// In en, this message translates to:
  /// **'{planTitle} — settlement'**
  String housingWorkbenchSettlementOpenLabel(String planTitle);

  /// No description provided for @housingWorkbenchOpenPlan.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get housingWorkbenchOpenPlan;

  /// No description provided for @housingWorkbenchEmpty.
  ///
  /// In en, this message translates to:
  /// **'No housing plans with your profile on this device.'**
  String get housingWorkbenchEmpty;

  /// No description provided for @housingActiveHubTitle.
  ///
  /// In en, this message translates to:
  /// **'Active agreement'**
  String get housingActiveHubTitle;

  /// No description provided for @housingActiveHubPeriod.
  ///
  /// In en, this message translates to:
  /// **'{dateRange}'**
  String housingActiveHubPeriod(String dateRange);

  /// No description provided for @housingActiveHubEnterExpense.
  ///
  /// In en, this message translates to:
  /// **'Submit an expense'**
  String get housingActiveHubEnterExpense;

  /// No description provided for @housingActiveHubEnterSettlementDue.
  ///
  /// In en, this message translates to:
  /// **'Submit a due settlement'**
  String get housingActiveHubEnterSettlementDue;

  /// No description provided for @housingActiveHubSettlementAvailableUntil.
  ///
  /// In en, this message translates to:
  /// **'Available until {date}'**
  String housingActiveHubSettlementAvailableUntil(String date);

  /// No description provided for @housingSettlementDueTitle.
  ///
  /// In en, this message translates to:
  /// **'Due settlement'**
  String get housingSettlementDueTitle;

  /// No description provided for @housingSettlementDueSubmit.
  ///
  /// In en, this message translates to:
  /// **'Propose settlement transfer'**
  String get housingSettlementDueSubmit;

  /// No description provided for @housingSettlementDueSuccess.
  ///
  /// In en, this message translates to:
  /// **'Settlement transfer proposed.'**
  String get housingSettlementDueSuccess;

  /// No description provided for @housingSettlementDueTransferDescription.
  ///
  /// In en, this message translates to:
  /// **'End-of-agreement settlement'**
  String get housingSettlementDueTransferDescription;

  /// No description provided for @housingSettlementDueNoCounterparties.
  ///
  /// In en, this message translates to:
  /// **'No outstanding balance with other participants.'**
  String get housingSettlementDueNoCounterparties;

  /// No description provided for @housingActiveHubMonthlyExpenses.
  ///
  /// In en, this message translates to:
  /// **'Accepted expenses'**
  String get housingActiveHubMonthlyExpenses;

  /// No description provided for @housingActiveHubBalances.
  ///
  /// In en, this message translates to:
  /// **'Balances between participants'**
  String get housingActiveHubBalances;

  /// No description provided for @housingActiveHubPaymentStatus.
  ///
  /// In en, this message translates to:
  /// **'Current expenses'**
  String get housingActiveHubPaymentStatus;

  /// No description provided for @housingActiveHubViewPlan.
  ///
  /// In en, this message translates to:
  /// **'View plan'**
  String get housingActiveHubViewPlan;

  /// No description provided for @housingActiveHubRequestAmendment.
  ///
  /// In en, this message translates to:
  /// **'Modify plan'**
  String get housingActiveHubRequestAmendment;

  /// No description provided for @housingActiveHubJournals.
  ///
  /// In en, this message translates to:
  /// **'Journals'**
  String get housingActiveHubJournals;

  /// No description provided for @housingActiveHubExportImport.
  ///
  /// In en, this message translates to:
  /// **'Security backup'**
  String get housingActiveHubExportImport;

  /// No description provided for @housingExportSecurityWarning.
  ///
  /// In en, this message translates to:
  /// **'The export file is unencrypted JSON. Store it securely and do not share it over untrusted channels.'**
  String get housingExportSecurityWarning;

  /// No description provided for @housingExportAction.
  ///
  /// In en, this message translates to:
  /// **'Export agreement data'**
  String get housingExportAction;

  /// No description provided for @housingExportCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Export JSON copied to clipboard.'**
  String get housingExportCopiedToClipboard;

  /// No description provided for @housingExportLastSavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved file'**
  String get housingExportLastSavedTitle;

  /// No description provided for @housingExportSavedLocation.
  ///
  /// In en, this message translates to:
  /// **'Internal storage/Documents/Bojairũ/{fileName}'**
  String housingExportSavedLocation(String fileName);

  /// No description provided for @housingExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String housingExportFailed(String error);

  /// No description provided for @housingImportNotAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get housingImportNotAvailableTitle;

  /// No description provided for @housingImportNotAvailableBody.
  ///
  /// In en, this message translates to:
  /// **'Import requires a valid housing entitlement and will be enabled in a later release.'**
  String get housingImportNotAvailableBody;

  /// No description provided for @housingActiveHubPassPlaceholderTitle.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get housingActiveHubPassPlaceholderTitle;

  /// No description provided for @housingActiveHubPassPlaceholderBody.
  ///
  /// In en, this message translates to:
  /// **'This screen will be available in the next implementation pass.'**
  String get housingActiveHubPassPlaceholderBody;

  /// No description provided for @housingRealizedExpenseTitle.
  ///
  /// In en, this message translates to:
  /// **'Submit an expense'**
  String get housingRealizedExpenseTitle;

  /// No description provided for @housingRealizedExpensePlanLine.
  ///
  /// In en, this message translates to:
  /// **'Plan line'**
  String get housingRealizedExpensePlanLine;

  /// No description provided for @housingRealizedExpenseAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get housingRealizedExpenseAmount;

  /// No description provided for @housingRealizedExpensePaymentDate.
  ///
  /// In en, this message translates to:
  /// **'Payment date'**
  String get housingRealizedExpensePaymentDate;

  /// No description provided for @housingRealizedExpenseTransferDate.
  ///
  /// In en, this message translates to:
  /// **'Transfer date'**
  String get housingRealizedExpenseTransferDate;

  /// No description provided for @housingRealizedExpensePaymentDatePick.
  ///
  /// In en, this message translates to:
  /// **'Select a date'**
  String get housingRealizedExpensePaymentDatePick;

  /// No description provided for @housingRealizedExpensePayer.
  ///
  /// In en, this message translates to:
  /// **'Who paid'**
  String get housingRealizedExpensePayer;

  /// No description provided for @housingRealizedExpenseKind.
  ///
  /// In en, this message translates to:
  /// **'Expense type'**
  String get housingRealizedExpenseKind;

  /// No description provided for @housingRealizedExpenseKindNormal.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get housingRealizedExpenseKindNormal;

  /// No description provided for @housingRealizedExpenseKindReimbursement.
  ///
  /// In en, this message translates to:
  /// **'Reimbursement'**
  String get housingRealizedExpenseKindReimbursement;

  /// No description provided for @housingRealizedExpenseKindAdvance.
  ///
  /// In en, this message translates to:
  /// **'Advance'**
  String get housingRealizedExpenseKindAdvance;

  /// No description provided for @housingRealizedExpenseKindTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get housingRealizedExpenseKindTransfer;

  /// No description provided for @housingRealizedExpenseBeneficiary.
  ///
  /// In en, this message translates to:
  /// **'Whose share is reimbursed'**
  String get housingRealizedExpenseBeneficiary;

  /// No description provided for @housingRealizedExpenseTransferRecipient.
  ///
  /// In en, this message translates to:
  /// **'Participant who received the amount'**
  String get housingRealizedExpenseTransferRecipient;

  /// No description provided for @housingRealizedExpenseTransferRecipientSummary.
  ///
  /// In en, this message translates to:
  /// **'Amount given to {name}'**
  String housingRealizedExpenseTransferRecipientSummary(String name);

  /// No description provided for @housingRealizedExpenseTransferDescription.
  ///
  /// In en, this message translates to:
  /// **'Description / comment (optional)'**
  String get housingRealizedExpenseTransferDescription;

  /// No description provided for @housingRealizedExpenseProofSection.
  ///
  /// In en, this message translates to:
  /// **'Proof (optional)'**
  String get housingRealizedExpenseProofSection;

  /// No description provided for @housingRealizedExpenseProofEncourage.
  ///
  /// In en, this message translates to:
  /// **'Adding a receipt or invoice helps your group validate this expense.'**
  String get housingRealizedExpenseProofEncourage;

  /// No description provided for @housingRealizedExpenseAddProof.
  ///
  /// In en, this message translates to:
  /// **'Add proof'**
  String get housingRealizedExpenseAddProof;

  /// No description provided for @housingRealizedExpensePickCamera.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get housingRealizedExpensePickCamera;

  /// No description provided for @housingRealizedExpenseCapturePhoto.
  ///
  /// In en, this message translates to:
  /// **'Capture photo'**
  String get housingRealizedExpenseCapturePhoto;

  /// No description provided for @housingRealizedExpenseCameraStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not access the camera on this device.'**
  String get housingRealizedExpenseCameraStartFailed;

  /// No description provided for @housingRealizedExpensePickGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get housingRealizedExpensePickGallery;

  /// No description provided for @housingRealizedExpensePickDocument.
  ///
  /// In en, this message translates to:
  /// **'Choose a document'**
  String get housingRealizedExpensePickDocument;

  /// No description provided for @housingRealizedExpenseStoragePath.
  ///
  /// In en, this message translates to:
  /// **'Saved at: {path}'**
  String housingRealizedExpenseStoragePath(String path);

  /// No description provided for @housingRealizedExpenseSaveDraft.
  ///
  /// In en, this message translates to:
  /// **'Save draft'**
  String get housingRealizedExpenseSaveDraft;

  /// No description provided for @housingRealizedExpenseSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit to group'**
  String get housingRealizedExpenseSubmit;

  /// No description provided for @housingRealizedExpenseDraftSaved.
  ///
  /// In en, this message translates to:
  /// **'Draft saved on this device'**
  String get housingRealizedExpenseDraftSaved;

  /// No description provided for @housingRealizedExpenseProposedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Expense submitted for group review'**
  String get housingRealizedExpenseProposedSnackbar;

  /// No description provided for @housingRealizedExpenseValidationLine.
  ///
  /// In en, this message translates to:
  /// **'Select a plan line'**
  String get housingRealizedExpenseValidationLine;

  /// No description provided for @housingRealizedExpenseValidationAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount'**
  String get housingRealizedExpenseValidationAmount;

  /// No description provided for @housingRealizedExpenseValidationPayer.
  ///
  /// In en, this message translates to:
  /// **'Select who paid'**
  String get housingRealizedExpenseValidationPayer;

  /// No description provided for @housingRealizedExpenseValidationDate.
  ///
  /// In en, this message translates to:
  /// **'Select a payment date'**
  String get housingRealizedExpenseValidationDate;

  /// No description provided for @housingRealizedExpenseValidationBeneficiary.
  ///
  /// In en, this message translates to:
  /// **'Select the participant who received the amount'**
  String get housingRealizedExpenseValidationBeneficiary;

  /// No description provided for @housingRealizedExpenseNoPlanLines.
  ///
  /// In en, this message translates to:
  /// **'This agreement has no expense lines yet. Add lines through a plan amendment.'**
  String get housingRealizedExpenseNoPlanLines;

  /// No description provided for @housingRealizedExpenseLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load agreement data'**
  String get housingRealizedExpenseLoadFailed;

  /// No description provided for @housingRealizedExpenseCropTitle.
  ///
  /// In en, this message translates to:
  /// **'Crop proof'**
  String get housingRealizedExpenseCropTitle;

  /// No description provided for @housingRealizedExpenseCropConfirm.
  ///
  /// In en, this message translates to:
  /// **'Use cropped image'**
  String get housingRealizedExpenseCropConfirm;

  /// No description provided for @housingRealizedExpenseCropFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not crop image'**
  String get housingRealizedExpenseCropFailed;

  /// No description provided for @housingRealizedExpenseProofTapToSaveCopy.
  ///
  /// In en, this message translates to:
  /// **'Tap to save a copy'**
  String get housingRealizedExpenseProofTapToSaveCopy;

  /// No description provided for @housingRealizedExpenseProofSaveCopyFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save a copy of the file'**
  String get housingRealizedExpenseProofSaveCopyFailed;

  /// No description provided for @housingRealizedExpenseProofImagesOnly.
  ///
  /// In en, this message translates to:
  /// **'Select an image file only (jpg, jpeg, png, webp, heic).'**
  String get housingRealizedExpenseProofImagesOnly;

  /// No description provided for @housingRealizedExpenseProofImageTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This image is too large to process in the web app. Choose a smaller image or send it another way.'**
  String get housingRealizedExpenseProofImageTooLarge;

  /// No description provided for @housingActiveHubReviewPending.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 expense awaiting your review} other{{count} expenses awaiting your review}}'**
  String housingActiveHubReviewPending(int count);

  /// No description provided for @housingRealizedExpenseReviewListTitle.
  ///
  /// In en, this message translates to:
  /// **'Review expenses'**
  String get housingRealizedExpenseReviewListTitle;

  /// No description provided for @housingRealizedExpenseReviewEmpty.
  ///
  /// In en, this message translates to:
  /// **'No expenses to review.'**
  String get housingRealizedExpenseReviewEmpty;

  /// No description provided for @housingRealizedExpenseReviewWaitingForYou.
  ///
  /// In en, this message translates to:
  /// **'Awaiting your review'**
  String get housingRealizedExpenseReviewWaitingForYou;

  /// No description provided for @housingRealizedExpenseReviewWaitingForOthers.
  ///
  /// In en, this message translates to:
  /// **'Awaiting other participants'**
  String get housingRealizedExpenseReviewWaitingForOthers;

  /// No description provided for @housingRealizedExpenseReviewPublished.
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get housingRealizedExpenseReviewPublished;

  /// No description provided for @housingRealizedExpenseReviewRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get housingRealizedExpenseReviewRejected;

  /// No description provided for @housingRealizedExpenseReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Expense review'**
  String get housingRealizedExpenseReviewTitle;

  /// No description provided for @housingRealizedExpenseReviewTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get housingRealizedExpenseReviewTypeLabel;

  /// No description provided for @housingRealizedExpenseReviewMadeByLabel.
  ///
  /// In en, this message translates to:
  /// **'Made by'**
  String get housingRealizedExpenseReviewMadeByLabel;

  /// No description provided for @housingRealizedExpenseReviewPlanLineLabel.
  ///
  /// In en, this message translates to:
  /// **'Plan line'**
  String get housingRealizedExpenseReviewPlanLineLabel;

  /// No description provided for @housingRealizedExpenseReviewDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description / comment'**
  String get housingRealizedExpenseReviewDescriptionLabel;

  /// No description provided for @housingRealizedExpenseTransferToYouBy.
  ///
  /// In en, this message translates to:
  /// **'Transferred to you by: {name}'**
  String housingRealizedExpenseTransferToYouBy(String name);

  /// No description provided for @housingRealizedExpenseTransferToParticipant.
  ///
  /// In en, this message translates to:
  /// **'Transferred to: {name}'**
  String housingRealizedExpenseTransferToParticipant(String name);

  /// No description provided for @housingRealizedExpenseReviewDescriptionNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get housingRealizedExpenseReviewDescriptionNone;

  /// No description provided for @housingRealizedExpenseReviewAcceptedWord.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get housingRealizedExpenseReviewAcceptedWord;

  /// No description provided for @housingRealizedExpenseReviewRejectedWord.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get housingRealizedExpenseReviewRejectedWord;

  /// No description provided for @housingRealizedExpenseReviewDecisionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Decisions'**
  String get housingRealizedExpenseReviewDecisionsTitle;

  /// No description provided for @housingRealizedExpenseReviewDecisionTableNameColumn.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get housingRealizedExpenseReviewDecisionTableNameColumn;

  /// No description provided for @housingRealizedExpenseReviewDecisionTableDateColumn.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get housingRealizedExpenseReviewDecisionTableDateColumn;

  /// No description provided for @housingRealizedExpenseReviewDecisionPendingShort.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get housingRealizedExpenseReviewDecisionPendingShort;

  /// No description provided for @housingRealizedExpenseReviewDecisionUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get housingRealizedExpenseReviewDecisionUnknown;

  /// No description provided for @housingRealizedExpenseReviewMotifLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get housingRealizedExpenseReviewMotifLabel;

  /// No description provided for @housingRealizedExpenseReviewDecisionPending.
  ///
  /// In en, this message translates to:
  /// **'{name}: pending'**
  String housingRealizedExpenseReviewDecisionPending(String name);

  /// No description provided for @housingRealizedExpenseReviewDecisionAccepted.
  ///
  /// In en, this message translates to:
  /// **'{name}: accepted'**
  String housingRealizedExpenseReviewDecisionAccepted(String name);

  /// No description provided for @housingRealizedExpenseReviewDecisionRejected.
  ///
  /// In en, this message translates to:
  /// **'{name}: rejected'**
  String housingRealizedExpenseReviewDecisionRejected(String name);

  /// No description provided for @housingRealizedExpenseReviewByName.
  ///
  /// In en, this message translates to:
  /// **'by {name}'**
  String housingRealizedExpenseReviewByName(String name);

  /// No description provided for @housingRealizedExpenseReviewAcceptedByOn.
  ///
  /// In en, this message translates to:
  /// **'Accepted by {name} on {when}'**
  String housingRealizedExpenseReviewAcceptedByOn(String name, String when);

  /// No description provided for @housingRealizedExpenseReviewRejectedByOn.
  ///
  /// In en, this message translates to:
  /// **'Rejected by {name} on {when}'**
  String housingRealizedExpenseReviewRejectedByOn(String name, String when);

  /// No description provided for @housingRealizedExpenseTransferReviewHint.
  ///
  /// In en, this message translates to:
  /// **'Make sure you have received the transfer before accepting. There is no deadline.'**
  String get housingRealizedExpenseTransferReviewHint;

  /// No description provided for @housingRealizedExpenseReviewPayer.
  ///
  /// In en, this message translates to:
  /// **'Paid by {name}'**
  String housingRealizedExpenseReviewPayer(String name);

  /// No description provided for @housingRealizedExpenseReviewRejections.
  ///
  /// In en, this message translates to:
  /// **'Rejections'**
  String get housingRealizedExpenseReviewRejections;

  /// No description provided for @housingRealizedExpenseAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get housingRealizedExpenseAccept;

  /// No description provided for @housingRealizedExpenseReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get housingRealizedExpenseReject;

  /// No description provided for @housingRealizedExpenseRejectTitle.
  ///
  /// In en, this message translates to:
  /// **'Reject expense'**
  String get housingRealizedExpenseRejectTitle;

  /// No description provided for @housingRealizedExpenseRejectJustification.
  ///
  /// In en, this message translates to:
  /// **'Reason (required)'**
  String get housingRealizedExpenseRejectJustification;

  /// No description provided for @housingRealizedExpenseRejectConfirm.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get housingRealizedExpenseRejectConfirm;

  /// No description provided for @housingRealizedExpenseAccepted.
  ///
  /// In en, this message translates to:
  /// **'Expense accepted'**
  String get housingRealizedExpenseAccepted;

  /// No description provided for @housingRealizedExpenseRejected.
  ///
  /// In en, this message translates to:
  /// **'Expense rejected'**
  String get housingRealizedExpenseRejected;

  /// No description provided for @housingRealizedExpenseResubmit.
  ///
  /// In en, this message translates to:
  /// **'Correct and resubmit'**
  String get housingRealizedExpenseResubmit;

  /// No description provided for @housingMonthlyExpensesTitle.
  ///
  /// In en, this message translates to:
  /// **'Accepted expenses'**
  String get housingMonthlyExpensesTitle;

  /// No description provided for @housingMonthlyExpensesMonthLabel.
  ///
  /// In en, this message translates to:
  /// **'{year}-{month}'**
  String housingMonthlyExpensesMonthLabel(int year, int month);

  /// No description provided for @housingMonthlyExpensesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No published expenses for this month.'**
  String get housingMonthlyExpensesEmpty;

  /// No description provided for @housingRejectedExpensesTitle.
  ///
  /// In en, this message translates to:
  /// **'Rejected expenses'**
  String get housingRejectedExpensesTitle;

  /// No description provided for @housingRejectedExpensesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No rejected expenses for this month.'**
  String get housingRejectedExpensesEmpty;

  /// No description provided for @housingBalancesTitle.
  ///
  /// In en, this message translates to:
  /// **'Balances between participants'**
  String get housingBalancesTitle;

  /// No description provided for @housingBalancesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No balances yet. Published expenses will appear here.'**
  String get housingBalancesEmpty;

  /// No description provided for @housingBalancesOwes.
  ///
  /// In en, this message translates to:
  /// **'{from} owes {to} {amount}'**
  String housingBalancesOwes(String from, String to, String amount);

  /// No description provided for @housingBalancesModeReal.
  ///
  /// In en, this message translates to:
  /// **'Real'**
  String get housingBalancesModeReal;

  /// No description provided for @housingBalancesModeOptimized.
  ///
  /// In en, this message translates to:
  /// **'Optimized'**
  String get housingBalancesModeOptimized;

  /// No description provided for @housingBalancesLegendTitle.
  ///
  /// In en, this message translates to:
  /// **'Legend'**
  String get housingBalancesLegendTitle;

  /// No description provided for @housingBalancesOwesNobody.
  ///
  /// In en, this message translates to:
  /// **'Owes nobody.'**
  String get housingBalancesOwesNobody;

  /// No description provided for @housingBalancesOwesAmountTo.
  ///
  /// In en, this message translates to:
  /// **'{amount} to {to}'**
  String housingBalancesOwesAmountTo(String amount, String to);

  /// No description provided for @housingBalancesInactiveMarker.
  ///
  /// In en, this message translates to:
  /// **'(former participant)'**
  String get housingBalancesInactiveMarker;

  /// No description provided for @housingExpensePaymentStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Current expenses'**
  String get housingExpensePaymentStatusTitle;

  /// No description provided for @housingExpensePaymentStatusEmpty.
  ///
  /// In en, this message translates to:
  /// **'No plan expenses to display.'**
  String get housingExpensePaymentStatusEmpty;

  /// No description provided for @housingExpensePaymentStatusDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Payments — {expenseName}'**
  String housingExpensePaymentStatusDetailsTitle(String expenseName);

  /// No description provided for @housingExpensePaymentStatusDetailsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No published payments for this expense this month.'**
  String get housingExpensePaymentStatusDetailsEmpty;

  /// No description provided for @housingExpensePaymentStatusDetailsLine.
  ///
  /// In en, this message translates to:
  /// **'{amount} — {date} — {payer}'**
  String housingExpensePaymentStatusDetailsLine(
    String amount,
    String date,
    String payer,
  );

  /// No description provided for @housingRealizedExpenseBudgetCapTitle.
  ///
  /// In en, this message translates to:
  /// **'Monthly budget exceeded'**
  String get housingRealizedExpenseBudgetCapTitle;

  /// No description provided for @housingRealizedExpenseBudgetCapBody.
  ///
  /// In en, this message translates to:
  /// **'This amount exceeds the monthly cap ({cap}) for this plan line. Submit anyway?'**
  String housingRealizedExpenseBudgetCapBody(String cap);

  /// No description provided for @housingRealizedExpenseBudgetCapConfirm.
  ///
  /// In en, this message translates to:
  /// **'Submit anyway'**
  String get housingRealizedExpenseBudgetCapConfirm;

  /// No description provided for @housingRealizedExpensePaymentChartCarryTitle.
  ///
  /// In en, this message translates to:
  /// **'Monthly amount exceeded'**
  String get housingRealizedExpensePaymentChartCarryTitle;

  /// No description provided for @housingRealizedExpensePaymentChartCarryBody.
  ///
  /// In en, this message translates to:
  /// **'This payment exceeds the monthly amount ({monthlyTotal}) for this plan line by {excess}. Should the excess be counted on the next month in the payment status chart?'**
  String housingRealizedExpensePaymentChartCarryBody(
    String monthlyTotal,
    String excess,
  );

  /// No description provided for @housingRealizedExpensePaymentChartCarryNextMonth.
  ///
  /// In en, this message translates to:
  /// **'Carry to next month'**
  String get housingRealizedExpensePaymentChartCarryNextMonth;

  /// No description provided for @housingRealizedExpensePaymentChartCarryCurrentMonth.
  ///
  /// In en, this message translates to:
  /// **'Show on current month'**
  String get housingRealizedExpensePaymentChartCarryCurrentMonth;

  /// No description provided for @housingActivePlanReadOnlyTitle.
  ///
  /// In en, this message translates to:
  /// **'Plan detail'**
  String get housingActivePlanReadOnlyTitle;

  /// No description provided for @housingActivePlanDatesLabel.
  ///
  /// In en, this message translates to:
  /// **'Plan dates'**
  String get housingActivePlanDatesLabel;

  /// No description provided for @housingActivePlanReadOnlyExpenses.
  ///
  /// In en, this message translates to:
  /// **'View expense lines'**
  String get housingActivePlanReadOnlyExpenses;

  /// No description provided for @housingAmendmentRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Modify plan'**
  String get housingAmendmentRequestTitle;

  /// No description provided for @housingAmendmentRequestIntro.
  ///
  /// In en, this message translates to:
  /// **'Choose one change per proposal. Your group must accept unanimously before it takes effect.'**
  String get housingAmendmentRequestIntro;

  /// No description provided for @housingAmendmentPendingBlocks.
  ///
  /// In en, this message translates to:
  /// **'A plan modification is already waiting for responses.'**
  String get housingAmendmentPendingBlocks;

  /// No description provided for @housingAmendmentPickLine.
  ///
  /// In en, this message translates to:
  /// **'Choose a plan line'**
  String get housingAmendmentPickLine;

  /// No description provided for @housingAmendmentTypeLineEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit an expense'**
  String get housingAmendmentTypeLineEdit;

  /// No description provided for @housingAmendmentTypeLineEditHint.
  ///
  /// In en, this message translates to:
  /// **'Title, amount, description, payer, recurrence, or split shares'**
  String get housingAmendmentTypeLineEditHint;

  /// No description provided for @housingAmendmentTypeLineAmount.
  ///
  /// In en, this message translates to:
  /// **'Change a line amount'**
  String get housingAmendmentTypeLineAmount;

  /// No description provided for @housingAmendmentTypeLineAmountHint.
  ///
  /// In en, this message translates to:
  /// **'Update the price for one expense line'**
  String get housingAmendmentTypeLineAmountHint;

  /// No description provided for @housingAmendmentTypeLineRecurrence.
  ///
  /// In en, this message translates to:
  /// **'Change recurrence'**
  String get housingAmendmentTypeLineRecurrence;

  /// No description provided for @housingAmendmentTypeLineRecurrenceHint.
  ///
  /// In en, this message translates to:
  /// **'Update how often one line repeats'**
  String get housingAmendmentTypeLineRecurrenceHint;

  /// No description provided for @housingAmendmentTypeLinePayer.
  ///
  /// In en, this message translates to:
  /// **'Change who pays'**
  String get housingAmendmentTypeLinePayer;

  /// No description provided for @housingAmendmentTypeLinePayerHint.
  ///
  /// In en, this message translates to:
  /// **'Update payment responsibility for one line'**
  String get housingAmendmentTypeLinePayerHint;

  /// No description provided for @housingAmendmentTypeLineAdd.
  ///
  /// In en, this message translates to:
  /// **'Add an expense'**
  String get housingAmendmentTypeLineAdd;

  /// No description provided for @housingAmendmentTypeLineAddHint.
  ///
  /// In en, this message translates to:
  /// **'Add a new expense to the plan'**
  String get housingAmendmentTypeLineAddHint;

  /// No description provided for @housingAmendmentTypeLineRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove an expense'**
  String get housingAmendmentTypeLineRemove;

  /// No description provided for @housingAmendmentTypeLineRemoveHint.
  ///
  /// In en, this message translates to:
  /// **'Retire one line (past expenses stay linked)'**
  String get housingAmendmentTypeLineRemoveHint;

  /// No description provided for @housingAmendmentLineRemoveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove this line from the plan? Existing realized expenses for this line are kept.'**
  String get housingAmendmentLineRemoveConfirm;

  /// No description provided for @housingAmendmentLineRemoveConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Remove line'**
  String get housingAmendmentLineRemoveConfirmAction;

  /// No description provided for @housingAmendmentTypeAgreementEnd.
  ///
  /// In en, this message translates to:
  /// **'Change end date'**
  String get housingAmendmentTypeAgreementEnd;

  /// No description provided for @housingAmendmentTypeAgreementEndHint.
  ///
  /// In en, this message translates to:
  /// **'Extend or shorten the agreement period'**
  String get housingAmendmentTypeAgreementEndHint;

  /// No description provided for @housingAmendmentEndDateSet.
  ///
  /// In en, this message translates to:
  /// **'End date set to {date}'**
  String housingAmendmentEndDateSet(String date);

  /// No description provided for @housingAmendmentTypeRuleChange.
  ///
  /// In en, this message translates to:
  /// **'Change agreement rules'**
  String get housingAmendmentTypeRuleChange;

  /// No description provided for @housingAmendmentTypeRuleChangeHint.
  ///
  /// In en, this message translates to:
  /// **'Edit quiet hours, withdrawal, or other rules'**
  String get housingAmendmentTypeRuleChangeHint;

  /// No description provided for @housingAmendmentRosterChangeTitle.
  ///
  /// In en, this message translates to:
  /// **'Major change'**
  String get housingAmendmentRosterChangeTitle;

  /// No description provided for @housingAmendmentRosterChangeHint.
  ///
  /// In en, this message translates to:
  /// **'Adding or removing roommates requires a new agreement'**
  String get housingAmendmentRosterChangeHint;

  /// No description provided for @housingAmendmentRosterChangeBody.
  ///
  /// In en, this message translates to:
  /// **'Participant changes are not allowed as an in-force amendment. End this agreement or start a new term with a derived version of the current plan.'**
  String get housingAmendmentRosterChangeBody;

  /// No description provided for @housingAgreementRenewalTitle.
  ///
  /// In en, this message translates to:
  /// **'New agreement term'**
  String get housingAgreementRenewalTitle;

  /// No description provided for @housingAgreementRenewalIntro.
  ///
  /// In en, this message translates to:
  /// **'When your agreement period ends or your group changes, start a new unanimous proposal. You can derive it from the current plan to avoid retyping everything.'**
  String get housingAgreementRenewalIntro;

  /// No description provided for @housingAgreementRenewalFork.
  ///
  /// In en, this message translates to:
  /// **'Start new term from this plan'**
  String get housingAgreementRenewalFork;

  /// No description provided for @housingAgreementEndNow.
  ///
  /// In en, this message translates to:
  /// **'End agreement today'**
  String get housingAgreementEndNow;

  /// No description provided for @housingAgreementEndConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'End agreement?'**
  String get housingAgreementEndConfirmTitle;

  /// No description provided for @housingAgreementEndConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'New realized expenses will be blocked after today. You can still review past expenses and start a new term later.'**
  String get housingAgreementEndConfirmBody;

  /// No description provided for @housingAgreementEndConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'End today'**
  String get housingAgreementEndConfirmAction;

  /// No description provided for @housingAgreementEndedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Agreement period closed on this device'**
  String get housingAgreementEndedSnackbar;

  /// No description provided for @housingAgreementExpiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Agreement period ended'**
  String get housingAgreementExpiredTitle;

  /// No description provided for @housingAgreementExpiredBody.
  ///
  /// In en, this message translates to:
  /// **'You cannot enter new realized expenses for this period. Start a new agreement term to continue.'**
  String get housingAgreementExpiredBody;

  /// No description provided for @housingAmendmentDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Requested change'**
  String get housingAmendmentDetailTitle;

  /// No description provided for @housingAmendmentDetailIntro.
  ///
  /// In en, this message translates to:
  /// **'{proposer} proposes to change {subject}.'**
  String housingAmendmentDetailIntro(String proposer, String subject);

  /// No description provided for @housingAmendmentDetailCurrent.
  ///
  /// In en, this message translates to:
  /// **'Currently'**
  String get housingAmendmentDetailCurrent;

  /// No description provided for @housingAmendmentDetailPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previously'**
  String get housingAmendmentDetailPrevious;

  /// No description provided for @housingAmendmentDetailAtRequestTime.
  ///
  /// In en, this message translates to:
  /// **'At the time of the request'**
  String get housingAmendmentDetailAtRequestTime;

  /// No description provided for @housingAmendmentDetailProposed.
  ///
  /// In en, this message translates to:
  /// **'Proposed'**
  String get housingAmendmentDetailProposed;

  /// No description provided for @housingAmendmentSubjectAgreementEnd.
  ///
  /// In en, this message translates to:
  /// **'the agreement end date'**
  String get housingAmendmentSubjectAgreementEnd;

  /// No description provided for @housingAmendmentSubjectLineEdit.
  ///
  /// In en, this message translates to:
  /// **'the expense “{line}”'**
  String housingAmendmentSubjectLineEdit(String line);

  /// No description provided for @housingAmendmentSubjectLineAmount.
  ///
  /// In en, this message translates to:
  /// **'the amount for “{line}”'**
  String housingAmendmentSubjectLineAmount(String line);

  /// No description provided for @housingAmendmentSubjectLineRecurrence.
  ///
  /// In en, this message translates to:
  /// **'the recurrence for “{line}”'**
  String housingAmendmentSubjectLineRecurrence(String line);

  /// No description provided for @housingAmendmentSubjectLinePayer.
  ///
  /// In en, this message translates to:
  /// **'who pays for “{line}”'**
  String housingAmendmentSubjectLinePayer(String line);

  /// No description provided for @housingAmendmentSubjectLineAdd.
  ///
  /// In en, this message translates to:
  /// **'the plan (new expense line)'**
  String get housingAmendmentSubjectLineAdd;

  /// No description provided for @housingAmendmentSubjectLineRemove.
  ///
  /// In en, this message translates to:
  /// **'the plan (remove “{line}”)'**
  String housingAmendmentSubjectLineRemove(String line);

  /// No description provided for @housingAmendmentSubjectRuleChange.
  ///
  /// In en, this message translates to:
  /// **'the agreement rules'**
  String get housingAmendmentSubjectRuleChange;

  /// No description provided for @housingAmendmentValueNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get housingAmendmentValueNotSet;

  /// No description provided for @housingAmendmentValueNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get housingAmendmentValueNone;

  /// No description provided for @housingAmendmentValueRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed from plan'**
  String get housingAmendmentValueRemoved;

  /// No description provided for @housingAmendmentUnknownLine.
  ///
  /// In en, this message translates to:
  /// **'this line'**
  String get housingAmendmentUnknownLine;

  /// No description provided for @housingAmendmentRulesCurrentPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Current rules (summary coming soon)'**
  String get housingAmendmentRulesCurrentPlaceholder;

  /// No description provided for @housingAmendmentRulesProposedPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Proposed rules (summary coming soon)'**
  String get housingAmendmentRulesProposedPlaceholder;

  /// No description provided for @housingActiveHubPendingAmendment.
  ///
  /// In en, this message translates to:
  /// **'There is a change request'**
  String get housingActiveHubPendingAmendment;

  /// No description provided for @housingAmendmentDetailLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get housingAmendmentDetailLoading;

  /// No description provided for @housingAmendmentAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get housingAmendmentAccept;

  /// No description provided for @housingAmendmentReject.
  ///
  /// In en, this message translates to:
  /// **'Refuse'**
  String get housingAmendmentReject;

  /// No description provided for @housingAmendmentSubmitToGroup.
  ///
  /// In en, this message translates to:
  /// **'Submit to the group'**
  String get housingAmendmentSubmitToGroup;

  /// No description provided for @housingAmendmentRulesContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get housingAmendmentRulesContinue;

  /// No description provided for @housingAmendmentRulesModifiedWhileDisabledBody.
  ///
  /// In en, this message translates to:
  /// **'You changed a rule without turning it on. Are you sure you did not forget something?'**
  String get housingAmendmentRulesModifiedWhileDisabledBody;

  /// No description provided for @housingAmendmentRulesModifiedWhileDisabledReview.
  ///
  /// In en, this message translates to:
  /// **'I want to check'**
  String get housingAmendmentRulesModifiedWhileDisabledReview;

  /// No description provided for @housingAmendmentRulesModifiedWhileDisabledContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue anyway'**
  String get housingAmendmentRulesModifiedWhileDisabledContinue;

  /// No description provided for @housingAgreementRuleStatusEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get housingAgreementRuleStatusEnabled;

  /// No description provided for @housingAgreementRuleStatusDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get housingAgreementRuleStatusDisabled;

  /// No description provided for @housingAmendmentPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Request preview'**
  String get housingAmendmentPreviewTitle;

  /// No description provided for @housingAmendmentPreviewIntro.
  ///
  /// In en, this message translates to:
  /// **'Review the proposed change to {subject} before sending it to the group.'**
  String housingAmendmentPreviewIntro(String subject);

  /// No description provided for @housingAmendmentNoMeaningfulChange.
  ///
  /// In en, this message translates to:
  /// **'There is no change compared to the current plan.'**
  String get housingAmendmentNoMeaningfulChange;

  /// No description provided for @housingAmendmentRequestStatusAction.
  ///
  /// In en, this message translates to:
  /// **'Request status'**
  String get housingAmendmentRequestStatusAction;

  /// No description provided for @housingAmendmentJournalTitle.
  ///
  /// In en, this message translates to:
  /// **'Plan changes'**
  String get housingAmendmentJournalTitle;

  /// No description provided for @housingJournalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Journals'**
  String get housingJournalsTitle;

  /// No description provided for @housingAmendmentJournalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Accepted and refused requests'**
  String get housingAmendmentJournalSubtitle;

  /// No description provided for @housingAmendmentJournalSubjectAgreementEnd.
  ///
  /// In en, this message translates to:
  /// **'Agreement end date'**
  String get housingAmendmentJournalSubjectAgreementEnd;

  /// No description provided for @housingAmendmentJournalLineAdd.
  ///
  /// In en, this message translates to:
  /// **'Expense added - {title} - {amount}'**
  String housingAmendmentJournalLineAdd(String title, String amount);

  /// No description provided for @housingAmendmentJournalLineEdit.
  ///
  /// In en, this message translates to:
  /// **'Expense modified - {title} - {amount}'**
  String housingAmendmentJournalLineEdit(String title, String amount);

  /// No description provided for @housingAmendmentJournalLineRemove.
  ///
  /// In en, this message translates to:
  /// **'Expense removed - {title} - {amount}'**
  String housingAmendmentJournalLineRemove(String title, String amount);

  /// No description provided for @housingAmendmentJournalEmpty.
  ///
  /// In en, this message translates to:
  /// **'No plan changes yet.'**
  String get housingAmendmentJournalEmpty;

  /// No description provided for @housingAmendmentJournalAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get housingAmendmentJournalAccepted;

  /// No description provided for @housingAmendmentJournalRefused.
  ///
  /// In en, this message translates to:
  /// **'Refused'**
  String get housingAmendmentJournalRefused;

  /// No description provided for @housingAmendmentJournalCardTitle.
  ///
  /// In en, this message translates to:
  /// **'{subject} — {status}'**
  String housingAmendmentJournalCardTitle(String subject, String status);

  /// No description provided for @housingAmendmentJournalCardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'By {name} · {date}'**
  String housingAmendmentJournalCardSubtitle(String name, String date);

  /// No description provided for @housingAmendmentRulesSummaryShort.
  ///
  /// In en, this message translates to:
  /// **'Agreement rules updated'**
  String get housingAmendmentRulesSummaryShort;

  /// No description provided for @housingAmendmentRulesGroupAdded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Added rule ({count})} other{Added rules ({count})}}'**
  String housingAmendmentRulesGroupAdded(int count);

  /// No description provided for @housingAmendmentRulesGroupModified.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Modified rule ({count})} other{Modified rules ({count})}}'**
  String housingAmendmentRulesGroupModified(int count);

  /// No description provided for @housingAmendmentRulesGroupRemoved.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Removed rule ({count})} other{Removed rules ({count})}}'**
  String housingAmendmentRulesGroupRemoved(int count);

  /// No description provided for @housingAmendmentRulesGroupUnchanged.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Unchanged rule ({count})} other{Unchanged rules ({count})}}'**
  String housingAmendmentRulesGroupUnchanged(int count);

  /// No description provided for @housingAmendmentRulesBeforeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Previously'**
  String get housingAmendmentRulesBeforeSubtitle;

  /// No description provided for @housingAmendmentRulesProposedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Proposed'**
  String get housingAmendmentRulesProposedSubtitle;

  /// No description provided for @housingAmendmentRulesUnchangedDetailHint.
  ///
  /// In en, this message translates to:
  /// **'This rule is unchanged in the proposed revision.'**
  String get housingAmendmentRulesUnchangedDetailHint;

  /// No description provided for @housingAmendmentRejectTitle.
  ///
  /// In en, this message translates to:
  /// **'Refuse change request'**
  String get housingAmendmentRejectTitle;

  /// No description provided for @housingAmendmentRejectMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'Message (optional)'**
  String get housingAmendmentRejectMessageLabel;

  /// No description provided for @housingAmendmentRejectConfirm.
  ///
  /// In en, this message translates to:
  /// **'Refuse'**
  String get housingAmendmentRejectConfirm;

  /// No description provided for @housingAmendmentRefusalMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'Refusal message'**
  String get housingAmendmentRefusalMessageLabel;

  /// No description provided for @housingActiveHubViewPendingAmendment.
  ///
  /// In en, this message translates to:
  /// **'Requested change'**
  String get housingActiveHubViewPendingAmendment;

  /// No description provided for @housingInviteResponseWindowTitle.
  ///
  /// In en, this message translates to:
  /// **'Response window'**
  String get housingInviteResponseWindowTitle;

  /// No description provided for @housingInviteResponseWindowBody.
  ///
  /// In en, this message translates to:
  /// **'Participants have until this date and time to respond (UTC).'**
  String get housingInviteResponseWindowBody;

  /// No description provided for @housingInvitePeriodOverlapTitle.
  ///
  /// In en, this message translates to:
  /// **'Agreement period conflict'**
  String get housingInvitePeriodOverlapTitle;

  /// No description provided for @housingInvitePeriodOverlapBody.
  ///
  /// In en, this message translates to:
  /// **'This agreement overlaps by more than one calendar day with another housing plan where you are a participant. Change the dates or resolve the other plan before sending.'**
  String get housingInvitePeriodOverlapBody;

  /// No description provided for @housingInvitePeriodOverlapDetail.
  ///
  /// In en, this message translates to:
  /// **'This agreement overlaps by more than one calendar day with “{planTitle}” ({dateRange}). Change the dates or resolve that plan before sending.'**
  String housingInvitePeriodOverlapDetail(String planTitle, String dateRange);

  /// No description provided for @housingPlanParticipantMustBeConnectedContact.
  ///
  /// In en, this message translates to:
  /// **'Every co-participant must be a connected contact on this device before you can send the proposal.'**
  String get housingPlanParticipantMustBeConnectedContact;

  /// No description provided for @housingInviteResponseDeadlineTitle.
  ///
  /// In en, this message translates to:
  /// **'Response deadline:'**
  String get housingInviteResponseDeadlineTitle;

  /// No description provided for @housingInviteResponseDeadlineInDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{In 1 day} other{In {count} days}}'**
  String housingInviteResponseDeadlineInDays(int count);

  /// No description provided for @housingInviteResponseDeadlineToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get housingInviteResponseDeadlineToday;

  /// No description provided for @deadlineRemainingInDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{In 1 day} other{In {count} days}}'**
  String deadlineRemainingInDays(int count);

  /// No description provided for @deadlineRemainingToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get deadlineRemainingToday;

  /// No description provided for @deadlineRemainingCountdown.
  ///
  /// In en, this message translates to:
  /// **'In {time}'**
  String deadlineRemainingCountdown(String time);

  /// No description provided for @deadlineRemainingExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get deadlineRemainingExpired;

  /// No description provided for @housingInviteResponseDeadlineCountdown.
  ///
  /// In en, this message translates to:
  /// **'In {time}'**
  String housingInviteResponseDeadlineCountdown(String time);

  /// No description provided for @housingInviteOfferClosedHint.
  ///
  /// In en, this message translates to:
  /// **'This offer is no longer open for responses.'**
  String get housingInviteOfferClosedHint;

  /// No description provided for @housingInviteForkedFromLabel.
  ///
  /// In en, this message translates to:
  /// **'Derived from a previous proposal ({revisionId}).'**
  String housingInviteForkedFromLabel(String revisionId);

  /// No description provided for @housingArchiveExpiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Expired proposal'**
  String get housingArchiveExpiredTitle;

  /// No description provided for @settingsActivityLogTitle.
  ///
  /// In en, this message translates to:
  /// **'Event journal'**
  String get settingsActivityLogTitle;

  /// No description provided for @settingsActivityLogSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Relay events on this device'**
  String get settingsActivityLogSubtitle;

  /// No description provided for @activityLogEmpty.
  ///
  /// In en, this message translates to:
  /// **'No events match your filters.'**
  String get activityLogEmpty;

  /// No description provided for @activityLogNoEntries.
  ///
  /// In en, this message translates to:
  /// **'No log entries yet.'**
  String get activityLogNoEntries;

  /// No description provided for @activityLogFiltersTitle.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get activityLogFiltersTitle;

  /// No description provided for @activityLogFilterDatesLabel.
  ///
  /// In en, this message translates to:
  /// **'Dates'**
  String get activityLogFilterDatesLabel;

  /// No description provided for @activityLogFilterInitiatorLabel.
  ///
  /// In en, this message translates to:
  /// **'Initiator'**
  String get activityLogFilterInitiatorLabel;

  /// No description provided for @activityLogFilterInitiatorAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get activityLogFilterInitiatorAll;

  /// No description provided for @activityLogFilterInitiatorSelf.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get activityLogFilterInitiatorSelf;

  /// No description provided for @activityLogFilterInitiatorContact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get activityLogFilterInitiatorContact;

  /// No description provided for @activityLogFilterEmitterLabel.
  ///
  /// In en, this message translates to:
  /// **'Emitter'**
  String get activityLogFilterEmitterLabel;

  /// No description provided for @activityLogFilterEmitterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get activityLogFilterEmitterAll;

  /// No description provided for @activityLogFilterEmitterSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get activityLogFilterEmitterSystem;

  /// No description provided for @activityLogFilterFromLabel.
  ///
  /// In en, this message translates to:
  /// **'From (date)'**
  String get activityLogFilterFromLabel;

  /// No description provided for @activityLogFilterToLabel.
  ///
  /// In en, this message translates to:
  /// **'To (date)'**
  String get activityLogFilterToLabel;

  /// No description provided for @activityLogApplyFilters.
  ///
  /// In en, this message translates to:
  /// **'Apply filters'**
  String get activityLogApplyFilters;

  /// No description provided for @activityLogKindContactHandshakeReceived.
  ///
  /// In en, this message translates to:
  /// **'Contact connection request received'**
  String get activityLogKindContactHandshakeReceived;

  /// No description provided for @activityLogKindContactDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Contact disconnected'**
  String get activityLogKindContactDisconnected;

  /// No description provided for @activityLogKindContactDeleted.
  ///
  /// In en, this message translates to:
  /// **'Contact deleted'**
  String get activityLogKindContactDeleted;

  /// No description provided for @activityLogKindHousingProposalSent.
  ///
  /// In en, this message translates to:
  /// **'Housing proposal sent'**
  String get activityLogKindHousingProposalSent;

  /// No description provided for @activityLogKindHousingProposalReceived.
  ///
  /// In en, this message translates to:
  /// **'Housing proposal received'**
  String get activityLogKindHousingProposalReceived;

  /// No description provided for @activityLogKindHousingProposalResponse.
  ///
  /// In en, this message translates to:
  /// **'Housing proposal response'**
  String get activityLogKindHousingProposalResponse;

  /// No description provided for @activityLogKindHousingProposalInvalidated.
  ///
  /// In en, this message translates to:
  /// **'Housing proposal closed'**
  String get activityLogKindHousingProposalInvalidated;

  /// No description provided for @activityLogKindHousingProposalExpired.
  ///
  /// In en, this message translates to:
  /// **'Housing proposal expired'**
  String get activityLogKindHousingProposalExpired;

  /// No description provided for @activityLogKindHousingProposalForkCreated.
  ///
  /// In en, this message translates to:
  /// **'Derived housing proposal started'**
  String get activityLogKindHousingProposalForkCreated;

  /// No description provided for @activityLogKindHousingAgreementActivated.
  ///
  /// In en, this message translates to:
  /// **'Housing agreement activated'**
  String get activityLogKindHousingAgreementActivated;

  /// No description provided for @activityLogKindHousingProposalAgreementExpired.
  ///
  /// In en, this message translates to:
  /// **'Plan amendment vote abandoned (agreement ended)'**
  String get activityLogKindHousingProposalAgreementExpired;

  /// No description provided for @activityLogKindHousingParticipationChangeAgreementExpired.
  ///
  /// In en, this message translates to:
  /// **'Ejection vote abandoned (agreement ended)'**
  String get activityLogKindHousingParticipationChangeAgreementExpired;

  /// No description provided for @housingInvitePlanActivating.
  ///
  /// In en, this message translates to:
  /// **'All participants have accepted. Activating the agreement…'**
  String get housingInvitePlanActivating;

  /// No description provided for @housingInviteProposalAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Invitation proposal'**
  String get housingInviteProposalAppBarTitle;

  /// No description provided for @housingInviteProposalIntroTitle.
  ///
  /// In en, this message translates to:
  /// **'Here is the proposal that will be sent to each of your participants.'**
  String get housingInviteProposalIntroTitle;

  /// No description provided for @housingInviteProposalSentIntroTitle.
  ///
  /// In en, this message translates to:
  /// **'Here is the proposal sent to each of your participants.'**
  String get housingInviteProposalSentIntroTitle;

  /// No description provided for @housingInviteParticipantsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Participants'**
  String get housingInviteParticipantsSectionTitle;

  /// No description provided for @housingInviteExpensesSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Expenses and split'**
  String get housingInviteExpensesSectionTitle;

  /// No description provided for @housingInviteRulesSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Agreement rules'**
  String get housingInviteRulesSectionTitle;

  /// No description provided for @housingInviteStatusAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get housingInviteStatusAccepted;

  /// No description provided for @housingInviteStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get housingInviteStatusPending;

  /// No description provided for @housingInviteStatusNegotiating.
  ///
  /// In en, this message translates to:
  /// **'In negotiation'**
  String get housingInviteStatusNegotiating;

  /// No description provided for @housingInviteStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get housingInviteStatusRejected;

  /// No description provided for @housingInviteAcceptFull.
  ///
  /// In en, this message translates to:
  /// **'I accept in full'**
  String get housingInviteAcceptFull;

  /// No description provided for @housingInviteMissingContactsAction.
  ///
  /// In en, this message translates to:
  /// **'Missing contacts'**
  String get housingInviteMissingContactsAction;

  /// No description provided for @housingInviteMissingContactsRedeemBanner.
  ///
  /// In en, this message translates to:
  /// **'To accept this plan, connect with {name} first. Enter their invitation code below.'**
  String housingInviteMissingContactsRedeemBanner(String name);

  /// No description provided for @housingInviteMissingContactsBlocked.
  ///
  /// In en, this message translates to:
  /// **'Connect with every co-participant before you can accept.'**
  String get housingInviteMissingContactsBlocked;

  /// No description provided for @housingPlanMissingContactsTitle.
  ///
  /// In en, this message translates to:
  /// **'Plan contacts'**
  String get housingPlanMissingContactsTitle;

  /// No description provided for @housingPlanMissingContactsIntro.
  ///
  /// In en, this message translates to:
  /// **'Each co-participant must be a connected contact on this device before you can accept the plan. Tap Establish contact for anyone you still need to reach.'**
  String get housingPlanMissingContactsIntro;

  /// No description provided for @housingPlanMissingContactsEmpty.
  ///
  /// In en, this message translates to:
  /// **'This plan has no other participants on this device.'**
  String get housingPlanMissingContactsEmpty;

  /// No description provided for @housingPlanMissingContactsAllReady.
  ///
  /// In en, this message translates to:
  /// **'Every co-participant is connected. You can go back and accept the plan.'**
  String get housingPlanMissingContactsAllReady;

  /// No description provided for @housingPlanMissingContactsEstablishContact.
  ///
  /// In en, this message translates to:
  /// **'Establish contact'**
  String get housingPlanMissingContactsEstablishContact;

  /// No description provided for @housingPlanMissingContactsPendingOutbound.
  ///
  /// In en, this message translates to:
  /// **'Request sent — waiting for their response.'**
  String get housingPlanMissingContactsPendingOutbound;

  /// No description provided for @housingPlanMissingContactsRefusedAt.
  ///
  /// In en, this message translates to:
  /// **'Refused {when}'**
  String housingPlanMissingContactsRefusedAt(String when);

  /// No description provided for @housingPlanMissingContactsInboundPrompt.
  ///
  /// In en, this message translates to:
  /// **'{requester} wishes to establish contact with you for this housing plan.'**
  String housingPlanMissingContactsInboundPrompt(String requester);

  /// No description provided for @housingPlanMissingContactsAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get housingPlanMissingContactsAccept;

  /// No description provided for @housingPlanMissingContactsRefuse.
  ///
  /// In en, this message translates to:
  /// **'Refuse'**
  String get housingPlanMissingContactsRefuse;

  /// No description provided for @housingInviteNegotiate.
  ///
  /// In en, this message translates to:
  /// **'I would like to negotiate'**
  String get housingInviteNegotiate;

  /// No description provided for @housingInviteRejectBlock.
  ///
  /// In en, this message translates to:
  /// **'I reject outright'**
  String get housingInviteRejectBlock;

  /// No description provided for @housingInviteNegotiateMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'Message to send with your negotiation request'**
  String get housingInviteNegotiateMessageLabel;

  /// No description provided for @housingInviteResponseSent.
  ///
  /// In en, this message translates to:
  /// **'Response sent.'**
  String get housingInviteResponseSent;

  /// No description provided for @housingArchiveEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Housing plans'**
  String get housingArchiveEntryTitle;

  /// No description provided for @housingArchiveEntryBody.
  ///
  /// In en, this message translates to:
  /// **'Choose a proposal to review, edit a draft, or create a new plan.'**
  String get housingArchiveEntryBody;

  /// No description provided for @housingArchiveNegotiatingTitle.
  ///
  /// In en, this message translates to:
  /// **'Plan in negotiation'**
  String get housingArchiveNegotiatingTitle;

  /// No description provided for @housingArchivePendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Plan waiting for {count} response(s)'**
  String housingArchivePendingTitle(int count);

  /// No description provided for @housingArchiveRejectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Rejected plan'**
  String get housingArchiveRejectedTitle;

  /// No description provided for @housingArchiveAmendmentRejectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Change request refused'**
  String get housingArchiveAmendmentRejectedTitle;

  /// No description provided for @housingArchiveDraftTitle.
  ///
  /// In en, this message translates to:
  /// **'Plan draft'**
  String get housingArchiveDraftTitle;

  /// No description provided for @housingArchiveDraftParticipantsTitle.
  ///
  /// In en, this message translates to:
  /// **'Plan with {count} participants'**
  String housingArchiveDraftParticipantsTitle(int count);

  /// No description provided for @housingArchiveCreateDerivedAction.
  ///
  /// In en, this message translates to:
  /// **'Create a derived version'**
  String get housingArchiveCreateDerivedAction;

  /// No description provided for @housingArchiveEditDraftAction.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get housingArchiveEditDraftAction;

  /// No description provided for @housingArchiveViewAction.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get housingArchiveViewAction;

  /// No description provided for @housingArchiveCreateNewPlan.
  ///
  /// In en, this message translates to:
  /// **'Create a new plan'**
  String get housingArchiveCreateNewPlan;

  /// No description provided for @housingArchiveForkPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Your response was sent.'**
  String get housingArchiveForkPromptTitle;

  /// No description provided for @housingArchiveForkPromptBody.
  ///
  /// In en, this message translates to:
  /// **'Do you want to create a derived version of this proposal now to make your changes?'**
  String get housingArchiveForkPromptBody;

  /// No description provided for @housingArchiveForkPromptLaterHint.
  ///
  /// In en, this message translates to:
  /// **'You can do this later from the main menu.'**
  String get housingArchiveForkPromptLaterHint;

  /// No description provided for @housingArchiveForkLaterAction.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get housingArchiveForkLaterAction;

  /// No description provided for @housingArchiveForkPromptCreateAction.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get housingArchiveForkPromptCreateAction;

  /// No description provided for @housingInviteProposalLockedHint.
  ///
  /// In en, this message translates to:
  /// **'Another participant is negotiating or has rejected this proposal. Responses are paused until the plan is revised.'**
  String get housingInviteProposalLockedHint;

  /// No description provided for @housingInviteInvitationStatusAction.
  ///
  /// In en, this message translates to:
  /// **'Invitation status'**
  String get housingInviteInvitationStatusAction;

  /// No description provided for @housingInviteStatusDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Invitation status'**
  String get housingInviteStatusDialogTitle;

  /// No description provided for @housingInviteStatusSentAtLabel.
  ///
  /// In en, this message translates to:
  /// **'Sent: {when}'**
  String housingInviteStatusSentAtLabel(String when);

  /// No description provided for @housingInviteStatusDeadlineLabel.
  ///
  /// In en, this message translates to:
  /// **'Response deadline: {when}'**
  String housingInviteStatusDeadlineLabel(String when);

  /// No description provided for @housingInviteStatusDeadlineNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get housingInviteStatusDeadlineNotSet;

  /// No description provided for @housingInviteStatusTableSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Invitees'**
  String get housingInviteStatusTableSectionTitle;

  /// No description provided for @housingInviteStatusTableInvitee.
  ///
  /// In en, this message translates to:
  /// **'Invitee'**
  String get housingInviteStatusTableInvitee;

  /// No description provided for @housingInviteStatusTableStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get housingInviteStatusTableStatus;

  /// No description provided for @housingInviteStatusMessagesSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get housingInviteStatusMessagesSectionTitle;

  /// No description provided for @housingInviteStatusNoPending.
  ///
  /// In en, this message translates to:
  /// **'No pending invitation for this plan.'**
  String get housingInviteStatusNoPending;

  /// No description provided for @housingInviteTransportSent.
  ///
  /// In en, this message translates to:
  /// **'Proposal sent to {sentCount} participant(s).'**
  String housingInviteTransportSent(int sentCount);

  /// No description provided for @housingInviteTransportPartial.
  ///
  /// In en, this message translates to:
  /// **'Proposal sent to {sentCount} participant(s); {failedCount} participant(s) could not be reached.'**
  String housingInviteTransportPartial(int sentCount, int failedCount);

  /// No description provided for @housingInviteTransportFailed.
  ///
  /// In en, this message translates to:
  /// **'The proposal could not be delivered to any participant. You can edit the plan and try again.'**
  String get housingInviteTransportFailed;

  /// No description provided for @housingInviteResendProposalAction.
  ///
  /// In en, this message translates to:
  /// **'Resend proposal'**
  String get housingInviteResendProposalAction;

  /// No description provided for @housingInviteViewSentProposalAction.
  ///
  /// In en, this message translates to:
  /// **'View sent proposal'**
  String get housingInviteViewSentProposalAction;

  /// No description provided for @housingInviteReceivedWhileEditingSnack.
  ///
  /// In en, this message translates to:
  /// **'You received a housing proposal from a participant.'**
  String get housingInviteReceivedWhileEditingSnack;

  /// No description provided for @housingInviteReceivedOpenAction.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get housingInviteReceivedOpenAction;

  /// No description provided for @pushNotificationHousingProposalTitle.
  ///
  /// In en, this message translates to:
  /// **'Housing proposal'**
  String get pushNotificationHousingProposalTitle;

  /// No description provided for @pushNotificationHousingProposalBody.
  ///
  /// In en, this message translates to:
  /// **'Open the app to review the proposal.'**
  String get pushNotificationHousingProposalBody;

  /// No description provided for @pushNotificationHousingAgreementActivatedTitle.
  ///
  /// In en, this message translates to:
  /// **'Unanimous agreement'**
  String get pushNotificationHousingAgreementActivatedTitle;

  /// No description provided for @pushNotificationHousingAgreementActivatedBody.
  ///
  /// In en, this message translates to:
  /// **'Your group has reached a unanimous housing agreement.'**
  String get pushNotificationHousingAgreementActivatedBody;

  /// No description provided for @pushNotificationHousingRealizedExpenseTitle.
  ///
  /// In en, this message translates to:
  /// **'Expense to review'**
  String get pushNotificationHousingRealizedExpenseTitle;

  /// No description provided for @pushNotificationHousingRealizedExpenseBody.
  ///
  /// In en, this message translates to:
  /// **'A participant submitted an expense for your agreement.'**
  String get pushNotificationHousingRealizedExpenseBody;

  /// No description provided for @pushNotificationHousingRealizedExpenseBodyFrom.
  ///
  /// In en, this message translates to:
  /// **'{name} submitted an expense to review.'**
  String pushNotificationHousingRealizedExpenseBodyFrom(String name);

  /// No description provided for @pushNotificationHousingRealizedExpenseAcceptedTitle.
  ///
  /// In en, this message translates to:
  /// **'Expense accepted'**
  String get pushNotificationHousingRealizedExpenseAcceptedTitle;

  /// No description provided for @pushNotificationHousingRealizedExpenseAcceptedBody.
  ///
  /// In en, this message translates to:
  /// **'A participant accepted your expense.'**
  String get pushNotificationHousingRealizedExpenseAcceptedBody;

  /// No description provided for @pushNotificationHousingRealizedExpenseAcceptedBodyFrom.
  ///
  /// In en, this message translates to:
  /// **'{name} accepted your expense.'**
  String pushNotificationHousingRealizedExpenseAcceptedBodyFrom(String name);

  /// No description provided for @pushNotificationHousingRealizedExpenseAcceptedBodyFromPeer.
  ///
  /// In en, this message translates to:
  /// **'{name} accepted {payer}\'s expense.'**
  String pushNotificationHousingRealizedExpenseAcceptedBodyFromPeer(
    String name,
    String payer,
  );

  /// No description provided for @pushNotificationHousingRealizedTransferAcceptedTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfer accepted'**
  String get pushNotificationHousingRealizedTransferAcceptedTitle;

  /// No description provided for @pushNotificationHousingRealizedTransferAcceptedBody.
  ///
  /// In en, this message translates to:
  /// **'A participant accepted your transfer.'**
  String get pushNotificationHousingRealizedTransferAcceptedBody;

  /// No description provided for @pushNotificationHousingRealizedTransferAcceptedBodyFrom.
  ///
  /// In en, this message translates to:
  /// **'{name} accepted your transfer.'**
  String pushNotificationHousingRealizedTransferAcceptedBodyFrom(String name);

  /// No description provided for @pushNotificationHousingRealizedTransferAcceptedBodyFromPeer.
  ///
  /// In en, this message translates to:
  /// **'{name} accepted {payer}\'s transfer.'**
  String pushNotificationHousingRealizedTransferAcceptedBodyFromPeer(
    String name,
    String payer,
  );

  /// No description provided for @pushNotificationHousingRealizedExpenseRejectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Expense rejected'**
  String get pushNotificationHousingRealizedExpenseRejectedTitle;

  /// No description provided for @pushNotificationHousingRealizedExpenseRejectedBody.
  ///
  /// In en, this message translates to:
  /// **'A participant rejected your expense.'**
  String get pushNotificationHousingRealizedExpenseRejectedBody;

  /// No description provided for @pushNotificationHousingRealizedExpenseRejectedBodyFrom.
  ///
  /// In en, this message translates to:
  /// **'{name} rejected your expense.'**
  String pushNotificationHousingRealizedExpenseRejectedBodyFrom(String name);

  /// No description provided for @pushNotificationHousingDecisionTitle.
  ///
  /// In en, this message translates to:
  /// **'Housing proposal response'**
  String get pushNotificationHousingDecisionTitle;

  /// No description provided for @pushNotificationHousingDecisionBody.
  ///
  /// In en, this message translates to:
  /// **'A participant responded to a housing proposal.'**
  String get pushNotificationHousingDecisionBody;

  /// No description provided for @pushNotificationHousingDecisionBodyFrom.
  ///
  /// In en, this message translates to:
  /// **'{name} responded to a housing proposal.'**
  String pushNotificationHousingDecisionBodyFrom(String name);

  /// No description provided for @pushNotificationHousingAmendmentDecisionTitle.
  ///
  /// In en, this message translates to:
  /// **'Agreement change response'**
  String get pushNotificationHousingAmendmentDecisionTitle;

  /// No description provided for @pushNotificationHousingAmendmentDecisionBody.
  ///
  /// In en, this message translates to:
  /// **'A participant responded to an agreement change request.'**
  String get pushNotificationHousingAmendmentDecisionBody;

  /// No description provided for @pushNotificationHousingAmendmentDecisionBodyFrom.
  ///
  /// In en, this message translates to:
  /// **'{name} responded to an agreement change request.'**
  String pushNotificationHousingAmendmentDecisionBodyFrom(String name);

  /// No description provided for @pushNotificationHousingPaymentReminderBeforeDueTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment reminder'**
  String get pushNotificationHousingPaymentReminderBeforeDueTitle;

  /// No description provided for @pushNotificationHousingPaymentReminderBeforeDueBody.
  ///
  /// In en, this message translates to:
  /// **'{lineTitle} is due soon.'**
  String pushNotificationHousingPaymentReminderBeforeDueBody(String lineTitle);

  /// No description provided for @pushNotificationHousingPaymentReminderOverdueTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment overdue'**
  String get pushNotificationHousingPaymentReminderOverdueTitle;

  /// No description provided for @pushNotificationHousingPaymentReminderOverdueBody.
  ///
  /// In en, this message translates to:
  /// **'{lineTitle} was not completed for this period.'**
  String pushNotificationHousingPaymentReminderOverdueBody(String lineTitle);

  /// No description provided for @pushNotificationContactInvitationBeforeExpiryTitle.
  ///
  /// In en, this message translates to:
  /// **'Invitation expiring soon'**
  String get pushNotificationContactInvitationBeforeExpiryTitle;

  /// No description provided for @pushNotificationContactInvitationBeforeExpiryBody.
  ///
  /// In en, this message translates to:
  /// **'A pending invitation will expire soon.'**
  String get pushNotificationContactInvitationBeforeExpiryBody;

  /// No description provided for @pushNotificationContactInvitationExpiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Invitation expired'**
  String get pushNotificationContactInvitationExpiredTitle;

  /// No description provided for @pushNotificationContactInvitationExpiredBody.
  ///
  /// In en, this message translates to:
  /// **'An invitation was not used and has expired.'**
  String get pushNotificationContactInvitationExpiredBody;

  /// No description provided for @pushNotificationHousingProposalDeadlineTitle.
  ///
  /// In en, this message translates to:
  /// **'Proposal deadline approaching'**
  String get pushNotificationHousingProposalDeadlineTitle;

  /// No description provided for @pushNotificationHousingProposalDeadlineBody.
  ///
  /// In en, this message translates to:
  /// **'A housing plan offer expires soon. Open Housing to respond or check status.'**
  String get pushNotificationHousingProposalDeadlineBody;

  /// No description provided for @notificationHousingPaymentRemindersLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment reminders'**
  String get notificationHousingPaymentRemindersLabel;

  /// No description provided for @housingOverdueJournalCardBody.
  ///
  /// In en, this message translates to:
  /// **'{lineTitle} was not completed for this period.'**
  String housingOverdueJournalCardBody(String lineTitle);

  /// No description provided for @housingBeforeDueJournalCardBody.
  ///
  /// In en, this message translates to:
  /// **'Payment due reminder for {dueDate}\n{lineTitle} - {amount}'**
  String housingBeforeDueJournalCardBody(
    String dueDate,
    String lineTitle,
    String amount,
  );

  /// No description provided for @housingDueDayJournalCardBody.
  ///
  /// In en, this message translates to:
  /// **'Reminder: due today\n{lineTitle} - {amount}'**
  String housingDueDayJournalCardBody(String lineTitle, String amount);

  /// No description provided for @pushNotificationHousingResponseFailureRelayUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'The relay server is temporarily unavailable.'**
  String get pushNotificationHousingResponseFailureRelayUnavailableBody;

  /// No description provided for @pushNotificationHousingResponseFailureUnknownBody.
  ///
  /// In en, this message translates to:
  /// **'The proposal you are trying to respond to was not found. There are several possible reasons. Contact the person directly.'**
  String get pushNotificationHousingResponseFailureUnknownBody;

  /// No description provided for @pushNotificationHousingResponseFailureSendBody.
  ///
  /// In en, this message translates to:
  /// **'An error occurred while sending the response.'**
  String get pushNotificationHousingResponseFailureSendBody;

  /// No description provided for @pushNotificationHousingResponseFailureLocalErrorBody.
  ///
  /// In en, this message translates to:
  /// **'An unknown error occurred.'**
  String get pushNotificationHousingResponseFailureLocalErrorBody;

  /// No description provided for @pushNotificationContactAddRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact request'**
  String get pushNotificationContactAddRequestTitle;

  /// No description provided for @pushNotificationContactAddRequestBody.
  ///
  /// In en, this message translates to:
  /// **'{name} wants to connect with you.'**
  String pushNotificationContactAddRequestBody(String name);

  /// No description provided for @pushNotificationContactAddedViaInvitationBody.
  ///
  /// In en, this message translates to:
  /// **'{name} is now in your contacts.'**
  String pushNotificationContactAddedViaInvitationBody(String name);

  /// No description provided for @pushNotificationContactDuplicateModuleAnchorRejectedBody.
  ///
  /// In en, this message translates to:
  /// **'The person you tried to connect with already has your contact on file, but you must restore your data before reconnecting.'**
  String get pushNotificationContactDuplicateModuleAnchorRejectedBody;

  /// No description provided for @contactsDuplicateDialogOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get contactsDuplicateDialogOk;

  /// No description provided for @contactsDuplicateReadMore.
  ///
  /// In en, this message translates to:
  /// **'Read more about this'**
  String get contactsDuplicateReadMore;

  /// No description provided for @contactsDuplicateAnchorHousingActive.
  ///
  /// In en, this message translates to:
  /// **'an active housing plan'**
  String get contactsDuplicateAnchorHousingActive;

  /// No description provided for @contactsDuplicateAnchorVehicleSharing.
  ///
  /// In en, this message translates to:
  /// **'a vehicle sharing link'**
  String get contactsDuplicateAnchorVehicleSharing;

  /// No description provided for @contactsDuplicateAnchorHousingAndVehicle.
  ///
  /// In en, this message translates to:
  /// **'Text to be determined for the Housing AND Vehicle case'**
  String get contactsDuplicateAnchorHousingAndVehicle;

  /// No description provided for @contactsDuplicateInviterRejectedIntro.
  ///
  /// In en, this message translates to:
  /// **'The contact who just used an invitation code was already in your contacts. This is a duplicate. The existing contact is linked to {anchor}.'**
  String contactsDuplicateInviterRejectedIntro(String anchor);

  /// No description provided for @contactsDuplicateInviterNotAdded.
  ///
  /// In en, this message translates to:
  /// **'The contact was NOT added.'**
  String get contactsDuplicateInviterNotAdded;

  /// No description provided for @contactsDuplicateInviterInformRestore.
  ///
  /// In en, this message translates to:
  /// **'Tell them they must restore their data on their device to reconnect with you.'**
  String get contactsDuplicateInviterInformRestore;

  /// No description provided for @contactsDuplicateInviterMergedBody.
  ///
  /// In en, this message translates to:
  /// **'The contact who just used an invitation code was already in your contacts. They were merged into the existing contact.'**
  String get contactsDuplicateInviterMergedBody;

  /// No description provided for @contactsDuplicateInviteeRejectedIntro.
  ///
  /// In en, this message translates to:
  /// **'The person you tried to connect with already has your contact. You are linked to {anchor}.'**
  String contactsDuplicateInviteeRejectedIntro(String anchor);

  /// No description provided for @contactsDuplicateInviteeMustRestore.
  ///
  /// In en, this message translates to:
  /// **'You MUST restore your data. That is what you need to do to reconnect properly.'**
  String get contactsDuplicateInviteeMustRestore;

  /// No description provided for @contactsDuplicateInviteeRejectedBannerBody.
  ///
  /// In en, this message translates to:
  /// **'A reconnection cannot be established this way because you participate in a sharing plan.'**
  String get contactsDuplicateInviteeRejectedBannerBody;

  /// No description provided for @pushNotificationContactAddRequestAcceptedBody.
  ///
  /// In en, this message translates to:
  /// **'Your connection request with {name} was accepted.'**
  String pushNotificationContactAddRequestAcceptedBody(String name);

  /// No description provided for @pushNotificationContactAddRequestRejectedBody.
  ///
  /// In en, this message translates to:
  /// **'Your connection request with {name} was declined.'**
  String pushNotificationContactAddRequestRejectedBody(String name);

  /// No description provided for @pushNotificationContactAddRequestExpiredCodeBody.
  ///
  /// In en, this message translates to:
  /// **'The connection code you used has expired.'**
  String get pushNotificationContactAddRequestExpiredCodeBody;

  /// No description provided for @pushNotificationContactAddRequestInvalidCodeBody.
  ///
  /// In en, this message translates to:
  /// **'The connection code you used is not valid.'**
  String get pushNotificationContactAddRequestInvalidCodeBody;

  /// No description provided for @pushNotificationContactAddRequestRelayErrorBody.
  ///
  /// In en, this message translates to:
  /// **'An error occurred on the relay server. Try again.'**
  String get pushNotificationContactAddRequestRelayErrorBody;

  /// No description provided for @pushNotificationContactAddRequestRelayUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'The relay server is temporarily unavailable.'**
  String get pushNotificationContactAddRequestRelayUnavailableBody;

  /// No description provided for @pushNotificationContactAddRequestUnknownFailureBody.
  ///
  /// In en, this message translates to:
  /// **'Your connection request failed.'**
  String get pushNotificationContactAddRequestUnknownFailureBody;

  /// No description provided for @pushNotificationPlanPeerEstablishmentRequestBody.
  ///
  /// In en, this message translates to:
  /// **'{requester} wishes to establish contact with you, in the context of the housing plan proposal from {proposer}.'**
  String pushNotificationPlanPeerEstablishmentRequestBody(
    String requester,
    String proposer,
  );

  /// No description provided for @pushNotificationContactDisconnectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact disconnected'**
  String get pushNotificationContactDisconnectionTitle;

  /// No description provided for @pushNotificationContactDisconnectionBody.
  ///
  /// In en, this message translates to:
  /// **'{name} disconnected from you.'**
  String pushNotificationContactDisconnectionBody(String name);

  /// No description provided for @housingInviteGenerateCodes.
  ///
  /// In en, this message translates to:
  /// **'Generate invitation codes'**
  String get housingInviteGenerateCodes;

  /// No description provided for @housingInviteCodesDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Invitation codes'**
  String get housingInviteCodesDialogTitle;

  /// No description provided for @housingInviteCodesDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Each code is for one co-participant. Share them however you prefer; registering codes with the relay server will be added later.'**
  String get housingInviteCodesDialogBody;

  /// No description provided for @housingInviteCodesCopyAll.
  ///
  /// In en, this message translates to:
  /// **'Copy all'**
  String get housingInviteCodesCopyAll;

  /// No description provided for @housingInviteCodesCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get housingInviteCodesCopied;

  /// No description provided for @housingInviteRuleOffHint.
  ///
  /// In en, this message translates to:
  /// **'This rule is turned off for this proposal.'**
  String get housingInviteRuleOffHint;

  /// No description provided for @housingInviteWithdrawalPerParticipantIntro.
  ///
  /// In en, this message translates to:
  /// **'Notice and penalty differ by participant (see below).'**
  String get housingInviteWithdrawalPerParticipantIntro;

  /// No description provided for @housingInviteHousingAgreementTitle.
  ///
  /// In en, this message translates to:
  /// **'Housing agreement'**
  String get housingInviteHousingAgreementTitle;

  /// No description provided for @housingInviteDateRangeSeparator.
  ///
  /// In en, this message translates to:
  /// **' to '**
  String get housingInviteDateRangeSeparator;

  /// No description provided for @housingInviteSunburstCenterLabel.
  ///
  /// In en, this message translates to:
  /// **'Overall'**
  String get housingInviteSunburstCenterLabel;

  /// No description provided for @housingInviteSunburstCenterParticipation.
  ///
  /// In en, this message translates to:
  /// **'Overall participation {pct}%'**
  String housingInviteSunburstCenterParticipation(String pct);

  /// No description provided for @housingInviteViewExpensesDetail.
  ///
  /// In en, this message translates to:
  /// **'View expenses in detail'**
  String get housingInviteViewExpensesDetail;

  /// No description provided for @housingInviteExpensesDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Expenses in detail'**
  String get housingInviteExpensesDetailTitle;

  /// No description provided for @housingInviteExpensesDetailSwipeHint.
  ///
  /// In en, this message translates to:
  /// **'Swipe left or right to browse each expense.'**
  String get housingInviteExpensesDetailSwipeHint;

  /// No description provided for @housingInviteExpensesDetailPageIndicator.
  ///
  /// In en, this message translates to:
  /// **'{current} of {total}'**
  String housingInviteExpensesDetailPageIndicator(int current, int total);

  /// No description provided for @housingInviteExpensesDetailLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load this expense.'**
  String get housingInviteExpensesDetailLoadError;

  /// No description provided for @housingInviteExpensesDetailPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous expense'**
  String get housingInviteExpensesDetailPrevious;

  /// No description provided for @housingInviteExpensesDetailNext.
  ///
  /// In en, this message translates to:
  /// **'Next expense'**
  String get housingInviteExpensesDetailNext;

  /// No description provided for @housingExpenseSunburstBudgetLabel.
  ///
  /// In en, this message translates to:
  /// **'{name} (budgeted max)'**
  String housingExpenseSunburstBudgetLabel(String name);

  /// No description provided for @housingInviteSunburstEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'No expense data to chart for this plan.'**
  String get housingInviteSunburstEmptyHint;

  /// No description provided for @housingInviteSunburstLegendAgreementShare.
  ///
  /// In en, this message translates to:
  /// **'{name} - {pct}% of the agreement'**
  String housingInviteSunburstLegendAgreementShare(String name, String pct);

  /// No description provided for @housingInviteSunburstMonthlyNormalizedFootnote.
  ///
  /// In en, this message translates to:
  /// **'Amount monthlyized (30-day equivalent).'**
  String get housingInviteSunburstMonthlyNormalizedFootnote;

  /// No description provided for @housingInviteSunburstLegendYouParticipation.
  ///
  /// In en, this message translates to:
  /// **'{participantName}\'s share: {userAmount}/{totalAmount} ({pct}%)'**
  String housingInviteSunburstLegendYouParticipation(
    String participantName,
    String userAmount,
    String totalAmount,
    String pct,
  );

  /// No description provided for @housingPlanSummaryDestroy.
  ///
  /// In en, this message translates to:
  /// **'Destroy plan'**
  String get housingPlanSummaryDestroy;

  /// No description provided for @housingPlanDestroyTitle.
  ///
  /// In en, this message translates to:
  /// **'Destroy plan'**
  String get housingPlanDestroyTitle;

  /// No description provided for @housingPlanDestroyBody.
  ///
  /// In en, this message translates to:
  /// **'This removes this housing plan, expenses, ratios, agreement, and draft participants from this device.'**
  String get housingPlanDestroyBody;

  /// No description provided for @housingPlanDestroyConfirm.
  ///
  /// In en, this message translates to:
  /// **'Destroy'**
  String get housingPlanDestroyConfirm;

  /// No description provided for @housingPlanRemovedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Plan removed'**
  String get housingPlanRemovedSnackbar;

  /// No description provided for @housingPlanAddCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Add category'**
  String get housingPlanAddCategoryTitle;

  /// No description provided for @housingPlanEditCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit category'**
  String get housingPlanEditCategoryTitle;

  /// No description provided for @housingPlanCategoryNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Category name'**
  String get housingPlanCategoryNameLabel;

  /// No description provided for @housingPlanCategoryDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'What belongs here (optional)'**
  String get housingPlanCategoryDescriptionLabel;

  /// No description provided for @housingPlanSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get housingPlanSave;

  /// No description provided for @housingPlanAddExpenseTitle.
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get housingPlanAddExpenseTitle;

  /// No description provided for @housingPlanEditExpenseTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit expense'**
  String get housingPlanEditExpenseTitle;

  /// No description provided for @housingPlanRecurringSwitch.
  ///
  /// In en, this message translates to:
  /// **'Recurring'**
  String get housingPlanRecurringSwitch;

  /// No description provided for @housingPlanApproximateAmountSwitch.
  ///
  /// In en, this message translates to:
  /// **'Approximate amount'**
  String get housingPlanApproximateAmountSwitch;

  /// No description provided for @housingPlanExpenseTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get housingPlanExpenseTitleLabel;

  /// No description provided for @housingPlanCategoryOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Category (optional)'**
  String get housingPlanCategoryOptionalLabel;

  /// No description provided for @housingPlanCategoryNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get housingPlanCategoryNone;

  /// No description provided for @housingPlanExpenseDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get housingPlanExpenseDescriptionLabel;

  /// No description provided for @housingPlanDayOfMonthLabel.
  ///
  /// In en, this message translates to:
  /// **'Day of month'**
  String get housingPlanDayOfMonthLabel;

  /// No description provided for @housingPlanMinLabel.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get housingPlanMinLabel;

  /// No description provided for @housingPlanMaxLabel.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get housingPlanMaxLabel;

  /// No description provided for @housingPlanAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get housingPlanAmountLabel;

  /// No description provided for @housingExpenseNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get housingExpenseNameLabel;

  /// No description provided for @housingExpenseAmountTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount type'**
  String get housingExpenseAmountTypeLabel;

  /// No description provided for @housingExpenseAmountDetermined.
  ///
  /// In en, this message translates to:
  /// **'Determined'**
  String get housingExpenseAmountDetermined;

  /// No description provided for @housingExpenseAmountBudgetMax.
  ///
  /// In en, this message translates to:
  /// **'Budgeted (max)'**
  String get housingExpenseAmountBudgetMax;

  /// No description provided for @housingExpensePaymentResponsibleLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment responsible'**
  String get housingExpensePaymentResponsibleLabel;

  /// No description provided for @housingExpensePaymentResponsibleAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get housingExpensePaymentResponsibleAll;

  /// No description provided for @housingExpenseSplitSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get housingExpenseSplitSectionTitle;

  /// No description provided for @housingExpenseEqualParts.
  ///
  /// In en, this message translates to:
  /// **'Equal parts'**
  String get housingExpenseEqualParts;

  /// No description provided for @housingExpenseLikeLabel.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get housingExpenseLikeLabel;

  /// No description provided for @housingExpenseLikeBlankHint.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get housingExpenseLikeBlankHint;

  /// No description provided for @housingExpenseSplitAmountColumn.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get housingExpenseSplitAmountColumn;

  /// No description provided for @housingExpenseSplitParticipantColumn.
  ///
  /// In en, this message translates to:
  /// **'Participant'**
  String get housingExpenseSplitParticipantColumn;

  /// No description provided for @housingExpenseSplitPercentColumn.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get housingExpenseSplitPercentColumn;

  /// No description provided for @housingExpenseSplitCorrectRow.
  ///
  /// In en, this message translates to:
  /// **'Correct!'**
  String get housingExpenseSplitCorrectRow;

  /// No description provided for @housingExpenseRecurrenceTapToSet.
  ///
  /// In en, this message translates to:
  /// **'Set payment recurrence'**
  String get housingExpenseRecurrenceTapToSet;

  /// No description provided for @housingExpenseRecurrenceSet.
  ///
  /// In en, this message translates to:
  /// **'Recurrence configured'**
  String get housingExpenseRecurrenceSet;

  /// No description provided for @housingExpenseRecurrenceConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm recurrence'**
  String get housingExpenseRecurrenceConfirmTitle;

  /// No description provided for @housingExpenseRecurrenceMonthlyDay.
  ///
  /// In en, this message translates to:
  /// **'On day {day} of each month, from {anchor}'**
  String housingExpenseRecurrenceMonthlyDay(int day, String anchor);

  /// No description provided for @housingExpenseRecurrenceUseRange.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get housingExpenseRecurrenceUseRange;

  /// No description provided for @housingExpenseRecurrenceEveryNDays.
  ///
  /// In en, this message translates to:
  /// **'Every {days} days, starting {anchor}'**
  String housingExpenseRecurrenceEveryNDays(int days, String anchor);

  /// No description provided for @housingExpenseRecurrenceNthWeekdayOfMonth.
  ///
  /// In en, this message translates to:
  /// **'{ordinal} {weekday} of the month, from {anchor}'**
  String housingExpenseRecurrenceNthWeekdayOfMonth(
    String ordinal,
    String weekday,
    String anchor,
  );

  /// No description provided for @housingRecurrenceOrdinalFirst.
  ///
  /// In en, this message translates to:
  /// **'First'**
  String get housingRecurrenceOrdinalFirst;

  /// No description provided for @housingRecurrenceOrdinalSecond.
  ///
  /// In en, this message translates to:
  /// **'Second'**
  String get housingRecurrenceOrdinalSecond;

  /// No description provided for @housingRecurrenceOrdinalThird.
  ///
  /// In en, this message translates to:
  /// **'Third'**
  String get housingRecurrenceOrdinalThird;

  /// No description provided for @housingRecurrenceOrdinalFourth.
  ///
  /// In en, this message translates to:
  /// **'Fourth'**
  String get housingRecurrenceOrdinalFourth;

  /// No description provided for @housingRecurrenceOrdinalFifth.
  ///
  /// In en, this message translates to:
  /// **'Fifth'**
  String get housingRecurrenceOrdinalFifth;

  /// No description provided for @housingRecurrenceWeekdayMonday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get housingRecurrenceWeekdayMonday;

  /// No description provided for @housingRecurrenceWeekdayTuesday.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get housingRecurrenceWeekdayTuesday;

  /// No description provided for @housingRecurrenceWeekdayWednesday.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get housingRecurrenceWeekdayWednesday;

  /// No description provided for @housingRecurrenceWeekdayThursday.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get housingRecurrenceWeekdayThursday;

  /// No description provided for @housingRecurrenceWeekdayFriday.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get housingRecurrenceWeekdayFriday;

  /// No description provided for @housingRecurrenceWeekdaySaturday.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get housingRecurrenceWeekdaySaturday;

  /// No description provided for @housingRecurrenceWeekdaySunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get housingRecurrenceWeekdaySunday;

  /// No description provided for @housingExpenseEnterAmountForSplit.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount for this expense'**
  String get housingExpenseEnterAmountForSplit;

  /// Months segment of plan calendar duration (step 2).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 month} other{{count} months}}'**
  String housingPlanDurationMonthsCount(int count);

  /// Days segment of plan calendar duration (step 2).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 day} other{{count} days}}'**
  String housingPlanDurationDaysCount(int count);

  /// No description provided for @carSharingPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Car sharing plan'**
  String get carSharingPlanTitle;

  /// No description provided for @carSharingPlanFinish.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get carSharingPlanFinish;

  /// No description provided for @carSharingOwnerPrompt.
  ///
  /// In en, this message translates to:
  /// **'{name}: specify whether this is your owned vehicle or a rental.'**
  String carSharingOwnerPrompt(String name);

  /// No description provided for @carSharingStepVehicle.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get carSharingStepVehicle;

  /// No description provided for @carSharingStepOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get carSharingStepOwner;

  /// No description provided for @carSharingStepParticipants.
  ///
  /// In en, this message translates to:
  /// **'Participants'**
  String get carSharingStepParticipants;

  /// No description provided for @carSharingStepInsurance.
  ///
  /// In en, this message translates to:
  /// **'Insurance & registration'**
  String get carSharingStepInsurance;

  /// No description provided for @carSharingStepCurrentState.
  ///
  /// In en, this message translates to:
  /// **'Current condition'**
  String get carSharingStepCurrentState;

  /// No description provided for @carSharingStepMaintenance.
  ///
  /// In en, this message translates to:
  /// **'Maintenance estimates'**
  String get carSharingStepMaintenance;

  /// No description provided for @carSharingStepAvailability.
  ///
  /// In en, this message translates to:
  /// **'Offered availability'**
  String get carSharingStepAvailability;

  /// No description provided for @carSharingStepFuel.
  ///
  /// In en, this message translates to:
  /// **'Fuel management'**
  String get carSharingStepFuel;

  /// No description provided for @carSharingStepClauses.
  ///
  /// In en, this message translates to:
  /// **'Other clauses'**
  String get carSharingStepClauses;

  /// No description provided for @carSharingFieldMake.
  ///
  /// In en, this message translates to:
  /// **'Make'**
  String get carSharingFieldMake;

  /// No description provided for @carSharingFieldModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get carSharingFieldModel;

  /// No description provided for @carSharingFieldColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get carSharingFieldColor;

  /// No description provided for @carSharingFieldYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get carSharingFieldYear;

  /// No description provided for @carSharingOwnerIsOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner vehicle'**
  String get carSharingOwnerIsOwner;

  /// No description provided for @carSharingOwnerIsRental.
  ///
  /// In en, this message translates to:
  /// **'Rental vehicle'**
  String get carSharingOwnerIsRental;

  /// No description provided for @carSharingRentalSharePermission.
  ///
  /// In en, this message translates to:
  /// **'Sharing right obtained from the lessor'**
  String get carSharingRentalSharePermission;

  /// No description provided for @carSharingRentalContractCopy.
  ///
  /// In en, this message translates to:
  /// **'Will provide a copy of the lease when the agreement is accepted'**
  String get carSharingRentalContractCopy;

  /// No description provided for @carSharingInsuranceNotify.
  ///
  /// In en, this message translates to:
  /// **'Will notify insurers when the agreement is accepted'**
  String get carSharingInsuranceNotify;

  /// No description provided for @carSharingInsuranceAssumeIncrease.
  ///
  /// In en, this message translates to:
  /// **'Will assume any insurance premium increase (if not, and premiums rise, this agreement is subject to renegotiation)'**
  String get carSharingInsuranceAssumeIncrease;

  /// No description provided for @carSharingInsuranceProvideDocs.
  ///
  /// In en, this message translates to:
  /// **'Will provide copies of insurance and registration papers when the agreement is accepted'**
  String get carSharingInsuranceProvideDocs;

  /// No description provided for @carSharingEstimatedValueLabel.
  ///
  /// In en, this message translates to:
  /// **'Estimated value'**
  String get carSharingEstimatedValueLabel;

  /// No description provided for @carSharingPhotoFront.
  ///
  /// In en, this message translates to:
  /// **'Front photo path (optional)'**
  String get carSharingPhotoFront;

  /// No description provided for @carSharingPhotoLeft.
  ///
  /// In en, this message translates to:
  /// **'Left side photo path (optional)'**
  String get carSharingPhotoLeft;

  /// No description provided for @carSharingPhotoRight.
  ///
  /// In en, this message translates to:
  /// **'Right side photo path (optional)'**
  String get carSharingPhotoRight;

  /// No description provided for @carSharingPhotoRear.
  ///
  /// In en, this message translates to:
  /// **'Rear photo path (optional)'**
  String get carSharingPhotoRear;

  /// No description provided for @carSharingPhotoSeatsFront.
  ///
  /// In en, this message translates to:
  /// **'Front seats photo path (optional)'**
  String get carSharingPhotoSeatsFront;

  /// No description provided for @carSharingPhotoSeatsRear.
  ///
  /// In en, this message translates to:
  /// **'Rear seats photo path (optional)'**
  String get carSharingPhotoSeatsRear;

  /// No description provided for @carSharingPhotoDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard photo path (optional)'**
  String get carSharingPhotoDashboard;

  /// No description provided for @carSharingPhotoOdometer.
  ///
  /// In en, this message translates to:
  /// **'Odometer photo path (optional)'**
  String get carSharingPhotoOdometer;

  /// No description provided for @carSharingMaintenanceIntro.
  ///
  /// In en, this message translates to:
  /// **'Planned maintenance items count toward the “maintenance” category when sharing costs.'**
  String get carSharingMaintenanceIntro;

  /// No description provided for @carSharingMaintenanceAdd.
  ///
  /// In en, this message translates to:
  /// **'Add maintenance item'**
  String get carSharingMaintenanceAdd;

  /// No description provided for @carSharingMaintenanceEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit maintenance item'**
  String get carSharingMaintenanceEditTitle;

  /// No description provided for @carSharingMaintenanceEmpty.
  ///
  /// In en, this message translates to:
  /// **'No maintenance items yet.'**
  String get carSharingMaintenanceEmpty;

  /// No description provided for @carSharingMaintenanceTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get carSharingMaintenanceTitleLabel;

  /// No description provided for @carSharingMaintenanceAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get carSharingMaintenanceAmountLabel;

  /// No description provided for @carSharingAvailabilityIntro.
  ///
  /// In en, this message translates to:
  /// **'Tap half-hour cells for the selected day: highlighted slots are when the vehicle is offered to co-sharers. Other times are assumed to stay with the owner.'**
  String get carSharingAvailabilityIntro;

  /// No description provided for @carSharingAvailabilityAvailable.
  ///
  /// In en, this message translates to:
  /// **'Offered to co-sharers'**
  String get carSharingAvailabilityAvailable;

  /// No description provided for @carSharingAvailabilityOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner use'**
  String get carSharingAvailabilityOwner;

  /// No description provided for @carSharingFuelIntro.
  ///
  /// In en, this message translates to:
  /// **'When using in-app fuel tracking, each purchase records: date/time, total cost, fuel volume, odometer reading, and whether it was a full tank. Full-tank entries anchor consumption between refills. Odometer readings also support distance per trip.'**
  String get carSharingFuelIntro;

  /// No description provided for @carSharingFuelUseAppTracking.
  ///
  /// In en, this message translates to:
  /// **'Use in-app fuel and odometer tracking'**
  String get carSharingFuelUseAppTracking;

  /// No description provided for @carSharingFuelCustomHint.
  ///
  /// In en, this message translates to:
  /// **'Describe a different arrangement (not tracked by the app)'**
  String get carSharingFuelCustomHint;

  /// No description provided for @carSharingClausesIntro.
  ///
  /// In en, this message translates to:
  /// **'Add optional clauses and suggested topics. Housing-specific rules (curfew, early withdrawal, building rules) are omitted here.'**
  String get carSharingClausesIntro;

  /// No description provided for @contactsTitle.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get contactsTitle;

  /// No description provided for @contactsPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a contact'**
  String get contactsPickerTitle;

  /// No description provided for @contactsPickerEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No selectable contacts yet'**
  String get contactsPickerEmptyTitle;

  /// No description provided for @contactsPickerEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Invite people and complete the connection in Contacts first. Only connected contacts can join this module.'**
  String get contactsPickerEmptyBody;

  /// No description provided for @contactsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No contacts yet'**
  String get contactsEmptyTitle;

  /// No description provided for @contactsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Invite someone and connect through the relay. Connected contacts can be reused across modules.'**
  String get contactsEmptyBody;

  /// No description provided for @contactsAddContactAction.
  ///
  /// In en, this message translates to:
  /// **'Invite someone'**
  String get contactsAddContactAction;

  /// No description provided for @contactsAddLocalOnlyAction.
  ///
  /// In en, this message translates to:
  /// **'Add local contact'**
  String get contactsAddLocalOnlyAction;

  /// No description provided for @contactsAddLocalOnlyTitle.
  ///
  /// In en, this message translates to:
  /// **'New contact'**
  String get contactsAddLocalOnlyTitle;

  /// No description provided for @contactsEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit contact'**
  String get contactsEditTitle;

  /// No description provided for @contactsDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get contactsDetailTitle;

  /// No description provided for @contactsDetailMissing.
  ///
  /// In en, this message translates to:
  /// **'This contact no longer exists.'**
  String get contactsDetailMissing;

  /// No description provided for @contactsInviteAction.
  ///
  /// In en, this message translates to:
  /// **'Invite a contact'**
  String get contactsInviteAction;

  /// No description provided for @contactsInviteTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite a contact'**
  String get contactsInviteTitle;

  /// No description provided for @contactsInviteIntroTitle.
  ///
  /// In en, this message translates to:
  /// **'Share a one-time code'**
  String get contactsInviteIntroTitle;

  /// No description provided for @contactsInviteIntroBody.
  ///
  /// In en, this message translates to:
  /// **'Generate a single-use code and share it outside the app (SMS, email, in person). Anyone with the code can add themselves to your contacts while the code is valid.'**
  String get contactsInviteIntroBody;

  /// No description provided for @contactsInviteValidityLabel.
  ///
  /// In en, this message translates to:
  /// **'Code valid for'**
  String get contactsInviteValidityLabel;

  /// No description provided for @contactsInviteGenerateAction.
  ///
  /// In en, this message translates to:
  /// **'Generate code'**
  String get contactsInviteGenerateAction;

  /// No description provided for @contactsInviteShareWarning.
  ///
  /// In en, this message translates to:
  /// **'Share this code with one person only. It expires automatically and stops working after being used or revoked.'**
  String get contactsInviteShareWarning;

  /// No description provided for @contactsInviteQrLabel.
  ///
  /// In en, this message translates to:
  /// **'Scan this QR code from the other device, or use the text code below.'**
  String get contactsInviteQrLabel;

  /// No description provided for @contactsInviteQrSemantics.
  ///
  /// In en, this message translates to:
  /// **'Invitation QR code'**
  String get contactsInviteQrSemantics;

  /// No description provided for @contactsInviteShortCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get contactsInviteShortCodeLabel;

  /// No description provided for @contactsInviteCopyDeepLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get contactsInviteCopyDeepLink;

  /// No description provided for @contactsInviteCopyShareText.
  ///
  /// In en, this message translates to:
  /// **'Copy invitation'**
  String get contactsInviteCopyShareText;

  /// No description provided for @contactsInviteShareText.
  ///
  /// In en, this message translates to:
  /// **'You\'re invited to connect on Bojairũ.\n\nOne-time code:\n{code}\n\nTo use it: open the Bojairũ app, go to Contacts, tap the scan/enter-code icon at the top of the screen, then paste this code. From the device that has the app installed you can also open: {link}'**
  String contactsInviteShareText(String link, String code);

  /// No description provided for @contactsInviteExpiresAt.
  ///
  /// In en, this message translates to:
  /// **'Expires {when}'**
  String contactsInviteExpiresAt(String when);

  /// No description provided for @contactsInviteDeadlineTitle.
  ///
  /// In en, this message translates to:
  /// **'Code valid until:'**
  String get contactsInviteDeadlineTitle;

  /// No description provided for @contactsInvitationStubTitle.
  ///
  /// In en, this message translates to:
  /// **'Invitation code'**
  String get contactsInvitationStubTitle;

  /// No description provided for @contactsInviteRevokeAction.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get contactsInviteRevokeAction;

  /// No description provided for @contactsInvitationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sent invitations'**
  String get contactsInvitationsTitle;

  /// No description provided for @contactsInvitationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No invitations sent yet.'**
  String get contactsInvitationsEmpty;

  /// No description provided for @contactsInvitationsItemTitle.
  ///
  /// In en, this message translates to:
  /// **'Invitation · {createdAt}'**
  String contactsInvitationsItemTitle(String createdAt);

  /// No description provided for @contactsInvitationsStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get contactsInvitationsStatusPending;

  /// No description provided for @contactsInvitationsStatusUsed.
  ///
  /// In en, this message translates to:
  /// **'Used'**
  String get contactsInvitationsStatusUsed;

  /// No description provided for @contactsInvitationsStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get contactsInvitationsStatusExpired;

  /// No description provided for @contactsInvitationsStatusRevoked.
  ///
  /// In en, this message translates to:
  /// **'Revoked'**
  String get contactsInvitationsStatusRevoked;

  /// No description provided for @contactsEnterInviteCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter a code'**
  String get contactsEnterInviteCodeTitle;

  /// No description provided for @contactsEnterInviteCodeIntro.
  ///
  /// In en, this message translates to:
  /// **'Paste or type the code you received from a contact.'**
  String get contactsEnterInviteCodeIntro;

  /// No description provided for @contactsEnterInviteCodeFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Invitation code'**
  String get contactsEnterInviteCodeFieldLabel;

  /// No description provided for @contactsEnterInviteCodeScanQr.
  ///
  /// In en, this message translates to:
  /// **'Scan QR code'**
  String get contactsEnterInviteCodeScanQr;

  /// No description provided for @contactsEnterInviteCodeScanQrHint.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at a Bojairũ invitation QR code.'**
  String get contactsEnterInviteCodeScanQrHint;

  /// No description provided for @contactsEnterInviteCodeSubmit.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get contactsEnterInviteCodeSubmit;

  /// No description provided for @contactsEnterInviteCodeValid.
  ///
  /// In en, this message translates to:
  /// **'Code format is valid'**
  String get contactsEnterInviteCodeValid;

  /// No description provided for @contactsEnterInviteCodeInvitationId.
  ///
  /// In en, this message translates to:
  /// **'Invitation id: {id}'**
  String contactsEnterInviteCodeInvitationId(String id);

  /// No description provided for @contactsHandshakeNotAvailableYet.
  ///
  /// In en, this message translates to:
  /// **'The relay handshake is not available yet. The code is valid locally, but cannot be redeemed until the relay is live.'**
  String get contactsHandshakeNotAvailableYet;

  /// No description provided for @contactsHandshakeDispatching.
  ///
  /// In en, this message translates to:
  /// **'Sending the request to the relay…'**
  String get contactsHandshakeDispatching;

  /// No description provided for @contactsHandshakeDispatched.
  ///
  /// In en, this message translates to:
  /// **'Code accepted. Establishing the contact…'**
  String get contactsHandshakeDispatched;

  /// No description provided for @contactsHandshakeCompleted.
  ///
  /// In en, this message translates to:
  /// **'Connected. The contact has been added to your list.'**
  String get contactsHandshakeCompleted;

  /// No description provided for @contactsHandshakeRejected.
  ///
  /// In en, this message translates to:
  /// **'The other person declined the connection. You can ask them for a new invitation if needed.'**
  String get contactsHandshakeRejected;

  /// No description provided for @contactsHandshakeFailed.
  ///
  /// In en, this message translates to:
  /// **'The connection attempt failed. You can try again with a fresh invitation.'**
  String get contactsHandshakeFailed;

  /// No description provided for @contactsHandshakeErrorRelayUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unable to reach the relay. Check your network and try again.'**
  String get contactsHandshakeErrorRelayUnavailable;

  /// No description provided for @contactsHandshakeErrorAlreadyCompleted.
  ///
  /// In en, this message translates to:
  /// **'This code has already been used.'**
  String get contactsHandshakeErrorAlreadyCompleted;

  /// No description provided for @contactsHandshakeErrorNonceConsumed.
  ///
  /// In en, this message translates to:
  /// **'This invitation has already been redeemed.'**
  String get contactsHandshakeErrorNonceConsumed;

  /// No description provided for @contactsHandshakeErrorExpired.
  ///
  /// In en, this message translates to:
  /// **'This invitation has expired.'**
  String get contactsHandshakeErrorExpired;

  /// No description provided for @contactsHandshakeErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong while contacting the relay.'**
  String get contactsHandshakeErrorUnknown;

  /// No description provided for @contactsIncomingTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection requests'**
  String get contactsIncomingTitle;

  /// No description provided for @contactsIncomingEmpty.
  ///
  /// In en, this message translates to:
  /// **'No pending connection requests.'**
  String get contactsIncomingEmpty;

  /// No description provided for @contactsIncomingBody.
  ///
  /// In en, this message translates to:
  /// **'{name} wants to connect.'**
  String contactsIncomingBody(String name);

  /// No description provided for @contactsIncomingAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get contactsIncomingAccept;

  /// No description provided for @contactsIncomingReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get contactsIncomingReject;

  /// No description provided for @contactsIncomingBannerOne.
  ///
  /// In en, this message translates to:
  /// **'1 new connection request'**
  String get contactsIncomingBannerOne;

  /// No description provided for @contactsIncomingBannerMany.
  ///
  /// In en, this message translates to:
  /// **'{count} new connection requests'**
  String contactsIncomingBannerMany(int count);

  /// No description provided for @contactsRefreshIncomingTooltip.
  ///
  /// In en, this message translates to:
  /// **'Check for connection requests'**
  String get contactsRefreshIncomingTooltip;

  /// No description provided for @contactsRefreshIncomingFound.
  ///
  /// In en, this message translates to:
  /// **'{count} pending connection request(s).'**
  String contactsRefreshIncomingFound(int count);

  /// No description provided for @contactsRefreshIncomingNone.
  ///
  /// In en, this message translates to:
  /// **'No pending connection requests found.'**
  String get contactsRefreshIncomingNone;

  /// No description provided for @contactsRefreshIncomingNoneWithActivePolls.
  ///
  /// In en, this message translates to:
  /// **'No pending connection requests found. Active relay poll(s): {count}.'**
  String contactsRefreshIncomingNoneWithActivePolls(int count);

  /// No description provided for @contactsRefreshIncomingDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'No pending connection requests found. Active relay poll(s): {activeCount}. Local handshake row(s): {totalCount}. Latest state: {latestState}.'**
  String contactsRefreshIncomingDiagnostics(
    int activeCount,
    int totalCount,
    String latestState,
  );

  /// No description provided for @contactsCodeErrorEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter a code to continue.'**
  String get contactsCodeErrorEmpty;

  /// No description provided for @contactsCodeErrorTooShort.
  ///
  /// In en, this message translates to:
  /// **'This code is too short.'**
  String get contactsCodeErrorTooShort;

  /// No description provided for @contactsCodeErrorTooLong.
  ///
  /// In en, this message translates to:
  /// **'This code is too long.'**
  String get contactsCodeErrorTooLong;

  /// No description provided for @contactsCodeErrorInvalidCharacters.
  ///
  /// In en, this message translates to:
  /// **'This code contains characters that are not allowed.'**
  String get contactsCodeErrorInvalidCharacters;

  /// No description provided for @contactsCodeErrorBadChecksum.
  ///
  /// In en, this message translates to:
  /// **'This code looks mistyped. Check the characters and try again.'**
  String get contactsCodeErrorBadChecksum;

  /// No description provided for @contactsCodeErrorUnsupportedVersion.
  ///
  /// In en, this message translates to:
  /// **'This code was created by a newer version of the app.'**
  String get contactsCodeErrorUnsupportedVersion;

  /// No description provided for @contactsKindLocalOnly.
  ///
  /// In en, this message translates to:
  /// **'Local only'**
  String get contactsKindLocalOnly;

  /// No description provided for @contactsKindDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get contactsKindDisconnected;

  /// No description provided for @contactsKindConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get contactsKindConnected;

  /// No description provided for @contactsKindBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get contactsKindBlocked;

  /// No description provided for @contactsKindDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get contactsKindDeleted;

  /// No description provided for @contactsFieldNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get contactsFieldNameLabel;

  /// No description provided for @contactsFieldNameHint.
  ///
  /// In en, this message translates to:
  /// **'How this person appears in the app'**
  String get contactsFieldNameHint;

  /// No description provided for @contactsFieldAvatarReadOnlyFootnote.
  ///
  /// In en, this message translates to:
  /// **'You may assign them a different name.\n\nNote: they will be notified in:\n    Settings >\n        Profile >\n            How others name you.'**
  String get contactsFieldAvatarReadOnlyFootnote;

  /// No description provided for @contactsFieldAvatarLabel.
  ///
  /// In en, this message translates to:
  /// **'Avatar'**
  String get contactsFieldAvatarLabel;

  /// No description provided for @contactsFieldNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get contactsFieldNotesLabel;

  /// No description provided for @contactsFieldNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Personal reminder, not shared'**
  String get contactsFieldNotesHint;

  /// No description provided for @contactsFieldNotesFootnote.
  ///
  /// In en, this message translates to:
  /// **'Your personal notes. They will not be shared.'**
  String get contactsFieldNotesFootnote;

  /// No description provided for @contactsDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete contact?'**
  String get contactsDeleteTitle;

  /// No description provided for @contactsDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Existing housing or vehicle entries that reference this contact will keep the name and avatar stored at the time they were added. To work with this person again, create a new local contact, or send them a new invitation.'**
  String get contactsDeleteBody;

  /// No description provided for @contactsDeletePreservesHistory.
  ///
  /// In en, this message translates to:
  /// **'Existing entries that reference this contact keep their stored name and avatar.'**
  String get contactsDeletePreservesHistory;

  /// No description provided for @contactsDeleteBlockedByPlansTitle.
  ///
  /// In en, this message translates to:
  /// **'Can\'t delete this contact yet'**
  String get contactsDeleteBlockedByPlansTitle;

  /// No description provided for @contactsDeleteBlockedByPlansBody.
  ///
  /// In en, this message translates to:
  /// **'This contact is still listed as a participant in {count, plural, =1{one plan} other{{count} plans}}: {plans}. Remove them from those plans first, then you\'ll be able to delete the contact.'**
  String contactsDeleteBlockedByPlansBody(int count, String plans);

  /// No description provided for @contactsDeleteBlockedConnectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Use Disconnect first'**
  String get contactsDeleteBlockedConnectedTitle;

  /// No description provided for @contactsDeleteBlockedConnectedBody.
  ///
  /// In en, this message translates to:
  /// **'This contact is currently connected. Just deleting it on this device would leave the other side thinking the connection is still up. Use Disconnect first: it sends an encrypted disconnect signal to the peer through the relay and downgrades the contact to local-only on this device. You can then delete the contact normally.'**
  String get contactsDeleteBlockedConnectedBody;

  /// No description provided for @contactsDeleteBlockedConnectedAction.
  ///
  /// In en, this message translates to:
  /// **'Disconnect first'**
  String get contactsDeleteBlockedConnectedAction;

  /// No description provided for @contactsBlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Block this contact?'**
  String get contactsBlockTitle;

  /// No description provided for @contactsBlockBody.
  ///
  /// In en, this message translates to:
  /// **'Incoming messages from this contact will be ignored locally. The relay is not informed of the block.'**
  String get contactsBlockBody;

  /// No description provided for @contactsUnblockTitle.
  ///
  /// In en, this message translates to:
  /// **'Unblock this contact?'**
  String get contactsUnblockTitle;

  /// No description provided for @contactsUnblockBody.
  ///
  /// In en, this message translates to:
  /// **'Incoming messages from this contact will be processed again.'**
  String get contactsUnblockBody;

  /// No description provided for @contactsDisconnectAction.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get contactsDisconnectAction;

  /// No description provided for @contactsDisconnectTitle.
  ///
  /// In en, this message translates to:
  /// **'Disconnect from this contact?'**
  String get contactsDisconnectTitle;

  /// No description provided for @contactsDisconnectBody.
  ///
  /// In en, this message translates to:
  /// **'A disconnect notice will be sent to the relay. Both sides will fall back to local-only contacts.'**
  String get contactsDisconnectBody;

  /// No description provided for @contactsDisconnectSent.
  ///
  /// In en, this message translates to:
  /// **'Disconnect notice sent. Contact is now local-only.'**
  String get contactsDisconnectSent;

  /// No description provided for @contactsReconnectAction.
  ///
  /// In en, this message translates to:
  /// **'Request reconnection'**
  String get contactsReconnectAction;

  /// No description provided for @contactsLabelEditorTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename locally'**
  String get contactsLabelEditorTitle;

  /// No description provided for @contactsLabelEditorScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename locally?'**
  String get contactsLabelEditorScreenTitle;

  /// No description provided for @contactsLabelEditorHint.
  ///
  /// In en, this message translates to:
  /// **'Leave blank to keep their original name'**
  String get contactsLabelEditorHint;

  /// No description provided for @contactsFieldTheirNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Their name'**
  String get contactsFieldTheirNameLabel;

  /// No description provided for @settingsProfileIdentityTitle.
  ///
  /// In en, this message translates to:
  /// **'Your profile'**
  String get settingsProfileIdentityTitle;

  /// No description provided for @settingsProfileIdentitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Name and avatar shown to your contacts'**
  String get settingsProfileIdentitySubtitle;

  /// No description provided for @settingsProfileAppearancesTitle.
  ///
  /// In en, this message translates to:
  /// **'How others label you'**
  String get settingsProfileAppearancesTitle;

  /// No description provided for @settingsProfileAppearancesBody.
  ///
  /// In en, this message translates to:
  /// **'Each connected contact can share the name they use for you in their list. It is delivered only inside encrypted profile updates.'**
  String get settingsProfileAppearancesBody;

  /// No description provided for @settingsProfileAppearancesColumnPeer.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get settingsProfileAppearancesColumnPeer;

  /// No description provided for @settingsProfileAppearancesColumnTheirLabel.
  ///
  /// In en, this message translates to:
  /// **'Their label for you'**
  String get settingsProfileAppearancesColumnTheirLabel;

  /// No description provided for @settingsProfileAppearancesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No connected contacts yet. Pair with someone to see how they label you here.'**
  String get settingsProfileAppearancesEmpty;

  /// No description provided for @settingsProfileAppearancesNoSharedLabels.
  ///
  /// In en, this message translates to:
  /// **'No contact has shared a custom name for you in their list yet.'**
  String get settingsProfileAppearancesNoSharedLabels;

  /// No description provided for @settingsProfileRenameBlockedBody.
  ///
  /// In en, this message translates to:
  /// **'You are part of an open housing vote on this device: {plans}. Finish or resolve that vote before changing your display name.'**
  String settingsProfileRenameBlockedBody(String plans);

  /// No description provided for @peerNameConflictTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact updated their name'**
  String get peerNameConflictTitle;

  /// No description provided for @peerNameConflictBody.
  ///
  /// In en, this message translates to:
  /// **'You label this contact \"{label}\". They now use \"{canonical}\" on their device.'**
  String peerNameConflictBody(String label, String canonical);

  /// No description provided for @peerNameConflictUseTheirs.
  ///
  /// In en, this message translates to:
  /// **'Use their name'**
  String get peerNameConflictUseTheirs;

  /// No description provided for @peerNameConflictKeepMine.
  ///
  /// In en, this message translates to:
  /// **'Keep my label'**
  String get peerNameConflictKeepMine;

  /// No description provided for @housingPastHubTitle.
  ///
  /// In en, this message translates to:
  /// **'Past agreement'**
  String get housingPastHubTitle;

  /// No description provided for @housingParticipationChangeIntroLine1.
  ///
  /// In en, this message translates to:
  /// **'A participant change is not a simple in-force amendment.'**
  String get housingParticipationChangeIntroLine1;

  /// No description provided for @housingParticipationChangeIntroLine2.
  ///
  /// In en, this message translates to:
  /// **'All options end the current plan for those who leave.'**
  String get housingParticipationChangeIntroLine2;

  /// No description provided for @housingParticipationChangeWithdrawalAction.
  ///
  /// In en, this message translates to:
  /// **'I want to withdraw from the agreement'**
  String get housingParticipationChangeWithdrawalAction;

  /// No description provided for @housingParticipationChangeEjectionAction.
  ///
  /// In en, this message translates to:
  /// **'I want to eject a participant'**
  String get housingParticipationChangeEjectionAction;

  /// No description provided for @housingParticipationChangeInviteParticipantAction.
  ///
  /// In en, this message translates to:
  /// **'I want to invite a participant'**
  String get housingParticipationChangeInviteParticipantAction;

  /// No description provided for @housingParticipationChangeInviteParticipantTitle.
  ///
  /// In en, this message translates to:
  /// **'Inviting a participant'**
  String get housingParticipationChangeInviteParticipantTitle;

  /// No description provided for @housingParticipationChangeInviteParticipantBody.
  ///
  /// In en, this message translates to:
  /// **'Adding someone to an active agreement requires ending the current plan and starting a new one with everyone’s consent. Read why in the FAQ.'**
  String get housingParticipationChangeInviteParticipantBody;

  /// No description provided for @housingParticipationChangeInviteParticipantFaqLink.
  ///
  /// In en, this message translates to:
  /// **'Read the FAQ'**
  String get housingParticipationChangeInviteParticipantFaqLink;

  /// No description provided for @helpFaqTitle.
  ///
  /// In en, this message translates to:
  /// **'Frequently asked questions'**
  String get helpFaqTitle;

  /// No description provided for @helpFaqIntro.
  ///
  /// In en, this message translates to:
  /// **'Answers to common questions about how Bojairũ works.'**
  String get helpFaqIntro;

  /// No description provided for @housingVoteRefusedByAgreementExpiration.
  ///
  /// In en, this message translates to:
  /// **'Refused — agreement expired'**
  String get housingVoteRefusedByAgreementExpiration;

  /// No description provided for @contactsDisconnectBlockedByPlansTitle.
  ///
  /// In en, this message translates to:
  /// **'Can\'t disconnect this contact yet'**
  String get contactsDisconnectBlockedByPlansTitle;

  /// No description provided for @contactsDisconnectBlockedByPlansBody.
  ///
  /// In en, this message translates to:
  /// **'This contact is part of an active housing agreement or an open vote on this device: {plans}. Finish or resolve that plan activity before disconnecting.'**
  String contactsDisconnectBlockedByPlansBody(String plans);

  /// No description provided for @housingParticipationChangeConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get housingParticipationChangeConfirmAction;

  /// No description provided for @housingParticipationChangeWithdrawalConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm your withdrawal?'**
  String get housingParticipationChangeWithdrawalConfirmTitle;

  /// No description provided for @housingParticipationChangeWithdrawalConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Planned departure date: {date}. Other participants must acknowledge your notice within five calendar days. Your departure takes effect on that date once everyone has acknowledged.'**
  String housingParticipationChangeWithdrawalConfirmBody(String date);

  /// No description provided for @housingParticipationChangeWithdrawalPenaltyHint.
  ///
  /// In en, this message translates to:
  /// **'An early withdrawal penalty of {amount} applies.'**
  String housingParticipationChangeWithdrawalPenaltyHint(String amount);

  /// No description provided for @housingEarlyWithdrawalPenaltyDescription.
  ///
  /// In en, this message translates to:
  /// **'Early departure penalty'**
  String get housingEarlyWithdrawalPenaltyDescription;

  /// No description provided for @housingEarlyWithdrawalPenaltyOwedTo.
  ///
  /// In en, this message translates to:
  /// **'This amount is owed to {name}.'**
  String housingEarlyWithdrawalPenaltyOwedTo(String name);

  /// No description provided for @housingParticipationChangeEjectionConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Eject a participant?'**
  String get housingParticipationChangeEjectionConfirmTitle;

  /// No description provided for @housingParticipationChangeEjectionConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Other participants must accept. The candidate is removed if accepted unanimously.'**
  String get housingParticipationChangeEjectionConfirmBody;

  /// No description provided for @housingParticipationChangeDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Major change'**
  String get housingParticipationChangeDetailTitle;

  /// No description provided for @housingParticipationChangeDetailWithdrawalBody.
  ///
  /// In en, this message translates to:
  /// **'{name} will leave the agreement on {date}.'**
  String housingParticipationChangeDetailWithdrawalBody(
    String name,
    String date,
  );

  /// No description provided for @housingParticipationChangeDetailEjectionBody.
  ///
  /// In en, this message translates to:
  /// **'{initiator} requests to eject {target}.'**
  String housingParticipationChangeDetailEjectionBody(
    String initiator,
    String target,
  );

  /// No description provided for @housingParticipationChangeAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get housingParticipationChangeAccept;

  /// No description provided for @housingParticipationChangeReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get housingParticipationChangeReject;

  /// No description provided for @housingParticipationChangeAcknowledge.
  ///
  /// In en, this message translates to:
  /// **'Acknowledge'**
  String get housingParticipationChangeAcknowledge;

  /// No description provided for @housingParticipationChangeAcknowledgementStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Acknowledgements'**
  String get housingParticipationChangeAcknowledgementStatusTitle;

  /// No description provided for @housingParticipationChangeWithdrawalPeerNotice.
  ///
  /// In en, this message translates to:
  /// **'Enter any useful expenses before {departureDate}. You may acknowledge this notice until {ackDeadline}.'**
  String housingParticipationChangeWithdrawalPeerNotice(
    String departureDate,
    String ackDeadline,
  );

  /// No description provided for @housingParticipationChangeEjectionCandidateNotice.
  ///
  /// In en, this message translates to:
  /// **'You are the participant named in this ejection request. The remaining participants must vote; you cannot accept or reject here.'**
  String get housingParticipationChangeEjectionCandidateNotice;

  /// No description provided for @housingParticipationChangeDecisionStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Votes'**
  String get housingParticipationChangeDecisionStatusTitle;

  /// No description provided for @housingParticipationChangeDecisionPending.
  ///
  /// In en, this message translates to:
  /// **'{name}: pending'**
  String housingParticipationChangeDecisionPending(String name);

  /// No description provided for @housingParticipationChangeDecisionAccepted.
  ///
  /// In en, this message translates to:
  /// **'{name}: accepted'**
  String housingParticipationChangeDecisionAccepted(String name);

  /// No description provided for @housingParticipationChangeDecisionRejected.
  ///
  /// In en, this message translates to:
  /// **'{name}: rejected'**
  String housingParticipationChangeDecisionRejected(String name);

  /// No description provided for @housingParticipationChangePenaltyApplies.
  ///
  /// In en, this message translates to:
  /// **'An early withdrawal penalty will apply.'**
  String get housingParticipationChangePenaltyApplies;

  /// No description provided for @housingParticipationChangePenaltyDoesNotApply.
  ///
  /// In en, this message translates to:
  /// **'No early withdrawal penalty will apply.'**
  String get housingParticipationChangePenaltyDoesNotApply;

  /// No description provided for @housingParticipationChangeBannerWithdrawal.
  ///
  /// In en, this message translates to:
  /// **'{name} is leaving the agreement'**
  String housingParticipationChangeBannerWithdrawal(String name);

  /// No description provided for @housingParticipationChangeBannerEjection.
  ///
  /// In en, this message translates to:
  /// **'{initiator} requests to eject {target}.'**
  String housingParticipationChangeBannerEjection(
    String initiator,
    String target,
  );

  /// No description provided for @housingParticipationChangeEjectionHubSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ejection request in progress...'**
  String get housingParticipationChangeEjectionHubSubtitle;

  /// No description provided for @pushNotificationHousingParticipationChangeTitle.
  ///
  /// In en, this message translates to:
  /// **'Major change'**
  String get pushNotificationHousingParticipationChangeTitle;

  /// No description provided for @pushNotificationHousingParticipationChangeBody.
  ///
  /// In en, this message translates to:
  /// **'A co-participant requested a major change.'**
  String get pushNotificationHousingParticipationChangeBody;

  /// No description provided for @pushNotificationHousingParticipationChangeBodyFrom.
  ///
  /// In en, this message translates to:
  /// **'{name} requested a major change.'**
  String pushNotificationHousingParticipationChangeBodyFrom(String name);

  /// No description provided for @housingParticipationJournalSubjectWithdrawal.
  ///
  /// In en, this message translates to:
  /// **'Voluntary withdrawal'**
  String get housingParticipationJournalSubjectWithdrawal;

  /// No description provided for @housingParticipationJournalSubjectEjection.
  ///
  /// In en, this message translates to:
  /// **'Participant ejection'**
  String get housingParticipationJournalSubjectEjection;

  /// No description provided for @housingParticipationJournalProposed.
  ///
  /// In en, this message translates to:
  /// **'Proposed'**
  String get housingParticipationJournalProposed;

  /// No description provided for @housingParticipationJournalDecisionAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get housingParticipationJournalDecisionAccepted;

  /// No description provided for @housingParticipationJournalDecisionRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get housingParticipationJournalDecisionRejected;

  /// No description provided for @housingParticipationJournalEffective.
  ///
  /// In en, this message translates to:
  /// **'Effective'**
  String get housingParticipationJournalEffective;

  /// No description provided for @housingParticipationJournalAborted.
  ///
  /// In en, this message translates to:
  /// **'Aborted'**
  String get housingParticipationJournalAborted;

  /// No description provided for @housingParticipationJournalSubjectLine.
  ///
  /// In en, this message translates to:
  /// **'{kind} — {event}'**
  String housingParticipationJournalSubjectLine(String kind, String event);

  /// No description provided for @housingInactiveSettlementTitle.
  ///
  /// In en, this message translates to:
  /// **'Settle with inactive participant'**
  String get housingInactiveSettlementTitle;

  /// No description provided for @housingInactiveSettlementTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Record a transfer to close the balance'**
  String get housingInactiveSettlementTileSubtitle;

  /// No description provided for @housingInactiveSettlementParticipantLabel.
  ///
  /// In en, this message translates to:
  /// **'Former participant: {name}'**
  String housingInactiveSettlementParticipantLabel(String name);

  /// No description provided for @housingInactiveSettlementCurrentBalance.
  ///
  /// In en, this message translates to:
  /// **'Current balance: {amount}'**
  String housingInactiveSettlementCurrentBalance(String amount);

  /// No description provided for @housingInactiveSettlementAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Transfer amount'**
  String get housingInactiveSettlementAmountLabel;

  /// No description provided for @housingInactiveSettlementAmountHint.
  ///
  /// In en, this message translates to:
  /// **'Positive: you pay them. Negative: they pay you.'**
  String get housingInactiveSettlementAmountHint;

  /// No description provided for @housingInactiveSettlementSubmit.
  ///
  /// In en, this message translates to:
  /// **'Publish settlement transfer'**
  String get housingInactiveSettlementSubmit;

  /// No description provided for @housingInactiveSettlementSuccess.
  ///
  /// In en, this message translates to:
  /// **'Settlement transfer recorded.'**
  String get housingInactiveSettlementSuccess;

  /// No description provided for @housingInactiveSettlementTransferDescription.
  ///
  /// In en, this message translates to:
  /// **'Settlement with former participant'**
  String get housingInactiveSettlementTransferDescription;

  /// No description provided for @housingInactiveSettlementErrorZero.
  ///
  /// In en, this message translates to:
  /// **'Enter a non-zero amount.'**
  String get housingInactiveSettlementErrorZero;

  /// No description provided for @housingInactiveSettlementErrorCannotCreateCredit.
  ///
  /// In en, this message translates to:
  /// **'This transfer would create a new balance in their favor.'**
  String get housingInactiveSettlementErrorCannotCreateCredit;

  /// No description provided for @housingInactiveSettlementErrorExceedsDebt.
  ///
  /// In en, this message translates to:
  /// **'Amount exceeds what they owe.'**
  String get housingInactiveSettlementErrorExceedsDebt;

  /// No description provided for @housingInactiveSettlementErrorCannotIncreaseDebt.
  ///
  /// In en, this message translates to:
  /// **'This transfer would increase what they owe.'**
  String get housingInactiveSettlementErrorCannotIncreaseDebt;

  /// No description provided for @housingInactiveSettlementErrorExceedsCredit.
  ///
  /// In en, this message translates to:
  /// **'Amount exceeds what is owed to them.'**
  String get housingInactiveSettlementErrorExceedsCredit;

  /// No description provided for @vehicleLicensingRequired.
  ///
  /// In en, this message translates to:
  /// **'Vehicle module requires an active subscription.'**
  String get vehicleLicensingRequired;

  /// No description provided for @vehicleSharingLicensingRequired.
  ///
  /// In en, this message translates to:
  /// **'Vehicle sharing requires an active subscription.'**
  String get vehicleSharingLicensingRequired;

  /// No description provided for @vehicleQuickActionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get vehicleQuickActionsTitle;

  /// No description provided for @vehicleMyVehiclesTitle.
  ///
  /// In en, this message translates to:
  /// **'My vehicles'**
  String get vehicleMyVehiclesTitle;

  /// No description provided for @vehicleMyVehiclesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No vehicles yet. Tap + to add one.'**
  String get vehicleMyVehiclesEmpty;

  /// No description provided for @vehicleOwnedActiveLimitReached.
  ///
  /// In en, this message translates to:
  /// **'Limit reached: at most 3 active vehicles.'**
  String get vehicleOwnedActiveLimitReached;

  /// No description provided for @vehicleDeactivatedLabel.
  ///
  /// In en, this message translates to:
  /// **'Deactivated {date}'**
  String vehicleDeactivatedLabel(String date);

  /// No description provided for @vehicleDeactivateAction.
  ///
  /// In en, this message translates to:
  /// **'Deactivate this vehicle'**
  String get vehicleDeactivateAction;

  /// No description provided for @vehicleDeactivateDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Deactivate this vehicle?'**
  String get vehicleDeactivateDialogTitle;

  /// No description provided for @vehicleDeactivateDialogBody.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone. You can still view the history, but no new entries or use sessions will be allowed for this vehicle.'**
  String get vehicleDeactivateDialogBody;

  /// No description provided for @vehicleDeactivateConfirm.
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get vehicleDeactivateConfirm;

  /// No description provided for @vehicleDeactivateBlockedOpenSession.
  ///
  /// In en, this message translates to:
  /// **'End the open use session first.'**
  String get vehicleDeactivateBlockedOpenSession;

  /// No description provided for @vehicleExportDataAction.
  ///
  /// In en, this message translates to:
  /// **'Export data'**
  String get vehicleExportDataAction;

  /// No description provided for @vehicleExportConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Export of factual vehicle data only.\n\nUse case: provide the data to another user during a transfer of ownership.'**
  String get vehicleExportConfirmBody;

  /// No description provided for @vehicleExportConfirmExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get vehicleExportConfirmExport;

  /// No description provided for @vehicleExportSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Export complete'**
  String get vehicleExportSuccessTitle;

  /// No description provided for @vehicleExportSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'File saved in Documents/Bojairũ/\n{fileName}'**
  String vehicleExportSuccessBody(String fileName);

  /// No description provided for @vehicleExportFileDataOfSegment.
  ///
  /// In en, this message translates to:
  /// **'Data-of'**
  String get vehicleExportFileDataOfSegment;

  /// No description provided for @vehicleExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed. Please try again.'**
  String get vehicleExportFailed;

  /// No description provided for @vehicleImportAction.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get vehicleImportAction;

  /// No description provided for @vehicleImportConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'You can import vehicle data exported by another user here.\n\nYou need the export file copied locally onto this device.'**
  String get vehicleImportConfirmBody;

  /// No description provided for @vehicleImportConfirmImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get vehicleImportConfirmImport;

  /// No description provided for @vehicleImportFailInvalid.
  ///
  /// In en, this message translates to:
  /// **'This file is not a valid vehicle export.'**
  String get vehicleImportFailInvalid;

  /// No description provided for @vehicleImportFailCorrupt.
  ///
  /// In en, this message translates to:
  /// **'Import failed. The file appears to be corrupted. Try again with another copy.'**
  String get vehicleImportFailCorrupt;

  /// No description provided for @vehicleImportFailOther.
  ///
  /// In en, this message translates to:
  /// **'Import failed. Please try again.'**
  String get vehicleImportFailOther;

  /// No description provided for @vehicleSaleImportUndoAction.
  ///
  /// In en, this message translates to:
  /// **'Undo import'**
  String get vehicleSaleImportUndoAction;

  /// No description provided for @vehicleSaleImportUndoConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Imported data for “{label}” will be permanently deleted.'**
  String vehicleSaleImportUndoConfirmBody(String label);

  /// No description provided for @vehicleSaleImportConfirmActionBody.
  ///
  /// In en, this message translates to:
  /// **'This action confirms the import of this vehicle. You will no longer be able to undo the import.'**
  String get vehicleSaleImportConfirmActionBody;

  /// No description provided for @vehicleSaleImportConfirmActionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get vehicleSaleImportConfirmActionConfirm;

  /// No description provided for @vehicleAddVehicle.
  ///
  /// In en, this message translates to:
  /// **'Add vehicle'**
  String get vehicleAddVehicle;

  /// No description provided for @vehicleAddFirst.
  ///
  /// In en, this message translates to:
  /// **'Add a vehicle first.'**
  String get vehicleAddFirst;

  /// No description provided for @vehicleFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get vehicleFieldLabel;

  /// No description provided for @vehicleFieldKind.
  ///
  /// In en, this message translates to:
  /// **'Vehicle kind'**
  String get vehicleFieldKind;

  /// No description provided for @vehicleFieldMake.
  ///
  /// In en, this message translates to:
  /// **'Make'**
  String get vehicleFieldMake;

  /// No description provided for @vehicleFieldModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get vehicleFieldModel;

  /// No description provided for @vehicleFieldColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get vehicleFieldColor;

  /// No description provided for @vehicleFieldYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get vehicleFieldYear;

  /// No description provided for @vehicleFieldInitialOdometer.
  ///
  /// In en, this message translates to:
  /// **'Initial odometer'**
  String get vehicleFieldInitialOdometer;

  /// No description provided for @vehicleFieldInitialHorometer.
  ///
  /// In en, this message translates to:
  /// **'Initial engine hour meter'**
  String get vehicleFieldInitialHorometer;

  /// No description provided for @vehicleFieldLicensePlate.
  ///
  /// In en, this message translates to:
  /// **'License plate'**
  String get vehicleFieldLicensePlate;

  /// No description provided for @vehicleFieldVin.
  ///
  /// In en, this message translates to:
  /// **'Vehicle identification number (VIN)'**
  String get vehicleFieldVin;

  /// No description provided for @vehicleFieldOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get vehicleFieldOptional;

  /// No description provided for @vehicleAddPhotosSection.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get vehicleAddPhotosSection;

  /// No description provided for @vehicleAddPhotosOptionalHint.
  ///
  /// In en, this message translates to:
  /// **'Visual archive of the vehicle\'s condition (optional).'**
  String get vehicleAddPhotosOptionalHint;

  /// No description provided for @vehicleAddGalleryStart.
  ///
  /// In en, this message translates to:
  /// **'Add a gallery'**
  String get vehicleAddGalleryStart;

  /// No description provided for @vehicleAddPhotoGalleryStart.
  ///
  /// In en, this message translates to:
  /// **'Add a photo gallery'**
  String get vehicleAddPhotoGalleryStart;

  /// No description provided for @vehicleAddGalleryTitle.
  ///
  /// In en, this message translates to:
  /// **'Gallery {index}'**
  String vehicleAddGalleryTitle(int index);

  /// No description provided for @vehicleAddGalleryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No photos in this gallery yet.'**
  String get vehicleAddGalleryEmpty;

  /// No description provided for @vehicleAddGalleryDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get vehicleAddGalleryDescription;

  /// No description provided for @vehicleAddGalleryAddPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get vehicleAddGalleryAddPhoto;

  /// No description provided for @vehicleAddGalleryAddGallery.
  ///
  /// In en, this message translates to:
  /// **'Add another gallery'**
  String get vehicleAddGalleryAddGallery;

  /// No description provided for @vehicleAddValidationLabelRequired.
  ///
  /// In en, this message translates to:
  /// **'Display name is required.'**
  String get vehicleAddValidationLabelRequired;

  /// No description provided for @vehicleAddValidationMakeRequired.
  ///
  /// In en, this message translates to:
  /// **'Make is required.'**
  String get vehicleAddValidationMakeRequired;

  /// No description provided for @vehicleAddValidationModelRequired.
  ///
  /// In en, this message translates to:
  /// **'Model is required.'**
  String get vehicleAddValidationModelRequired;

  /// No description provided for @vehicleAddValidationColorRequired.
  ///
  /// In en, this message translates to:
  /// **'Color is required.'**
  String get vehicleAddValidationColorRequired;

  /// No description provided for @vehicleAddValidationYearInvalid.
  ///
  /// In en, this message translates to:
  /// **'Year must be a valid four-digit value.'**
  String get vehicleAddValidationYearInvalid;

  /// No description provided for @vehicleAddValidationMeterRequired.
  ///
  /// In en, this message translates to:
  /// **'Initial meter reading is required.'**
  String get vehicleAddValidationMeterRequired;

  /// No description provided for @vehicleAddValidationFluidChangeFrequencyRequired.
  ///
  /// In en, this message translates to:
  /// **'Oil changes are required.'**
  String get vehicleAddValidationFluidChangeFrequencyRequired;

  /// No description provided for @vehicleAddValidationRequiredFields.
  ///
  /// In en, this message translates to:
  /// **'Complete all required fields, including the odometer photo.'**
  String get vehicleAddValidationRequiredFields;

  /// No description provided for @vehicleOdometerPhotoLabel.
  ///
  /// In en, this message translates to:
  /// **'Odometer photo'**
  String get vehicleOdometerPhotoLabel;

  /// No description provided for @vehicleEditDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit details'**
  String get vehicleEditDetailsTitle;

  /// No description provided for @vehicleJournalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get vehicleJournalsTitle;

  /// No description provided for @vehicleJournalSelectorLabel.
  ///
  /// In en, this message translates to:
  /// **'Log'**
  String get vehicleJournalSelectorLabel;

  /// No description provided for @vehicleFormVehicleLabel.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get vehicleFormVehicleLabel;

  /// No description provided for @vehicleJournalEmpty.
  ///
  /// In en, this message translates to:
  /// **'No entries yet.'**
  String get vehicleJournalEmpty;

  /// No description provided for @vehicleLogRecordedAt.
  ///
  /// In en, this message translates to:
  /// **'Recorded on'**
  String get vehicleLogRecordedAt;

  /// No description provided for @vehicleLogReadingRole.
  ///
  /// In en, this message translates to:
  /// **'Reading type'**
  String get vehicleLogReadingRole;

  /// No description provided for @vehicleLogReadingRoleSessionEnd.
  ///
  /// In en, this message translates to:
  /// **'{userName} - End'**
  String vehicleLogReadingRoleSessionEnd(String userName);

  /// No description provided for @vehicleLogReadingRoleSessionStart.
  ///
  /// In en, this message translates to:
  /// **'{userName} - Start'**
  String vehicleLogReadingRoleSessionStart(String userName);

  /// No description provided for @vehicleLogReadingRoleStandalone.
  ///
  /// In en, this message translates to:
  /// **'One-time reading'**
  String get vehicleLogReadingRoleStandalone;

  /// No description provided for @vehicleLogReadingRoleFuelPurchase.
  ///
  /// In en, this message translates to:
  /// **'Fuel purchase'**
  String get vehicleLogReadingRoleFuelPurchase;

  /// No description provided for @vehicleLogReadingRoleCorrection.
  ///
  /// In en, this message translates to:
  /// **'Correction'**
  String get vehicleLogReadingRoleCorrection;

  /// No description provided for @vehicleLogReadingRoleCorrectionBy.
  ///
  /// In en, this message translates to:
  /// **'Correction by {userName}'**
  String vehicleLogReadingRoleCorrectionBy(String userName);

  /// No description provided for @vehicleLogReadingRoleCorrectionSessionStart.
  ///
  /// In en, this message translates to:
  /// **'Correction by {userName} at session start'**
  String vehicleLogReadingRoleCorrectionSessionStart(String userName);

  /// No description provided for @vehicleLogReadingRoleCorrectionStandalone.
  ///
  /// In en, this message translates to:
  /// **'Correction by {userName} during a one-time reading'**
  String vehicleLogReadingRoleCorrectionStandalone(String userName);

  /// No description provided for @vehicleLogCorrectionJournalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Odometer correction to verify'**
  String get vehicleLogCorrectionJournalSubtitle;

  /// No description provided for @vehicleLogCorrectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Correction'**
  String get vehicleLogCorrectionLabel;

  /// No description provided for @vehicleLogCorrectionMustBeAttributed.
  ///
  /// In en, this message translates to:
  /// **'{gap} must be attributed'**
  String vehicleLogCorrectionMustBeAttributed(String gap);

  /// No description provided for @vehicleLogCorrectionGapMustBeAdded.
  ///
  /// In en, this message translates to:
  /// **'{gap} must be added'**
  String vehicleLogCorrectionGapMustBeAdded(String gap);

  /// No description provided for @vehicleLogCorrectionGapMustBeRemoved.
  ///
  /// In en, this message translates to:
  /// **'{gap} must be removed'**
  String vehicleLogCorrectionGapMustBeRemoved(String gap);

  /// No description provided for @vehiclePendingCorrectionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Pending corrections'**
  String get vehiclePendingCorrectionsTitle;

  /// No description provided for @vehiclePendingCorrectionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No pending corrections.'**
  String get vehiclePendingCorrectionsEmpty;

  /// No description provided for @vehiclePendingCorrectionDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Odometer correction'**
  String get vehiclePendingCorrectionDetailTitle;

  /// No description provided for @vehicleCorrectReadingButton.
  ///
  /// In en, this message translates to:
  /// **'Correct entry from {date}'**
  String vehicleCorrectReadingButton(String date);

  /// No description provided for @vehicleAddMissingSessionButton.
  ///
  /// In en, this message translates to:
  /// **'Add a use session'**
  String get vehicleAddMissingSessionButton;

  /// No description provided for @vehicleSplitSessionButton.
  ///
  /// In en, this message translates to:
  /// **'Split session'**
  String get vehicleSplitSessionButton;

  /// No description provided for @vehicleGapResolutionSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get vehicleGapResolutionSubmit;

  /// No description provided for @vehicleLogReadingRoleCorrectionApplied.
  ///
  /// In en, this message translates to:
  /// **'Correction applied'**
  String get vehicleLogReadingRoleCorrectionApplied;

  /// No description provided for @vehicleLogCorrectionAppliedSummary.
  ///
  /// In en, this message translates to:
  /// **'{km} were attributed to {name}'**
  String vehicleLogCorrectionAppliedSummary(String km, String name);

  /// No description provided for @vehicleLogCorrectionAppliedSplitSummary.
  ///
  /// In en, this message translates to:
  /// **'{km} were attributed (split)'**
  String vehicleLogCorrectionAppliedSplitSummary(String km);

  /// No description provided for @vehicleLogReadingRoleCorrectionReplaces.
  ///
  /// In en, this message translates to:
  /// **'Correction — replaces {label}'**
  String vehicleLogReadingRoleCorrectionReplaces(String label);

  /// No description provided for @vehicleLogCorrectionAppliedDivergence.
  ///
  /// In en, this message translates to:
  /// **'Observed gap: {gap}'**
  String vehicleLogCorrectionAppliedDivergence(String gap);

  /// No description provided for @vehicleGapResolutionPreviousReading.
  ///
  /// In en, this message translates to:
  /// **'Previous reading'**
  String get vehicleGapResolutionPreviousReading;

  /// No description provided for @vehicleGapResolutionTriggerReading.
  ///
  /// In en, this message translates to:
  /// **'Subsequent reading'**
  String get vehicleGapResolutionTriggerReading;

  /// No description provided for @vehicleGapResolutionValidationMonotonicity.
  ///
  /// In en, this message translates to:
  /// **'This value would conflict with another reading.'**
  String get vehicleGapResolutionValidationMonotonicity;

  /// No description provided for @vehicleGapResolutionValidationSegment.
  ///
  /// In en, this message translates to:
  /// **'Segments do not cover the gap correctly.'**
  String get vehicleGapResolutionValidationSegment;

  /// No description provided for @vehicleGapResolutionValidationDateOverlap.
  ///
  /// In en, this message translates to:
  /// **'Segment dates overlap.'**
  String get vehicleGapResolutionValidationDateOverlap;

  /// No description provided for @vehicleGapResolutionAssignTo.
  ///
  /// In en, this message translates to:
  /// **'Assign to'**
  String get vehicleGapResolutionAssignTo;

  /// No description provided for @vehicleGapResolutionDates.
  ///
  /// In en, this message translates to:
  /// **'Date(s)'**
  String get vehicleGapResolutionDates;

  /// No description provided for @vehicleGapResolutionStartMeter.
  ///
  /// In en, this message translates to:
  /// **'Start odometer'**
  String get vehicleGapResolutionStartMeter;

  /// No description provided for @vehicleGapResolutionEndMeter.
  ///
  /// In en, this message translates to:
  /// **'End odometer'**
  String get vehicleGapResolutionEndMeter;

  /// No description provided for @vehicleLogMeterTitle.
  ///
  /// In en, this message translates to:
  /// **'Log — odometer'**
  String get vehicleLogMeterTitle;

  /// No description provided for @vehicleLogMeterFuelTitle.
  ///
  /// In en, this message translates to:
  /// **'Odometer and fuel'**
  String get vehicleLogMeterFuelTitle;

  /// No description provided for @vehicleLogMeterDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Reading details'**
  String get vehicleLogMeterDetailTitle;

  /// No description provided for @vehicleLogFuelTitle.
  ///
  /// In en, this message translates to:
  /// **'Log — fuel'**
  String get vehicleLogFuelTitle;

  /// No description provided for @vehicleLogFuelDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Purchase details'**
  String get vehicleLogFuelDetailTitle;

  /// No description provided for @vehicleFuelPurchaseMadeBy.
  ///
  /// In en, this message translates to:
  /// **'Purchased by: {name}'**
  String vehicleFuelPurchaseMadeBy(String name);

  /// No description provided for @vehicleLogMaintenanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get vehicleLogMaintenanceTitle;

  /// No description provided for @vehicleLogMaintenanceDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Maintenance details'**
  String get vehicleLogMaintenanceDetailTitle;

  /// No description provided for @vehicleLogViolationTitle.
  ///
  /// In en, this message translates to:
  /// **'Damage and violations'**
  String get vehicleLogViolationTitle;

  /// No description provided for @vehicleLogViolationDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Violation details'**
  String get vehicleLogViolationDetailTitle;

  /// No description provided for @vehicleKindCar.
  ///
  /// In en, this message translates to:
  /// **'Car'**
  String get vehicleKindCar;

  /// No description provided for @vehicleKindTruck.
  ///
  /// In en, this message translates to:
  /// **'Truck'**
  String get vehicleKindTruck;

  /// No description provided for @vehicleKindMotorcycle.
  ///
  /// In en, this message translates to:
  /// **'Motorcycle'**
  String get vehicleKindMotorcycle;

  /// No description provided for @vehicleKindBoat.
  ///
  /// In en, this message translates to:
  /// **'Boat'**
  String get vehicleKindBoat;

  /// No description provided for @vehicleQuickActionOdometer.
  ///
  /// In en, this message translates to:
  /// **'Odometer reading'**
  String get vehicleQuickActionOdometer;

  /// No description provided for @vehicleUseSessionStartAction.
  ///
  /// In en, this message translates to:
  /// **'Start a use session'**
  String get vehicleUseSessionStartAction;

  /// No description provided for @vehicleUseSessionEndAction.
  ///
  /// In en, this message translates to:
  /// **'End a use session'**
  String get vehicleUseSessionEndAction;

  /// No description provided for @vehicleUseSessionStartedOn.
  ///
  /// In en, this message translates to:
  /// **'started on {dateTime}'**
  String vehicleUseSessionStartedOn(String dateTime);

  /// No description provided for @vehicleQuickActionFuel.
  ///
  /// In en, this message translates to:
  /// **'Fuel purchase'**
  String get vehicleQuickActionFuel;

  /// No description provided for @vehicleQuickActionMaintenance.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get vehicleQuickActionMaintenance;

  /// No description provided for @vehicleQuickActionViolation.
  ///
  /// In en, this message translates to:
  /// **'Damage or violation'**
  String get vehicleQuickActionViolation;

  /// No description provided for @vehicleOdometerLabel.
  ///
  /// In en, this message translates to:
  /// **'Odometer'**
  String get vehicleOdometerLabel;

  /// No description provided for @vehicleHorometerLabel.
  ///
  /// In en, this message translates to:
  /// **'Engine hour meter'**
  String get vehicleHorometerLabel;

  /// No description provided for @vehicleMeterPhotoRequired.
  ///
  /// In en, this message translates to:
  /// **'A meter photo is required.'**
  String get vehicleMeterPhotoRequired;

  /// No description provided for @vehicleMeterPhotoAdd.
  ///
  /// In en, this message translates to:
  /// **'Add meter photo'**
  String get vehicleMeterPhotoAdd;

  /// No description provided for @vehicleMeterPhotoAttached.
  ///
  /// In en, this message translates to:
  /// **'Photo attached'**
  String get vehicleMeterPhotoAttached;

  /// No description provided for @vehicleMeterKnownUnchangedNoPhotoOdometer.
  ///
  /// In en, this message translates to:
  /// **'Known odometer unchanged. No photo recorded.'**
  String get vehicleMeterKnownUnchangedNoPhotoOdometer;

  /// No description provided for @vehicleMeterKnownUnchangedNoPhotoHorometer.
  ///
  /// In en, this message translates to:
  /// **'Known engine hour meter unchanged. No photo recorded.'**
  String get vehicleMeterKnownUnchangedNoPhotoHorometer;

  /// No description provided for @vehicleMeterPhotoCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get vehicleMeterPhotoCamera;

  /// No description provided for @vehicleMeterPhotoGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get vehicleMeterPhotoGallery;

  /// No description provided for @vehicleUseSessionStart.
  ///
  /// In en, this message translates to:
  /// **'Start use session'**
  String get vehicleUseSessionStart;

  /// No description provided for @vehicleUseSessionEnd.
  ///
  /// In en, this message translates to:
  /// **'End use session'**
  String get vehicleUseSessionEnd;

  /// No description provided for @vehicleUseSessionStarted.
  ///
  /// In en, this message translates to:
  /// **'Session started. End it when you finish driving.'**
  String get vehicleUseSessionStarted;

  /// No description provided for @vehicleUseSessionEnded.
  ///
  /// In en, this message translates to:
  /// **'Session ended.'**
  String get vehicleUseSessionEnded;

  /// No description provided for @vehicleConsumptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Consumption'**
  String get vehicleConsumptionTitle;

  /// No description provided for @vehicleConsumptionInsufficient.
  ///
  /// In en, this message translates to:
  /// **'Insufficient data for consumption'**
  String get vehicleConsumptionInsufficient;

  /// No description provided for @vehicleConsumptionPer100Km.
  ///
  /// In en, this message translates to:
  /// **'{value} L/100 km'**
  String vehicleConsumptionPer100Km(String value);

  /// No description provided for @vehicleConsumptionPerHour.
  ///
  /// In en, this message translates to:
  /// **'{value} L/h'**
  String vehicleConsumptionPerHour(String value);

  /// No description provided for @vehicleDrivingConditionColumn.
  ///
  /// In en, this message translates to:
  /// **'Condition'**
  String get vehicleDrivingConditionColumn;

  /// No description provided for @vehicleDrivingConditionProportionColumn.
  ///
  /// In en, this message translates to:
  /// **'Share of distance'**
  String get vehicleDrivingConditionProportionColumn;

  /// No description provided for @vehicleDrivingConditionRoute.
  ///
  /// In en, this message translates to:
  /// **'Highway'**
  String get vehicleDrivingConditionRoute;

  /// No description provided for @vehicleDrivingConditionCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get vehicleDrivingConditionCity;

  /// No description provided for @vehicleDrivingConditionTraffic.
  ///
  /// In en, this message translates to:
  /// **'Traffic'**
  String get vehicleDrivingConditionTraffic;

  /// No description provided for @vehicleConsumptionReliabilityNone.
  ///
  /// In en, this message translates to:
  /// **'There is not enough data to calculate fuel consumption.'**
  String get vehicleConsumptionReliabilityNone;

  /// No description provided for @vehicleConsumptionReliabilityPreliminary.
  ///
  /// In en, this message translates to:
  /// **'This estimate is preliminary. It will become more accurate as you add more data.'**
  String get vehicleConsumptionReliabilityPreliminary;

  /// No description provided for @vehicleConsumptionReliabilityReliable.
  ///
  /// In en, this message translates to:
  /// **'This estimate is reliable, based on the calculation formula and the data you entered.'**
  String get vehicleConsumptionReliabilityReliable;

  /// No description provided for @vehicleConsumptionReliabilityVeryReliable.
  ///
  /// In en, this message translates to:
  /// **'This estimate is very reliable because it is based on a large amount of data you entered.'**
  String get vehicleConsumptionReliabilityVeryReliable;

  /// No description provided for @vehicleConsumptionEstimationModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Fuel consumption estimation mode'**
  String get vehicleConsumptionEstimationModeTitle;

  /// No description provided for @vehicleConsumptionEstimationModeSimpleTitle.
  ///
  /// In en, this message translates to:
  /// **'Simple'**
  String get vehicleConsumptionEstimationModeSimpleTitle;

  /// No description provided for @vehicleConsumptionEstimationModeSimpleDescription.
  ///
  /// In en, this message translates to:
  /// **'Only liters per 100 {distanceUnit}'**
  String vehicleConsumptionEstimationModeSimpleDescription(String distanceUnit);

  /// No description provided for @vehicleConsumptionEstimationModeDetailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Detailed'**
  String get vehicleConsumptionEstimationModeDetailedTitle;

  /// No description provided for @vehicleConsumptionEstimationModeDetailedDescription.
  ///
  /// In en, this message translates to:
  /// **'Liters per 100 {distanceUnit} for driving on highway / in city / in traffic'**
  String vehicleConsumptionEstimationModeDetailedDescription(
    String distanceUnit,
  );

  /// No description provided for @vehicleDistanceUnitKilometres.
  ///
  /// In en, this message translates to:
  /// **'kilometres'**
  String get vehicleDistanceUnitKilometres;

  /// No description provided for @vehicleDistanceUnitMiles.
  ///
  /// In en, this message translates to:
  /// **'miles'**
  String get vehicleDistanceUnitMiles;

  /// No description provided for @vehicleConsumptionRequireDetailedForBorrowers.
  ///
  /// In en, this message translates to:
  /// **'Require borrowers to declare highway / city / traffic percentages'**
  String get vehicleConsumptionRequireDetailedForBorrowers;

  /// No description provided for @vehicleConsumptionSimpleEstimate.
  ///
  /// In en, this message translates to:
  /// **'Consumption: {value} L/100 km'**
  String vehicleConsumptionSimpleEstimate(String value);

  /// No description provided for @vehicleConsumptionInsufficientDetailedData.
  ///
  /// In en, this message translates to:
  /// **'Not enough data yet for a detailed estimate (highway / city / traffic). The simple estimate below is shown until more detailed sessions are recorded.'**
  String get vehicleConsumptionInsufficientDetailedData;

  /// No description provided for @vehicleConsumptionCarriedFromDetailedMode.
  ///
  /// In en, this message translates to:
  /// **'This estimate is carried over from your previous detailed mode. It will refine as you record more full-tank periods in simple mode.'**
  String get vehicleConsumptionCarriedFromDetailedMode;

  /// No description provided for @vehicleStatisticsConsumptionHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Reliable consumption history'**
  String get vehicleStatisticsConsumptionHistoryTitle;

  /// No description provided for @vehicleConsumptionHistoryBlended.
  ///
  /// In en, this message translates to:
  /// **'{date}: {value} L/100 km'**
  String vehicleConsumptionHistoryBlended(String date, String value);

  /// No description provided for @vehicleSessionEndTankConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm tank level'**
  String get vehicleSessionEndTankConfirmTitle;

  /// No description provided for @vehicleSessionEndTankConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'You declared the tank at {percent}% full after {distance} since the last fuel purchase. Please confirm this is correct.'**
  String vehicleSessionEndTankConfirmBody(String distance, int percent);

  /// No description provided for @vehicleSessionEndTankConfirmReview.
  ///
  /// In en, this message translates to:
  /// **'Review entry'**
  String get vehicleSessionEndTankConfirmReview;

  /// No description provided for @vehicleSessionEndTankConfirmProceed.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get vehicleSessionEndTankConfirmProceed;

  /// No description provided for @vehicleStatisticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get vehicleStatisticsTitle;

  /// No description provided for @vehicleStatisticsMileageTitle.
  ///
  /// In en, this message translates to:
  /// **'My mileage'**
  String get vehicleStatisticsMileageTitle;

  /// No description provided for @vehicleStatisticsExpensesTitle.
  ///
  /// In en, this message translates to:
  /// **'My expenses'**
  String get vehicleStatisticsExpensesTitle;

  /// No description provided for @vehicleExpenseFuel.
  ///
  /// In en, this message translates to:
  /// **'Fuel'**
  String get vehicleExpenseFuel;

  /// No description provided for @vehicleExpenseMaintenance.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get vehicleExpenseMaintenance;

  /// No description provided for @vehicleExpenseViolations.
  ///
  /// In en, this message translates to:
  /// **'Violations'**
  String get vehicleExpenseViolations;

  /// No description provided for @vehicleFuelCost.
  ///
  /// In en, this message translates to:
  /// **'Total cost'**
  String get vehicleFuelCost;

  /// No description provided for @vehicleFuelVolume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get vehicleFuelVolume;

  /// No description provided for @vehicleFuelMeter.
  ///
  /// In en, this message translates to:
  /// **'Odometer'**
  String get vehicleFuelMeter;

  /// No description provided for @vehicleFuelFullTank.
  ///
  /// In en, this message translates to:
  /// **'Full tank'**
  String get vehicleFuelFullTank;

  /// No description provided for @vehicleFuelTankState.
  ///
  /// In en, this message translates to:
  /// **'Tank state'**
  String get vehicleFuelTankState;

  /// No description provided for @vehicleFuelApproximateLevel.
  ///
  /// In en, this message translates to:
  /// **'Approximately:'**
  String get vehicleFuelApproximateLevel;

  /// No description provided for @vehicleFieldFuelTankCapacity.
  ///
  /// In en, this message translates to:
  /// **'Fuel tank capacity'**
  String get vehicleFieldFuelTankCapacity;

  /// No description provided for @vehicleFieldFluidChangeFrequency.
  ///
  /// In en, this message translates to:
  /// **'Oil changes'**
  String get vehicleFieldFluidChangeFrequency;

  /// No description provided for @vehicleOilChangeIntervalRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter an oil change interval.'**
  String get vehicleOilChangeIntervalRequired;

  /// No description provided for @vehicleOilChangeIntervalInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid number.'**
  String get vehicleOilChangeIntervalInvalid;

  /// No description provided for @vehicleOilChangeIntervalLandMin.
  ///
  /// In en, this message translates to:
  /// **'Minimum: 1 (1,000 km or miles).'**
  String get vehicleOilChangeIntervalLandMin;

  /// No description provided for @vehicleOilChangeIntervalLandMax.
  ///
  /// In en, this message translates to:
  /// **'Maximum: 20 (20,000 km or miles).'**
  String get vehicleOilChangeIntervalLandMax;

  /// No description provided for @vehicleOilChangeIntervalBoatMin.
  ///
  /// In en, this message translates to:
  /// **'Minimum: 50 h.'**
  String get vehicleOilChangeIntervalBoatMin;

  /// No description provided for @vehicleOilChangeIntervalBoatMax.
  ///
  /// In en, this message translates to:
  /// **'Maximum: 500 h.'**
  String get vehicleOilChangeIntervalBoatMax;

  /// No description provided for @vehicleDetailEarlierPhotos.
  ///
  /// In en, this message translates to:
  /// **'Earlier photos'**
  String get vehicleDetailEarlierPhotos;

  /// No description provided for @vehicleFuelTankInTank.
  ///
  /// In en, this message translates to:
  /// **'{volume} in tank'**
  String vehicleFuelTankInTank(String volume);

  /// No description provided for @vehicleFuelTankInfoTooltip.
  ///
  /// In en, this message translates to:
  /// **'About fuel tank estimate'**
  String get vehicleFuelTankInfoTooltip;

  /// No description provided for @vehicleMaintenanceCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get vehicleMaintenanceCategory;

  /// No description provided for @vehicleMaintenanceCategoryOil.
  ///
  /// In en, this message translates to:
  /// **'Oil'**
  String get vehicleMaintenanceCategoryOil;

  /// No description provided for @vehicleMaintenanceCategoryOtherFluids.
  ///
  /// In en, this message translates to:
  /// **'Other fluids'**
  String get vehicleMaintenanceCategoryOtherFluids;

  /// No description provided for @vehicleMaintenanceCategoryTires.
  ///
  /// In en, this message translates to:
  /// **'Tires'**
  String get vehicleMaintenanceCategoryTires;

  /// No description provided for @vehicleMaintenanceCategoryBrakes.
  ///
  /// In en, this message translates to:
  /// **'Brakes'**
  String get vehicleMaintenanceCategoryBrakes;

  /// No description provided for @vehicleMaintenanceCategoryLights.
  ///
  /// In en, this message translates to:
  /// **'Lights'**
  String get vehicleMaintenanceCategoryLights;

  /// No description provided for @vehicleMaintenanceCategoryCleaning.
  ///
  /// In en, this message translates to:
  /// **'Cleaning'**
  String get vehicleMaintenanceCategoryCleaning;

  /// No description provided for @vehicleMaintenanceCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get vehicleMaintenanceCategoryOther;

  /// No description provided for @vehicleMaintenanceCost.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get vehicleMaintenanceCost;

  /// No description provided for @vehicleMaintenanceNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get vehicleMaintenanceNotes;

  /// No description provided for @vehicleViolationType.
  ///
  /// In en, this message translates to:
  /// **'Violation type'**
  String get vehicleViolationType;

  /// No description provided for @vehicleViolationAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get vehicleViolationAmount;

  /// No description provided for @vehicleMaintenanceAlertTile.
  ///
  /// In en, this message translates to:
  /// **'{category}: {remaining} remaining'**
  String vehicleMaintenanceAlertTile(String category, String remaining);

  /// No description provided for @vehicleGapAttributionTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlogged usage'**
  String get vehicleGapAttributionTitle;

  /// No description provided for @vehicleGapAttributionPrompt.
  ///
  /// In en, this message translates to:
  /// **'Who is the {gap} difference attributable to?'**
  String vehicleGapAttributionPrompt(String gap);

  /// No description provided for @vehicleGapAttributionUnknown.
  ///
  /// In en, this message translates to:
  /// **'I don\'t know'**
  String get vehicleGapAttributionUnknown;

  /// No description provided for @vehicleGapAttributionSelf.
  ///
  /// In en, this message translates to:
  /// **'Myself'**
  String get vehicleGapAttributionSelf;

  /// No description provided for @vehicleGapOwnerNotified.
  ///
  /// In en, this message translates to:
  /// **'The owner will be notified.'**
  String get vehicleGapOwnerNotified;

  /// No description provided for @vehiclePositiveGapConfirmPrompt.
  ///
  /// In en, this message translates to:
  /// **'This is a difference of {gap}. Are you sure?'**
  String vehiclePositiveGapConfirmPrompt(String gap);

  /// No description provided for @vehiclePositiveGapConfirmNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get vehiclePositiveGapConfirmNo;

  /// No description provided for @vehiclePositiveGapConfirmYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get vehiclePositiveGapConfirmYes;

  /// No description provided for @vehicleNegativeGapTitle.
  ///
  /// In en, this message translates to:
  /// **'Reading decreased'**
  String get vehicleNegativeGapTitle;

  /// No description provided for @vehicleNegativeGapBody.
  ///
  /// In en, this message translates to:
  /// **'The new reading is {gap} lower than the last stored reading.'**
  String vehicleNegativeGapBody(String gap);

  /// No description provided for @vehicleNegativeGapMaintain.
  ///
  /// In en, this message translates to:
  /// **'Maintain reading, investigate later'**
  String get vehicleNegativeGapMaintain;

  /// No description provided for @vehicleNegativeGapCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel entry'**
  String get vehicleNegativeGapCancel;

  /// No description provided for @vehicleSuspiciousGapTitle.
  ///
  /// In en, this message translates to:
  /// **'Unusually large difference'**
  String get vehicleSuspiciousGapTitle;

  /// No description provided for @vehicleSuspiciousGapBody.
  ///
  /// In en, this message translates to:
  /// **'The difference of {gap} exceeds what is plausible on one tank ({maxGap}). This reading may be incorrect.'**
  String vehicleSuspiciousGapBody(String gap, String maxGap);

  /// No description provided for @vehicleSuspiciousGapConfirm.
  ///
  /// In en, this message translates to:
  /// **'Use this reading anyway'**
  String get vehicleSuspiciousGapConfirm;

  /// No description provided for @vehicleSuspiciousGapCancel.
  ///
  /// In en, this message translates to:
  /// **'Review entry'**
  String get vehicleSuspiciousGapCancel;

  /// No description provided for @vehicleRoleOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get vehicleRoleOwner;

  /// No description provided for @vehicleRoleBorrower.
  ///
  /// In en, this message translates to:
  /// **'Borrower'**
  String get vehicleRoleBorrower;

  /// No description provided for @vehicleSharingAccessibleTitle.
  ///
  /// In en, this message translates to:
  /// **'Accessible vehicles'**
  String get vehicleSharingAccessibleTitle;

  /// No description provided for @vehicleSharingAccessibleEmpty.
  ///
  /// In en, this message translates to:
  /// **'No shared vehicles yet.'**
  String get vehicleSharingAccessibleEmpty;

  /// No description provided for @vehicleSharingPendingOffers.
  ///
  /// In en, this message translates to:
  /// **'Pending offers'**
  String get vehicleSharingPendingOffers;

  /// No description provided for @vehicleSharingAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get vehicleSharingAccept;

  /// No description provided for @vehicleSharingOffer.
  ///
  /// In en, this message translates to:
  /// **'Offer sharing'**
  String get vehicleSharingOffer;

  /// No description provided for @vehicleSharingOfferPickContact.
  ///
  /// In en, this message translates to:
  /// **'Select a connected contact'**
  String get vehicleSharingOfferPickContact;

  /// No description provided for @vehicleSharingNoContacts.
  ///
  /// In en, this message translates to:
  /// **'Add a connected contact first.'**
  String get vehicleSharingNoContacts;

  /// No description provided for @vehicleSharingOfferSent.
  ///
  /// In en, this message translates to:
  /// **'Offer sent.'**
  String get vehicleSharingOfferSent;

  /// No description provided for @vehicleSharingOfferBlocked.
  ///
  /// In en, this message translates to:
  /// **'Sharing requires vehicle and vehicle-sharing subscriptions.'**
  String get vehicleSharingOfferBlocked;

  /// No description provided for @vehicleSharingForwarded.
  ///
  /// In en, this message translates to:
  /// **'Recorded on the owner\'s vehicle.'**
  String get vehicleSharingForwarded;

  /// No description provided for @vehicleSharingBorrowerLabel.
  ///
  /// In en, this message translates to:
  /// **'Borrower: {name}'**
  String vehicleSharingBorrowerLabel(String name);

  /// No description provided for @vehicleSharingOwnerLabel.
  ///
  /// In en, this message translates to:
  /// **'Owner: {name}'**
  String vehicleSharingOwnerLabel(String name);

  /// No description provided for @vehicleUsageBlockedOwnOnBorrowerPath.
  ///
  /// In en, this message translates to:
  /// **'This vehicle is yours. Use the Vehicle module to record owner usage — not Vehicle sharing.'**
  String get vehicleUsageBlockedOwnOnBorrowerPath;

  /// No description provided for @vehicleUsageBlockedNotOwnedOnOwnerPath.
  ///
  /// In en, this message translates to:
  /// **'This vehicle is not in your owned list. Use Vehicle sharing for a vehicle shared with you.'**
  String get vehicleUsageBlockedNotOwnedOnOwnerPath;

  /// No description provided for @vehicleUsageBlockedMissingBorrowerIdentity.
  ///
  /// In en, this message translates to:
  /// **'Borrower identity is missing for this form.'**
  String get vehicleUsageBlockedMissingBorrowerIdentity;

  /// No description provided for @vehicleUsageBlockedVehicleNotFound.
  ///
  /// In en, this message translates to:
  /// **'Vehicle not found.'**
  String get vehicleUsageBlockedVehicleNotFound;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'Ok'**
  String get commonOk;

  /// No description provided for @sandboxRibbonLabel.
  ///
  /// In en, this message translates to:
  /// **'Simulation mode'**
  String get sandboxRibbonLabel;

  /// No description provided for @sandboxModeButton.
  ///
  /// In en, this message translates to:
  /// **'Simulation mode'**
  String get sandboxModeButton;

  /// No description provided for @sandboxEnterDialogBody.
  ///
  /// In en, this message translates to:
  /// **'You can simulate a plan with fake participants. This gives you an excellent preview of the app.\n\nTo use the “real” app, return to real mode. Tap the red banner at the top of the app to do so. You will be reminded after 8 hours.'**
  String get sandboxEnterDialogBody;

  /// No description provided for @sandboxEnterConfirm.
  ///
  /// In en, this message translates to:
  /// **'Simulate'**
  String get sandboxEnterConfirm;

  /// No description provided for @sandboxEnterRestartMessage.
  ///
  /// In en, this message translates to:
  /// **'The app will close now. Reopen it to continue.'**
  String get sandboxEnterRestartMessage;

  /// No description provided for @sandboxHomeWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Vehicle modules cannot be simulated.\n\nStart by exploring the Contacts module. Adding contacts is simplified for this simulation. You can rename these fake contacts.\n\n'**
  String get sandboxHomeWelcomeBody;

  /// No description provided for @sandboxExitDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave simulation mode?'**
  String get sandboxExitDialogTitle;

  /// No description provided for @sandboxRestartRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Fully quit the app, then reopen it to continue.'**
  String get sandboxRestartRequiredMessage;

  /// No description provided for @sandboxBotsExhausted.
  ///
  /// In en, this message translates to:
  /// **'You have invited all the bots.'**
  String get sandboxBotsExhausted;

  /// No description provided for @sandboxInvitingBot.
  ///
  /// In en, this message translates to:
  /// **'Inviting simulated participant…'**
  String get sandboxInvitingBot;

  /// No description provided for @sandboxBotExpenseTitle.
  ///
  /// In en, this message translates to:
  /// **'Simulate a bot expense'**
  String get sandboxBotExpenseTitle;

  /// No description provided for @sandboxBotExpenseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Simulation mode'**
  String get sandboxBotExpenseSubtitle;

  /// No description provided for @sandboxBotExpenseDescription.
  ///
  /// In en, this message translates to:
  /// **'Simulated expense'**
  String get sandboxBotExpenseDescription;

  /// No description provided for @sandboxEightHourNudgeTitle.
  ///
  /// In en, this message translates to:
  /// **'Simulation mode'**
  String get sandboxEightHourNudgeTitle;

  /// No description provided for @sandboxEightHourNudgeBody.
  ///
  /// In en, this message translates to:
  /// **'You have been in simulation mode for 8 hours. Consider returning to real mode so you do not miss a partner invitation.'**
  String get sandboxEightHourNudgeBody;

  /// No description provided for @sandboxPortabilityBlocked.
  ///
  /// In en, this message translates to:
  /// **'Export and import are unavailable in simulation mode.'**
  String get sandboxPortabilityBlocked;

  /// No description provided for @sandboxEnterFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not enter simulation mode (checkpoint verification failed).'**
  String get sandboxEnterFailed;

  /// No description provided for @sandboxModuleDisabled.
  ///
  /// In en, this message translates to:
  /// **'This module is not available in simulation mode.'**
  String get sandboxModuleDisabled;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
