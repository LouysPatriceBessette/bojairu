// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Bojairũ';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonFinishSetup => 'Finish setup';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonRestart => 'Restart';

  @override
  String get commonComingSoon => 'Coming soon';

  @override
  String get commonNotSet => 'Not set';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonSend => 'Send';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonYes => 'Yes';

  @override
  String get commonNo => 'No';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonDone => 'Done';

  @override
  String get commonCopy => 'Copy';

  @override
  String get commonPaste => 'Paste';

  @override
  String get commonBlock => 'Block';

  @override
  String get commonUnblock => 'Unblock';

  @override
  String get navHome => 'Home';

  @override
  String get navSettings => 'Settings';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguageTitle => 'Language';

  @override
  String get settingsLanguageSubtitle => 'Change the app language';

  @override
  String get languageSystem => 'System';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageFrench => 'French';

  @override
  String get languageSpanish => 'Spanish';

  @override
  String get settingsProfileTitle => 'Profile';

  @override
  String get settingsCurrencyTitle => 'Currency';

  @override
  String get settingsDateFormatTitle => 'Date format';

  @override
  String get settingsDistanceUnitTitle => 'Distance unit';

  @override
  String get settingsPrivacyPolicyTitle => 'Privacy policy';

  @override
  String get settingsPrivacyPolicySubtitle =>
      'How your personal information is handled';

  @override
  String get settingsAppVersionTitle => 'App version';

  @override
  String get settingsEnvironmentTitle => 'Environment';

  @override
  String get settingsApiBaseUrlTitle => 'API base URL';

  @override
  String get settingsNotificationsTitle => 'Notifications';

  @override
  String get settingsNotificationsSubtitle =>
      'Permissions, categories, and sound';

  @override
  String get settingsUnitsTitle => 'Units';

  @override
  String get settingsUnitsSubtitle => 'Various unit formats';

  @override
  String get settingsAboutTitle => 'About';

  @override
  String get settingsAboutSubtitle => 'Environment, API URL, and app version';

  @override
  String get settingsExportImportTitle => 'Export / import data';

  @override
  String get settingsExportImportSubtitle =>
      'Full-device security backup and restore';

  @override
  String get deviceDataExportSecurityWarning =>
      'The backup file is unencrypted JSON. Store it securely and do not share it over untrusted channels.';

  @override
  String get deviceDataExportAction => 'Export all data';

  @override
  String get deviceDataImportAction => 'Import backup';

  @override
  String get deviceDataExportCopiedToClipboard =>
      'Backup JSON copied to clipboard.';

  @override
  String get deviceDataExportLastSavedTitle => 'Saved file';

  @override
  String deviceDataExportSavedLocation(String fileName) {
    return 'Documents/Bojairũ/$fileName';
  }

  @override
  String deviceDataExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get deviceDataImportDisabledNoSubscription =>
      'Import requires an active paid housing subscription on this device.';

  @override
  String get deviceDataImportDisabledWeb =>
      'Import is not available on web (development only).';

  @override
  String get deviceDataReplaceConfirmTitle => 'Replace all local data?';

  @override
  String get deviceDataReplaceConfirmBody =>
      'This backup will replace every piece of operational data on this device. This is intended mainly for device replacement.';

  @override
  String get deviceDataImportSuccess =>
      'Backup restored. Relay sync is available again.';

  @override
  String deviceDataImportFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String deviceDataImportValidationFailed(String code) {
    return 'Invalid backup file ($code).';
  }

  @override
  String get deviceDataMigrationNetworkFailure =>
      'Local data was restored but the relay could not be reached. Check your connection and retry migration.';

  @override
  String deviceDataMigrationFailed(String code) {
    return 'Server identity update failed ($code).';
  }

  @override
  String get deviceDataMigrationPendingTitle => 'Server sync pending';

  @override
  String get deviceDataMigrationPendingBody =>
      'Your data is on this device but the server still needs to link your new installation identity.';

  @override
  String get deviceDataRetryMigrationAction => 'Retry server sync';

  @override
  String get deviceDataCanonicalRestoreTitle =>
      'Restore data for which participant?';

  @override
  String get settingsNotificationsGeneralSection => 'General permission';

  @override
  String get settingsNotificationsSystemPermissionTitle => 'System permission';

  @override
  String get settingsNotificationsSystemPermissionBody =>
      'The app will ask after a relevant action, such as inviting someone.';

  @override
  String get settingsNotificationsSystemPermissionChecking =>
      'Checking permission…';

  @override
  String get settingsNotificationsSystemPermissionUnsupported =>
      'Not supported on this platform';

  @override
  String get settingsNotificationsSystemPermissionUnknown =>
      'Not requested yet';

  @override
  String get settingsNotificationsSystemPermissionGranted =>
      'Allowed by the system';

  @override
  String get settingsNotificationsSystemPermissionDenied =>
      'Blocked by the system';

  @override
  String get settingsNotificationsSystemPermissionProvisional =>
      'Allowed quietly';

  @override
  String get settingsNotificationsRequestAction => 'Allow';

  @override
  String get settingsNotificationsGeneralSwitchTitle =>
      'Allow app notifications';

  @override
  String get settingsNotificationsGeneralSwitchBody =>
      'Master switch for notification categories in this app.';

  @override
  String get settingsNotificationsWakeFromSleepBody =>
      'When allowed, the app can register with the relay so a closed app may wake briefly to check for new contact or payment reminders—without showing message content in the push itself.';

  @override
  String get settingsNotificationsContactsSection => 'Contacts';

  @override
  String get settingsNotificationsContactAddRequest =>
      'Add requests/confirmations';

  @override
  String get settingsNotificationsContactDisconnection =>
      'Disconnection notices';

  @override
  String get settingsNotificationsContactInvitationExpiration =>
      'Unconsumed invitation expiration';

  @override
  String get settingsNotificationsCountryStatsSection => 'User statistics';

  @override
  String get settingsNotificationsCountryStatsSwitchTitle =>
      'Which country are you located in?';

  @override
  String get settingsNotificationsCountryStatsSwitchSubtitle =>
      'Allow sharing your country name. No other personal content will be used. The data is compiled into a per-country user total.';

  @override
  String get settingsNotificationsCountryStatsPickerLabel => 'Country';

  @override
  String get settingsNotificationsCountryStatsSearchHint => 'Search by name';

  @override
  String get settingsNotificationsCountryStatsEmpty => 'No matching country';

  @override
  String get settingsNotificationsHousingSection => 'Housing';

  @override
  String get settingsNotificationsHousingPlanSubmission =>
      'Plan submission received';

  @override
  String get settingsNotificationsHousingDecisionChange =>
      'Participant decision status changes';

  @override
  String get settingsNotificationsHousingOfferExpiration =>
      'Plan offer expiration without unanimous acceptance';

  @override
  String get settingsNotificationsSoundSection => 'Sound';

  @override
  String get settingsNotificationsSoundSwitchTitle => 'Play a sound';

  @override
  String get settingsNotificationsSoundSwitchBody =>
      'Show notifications silently when this is off.';

  @override
  String get settingsNotificationsSoundPickerTitle => 'Notification sound';

  @override
  String get settingsNotificationsSoundPickerBody =>
      'Device sound selection will be added later where platforms allow it safely.';

  @override
  String get settingsNotificationsEnableBlocked =>
      'System notification permission is not granted.';

  @override
  String get notificationFlowPermissionPromptTitle =>
      'Enable useful notifications?';

  @override
  String get notificationFlowPermissionPromptBody =>
      'The app can enable the notification permissions needed for what you are about to do.';

  @override
  String get notificationFlowPermissionEnableAction =>
      'Yes, enable them and continue';

  @override
  String get notificationFlowPermissionReviewAction => 'I want to check myself';

  @override
  String get notificationFlowPermissionNoAction => 'No, continue';

  @override
  String get onboardingTitle => 'Setup';

  @override
  String get onboardingLanguageTitle => 'Language';

  @override
  String get onboardingLanguageBody =>
      'Choose the app language. You can change it anytime in Settings.';

  @override
  String get onboardingWelcomeTitle => 'Welcome';

  @override
  String get onboardingWelcomeIntro =>
      'Bojairũ is an app developed to help roommates get along better.\n\nBy using this app, you will avoid misunderstandings, oversights, and calculation errors that often lead to conflict. To get the most out of it, enter data as it becomes known.';

  @override
  String get onboardingWelcomeConfidentialTitle => 'Confidential';

  @override
  String get onboardingWelcomeConfidentialBody =>
      'Finally, real privacy. You can enter your data without any worry. No one other than you and your roommates will have access. This is not just a promise—it is a demonstrable fact. All of the app’s code is public and can be inspected and audited.\n\nThis does imply an important trade-off: there is no way to recover your data if you lose it (loss, theft, or breakage of your device). The app includes an import/export feature that is strongly suggested to use periodically to keep a backup. You are free to put the exported file wherever you want. Securing that backup is your responsibility.';

  @override
  String get onboardingOk => 'OK';

  @override
  String get onboardingProfileTitle => 'Your profile';

  @override
  String get onboardingNameLabel => 'Name';

  @override
  String get onboardingNameHint => 'Your display name';

  @override
  String get onboardingAvatarTitle => 'Choose an avatar';

  @override
  String get onboardingPreferencesTitle => 'Preferences';

  @override
  String get prefsCurrencyLabel => 'Currency';

  @override
  String get prefsCurrencySearchHint => 'Search by code or name';

  @override
  String get prefsDateFormatLabel => 'Date format';

  @override
  String get prefsDistanceUnitLabel => 'Distance unit';

  @override
  String get prefsDistanceUnitKm => 'Kilometers (km)';

  @override
  String get prefsDistanceUnitMiles => 'Miles';

  @override
  String get prefsLiquidVolumeUnitLabel => 'Liquid volume unit';

  @override
  String get prefsLiquidVolumeUnitLiter => 'Liter';

  @override
  String get prefsLiquidVolumeUnitUsGallon => 'US gallon (3.785 L)';

  @override
  String get prefsLiquidVolumeUnitImperialGallon => 'Imperial gallon (4.546 L)';

  @override
  String get prefsWeekStartLabel => 'Week starts on';

  @override
  String get prefsWeekStartSunday => 'Sunday';

  @override
  String get prefsWeekStartMonday => 'Monday';

  @override
  String get prefsTimeZoneLabel => 'Time zone';

  @override
  String get prefsTimeZoneDevice => 'Use device local time';

  @override
  String get prefsTimeZoneSearchHint => 'Search time zones';

  @override
  String get errorSomethingWentWrongTitle => 'Something went wrong';

  @override
  String get errorSomethingWentWrongBody =>
      'Please take a screenshot now and send it with a short description of the steps that led to this error.';

  @override
  String get errorReportBugLink => 'Report this error';

  @override
  String get errorUnknownOnboardingStep => 'Unknown onboarding step.';

  @override
  String get homeHousingPlan => 'Housing plan';

  @override
  String get homeModuleContacts => 'Contacts';

  @override
  String get homeModuleHousing => 'Housing';

  @override
  String get homeModuleVehicle => 'Vehicle';

  @override
  String get homeModuleVehicleSharing => 'Vehicle sharing';

  @override
  String get housingPlanSummaryMonthlyTotal => 'Monthly total';

  @override
  String housingPlanLoadError(String error) {
    return 'Could not load plan data.\n$error';
  }

  @override
  String get housingPlanStepParticipants => 'Participants';

  @override
  String get housingPlanStepPlanDates => 'Plan dates';

  @override
  String get housingPlanStepExpenseCategories => 'Expense categories';

  @override
  String get housingPlanStepExpenses => 'Expenses';

  @override
  String get housingPlanStepSplit => 'Split';

  @override
  String get housingPlanStepAgreementRules => 'Agreement rules';

  @override
  String get housingAgreementRulesIntro =>
      'Turn rules on or off. Fixed rules stay listed even when off so everyone sees what was negotiated. You can add your own rules and remove them until a proposal has been accepted.';

  @override
  String get housingAgreementRulesAmendmentIntro =>
      'Turn optional rules on or off, edit them, add new ones, or remove them. Fixed rules (curfew, early withdrawal, building) stay listed even when off. New rules must be enabled to be included in the proposal.';

  @override
  String get housingAgreementRuleCurfewTitle => 'Quiet hours calendar';

  @override
  String get housingAgreementRuleCurfewPlaceholder =>
      'Indicative week (no dates): tap a day letter, then use the grid. In edit mode, tap a 30-minute cell to cycle no rule → absolute quiet (red) → moderate quiet (yellow).';

  @override
  String get housingQuietHoursAbsolute => 'Absolute quiet';

  @override
  String get housingQuietHoursModerate => 'Moderate quiet';

  @override
  String get housingQuietHoursNoneThisDay => 'No quiet hours';

  @override
  String get housingQuietHoursCopyDayTooltip => 'Copy this day to other days';

  @override
  String housingQuietHoursCopyDayDialogMessage(String sourceDay) {
    return 'Copy the schedule for $sourceDay to which other days?';
  }

  @override
  String get housingAgreementRuleEarlyWithdrawalTitle => 'Early withdrawal';

  @override
  String get housingAgreementRuleBuildingTitle => 'Building / household rules';

  @override
  String get housingAgreementRuleBuildingHint =>
      'Suggested topics you can copy or adapt:\nNon-smoking\nNo pets\nNothing stored in hallways\n…';

  @override
  String get housingAgreementRuleEdit => 'Edit';

  @override
  String get housingAgreementRuleFinishEditing => 'Done editing';

  @override
  String get housingAgreementRuleTitleRequired =>
      'Enter a title for this rule.';

  @override
  String get housingAgreementSuggestionLabel => 'Suggestion';

  @override
  String get housingAgreementSuggestionCleanlinessTitle =>
      'Common area cleanliness';

  @override
  String get housingAgreementSuggestionCleanlinessBody =>
      'Keep clothing in assigned storage only.\nClean the shower and toilet after each use.\nWipe kitchen counters after cooking.';

  @override
  String get housingAgreementSuggestionFridgeTitle => 'Fridge management';

  @override
  String get housingAgreementSuggestionFridgeBody =>
      'Label food you do not want to share.\nThrow away expired items regularly.\nKeep shelves and door clean.';

  @override
  String get housingAgreementRuleRemove => 'Remove rule';

  @override
  String get housingAgreementRuleDismissSuggestion => 'Remove from list';

  @override
  String get housingAgreementRuleAdd => 'Add rule';

  @override
  String get housingAgreementRuleAddTitle => 'Add agreement rule';

  @override
  String get housingAgreementRuleCustomTitleLabel => 'Title';

  @override
  String get housingAgreementRuleCustomBodyLabel => 'Details (optional)';

  @override
  String get housingAgreementRulesRemovalLockedHint =>
      'Rules that were part of an accepted proposal cannot be removed; you can still turn them off.';

  @override
  String get housingAgreementRuleEarlyWithdrawalDisabledHint =>
      'Turn this rule on to set minimum notice and penalty.';

  @override
  String housingPlanParticipantsCount(int count) {
    return '$count participants';
  }

  @override
  String get housingPlanFewerParticipantsTooltip => 'Fewer participants';

  @override
  String get housingPlanMoreParticipantsTooltip => 'More participants';

  @override
  String get housingPlanAddCategoryTooltip => 'Add expense category';

  @override
  String get housingPlanAddExpenseTooltip => 'Add expense';

  @override
  String get housingPlanBack => 'Back';

  @override
  String get housingPlanNext => 'Next';

  @override
  String get housingPlanFinish => 'Finish';

  @override
  String get housingPlanSplitValidationMessage =>
      'Each expense or category must total 100% across participants.';

  @override
  String housingPlanCouldNotContinue(String error) {
    return 'Could not continue: $error';
  }

  @override
  String get housingPlanInviteComingSoon => 'Invite participants (coming soon)';

  @override
  String get housingPlanPreviousPerson => 'Previous';

  @override
  String get housingPlanNextPerson => 'Next';

  @override
  String get housingPlanParticipantNameLabel => 'Name';

  @override
  String get housingPlanChooseContactAction => 'Choose contact';

  @override
  String get housingPlanChangeContactAction => 'Change contact';

  @override
  String get housingPlanRemoveParticipantHint =>
      'Drag and drop a contact here to remove it.';

  @override
  String get housingPlanContactRequired =>
      'Choose a contact for each participant before continuing.';

  @override
  String get housingPlanParticipantsMustBeConnected =>
      'Each co-participant must be a connected contact (they use the app on their own account). Invite them from Contacts first, then select them here.';

  @override
  String get housingPlanParticipantsPlaceholderNote =>
      'Co-participants must be connected contacts. The plan keeps a name and avatar snapshot for historical readability.';

  @override
  String get housingPlanYou => 'You';

  @override
  String housingPlanCoParticipantUnnamed(int index) {
    return 'Co-participant $index';
  }

  @override
  String get housingPlanPlanStart => 'Plan start';

  @override
  String get housingPlanPlanEnd => 'Plan end';

  @override
  String get housingPlanDurationLabel => 'Duration';

  @override
  String get housingPlanEndDateError =>
      'End date must be after start date (by at least one calendar day).';

  @override
  String get housingPlanCategoriesEmptyHint =>
      'Tap + to add a category. On the next step you can assign each expense to a category so related items stay together.';

  @override
  String get housingPlanDeleteCategoryTitle => 'Delete category';

  @override
  String get housingPlanDeleteCategoryBody =>
      'Expenses in this category will be unassigned from it. This does not delete the expenses.';

  @override
  String get housingPlanCancel => 'Cancel';

  @override
  String get housingPlanDelete => 'Delete';

  @override
  String get housingPlanTapToAddExpense => 'Tap + to add an expense.';

  @override
  String get housingPlanAddExpensesFirst => 'Add expenses first.';

  @override
  String get housingPlanAddAtLeastOneExpense => 'Add at least one expense!';

  @override
  String get housingPlanExpenseAmountsIncomplete =>
      'Each expense must have an amount greater than zero.';

  @override
  String get housingPlanExpenseRecurrenceIncomplete =>
      'Set recurrence for every recurring expense.';

  @override
  String get housingPlanExpenseSplitsIncomplete =>
      'Each expense split must total 100%.';

  @override
  String get housingPlanExpenseParticipantsMissing =>
      'Participants are missing; expenses cannot be validated.';

  @override
  String get housingPlanSplitNoCategory => 'No category';

  @override
  String get housingPlanWithdrawalIntro => 'Early withdrawal rules.';

  @override
  String get housingPlanWithdrawalSameForAll =>
      'Same rule for all participants';

  @override
  String get housingPlanMinimumNoticeDays => 'Minimum notice (days)';

  @override
  String get housingPlanPenaltyAmount => 'Penalty amount';

  @override
  String get housingPlanSummaryMissingAgreement => 'Missing agreement';

  @override
  String get housingPlanSummaryMissingParticipants =>
      'No participants found for this plan. Edit the plan to set them up again.';

  @override
  String get housingPlanSummaryEditPlan => 'Edit plan';

  @override
  String get housingPlanSummaryInvite => 'Submit my plan';

  @override
  String get housingWorkbenchTitle => 'Housing plans';

  @override
  String get housingWorkbenchDraftsSection => 'Draft(s)';

  @override
  String get housingWorkbenchPendingSection => 'Pending';

  @override
  String get housingWorkbenchArchivedSection => 'Archived';

  @override
  String get housingWorkbenchActiveSection => 'Active plans';

  @override
  String get housingWorkbenchSettlementSection => 'Settlement in progress';

  @override
  String housingWorkbenchSettlementOpenLabel(String planTitle) {
    return '$planTitle — settlement';
  }

  @override
  String get housingWorkbenchOpenPlan => 'Open';

  @override
  String get housingWorkbenchEmpty =>
      'No housing plans with your profile on this device.';

  @override
  String get housingActiveHubTitle => 'Active agreement';

  @override
  String housingActiveHubPeriod(String dateRange) {
    return '$dateRange';
  }

  @override
  String get housingActiveHubEnterExpense => 'Submit an expense';

  @override
  String get housingActiveHubEnterSettlementDue => 'Submit a due settlement';

  @override
  String housingActiveHubSettlementAvailableUntil(String date) {
    return 'Available until $date';
  }

  @override
  String get housingSettlementDueTitle => 'Due settlement';

  @override
  String get housingSettlementDueSubmit => 'Propose settlement transfer';

  @override
  String get housingSettlementDueSuccess => 'Settlement transfer proposed.';

  @override
  String get housingSettlementDueTransferDescription =>
      'End-of-agreement settlement';

  @override
  String get housingSettlementDueNoCounterparties =>
      'No outstanding balance with other participants.';

  @override
  String get housingActiveHubMonthlyExpenses => 'Accepted expenses';

  @override
  String get housingActiveHubBalances => 'Balances between participants';

  @override
  String get housingActiveHubPaymentStatus => 'Current expenses';

  @override
  String get housingActiveHubViewPlan => 'View plan';

  @override
  String get housingActiveHubRequestAmendment => 'Modify plan';

  @override
  String get housingActiveHubJournals => 'Journals';

  @override
  String get housingActiveHubExportImport => 'Security backup';

  @override
  String get housingExportSecurityWarning =>
      'The export file is unencrypted JSON. Store it securely and do not share it over untrusted channels.';

  @override
  String get housingExportAction => 'Export agreement data';

  @override
  String get housingExportCopiedToClipboard =>
      'Export JSON copied to clipboard.';

  @override
  String get housingExportLastSavedTitle => 'Saved file';

  @override
  String housingExportSavedLocation(String fileName) {
    return 'Internal storage/Documents/Bojairũ/$fileName';
  }

  @override
  String housingExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get housingImportNotAvailableTitle => 'Import';

  @override
  String get housingImportNotAvailableBody =>
      'Import requires a valid housing entitlement and will be enabled in a later release.';

  @override
  String get housingActiveHubPassPlaceholderTitle => 'Coming soon';

  @override
  String get housingActiveHubPassPlaceholderBody =>
      'This screen will be available in the next implementation pass.';

  @override
  String get housingRealizedExpenseTitle => 'Submit an expense';

  @override
  String get housingRealizedExpensePlanLine => 'Plan line';

  @override
  String get housingRealizedExpenseAmount => 'Amount';

  @override
  String get housingRealizedExpensePaymentDate => 'Payment date';

  @override
  String get housingRealizedExpenseTransferDate => 'Transfer date';

  @override
  String get housingRealizedExpensePaymentDatePick => 'Select a date';

  @override
  String get housingRealizedExpensePayer => 'Who paid';

  @override
  String get housingRealizedExpenseKind => 'Expense type';

  @override
  String get housingRealizedExpenseKindNormal => 'Payment';

  @override
  String get housingRealizedExpenseKindReimbursement => 'Reimbursement';

  @override
  String get housingRealizedExpenseKindAdvance => 'Advance';

  @override
  String get housingRealizedExpenseKindTransfer => 'Transfer';

  @override
  String get housingRealizedExpenseBeneficiary => 'Whose share is reimbursed';

  @override
  String get housingRealizedExpenseTransferRecipient =>
      'Participant who received the amount';

  @override
  String housingRealizedExpenseTransferRecipientSummary(String name) {
    return 'Amount given to $name';
  }

  @override
  String get housingRealizedExpenseTransferDescription =>
      'Description / comment (optional)';

  @override
  String get housingRealizedExpenseProofSection => 'Proof (optional)';

  @override
  String get housingRealizedExpenseProofEncourage =>
      'Adding a receipt or invoice helps your group validate this expense.';

  @override
  String get housingRealizedExpenseAddProof => 'Add proof';

  @override
  String get housingRealizedExpensePickCamera => 'Take a photo';

  @override
  String get housingRealizedExpenseCapturePhoto => 'Capture photo';

  @override
  String get housingRealizedExpenseCameraStartFailed =>
      'Could not access the camera on this device.';

  @override
  String get housingRealizedExpensePickGallery => 'Choose from gallery';

  @override
  String get housingRealizedExpensePickDocument => 'Choose a document';

  @override
  String housingRealizedExpenseStoragePath(String path) {
    return 'Saved at: $path';
  }

  @override
  String get housingRealizedExpenseSaveDraft => 'Save draft';

  @override
  String get housingRealizedExpenseSubmit => 'Submit to group';

  @override
  String get housingRealizedExpenseDraftSaved => 'Draft saved on this device';

  @override
  String get housingRealizedExpenseProposedSnackbar =>
      'Expense submitted for group review';

  @override
  String get housingRealizedExpenseValidationLine => 'Select a plan line';

  @override
  String get housingRealizedExpenseValidationAmount => 'Enter a valid amount';

  @override
  String get housingRealizedExpenseValidationPayer => 'Select who paid';

  @override
  String get housingRealizedExpenseValidationDate => 'Select a payment date';

  @override
  String get housingRealizedExpenseValidationBeneficiary =>
      'Select the participant who received the amount';

  @override
  String get housingRealizedExpenseNoPlanLines =>
      'This agreement has no expense lines yet. Add lines through a plan amendment.';

  @override
  String get housingRealizedExpenseLoadFailed =>
      'Could not load agreement data';

  @override
  String get housingRealizedExpenseCropTitle => 'Crop proof';

  @override
  String get housingRealizedExpenseCropConfirm => 'Use cropped image';

  @override
  String get housingRealizedExpenseCropFailed => 'Could not crop image';

  @override
  String get housingRealizedExpenseProofTapToSaveCopy => 'Tap to save a copy';

  @override
  String get housingRealizedExpenseProofSaveCopyFailed =>
      'Could not save a copy of the file';

  @override
  String get housingRealizedExpenseProofImagesOnly =>
      'Select an image file only (jpg, jpeg, png, webp, heic).';

  @override
  String get housingRealizedExpenseProofImageTooLarge =>
      'This image is too large to process in the web app. Choose a smaller image or send it another way.';

  @override
  String housingActiveHubReviewPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count expenses awaiting your review',
      one: '1 expense awaiting your review',
    );
    return '$_temp0';
  }

  @override
  String get housingRealizedExpenseReviewListTitle => 'Review expenses';

  @override
  String get housingRealizedExpenseReviewEmpty => 'No expenses to review.';

  @override
  String get housingRealizedExpenseReviewWaitingForYou =>
      'Awaiting your review';

  @override
  String get housingRealizedExpenseReviewWaitingForOthers =>
      'Awaiting other participants';

  @override
  String get housingRealizedExpenseReviewPublished => 'Published';

  @override
  String get housingRealizedExpenseReviewRejected => 'Rejected';

  @override
  String get housingRealizedExpenseReviewTitle => 'Expense review';

  @override
  String get housingRealizedExpenseReviewTypeLabel => 'Type';

  @override
  String get housingRealizedExpenseReviewMadeByLabel => 'Made by';

  @override
  String get housingRealizedExpenseReviewPlanLineLabel => 'Plan line';

  @override
  String get housingRealizedExpenseReviewDescriptionLabel =>
      'Description / comment';

  @override
  String housingRealizedExpenseTransferToYouBy(String name) {
    return 'Transferred to you by: $name';
  }

  @override
  String housingRealizedExpenseTransferToParticipant(String name) {
    return 'Transferred to: $name';
  }

  @override
  String get housingRealizedExpenseReviewDescriptionNone => 'None';

  @override
  String get housingRealizedExpenseReviewAcceptedWord => 'Accepted';

  @override
  String get housingRealizedExpenseReviewRejectedWord => 'Rejected';

  @override
  String get housingRealizedExpenseReviewDecisionsTitle => 'Decisions';

  @override
  String get housingRealizedExpenseReviewDecisionTableNameColumn => 'Name';

  @override
  String get housingRealizedExpenseReviewDecisionTableDateColumn => 'Date';

  @override
  String get housingRealizedExpenseReviewDecisionPendingShort => 'Pending';

  @override
  String get housingRealizedExpenseReviewDecisionUnknown => 'Unknown';

  @override
  String get housingRealizedExpenseReviewMotifLabel => 'Reason';

  @override
  String housingRealizedExpenseReviewDecisionPending(String name) {
    return '$name: pending';
  }

  @override
  String housingRealizedExpenseReviewDecisionAccepted(String name) {
    return '$name: accepted';
  }

  @override
  String housingRealizedExpenseReviewDecisionRejected(String name) {
    return '$name: rejected';
  }

  @override
  String housingRealizedExpenseReviewByName(String name) {
    return 'by $name';
  }

  @override
  String housingRealizedExpenseReviewAcceptedByOn(String name, String when) {
    return 'Accepted by $name on $when';
  }

  @override
  String housingRealizedExpenseReviewRejectedByOn(String name, String when) {
    return 'Rejected by $name on $when';
  }

  @override
  String get housingRealizedExpenseTransferReviewHint =>
      'Make sure you have received the transfer before accepting. There is no deadline.';

  @override
  String housingRealizedExpenseReviewPayer(String name) {
    return 'Paid by $name';
  }

  @override
  String get housingRealizedExpenseReviewRejections => 'Rejections';

  @override
  String get housingRealizedExpenseAccept => 'Accept';

  @override
  String get housingRealizedExpenseReject => 'Reject';

  @override
  String get housingRealizedExpenseRejectTitle => 'Reject expense';

  @override
  String get housingRealizedExpenseRejectJustification => 'Reason (required)';

  @override
  String get housingRealizedExpenseRejectConfirm => 'Reject';

  @override
  String get housingRealizedExpenseAccepted => 'Expense accepted';

  @override
  String get housingRealizedExpenseRejected => 'Expense rejected';

  @override
  String get housingRealizedExpenseResubmit => 'Correct and resubmit';

  @override
  String get housingMonthlyExpensesTitle => 'Accepted expenses';

  @override
  String housingMonthlyExpensesMonthLabel(int year, int month) {
    return '$year-$month';
  }

  @override
  String get housingMonthlyExpensesEmpty =>
      'No published expenses for this month.';

  @override
  String get housingRejectedExpensesTitle => 'Rejected expenses';

  @override
  String get housingRejectedExpensesEmpty =>
      'No rejected expenses for this month.';

  @override
  String get housingBalancesTitle => 'Balances between participants';

  @override
  String get housingBalancesEmpty =>
      'No balances yet. Published expenses will appear here.';

  @override
  String housingBalancesOwes(String from, String to, String amount) {
    return '$from owes $to $amount';
  }

  @override
  String get housingBalancesModeReal => 'Real';

  @override
  String get housingBalancesModeOptimized => 'Optimized';

  @override
  String get housingBalancesLegendTitle => 'Legend';

  @override
  String get housingBalancesOwesNobody => 'Owes nobody.';

  @override
  String housingBalancesOwesAmountTo(String amount, String to) {
    return '$amount to $to';
  }

  @override
  String get housingBalancesInactiveMarker => '(former participant)';

  @override
  String get housingExpensePaymentStatusTitle => 'Current expenses';

  @override
  String get housingExpensePaymentStatusEmpty => 'No plan expenses to display.';

  @override
  String housingExpensePaymentStatusDetailsTitle(String expenseName) {
    return 'Payments — $expenseName';
  }

  @override
  String get housingExpensePaymentStatusDetailsEmpty =>
      'No published payments for this expense this month.';

  @override
  String housingExpensePaymentStatusDetailsLine(
    String amount,
    String date,
    String payer,
  ) {
    return '$amount — $date — $payer';
  }

  @override
  String get housingRealizedExpenseBudgetCapTitle => 'Monthly budget exceeded';

  @override
  String housingRealizedExpenseBudgetCapBody(String cap) {
    return 'This amount exceeds the monthly cap ($cap) for this plan line. Submit anyway?';
  }

  @override
  String get housingRealizedExpenseBudgetCapConfirm => 'Submit anyway';

  @override
  String get housingRealizedExpensePaymentChartCarryTitle =>
      'Monthly amount exceeded';

  @override
  String housingRealizedExpensePaymentChartCarryBody(
    String monthlyTotal,
    String excess,
  ) {
    return 'This payment exceeds the monthly amount ($monthlyTotal) for this plan line by $excess. Should the excess be counted on the next month in the payment status chart?';
  }

  @override
  String get housingRealizedExpensePaymentChartCarryNextMonth =>
      'Carry to next month';

  @override
  String get housingRealizedExpensePaymentChartCarryCurrentMonth =>
      'Show on current month';

  @override
  String get housingActivePlanReadOnlyTitle => 'Plan detail';

  @override
  String get housingActivePlanDatesLabel => 'Plan dates';

  @override
  String get housingActivePlanReadOnlyExpenses => 'View expense lines';

  @override
  String get housingAmendmentRequestTitle => 'Modify plan';

  @override
  String get housingAmendmentRequestIntro =>
      'Choose one change per proposal. Your group must accept unanimously before it takes effect.';

  @override
  String get housingAmendmentPendingBlocks =>
      'A plan modification is already waiting for responses.';

  @override
  String get housingAmendmentPickLine => 'Choose a plan line';

  @override
  String get housingAmendmentTypeLineEdit => 'Edit an expense';

  @override
  String get housingAmendmentTypeLineEditHint =>
      'Title, amount, description, payer, recurrence, or split shares';

  @override
  String get housingAmendmentTypeLineAmount => 'Change a line amount';

  @override
  String get housingAmendmentTypeLineAmountHint =>
      'Update the price for one expense line';

  @override
  String get housingAmendmentTypeLineRecurrence => 'Change recurrence';

  @override
  String get housingAmendmentTypeLineRecurrenceHint =>
      'Update how often one line repeats';

  @override
  String get housingAmendmentTypeLinePayer => 'Change who pays';

  @override
  String get housingAmendmentTypeLinePayerHint =>
      'Update payment responsibility for one line';

  @override
  String get housingAmendmentTypeLineAdd => 'Add an expense';

  @override
  String get housingAmendmentTypeLineAddHint => 'Add a new expense to the plan';

  @override
  String get housingAmendmentTypeLineRemove => 'Remove an expense';

  @override
  String get housingAmendmentTypeLineRemoveHint =>
      'Retire one line (past expenses stay linked)';

  @override
  String get housingAmendmentLineRemoveConfirm =>
      'Remove this line from the plan? Existing realized expenses for this line are kept.';

  @override
  String get housingAmendmentLineRemoveConfirmAction => 'Remove line';

  @override
  String get housingAmendmentTypeAgreementEnd => 'Change end date';

  @override
  String get housingAmendmentTypeAgreementEndHint =>
      'Extend or shorten the agreement period';

  @override
  String housingAmendmentEndDateSet(String date) {
    return 'End date set to $date';
  }

  @override
  String get housingAmendmentTypeRuleChange => 'Change agreement rules';

  @override
  String get housingAmendmentTypeRuleChangeHint =>
      'Edit quiet hours, withdrawal, or other rules';

  @override
  String get housingAmendmentRosterChangeTitle => 'Major change';

  @override
  String get housingAmendmentRosterChangeHint =>
      'Adding or removing roommates requires a new agreement';

  @override
  String get housingAmendmentRosterChangeBody =>
      'Participant changes are not allowed as an in-force amendment. End this agreement or start a new term with a derived version of the current plan.';

  @override
  String get housingAgreementRenewalTitle => 'New agreement term';

  @override
  String get housingAgreementRenewalIntro =>
      'When your agreement period ends or your group changes, start a new unanimous proposal. You can derive it from the current plan to avoid retyping everything.';

  @override
  String get housingAgreementRenewalFork => 'Start new term from this plan';

  @override
  String get housingAgreementEndNow => 'End agreement today';

  @override
  String get housingAgreementEndConfirmTitle => 'End agreement?';

  @override
  String get housingAgreementEndConfirmBody =>
      'New realized expenses will be blocked after today. You can still review past expenses and start a new term later.';

  @override
  String get housingAgreementEndConfirmAction => 'End today';

  @override
  String get housingAgreementEndedSnackbar =>
      'Agreement period closed on this device';

  @override
  String get housingAgreementExpiredTitle => 'Agreement period ended';

  @override
  String get housingAgreementExpiredBody =>
      'You cannot enter new realized expenses for this period. Start a new agreement term to continue.';

  @override
  String get housingAmendmentDetailTitle => 'Requested change';

  @override
  String housingAmendmentDetailIntro(String proposer, String subject) {
    return '$proposer proposes to change $subject.';
  }

  @override
  String get housingAmendmentDetailCurrent => 'Currently';

  @override
  String get housingAmendmentDetailPrevious => 'Previously';

  @override
  String get housingAmendmentDetailAtRequestTime =>
      'At the time of the request';

  @override
  String get housingAmendmentDetailProposed => 'Proposed';

  @override
  String get housingAmendmentSubjectAgreementEnd => 'the agreement end date';

  @override
  String housingAmendmentSubjectLineEdit(String line) {
    return 'the expense “$line”';
  }

  @override
  String housingAmendmentSubjectLineAmount(String line) {
    return 'the amount for “$line”';
  }

  @override
  String housingAmendmentSubjectLineRecurrence(String line) {
    return 'the recurrence for “$line”';
  }

  @override
  String housingAmendmentSubjectLinePayer(String line) {
    return 'who pays for “$line”';
  }

  @override
  String get housingAmendmentSubjectLineAdd => 'the plan (new expense line)';

  @override
  String housingAmendmentSubjectLineRemove(String line) {
    return 'the plan (remove “$line”)';
  }

  @override
  String get housingAmendmentSubjectRuleChange => 'the agreement rules';

  @override
  String get housingAmendmentValueNotSet => 'Not set';

  @override
  String get housingAmendmentValueNone => 'None';

  @override
  String get housingAmendmentValueRemoved => 'Removed from plan';

  @override
  String get housingAmendmentUnknownLine => 'this line';

  @override
  String get housingAmendmentRulesCurrentPlaceholder =>
      'Current rules (summary coming soon)';

  @override
  String get housingAmendmentRulesProposedPlaceholder =>
      'Proposed rules (summary coming soon)';

  @override
  String get housingActiveHubPendingAmendment => 'There is a change request';

  @override
  String get housingAmendmentDetailLoading => 'Loading…';

  @override
  String get housingAmendmentAccept => 'Accept';

  @override
  String get housingAmendmentReject => 'Refuse';

  @override
  String get housingAmendmentSubmitToGroup => 'Submit to the group';

  @override
  String get housingAmendmentRulesContinue => 'Continue';

  @override
  String get housingAmendmentRulesModifiedWhileDisabledBody =>
      'You changed a rule without turning it on. Are you sure you did not forget something?';

  @override
  String get housingAmendmentRulesModifiedWhileDisabledReview =>
      'I want to check';

  @override
  String get housingAmendmentRulesModifiedWhileDisabledContinue =>
      'Continue anyway';

  @override
  String get housingAgreementRuleStatusEnabled => 'Enabled';

  @override
  String get housingAgreementRuleStatusDisabled => 'Disabled';

  @override
  String get housingAmendmentPreviewTitle => 'Request preview';

  @override
  String housingAmendmentPreviewIntro(String subject) {
    return 'Review the proposed change to $subject before sending it to the group.';
  }

  @override
  String get housingAmendmentNoMeaningfulChange =>
      'There is no change compared to the current plan.';

  @override
  String get housingAmendmentRequestStatusAction => 'Request status';

  @override
  String get housingAmendmentJournalTitle => 'Plan changes';

  @override
  String get housingJournalsTitle => 'Journals';

  @override
  String get housingAmendmentJournalSubtitle => 'Accepted and refused requests';

  @override
  String get housingAmendmentJournalSubjectAgreementEnd => 'Agreement end date';

  @override
  String housingAmendmentJournalLineAdd(String title, String amount) {
    return 'Expense added - $title - $amount';
  }

  @override
  String housingAmendmentJournalLineEdit(String title, String amount) {
    return 'Expense modified - $title - $amount';
  }

  @override
  String housingAmendmentJournalLineRemove(String title, String amount) {
    return 'Expense removed - $title - $amount';
  }

  @override
  String get housingAmendmentJournalEmpty => 'No plan changes yet.';

  @override
  String get housingAmendmentJournalAccepted => 'Accepted';

  @override
  String get housingAmendmentJournalRefused => 'Refused';

  @override
  String housingAmendmentJournalCardTitle(String subject, String status) {
    return '$subject — $status';
  }

  @override
  String housingAmendmentJournalCardSubtitle(String name, String date) {
    return 'By $name · $date';
  }

  @override
  String get housingAmendmentRulesSummaryShort => 'Agreement rules updated';

  @override
  String housingAmendmentRulesGroupAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added rules ($count)',
      one: 'Added rule ($count)',
    );
    return '$_temp0';
  }

  @override
  String housingAmendmentRulesGroupModified(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Modified rules ($count)',
      one: 'Modified rule ($count)',
    );
    return '$_temp0';
  }

  @override
  String housingAmendmentRulesGroupRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Removed rules ($count)',
      one: 'Removed rule ($count)',
    );
    return '$_temp0';
  }

  @override
  String housingAmendmentRulesGroupUnchanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Unchanged rules ($count)',
      one: 'Unchanged rule ($count)',
    );
    return '$_temp0';
  }

  @override
  String get housingAmendmentRulesBeforeSubtitle => 'Previously';

  @override
  String get housingAmendmentRulesProposedSubtitle => 'Proposed';

  @override
  String get housingAmendmentRulesUnchangedDetailHint =>
      'This rule is unchanged in the proposed revision.';

  @override
  String get housingAmendmentRejectTitle => 'Refuse change request';

  @override
  String get housingAmendmentRejectMessageLabel => 'Message (optional)';

  @override
  String get housingAmendmentRejectConfirm => 'Refuse';

  @override
  String get housingAmendmentRefusalMessageLabel => 'Refusal message';

  @override
  String get housingActiveHubViewPendingAmendment => 'Requested change';

  @override
  String get housingInviteResponseWindowTitle => 'Response window';

  @override
  String get housingInviteResponseWindowBody =>
      'Participants have until this date and time to respond (UTC).';

  @override
  String get housingInvitePeriodOverlapTitle => 'Agreement period conflict';

  @override
  String get housingInvitePeriodOverlapBody =>
      'This agreement overlaps by more than one calendar day with another housing plan where you are a participant. Change the dates or resolve the other plan before sending.';

  @override
  String housingInvitePeriodOverlapDetail(String planTitle, String dateRange) {
    return 'This agreement overlaps by more than one calendar day with “$planTitle” ($dateRange). Change the dates or resolve that plan before sending.';
  }

  @override
  String get housingPlanParticipantMustBeConnectedContact =>
      'Every co-participant must be a connected contact on this device before you can send the proposal.';

  @override
  String get housingInviteResponseDeadlineTitle => 'Response deadline:';

  @override
  String housingInviteResponseDeadlineInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'In $count days',
      one: 'In 1 day',
    );
    return '$_temp0';
  }

  @override
  String get housingInviteResponseDeadlineToday => 'Today';

  @override
  String deadlineRemainingInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'In $count days',
      one: 'In 1 day',
    );
    return '$_temp0';
  }

  @override
  String get deadlineRemainingToday => 'Today';

  @override
  String deadlineRemainingCountdown(String time) {
    return 'In $time';
  }

  @override
  String get deadlineRemainingExpired => 'Expired';

  @override
  String housingInviteResponseDeadlineCountdown(String time) {
    return 'In $time';
  }

  @override
  String get housingInviteOfferClosedHint =>
      'This offer is no longer open for responses.';

  @override
  String housingInviteForkedFromLabel(String revisionId) {
    return 'Derived from a previous proposal ($revisionId).';
  }

  @override
  String get housingArchiveExpiredTitle => 'Expired proposal';

  @override
  String get settingsActivityLogTitle => 'Event journal';

  @override
  String get settingsActivityLogSubtitle => 'Relay events on this device';

  @override
  String get activityLogEmpty => 'No events match your filters.';

  @override
  String get activityLogNoEntries => 'No log entries yet.';

  @override
  String get activityLogFiltersTitle => 'Filters';

  @override
  String get activityLogFilterDatesLabel => 'Dates';

  @override
  String get activityLogFilterInitiatorLabel => 'Initiator';

  @override
  String get activityLogFilterInitiatorAll => 'All';

  @override
  String get activityLogFilterInitiatorSelf => 'Me';

  @override
  String get activityLogFilterInitiatorContact => 'Contact';

  @override
  String get activityLogFilterEmitterLabel => 'Emitter';

  @override
  String get activityLogFilterEmitterAll => 'All';

  @override
  String get activityLogFilterEmitterSystem => 'System';

  @override
  String get activityLogFilterFromLabel => 'From (date)';

  @override
  String get activityLogFilterToLabel => 'To (date)';

  @override
  String get activityLogApplyFilters => 'Apply filters';

  @override
  String get activityLogKindContactHandshakeReceived =>
      'Contact connection request received';

  @override
  String get activityLogKindContactDisconnected => 'Contact disconnected';

  @override
  String get activityLogKindContactDeleted => 'Contact deleted';

  @override
  String get activityLogKindHousingProposalSent => 'Housing proposal sent';

  @override
  String get activityLogKindHousingProposalReceived =>
      'Housing proposal received';

  @override
  String get activityLogKindHousingProposalResponse =>
      'Housing proposal response';

  @override
  String get activityLogKindHousingProposalInvalidated =>
      'Housing proposal closed';

  @override
  String get activityLogKindHousingProposalExpired =>
      'Housing proposal expired';

  @override
  String get activityLogKindHousingProposalForkCreated =>
      'Derived housing proposal started';

  @override
  String get activityLogKindHousingAgreementActivated =>
      'Housing agreement activated';

  @override
  String get activityLogKindHousingProposalAgreementExpired =>
      'Plan amendment vote abandoned (agreement ended)';

  @override
  String get activityLogKindHousingParticipationChangeAgreementExpired =>
      'Ejection vote abandoned (agreement ended)';

  @override
  String get activityLogKindVehicleSharingOfferSent =>
      'Vehicle sharing offer sent';

  @override
  String get activityLogKindVehicleSharingOfferReceived =>
      'Vehicle sharing offer received';

  @override
  String get activityLogKindVehicleSharingOfferResponse =>
      'Vehicle sharing offer response';

  @override
  String get activityLogKindVehicleSharingOfferExpired =>
      'Vehicle sharing offer expired';

  @override
  String get housingInvitePlanActivating =>
      'All participants have accepted. Activating the agreement…';

  @override
  String get housingInviteProposalAppBarTitle => 'Invitation proposal';

  @override
  String get housingInviteProposalIntroTitle =>
      'Here is the proposal that will be sent to each of your participants.';

  @override
  String get housingInviteProposalSentIntroTitle =>
      'Here is the proposal sent to each of your participants.';

  @override
  String get housingInviteParticipantsSectionTitle => 'Participants';

  @override
  String get housingInviteExpensesSectionTitle => 'Expenses and split';

  @override
  String get housingInviteRulesSectionTitle => 'Agreement rules';

  @override
  String get housingInviteStatusAccepted => 'Accepted';

  @override
  String get housingInviteStatusPending => 'Pending';

  @override
  String get housingInviteStatusNegotiating => 'In negotiation';

  @override
  String get housingInviteStatusRejected => 'Rejected';

  @override
  String get housingInviteAcceptFull => 'I accept in full';

  @override
  String get housingInviteMissingContactsAction => 'Missing contacts';

  @override
  String housingInviteMissingContactsRedeemBanner(String name) {
    return 'To accept this plan, connect with $name first. Enter their invitation code below.';
  }

  @override
  String get housingInviteMissingContactsBlocked =>
      'Connect with every co-participant before you can accept.';

  @override
  String get housingPlanMissingContactsTitle => 'Plan contacts';

  @override
  String get housingPlanMissingContactsIntro =>
      'Each co-participant must be a connected contact on this device before you can accept the plan. Tap Establish contact for anyone you still need to reach.';

  @override
  String get housingPlanMissingContactsEmpty =>
      'This plan has no other participants on this device.';

  @override
  String get housingPlanMissingContactsAllReady =>
      'Every co-participant is connected. You can go back and accept the plan.';

  @override
  String get housingPlanMissingContactsEstablishContact => 'Establish contact';

  @override
  String get housingPlanMissingContactsPendingOutbound =>
      'Request sent — waiting for their response.';

  @override
  String housingPlanMissingContactsRefusedAt(String when) {
    return 'Refused $when';
  }

  @override
  String housingPlanMissingContactsInboundPrompt(String requester) {
    return '$requester wishes to establish contact with you for this housing plan.';
  }

  @override
  String get housingPlanMissingContactsAccept => 'Accept';

  @override
  String get housingPlanMissingContactsRefuse => 'Refuse';

  @override
  String get housingInviteNegotiate => 'I would like to negotiate';

  @override
  String get housingInviteRejectBlock => 'I reject outright';

  @override
  String get housingInviteNegotiateMessageLabel =>
      'Message to send with your negotiation request';

  @override
  String get housingInviteResponseSent => 'Response sent.';

  @override
  String get housingArchiveEntryTitle => 'Housing plans';

  @override
  String get housingArchiveEntryBody =>
      'Choose a proposal to review, edit a draft, or create a new plan.';

  @override
  String get housingArchiveNegotiatingTitle => 'Plan in negotiation';

  @override
  String housingArchivePendingTitle(int count) {
    return 'Plan waiting for $count response(s)';
  }

  @override
  String get housingArchiveRejectedTitle => 'Rejected plan';

  @override
  String get housingArchiveAmendmentRejectedTitle => 'Change request refused';

  @override
  String get housingArchiveDraftTitle => 'Plan draft';

  @override
  String housingArchiveDraftParticipantsTitle(int count) {
    return 'Plan with $count participants';
  }

  @override
  String get housingArchiveCreateDerivedAction => 'Create a derived version';

  @override
  String get housingArchiveEditDraftAction => 'Edit';

  @override
  String get housingArchiveViewAction => 'View';

  @override
  String get housingArchiveCreateNewPlan => 'Create a new plan';

  @override
  String get housingArchiveForkPromptTitle => 'Your response was sent.';

  @override
  String get housingArchiveForkPromptBody =>
      'Do you want to create a derived version of this proposal now to make your changes?';

  @override
  String get housingArchiveForkPromptLaterHint =>
      'You can do this later from the main menu.';

  @override
  String get housingArchiveForkLaterAction => 'Later';

  @override
  String get housingArchiveForkPromptCreateAction => 'Create';

  @override
  String get housingInviteProposalLockedHint =>
      'Another participant is negotiating or has rejected this proposal. Responses are paused until the plan is revised.';

  @override
  String get housingInviteInvitationStatusAction => 'Invitation status';

  @override
  String get housingInviteStatusDialogTitle => 'Invitation status';

  @override
  String housingInviteStatusSentAtLabel(String when) {
    return 'Sent: $when';
  }

  @override
  String housingInviteStatusDeadlineLabel(String when) {
    return 'Response deadline: $when';
  }

  @override
  String get housingInviteStatusDeadlineNotSet => 'Not set';

  @override
  String get housingInviteStatusTableSectionTitle => 'Invitees';

  @override
  String get housingInviteStatusTableInvitee => 'Invitee';

  @override
  String get housingInviteStatusTableStatus => 'Status';

  @override
  String get housingInviteStatusMessagesSectionTitle => 'Messages';

  @override
  String get housingInviteStatusNoPending =>
      'No pending invitation for this plan.';

  @override
  String housingInviteTransportSent(int sentCount) {
    return 'Proposal sent to $sentCount participant(s).';
  }

  @override
  String housingInviteTransportPartial(int sentCount, int failedCount) {
    return 'Proposal sent to $sentCount participant(s); $failedCount participant(s) could not be reached.';
  }

  @override
  String get housingInviteTransportFailed =>
      'The proposal could not be delivered to any participant. You can edit the plan and try again.';

  @override
  String get housingInviteResendProposalAction => 'Resend proposal';

  @override
  String get housingInviteViewSentProposalAction => 'View sent proposal';

  @override
  String get housingInviteReceivedWhileEditingSnack =>
      'You received a housing proposal from a participant.';

  @override
  String get housingInviteReceivedOpenAction => 'View';

  @override
  String get pushNotificationHousingProposalTitle => 'Housing proposal';

  @override
  String get pushNotificationHousingProposalBody =>
      'Open the app to review the proposal.';

  @override
  String get pushNotificationVehicleSharingOfferTitle =>
      'Vehicle sharing offer';

  @override
  String get pushNotificationVehicleSharingOfferBody =>
      'Open Vehicle sharing to review the offer.';

  @override
  String pushNotificationVehicleSharingOfferBodyFrom(
    String name,
    String vehicle,
  ) {
    return '$name offered to share $vehicle with you.';
  }

  @override
  String get pushNotificationVehicleSharingOfferAcceptTitle =>
      'Vehicle sharing accepted';

  @override
  String get pushNotificationVehicleSharingOfferAcceptBody =>
      'Open Vehicle sharing to see the active share.';

  @override
  String pushNotificationVehicleSharingOfferAcceptBodyFrom(
    String name,
    String vehicle,
  ) {
    return '$name accepted your offer to share $vehicle.';
  }

  @override
  String get vehicleSharingOfferRelayFailed =>
      'Offer saved here, but sending to the contact failed. Try again later.';

  @override
  String get vehicleSharingAcceptRelayFailed =>
      'Acceptance saved here, but sending to the owner failed. Try again later.';

  @override
  String get pushNotificationHousingAgreementActivatedTitle =>
      'Unanimous agreement';

  @override
  String get pushNotificationHousingAgreementActivatedBody =>
      'Your group has reached a unanimous housing agreement.';

  @override
  String get pushNotificationHousingRealizedExpenseTitle => 'Expense to review';

  @override
  String get pushNotificationHousingRealizedExpenseBody =>
      'A participant submitted an expense for your agreement.';

  @override
  String pushNotificationHousingRealizedExpenseBodyFrom(String name) {
    return '$name submitted an expense to review.';
  }

  @override
  String get pushNotificationHousingRealizedExpenseAcceptedTitle =>
      'Expense accepted';

  @override
  String get pushNotificationHousingRealizedExpenseAcceptedBody =>
      'A participant accepted your expense.';

  @override
  String pushNotificationHousingRealizedExpenseAcceptedBodyFrom(String name) {
    return '$name accepted your expense.';
  }

  @override
  String pushNotificationHousingRealizedExpenseAcceptedBodyFromPeer(
    String name,
    String payer,
  ) {
    return '$name accepted $payer\'s expense.';
  }

  @override
  String get pushNotificationHousingRealizedTransferAcceptedTitle =>
      'Transfer accepted';

  @override
  String get pushNotificationHousingRealizedTransferAcceptedBody =>
      'A participant accepted your transfer.';

  @override
  String pushNotificationHousingRealizedTransferAcceptedBodyFrom(String name) {
    return '$name accepted your transfer.';
  }

  @override
  String pushNotificationHousingRealizedTransferAcceptedBodyFromPeer(
    String name,
    String payer,
  ) {
    return '$name accepted $payer\'s transfer.';
  }

  @override
  String get pushNotificationHousingRealizedExpenseRejectedTitle =>
      'Expense rejected';

  @override
  String get pushNotificationHousingRealizedExpenseRejectedBody =>
      'A participant rejected your expense.';

  @override
  String pushNotificationHousingRealizedExpenseRejectedBodyFrom(String name) {
    return '$name rejected your expense.';
  }

  @override
  String get pushNotificationHousingDecisionTitle =>
      'Housing proposal response';

  @override
  String get pushNotificationHousingDecisionBody =>
      'A participant responded to a housing proposal.';

  @override
  String pushNotificationHousingDecisionBodyFrom(String name) {
    return '$name responded to a housing proposal.';
  }

  @override
  String get pushNotificationHousingAmendmentDecisionTitle =>
      'Agreement change response';

  @override
  String get pushNotificationHousingAmendmentDecisionBody =>
      'A participant responded to an agreement change request.';

  @override
  String pushNotificationHousingAmendmentDecisionBodyFrom(String name) {
    return '$name responded to an agreement change request.';
  }

  @override
  String get pushNotificationHousingPaymentReminderBeforeDueTitle =>
      'Payment reminder';

  @override
  String pushNotificationHousingPaymentReminderBeforeDueBody(String lineTitle) {
    return '$lineTitle is due soon.';
  }

  @override
  String get pushNotificationHousingPaymentReminderOverdueTitle =>
      'Payment overdue';

  @override
  String pushNotificationHousingPaymentReminderOverdueBody(String lineTitle) {
    return '$lineTitle was not completed for this period.';
  }

  @override
  String get pushNotificationContactInvitationBeforeExpiryTitle =>
      'Invitation expiring soon';

  @override
  String get pushNotificationContactInvitationBeforeExpiryBody =>
      'A pending invitation will expire soon.';

  @override
  String get pushNotificationContactInvitationExpiredTitle =>
      'Invitation expired';

  @override
  String get pushNotificationContactInvitationExpiredBody =>
      'An invitation was not used and has expired.';

  @override
  String get pushNotificationHousingProposalDeadlineTitle =>
      'Proposal deadline approaching';

  @override
  String get pushNotificationHousingProposalDeadlineBody =>
      'A housing plan offer expires soon. Open Housing to respond or check status.';

  @override
  String get notificationHousingPaymentRemindersLabel => 'Payment reminders';

  @override
  String housingOverdueJournalCardBody(String lineTitle) {
    return '$lineTitle was not completed for this period.';
  }

  @override
  String housingBeforeDueJournalCardBody(
    String dueDate,
    String lineTitle,
    String amount,
  ) {
    return 'Payment due reminder for $dueDate\n$lineTitle - $amount';
  }

  @override
  String housingDueDayJournalCardBody(String lineTitle, String amount) {
    return 'Reminder: due today\n$lineTitle - $amount';
  }

  @override
  String get pushNotificationHousingResponseFailureRelayUnavailableBody =>
      'The relay server is temporarily unavailable.';

  @override
  String get pushNotificationHousingResponseFailureUnknownBody =>
      'The proposal you are trying to respond to was not found. There are several possible reasons. Contact the person directly.';

  @override
  String get pushNotificationHousingResponseFailureSendBody =>
      'An error occurred while sending the response.';

  @override
  String get pushNotificationHousingResponseFailureLocalErrorBody =>
      'An unknown error occurred.';

  @override
  String get pushNotificationContactAddRequestTitle => 'Contact request';

  @override
  String pushNotificationContactAddRequestBody(String name) {
    return '$name wants to connect with you.';
  }

  @override
  String pushNotificationContactAddedViaInvitationBody(String name) {
    return '$name is now in your contacts.';
  }

  @override
  String get pushNotificationContactDuplicateModuleAnchorRejectedBody =>
      'The person you tried to connect with already has your contact on file, but you must restore your data before reconnecting.';

  @override
  String get contactsDuplicateDialogOk => 'OK';

  @override
  String get contactsDuplicateReadMore => 'Read more about this';

  @override
  String get contactsDuplicateAnchorHousingActive => 'an active housing plan';

  @override
  String get contactsDuplicateAnchorVehicleSharing => 'a vehicle sharing link';

  @override
  String get contactsDuplicateAnchorHousingAndVehicle =>
      'Text to be determined for the Housing AND Vehicle case';

  @override
  String contactsDuplicateInviterRejectedIntro(String anchor) {
    return 'The contact who just used an invitation code was already in your contacts. This is a duplicate. The existing contact is linked to $anchor.';
  }

  @override
  String get contactsDuplicateInviterNotAdded => 'The contact was NOT added.';

  @override
  String get contactsDuplicateInviterInformRestore =>
      'Tell them they must restore their data on their device to reconnect with you.';

  @override
  String get contactsDuplicateInviterMergedBody =>
      'The contact who just used an invitation code was already in your contacts. They were merged into the existing contact.';

  @override
  String contactsDuplicateInviteeRejectedIntro(String anchor) {
    return 'The person you tried to connect with already has your contact. You are linked to $anchor.';
  }

  @override
  String get contactsDuplicateInviteeMustRestore =>
      'You MUST restore your data. That is what you need to do to reconnect properly.';

  @override
  String get contactsDuplicateInviteeRejectedBannerBody =>
      'A reconnection cannot be established this way because you participate in a sharing plan.';

  @override
  String pushNotificationContactAddRequestAcceptedBody(String name) {
    return 'Your connection request with $name was accepted.';
  }

  @override
  String pushNotificationContactAddRequestRejectedBody(String name) {
    return 'Your connection request with $name was declined.';
  }

  @override
  String get pushNotificationContactAddRequestExpiredCodeBody =>
      'The connection code you used has expired.';

  @override
  String get pushNotificationContactAddRequestInvalidCodeBody =>
      'The connection code you used is not valid.';

  @override
  String get pushNotificationContactAddRequestRelayErrorBody =>
      'An error occurred on the relay server. Try again.';

  @override
  String get pushNotificationContactAddRequestRelayUnavailableBody =>
      'The relay server is temporarily unavailable.';

  @override
  String get pushNotificationContactAddRequestUnknownFailureBody =>
      'Your connection request failed.';

  @override
  String pushNotificationPlanPeerEstablishmentRequestBody(
    String requester,
    String proposer,
  ) {
    return '$requester wishes to establish contact with you, in the context of the housing plan proposal from $proposer.';
  }

  @override
  String get pushNotificationContactDisconnectionTitle =>
      'Contact disconnected';

  @override
  String pushNotificationContactDisconnectionBody(String name) {
    return '$name disconnected from you.';
  }

  @override
  String get housingInviteGenerateCodes => 'Generate invitation codes';

  @override
  String get housingInviteCodesDialogTitle => 'Invitation codes';

  @override
  String get housingInviteCodesDialogBody =>
      'Each code is for one co-participant. Share them however you prefer; registering codes with the relay server will be added later.';

  @override
  String get housingInviteCodesCopyAll => 'Copy all';

  @override
  String get housingInviteCodesCopied => 'Copied to clipboard';

  @override
  String get housingInviteRuleOffHint =>
      'This rule is turned off for this proposal.';

  @override
  String get housingInviteWithdrawalPerParticipantIntro =>
      'Notice and penalty differ by participant (see below).';

  @override
  String get housingInviteHousingAgreementTitle => 'Housing agreement';

  @override
  String get housingInviteDateRangeSeparator => ' to ';

  @override
  String get housingInviteSunburstCenterLabel => 'Overall';

  @override
  String housingInviteSunburstCenterParticipation(String pct) {
    return 'Overall participation $pct%';
  }

  @override
  String get housingInviteViewExpensesDetail => 'View expenses in detail';

  @override
  String get housingInviteExpensesDetailTitle => 'Expenses in detail';

  @override
  String get housingInviteExpensesDetailSwipeHint =>
      'Swipe left or right to browse each expense.';

  @override
  String housingInviteExpensesDetailPageIndicator(int current, int total) {
    return '$current of $total';
  }

  @override
  String get housingInviteExpensesDetailLoadError =>
      'Could not load this expense.';

  @override
  String get housingInviteExpensesDetailPrevious => 'Previous expense';

  @override
  String get housingInviteExpensesDetailNext => 'Next expense';

  @override
  String housingExpenseSunburstBudgetLabel(String name) {
    return '$name (budgeted max)';
  }

  @override
  String get housingInviteSunburstEmptyHint =>
      'No expense data to chart for this plan.';

  @override
  String housingInviteSunburstLegendAgreementShare(String name, String pct) {
    return '$name - $pct% of the agreement';
  }

  @override
  String get housingInviteSunburstMonthlyNormalizedFootnote =>
      'Amount monthlyized (30-day equivalent).';

  @override
  String housingInviteSunburstLegendYouParticipation(
    String participantName,
    String userAmount,
    String totalAmount,
    String pct,
  ) {
    return '$participantName\'s share: $userAmount/$totalAmount ($pct%)';
  }

  @override
  String get housingPlanSummaryDestroy => 'Destroy plan';

  @override
  String get housingPlanDestroyTitle => 'Destroy plan';

  @override
  String get housingPlanDestroyBody =>
      'This removes this housing plan, expenses, ratios, agreement, and draft participants from this device.';

  @override
  String get housingPlanDestroyConfirm => 'Destroy';

  @override
  String get housingPlanRemovedSnackbar => 'Plan removed';

  @override
  String get housingPlanAddCategoryTitle => 'Add category';

  @override
  String get housingPlanEditCategoryTitle => 'Edit category';

  @override
  String get housingPlanCategoryNameLabel => 'Category name';

  @override
  String get housingPlanCategoryDescriptionLabel =>
      'What belongs here (optional)';

  @override
  String get housingPlanSave => 'Save';

  @override
  String get housingPlanAddExpenseTitle => 'Add expense';

  @override
  String get housingPlanEditExpenseTitle => 'Edit expense';

  @override
  String get housingPlanRecurringSwitch => 'Recurring';

  @override
  String get housingPlanApproximateAmountSwitch => 'Approximate amount';

  @override
  String get housingPlanExpenseTitleLabel => 'Title';

  @override
  String get housingPlanCategoryOptionalLabel => 'Category (optional)';

  @override
  String get housingPlanCategoryNone => 'None';

  @override
  String get housingPlanExpenseDescriptionLabel => 'Description (optional)';

  @override
  String get housingPlanDayOfMonthLabel => 'Day of month';

  @override
  String get housingPlanMinLabel => 'Min';

  @override
  String get housingPlanMaxLabel => 'Max';

  @override
  String get housingPlanAmountLabel => 'Amount';

  @override
  String get housingExpenseNameLabel => 'Name';

  @override
  String get housingExpenseAmountTypeLabel => 'Amount type';

  @override
  String get housingExpenseAmountDetermined => 'Determined';

  @override
  String get housingExpenseAmountBudgetMax => 'Budgeted (max)';

  @override
  String get housingExpensePaymentResponsibleLabel => 'Payment responsible';

  @override
  String get housingExpensePaymentResponsibleAll => 'All';

  @override
  String get housingExpenseSplitSectionTitle => 'Split';

  @override
  String get housingExpenseEqualParts => 'Equal parts';

  @override
  String get housingExpenseLikeLabel => 'Like';

  @override
  String get housingExpenseLikeBlankHint => '—';

  @override
  String get housingExpenseSplitAmountColumn => 'Amount';

  @override
  String get housingExpenseSplitParticipantColumn => 'Participant';

  @override
  String get housingExpenseSplitPercentColumn => 'Share';

  @override
  String get housingExpenseSplitCorrectRow => 'Correct!';

  @override
  String get housingExpenseRecurrenceTapToSet => 'Set payment recurrence';

  @override
  String get housingExpenseRecurrenceSet => 'Recurrence configured';

  @override
  String get housingExpenseRecurrenceConfirmTitle => 'Confirm recurrence';

  @override
  String housingExpenseRecurrenceMonthlyDay(int day, String anchor) {
    return 'On day $day of each month, from $anchor';
  }

  @override
  String get housingExpenseRecurrenceUseRange => 'Use';

  @override
  String housingExpenseRecurrenceEveryNDays(int days, String anchor) {
    return 'Every $days days, starting $anchor';
  }

  @override
  String housingExpenseRecurrenceNthWeekdayOfMonth(
    String ordinal,
    String weekday,
    String anchor,
  ) {
    return '$ordinal $weekday of the month, from $anchor';
  }

  @override
  String get housingRecurrenceOrdinalFirst => 'First';

  @override
  String get housingRecurrenceOrdinalSecond => 'Second';

  @override
  String get housingRecurrenceOrdinalThird => 'Third';

  @override
  String get housingRecurrenceOrdinalFourth => 'Fourth';

  @override
  String get housingRecurrenceOrdinalFifth => 'Fifth';

  @override
  String get housingRecurrenceWeekdayMonday => 'Monday';

  @override
  String get housingRecurrenceWeekdayTuesday => 'Tuesday';

  @override
  String get housingRecurrenceWeekdayWednesday => 'Wednesday';

  @override
  String get housingRecurrenceWeekdayThursday => 'Thursday';

  @override
  String get housingRecurrenceWeekdayFriday => 'Friday';

  @override
  String get housingRecurrenceWeekdaySaturday => 'Saturday';

  @override
  String get housingRecurrenceWeekdaySunday => 'Sunday';

  @override
  String get housingExpenseEnterAmountForSplit =>
      'Enter an amount for this expense';

  @override
  String housingPlanDurationMonthsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months',
      one: '1 month',
    );
    return '$_temp0';
  }

  @override
  String housingPlanDurationDaysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get carSharingPlanTitle => 'Car sharing plan';

  @override
  String get carSharingPlanFinish => 'Done';

  @override
  String carSharingOwnerPrompt(String name) {
    return '$name: specify whether this is your owned vehicle or a rental.';
  }

  @override
  String get carSharingStepVehicle => 'Vehicle';

  @override
  String get carSharingStepOwner => 'Owner';

  @override
  String get carSharingStepParticipants => 'Participants';

  @override
  String get carSharingStepInsurance => 'Insurance & registration';

  @override
  String get carSharingStepCurrentState => 'Current condition';

  @override
  String get carSharingStepMaintenance => 'Maintenance estimates';

  @override
  String get carSharingStepAvailability => 'Offered availability';

  @override
  String get carSharingStepFuel => 'Fuel management';

  @override
  String get carSharingStepClauses => 'Other clauses';

  @override
  String get carSharingFieldMake => 'Make';

  @override
  String get carSharingFieldModel => 'Model';

  @override
  String get carSharingFieldColor => 'Color';

  @override
  String get carSharingFieldYear => 'Year';

  @override
  String get carSharingOwnerIsOwner => 'Owner vehicle';

  @override
  String get carSharingOwnerIsRental => 'Rental vehicle';

  @override
  String get carSharingRentalSharePermission =>
      'Sharing right obtained from the lessor';

  @override
  String get carSharingRentalContractCopy =>
      'Will provide a copy of the lease when the agreement is accepted';

  @override
  String get carSharingInsuranceNotify =>
      'Will notify insurers when the agreement is accepted';

  @override
  String get carSharingInsuranceAssumeIncrease =>
      'Will assume any insurance premium increase (if not, and premiums rise, this agreement is subject to renegotiation)';

  @override
  String get carSharingInsuranceProvideDocs =>
      'Will provide copies of insurance and registration papers when the agreement is accepted';

  @override
  String get carSharingEstimatedValueLabel => 'Estimated value';

  @override
  String get carSharingPhotoFront => 'Front photo path (optional)';

  @override
  String get carSharingPhotoLeft => 'Left side photo path (optional)';

  @override
  String get carSharingPhotoRight => 'Right side photo path (optional)';

  @override
  String get carSharingPhotoRear => 'Rear photo path (optional)';

  @override
  String get carSharingPhotoSeatsFront => 'Front seats photo path (optional)';

  @override
  String get carSharingPhotoSeatsRear => 'Rear seats photo path (optional)';

  @override
  String get carSharingPhotoDashboard => 'Dashboard photo path (optional)';

  @override
  String get carSharingPhotoOdometer => 'Odometer photo path (optional)';

  @override
  String get carSharingMaintenanceIntro =>
      'Planned maintenance items count toward the “maintenance” category when sharing costs.';

  @override
  String get carSharingMaintenanceAdd => 'Add maintenance item';

  @override
  String get carSharingMaintenanceEditTitle => 'Edit maintenance item';

  @override
  String get carSharingMaintenanceEmpty => 'No maintenance items yet.';

  @override
  String get carSharingMaintenanceTitleLabel => 'Title';

  @override
  String get carSharingMaintenanceAmountLabel => 'Amount';

  @override
  String get carSharingAvailabilityIntro =>
      'Tap half-hour cells for the selected day: highlighted slots are when the vehicle is offered to co-sharers. Other times are assumed to stay with the owner.';

  @override
  String get carSharingAvailabilityAvailable => 'Offered to co-sharers';

  @override
  String get carSharingAvailabilityOwner => 'Owner use';

  @override
  String get carSharingFuelIntro =>
      'When using in-app fuel tracking, each purchase records: date/time, total cost, fuel volume, odometer reading, and whether it was a full tank. Full-tank entries anchor consumption between refills. Odometer readings also support distance per trip.';

  @override
  String get carSharingFuelUseAppTracking =>
      'Use in-app fuel and odometer tracking';

  @override
  String get carSharingFuelCustomHint =>
      'Describe a different arrangement (not tracked by the app)';

  @override
  String get carSharingClausesIntro =>
      'Add optional clauses and suggested topics. Housing-specific rules (curfew, early withdrawal, building rules) are omitted here.';

  @override
  String get contactsTitle => 'Contacts';

  @override
  String get contactsPickerTitle => 'Choose a contact';

  @override
  String get contactsPickerEmptyTitle => 'No selectable contacts yet';

  @override
  String get contactsPickerEmptyBody =>
      'Invite people and complete the connection in Contacts first. Only connected contacts can join this module.';

  @override
  String get contactsEmptyTitle => 'No contacts yet';

  @override
  String get contactsEmptyBody =>
      'Invite someone and connect through the relay. Connected contacts can be reused across modules.';

  @override
  String get contactsAddContactAction => 'Invite someone';

  @override
  String get contactsAddLocalOnlyAction => 'Add local contact';

  @override
  String get contactsAddLocalOnlyTitle => 'New contact';

  @override
  String get contactsEditTitle => 'Edit contact';

  @override
  String get contactsDetailTitle => 'Contact';

  @override
  String get contactsDetailMissing => 'This contact no longer exists.';

  @override
  String get contactsInviteAction => 'Invite a contact';

  @override
  String get contactsInviteTitle => 'Invite a contact';

  @override
  String get contactsInviteIntroTitle => 'Share a one-time code';

  @override
  String get contactsInviteIntroBody =>
      'Generate a single-use code and share it outside the app (SMS, email, in person). Anyone with the code can add themselves to your contacts while the code is valid.';

  @override
  String get contactsInviteValidityLabel => 'Code valid for';

  @override
  String get contactsInviteGenerateAction => 'Generate code';

  @override
  String get contactsInviteShareWarning =>
      'Share this code with one person only. It expires automatically and stops working after being used or revoked.';

  @override
  String get contactsInviteQrLabel =>
      'Scan this QR code from the other device, or use the text code below.';

  @override
  String get contactsInviteQrSemantics => 'Invitation QR code';

  @override
  String get contactsInviteShortCodeLabel => 'Code';

  @override
  String get contactsInviteCopyDeepLink => 'Copy link';

  @override
  String get contactsInviteCopyShareText => 'Copy invitation';

  @override
  String contactsInviteShareText(String link, String code) {
    return 'You\'re invited to connect on Bojairũ.\n\nOne-time code:\n$code\n\nTo use it: open the Bojairũ app, go to Contacts, tap the scan/enter-code icon at the top of the screen, then paste this code. From the device that has the app installed you can also open: $link';
  }

  @override
  String contactsInviteExpiresAt(String when) {
    return 'Expires $when';
  }

  @override
  String get contactsInviteDeadlineTitle => 'Code valid until:';

  @override
  String get contactsInvitationStubTitle => 'Invitation code';

  @override
  String get contactsInviteRevokeAction => 'Revoke';

  @override
  String get contactsInvitationsTitle => 'Sent invitations';

  @override
  String get contactsInvitationsEmpty => 'No invitations sent yet.';

  @override
  String contactsInvitationsItemTitle(String createdAt) {
    return 'Invitation · $createdAt';
  }

  @override
  String get contactsInvitationsStatusPending => 'Pending';

  @override
  String get contactsInvitationsStatusUsed => 'Used';

  @override
  String get contactsInvitationsStatusExpired => 'Expired';

  @override
  String get contactsInvitationsStatusRevoked => 'Revoked';

  @override
  String get contactsEnterInviteCodeTitle => 'Enter a code';

  @override
  String get contactsEnterInviteCodeIntro =>
      'Paste or type the code you received from a contact.';

  @override
  String get contactsEnterInviteCodeFieldLabel => 'Invitation code';

  @override
  String get contactsEnterInviteCodeScanQr => 'Scan QR code';

  @override
  String get contactsEnterInviteCodeScanQrHint =>
      'Point the camera at a Bojairũ invitation QR code.';

  @override
  String get contactsEnterInviteCodeSubmit => 'Connect';

  @override
  String get contactsEnterInviteCodeValid => 'Code format is valid';

  @override
  String contactsEnterInviteCodeInvitationId(String id) {
    return 'Invitation id: $id';
  }

  @override
  String get contactsHandshakeNotAvailableYet =>
      'The relay handshake is not available yet. The code is valid locally, but cannot be redeemed until the relay is live.';

  @override
  String get contactsHandshakeDispatching =>
      'Sending the request to the relay…';

  @override
  String get contactsHandshakeDispatched =>
      'Code accepted. Establishing the contact…';

  @override
  String get contactsHandshakeCompleted =>
      'Connected. The contact has been added to your list.';

  @override
  String get contactsHandshakeRejected =>
      'The other person declined the connection. You can ask them for a new invitation if needed.';

  @override
  String get contactsHandshakeFailed =>
      'The connection attempt failed. You can try again with a fresh invitation.';

  @override
  String get contactsHandshakeErrorRelayUnavailable =>
      'Unable to reach the relay. Check your network and try again.';

  @override
  String get contactsHandshakeErrorAlreadyCompleted =>
      'This code has already been used.';

  @override
  String get contactsHandshakeErrorNonceConsumed =>
      'This invitation has already been redeemed.';

  @override
  String get contactsHandshakeErrorExpired => 'This invitation has expired.';

  @override
  String get contactsHandshakeErrorUnknown =>
      'Something went wrong while contacting the relay.';

  @override
  String get contactsIncomingTitle => 'Connection requests';

  @override
  String get contactsIncomingEmpty => 'No pending connection requests.';

  @override
  String contactsIncomingBody(String name) {
    return '$name wants to connect.';
  }

  @override
  String get contactsIncomingAccept => 'Accept';

  @override
  String get contactsIncomingReject => 'Reject';

  @override
  String get contactsIncomingBannerOne => '1 new connection request';

  @override
  String contactsIncomingBannerMany(int count) {
    return '$count new connection requests';
  }

  @override
  String get contactsRefreshIncomingTooltip => 'Check for connection requests';

  @override
  String contactsRefreshIncomingFound(int count) {
    return '$count pending connection request(s).';
  }

  @override
  String get contactsRefreshIncomingNone =>
      'No pending connection requests found.';

  @override
  String contactsRefreshIncomingNoneWithActivePolls(int count) {
    return 'No pending connection requests found. Active relay poll(s): $count.';
  }

  @override
  String contactsRefreshIncomingDiagnostics(
    int activeCount,
    int totalCount,
    String latestState,
  ) {
    return 'No pending connection requests found. Active relay poll(s): $activeCount. Local handshake row(s): $totalCount. Latest state: $latestState.';
  }

  @override
  String get contactsCodeErrorEmpty => 'Enter a code to continue.';

  @override
  String get contactsCodeErrorTooShort => 'This code is too short.';

  @override
  String get contactsCodeErrorTooLong => 'This code is too long.';

  @override
  String get contactsCodeErrorInvalidCharacters =>
      'This code contains characters that are not allowed.';

  @override
  String get contactsCodeErrorBadChecksum =>
      'This code looks mistyped. Check the characters and try again.';

  @override
  String get contactsCodeErrorUnsupportedVersion =>
      'This code was created by a newer version of the app.';

  @override
  String get contactsKindLocalOnly => 'Local only';

  @override
  String get contactsKindDisconnected => 'Disconnected';

  @override
  String get contactsKindConnected => 'Connected';

  @override
  String get contactsKindBlocked => 'Blocked';

  @override
  String get contactsKindDeleted => 'Deleted';

  @override
  String get contactsFieldNameLabel => 'Name';

  @override
  String get contactsFieldNameHint => 'How this person appears in the app';

  @override
  String get contactsFieldAvatarReadOnlyFootnote =>
      'You may assign them a different name.\n\nNote: they will be notified in:\n    Settings >\n        Profile >\n            How others name you.';

  @override
  String get contactsFieldAvatarLabel => 'Avatar';

  @override
  String get contactsFieldNotesLabel => 'Notes';

  @override
  String get contactsFieldNotesHint => 'Personal reminder, not shared';

  @override
  String get contactsFieldNotesFootnote =>
      'Your personal notes. They will not be shared.';

  @override
  String get contactsDeleteTitle => 'Delete contact?';

  @override
  String get contactsDeleteBody =>
      'Existing housing or vehicle entries that reference this contact will keep the name and avatar stored at the time they were added. To work with this person again, create a new local contact, or send them a new invitation.';

  @override
  String get contactsDeletePreservesHistory =>
      'Existing entries that reference this contact keep their stored name and avatar.';

  @override
  String get contactsDeleteBlockedByPlansTitle =>
      'Can\'t delete this contact yet';

  @override
  String contactsDeleteBlockedByPlansBody(int count, String plans) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count plans',
      one: 'one plan',
    );
    return 'This contact is still listed as a participant in $_temp0: $plans. Remove them from those plans first, then you\'ll be able to delete the contact.';
  }

  @override
  String get contactsDeleteBlockedConnectedTitle => 'Use Disconnect first';

  @override
  String get contactsDeleteBlockedConnectedBody =>
      'This contact is currently connected. Just deleting it on this device would leave the other side thinking the connection is still up. Use Disconnect first: it sends an encrypted disconnect signal to the peer through the relay and downgrades the contact to local-only on this device. You can then delete the contact normally.';

  @override
  String get contactsDeleteBlockedConnectedAction => 'Disconnect first';

  @override
  String get contactsBlockTitle => 'Block this contact?';

  @override
  String get contactsBlockBody =>
      'Incoming messages from this contact will be ignored locally. The relay is not informed of the block.';

  @override
  String get contactsUnblockTitle => 'Unblock this contact?';

  @override
  String get contactsUnblockBody =>
      'Incoming messages from this contact will be processed again.';

  @override
  String get contactsDisconnectAction => 'Disconnect';

  @override
  String get contactsDisconnectTitle => 'Disconnect from this contact?';

  @override
  String get contactsDisconnectBody =>
      'A disconnect notice will be sent to the relay. Both sides will fall back to local-only contacts.';

  @override
  String get contactsDisconnectSent =>
      'Disconnect notice sent. Contact is now local-only.';

  @override
  String get contactsReconnectAction => 'Request reconnection';

  @override
  String get contactsLabelEditorTitle => 'Rename locally';

  @override
  String get contactsLabelEditorScreenTitle => 'Rename locally?';

  @override
  String get contactsLabelEditorHint =>
      'Leave blank to keep their original name';

  @override
  String get contactsFieldTheirNameLabel => 'Their name';

  @override
  String get settingsProfileIdentityTitle => 'Your profile';

  @override
  String get settingsProfileIdentitySubtitle =>
      'Name and avatar shown to your contacts';

  @override
  String get settingsProfileAppearancesTitle => 'How others label you';

  @override
  String get settingsProfileAppearancesBody =>
      'Each connected contact can share the name they use for you in their list. It is delivered only inside encrypted profile updates.';

  @override
  String get settingsProfileAppearancesColumnPeer => 'Contact';

  @override
  String get settingsProfileAppearancesColumnTheirLabel =>
      'Their label for you';

  @override
  String get settingsProfileAppearancesEmpty =>
      'No connected contacts yet. Pair with someone to see how they label you here.';

  @override
  String get settingsProfileAppearancesNoSharedLabels =>
      'No contact has shared a custom name for you in their list yet.';

  @override
  String settingsProfileRenameBlockedBody(String plans) {
    return 'You are part of an open housing vote on this device: $plans. Finish or resolve that vote before changing your display name.';
  }

  @override
  String get peerNameConflictTitle => 'Contact updated their name';

  @override
  String peerNameConflictBody(String label, String canonical) {
    return 'You label this contact \"$label\". They now use \"$canonical\" on their device.';
  }

  @override
  String get peerNameConflictUseTheirs => 'Use their name';

  @override
  String get peerNameConflictKeepMine => 'Keep my label';

  @override
  String get housingPastHubTitle => 'Past agreement';

  @override
  String get housingParticipationChangeIntroLine1 =>
      'A participant change is not a simple in-force amendment.';

  @override
  String get housingParticipationChangeIntroLine2 =>
      'All options end the current plan for those who leave.';

  @override
  String get housingParticipationChangeWithdrawalAction =>
      'I want to withdraw from the agreement';

  @override
  String get housingParticipationChangeEjectionAction =>
      'I want to eject a participant';

  @override
  String get housingParticipationChangeInviteParticipantAction =>
      'I want to invite a participant';

  @override
  String get housingParticipationChangeInviteParticipantTitle =>
      'Inviting a participant';

  @override
  String get housingParticipationChangeInviteParticipantBody =>
      'Adding someone to an active agreement requires ending the current plan and starting a new one with everyone’s consent. Read why in the FAQ.';

  @override
  String get housingParticipationChangeInviteParticipantFaqLink =>
      'Read the FAQ';

  @override
  String get helpFaqTitle => 'Frequently asked questions';

  @override
  String get helpFaqIntro =>
      'Answers to common questions about how Bojairũ works';

  @override
  String get housingVoteRefusedByAgreementExpiration =>
      'Refused — agreement expired';

  @override
  String get contactsDisconnectBlockedByPlansTitle =>
      'Can\'t disconnect this contact yet';

  @override
  String contactsDisconnectBlockedByPlansBody(String plans) {
    return 'This contact is part of an active housing agreement or an open vote on this device: $plans. Finish or resolve that plan activity before disconnecting.';
  }

  @override
  String get housingParticipationChangeConfirmAction => 'Yes';

  @override
  String get housingParticipationChangeWithdrawalConfirmTitle =>
      'Confirm your withdrawal?';

  @override
  String housingParticipationChangeWithdrawalConfirmBody(String date) {
    return 'Planned departure date: $date. Other participants must acknowledge your notice within five calendar days. Your departure takes effect on that date once everyone has acknowledged.';
  }

  @override
  String housingParticipationChangeWithdrawalPenaltyHint(String amount) {
    return 'An early withdrawal penalty of $amount applies.';
  }

  @override
  String get housingEarlyWithdrawalPenaltyDescription =>
      'Early departure penalty';

  @override
  String housingEarlyWithdrawalPenaltyOwedTo(String name) {
    return 'This amount is owed to $name.';
  }

  @override
  String get housingParticipationChangeEjectionConfirmTitle =>
      'Eject a participant?';

  @override
  String get housingParticipationChangeEjectionConfirmBody =>
      'Other participants must accept. The candidate is removed if accepted unanimously.';

  @override
  String get housingParticipationChangeDetailTitle => 'Major change';

  @override
  String housingParticipationChangeDetailWithdrawalBody(
    String name,
    String date,
  ) {
    return '$name will leave the agreement on $date.';
  }

  @override
  String housingParticipationChangeDetailEjectionBody(
    String initiator,
    String target,
  ) {
    return '$initiator requests to eject $target.';
  }

  @override
  String get housingParticipationChangeAccept => 'Accept';

  @override
  String get housingParticipationChangeReject => 'Reject';

  @override
  String get housingParticipationChangeAcknowledge => 'Acknowledge';

  @override
  String get housingParticipationChangeAcknowledgementStatusTitle =>
      'Acknowledgements';

  @override
  String housingParticipationChangeWithdrawalPeerNotice(
    String departureDate,
    String ackDeadline,
  ) {
    return 'Enter any useful expenses before $departureDate. You may acknowledge this notice until $ackDeadline.';
  }

  @override
  String get housingParticipationChangeEjectionCandidateNotice =>
      'You are the participant named in this ejection request. The remaining participants must vote; you cannot accept or reject here.';

  @override
  String get housingParticipationChangeDecisionStatusTitle => 'Votes';

  @override
  String housingParticipationChangeDecisionPending(String name) {
    return '$name: pending';
  }

  @override
  String housingParticipationChangeDecisionAccepted(String name) {
    return '$name: accepted';
  }

  @override
  String housingParticipationChangeDecisionRejected(String name) {
    return '$name: rejected';
  }

  @override
  String get housingParticipationChangePenaltyApplies =>
      'An early withdrawal penalty will apply.';

  @override
  String get housingParticipationChangePenaltyDoesNotApply =>
      'No early withdrawal penalty will apply.';

  @override
  String housingParticipationChangeBannerWithdrawal(String name) {
    return '$name is leaving the agreement';
  }

  @override
  String housingParticipationChangeBannerEjection(
    String initiator,
    String target,
  ) {
    return '$initiator requests to eject $target.';
  }

  @override
  String get housingParticipationChangeEjectionHubSubtitle =>
      'Ejection request in progress...';

  @override
  String get pushNotificationHousingParticipationChangeTitle => 'Major change';

  @override
  String get pushNotificationHousingParticipationChangeBody =>
      'A co-participant requested a major change.';

  @override
  String pushNotificationHousingParticipationChangeBodyFrom(String name) {
    return '$name requested a major change.';
  }

  @override
  String get housingParticipationJournalSubjectWithdrawal =>
      'Voluntary withdrawal';

  @override
  String get housingParticipationJournalSubjectEjection =>
      'Participant ejection';

  @override
  String get housingParticipationJournalProposed => 'Proposed';

  @override
  String get housingParticipationJournalDecisionAccepted => 'Accepted';

  @override
  String get housingParticipationJournalDecisionRejected => 'Rejected';

  @override
  String get housingParticipationJournalEffective => 'Effective';

  @override
  String get housingParticipationJournalAborted => 'Aborted';

  @override
  String housingParticipationJournalSubjectLine(String kind, String event) {
    return '$kind — $event';
  }

  @override
  String get housingInactiveSettlementTitle =>
      'Settle with inactive participant';

  @override
  String get housingInactiveSettlementTileSubtitle =>
      'Record a transfer to close the balance';

  @override
  String housingInactiveSettlementParticipantLabel(String name) {
    return 'Former participant: $name';
  }

  @override
  String housingInactiveSettlementCurrentBalance(String amount) {
    return 'Current balance: $amount';
  }

  @override
  String get housingInactiveSettlementAmountLabel => 'Transfer amount';

  @override
  String get housingInactiveSettlementAmountHint =>
      'Positive: you pay them. Negative: they pay you.';

  @override
  String get housingInactiveSettlementSubmit => 'Publish settlement transfer';

  @override
  String get housingInactiveSettlementSuccess =>
      'Settlement transfer recorded.';

  @override
  String get housingInactiveSettlementTransferDescription =>
      'Settlement with former participant';

  @override
  String get housingInactiveSettlementErrorZero => 'Enter a non-zero amount.';

  @override
  String get housingInactiveSettlementErrorCannotCreateCredit =>
      'This transfer would create a new balance in their favor.';

  @override
  String get housingInactiveSettlementErrorExceedsDebt =>
      'Amount exceeds what they owe.';

  @override
  String get housingInactiveSettlementErrorCannotIncreaseDebt =>
      'This transfer would increase what they owe.';

  @override
  String get housingInactiveSettlementErrorExceedsCredit =>
      'Amount exceeds what is owed to them.';

  @override
  String get vehicleLicensingRequired =>
      'Vehicle module requires an active subscription.';

  @override
  String get vehicleSharingLicensingRequired =>
      'Vehicle sharing requires an active subscription.';

  @override
  String get vehicleQuickActionsTitle => 'Quick actions';

  @override
  String get vehicleMyVehiclesTitle => 'My vehicles';

  @override
  String get vehicleMyVehiclesEmpty => 'No vehicles yet. Tap + to add one.';

  @override
  String get vehicleOwnedActiveLimitReached =>
      'Limit reached: at most 3 active vehicles.';

  @override
  String vehicleDeactivatedLabel(String date) {
    return 'Deactivated $date';
  }

  @override
  String get vehicleDeactivateAction => 'Deactivate this vehicle';

  @override
  String get vehicleDeactivateDialogTitle => 'Deactivate this vehicle?';

  @override
  String get vehicleDeactivateDialogBody =>
      'This cannot be undone. You can still view the history, but no new entries or use sessions will be allowed for this vehicle.';

  @override
  String get vehicleDeactivateConfirm => 'Deactivate';

  @override
  String get vehicleDeactivateBlockedOpenSession =>
      'End the open use session first.';

  @override
  String get vehicleExportDataAction => 'Export data';

  @override
  String get vehicleExportConfirmBody =>
      'Export of factual vehicle data only.\n\nUse case: provide the data to another user during a transfer of ownership.';

  @override
  String get vehicleExportConfirmExport => 'Export';

  @override
  String get vehicleExportSuccessTitle => 'Export complete';

  @override
  String vehicleExportSuccessBody(String fileName) {
    return 'File saved in Documents/Bojairũ/\n$fileName';
  }

  @override
  String get vehicleExportFileDataOfSegment => 'Data-of';

  @override
  String get vehicleExportFailed => 'Export failed. Please try again.';

  @override
  String get vehicleImportAction => 'Import';

  @override
  String get vehicleImportConfirmBody =>
      'You can import vehicle data exported by another user here.\n\nYou need the export file copied locally onto this device.';

  @override
  String get vehicleImportConfirmImport => 'Import';

  @override
  String get vehicleImportFailInvalid =>
      'This file is not a valid vehicle export.';

  @override
  String get vehicleImportFailCorrupt =>
      'Import failed. The file appears to be corrupted. Try again with another copy.';

  @override
  String get vehicleImportFailOther => 'Import failed. Please try again.';

  @override
  String get vehicleSaleImportUndoAction => 'Undo import';

  @override
  String vehicleSaleImportUndoConfirmBody(String label) {
    return 'Imported data for “$label” will be permanently deleted.';
  }

  @override
  String get vehicleSaleImportConfirmActionBody =>
      'This action confirms the import of this vehicle. You will no longer be able to undo the import.';

  @override
  String get vehicleSaleImportConfirmActionConfirm => 'Confirm';

  @override
  String get vehicleAddVehicle => 'Add vehicle';

  @override
  String get vehicleAddFirst => 'Add a vehicle first.';

  @override
  String get vehicleFieldLabel => 'Display name';

  @override
  String get vehicleFieldKind => 'Vehicle kind';

  @override
  String get vehicleFieldMake => 'Make';

  @override
  String get vehicleFieldModel => 'Model';

  @override
  String get vehicleFieldColor => 'Color';

  @override
  String get vehicleFieldYear => 'Year';

  @override
  String get vehicleFieldInitialOdometer => 'Initial odometer';

  @override
  String get vehicleFieldInitialHorometer => 'Initial engine hour meter';

  @override
  String get vehicleFieldLicensePlate => 'License plate';

  @override
  String get vehicleFieldVin => 'Vehicle identification number (VIN)';

  @override
  String get vehicleFieldOptional => 'Optional';

  @override
  String get vehicleAddPhotosSection => 'Photos';

  @override
  String get vehicleAddPhotosOptionalHint =>
      'Visual archive of the vehicle\'s condition (optional).';

  @override
  String get vehicleAddGalleryStart => 'Add a gallery';

  @override
  String get vehicleAddPhotoGalleryStart => 'Add a photo gallery';

  @override
  String vehicleAddGalleryTitle(int index) {
    return 'Gallery $index';
  }

  @override
  String get vehicleAddGalleryEmpty => 'No photos in this gallery yet.';

  @override
  String get vehicleAddGalleryDescription => 'Description';

  @override
  String get vehicleAddGalleryAddPhoto => 'Add photo';

  @override
  String get vehicleAddGalleryAddGallery => 'Add another gallery';

  @override
  String get vehicleAddValidationLabelRequired => 'Display name is required.';

  @override
  String get vehicleAddValidationMakeRequired => 'Make is required.';

  @override
  String get vehicleAddValidationModelRequired => 'Model is required.';

  @override
  String get vehicleAddValidationColorRequired => 'Color is required.';

  @override
  String get vehicleAddValidationYearInvalid =>
      'Year must be a valid four-digit value.';

  @override
  String get vehicleAddValidationMeterRequired =>
      'Initial meter reading is required.';

  @override
  String get vehicleAddValidationFluidChangeFrequencyRequired =>
      'Oil changes are required.';

  @override
  String get vehicleAddValidationRequiredFields =>
      'Complete all required fields, including the odometer photo.';

  @override
  String get vehicleOdometerPhotoLabel => 'Odometer photo';

  @override
  String get vehicleEditDetailsTitle => 'Edit details';

  @override
  String get vehicleJournalsTitle => 'Logs';

  @override
  String get vehicleJournalSelectorLabel => 'Log';

  @override
  String get vehicleFormVehicleLabel => 'Vehicle';

  @override
  String get vehicleJournalEmpty => 'No entries yet.';

  @override
  String get vehicleLogRecordedAt => 'Recorded on';

  @override
  String get vehicleLogReadingRole => 'Reading type';

  @override
  String vehicleLogReadingRoleSessionEnd(String userName) {
    return '$userName - End';
  }

  @override
  String vehicleLogReadingRoleSessionStart(String userName) {
    return '$userName - Start';
  }

  @override
  String get vehicleLogReadingRoleStandalone => 'One-time reading';

  @override
  String get vehicleLogReadingRoleFuelPurchase => 'Fuel purchase';

  @override
  String get vehicleLogReadingRoleCorrection => 'Correction';

  @override
  String vehicleLogReadingRoleCorrectionBy(String userName) {
    return 'Correction by $userName';
  }

  @override
  String vehicleLogReadingRoleCorrectionSessionStart(String userName) {
    return 'Correction by $userName at session start';
  }

  @override
  String vehicleLogReadingRoleCorrectionStandalone(String userName) {
    return 'Correction by $userName during a one-time reading';
  }

  @override
  String get vehicleLogCorrectionJournalSubtitle =>
      'Odometer correction to verify';

  @override
  String get vehicleLogCorrectionLabel => 'Correction';

  @override
  String vehicleLogCorrectionMustBeAttributed(String gap) {
    return '$gap must be attributed';
  }

  @override
  String vehicleLogCorrectionGapMustBeAdded(String gap) {
    return '$gap must be added';
  }

  @override
  String vehicleLogCorrectionGapMustBeRemoved(String gap) {
    return '$gap must be removed';
  }

  @override
  String get vehiclePendingCorrectionsTitle => 'Pending corrections';

  @override
  String get vehiclePendingCorrectionsEmpty => 'No pending corrections.';

  @override
  String get vehiclePendingCorrectionDetailTitle => 'Odometer correction';

  @override
  String vehicleCorrectReadingButton(String date) {
    return 'Correct entry from $date';
  }

  @override
  String get vehicleAddMissingSessionButton => 'Add a use session';

  @override
  String get vehicleSplitSessionButton => 'Split session';

  @override
  String get vehicleGapResolutionSubmit => 'Submit';

  @override
  String get vehicleLogReadingRoleCorrectionApplied => 'Correction applied';

  @override
  String vehicleLogCorrectionAppliedSummary(String km, String name) {
    return '$km were attributed to $name';
  }

  @override
  String vehicleLogCorrectionAppliedSplitSummary(String km) {
    return '$km were attributed (split)';
  }

  @override
  String vehicleLogReadingRoleCorrectionReplaces(String label) {
    return 'Correction — replaces $label';
  }

  @override
  String vehicleLogCorrectionAppliedDivergence(String gap) {
    return 'Observed gap: $gap';
  }

  @override
  String get vehicleGapResolutionPreviousReading => 'Previous reading';

  @override
  String get vehicleGapResolutionTriggerReading => 'Subsequent reading';

  @override
  String get vehicleGapResolutionValidationMonotonicity =>
      'This value would conflict with another reading.';

  @override
  String get vehicleGapResolutionValidationSegment =>
      'Segments do not cover the gap correctly.';

  @override
  String get vehicleGapResolutionValidationDateOverlap =>
      'Segment dates overlap.';

  @override
  String get vehicleGapResolutionAssignTo => 'Assign to';

  @override
  String get vehicleGapResolutionDates => 'Date(s)';

  @override
  String get vehicleGapResolutionStartMeter => 'Start odometer';

  @override
  String get vehicleGapResolutionEndMeter => 'End odometer';

  @override
  String get vehicleLogMeterTitle => 'Log — odometer';

  @override
  String get vehicleLogMeterFuelTitle => 'Odometer and fuel';

  @override
  String get vehicleLogMeterDetailTitle => 'Reading details';

  @override
  String get vehicleLogFuelTitle => 'Log — fuel';

  @override
  String get vehicleLogFuelDetailTitle => 'Purchase details';

  @override
  String vehicleFuelPurchaseMadeBy(String name) {
    return 'Purchased by: $name';
  }

  @override
  String get vehicleLogMaintenanceTitle => 'Maintenance';

  @override
  String get vehicleLogMaintenanceDetailTitle => 'Maintenance details';

  @override
  String get vehicleLogViolationTitle => 'Damage and violations';

  @override
  String get vehicleLogViolationDetailTitle => 'Violation details';

  @override
  String get vehicleKindCar => 'Car';

  @override
  String get vehicleKindTruck => 'Truck';

  @override
  String get vehicleKindMotorcycle => 'Motorcycle';

  @override
  String get vehicleKindBoat => 'Boat';

  @override
  String get vehicleQuickActionOdometer => 'Odometer reading';

  @override
  String get vehicleUseSessionStartAction => 'Start a use session';

  @override
  String get vehicleUseSessionEndAction => 'End a use session';

  @override
  String vehicleUseSessionStartedOn(String dateTime) {
    return 'started on $dateTime';
  }

  @override
  String get vehicleQuickActionFuel => 'Fuel purchase';

  @override
  String get vehicleQuickActionMaintenance => 'Maintenance';

  @override
  String get vehicleQuickActionViolation => 'Damage or violation';

  @override
  String get vehicleOdometerLabel => 'Odometer';

  @override
  String get vehicleHorometerLabel => 'Engine hour meter';

  @override
  String get vehicleMeterPhotoRequired => 'A meter photo is required.';

  @override
  String get vehicleMeterPhotoAdd => 'Add meter photo';

  @override
  String get vehicleMeterPhotoAttached => 'Photo attached';

  @override
  String get vehicleMeterKnownUnchangedNoPhotoOdometer =>
      'Known odometer unchanged. No photo recorded.';

  @override
  String get vehicleMeterKnownUnchangedNoPhotoHorometer =>
      'Known engine hour meter unchanged. No photo recorded.';

  @override
  String get vehicleMeterPhotoCamera => 'Camera';

  @override
  String get vehicleMeterPhotoGallery => 'Gallery';

  @override
  String get vehicleUseSessionStart => 'Start use session';

  @override
  String get vehicleUseSessionEnd => 'End use session';

  @override
  String get vehicleUseSessionStarted =>
      'Session started. End it when you finish driving.';

  @override
  String get vehicleUseSessionEnded => 'Session ended.';

  @override
  String get vehicleConsumptionTitle => 'Consumption';

  @override
  String get vehicleConsumptionInsufficient =>
      'Insufficient data for consumption';

  @override
  String vehicleConsumptionPer100Km(String value) {
    return '$value L/100 km';
  }

  @override
  String vehicleConsumptionPerHour(String value) {
    return '$value L/h';
  }

  @override
  String get vehicleDrivingConditionColumn => 'Condition';

  @override
  String get vehicleDrivingConditionProportionColumn => 'Share of distance';

  @override
  String get vehicleDrivingConditionRoute => 'Highway';

  @override
  String get vehicleDrivingConditionCity => 'City';

  @override
  String get vehicleDrivingConditionTraffic => 'Traffic';

  @override
  String get vehicleConsumptionReliabilityNone =>
      'There is not enough data to calculate fuel consumption.';

  @override
  String get vehicleConsumptionReliabilityPreliminary =>
      'This estimate is preliminary. It will become more accurate as you add more data.';

  @override
  String get vehicleConsumptionReliabilityReliable =>
      'This estimate is reliable, based on the calculation formula and the data you entered.';

  @override
  String get vehicleConsumptionReliabilityVeryReliable =>
      'This estimate is very reliable because it is based on a large amount of data you entered.';

  @override
  String get vehicleConsumptionEstimationModeTitle =>
      'Fuel consumption estimation mode';

  @override
  String get vehicleConsumptionEstimationModeSimpleTitle => 'Simple';

  @override
  String vehicleConsumptionEstimationModeSimpleDescription(
    String distanceUnit,
  ) {
    return 'Only liters per 100 $distanceUnit';
  }

  @override
  String get vehicleConsumptionEstimationModeDetailedTitle => 'Detailed';

  @override
  String vehicleConsumptionEstimationModeDetailedDescription(
    String distanceUnit,
  ) {
    return 'Liters per 100 $distanceUnit for driving on highway / in city / in traffic';
  }

  @override
  String get vehicleDistanceUnitKilometres => 'kilometres';

  @override
  String get vehicleDistanceUnitMiles => 'miles';

  @override
  String get vehicleConsumptionRequireDetailedForBorrowers =>
      'Require borrowers to declare highway / city / traffic percentages';

  @override
  String vehicleConsumptionSimpleEstimate(String value) {
    return 'Consumption: $value L/100 km';
  }

  @override
  String get vehicleConsumptionInsufficientDetailedData =>
      'Not enough data yet for a detailed estimate (highway / city / traffic). The simple estimate below is shown until more detailed sessions are recorded.';

  @override
  String get vehicleConsumptionCarriedFromDetailedMode =>
      'This estimate is carried over from your previous detailed mode. It will refine as you record more full-tank periods in simple mode.';

  @override
  String get vehicleStatisticsConsumptionHistoryTitle =>
      'Reliable consumption history';

  @override
  String vehicleConsumptionHistoryBlended(String date, String value) {
    return '$date: $value L/100 km';
  }

  @override
  String get vehicleSessionEndTankConfirmTitle => 'Confirm tank level';

  @override
  String vehicleSessionEndTankConfirmBody(String distance, int percent) {
    return 'You declared the tank at $percent% full after $distance since the last fuel purchase. Please confirm this is correct.';
  }

  @override
  String get vehicleSessionEndTankConfirmReview => 'Review entry';

  @override
  String get vehicleSessionEndTankConfirmProceed => 'Confirm';

  @override
  String get vehicleStatisticsTitle => 'Statistics';

  @override
  String get vehicleStatisticsMileageTitle => 'My mileage';

  @override
  String get vehicleStatisticsExpensesTitle => 'My expenses';

  @override
  String get vehicleExpenseFuel => 'Fuel';

  @override
  String get vehicleExpenseMaintenance => 'Maintenance';

  @override
  String get vehicleExpenseViolations => 'Violations';

  @override
  String get vehicleFuelCost => 'Total cost';

  @override
  String get vehicleFuelVolume => 'Volume';

  @override
  String get vehicleFuelMeter => 'Odometer';

  @override
  String get vehicleFuelFullTank => 'Full tank';

  @override
  String get vehicleFuelTankState => 'Tank state';

  @override
  String get vehicleFuelApproximateLevel => 'Approximately:';

  @override
  String get vehicleFieldFuelTankCapacity => 'Fuel tank capacity';

  @override
  String get vehicleFieldFluidChangeFrequency => 'Oil changes';

  @override
  String get vehicleOilChangeIntervalRequired =>
      'Enter an oil change interval.';

  @override
  String get vehicleOilChangeIntervalInvalid => 'Invalid number.';

  @override
  String get vehicleOilChangeIntervalLandMin =>
      'Minimum: 1 (1,000 km or miles).';

  @override
  String get vehicleOilChangeIntervalLandMax =>
      'Maximum: 20 (20,000 km or miles).';

  @override
  String get vehicleOilChangeIntervalBoatMin => 'Minimum: 50 h.';

  @override
  String get vehicleOilChangeIntervalBoatMax => 'Maximum: 500 h.';

  @override
  String get vehicleDetailEarlierPhotos => 'Earlier photos';

  @override
  String vehicleFuelTankInTank(String volume) {
    return '$volume in tank';
  }

  @override
  String get vehicleFuelTankInfoTooltip => 'About fuel tank estimate';

  @override
  String get vehicleMaintenanceCategory => 'Category';

  @override
  String get vehicleMaintenanceCategoryOil => 'Oil';

  @override
  String get vehicleMaintenanceCategoryOtherFluids => 'Other fluids';

  @override
  String get vehicleMaintenanceCategoryTires => 'Tires';

  @override
  String get vehicleMaintenanceCategoryBrakes => 'Brakes';

  @override
  String get vehicleMaintenanceCategoryLights => 'Lights';

  @override
  String get vehicleMaintenanceCategoryCleaning => 'Cleaning';

  @override
  String get vehicleMaintenanceCategoryOther => 'Other';

  @override
  String get vehicleMaintenanceCost => 'Cost';

  @override
  String get vehicleMaintenanceNotes => 'Notes';

  @override
  String get vehicleViolationType => 'Violation type';

  @override
  String get vehicleViolationAmount => 'Amount';

  @override
  String vehicleMaintenanceAlertTile(String category, String remaining) {
    return '$category: $remaining remaining';
  }

  @override
  String get vehicleGapAttributionTitle => 'Unlogged usage';

  @override
  String vehicleGapAttributionPrompt(String gap) {
    return 'Who is the $gap difference attributable to?';
  }

  @override
  String get vehicleGapAttributionUnknown => 'I don\'t know';

  @override
  String get vehicleGapAttributionSelf => 'Myself';

  @override
  String get vehicleGapOwnerNotified => 'The owner will be notified.';

  @override
  String vehiclePositiveGapConfirmPrompt(String gap) {
    return 'This is a difference of $gap. Are you sure?';
  }

  @override
  String get vehiclePositiveGapConfirmNo => 'No';

  @override
  String get vehiclePositiveGapConfirmYes => 'Yes';

  @override
  String get vehicleNegativeGapTitle => 'Reading decreased';

  @override
  String vehicleNegativeGapBody(String gap) {
    return 'The new reading is $gap lower than the last stored reading.';
  }

  @override
  String get vehicleNegativeGapMaintain =>
      'Maintain reading, investigate later';

  @override
  String get vehicleNegativeGapCancel => 'Cancel entry';

  @override
  String get vehicleSuspiciousGapTitle => 'Unusually large difference';

  @override
  String vehicleSuspiciousGapBody(String gap, String maxGap) {
    return 'The difference of $gap exceeds what is plausible on one tank ($maxGap). This reading may be incorrect.';
  }

  @override
  String get vehicleSuspiciousGapConfirm => 'Use this reading anyway';

  @override
  String get vehicleSuspiciousGapCancel => 'Review entry';

  @override
  String get vehicleRoleOwner => 'Owner';

  @override
  String get vehicleRoleBorrower => 'Borrower';

  @override
  String get vehicleSharingShareableTitle => 'Shareable vehicle';

  @override
  String get vehicleSharingShareableTitlePlural => 'Shareable vehicles';

  @override
  String get vehicleSharingAccessibleTitle => 'Accessible vehicle';

  @override
  String get vehicleSharingAccessibleTitlePlural => 'Accessible vehicles';

  @override
  String get vehicleSharingPendingOfferTitle => 'Pending offer';

  @override
  String get vehicleSharingPendingOfferTitlePlural => 'Pending offers';

  @override
  String get vehicleSharingEmptyNone => 'None';

  @override
  String get vehicleSharingEmptyNoneFeminine => 'None';

  @override
  String get vehicleSharingSharesDetailTitle => 'Sharing';

  @override
  String get vehicleSharingAddShare => 'Add a share';

  @override
  String get vehicleSharingNewShareTitle => 'New share';

  @override
  String vehicleSharingInviteForContact(String name) {
    return 'Invitation for $name';
  }

  @override
  String get vehicleSharingInviteRateLabel => 'Cents per km of use (optional)';

  @override
  String get vehicleSharingInviteRateHelper => 'Compensates normal wear.';

  @override
  String get vehicleSharingInviteRateInvalid =>
      'Enter a whole number of cents (≥ 0).';

  @override
  String vehicleSharingInviteRatePer100Km(String amount) {
    return '$amount for 100 km';
  }

  @override
  String get vehicleSharingInviteAvailabilitySection =>
      'Availability period (optional)';

  @override
  String get vehicleSharingAvailabilityLevelPrimary => 'Available';

  @override
  String get vehicleSharingInviteAvailabilitySaveFirst =>
      'Save or cancel the availability period before sending.';

  @override
  String get vehicleSharingInviteRulesLabel => 'Other rules';

  @override
  String get vehicleSharingInviteSend => 'Send invitation';

  @override
  String get vehicleSharingInviteDisclaimerBody1 =>
      'Only the amount per kilometre is tracked by the app.';

  @override
  String get vehicleSharingInviteDisclaimerBody2 =>
      'Availability and other rules are for your borrower\'s information only.';

  @override
  String get vehicleSharingInviteDisclaimerDoNotShow => 'Don\'t show again';

  @override
  String get vehicleSharingAccept => 'Accept';

  @override
  String get vehicleSharingOffer => 'Offer sharing';

  @override
  String get vehicleSharingOfferPickContact => 'Select a connected contact';

  @override
  String get vehicleSharingNoContacts => 'Add a connected contact first.';

  @override
  String get vehicleSharingOfferSent => 'Offer sent.';

  @override
  String get vehicleSharingOfferDeadlineTitle => 'Response deadline';

  @override
  String get vehicleSharingOfferDeadlineBody =>
      'The borrower has this long to accept the invitation.';

  @override
  String vehicleSharingInvitationSentToAt(String name, String when) {
    return 'Invitation sent to $name on $when';
  }

  @override
  String get vehicleSharingOfferBlocked =>
      'Sharing requires vehicle and vehicle-sharing subscriptions.';

  @override
  String get vehicleSharingForwarded => 'Recorded on the owner\'s vehicle.';

  @override
  String vehicleSharingBorrowerLabel(String name) {
    return 'Borrower: $name';
  }

  @override
  String vehicleSharingOwnerLabel(String name) {
    return 'Owner: $name';
  }

  @override
  String get vehicleUsageBlockedOwnOnBorrowerPath =>
      'This vehicle is yours. Use the Vehicle module to record owner usage — not Vehicle sharing.';

  @override
  String get vehicleUsageBlockedNotOwnedOnOwnerPath =>
      'This vehicle is not in your owned list. Use Vehicle sharing for a vehicle shared with you.';

  @override
  String get vehicleUsageBlockedMissingBorrowerIdentity =>
      'Borrower identity is missing for this form.';

  @override
  String get vehicleUsageBlockedVehicleNotFound => 'Vehicle not found.';

  @override
  String get commonOk => 'Ok';

  @override
  String get sandboxRibbonLabel => 'Simulation mode';

  @override
  String get sandboxModeButton => 'Simulation mode';

  @override
  String get sandboxEnterDialogBody =>
      'You can simulate a plan with fake participants. This gives you an excellent preview of the app.\n\nTo use the “real” app, return to real mode. Tap the red banner at the top of the app to do so. You will be reminded after 8 hours.';

  @override
  String get sandboxEnterConfirm => 'Simulate';

  @override
  String get sandboxEnterRestartMessage =>
      'The app will close now. Reopen it to continue.';

  @override
  String get sandboxHomeWelcomeBody =>
      'Vehicle modules cannot be simulated.\n\nStart by exploring the Contacts module. Adding contacts is simplified for this simulation. You can rename these fake contacts.\n\n';

  @override
  String get sandboxExitDialogTitle => 'Leave simulation mode?';

  @override
  String get sandboxRestartRequiredMessage =>
      'Fully quit the app, then reopen it to continue.';

  @override
  String get sandboxBotsExhausted => 'You have invited all the bots.';

  @override
  String get sandboxInvitingBot => 'Inviting simulated participant…';

  @override
  String get sandboxBotExpenseTitle => 'Simulate a bot expense';

  @override
  String get sandboxBotExpenseSubtitle => 'Simulation mode';

  @override
  String get sandboxBotExpenseDescription => 'Simulated expense';

  @override
  String get sandboxEightHourNudgeTitle => 'Simulation mode';

  @override
  String get sandboxEightHourNudgeBody =>
      'You have been in simulation mode for 8 hours. Consider returning to real mode so you do not miss a partner invitation.';

  @override
  String get sandboxPortabilityBlocked =>
      'Export and import are unavailable in simulation mode.';

  @override
  String get sandboxEnterFailed =>
      'Could not enter simulation mode (checkpoint verification failed).';

  @override
  String get sandboxModuleDisabled =>
      'This module is not available in simulation mode.';
}
