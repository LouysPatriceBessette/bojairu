// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Bojairũ';

  @override
  String get commonContinue => 'Continuer';

  @override
  String get commonFinishSetup => 'Terminer la configuration';

  @override
  String get commonRetry => 'Réessayer';

  @override
  String get commonRestart => 'Redémarrer';

  @override
  String get commonComingSoon => 'Bientôt disponible';

  @override
  String get commonNotSet => 'Non défini';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get commonSend => 'Envoyer';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get commonYes => 'Oui';

  @override
  String get commonNo => 'Non';

  @override
  String get commonEdit => 'Modifier';

  @override
  String get commonDone => 'Terminé';

  @override
  String get commonCopy => 'Copier';

  @override
  String get commonPaste => 'Coller';

  @override
  String get commonBlock => 'Bloquer';

  @override
  String get commonUnblock => 'Débloquer';

  @override
  String get navHome => 'Accueil';

  @override
  String get navSettings => 'Paramètres';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsLanguageTitle => 'Langue';

  @override
  String get settingsLanguageSubtitle => 'Changer la langue de l’application';

  @override
  String get languageSystem => 'Système';

  @override
  String get languageEnglish => 'Anglais';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageSpanish => 'Espagnol';

  @override
  String get settingsProfileTitle => 'Profil';

  @override
  String get settingsCurrencyTitle => 'Devise';

  @override
  String get settingsDateFormatTitle => 'Format de date';

  @override
  String get settingsDistanceUnitTitle => 'Unité de distance';

  @override
  String get settingsPrivacyPolicyTitle => 'Politique de confidentialité';

  @override
  String get settingsPrivacyPolicySubtitle =>
      'Comment sont traitées vos informations personnelles';

  @override
  String get settingsAppVersionTitle => 'Version de l’application';

  @override
  String get settingsEnvironmentTitle => 'Environnement';

  @override
  String get settingsApiBaseUrlTitle => 'URL de base API';

  @override
  String get settingsNotificationsTitle => 'Notifications';

  @override
  String get settingsNotificationsSubtitle => 'Permissions, catégories et son';

  @override
  String get settingsUnitsTitle => 'Unités';

  @override
  String get settingsUnitsSubtitle => 'Divers formats d\'unités';

  @override
  String get settingsAboutTitle => 'À propos';

  @override
  String get settingsAboutSubtitle => 'Environnement, URL API et version';

  @override
  String get settingsExportImportTitle => 'Exporter / importer des données';

  @override
  String get settingsExportImportSubtitle =>
      'Sauvegarde et restauration complètes de l\'appareil';

  @override
  String get deviceDataExportSecurityWarning =>
      'Le fichier de sauvegarde est du JSON non chiffré. Conservez-le en lieu sûr et ne le partagez pas sur des canaux non fiables.';

  @override
  String get deviceDataExportAction => 'Exporter toutes les données';

  @override
  String get deviceDataImportAction => 'Importer une sauvegarde';

  @override
  String get deviceDataExportCopiedToClipboard =>
      'JSON de sauvegarde copié dans le presse-papiers.';

  @override
  String get deviceDataExportLastSavedTitle => 'Fichier enregistré';

  @override
  String deviceDataExportSavedLocation(String fileName) {
    return 'Documents/Bojairũ/$fileName';
  }

  @override
  String deviceDataExportFailed(String error) {
    return 'Échec de l\'export : $error';
  }

  @override
  String get deviceDataImportDisabledNoSubscription =>
      'L\'import exige un abonnement logement actif et payé sur cet appareil.';

  @override
  String get deviceDataImportDisabledWeb =>
      'L\'import n\'est pas disponible sur le web (développement seulement).';

  @override
  String get deviceDataReplaceConfirmTitle =>
      'Remplacer toutes les données locales ?';

  @override
  String get deviceDataReplaceConfirmBody =>
      'Cette sauvegarde remplacera toutes les données opérationnelles sur cet appareil. C\'est surtout prévu pour un changement d\'appareil.';

  @override
  String get deviceDataImportSuccess =>
      'Sauvegarde restaurée. La sync relay est de nouveau disponible.';

  @override
  String deviceDataImportFailed(String error) {
    return 'Échec de l\'import : $error';
  }

  @override
  String deviceDataImportValidationFailed(String code) {
    return 'Fichier de sauvegarde invalide ($code).';
  }

  @override
  String get deviceDataMigrationNetworkFailure =>
      'Les données locales sont restaurées mais le relay est injoignable. Vérifiez votre connexion et réessayez la sync serveur.';

  @override
  String deviceDataMigrationFailed(String code) {
    return 'Échec de la mise à jour d\'identité serveur ($code).';
  }

  @override
  String get deviceDataMigrationPendingTitle => 'Sync serveur en attente';

  @override
  String get deviceDataMigrationPendingBody =>
      'Vos données sont sur cet appareil mais le serveur doit encore lier votre nouvelle identité d\'installation.';

  @override
  String get deviceDataRetryMigrationAction => 'Réessayer la sync serveur';

  @override
  String get deviceDataCanonicalRestoreTitle =>
      'Restaurer les données pour quel participant ?';

  @override
  String get settingsNotificationsGeneralSection => 'Permission générale';

  @override
  String get settingsNotificationsSystemPermissionTitle => 'Permission système';

  @override
  String get settingsNotificationsSystemPermissionBody =>
      'L’app fera la demande après une action pertinente, comme inviter quelqu’un.';

  @override
  String get settingsNotificationsSystemPermissionChecking =>
      'Vérification de la permission…';

  @override
  String get settingsNotificationsSystemPermissionUnsupported =>
      'Non pris en charge sur cette plateforme';

  @override
  String get settingsNotificationsSystemPermissionUnknown =>
      'Pas encore demandé';

  @override
  String get settingsNotificationsSystemPermissionGranted =>
      'Autorisé par le système';

  @override
  String get settingsNotificationsSystemPermissionDenied =>
      'Bloqué par le système';

  @override
  String get settingsNotificationsSystemPermissionProvisional =>
      'Autorisé silencieusement';

  @override
  String get settingsNotificationsRequestAction => 'Autoriser';

  @override
  String get settingsNotificationsGeneralSwitchTitle =>
      'Autoriser les notifications de l’app';

  @override
  String get settingsNotificationsGeneralSwitchBody =>
      'Interrupteur principal pour les catégories de notification de cette app.';

  @override
  String get settingsNotificationsWakeFromSleepBody =>
      'Si autorisé, l’app s’enregistre auprès du relais pour qu’une app fermée puisse se réveiller brièvement et vérifier les nouvelles demandes de contact ou rappels de paiement—sans afficher le contenu des messages dans la notification push.';

  @override
  String get settingsNotificationsContactsSection => 'Contacts';

  @override
  String get settingsNotificationsContactAddRequest =>
      'Demande/confirmation d’ajout';

  @override
  String get settingsNotificationsContactDisconnection => 'Avis de déconnexion';

  @override
  String get settingsNotificationsContactInvitationExpiration =>
      'Expiration d’une invitation non consommée';

  @override
  String get settingsNotificationsCountryStatsSection =>
      'Statistiques utilisateurs';

  @override
  String get settingsNotificationsCountryStatsSwitchTitle =>
      'Dans quel pays êtes-vous situé?';

  @override
  String get settingsNotificationsCountryStatsSwitchSubtitle =>
      'Permettre le partage du nom de votre pays. Aucun autre contenu personnel ne sera utilisé. La donnée sera compilée dans un total d’utilisateurs par pays.';

  @override
  String get settingsNotificationsCountryStatsPickerLabel => 'Pays';

  @override
  String get settingsNotificationsCountryStatsSearchHint =>
      'Rechercher par nom';

  @override
  String get settingsNotificationsCountryStatsEmpty =>
      'Aucun pays correspondant';

  @override
  String get settingsNotificationsHousingSection => 'Logement';

  @override
  String get settingsNotificationsHousingPlanSubmission =>
      'Soumission d’un plan reçue';

  @override
  String get settingsNotificationsHousingDecisionChange =>
      'Changements de statut de décision d’un participant';

  @override
  String get settingsNotificationsHousingOfferExpiration =>
      'Expiration d’une offre de plan sans acceptation unanime';

  @override
  String get settingsNotificationsSoundSection => 'Son';

  @override
  String get settingsNotificationsSoundSwitchTitle => 'Jouer un son';

  @override
  String get settingsNotificationsSoundSwitchBody =>
      'Les notifications seront silencieuses quand ce réglage est désactivé.';

  @override
  String get settingsNotificationsSoundPickerTitle => 'Son de notification';

  @override
  String get settingsNotificationsSoundPickerBody =>
      'La sélection d’un son de l’appareil sera ajoutée plus tard quand les plateformes le permettent sans risque.';

  @override
  String get settingsNotificationsEnableBlocked =>
      'La permission système des notifications n’est pas accordée.';

  @override
  String get notificationFlowPermissionPromptTitle =>
      'Activer les notifications utiles?';

  @override
  String get notificationFlowPermissionPromptBody =>
      'L’app peut activer les permissions de notification nécessaires pour ce que vous vous apprêtez à faire.';

  @override
  String get notificationFlowPermissionEnableAction =>
      'Oui, les activer et continuer';

  @override
  String get notificationFlowPermissionReviewAction =>
      'Je veux vérifier moi-même';

  @override
  String get notificationFlowPermissionNoAction => 'Non, continuer';

  @override
  String get onboardingTitle => 'Configuration';

  @override
  String get onboardingLanguageTitle => 'Langue';

  @override
  String get onboardingLanguageBody =>
      'Choisissez la langue de l’application. Vous pourrez la changer en tout temps dans les paramètres.';

  @override
  String get onboardingWelcomeTitle => 'Bienvenue';

  @override
  String get onboardingWelcomeIntro =>
      'Bojairũ est une application développée dans le but d\'aider les colocataires à mieux s\'entendre.\n\nEn utilisant cette application, vous éviterez des malentendus, des oublis et des erreurs de calculs qui sont souvent source de conflits. Pour en tirer le maximum, il faut entrer les données au fur et à mesure qu\'elles sont connues.';

  @override
  String get onboardingWelcomeConfidentialTitle => 'Confidentiel';

  @override
  String get onboardingWelcomeConfidentialBody =>
      'Enfin une véritable confidentialité. Vous pouvez entrer vos données sans aucune crainte. Personne d\'autre que vous et vos colocataires n\'y auront accès. Cette affirmation n\'est pas une simple promesse, c\'est un fait démontrable. Tout le code de l\'application est public et peut être inspecté et audité.\n\nCeci implique toutefois un compromis important: Il n\'y a aucune manière de récupérer vos données si vous les perdez (perte, vol ou bris de votre appareil). L\'application inclut une fonctionnalité d\'import/export de données qu\'il est fortement suggéré d\'utiliser périodiquement afin de conserver une sauvegarde. Libre à vous de placer le fichier exporté où vous voulez. Le stockage sécuritaire de cette sauvegarde sera de votre responsabilité.';

  @override
  String get onboardingOk => 'Ok';

  @override
  String get onboardingProfileTitle => 'Votre profil';

  @override
  String get onboardingNameLabel => 'Nom';

  @override
  String get onboardingNameHint => 'Nom affiché';

  @override
  String get onboardingAvatarTitle => 'Choisissez un avatar';

  @override
  String get onboardingPreferencesTitle => 'Préférences';

  @override
  String get prefsCurrencyLabel => 'Devise';

  @override
  String get prefsCurrencySearchHint => 'Rechercher par code ou nom';

  @override
  String get prefsDateFormatLabel => 'Format de date';

  @override
  String get prefsDistanceUnitLabel => 'Unité de distance';

  @override
  String get prefsDistanceUnitKm => 'Kilomètres (km)';

  @override
  String get prefsDistanceUnitMiles => 'Miles';

  @override
  String get prefsLiquidVolumeUnitLabel => 'Unité de volume liquide';

  @override
  String get prefsLiquidVolumeUnitLiter => 'Litre';

  @override
  String get prefsLiquidVolumeUnitUsGallon => 'Gallon US (3,785 L)';

  @override
  String get prefsLiquidVolumeUnitImperialGallon => 'Gallon impérial (4,546 L)';

  @override
  String get prefsWeekStartLabel => 'Début de la semaine';

  @override
  String get prefsWeekStartSunday => 'Dimanche';

  @override
  String get prefsWeekStartMonday => 'Lundi';

  @override
  String get prefsTimeZoneLabel => 'Fuseau horaire';

  @override
  String get prefsTimeZoneDevice => 'Utiliser l’heure locale de l’appareil';

  @override
  String get prefsTimeZoneSearchHint => 'Rechercher un fuseau horaire';

  @override
  String get errorSomethingWentWrongTitle => 'Une erreur est survenue';

  @override
  String get errorSomethingWentWrongBody =>
      'S\'il vous plaît, prenez une capture d\'écran maintenant et envoyez-la avec une description des étapes qui vous ont mené à cette erreur.';

  @override
  String get errorReportBugLink => 'Rapporter cette erreur';

  @override
  String get errorUnknownOnboardingStep => 'Étape de configuration inconnue.';

  @override
  String get homeHousingPlan => 'Plan logement';

  @override
  String get homeModuleContacts => 'Contacts';

  @override
  String get homeModuleHousing => 'Logement';

  @override
  String get homeModuleVehicle => 'Véhicule';

  @override
  String get homeModuleVehicleSharing => 'Partage de véhicule';

  @override
  String get housingPlanSummaryMonthlyTotal => 'Total mensuel';

  @override
  String housingPlanLoadError(String error) {
    return 'Impossible de charger les données du plan.\n$error';
  }

  @override
  String get housingPlanStepParticipants => 'Participants';

  @override
  String get housingPlanStepPlanDates => 'Dates du plan';

  @override
  String get housingPlanStepExpenseCategories => 'Catégories de dépenses';

  @override
  String get housingPlanStepExpenses => 'Dépenses';

  @override
  String get housingPlanStepSplit => 'Répartition';

  @override
  String get housingPlanStepAgreementRules => 'Règles de l\'accord';

  @override
  String get housingAgreementRulesIntro =>
      'Activez ou désactivez chaque règle. Les règles fixes restent visibles même désactivées pour montrer ce qui a été négocié. Vous pouvez ajouter des règles et les retirer tant qu\'aucune proposition n\'a été acceptée.';

  @override
  String get housingAgreementRulesAmendmentIntro =>
      'Activez ou désactivez les règles optionnelles, modifiez-les, ajoutez-en ou retirez-les. Les règles fixes (couvre-feu, retrait anticipé, immeuble) restent visibles même désactivées. Les nouvelles règles doivent être activées pour figurer dans la proposition.';

  @override
  String get housingAgreementRuleCurfewTitle => 'Calendrier de couvre-feu';

  @override
  String get housingAgreementRuleCurfewPlaceholder =>
      'Semaine indicative (sans dates) : choisissez un jour, puis la grille. En édition, touchez une case de 30 minutes pour faire défiler aucune règle → calme absolu (rouge) → calme modéré (jaune).';

  @override
  String get housingQuietHoursAbsolute => 'Calme absolu';

  @override
  String get housingQuietHoursModerate => 'Calme modéré';

  @override
  String get housingQuietHoursNoneThisDay => 'Aucun horaire';

  @override
  String get housingQuietHoursCopyDayTooltip =>
      'Copier cette journée vers d\'autres jours';

  @override
  String housingQuietHoursCopyDayDialogMessage(String sourceDay) {
    return 'Copier l\'horaire de la journée de $sourceDay sur quels autres jours ?';
  }

  @override
  String get housingAgreementRuleEarlyWithdrawalTitle => 'Retrait anticipé';

  @override
  String get housingAgreementRuleBuildingTitle =>
      'Règles de l\'immeuble / du logement';

  @override
  String get housingAgreementRuleBuildingHint =>
      'Exemples à adapter :\nLogement non-fumeur\nPas d\'animaux\nRien dans les couloirs\n…';

  @override
  String get housingAgreementRuleEdit => 'Modifier';

  @override
  String get housingAgreementRuleFinishEditing => 'Terminer l\'édition';

  @override
  String get housingAgreementRuleTitleRequired =>
      'Saisissez un titre pour cette règle.';

  @override
  String get housingAgreementSuggestionLabel => 'Suggestion';

  @override
  String get housingAgreementSuggestionCleanlinessTitle =>
      'Propreté des espaces communs';

  @override
  String get housingAgreementSuggestionCleanlinessBody =>
      'Gardez vos vêtements aux emplacements prévus.\nNettoyez douche et toilettes après usage.\nEssuyez le plan de travail après cuisine.';

  @override
  String get housingAgreementSuggestionFridgeTitle =>
      'Gestion du réfrigérateur';

  @override
  String get housingAgreementSuggestionFridgeBody =>
      'Identifiez clairement ce que vous ne partagez pas.\nJetez régulièrement ce qui n\'est plus bon.\nGardez tablettes et portes propres.';

  @override
  String get housingAgreementRuleRemove => 'Retirer la règle';

  @override
  String get housingAgreementRuleDismissSuggestion => 'Retirer de la liste';

  @override
  String get housingAgreementRuleAdd => 'Ajouter une règle';

  @override
  String get housingAgreementRuleAddTitle => 'Ajouter une règle à l\'accord';

  @override
  String get housingAgreementRuleCustomTitleLabel => 'Titre';

  @override
  String get housingAgreementRuleCustomBodyLabel => 'Détails (optionnel)';

  @override
  String get housingAgreementRulesRemovalLockedHint =>
      'Les règles ayant fait partie d\'une proposition acceptée ne peuvent pas être retirées ; vous pouvez encore les désactiver.';

  @override
  String get housingAgreementRuleEarlyWithdrawalDisabledHint =>
      'Activez la règle pour renseigner préavis et pénalité.';

  @override
  String housingPlanParticipantsCount(int count) {
    return '$count participants';
  }

  @override
  String get housingPlanFewerParticipantsTooltip => 'Moins de participants';

  @override
  String get housingPlanMoreParticipantsTooltip => 'Plus de participants';

  @override
  String get housingPlanAddCategoryTooltip =>
      'Ajouter une catégorie de dépense';

  @override
  String get housingPlanAddExpenseTooltip => 'Ajouter une dépense';

  @override
  String get housingPlanBack => 'Retour';

  @override
  String get housingPlanNext => 'Suivant';

  @override
  String get housingPlanFinish => 'Terminer';

  @override
  String get housingPlanSplitValidationMessage =>
      'Chaque dépense ou catégorie doit totaliser 100 % entre les participants.';

  @override
  String housingPlanCouldNotContinue(String error) {
    return 'Impossible de continuer : $error';
  }

  @override
  String get housingPlanInviteComingSoon =>
      'Inviter les participants (bientôt)';

  @override
  String get housingPlanPreviousPerson => 'Précédent';

  @override
  String get housingPlanNextPerson => 'Suivant';

  @override
  String get housingPlanParticipantNameLabel => 'Nom';

  @override
  String get housingPlanChooseContactAction => 'Choisir un contact';

  @override
  String get housingPlanChangeContactAction => 'Changer de contact';

  @override
  String get housingPlanRemoveParticipantHint =>
      'Glissez-déplacez un contact ici pour le retirer.';

  @override
  String get housingPlanContactRequired =>
      'Choisissez un contact pour chaque participant avant de continuer.';

  @override
  String get housingPlanParticipantsMustBeConnected =>
      'Chaque co-participant doit être un contact connecté (il utilise l’app avec son propre compte). Invitez-le depuis Contacts d’abord, puis sélectionnez-le ici.';

  @override
  String get housingPlanParticipantsPlaceholderNote =>
      'Les co-participants doivent être des contacts connectés. Le plan conserve une copie du nom et de l’avatar pour garder l’historique lisible.';

  @override
  String get housingPlanYou => 'Vous';

  @override
  String housingPlanCoParticipantUnnamed(int index) {
    return 'Co-participant $index';
  }

  @override
  String get housingPlanPlanStart => 'Début du plan';

  @override
  String get housingPlanPlanEnd => 'Fin du plan';

  @override
  String get housingPlanDurationLabel => 'Durée';

  @override
  String get housingPlanEndDateError =>
      'La date de fin doit être après la date de début (d’au moins un jour calendaire).';

  @override
  String get housingPlanCategoriesEmptyHint =>
      'Appuyez sur + pour ajouter une catégorie. À l’étape suivante, vous pourrez rattacher chaque dépense à une catégorie pour garder les postes liés ensemble.';

  @override
  String get housingPlanDeleteCategoryTitle => 'Supprimer la catégorie';

  @override
  String get housingPlanDeleteCategoryBody =>
      'Les dépenses de cette catégorie n’y seront plus rattachées. Les dépenses elles-mêmes ne sont pas supprimées.';

  @override
  String get housingPlanCancel => 'Annuler';

  @override
  String get housingPlanDelete => 'Supprimer';

  @override
  String get housingPlanTapToAddExpense =>
      'Appuyez sur + pour ajouter une dépense.';

  @override
  String get housingPlanAddExpensesFirst => 'Ajoutez d’abord des dépenses.';

  @override
  String get housingPlanAddAtLeastOneExpense => 'Ajoutez au moins une dépense!';

  @override
  String get housingPlanExpenseAmountsIncomplete =>
      'Chaque dépense doit avoir un montant supérieur à zéro.';

  @override
  String get housingPlanExpenseRecurrenceIncomplete =>
      'Indiquez la récurrence de chaque dépense récurrente.';

  @override
  String get housingPlanExpenseSplitsIncomplete =>
      'La répartition de chaque dépense doit totaliser 100 %.';

  @override
  String get housingPlanExpenseParticipantsMissing =>
      'Il manque des participants pour valider les dépenses.';

  @override
  String get housingPlanSplitNoCategory => 'Sans catégorie';

  @override
  String get housingPlanWithdrawalIntro => 'Règles de retrait anticipé.';

  @override
  String get housingPlanWithdrawalSameForAll =>
      'Même règle pour tous les participants';

  @override
  String get housingPlanMinimumNoticeDays => 'Préavis minimum (jours)';

  @override
  String get housingPlanPenaltyAmount => 'Montant de la pénalité';

  @override
  String get housingPlanSummaryMissingAgreement => 'Accord manquant';

  @override
  String get housingPlanSummaryMissingParticipants =>
      'Aucun participant pour ce plan. Modifiez le plan pour les configurer à nouveau.';

  @override
  String get housingPlanSummaryEditPlan => 'Modifier le plan';

  @override
  String get housingPlanSummaryInvite => 'Soumettre mon plan';

  @override
  String get housingWorkbenchTitle => 'Plans logement';

  @override
  String get housingWorkbenchDraftsSection => 'Ébauche(s)';

  @override
  String get housingWorkbenchPendingSection => 'En attente';

  @override
  String get housingWorkbenchArchivedSection => 'Archivée(s)';

  @override
  String get housingWorkbenchActiveSection => 'Plans actifs';

  @override
  String get housingWorkbenchSettlementSection => 'Règlement en cours';

  @override
  String housingWorkbenchSettlementOpenLabel(String planTitle) {
    return '$planTitle — règlement';
  }

  @override
  String get housingWorkbenchOpenPlan => 'Ouvrir';

  @override
  String get housingWorkbenchEmpty =>
      'Aucun plan logement avec votre profil sur cet appareil.';

  @override
  String get housingActiveHubTitle => 'Entente active';

  @override
  String housingActiveHubPeriod(String dateRange) {
    return '$dateRange';
  }

  @override
  String get housingActiveHubEnterExpense => 'Soumettre une dépense';

  @override
  String get housingActiveHubEnterSettlementDue => 'Régler un dû';

  @override
  String housingActiveHubSettlementAvailableUntil(String date) {
    return 'Fonctionnalité disponible jusqu\'au $date';
  }

  @override
  String get housingSettlementDueTitle => 'Règlement de dû';

  @override
  String get housingSettlementDueSubmit => 'Proposer le règlement';

  @override
  String get housingSettlementDueSuccess => 'Règlement proposé.';

  @override
  String get housingSettlementDueTransferDescription =>
      'Règlement de fin d\'entente';

  @override
  String get housingSettlementDueNoCounterparties =>
      'Aucun solde en cours avec les autres participants.';

  @override
  String get housingActiveHubMonthlyExpenses => 'Dépenses acceptées';

  @override
  String get housingActiveHubBalances => 'Dûs entre participants';

  @override
  String get housingActiveHubPaymentStatus => 'Dépenses courantes';

  @override
  String get housingActiveHubViewPlan => 'Consulter le plan';

  @override
  String get housingActiveHubRequestAmendment => 'Modifier le plan';

  @override
  String get housingActiveHubJournals => 'Journaux';

  @override
  String get housingActiveHubExportImport => 'Sauvegarde de sécurité';

  @override
  String get housingExportSecurityWarning =>
      'Le fichier exporté est du JSON non chiffré. Conservez-le en lieu sûr et ne le partagez pas sur des canaux non fiables.';

  @override
  String get housingExportAction => 'Exporter les données de l\'entente';

  @override
  String get housingExportCopiedToClipboard =>
      'JSON exporté copié dans le presse-papiers.';

  @override
  String get housingExportLastSavedTitle => 'Fichier enregistré';

  @override
  String housingExportSavedLocation(String fileName) {
    return 'Stockage interne/Documents/Bojairũ/$fileName';
  }

  @override
  String housingExportFailed(String error) {
    return 'Échec de l\'export : $error';
  }

  @override
  String get housingImportNotAvailableTitle => 'Importation';

  @override
  String get housingImportNotAvailableBody =>
      'L\'importation exige un droit logement valide et sera activée dans une version ultérieure.';

  @override
  String get housingActiveHubPassPlaceholderTitle => 'Bientôt disponible';

  @override
  String get housingActiveHubPassPlaceholderBody =>
      'Cet écran sera disponible à la prochaine étape d\'implémentation.';

  @override
  String get housingRealizedExpenseTitle => 'Soumettre une dépense';

  @override
  String get housingRealizedExpensePlanLine => 'Ligne du plan';

  @override
  String get housingRealizedExpenseAmount => 'Montant';

  @override
  String get housingRealizedExpensePaymentDate => 'Date du paiement';

  @override
  String get housingRealizedExpenseTransferDate => 'Date du virement';

  @override
  String get housingRealizedExpensePaymentDatePick => 'Choisir une date';

  @override
  String get housingRealizedExpensePayer => 'Qui a payé';

  @override
  String get housingRealizedExpenseKind => 'Type de dépense';

  @override
  String get housingRealizedExpenseKindNormal => 'Paiement';

  @override
  String get housingRealizedExpenseKindReimbursement => 'Remboursement';

  @override
  String get housingRealizedExpenseKindAdvance => 'Avance';

  @override
  String get housingRealizedExpenseKindTransfer => 'Virement';

  @override
  String get housingRealizedExpenseBeneficiary => 'Part remboursée de';

  @override
  String get housingRealizedExpenseTransferRecipient =>
      'Participant qui a reçu le montant';

  @override
  String housingRealizedExpenseTransferRecipientSummary(String name) {
    return 'Montant donné à $name';
  }

  @override
  String get housingRealizedExpenseTransferDescription =>
      'Description / commentaire (optionel)';

  @override
  String get housingRealizedExpenseProofSection => 'Preuve (optionel)';

  @override
  String get housingRealizedExpenseProofEncourage =>
      'Ajouter un reçu ou une facture aide le groupe à valider cette dépense.';

  @override
  String get housingRealizedExpenseAddProof => 'Ajouter une preuve';

  @override
  String get housingRealizedExpensePickCamera => 'Prendre une photo';

  @override
  String get housingRealizedExpenseCapturePhoto => 'Capturer la photo';

  @override
  String get housingRealizedExpenseCameraStartFailed =>
      'Impossible d\'accéder à la caméra sur cet appareil.';

  @override
  String get housingRealizedExpensePickGallery => 'Choisir dans la galerie';

  @override
  String get housingRealizedExpensePickDocument => 'Choisir un document';

  @override
  String housingRealizedExpenseStoragePath(String path) {
    return 'Enregistré : $path';
  }

  @override
  String get housingRealizedExpenseSaveDraft => 'Enregistrer le brouillon';

  @override
  String get housingRealizedExpenseSubmit => 'Soumettre au groupe';

  @override
  String get housingRealizedExpenseDraftSaved =>
      'Brouillon enregistré sur cet appareil';

  @override
  String get housingRealizedExpenseProposedSnackbar =>
      'Dépense soumise pour révision du groupe';

  @override
  String get housingRealizedExpenseValidationLine =>
      'Sélectionnez une ligne du plan';

  @override
  String get housingRealizedExpenseValidationAmount =>
      'Entrez un montant valide';

  @override
  String get housingRealizedExpenseValidationPayer => 'Indiquez qui a payé';

  @override
  String get housingRealizedExpenseValidationDate =>
      'Sélectionnez une date de paiement';

  @override
  String get housingRealizedExpenseValidationBeneficiary =>
      'Indiquez le participant qui a reçu le montant';

  @override
  String get housingRealizedExpenseNoPlanLines =>
      'Cette entente n\'a pas encore de lignes de dépense. Ajoutez-en via une modification du plan.';

  @override
  String get housingRealizedExpenseLoadFailed =>
      'Impossible de charger les données de l\'entente';

  @override
  String get housingRealizedExpenseCropTitle => 'Recadrer la preuve';

  @override
  String get housingRealizedExpenseCropConfirm => 'Utiliser l\'image recadrée';

  @override
  String get housingRealizedExpenseCropFailed =>
      'Impossible de recadrer l\'image';

  @override
  String get housingRealizedExpenseProofTapToSaveCopy =>
      'Touchez pour enregistrer une copie';

  @override
  String get housingRealizedExpenseProofSaveCopyFailed =>
      'Impossible d\'enregistrer une copie du fichier';

  @override
  String get housingRealizedExpenseProofImagesOnly =>
      'Sélectionnez seulement une image (jpg, jpeg, png, webp, heic).';

  @override
  String get housingRealizedExpenseProofImageTooLarge =>
      'Cette image est trop volumineuse pour être traitée dans l\'application web. Choisissez une image plus petite ou envoyez-la autrement.';

  @override
  String housingActiveHubReviewPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dépenses à réviser',
      one: '1 dépense à réviser',
    );
    return '$_temp0';
  }

  @override
  String get housingRealizedExpenseReviewListTitle => 'Réviser les dépenses';

  @override
  String get housingRealizedExpenseReviewEmpty => 'Aucune dépense à réviser.';

  @override
  String get housingRealizedExpenseReviewWaitingForYou =>
      'En attente de votre révision';

  @override
  String get housingRealizedExpenseReviewWaitingForOthers =>
      'En attente des autres participants';

  @override
  String get housingRealizedExpenseReviewPublished => 'Publiée';

  @override
  String get housingRealizedExpenseReviewRejected => 'Refusée';

  @override
  String get housingRealizedExpenseReviewTitle => 'Révision de dépense';

  @override
  String get housingRealizedExpenseReviewTypeLabel => 'Type';

  @override
  String get housingRealizedExpenseReviewMadeByLabel => 'Faite par';

  @override
  String get housingRealizedExpenseReviewPlanLineLabel => 'Ligne du plan';

  @override
  String get housingRealizedExpenseReviewDescriptionLabel =>
      'Description / commentaire';

  @override
  String housingRealizedExpenseTransferToYouBy(String name) {
    return 'Viré à vous par: $name';
  }

  @override
  String housingRealizedExpenseTransferToParticipant(String name) {
    return 'Viré à $name';
  }

  @override
  String get housingRealizedExpenseReviewDescriptionNone => 'Aucun';

  @override
  String get housingRealizedExpenseReviewAcceptedWord => 'Accepté';

  @override
  String get housingRealizedExpenseReviewRejectedWord => 'Refusé';

  @override
  String get housingRealizedExpenseReviewDecisionsTitle => 'Décisions';

  @override
  String get housingRealizedExpenseReviewDecisionTableNameColumn => 'Nom';

  @override
  String get housingRealizedExpenseReviewDecisionTableDateColumn => 'Date';

  @override
  String get housingRealizedExpenseReviewDecisionPendingShort => 'En attente';

  @override
  String get housingRealizedExpenseReviewDecisionUnknown => 'Inconnue';

  @override
  String get housingRealizedExpenseReviewMotifLabel => 'Motif';

  @override
  String housingRealizedExpenseReviewDecisionPending(String name) {
    return '$name : en attente';
  }

  @override
  String housingRealizedExpenseReviewDecisionAccepted(String name) {
    return '$name : accepté';
  }

  @override
  String housingRealizedExpenseReviewDecisionRejected(String name) {
    return '$name : refusé';
  }

  @override
  String housingRealizedExpenseReviewByName(String name) {
    return 'par $name';
  }

  @override
  String housingRealizedExpenseReviewAcceptedByOn(String name, String when) {
    return 'Accepté par $name le $when';
  }

  @override
  String housingRealizedExpenseReviewRejectedByOn(String name, String when) {
    return 'Refusé par $name le $when';
  }

  @override
  String get housingRealizedExpenseTransferReviewHint =>
      'Vérifiez que vous avez bien reçu le virement avant d\'accepter. Il n\'y a pas de délai limite.';

  @override
  String housingRealizedExpenseReviewPayer(String name) {
    return 'Payée par $name';
  }

  @override
  String get housingRealizedExpenseReviewRejections => 'Refus';

  @override
  String get housingRealizedExpenseAccept => 'Accepter';

  @override
  String get housingRealizedExpenseReject => 'Refuser';

  @override
  String get housingRealizedExpenseRejectTitle => 'Refuser la dépense';

  @override
  String get housingRealizedExpenseRejectJustification => 'Motif (obligatoire)';

  @override
  String get housingRealizedExpenseRejectConfirm => 'Refuser';

  @override
  String get housingRealizedExpenseAccepted => 'Dépense acceptée';

  @override
  String get housingRealizedExpenseRejected => 'Dépense refusée';

  @override
  String get housingRealizedExpenseResubmit => 'Corriger et resoumettre';

  @override
  String get housingMonthlyExpensesTitle => 'Dépenses acceptées';

  @override
  String housingMonthlyExpensesMonthLabel(int year, int month) {
    return '$year-$month';
  }

  @override
  String get housingMonthlyExpensesEmpty =>
      'Aucune dépense publiée pour ce mois.';

  @override
  String get housingRejectedExpensesTitle => 'Dépenses refusées';

  @override
  String get housingRejectedExpensesEmpty =>
      'Aucune dépense refusée pour ce mois.';

  @override
  String get housingBalancesTitle => 'Dûs entre participants';

  @override
  String get housingBalancesEmpty =>
      'Aucune balance pour l\'instant. Les dépenses publiées apparaîtront ici.';

  @override
  String housingBalancesOwes(String from, String to, String amount) {
    return '$from doit $amount à $to';
  }

  @override
  String get housingBalancesModeReal => 'Réels';

  @override
  String get housingBalancesModeOptimized => 'Optimisés';

  @override
  String get housingBalancesLegendTitle => 'Légende';

  @override
  String get housingBalancesOwesNobody => 'Ne doit rien à personne.';

  @override
  String housingBalancesOwesAmountTo(String amount, String to) {
    return '$amount à $to';
  }

  @override
  String get housingBalancesInactiveMarker => '(ancien participant)';

  @override
  String get housingExpensePaymentStatusTitle => 'Dépenses courantes';

  @override
  String get housingExpensePaymentStatusEmpty =>
      'Aucune dépense du plan à afficher.';

  @override
  String housingExpensePaymentStatusDetailsTitle(String expenseName) {
    return 'Paiements — $expenseName';
  }

  @override
  String get housingExpensePaymentStatusDetailsEmpty =>
      'Aucun paiement publié pour cette dépense ce mois-ci.';

  @override
  String housingExpensePaymentStatusDetailsLine(
    String amount,
    String date,
    String payer,
  ) {
    return '$amount — $date — $payer';
  }

  @override
  String get housingRealizedExpenseBudgetCapTitle => 'Budget mensuel dépassé';

  @override
  String housingRealizedExpenseBudgetCapBody(String cap) {
    return 'Ce montant dépasse le plafond mensuel ($cap) pour cette ligne. Soumettre quand même ?';
  }

  @override
  String get housingRealizedExpenseBudgetCapConfirm => 'Soumettre quand même';

  @override
  String get housingRealizedExpensePaymentChartCarryTitle =>
      'Montant mensuel dépassé';

  @override
  String housingRealizedExpensePaymentChartCarryBody(
    String monthlyTotal,
    String excess,
  ) {
    return 'Ce paiement dépasse le montant mensualisé ($monthlyTotal) de cette dépense de $excess. Reporter l\'excédent au mois suivant dans le graphique d\'état des paiements ?';
  }

  @override
  String get housingRealizedExpensePaymentChartCarryNextMonth =>
      'Reporter au mois suivant';

  @override
  String get housingRealizedExpensePaymentChartCarryCurrentMonth =>
      'Afficher sur le mois courant';

  @override
  String get housingActivePlanReadOnlyTitle => 'Détail du plan';

  @override
  String get housingActivePlanDatesLabel => 'Dates du plan';

  @override
  String get housingActivePlanReadOnlyExpenses => 'Voir les lignes de dépense';

  @override
  String get housingAmendmentRequestTitle => 'Modifier le plan';

  @override
  String get housingAmendmentRequestIntro =>
      'Choisissez un seul changement par proposition. Le groupe doit l\'accepter à l\'unanimité.';

  @override
  String get housingAmendmentPendingBlocks =>
      'Une modification attend déjà des réponses.';

  @override
  String get housingAmendmentPickLine => 'Choisir une ligne';

  @override
  String get housingAmendmentTypeLineEdit => 'Modifier une dépense';

  @override
  String get housingAmendmentTypeLineEditHint =>
      'Titre, montant, description, responsable, récurrence ou parts';

  @override
  String get housingAmendmentTypeLineAmount => 'Modifier un montant';

  @override
  String get housingAmendmentTypeLineAmountHint =>
      'Mettre à jour le prix d\'une ligne';

  @override
  String get housingAmendmentTypeLineRecurrence => 'Modifier la récurrence';

  @override
  String get housingAmendmentTypeLineRecurrenceHint =>
      'Changer la fréquence d\'une ligne';

  @override
  String get housingAmendmentTypeLinePayer => 'Modifier qui paie';

  @override
  String get housingAmendmentTypeLinePayerHint =>
      'Changer le responsable du paiement';

  @override
  String get housingAmendmentTypeLineAdd => 'Ajouter une dépense';

  @override
  String get housingAmendmentTypeLineAddHint =>
      'Ajouter une nouvelle dépense au plan';

  @override
  String get housingAmendmentTypeLineRemove => 'Retirer une dépense';

  @override
  String get housingAmendmentTypeLineRemoveHint =>
      'Retirer une ligne (les dépenses passées restent liées)';

  @override
  String get housingAmendmentLineRemoveConfirm =>
      'Retirer cette ligne du plan ? Les dépenses déjà enregistrées pour cette ligne sont conservées.';

  @override
  String get housingAmendmentLineRemoveConfirmAction => 'Retirer la ligne';

  @override
  String get housingAmendmentTypeAgreementEnd => 'Modifier la date de fin';

  @override
  String get housingAmendmentTypeAgreementEndHint =>
      'Prolonger ou raccourcir la période';

  @override
  String housingAmendmentEndDateSet(String date) {
    return 'Fin fixée au $date';
  }

  @override
  String get housingAmendmentTypeRuleChange => 'Modifier les règles';

  @override
  String get housingAmendmentTypeRuleChangeHint => 'Couvre-feu, retrait, etc.';

  @override
  String get housingAmendmentRosterChangeTitle => 'Changement majeur';

  @override
  String get housingAmendmentRosterChangeHint =>
      'Ajouter ou retirer un colocataire exige une nouvelle entente';

  @override
  String get housingAmendmentRosterChangeBody =>
      'Les changements de participants ne sont pas une modification en cours d\'entente. Terminez l\'entente ou démarrez une nouvelle période à partir du plan actuel.';

  @override
  String get housingAgreementRenewalTitle => 'Nouvelle période d\'entente';

  @override
  String get housingAgreementRenewalIntro =>
      'À la fin de la période ou pour un changement de groupe, démarrez une nouvelle proposition unanime. Vous pouvez la dériver du plan actuel.';

  @override
  String get housingAgreementRenewalFork =>
      'Nouvelle période à partir de ce plan';

  @override
  String get housingAgreementEndNow => 'Terminer l\'entente aujourd\'hui';

  @override
  String get housingAgreementEndConfirmTitle => 'Terminer l\'entente ?';

  @override
  String get housingAgreementEndConfirmBody =>
      'Aucune nouvelle dépense réalisée après aujourd\'hui. Vous pourrez démarrer une nouvelle période plus tard.';

  @override
  String get housingAgreementEndConfirmAction => 'Terminer aujourd\'hui';

  @override
  String get housingAgreementEndedSnackbar =>
      'Période d\'entente close sur cet appareil';

  @override
  String get housingAgreementExpiredTitle => 'Période terminée';

  @override
  String get housingAgreementExpiredBody =>
      'Vous ne pouvez plus entrer de dépenses réalisées pour cette période. Démarrez une nouvelle entente pour continuer.';

  @override
  String get housingAmendmentDetailTitle => 'Changement demandé';

  @override
  String housingAmendmentDetailIntro(String proposer, String subject) {
    return '$proposer propose de modifier $subject.';
  }

  @override
  String get housingAmendmentDetailCurrent => 'Actuellement';

  @override
  String get housingAmendmentDetailPrevious => 'Auparavant';

  @override
  String get housingAmendmentDetailAtRequestTime => 'Au moment de la demande';

  @override
  String get housingAmendmentDetailProposed => 'Proposé';

  @override
  String get housingAmendmentSubjectAgreementEnd => 'Date de fin d\'entente';

  @override
  String housingAmendmentSubjectLineEdit(String line) {
    return 'la dépense « $line »';
  }

  @override
  String housingAmendmentSubjectLineAmount(String line) {
    return 'le montant de « $line »';
  }

  @override
  String housingAmendmentSubjectLineRecurrence(String line) {
    return 'la récurrence de « $line »';
  }

  @override
  String housingAmendmentSubjectLinePayer(String line) {
    return 'qui paie pour « $line »';
  }

  @override
  String get housingAmendmentSubjectLineAdd =>
      'le plan (nouvelle ligne de dépense)';

  @override
  String housingAmendmentSubjectLineRemove(String line) {
    return 'le plan (retirer « $line »)';
  }

  @override
  String get housingAmendmentSubjectRuleChange => 'les règles d\'entente';

  @override
  String get housingAmendmentValueNotSet => 'Non défini';

  @override
  String get housingAmendmentValueNone => 'Aucune';

  @override
  String get housingAmendmentValueRemoved => 'Retirée du plan';

  @override
  String get housingAmendmentUnknownLine => 'cette ligne';

  @override
  String get housingAmendmentRulesCurrentPlaceholder =>
      'Règles actuelles (résumé à venir)';

  @override
  String get housingAmendmentRulesProposedPlaceholder =>
      'Règles proposées (résumé à venir)';

  @override
  String get housingActiveHubPendingAmendment =>
      'Il y a une demande de changement';

  @override
  String get housingAmendmentDetailLoading => 'Chargement…';

  @override
  String get housingAmendmentAccept => 'Accepter';

  @override
  String get housingAmendmentReject => 'Refuser';

  @override
  String get housingAmendmentSubmitToGroup => 'Soumettre au groupe';

  @override
  String get housingAmendmentRulesContinue => 'Continuer';

  @override
  String get housingAmendmentRulesModifiedWhileDisabledBody =>
      'Vous avez modifié une règle sans l\'activer, êtes vous certain de ne rien avoir oublié?';

  @override
  String get housingAmendmentRulesModifiedWhileDisabledReview =>
      'Je veux vérifier';

  @override
  String get housingAmendmentRulesModifiedWhileDisabledContinue =>
      'Continuer tout de même';

  @override
  String get housingAgreementRuleStatusEnabled => 'Activé';

  @override
  String get housingAgreementRuleStatusDisabled => 'Désactivé';

  @override
  String get housingAmendmentPreviewTitle => 'Aperçu de la demande';

  @override
  String housingAmendmentPreviewIntro(String subject) {
    return 'Vérifiez le changement proposé pour $subject avant l\'envoi au groupe.';
  }

  @override
  String get housingAmendmentNoMeaningfulChange =>
      'Aucun changement par rapport au plan actuel.';

  @override
  String get housingAmendmentRequestStatusAction => 'Statut de la demande';

  @override
  String get housingAmendmentJournalTitle => 'Changements au plan';

  @override
  String get housingJournalsTitle => 'Journaux';

  @override
  String get housingAmendmentJournalSubtitle =>
      'Demandes acceptées et refusées';

  @override
  String get housingAmendmentJournalSubjectAgreementEnd =>
      'Date de fin d\'entente';

  @override
  String housingAmendmentJournalLineAdd(String title, String amount) {
    return 'Ajout d\'une dépense - $title - $amount';
  }

  @override
  String housingAmendmentJournalLineEdit(String title, String amount) {
    return 'Modification d\'une dépense - $title - $amount';
  }

  @override
  String housingAmendmentJournalLineRemove(String title, String amount) {
    return 'Retrait d\'une dépense - $title - $amount';
  }

  @override
  String get housingAmendmentJournalEmpty =>
      'Aucun changement au plan pour le moment.';

  @override
  String get housingAmendmentJournalAccepted => 'Acceptée';

  @override
  String get housingAmendmentJournalRefused => 'Refusée';

  @override
  String housingAmendmentJournalCardTitle(String subject, String status) {
    return '$subject — $status';
  }

  @override
  String housingAmendmentJournalCardSubtitle(String name, String date) {
    return 'Par $name · $date';
  }

  @override
  String get housingAmendmentRulesSummaryShort =>
      'Règles d\'entente mises à jour';

  @override
  String housingAmendmentRulesGroupAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Règles ajoutées ($count)',
      one: 'Règle ajoutée ($count)',
    );
    return '$_temp0';
  }

  @override
  String housingAmendmentRulesGroupModified(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Règles modifiées ($count)',
      one: 'Règle modifiée ($count)',
    );
    return '$_temp0';
  }

  @override
  String housingAmendmentRulesGroupRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Règles retirées ($count)',
      one: 'Règle retirée ($count)',
    );
    return '$_temp0';
  }

  @override
  String housingAmendmentRulesGroupUnchanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Règles inchangées ($count)',
      one: 'Règle inchangée ($count)',
    );
    return '$_temp0';
  }

  @override
  String get housingAmendmentRulesBeforeSubtitle => 'Auparavant';

  @override
  String get housingAmendmentRulesProposedSubtitle => 'Proposé';

  @override
  String get housingAmendmentRulesUnchangedDetailHint =>
      'Cette règle est inchangée dans la proposition.';

  @override
  String get housingAmendmentRejectTitle => 'Refuser la demande';

  @override
  String get housingAmendmentRejectMessageLabel => 'Message (facultatif)';

  @override
  String get housingAmendmentRejectConfirm => 'Refuser';

  @override
  String get housingAmendmentRefusalMessageLabel => 'Message de refus';

  @override
  String get housingActiveHubViewPendingAmendment => 'Changement demandé';

  @override
  String get housingInviteResponseWindowTitle => 'Délai de réponse';

  @override
  String get housingInviteResponseWindowBody =>
      'Les participants ont jusqu\'à cette date et heure pour répondre (UTC).';

  @override
  String get housingInvitePeriodOverlapTitle => 'Conflit de période d\'accord';

  @override
  String get housingInvitePeriodOverlapBody =>
      'Cet accord chevauche plus d\'un jour calendaire avec un autre plan logement où vous êtes participant. Modifiez les dates ou réglez l\'autre plan avant d\'envoyer.';

  @override
  String housingInvitePeriodOverlapDetail(String planTitle, String dateRange) {
    return 'Cet accord chevauche plus d\'un jour calendaire avec « $planTitle » ($dateRange). Modifiez les dates ou réglez ce plan avant d\'envoyer.';
  }

  @override
  String get housingPlanParticipantMustBeConnectedContact =>
      'Chaque co-participant doit être un contact connecté sur cet appareil avant l\'envoi de la proposition.';

  @override
  String get housingInviteResponseDeadlineTitle => 'Fin du délai de réponse :';

  @override
  String housingInviteResponseDeadlineInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Dans $count jours',
      one: 'Dans 1 jour',
    );
    return '$_temp0';
  }

  @override
  String get housingInviteResponseDeadlineToday => 'Aujourd\'hui';

  @override
  String deadlineRemainingInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Dans $count jours',
      one: 'Dans 1 jour',
    );
    return '$_temp0';
  }

  @override
  String get deadlineRemainingToday => 'Aujourd\'hui';

  @override
  String deadlineRemainingCountdown(String time) {
    return 'Dans $time';
  }

  @override
  String get deadlineRemainingExpired => 'Expiré';

  @override
  String housingInviteResponseDeadlineCountdown(String time) {
    return 'Dans $time';
  }

  @override
  String get housingInviteOfferClosedHint =>
      'Cette offre n\'accepte plus de réponses.';

  @override
  String housingInviteForkedFromLabel(String revisionId) {
    return 'Version dérivée d\'une proposition antérieure ($revisionId).';
  }

  @override
  String get housingArchiveExpiredTitle => 'Proposition expirée';

  @override
  String get settingsActivityLogTitle => 'Journal d\'évènements';

  @override
  String get settingsActivityLogSubtitle =>
      'Événements relais sur cet appareil';

  @override
  String get activityLogEmpty => 'Aucun événement ne correspond aux filtres.';

  @override
  String get activityLogNoEntries => 'Aucun événement dans le journal.';

  @override
  String get activityLogFiltersTitle => 'Filtres';

  @override
  String get activityLogFilterDatesLabel => 'Dates';

  @override
  String get activityLogFilterInitiatorLabel => 'Initiateur';

  @override
  String get activityLogFilterInitiatorAll => 'Tous';

  @override
  String get activityLogFilterInitiatorSelf => 'Moi';

  @override
  String get activityLogFilterInitiatorContact => 'Contact';

  @override
  String get activityLogFilterEmitterLabel => 'Émetteur';

  @override
  String get activityLogFilterEmitterAll => 'Tous';

  @override
  String get activityLogFilterEmitterSystem => 'Système';

  @override
  String get activityLogFilterFromLabel => 'Du (date)';

  @override
  String get activityLogFilterToLabel => 'Au (date)';

  @override
  String get activityLogApplyFilters => 'Appliquer les filtres';

  @override
  String get activityLogKindContactHandshakeReceived =>
      'Demande de connexion reçue';

  @override
  String get activityLogKindContactDisconnected => 'Contact déconnecté';

  @override
  String get activityLogKindContactDeleted => 'Contact supprimé';

  @override
  String get activityLogKindHousingProposalSent =>
      'Proposition logement envoyée';

  @override
  String get activityLogKindHousingProposalReceived =>
      'Proposition logement reçue';

  @override
  String get activityLogKindHousingProposalResponse =>
      'Réponse à une proposition logement';

  @override
  String get activityLogKindHousingProposalInvalidated =>
      'Proposition logement fermée';

  @override
  String get activityLogKindHousingProposalExpired =>
      'Proposition logement expirée';

  @override
  String get activityLogKindHousingProposalForkCreated =>
      'Version dérivée logement démarrée';

  @override
  String get activityLogKindHousingAgreementActivated =>
      'Entente de logement activée';

  @override
  String get activityLogKindHousingProposalAgreementExpired =>
      'Vote sur modification de plan abandonné (Entente terminée)';

  @override
  String get activityLogKindHousingParticipationChangeAgreementExpired =>
      'Vote sur éjection abandonné (Entente terminée)';

  @override
  String get activityLogKindVehicleSharingOfferSent =>
      'Offre de partage véhicule envoyée';

  @override
  String get activityLogKindVehicleSharingOfferReceived =>
      'Offre de partage véhicule reçue';

  @override
  String get activityLogKindVehicleSharingOfferResponse =>
      'Réponse à une offre de partage véhicule';

  @override
  String get activityLogKindVehicleSharingOfferExpired =>
      'Offre de partage véhicule expirée';

  @override
  String get activityLogKindVehicleUseSessionStartSent =>
      'Début de session de partage envoyé';

  @override
  String get activityLogKindVehicleUseSessionStartReceived =>
      'Début de session de partage reçu';

  @override
  String get activityLogKindVehicleUseSessionEndSent =>
      'Fin de session de partage envoyée';

  @override
  String get activityLogKindVehicleUseSessionEndReceived =>
      'Fin de session de partage reçue';

  @override
  String get housingInvitePlanActivating =>
      'Tous les participants ont accepté. Activation de l\'entente…';

  @override
  String get housingInviteProposalAppBarTitle => 'Proposition d\'invitation';

  @override
  String get housingInviteProposalIntroTitle =>
      'Voici la proposition qui sera envoyée à chacun de vos participants.';

  @override
  String get housingInviteProposalSentIntroTitle =>
      'Voici la proposition envoyée à chacun de vos participants.';

  @override
  String get housingInviteParticipantsSectionTitle => 'Participants';

  @override
  String get housingInviteExpensesSectionTitle => 'Dépenses et répartition';

  @override
  String get housingInviteRulesSectionTitle => 'Règles de l\'accord';

  @override
  String get housingInviteStatusAccepted => 'Accepté';

  @override
  String get housingInviteStatusPending => 'En attente';

  @override
  String get housingInviteStatusNegotiating => 'En négociation';

  @override
  String get housingInviteStatusRejected => 'Rejeté';

  @override
  String get housingInviteAcceptFull => 'J\'accepte en totalité';

  @override
  String get housingInviteMissingContactsAction => 'Contacts manquants';

  @override
  String housingInviteMissingContactsRedeemBanner(String name) {
    return 'Pour accepter ce plan, connectez-vous d\'abord avec $name. Saisissez son code d\'invitation ci-dessous.';
  }

  @override
  String get housingInviteMissingContactsBlocked =>
      'Connectez-vous avec chaque co-participant avant de pouvoir accepter.';

  @override
  String get housingPlanMissingContactsTitle => 'Contacts du plan';

  @override
  String get housingPlanMissingContactsIntro =>
      'Chaque co-participant doit être un contact connecté sur cet appareil avant que vous puissiez accepter le plan. Appuyez sur Établir le contact pour chaque personne qu\'il vous manque encore.';

  @override
  String get housingPlanMissingContactsEmpty =>
      'Ce plan n\'a pas d\'autre participant sur cet appareil.';

  @override
  String get housingPlanMissingContactsAllReady =>
      'Tous les co-participants sont connectés. Vous pouvez revenir en arrière et accepter le plan.';

  @override
  String get housingPlanMissingContactsEstablishContact => 'Établir le contact';

  @override
  String get housingPlanMissingContactsPendingOutbound =>
      'Demande envoyée — en attente de leur réponse.';

  @override
  String housingPlanMissingContactsRefusedAt(String when) {
    return 'Refusé $when';
  }

  @override
  String housingPlanMissingContactsInboundPrompt(String requester) {
    return '$requester souhaite établir le contact avec vous pour ce plan de logement.';
  }

  @override
  String get housingPlanMissingContactsAccept => 'Accepter';

  @override
  String get housingPlanMissingContactsRefuse => 'Refuser';

  @override
  String get housingInviteNegotiate => 'J\'aimerais négocier';

  @override
  String get housingInviteRejectBlock => 'Je refuse en bloc';

  @override
  String get housingInviteNegotiateMessageLabel =>
      'Message à envoyer avec la demande de négociation';

  @override
  String get housingInviteResponseSent => 'Réponse envoyée.';

  @override
  String get housingArchiveEntryTitle => 'Plans logement';

  @override
  String get housingArchiveEntryBody =>
      'Choisissez une proposition à consulter, modifiez une ébauche ou créez un nouveau plan.';

  @override
  String get housingArchiveNegotiatingTitle => 'Plan en négociation';

  @override
  String housingArchivePendingTitle(int count) {
    return 'Plan en attente de $count réponse(s)';
  }

  @override
  String get housingArchiveRejectedTitle => 'Plan rejeté';

  @override
  String get housingArchiveAmendmentRejectedTitle => 'Modification refusée';

  @override
  String get housingArchiveDraftTitle => 'Ébauche de plan';

  @override
  String housingArchiveDraftParticipantsTitle(int count) {
    return 'Plan de $count participants';
  }

  @override
  String get housingArchiveCreateDerivedAction => 'Créer une version dérivée';

  @override
  String get housingArchiveEditDraftAction => 'Modifier';

  @override
  String get housingArchiveViewAction => 'Consulter';

  @override
  String get housingArchiveCreateNewPlan => 'Créer un nouveau plan';

  @override
  String get housingArchiveForkPromptTitle => 'Votre réponse a été envoyée.';

  @override
  String get housingArchiveForkPromptBody =>
      'Voulez-vous créer une version dérivée de cette proposition maintenant afin d\'y apporter vos changements?';

  @override
  String get housingArchiveForkPromptLaterHint =>
      'Vous pouvez le faire plus tard à partir du menu principal.';

  @override
  String get housingArchiveForkLaterAction => 'Plus tard';

  @override
  String get housingArchiveForkPromptCreateAction => 'Créer';

  @override
  String get housingInviteProposalLockedHint =>
      'Un autre participant est en négociation ou a rejeté cette proposition. Les réponses sont suspendues jusqu\'à révision du plan.';

  @override
  String get housingInviteInvitationStatusAction => 'Statut des invitations';

  @override
  String get housingInviteStatusDialogTitle => 'Statut des invitations';

  @override
  String housingInviteStatusSentAtLabel(String when) {
    return 'Envoyé : $when';
  }

  @override
  String housingInviteStatusDeadlineLabel(String when) {
    return 'Fin du délai de réponse : $when';
  }

  @override
  String get housingInviteStatusDeadlineNotSet => 'Non défini';

  @override
  String get housingInviteStatusTableSectionTitle => 'Invités';

  @override
  String get housingInviteStatusTableInvitee => 'Invité';

  @override
  String get housingInviteStatusTableStatus => 'Statut';

  @override
  String get housingInviteStatusMessagesSectionTitle => 'Messages';

  @override
  String get housingInviteStatusNoPending =>
      'Aucune invitation en attente pour ce plan.';

  @override
  String housingInviteTransportSent(int sentCount) {
    return 'Proposition envoyée à $sentCount participant(s).';
  }

  @override
  String housingInviteTransportPartial(int sentCount, int failedCount) {
    return 'Proposition envoyée à $sentCount participant(s); $failedCount participant(s) n\'ont pas pu être joints.';
  }

  @override
  String get housingInviteTransportFailed =>
      'La proposition n\'a pu être livrée à aucun participant. Vous pouvez modifier le plan et réessayer.';

  @override
  String get housingInviteResendProposalAction => 'Renvoyer la proposition';

  @override
  String get housingInviteViewSentProposalAction =>
      'Voir la proposition envoyée';

  @override
  String get housingInviteReceivedWhileEditingSnack =>
      'Vous avez reçu une proposition de logement d\'un participant.';

  @override
  String get housingInviteReceivedOpenAction => 'Voir';

  @override
  String get pushNotificationHousingProposalTitle => 'Proposition de logement';

  @override
  String get pushNotificationHousingProposalBody =>
      'Ouvrez l\'application pour consulter la proposition.';

  @override
  String get pushNotificationVehicleSharingOfferTitle =>
      'Offre de partage de véhicule';

  @override
  String get pushNotificationVehicleSharingOfferBody =>
      'Ouvrez Partage de véhicule pour consulter l\'offre.';

  @override
  String pushNotificationVehicleSharingOfferBodyFrom(
    String name,
    String vehicle,
  ) {
    return '$name vous propose de partager $vehicle.';
  }

  @override
  String get pushNotificationVehicleSharingOfferAcceptTitle =>
      'Partage de véhicule accepté';

  @override
  String get pushNotificationVehicleSharingOfferAcceptBody =>
      'Ouvrez Partage de véhicule pour voir le partage actif.';

  @override
  String pushNotificationVehicleSharingOfferAcceptBodyFrom(
    String name,
    String vehicle,
  ) {
    return '$name a accepté de partager $vehicle.';
  }

  @override
  String get pushNotificationVehicleSessionGapTitle =>
      'Écart de kilométrage possible';

  @override
  String get pushNotificationVehicleSessionGapBody =>
      'Une session n\'a peut-être pas été terminée. Ouvrez les corrections en attente pour vérifier la lecture.';

  @override
  String pushNotificationVehicleSessionGapBodyFrom(
    String name,
    String vehicle,
  ) {
    return '$name a débuté une session sur $vehicle. Une session précédente est peut-être restée ouverte.';
  }

  @override
  String get pushNotificationVehicleMaintenanceTitle => 'Entretien enregistré';

  @override
  String get pushNotificationVehicleMaintenanceBody =>
      'Un emprunteur a enregistré un entretien sur un véhicule partagé.';

  @override
  String pushNotificationVehicleMaintenanceBodyFrom(
    String name,
    String vehicle,
  ) {
    return '$name a enregistré un entretien sur $vehicle.';
  }

  @override
  String get pushNotificationVehicleTrafficViolationTitle =>
      'Dommage ou infraction';

  @override
  String get pushNotificationVehicleTrafficViolationBody =>
      'Un emprunteur a enregistré un dommage ou une infraction sur un véhicule partagé.';

  @override
  String pushNotificationVehicleTrafficViolationBodyFrom(
    String name,
    String vehicle,
  ) {
    return '$name a enregistré un dommage ou une infraction sur $vehicle.';
  }

  @override
  String get pushNotificationUsageBalanceFreezeProposeTitle => 'Figer le solde';

  @override
  String pushNotificationUsageBalanceFreezeProposeBody(String name) {
    return '$name demande de figer le solde d\'utilisation.';
  }

  @override
  String get pushNotificationUsageBalanceFreezeAcceptedTitle => 'Solde figé';

  @override
  String pushNotificationUsageBalanceFreezeAcceptedBody(String name) {
    return '$name a accepté de figer le solde d\'utilisation.';
  }

  @override
  String get pushNotificationUsageBalanceFreezeRejectedTitle =>
      'Figeage refusé';

  @override
  String pushNotificationUsageBalanceFreezeRejectedBody(String name) {
    return '$name a refusé de figer le solde d\'utilisation.';
  }

  @override
  String get pushNotificationUsageBalanceTransferProposeTitle =>
      'Virement déclaré';

  @override
  String pushNotificationUsageBalanceTransferProposeBody(String name) {
    return '$name a déclaré un virement pour le solde d\'utilisation.';
  }

  @override
  String get pushNotificationUsageBalanceTransferAcceptedTitle =>
      'Virement accepté';

  @override
  String pushNotificationUsageBalanceTransferAcceptedBody(String name) {
    return '$name a confirmé la réception du virement.';
  }

  @override
  String get pushNotificationUsageBalanceTransferRejectedTitle =>
      'Virement refusé';

  @override
  String pushNotificationUsageBalanceTransferRejectedBody(String name) {
    return '$name a refusé la déclaration de virement.';
  }

  @override
  String get vehicleSharingOfferRelayFailed =>
      'Offre enregistrée ici, mais l\'envoi au contact a échoué. Réessayez plus tard.';

  @override
  String get vehicleSharingAcceptRelayFailed =>
      'Acceptation enregistrée ici, mais l\'envoi au propriétaire a échoué. Réessayez plus tard.';

  @override
  String get pushNotificationHousingAgreementActivatedTitle =>
      'Entente unanime';

  @override
  String get pushNotificationHousingAgreementActivatedBody =>
      'Votre groupe a conclu une entente de logement unanime.';

  @override
  String get pushNotificationHousingRealizedExpenseTitle => 'Dépense à réviser';

  @override
  String get pushNotificationHousingRealizedExpenseBody =>
      'Un participant a soumis une dépense pour votre entente.';

  @override
  String pushNotificationHousingRealizedExpenseBodyFrom(String name) {
    return '$name a soumis une dépense à réviser.';
  }

  @override
  String get pushNotificationHousingRealizedExpenseAcceptedTitle =>
      'Dépense acceptée';

  @override
  String get pushNotificationHousingRealizedExpenseAcceptedBody =>
      'Un participant a accepté votre dépense.';

  @override
  String pushNotificationHousingRealizedExpenseAcceptedBodyFrom(String name) {
    return '$name a accepté votre dépense.';
  }

  @override
  String pushNotificationHousingRealizedExpenseAcceptedBodyFromPeer(
    String name,
    String payer,
  ) {
    return '$name a accepté la dépense de $payer.';
  }

  @override
  String get pushNotificationHousingRealizedTransferAcceptedTitle =>
      'Virement accepté';

  @override
  String get pushNotificationHousingRealizedTransferAcceptedBody =>
      'Un participant a accepté votre virement.';

  @override
  String pushNotificationHousingRealizedTransferAcceptedBodyFrom(String name) {
    return '$name a accepté votre virement.';
  }

  @override
  String pushNotificationHousingRealizedTransferAcceptedBodyFromPeer(
    String name,
    String payer,
  ) {
    return '$name a accepté le virement de $payer.';
  }

  @override
  String get pushNotificationHousingRealizedExpenseRejectedTitle =>
      'Dépense refusée';

  @override
  String get pushNotificationHousingRealizedExpenseRejectedBody =>
      'Un participant a refusé votre dépense.';

  @override
  String pushNotificationHousingRealizedExpenseRejectedBodyFrom(String name) {
    return '$name a refusé votre dépense.';
  }

  @override
  String get pushNotificationHousingDecisionTitle =>
      'Réponse à une proposition de logement';

  @override
  String get pushNotificationHousingDecisionBody =>
      'Un participant a répondu à une proposition de logement.';

  @override
  String pushNotificationHousingDecisionBodyFrom(String name) {
    return '$name a répondu à une proposition de logement.';
  }

  @override
  String get pushNotificationHousingAmendmentDecisionTitle =>
      'Réponse à une demande de changement';

  @override
  String get pushNotificationHousingAmendmentDecisionBody =>
      'Un participant a répondu à une demande de changement de l\'entente.';

  @override
  String pushNotificationHousingAmendmentDecisionBodyFrom(String name) {
    return '$name a répondu à une demande de changement de l\'entente.';
  }

  @override
  String get pushNotificationHousingPaymentReminderBeforeDueTitle =>
      'Rappel de paiement';

  @override
  String pushNotificationHousingPaymentReminderBeforeDueBody(String lineTitle) {
    return 'L\'échéance de $lineTitle approche.';
  }

  @override
  String get pushNotificationHousingPaymentReminderOverdueTitle =>
      'Paiement en retard';

  @override
  String pushNotificationHousingPaymentReminderOverdueBody(String lineTitle) {
    return 'Le paiement de $lineTitle n\'a pas été complété pour cette période.';
  }

  @override
  String get pushNotificationContactInvitationBeforeExpiryTitle =>
      'Invitation bientôt expirée';

  @override
  String get pushNotificationContactInvitationBeforeExpiryBody =>
      'Une invitation en attente expirera bientôt.';

  @override
  String get pushNotificationContactInvitationExpiredTitle =>
      'Invitation expirée';

  @override
  String get pushNotificationContactInvitationExpiredBody =>
      'Une invitation n’a pas été utilisée et a expiré.';

  @override
  String get pushNotificationHousingProposalDeadlineTitle =>
      'Échéance de proposition proche';

  @override
  String get pushNotificationHousingProposalDeadlineBody =>
      'Une offre de plan logement expire bientôt. Ouvrez Logement pour répondre ou vérifier le statut.';

  @override
  String get notificationHousingPaymentRemindersLabel => 'Rappels de paiement';

  @override
  String housingOverdueJournalCardBody(String lineTitle) {
    return 'Le paiement de $lineTitle n\'a pas été complété pour cette période.';
  }

  @override
  String housingBeforeDueJournalCardBody(
    String dueDate,
    String lineTitle,
    String amount,
  ) {
    return 'Rappel de l\'échéance du $dueDate\n$lineTitle - $amount';
  }

  @override
  String housingDueDayJournalCardBody(String lineTitle, String amount) {
    return 'Rappel de l\'échéance d\'aujourd\'hui\n$lineTitle - $amount';
  }

  @override
  String get pushNotificationHousingResponseFailureRelayUnavailableBody =>
      'Le serveur de relai est temporairement indisponible.';

  @override
  String get pushNotificationHousingResponseFailureUnknownBody =>
      'La proposition à laquelle vous tentez de répondre n\'a pas été trouvée. Il y a plusieurs raisons possibles. Recontactez la personne directement.';

  @override
  String get pushNotificationHousingResponseFailureSendBody =>
      'Une erreur s\'est produite lors de l\'envoi de la réponse.';

  @override
  String get pushNotificationHousingResponseFailureLocalErrorBody =>
      'Une erreur inconnue s\'est produite.';

  @override
  String get pushNotificationContactAddRequestTitle => 'Demande de contact';

  @override
  String pushNotificationContactAddRequestBody(String name) {
    return '$name veut se connecter avec vous.';
  }

  @override
  String pushNotificationContactAddedViaInvitationBody(String name) {
    return '$name fait maintenant partie de vos contacts.';
  }

  @override
  String get pushNotificationContactDuplicateModuleAnchorRejectedBody =>
      'La personne avec qui vous avez tenté de vous connecter possède déjà votre contact. Vous devez restaurer vos données avant de pouvoir rétablir la connexion.';

  @override
  String get contactsDuplicateDialogOk => 'Ok';

  @override
  String get contactsDuplicateReadMore => 'Lire plus à ce sujet';

  @override
  String get contactsDuplicateAnchorHousingActive =>
      'un plan de logement actif';

  @override
  String get contactsDuplicateAnchorVehicleSharing => 'un partage de véhicule';

  @override
  String get contactsDuplicateAnchorHousingAndVehicle =>
      'Texte à déterminer pour le cas Véhicule ET Logement';

  @override
  String contactsDuplicateInviterRejectedIntro(String anchor) {
    return 'Le contact qui vient d\'utiliser un code d\'invitation était déjà présent dans vos contacts. Il s\'agit d\'un doublon. Le contact déjà existant est lié à $anchor.';
  }

  @override
  String get contactsDuplicateInviterNotAdded =>
      'Le contact n\'a PAS été ajouté.';

  @override
  String get contactsDuplicateInviterInformRestore =>
      'Informez la personne qu\'elle doit restaurer ses données de son coté afin de rétablir la connexion avec vous.';

  @override
  String get contactsDuplicateInviterMergedBody =>
      'Le contact qui vient d\'utiliser un code d\'invitation était déjà présent dans vos contacts. Ce contact a été associé au contact pré-existant.';

  @override
  String contactsDuplicateInviteeRejectedIntro(String anchor) {
    return 'La personne avec qui vous avez tenté de vous connecter possède déjà votre contact. Vous êtes lié à $anchor.';
  }

  @override
  String get contactsDuplicateInviteeMustRestore =>
      'Vous DEVEZ restaurer vos données. C\'est ce qui doit être fait pour correctement rétablir le contact.';

  @override
  String get contactsDuplicateInviteeRejectedBannerBody =>
      'Une re-connexion ne peut être établie de cette façon, car vous participez à un plan de partage.';

  @override
  String pushNotificationContactAddRequestAcceptedBody(String name) {
    return 'Votre demande de connexion avec $name a été acceptée.';
  }

  @override
  String pushNotificationContactAddRequestRejectedBody(String name) {
    return 'Votre demande de connexion avec $name a été refusée.';
  }

  @override
  String get pushNotificationContactAddRequestExpiredCodeBody =>
      'Le code de connexion que vous avez utilisé a expiré.';

  @override
  String get pushNotificationContactAddRequestInvalidCodeBody =>
      'Le code de connexion que vous avez utilisé n\'est pas valide.';

  @override
  String get pushNotificationContactAddRequestRelayErrorBody =>
      'Une erreur s\'est produite au niveau du serveur de relai. Ré-essayez.';

  @override
  String get pushNotificationContactAddRequestRelayUnavailableBody =>
      'Le serveur de relai est temporairement indisponible.';

  @override
  String get pushNotificationContactAddRequestUnknownFailureBody =>
      'Votre demande de connexion a échoué.';

  @override
  String pushNotificationPlanPeerEstablishmentRequestBody(
    String requester,
    String proposer,
  ) {
    return '$requester souhaite établir le contact avec vous, dans le cadre de la proposition de logement de $proposer.';
  }

  @override
  String get pushNotificationContactDisconnectionTitle => 'Contact déconnecté';

  @override
  String pushNotificationContactDisconnectionBody(String name) {
    return '$name s’est déconnecté de vous.';
  }

  @override
  String get housingInviteGenerateCodes => 'Générer les codes d\'invitation';

  @override
  String get housingInviteCodesDialogTitle => 'Codes d\'invitation';

  @override
  String get housingInviteCodesDialogBody =>
      'Chaque code est destiné à un co-participant. Partagez-les comme vous voulez ; l\'enregistrement sur le serveur relais sera ajouté ultérieurement.';

  @override
  String get housingInviteCodesCopyAll => 'Tout copier';

  @override
  String get housingInviteCodesCopied => 'Copié dans le presse-papiers';

  @override
  String get housingInviteRuleOffHint =>
      'Cette règle est désactivée pour cette proposition.';

  @override
  String get housingInviteWithdrawalPerParticipantIntro =>
      'Préavis et pénalité varient selon le participant (voir ci-dessous).';

  @override
  String get housingInviteHousingAgreementTitle => 'Entente de logement';

  @override
  String get housingInviteDateRangeSeparator => ' au ';

  @override
  String get housingInviteSunburstCenterLabel => 'Globalement';

  @override
  String housingInviteSunburstCenterParticipation(String pct) {
    return 'Participation globale $pct%';
  }

  @override
  String get housingInviteViewExpensesDetail => 'Voir les dépenses en détail';

  @override
  String get housingInviteExpensesDetailTitle => 'Dépenses en détail';

  @override
  String get housingInviteExpensesDetailSwipeHint =>
      'Glissez à gauche ou à droite pour parcourir chaque dépense.';

  @override
  String housingInviteExpensesDetailPageIndicator(int current, int total) {
    return '$current sur $total';
  }

  @override
  String get housingInviteExpensesDetailLoadError =>
      'Impossible de charger cette dépense.';

  @override
  String get housingInviteExpensesDetailPrevious => 'Dépense précédente';

  @override
  String get housingInviteExpensesDetailNext => 'Dépense suivante';

  @override
  String housingExpenseSunburstBudgetLabel(String name) {
    return '$name (budgétisé max)';
  }

  @override
  String get housingInviteSunburstEmptyHint =>
      'Aucune donnée de dépense à afficher pour ce plan.';

  @override
  String housingInviteSunburstLegendAgreementShare(String name, String pct) {
    return '$name - $pct % de l\'entente';
  }

  @override
  String get housingInviteSunburstMonthlyNormalizedFootnote =>
      'Montant mensualisé (équivalent sur 30 jours).';

  @override
  String housingInviteSunburstLegendYouParticipation(
    String participantName,
    String userAmount,
    String totalAmount,
    String pct,
  ) {
    return 'Part de $participantName : $userAmount/$totalAmount ($pct %)';
  }

  @override
  String get housingPlanSummaryDestroy => 'Supprimer le plan';

  @override
  String get housingPlanDestroyTitle => 'Supprimer le plan';

  @override
  String get housingPlanDestroyBody =>
      'Cela supprime sur cet appareil ce plan logement, les dépenses, les ratios, l’accord et les participants brouillon.';

  @override
  String get housingPlanDestroyConfirm => 'Supprimer';

  @override
  String get housingPlanRemovedSnackbar => 'Plan supprimé';

  @override
  String get housingPlanAddCategoryTitle => 'Ajouter une catégorie';

  @override
  String get housingPlanEditCategoryTitle => 'Modifier la catégorie';

  @override
  String get housingPlanCategoryNameLabel => 'Nom de la catégorie';

  @override
  String get housingPlanCategoryDescriptionLabel =>
      'Que doit contenir cette catégorie (optionnel)';

  @override
  String get housingPlanSave => 'Enregistrer';

  @override
  String get housingPlanAddExpenseTitle => 'Ajouter une dépense';

  @override
  String get housingPlanEditExpenseTitle => 'Modifier la dépense';

  @override
  String get housingPlanRecurringSwitch => 'Récurrent';

  @override
  String get housingPlanApproximateAmountSwitch => 'Montant approximatif';

  @override
  String get housingPlanExpenseTitleLabel => 'Titre';

  @override
  String get housingPlanCategoryOptionalLabel => 'Catégorie (optionnel)';

  @override
  String get housingPlanCategoryNone => 'Aucune';

  @override
  String get housingPlanExpenseDescriptionLabel => 'Description (optionnel)';

  @override
  String get housingPlanDayOfMonthLabel => 'Jour du mois';

  @override
  String get housingPlanMinLabel => 'Min';

  @override
  String get housingPlanMaxLabel => 'Max';

  @override
  String get housingPlanAmountLabel => 'Montant';

  @override
  String get housingExpenseNameLabel => 'Nom';

  @override
  String get housingExpenseAmountTypeLabel => 'Type de montant';

  @override
  String get housingExpenseAmountDetermined => 'Déterminé';

  @override
  String get housingExpenseAmountBudgetMax => 'Budgetté (max)';

  @override
  String get housingExpensePaymentResponsibleLabel => 'Responsable du paiement';

  @override
  String get housingExpensePaymentResponsibleAll => 'Tous';

  @override
  String get housingExpenseSplitSectionTitle => 'Répartition';

  @override
  String get housingExpenseEqualParts => 'À parts égales';

  @override
  String get housingExpenseLikeLabel => 'Comme pour';

  @override
  String get housingExpenseLikeBlankHint => '—';

  @override
  String get housingExpenseSplitAmountColumn => 'Montant';

  @override
  String get housingExpenseSplitParticipantColumn => 'Participant';

  @override
  String get housingExpenseSplitPercentColumn => 'Part';

  @override
  String get housingExpenseSplitCorrectRow => 'Corrigez!';

  @override
  String get housingExpenseRecurrenceTapToSet => 'Définir la récurrence';

  @override
  String get housingExpenseRecurrenceSet => 'Récurrence définie';

  @override
  String get housingExpenseRecurrenceConfirmTitle => 'Confirmer la récurrence';

  @override
  String housingExpenseRecurrenceMonthlyDay(int day, String anchor) {
    return 'Le $day de chaque mois, à partir du $anchor';
  }

  @override
  String get housingExpenseRecurrenceUseRange => 'Utiliser';

  @override
  String housingExpenseRecurrenceEveryNDays(int days, String anchor) {
    return 'À tous les $days jours, à partir du $anchor';
  }

  @override
  String housingExpenseRecurrenceNthWeekdayOfMonth(
    String ordinal,
    String weekday,
    String anchor,
  ) {
    return '$ordinal $weekday du mois, à partir du $anchor';
  }

  @override
  String get housingRecurrenceOrdinalFirst => 'Premier';

  @override
  String get housingRecurrenceOrdinalSecond => 'Deuxième';

  @override
  String get housingRecurrenceOrdinalThird => 'Troisième';

  @override
  String get housingRecurrenceOrdinalFourth => 'Quatrième';

  @override
  String get housingRecurrenceOrdinalFifth => 'Cinquième';

  @override
  String get housingRecurrenceWeekdayMonday => 'lundi';

  @override
  String get housingRecurrenceWeekdayTuesday => 'mardi';

  @override
  String get housingRecurrenceWeekdayWednesday => 'mercredi';

  @override
  String get housingRecurrenceWeekdayThursday => 'jeudi';

  @override
  String get housingRecurrenceWeekdayFriday => 'vendredi';

  @override
  String get housingRecurrenceWeekdaySaturday => 'samedi';

  @override
  String get housingRecurrenceWeekdaySunday => 'dimanche';

  @override
  String get housingExpenseEnterAmountForSplit =>
      'Entrez un montant pour cette dépense';

  @override
  String housingPlanDurationMonthsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mois',
      one: '1 mois',
    );
    return '$_temp0';
  }

  @override
  String housingPlanDurationDaysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours',
      one: '1 jour',
    );
    return '$_temp0';
  }

  @override
  String get carSharingPlanTitle => 'Plan partage de voiture';

  @override
  String get carSharingPlanFinish => 'Terminer';

  @override
  String carSharingOwnerPrompt(String name) {
    return '$name : indiquez s’il s’agit de votre véhicule ou d’une location.';
  }

  @override
  String get carSharingStepVehicle => 'Le véhicule';

  @override
  String get carSharingStepOwner => 'Le propriétaire';

  @override
  String get carSharingStepParticipants => 'Participants';

  @override
  String get carSharingStepInsurance => 'Assurances et immatriculations';

  @override
  String get carSharingStepCurrentState => 'État actuel';

  @override
  String get carSharingStepMaintenance => 'Entretiens à faire';

  @override
  String get carSharingStepAvailability => 'Disponibilités offertes';

  @override
  String get carSharingStepFuel => 'Gestion de l’essence';

  @override
  String get carSharingStepClauses => 'Autres clauses';

  @override
  String get carSharingFieldMake => 'Marque';

  @override
  String get carSharingFieldModel => 'Modèle';

  @override
  String get carSharingFieldColor => 'Couleur';

  @override
  String get carSharingFieldYear => 'Année';

  @override
  String get carSharingOwnerIsOwner => 'Véhicule en propriété';

  @override
  String get carSharingOwnerIsRental => 'Véhicule de location';

  @override
  String get carSharingRentalSharePermission =>
      'Droit de partage obtenu de la part du locateur';

  @override
  String get carSharingRentalContractCopy =>
      'Fournira une copie du contrat de location lors de l’acceptation de l’entente';

  @override
  String get carSharingInsuranceNotify =>
      'Informera les assureurs lors de l’acceptation de l’entente';

  @override
  String get carSharingInsuranceAssumeIncrease =>
      'Assumera l’éventuelle augmentation du prix d’assurance (si non et qu’il y a une augmentation, ce contrat est sujet à renégociation)';

  @override
  String get carSharingInsuranceProvideDocs =>
      'Fournira une copie des papiers d’assurance et d’immatriculation lors de l’acceptation de l’entente';

  @override
  String get carSharingEstimatedValueLabel => 'Valeur estimée';

  @override
  String get carSharingPhotoFront => 'Photo avant — chemin (optionnel)';

  @override
  String get carSharingPhotoLeft => 'Photo côté gauche — chemin (optionnel)';

  @override
  String get carSharingPhotoRight => 'Photo côté droit — chemin (optionnel)';

  @override
  String get carSharingPhotoRear => 'Photo arrière — chemin (optionnel)';

  @override
  String get carSharingPhotoSeatsFront =>
      'Photo sièges avant — chemin (optionnel)';

  @override
  String get carSharingPhotoSeatsRear =>
      'Photo sièges arrière — chemin (optionnel)';

  @override
  String get carSharingPhotoDashboard =>
      'Photo tableau de bord — chemin (optionnel)';

  @override
  String get carSharingPhotoOdometer =>
      'Photo kilométrage — chemin (optionnel)';

  @override
  String get carSharingMaintenanceIntro =>
      'Comme pour les dépenses du plan logement ; elles compteront dans la catégorie « entretien ».';

  @override
  String get carSharingMaintenanceAdd => 'Ajouter un entretien';

  @override
  String get carSharingMaintenanceEditTitle => 'Modifier l’entretien';

  @override
  String get carSharingMaintenanceEmpty =>
      'Aucun entretien prévu pour l’instant.';

  @override
  String get carSharingMaintenanceTitleLabel => 'Titre';

  @override
  String get carSharingMaintenanceAmountLabel => 'Montant';

  @override
  String get carSharingAvailabilityIntro =>
      'Comme la grille du couvre-feu : indiquez les plages où le véhicule est offert aux co-participants. Le reste du temps, il reste à l’usage du propriétaire.';

  @override
  String get carSharingAvailabilityAvailable => 'Offert aux co-participants';

  @override
  String get carSharingAvailabilityOwner => 'Usage propriétaire';

  @override
  String get carSharingFuelIntro =>
      'En mode suivi dans l’app, chaque achat enregistre : date/heure, coût total, volume de carburant, relevé d’odomètre, et s’il s’agit d’un plein. Les pleins servent d’ancrage pour la consommation entre ravitaillements. L’odomètre sert aussi à la distance par utilisation.';

  @override
  String get carSharingFuelUseAppTracking =>
      'Utiliser le suivi essence et odomètre de l’app';

  @override
  String get carSharingFuelCustomHint =>
      'Décrivez un autre mode (non géré par l’app)';

  @override
  String get carSharingClausesIntro =>
      'Clauses facultatives et suggestions. Les règles propres au logement (couvre-feu, retrait anticipé, immeuble) ne figurent pas ici.';

  @override
  String get contactsTitle => 'Contacts';

  @override
  String get contactsPickerTitle => 'Choisir un contact';

  @override
  String get contactsPickerEmptyTitle =>
      'Aucun contact sélectionnable pour l’instant';

  @override
  String get contactsPickerEmptyBody =>
      'Invitez des personnes et terminez la connexion dans Contacts d’abord. Seuls les contacts connectés peuvent rejoindre ce module.';

  @override
  String get contactsEmptyTitle => 'Aucun contact pour l’instant';

  @override
  String get contactsEmptyBody =>
      'Invitez quelqu’un et connectez-vous via le relais. Les contacts connectés sont réutilisables entre modules.';

  @override
  String get contactsAddContactAction => 'Inviter quelqu’un';

  @override
  String get contactsAddLocalOnlyAction => 'Ajouter un contact local';

  @override
  String get contactsAddLocalOnlyTitle => 'Nouveau contact';

  @override
  String get contactsEditTitle => 'Modifier le contact';

  @override
  String get contactsDetailTitle => 'Contact';

  @override
  String get contactsDetailMissing => 'Ce contact n’existe plus.';

  @override
  String get contactsInviteAction => 'Inviter un contact';

  @override
  String get contactsInviteTitle => 'Inviter un contact';

  @override
  String get contactsInviteIntroTitle => 'Partager un code à usage unique';

  @override
  String get contactsInviteIntroBody =>
      'Générez un code à usage unique et partagez-le en dehors de l’app (SMS, courriel, en personne). La personne qui reçoit le code peut s’ajouter à vos contacts tant que le code est valide.';

  @override
  String get contactsInviteValidityLabel => 'Code valide pour';

  @override
  String get contactsInviteGenerateAction => 'Générer le code';

  @override
  String get contactsInviteShareWarning =>
      'Partagez ce code avec une seule personne. Il expire automatiquement et ne fonctionne plus après usage ou révocation.';

  @override
  String get contactsInviteQrLabel =>
      'Scannez ce code QR depuis l’autre appareil, ou utilisez le code texte ci-dessous.';

  @override
  String get contactsInviteQrSemantics => 'Code QR d’invitation';

  @override
  String get contactsInviteShortCodeLabel => 'Code';

  @override
  String get contactsInviteCopyDeepLink => 'Copier le lien';

  @override
  String get contactsInviteCopyShareText => 'Copier l’invitation';

  @override
  String contactsInviteShareText(String link, String code) {
    return 'Vous êtes invité à vous connecter sur Bojairũ.\n\nCode à usage unique :\n$code\n\nPour l’utiliser : ouvrez l’app Bojairũ, allez dans Contacts, touchez l’icône scanner/saisir un code dans le haut de l’écran et collez ce code. Depuis l’appareil où l’app est installée vous pouvez aussi ouvrir : $link';
  }

  @override
  String contactsInviteExpiresAt(String when) {
    return 'Expire $when';
  }

  @override
  String get contactsInviteDeadlineTitle => 'Fin de validité du code :';

  @override
  String get contactsInvitationStubTitle => 'Code d\'invitation';

  @override
  String get contactsInviteRevokeAction => 'Révoquer';

  @override
  String get contactsInvitationsTitle => 'Codes d\'invitation';

  @override
  String get contactsInvitationsEmpty => 'Aucun code généré.';

  @override
  String contactsInvitationsItemTitle(String createdAt) {
    return 'Invitation · $createdAt';
  }

  @override
  String get contactsInvitationsStatusPending => 'En attente';

  @override
  String get contactsInvitationsStatusUsed => 'Utilisé';

  @override
  String get contactsInvitationsStatusExpired => 'Expiré';

  @override
  String get contactsInvitationsStatusRevoked => 'Révoqué';

  @override
  String get contactsEnterInviteCodeTitle => 'Saisir un code';

  @override
  String get contactsEnterInviteCodeIntro =>
      'Collez ou tapez le code reçu d’un contact.';

  @override
  String get contactsEnterInviteCodeFieldLabel => 'Code d’invitation';

  @override
  String get contactsEnterInviteCodeScanQr => 'Scanner le code QR';

  @override
  String get contactsEnterInviteCodeScanQrHint =>
      'Pointez la caméra vers un code QR d’invitation Bojairũ.';

  @override
  String get contactsEnterInviteCodeSubmit => 'Se connecter';

  @override
  String get contactsEnterInviteCodeValid => 'Le format du code est valide';

  @override
  String contactsEnterInviteCodeInvitationId(String id) {
    return 'Identifiant d’invitation : $id';
  }

  @override
  String get contactsHandshakeNotAvailableYet =>
      'La poignée de main du relais n’est pas encore disponible. Le code est valide localement, mais il ne peut pas être utilisé tant que le relais n’est pas en ligne.';

  @override
  String get contactsHandshakeDispatching => 'Envoi de la requête au relais…';

  @override
  String get contactsHandshakeDispatched =>
      'Code accepté. Établissement du contact…';

  @override
  String get contactsHandshakeCompleted =>
      'Connecté. Le contact a été ajouté à votre liste.';

  @override
  String get contactsHandshakeRejected =>
      'Votre interlocuteur a refusé la connexion. Demandez-lui une nouvelle invitation si besoin.';

  @override
  String get contactsHandshakeFailed =>
      'La tentative de connexion a échoué. Vous pouvez réessayer avec une nouvelle invitation.';

  @override
  String get contactsHandshakeErrorRelayUnavailable =>
      'Relais injoignable. Vérifiez votre connexion et réessayez.';

  @override
  String get contactsHandshakeErrorAlreadyCompleted =>
      'Ce code a déjà été utilisé.';

  @override
  String get contactsHandshakeErrorNonceConsumed =>
      'Cette invitation a déjà été honorée.';

  @override
  String get contactsHandshakeErrorExpired => 'Cette invitation a expiré.';

  @override
  String get contactsHandshakeErrorUnknown =>
      'Une erreur est survenue lors de la communication avec le relais.';

  @override
  String get contactsIncomingTitle => 'Demandes de connexion';

  @override
  String get contactsIncomingEmpty => 'Aucune demande de connexion en attente.';

  @override
  String contactsIncomingBody(String name) {
    return '$name souhaite se connecter.';
  }

  @override
  String get contactsIncomingAccept => 'Accepter';

  @override
  String get contactsIncomingReject => 'Refuser';

  @override
  String get contactsIncomingBannerOne => '1 nouvelle demande de connexion';

  @override
  String contactsIncomingBannerMany(int count) {
    return '$count nouvelles demandes de connexion';
  }

  @override
  String get contactsRefreshIncomingTooltip =>
      'Vérifier les demandes de connexion';

  @override
  String contactsRefreshIncomingFound(int count) {
    return '$count demande(s) de connexion en attente.';
  }

  @override
  String get contactsRefreshIncomingNone =>
      'Aucune demande de connexion en attente trouvée.';

  @override
  String contactsRefreshIncomingNoneWithActivePolls(int count) {
    return 'Aucune demande de connexion en attente trouvée. Poll(s) relais actif(s) : $count.';
  }

  @override
  String contactsRefreshIncomingDiagnostics(
    int activeCount,
    int totalCount,
    String latestState,
  ) {
    return 'Aucune demande de connexion en attente trouvée. Poll(s) relais actif(s) : $activeCount. Ligne(s) handshake locale(s) : $totalCount. Dernier état : $latestState.';
  }

  @override
  String get contactsCodeErrorEmpty => 'Saisissez un code pour continuer.';

  @override
  String get contactsCodeErrorTooShort => 'Ce code est trop court.';

  @override
  String get contactsCodeErrorTooLong => 'Ce code est trop long.';

  @override
  String get contactsCodeErrorInvalidCharacters =>
      'Ce code contient des caractères non autorisés.';

  @override
  String get contactsCodeErrorBadChecksum =>
      'Ce code semble mal recopié. Vérifiez les caractères et réessayez.';

  @override
  String get contactsCodeErrorUnsupportedVersion =>
      'Ce code a été créé par une version plus récente de l’app.';

  @override
  String get contactsKindLocalOnly => 'Local uniquement';

  @override
  String get contactsKindDisconnected => 'Déconnecté';

  @override
  String get contactsKindConnected => 'Connecté';

  @override
  String get contactsKindBlocked => 'Bloqué';

  @override
  String get contactsKindDeleted => 'Supprimé';

  @override
  String get contactsFieldNameLabel => 'Nom';

  @override
  String get contactsFieldNameHint =>
      'Tel que cette personne apparaît dans l’app';

  @override
  String get contactsFieldAvatarReadOnlyFootnote =>
      'Vous pouvez lui attribuer un autre nom.\n\nAttention! Le contact en sera informé dans:\n    Paramètres >\n        Profil >\n            Comment les autres vous nomment.';

  @override
  String get contactsFieldAvatarLabel => 'Avatar';

  @override
  String get contactsFieldNotesLabel => 'Notes';

  @override
  String get contactsFieldNotesHint => 'Rappel personnel, non partagé';

  @override
  String get contactsFieldNotesFootnote =>
      'Vos notes personnelles. Ne seront pas partagées.';

  @override
  String get contactsDeleteTitle => 'Supprimer ce contact ?';

  @override
  String get contactsDeleteBody =>
      'Les entrées existantes (logement ou véhicule) qui réfèrent à ce contact conserveront le nom et l\'avatar enregistrés au moment de leur création. Pour travailler à nouveau avec cette personne, créez un nouveau contact local ou envoyez-lui une nouvelle invitation.';

  @override
  String get contactsDeletePreservesHistory =>
      'Les entrées existantes qui réfèrent à ce contact conservent leur nom et avatar.';

  @override
  String get contactsDeleteBlockedByPlansTitle =>
      'Impossible de supprimer ce contact';

  @override
  String contactsDeleteBlockedByPlansBody(int count, String plans) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count plans',
      one: 'un plan',
    );
    return 'Ce contact est encore listé comme participant dans $_temp0 : $plans. Retirez-le d\'abord de ces plans, puis vous pourrez supprimer le contact.';
  }

  @override
  String get contactsDeleteBlockedConnectedTitle =>
      'Utilisez Se déconnecter d\'abord';

  @override
  String get contactsDeleteBlockedConnectedBody =>
      'Ce contact est actuellement connecté. Le supprimer sur cet appareil seulement laisserait l\'autre personne penser que la connexion est toujours active. Utilisez d\'abord « Se déconnecter » : un signal de déconnexion chiffré est envoyé au correspondant via le relais et le contact repasse en « local uniquement » sur cet appareil. Vous pourrez ensuite le supprimer normalement.';

  @override
  String get contactsDeleteBlockedConnectedAction => 'Se déconnecter d\'abord';

  @override
  String get contactsBlockTitle => 'Bloquer ce contact ?';

  @override
  String get contactsBlockBody =>
      'Les messages entrants de ce contact seront ignorés localement. Le relais n’est pas informé du blocage.';

  @override
  String get contactsUnblockTitle => 'Débloquer ce contact ?';

  @override
  String get contactsUnblockBody =>
      'Les messages entrants de ce contact seront à nouveau traités.';

  @override
  String get contactsDisconnectAction => 'Se déconnecter';

  @override
  String get contactsDisconnectTitle => 'Se déconnecter de ce contact ?';

  @override
  String get contactsDisconnectBody =>
      'Un avis de déconnexion sera envoyé au relais. Les deux côtés repasseront à des contacts locaux uniquement.';

  @override
  String get contactsDisconnectSent =>
      'Avis de déconnexion envoyé. Le contact est maintenant local uniquement.';

  @override
  String get contactsReconnectAction => 'Demander une reconnexion';

  @override
  String get contactsLabelEditorTitle => 'Renommer locallement';

  @override
  String get contactsLabelEditorScreenTitle => 'Renommer locallement?';

  @override
  String get contactsLabelEditorHint => 'Vide pour garder le nom original';

  @override
  String get contactsFieldTheirNameLabel => 'Son nom';

  @override
  String get settingsProfileIdentityTitle => 'Votre profil';

  @override
  String get settingsProfileIdentitySubtitle =>
      'Nom et avatar visibles par vos contacts';

  @override
  String get settingsProfileAppearancesTitle =>
      'Comment les autres vous nomment';

  @override
  String get settingsProfileAppearancesBody =>
      'Chaque contact connecté peut partager le nom qu\'il vous donne dans sa liste. Cela transite uniquement dans les mises à jour de profil chiffrées.';

  @override
  String get settingsProfileAppearancesColumnPeer => 'Contact';

  @override
  String get settingsProfileAppearancesColumnTheirLabel =>
      'Son libellé pour vous';

  @override
  String get settingsProfileAppearancesEmpty =>
      'Aucun contact connecté pour l\'instant. Associez-vous à quelqu\'un pour voir ici comment il vous nomme.';

  @override
  String get settingsProfileAppearancesNoSharedLabels =>
      'Aucun contact ne vous a encore communiqué un nom personnalisé dans sa liste.';

  @override
  String settingsProfileRenameBlockedBody(String plans) {
    return 'Vous participez à un vote logement ouvert sur cet appareil : $plans. Terminez ou réglez ce vote avant de changer votre nom affiché.';
  }

  @override
  String get peerNameConflictTitle => 'Le contact a changé de nom';

  @override
  String peerNameConflictBody(String label, String canonical) {
    return 'Vous affichez ce contact sous « $label ». Il utilise maintenant « $canonical » sur son appareil.';
  }

  @override
  String get peerNameConflictUseTheirs => 'Utiliser son nom';

  @override
  String get peerNameConflictKeepMine => 'Garder mon libellé';

  @override
  String get housingPastHubTitle => 'Entente passée';

  @override
  String get housingParticipationChangeIntroLine1 =>
      'Un changement de participant n\'est pas une simple modification de l\'entente en vigueur.';

  @override
  String get housingParticipationChangeIntroLine2 =>
      'Toutes ces options mènent à la terminaison du plan actuel pour celui ou ceux qui quittent.';

  @override
  String get housingParticipationChangeWithdrawalAction =>
      'Je veux me retirer de l\'entente';

  @override
  String get housingParticipationChangeEjectionAction =>
      'Je veux éjecter un participant';

  @override
  String get housingParticipationChangeInviteParticipantAction =>
      'Je veux inviter un participant';

  @override
  String get housingParticipationChangeInviteParticipantTitle =>
      'Inviter un participant';

  @override
  String get housingParticipationChangeInviteParticipantBody =>
      'Ajouter quelqu\'un à une entente active exige de terminer le plan actuel et d\'en négocier un nouveau avec le consentement de tous. Consultez la FAQ pour le pourquoi.';

  @override
  String get housingParticipationChangeInviteParticipantFaqLink =>
      'Consulter la FAQ';

  @override
  String get helpFaqTitle => 'Foire aux questions';

  @override
  String get helpFaqIntro =>
      'Réponses aux questions fréquentes sur le fonctionnement de Bojairũ';

  @override
  String get housingVoteRefusedByAgreementExpiration =>
      'Refusé par expiration de l\'entente';

  @override
  String get contactsDisconnectBlockedByPlansTitle =>
      'Impossible de déconnecter ce contact pour l\'instant';

  @override
  String contactsDisconnectBlockedByPlansBody(String plans) {
    return 'Ce contact fait partie d\'une entente active ou d\'un vote ouvert sur cet appareil : $plans. Terminez ou réglez cette activité avant de déconnecter.';
  }

  @override
  String get housingParticipationChangeConfirmAction => 'Oui';

  @override
  String get housingParticipationChangeWithdrawalConfirmTitle =>
      'Confirmer votre retrait ?';

  @override
  String housingParticipationChangeWithdrawalConfirmBody(String date) {
    return 'Date de départ prévue : $date. Les autres participants doivent accuser réception de l\'avis dans les cinq jours civils. Le départ prend effet à cette date une fois que tout le monde a accusé réception.';
  }

  @override
  String housingParticipationChangeWithdrawalPenaltyHint(String amount) {
    return 'Une pénalité de retrait anticipé de $amount s\'applique.';
  }

  @override
  String get housingEarlyWithdrawalPenaltyDescription =>
      'Pénalité de départ anticipé';

  @override
  String housingEarlyWithdrawalPenaltyOwedTo(String name) {
    return 'Ce montant est dû à $name.';
  }

  @override
  String get housingParticipationChangeEjectionConfirmTitle =>
      'Éjecter un participant ?';

  @override
  String get housingParticipationChangeEjectionConfirmBody =>
      'Les autres participants devront accepter. Le candidat sera retiré du groupe si la demande est acceptée à l\'unanimité.';

  @override
  String get housingParticipationChangeDetailTitle => 'Changement majeur';

  @override
  String housingParticipationChangeDetailWithdrawalBody(
    String name,
    String date,
  ) {
    return '$name se retire de l\'entente le $date.';
  }

  @override
  String housingParticipationChangeDetailEjectionBody(
    String initiator,
    String target,
  ) {
    return '$initiator demande d\'éjecter $target.';
  }

  @override
  String get housingParticipationChangeAccept => 'Accepter';

  @override
  String get housingParticipationChangeReject => 'Refuser';

  @override
  String get housingParticipationChangeAcknowledge => 'Accuser réception';

  @override
  String get housingParticipationChangeAcknowledgementStatusTitle =>
      'Accusés de réception';

  @override
  String housingParticipationChangeWithdrawalPeerNotice(
    String departureDate,
    String ackDeadline,
  ) {
    return 'Entrez les dépenses utiles avant le $departureDate. Vous pouvez accuser réception de cet avis jusqu\'au $ackDeadline.';
  }

  @override
  String get housingParticipationChangeEjectionCandidateNotice =>
      'Vous êtes la personne visée par cette demande d\'éjection. Les autres participants doivent voter ; vous ne pouvez pas accepter ni refuser ici.';

  @override
  String get housingParticipationChangeDecisionStatusTitle => 'Votes';

  @override
  String housingParticipationChangeDecisionPending(String name) {
    return '$name : en attente';
  }

  @override
  String housingParticipationChangeDecisionAccepted(String name) {
    return '$name : accepté';
  }

  @override
  String housingParticipationChangeDecisionRejected(String name) {
    return '$name : refusé';
  }

  @override
  String get housingParticipationChangePenaltyApplies =>
      'Une pénalité de retrait anticipé s\'appliquera.';

  @override
  String get housingParticipationChangePenaltyDoesNotApply =>
      'Aucune pénalité de retrait anticipé ne s\'appliquera.';

  @override
  String housingParticipationChangeBannerWithdrawal(String name) {
    return '$name se retire de l\'entente';
  }

  @override
  String housingParticipationChangeBannerEjection(
    String initiator,
    String target,
  ) {
    return '$initiator demande d\'éjecter $target.';
  }

  @override
  String get housingParticipationChangeEjectionHubSubtitle =>
      'Demande d\'éjection en cours...';

  @override
  String get pushNotificationHousingParticipationChangeTitle =>
      'Changement majeur';

  @override
  String get pushNotificationHousingParticipationChangeBody =>
      'Un co-participant a demandé un changement majeur.';

  @override
  String pushNotificationHousingParticipationChangeBodyFrom(String name) {
    return '$name a demandé un changement majeur.';
  }

  @override
  String get housingParticipationJournalSubjectWithdrawal =>
      'Retrait volontaire';

  @override
  String get housingParticipationJournalSubjectEjection =>
      'Éjection d\'un participant';

  @override
  String get housingParticipationJournalProposed => 'Proposé';

  @override
  String get housingParticipationJournalDecisionAccepted => 'Accepté';

  @override
  String get housingParticipationJournalDecisionRejected => 'Refusé';

  @override
  String get housingParticipationJournalEffective => 'Effectif';

  @override
  String get housingParticipationJournalAborted => 'Abandonné';

  @override
  String housingParticipationJournalSubjectLine(String kind, String event) {
    return '$kind — $event';
  }

  @override
  String get housingInactiveSettlementTitle =>
      'Régler avec un ancien participant';

  @override
  String get housingInactiveSettlementTileSubtitle =>
      'Enregistrer un transfert pour solder le solde';

  @override
  String housingInactiveSettlementParticipantLabel(String name) {
    return 'Ancien participant : $name';
  }

  @override
  String housingInactiveSettlementCurrentBalance(String amount) {
    return 'Solde actuel : $amount';
  }

  @override
  String get housingInactiveSettlementAmountLabel => 'Montant du transfert';

  @override
  String get housingInactiveSettlementAmountHint =>
      'Positif : vous leur payez. Négatif : ils vous paient.';

  @override
  String get housingInactiveSettlementSubmit =>
      'Publier le transfert de clôture';

  @override
  String get housingInactiveSettlementSuccess =>
      'Transfert de clôture enregistré.';

  @override
  String get housingInactiveSettlementTransferDescription =>
      'Règlement avec un ancien participant';

  @override
  String get housingInactiveSettlementErrorZero => 'Entrez un montant non nul.';

  @override
  String get housingInactiveSettlementErrorCannotCreateCredit =>
      'Ce transfert créerait un nouveau solde en leur faveur.';

  @override
  String get housingInactiveSettlementErrorExceedsDebt =>
      'Le montant dépasse ce qu\'ils doivent.';

  @override
  String get housingInactiveSettlementErrorCannotIncreaseDebt =>
      'Ce transfert augmenterait ce qu\'ils doivent.';

  @override
  String get housingInactiveSettlementErrorExceedsCredit =>
      'Le montant dépasse ce qui leur est dû.';

  @override
  String get vehicleLicensingRequired =>
      'Le module Véhicule nécessite un abonnement actif.';

  @override
  String get vehicleSharingLicensingRequired =>
      'Le partage de véhicule nécessite un abonnement actif.';

  @override
  String get vehicleQuickActionsTitle => 'Actions rapides';

  @override
  String get vehicleMyVehiclesTitle => 'Mes véhicules';

  @override
  String get vehicleMyVehiclesEmpty =>
      'Aucun véhicule. Appuyez sur + pour en ajouter un.';

  @override
  String get vehicleOwnedActiveLimitReached =>
      'Limite atteinte : 3 véhicules actifs maximum.';

  @override
  String vehicleDeactivatedLabel(String date) {
    return 'Désactivé $date';
  }

  @override
  String get vehicleDeactivateAction => 'Désactiver ce véhicule';

  @override
  String get vehicleDeactivateDialogTitle => 'Désactiver ce véhicule ?';

  @override
  String get vehicleDeactivateDialogBody =>
      'Cette action est définitive. Vous pourrez encore consulter l\'historique, mais plus rien ne pourra être saisi pour ce véhicule.';

  @override
  String get vehicleDeactivateConfirm => 'Désactiver';

  @override
  String get vehicleDeactivateBlockedOpenSession =>
      'Terminez d\'abord la session d\'utilisation en cours.';

  @override
  String get vehicleExportDataAction => 'Exporter les données';

  @override
  String get vehicleExportConfirmBody =>
      'Export de données factuelles du véhicule seulement.\n\nCas d\'utilisation: fournir les données à un autre utilisateur lors d\'un transfert de propriété.';

  @override
  String get vehicleExportConfirmExport => 'Exporter';

  @override
  String get vehicleExportSuccessTitle => 'Export terminé';

  @override
  String vehicleExportSuccessBody(String fileName) {
    return 'Fichier enregistré dans Documents/Bojairũ/\n$fileName';
  }

  @override
  String get vehicleExportFileDataOfSegment => 'Données-de';

  @override
  String get vehicleExportFailed => 'L\'exportation a échoué. Réessayez.';

  @override
  String get vehicleImportAction => 'Importer';

  @override
  String get vehicleImportConfirmBody =>
      'L\'importation des données d\'un véhicule qui ont été exportées par un autre utilisateur est possible ici.\n\nIl vous faut avoir obtenu le fichier d\'export et l\'avoir copié localement sur cet appareil.';

  @override
  String get vehicleImportConfirmImport => 'Importer';

  @override
  String get vehicleImportFailInvalid =>
      'Ce fichier n\'est pas un export véhicule valide.';

  @override
  String get vehicleImportFailCorrupt =>
      'L\'importation a échoué. Le fichier semble corrompu. Réessayez avec une autre copie.';

  @override
  String get vehicleImportFailOther => 'L\'importation a échoué. Réessayez.';

  @override
  String get vehicleSaleImportUndoAction => 'Défaire l\'importation';

  @override
  String vehicleSaleImportUndoConfirmBody(String label) {
    return 'Les données importées de « $label » seront définitivement supprimées.';
  }

  @override
  String get vehicleSaleImportConfirmActionBody =>
      'Cette action confirme l\'importation de ce véhicule. Vous ne pourrez plus défaire l\'importation.';

  @override
  String get vehicleSaleImportConfirmActionConfirm => 'Confirmer';

  @override
  String get vehicleAddVehicle => 'Ajouter un véhicule';

  @override
  String get vehicleAddFirst => 'Ajoutez d\'abord un véhicule.';

  @override
  String get vehicleFieldLabel => 'Nom affiché';

  @override
  String get vehicleFieldKind => 'Type de véhicule';

  @override
  String get vehicleFieldMake => 'Marque';

  @override
  String get vehicleFieldModel => 'Modèle';

  @override
  String get vehicleFieldColor => 'Couleur';

  @override
  String get vehicleFieldYear => 'Année';

  @override
  String get vehicleFieldInitialOdometer => 'Odomètre initial';

  @override
  String get vehicleFieldInitialHorometer => 'Horomètre initial';

  @override
  String get vehicleFieldLicensePlate => 'Immatriculation';

  @override
  String get vehicleFieldVin => 'Numéro d\'identification du véhicule (NIV)';

  @override
  String get vehicleFieldOptional => 'Optionnel';

  @override
  String get vehicleAddPhotosSection => 'Photos';

  @override
  String get vehicleAddPhotosOptionalHint =>
      'Archive visuelle de l\'état du véhicule (optionnel).';

  @override
  String get vehicleAddGalleryStart => 'Ajouter une galerie';

  @override
  String get vehicleAddPhotoGalleryStart => 'Ajouter une galerie de photos';

  @override
  String vehicleAddGalleryTitle(int index) {
    return 'Galerie $index';
  }

  @override
  String get vehicleAddGalleryEmpty => 'Aucune photo dans cette galerie.';

  @override
  String get vehicleAddGalleryDescription => 'Description';

  @override
  String get vehicleAddGalleryAddPhoto => 'Ajouter une photo';

  @override
  String get vehicleAddGalleryAddGallery => 'Ajouter une autre galerie';

  @override
  String get vehicleAddValidationLabelRequired =>
      'Le nom affiché est obligatoire.';

  @override
  String get vehicleAddValidationMakeRequired => 'La marque est obligatoire.';

  @override
  String get vehicleAddValidationModelRequired => 'Le modèle est obligatoire.';

  @override
  String get vehicleAddValidationColorRequired => 'La couleur est obligatoire.';

  @override
  String get vehicleAddValidationYearInvalid =>
      'L\'année doit comporter quatre chiffres valides.';

  @override
  String get vehicleAddValidationMeterRequired =>
      'La lecture initiale du compteur est obligatoire.';

  @override
  String get vehicleAddValidationFluidChangeFrequencyRequired =>
      'Les changements d\'huile sont obligatoires.';

  @override
  String get vehicleAddValidationRequiredFields =>
      'Complétez tous les champs obligatoires, y compris la photo de l\'odomètre.';

  @override
  String get vehicleOdometerPhotoLabel => 'Photo de l\'odomètre';

  @override
  String get vehicleEditDetailsTitle => 'Modifier les détails';

  @override
  String get vehicleJournalsTitle => 'Journaux';

  @override
  String get vehicleJournalSelectorLabel => 'Journal';

  @override
  String get vehicleFormVehicleLabel => 'Véhicule';

  @override
  String get vehicleJournalEmpty => 'Aucune entrée pour l\'instant.';

  @override
  String get vehicleLogRecordedAt => 'Enregistré le';

  @override
  String get vehicleLogReadingRole => 'Type de relevé';

  @override
  String vehicleLogReadingRoleSessionEnd(String userName) {
    return '$userName - Fin';
  }

  @override
  String vehicleLogReadingRoleSessionStart(String userName) {
    return '$userName - Début';
  }

  @override
  String get vehicleLogReadingRoleStandalone => 'Lecture ponctuelle';

  @override
  String get vehicleLogReadingRoleFuelPurchase => 'Achat de carburant';

  @override
  String get vehicleLogReadingRoleMaintenance => 'Entretien';

  @override
  String get vehicleLogReadingRoleCorrection => 'Correction';

  @override
  String vehicleLogReadingRoleCorrectionBy(String userName) {
    return 'Correction par $userName';
  }

  @override
  String vehicleLogReadingRoleCorrectionSessionStart(String userName) {
    return 'Correction par $userName en début de session';
  }

  @override
  String vehicleLogReadingRoleCorrectionStandalone(String userName) {
    return 'Correction par $userName lors d\'une lecture ponctuelle';
  }

  @override
  String get vehicleLogCorrectionJournalSubtitle =>
      'Correction d\'odomètre à vérifier';

  @override
  String get vehicleLogCorrectionLabel => 'Correction';

  @override
  String vehicleLogCorrectionMustBeAttributed(String gap) {
    return '$gap doivent être attribués';
  }

  @override
  String vehicleLogCorrectionGapMustBeAdded(String gap) {
    return '$gap doivent être ajoutés';
  }

  @override
  String vehicleLogCorrectionGapMustBeRemoved(String gap) {
    return '$gap doivent être retirés';
  }

  @override
  String get vehiclePendingCorrectionsTitle => 'Corrections en attente';

  @override
  String get vehicleBorrowerBalancesTitle => 'Soldes des emprunteurs';

  @override
  String get vehicleBorrowerBalancesEmpty =>
      'Aucun emprunteur accepté pour le moment.';

  @override
  String get vehicleUsageBalanceTitle => 'Solde d\'utilisation';

  @override
  String get vehicleUsageBalanceTileOwner => 'Soldes des emprunteurs';

  @override
  String get vehicleUsageBalanceTileBorrower => 'Solde d\'utilisation';

  @override
  String get vehicleUsageBalanceUnavailableConsumption =>
      'Le solde d\'utilisation n\'est pas disponible tant que la consommation du véhicule n\'a pas une estimation fiable.';

  @override
  String get vehicleUsageBalanceUnavailableFuelPrice =>
      'Le solde d\'utilisation n\'est pas disponible tant qu\'au moins un achat de carburant avec volume et prix n\'a pas été enregistré.';

  @override
  String get vehicleUsageBalanceNetLabel => 'Solde';

  @override
  String get vehicleUsageBalanceOwedToOwner => 'Montant dû au propriétaire';

  @override
  String get vehicleUsageBalanceCreditForBorrower =>
      'Crédit pour l\'emprunteur';

  @override
  String get vehicleUsageBalanceMyMileage => 'Mon kilométrage';

  @override
  String get vehicleUsageBalanceMyMileageMiles => 'Mon mileage';

  @override
  String get vehicleUsageBalanceEstimatedFuel => 'Carburant utilisé';

  @override
  String get vehicleUsageBalanceBorrowerFuel => 'Achats de carburant';

  @override
  String get vehicleUsageBalanceBorrowerMaintenance => 'Entretiens';

  @override
  String get vehicleUsageBalanceCompensation => 'Compensation d\'utilisation';

  @override
  String get vehicleUsageBalanceConsumption => 'Consommation moyenne (C)';

  @override
  String get vehicleUsageBalanceDistance => 'Distance attribuée (D)';

  @override
  String get vehicleUsageBalanceFuelPrice => 'Prix moyen du carburant (P)';

  @override
  String get vehicleUsageBalanceRatePerKm => 'Compensation par km (T)';

  @override
  String get vehicleUsageBalanceInformativeNote =>
      'Ce solde est informatif. L\'enregistrement d\'un paiement entre propriétaire et emprunteur sera une étape séparée (à venir).';

  @override
  String get vehicleUsageBalanceMileageSessionDatesBlurb =>
      'Selon les dates de fin de session d\'utilisation';

  @override
  String vehicleUsageBalanceCompensationDistanceBlurb(
    String distance,
    String unit,
  ) {
    return 'Distance parcourue : $distance $unit';
  }

  @override
  String vehicleUsageBalanceCompensationRateBlurb(String rate, String unit) {
    return 'Compensation d\'utilisation : $rate \$ / $unit';
  }

  @override
  String vehicleUsageBalanceFuelPriceBlurb(String price, String volumeUnit) {
    return 'Prix moyen du carburant : $price / $volumeUnit';
  }

  @override
  String vehicleUsageBalanceFuelConsumptionBlurb(
    String consumption,
    String volumeUnit,
    String distanceUnit,
  ) {
    return 'Consommation moyenne : $consumption $volumeUnit / 100 $distanceUnit';
  }

  @override
  String vehicleUsageBalanceFuelDistanceBlurb(String distance, String unit) {
    return 'Distance parcourue : $distance $unit';
  }

  @override
  String get vehicleUsageBalanceFuelPurchasesDeductedBlurb =>
      'La somme des achats de carburant que vous avez fait est déduite';

  @override
  String get vehicleUsageBalanceMaintenanceDeductedBlurb =>
      'La somme des entretiens que vous avez fait est déduite';

  @override
  String vehicleUsageBalanceDistanceAmount(String distance, String unit) {
    return '$distance $unit';
  }

  @override
  String get vehicleDistanceUnitKilometre => 'kilomètre';

  @override
  String get vehicleDistanceUnitMile => 'mile';

  @override
  String get vehicleUsageBalanceRevokedSuffix => ' (révoqué)';

  @override
  String get vehicleUsageBalanceFreezeButton => 'Figer ce solde';

  @override
  String get vehicleUsageBalanceTransferButton => 'Virement';

  @override
  String get vehicleUsageBalanceFreezeProposeBody =>
      'Une demande d\'accord pour figer ce solde sera envoyée.';

  @override
  String get vehicleUsageBalanceTransferProposeBody =>
      'Montant qui a été viré au propriétaire :';

  @override
  String get vehicleUsageBalanceTransferProposeBodyToBorrower =>
      'Montant qui a été viré à l\'emprunteur :';

  @override
  String get vehicleUsageBalanceFreezeConfirmTitle => 'Figer le solde ?';

  @override
  String vehicleUsageBalanceFreezeConfirmBody(
    String name,
    String amount,
    String when,
  ) {
    return '$name demande de figer de $amount.\n\n$when';
  }

  @override
  String get vehicleUsageBalanceTransferConfirmTitle =>
      'Confirmer la réception d\'un virement';

  @override
  String get vehicleUsageBalanceDecisionLater => 'Plus tard';

  @override
  String get vehicleUsageBalanceDecisionReject => 'Rejeter';

  @override
  String get vehicleUsageBalanceDecisionConfirm => 'Confirmer';

  @override
  String get vehicleUsageBalanceCancel => 'Annuler';

  @override
  String get vehicleUsageBalanceSubmit => 'Soumettre';

  @override
  String get vehicleUsageBalanceNotInCurrent =>
      'Non inclus dans le solde actuel';

  @override
  String get vehicleUsageBalanceCarriedForward => 'Solde reporté';

  @override
  String get vehicleUsageBalanceCarriedFreezeLabel => 'Solde';

  @override
  String get vehicleUsageBalanceCarriedTransferSent => 'Virement envoyé';

  @override
  String get vehicleUsageBalanceCarriedTransferReceived => 'Virement reçu';

  @override
  String get vehicleUsageBalancePendingDecision => 'Décision en attente';

  @override
  String vehicleUsageBalanceHistoricalTitle(String date) {
    return 'Solde du $date';
  }

  @override
  String get vehicleUsageBalanceBack => 'Retour';

  @override
  String get vehiclePendingCorrectionsEmpty => 'Aucune correction en attente.';

  @override
  String get vehiclePendingCorrectionDetailTitle => 'Correction d\'odomètre';

  @override
  String vehicleCorrectReadingButton(String date) {
    return 'Corriger l\'entrée du $date';
  }

  @override
  String get vehicleAddMissingSessionButton =>
      'Ajouter une session d\'utilisation';

  @override
  String get vehicleSplitSessionButton => 'Scinder la session';

  @override
  String get vehicleGapResolutionSubmit => 'Soumettre';

  @override
  String get vehicleLogReadingRoleCorrectionApplied => 'Correction appliquée';

  @override
  String vehicleLogCorrectionAppliedSummary(String km, String name) {
    return '$km ont été attribués à $name';
  }

  @override
  String vehicleLogCorrectionAppliedSplitSummary(String km) {
    return '$km ont été attribués (répartition)';
  }

  @override
  String vehicleLogReadingRoleCorrectionReplaces(String label) {
    return 'Correction — remplace $label';
  }

  @override
  String vehicleLogCorrectionAppliedDivergence(String gap) {
    return 'Écart constaté : $gap';
  }

  @override
  String get vehicleGapResolutionPreviousReading => 'Lecture précédente';

  @override
  String get vehicleGapResolutionTriggerReading => 'Lecture subséquente';

  @override
  String get vehicleGapResolutionValidationMonotonicity =>
      'Cette valeur créerait un écart avec une autre lecture.';

  @override
  String get vehicleGapResolutionValidationSegment =>
      'Les segments ne couvrent pas l\'écart correctement.';

  @override
  String get vehicleGapResolutionValidationDateOverlap =>
      'Les dates des segments se chevauchent.';

  @override
  String get vehicleGapResolutionAssignTo => 'Attribuer à';

  @override
  String get vehicleGapResolutionDates => 'Date(s)';

  @override
  String get vehicleGapResolutionStartMeter => 'Odomètre de départ';

  @override
  String get vehicleGapResolutionEndMeter => 'Odomètre de fin';

  @override
  String get vehicleLogMeterTitle => 'Journal — odomètre';

  @override
  String get vehicleLogMeterFuelTitle => 'Odomètre et carburant';

  @override
  String get vehicleLogSharingSessionsTitle => 'Sessions de partage';

  @override
  String get vehicleLogMeterDetailTitle => 'Détail du relevé';

  @override
  String get vehicleLogFuelTitle => 'Journal — carburant';

  @override
  String get vehicleLogFuelDetailTitle => 'Détail de l\'achat';

  @override
  String vehicleFuelPurchaseMadeBy(String name) {
    return 'Achat fait par: $name';
  }

  @override
  String get vehicleLogMaintenanceTitle => 'Entretien';

  @override
  String get vehicleLogMaintenanceDetailTitle => 'Détail de l\'entretien';

  @override
  String get vehicleLogViolationTitle => 'Dommages et infractions';

  @override
  String get vehicleLogViolationDetailTitle => 'Détail de l\'infraction';

  @override
  String get vehicleKindCar => 'Voiture';

  @override
  String get vehicleKindTruck => 'Camion';

  @override
  String get vehicleKindMotorcycle => 'Moto';

  @override
  String get vehicleKindBoat => 'Bateau';

  @override
  String get vehicleQuickActionOdometer => 'Lecture d\'odomètre';

  @override
  String get vehicleUseSessionStartAction =>
      'Commencer une session d\'utilisation';

  @override
  String get vehicleUseSessionEndAction =>
      'Terminer une session d\'utilisation';

  @override
  String vehicleUseSessionStartedOn(String dateTime) {
    return 'débutée le $dateTime';
  }

  @override
  String get vehicleQuickActionFuel => 'Achat de carburant';

  @override
  String get vehicleQuickActionMaintenance => 'Entretien';

  @override
  String get vehicleQuickActionViolation => 'Dommage ou infraction';

  @override
  String get vehicleOdometerLabel => 'Odomètre';

  @override
  String get vehicleHorometerLabel => 'Horomètre';

  @override
  String get vehicleMeterPhotoRequired =>
      'Une photo du compteur est obligatoire.';

  @override
  String get vehicleMeterPhotoAdd => 'Ajouter une photo';

  @override
  String get vehicleMeterPhotoAttached => 'Photo jointe';

  @override
  String get vehicleMeterKnownUnchangedNoPhotoOdometer =>
      'Odomètre connu inchangé. Photo non saisie.';

  @override
  String get vehicleMeterKnownUnchangedNoPhotoHorometer =>
      'Horomètre connu inchangé. Photo non saisie.';

  @override
  String get vehicleMeterPhotoCamera => 'Appareil photo';

  @override
  String get vehicleMeterPhotoGallery => 'Galerie';

  @override
  String get vehicleUseSessionStart => 'Début d\'utilisation';

  @override
  String get vehicleUseSessionEnd => 'Fin d\'utilisation';

  @override
  String get vehicleUseSessionStarted =>
      'Session démarrée. Terminez-la à la fin du trajet.';

  @override
  String get vehicleUseSessionEnded => 'Session terminée.';

  @override
  String get vehicleConsumptionTitle => 'Consommation';

  @override
  String get vehicleConsumptionInsufficient =>
      'Données insuffisantes pour la consommation';

  @override
  String vehicleConsumptionPer100Km(
    String value,
    String volumeUnit,
    String distanceUnit,
  ) {
    return '$value $volumeUnit/100 $distanceUnit';
  }

  @override
  String vehicleConsumptionPerHour(String value, String volumeUnit) {
    return '$value $volumeUnit/h';
  }

  @override
  String get vehicleDrivingConditionColumn => 'Condition';

  @override
  String get vehicleDrivingConditionProportionColumn =>
      'Proportion (du kilométrage parcouru)';

  @override
  String get vehicleDrivingConditionRoute => 'Route';

  @override
  String get vehicleDrivingConditionCity => 'Ville';

  @override
  String get vehicleDrivingConditionTraffic => 'Traffic';

  @override
  String get vehicleConsumptionReliabilityNone =>
      'Il n\'y a pas suffisamment de données pour calculer la consommation d\'essence.';

  @override
  String get vehicleConsumptionReliabilityPreliminary =>
      'Cette estimation est préliminaire. Elle se précisera avec plus de données.';

  @override
  String get vehicleConsumptionReliabilityReliable =>
      'Cette estimation est fiable, selon la formule de calcul utilisée et les données que vous avez entrées.';

  @override
  String get vehicleConsumptionReliabilityVeryReliable =>
      'Cette estimation est très fiable car elle repose sur beaucoup de données que vous avez entrées.';

  @override
  String get vehicleConsumptionEstimationModeTitle =>
      'Mode d\'estimation de la consommation d\'essence';

  @override
  String get vehicleConsumptionEstimationModeSimpleTitle => 'Simple';

  @override
  String vehicleConsumptionEstimationModeSimpleDescription(
    String volumeUnitWord,
    String distanceUnit,
  ) {
    return 'Seulement le nombre de $volumeUnitWord par 100 $distanceUnit';
  }

  @override
  String get vehicleConsumptionEstimationModeDetailedTitle => 'Détaillée';

  @override
  String vehicleConsumptionEstimationModeDetailedDescription(
    String volumeUnitWordCap,
    String distanceUnit,
  ) {
    return '$volumeUnitWordCap par 100 $distanceUnit pour la conduite sur route / en ville / dans le traffic';
  }

  @override
  String get vehicleDistanceUnitKilometres => 'kilomètres';

  @override
  String get vehicleDistanceUnitMiles => 'miles';

  @override
  String get vehicleLiquidVolumeUnitLitres => 'litres';

  @override
  String get vehicleLiquidVolumeUnitUsGallons => 'gallons US';

  @override
  String get vehicleLiquidVolumeUnitImperialGallons => 'gallons impériaux';

  @override
  String get vehicleLiquidVolumeUnitLitresCap => 'Litres';

  @override
  String get vehicleLiquidVolumeUnitUsGallonsCap => 'Gallons US';

  @override
  String get vehicleLiquidVolumeUnitImperialGallonsCap => 'Gallons impériaux';

  @override
  String get vehicleConsumptionRequireDetailedForBorrowers =>
      'Imposer aux emprunteurs la saisie des pourcentages route / ville / trafic';

  @override
  String vehicleConsumptionSimpleEstimate(
    String value,
    String volumeUnit,
    String distanceUnit,
  ) {
    return 'Consommation : $value $volumeUnit/100 $distanceUnit';
  }

  @override
  String get vehicleConsumptionInsufficientDetailedData =>
      'Il n\'y a pas assez de données pour produire l\'estimation détaillée (route / ville / trafic). L\'estimation simple ci-dessous est affichée en attendant davantage de sessions détaillées.';

  @override
  String get vehicleConsumptionCarriedFromDetailedMode =>
      'Cette estimation provient de votre ancien mode détaillé. Elle se précisera avec de nouvelles périodes entre pleins en mode simple.';

  @override
  String get vehicleStatisticsConsumptionHistoryTitle =>
      'Historique des estimations fiables';

  @override
  String vehicleConsumptionHistoryBlended(
    String date,
    String value,
    String volumeUnit,
    String distanceUnit,
  ) {
    return '$date : $value $volumeUnit/100 $distanceUnit';
  }

  @override
  String get vehicleSessionEndTankConfirmTitle =>
      'Confirmer l\'état du réservoir';

  @override
  String vehicleSessionEndTankConfirmBody(String distance, int percent) {
    return 'Vous avez déclaré le réservoir à $percent % plein après $distance depuis le dernier achat d\'essence. Veuillez confirmer que c\'est exact.';
  }

  @override
  String get vehicleSessionEndTankConfirmReview => 'Revoir la saisie';

  @override
  String get vehicleSessionEndTankConfirmProceed => 'Confirmer';

  @override
  String get vehicleStatisticsTitle => 'Statistiques';

  @override
  String get vehicleStatisticsMileageTitle => 'Mon kilométrage';

  @override
  String get vehicleStatisticsExpensesTitle => 'Mes dépenses';

  @override
  String get vehicleExpenseFuel => 'Carburant';

  @override
  String get vehicleExpenseMaintenance => 'Entretien';

  @override
  String get vehicleExpenseViolations => 'Infractions';

  @override
  String get vehicleFuelCost => 'Coût total';

  @override
  String get vehicleFuelVolume => 'Volume';

  @override
  String get vehicleFuelMeter => 'Odomètre';

  @override
  String get vehicleFuelFullTank => 'Réservoir plein';

  @override
  String get vehicleFuelTankState => 'État du réservoir';

  @override
  String get vehicleFuelApproximateLevel => 'Approximativement :';

  @override
  String get vehicleFieldFuelTankCapacity => 'Capacité du réservoir d\'essence';

  @override
  String get vehicleFieldFluidChangeFrequency => 'Changements d\'huile';

  @override
  String get vehicleOilChangeIntervalRequired =>
      'Saisissez un intervalle de changement d\'huile.';

  @override
  String get vehicleOilChangeIntervalInvalid => 'Valeur numérique invalide.';

  @override
  String get vehicleOilChangeIntervalLandMin =>
      'Minimum : 1 (1 000 km ou miles).';

  @override
  String get vehicleOilChangeIntervalLandMax =>
      'Maximum : 20 (20 000 km ou miles).';

  @override
  String get vehicleOilChangeIntervalBoatMin => 'Minimum : 50 h.';

  @override
  String get vehicleOilChangeIntervalBoatMax => 'Maximum : 500 h.';

  @override
  String get vehicleDetailEarlierPhotos => 'Photos antérieures';

  @override
  String vehicleFuelTankInTank(String volume) {
    return '$volume dans le réservoir';
  }

  @override
  String get vehicleFuelTankInfoTooltip =>
      'À propos de l\'estimation du réservoir';

  @override
  String get vehicleMaintenanceCategory => 'Catégorie';

  @override
  String get vehicleMaintenanceCategoryOil => 'Huile';

  @override
  String get vehicleMaintenanceCategoryOtherFluids => 'Autres fluides';

  @override
  String get vehicleMaintenanceCategoryTires => 'Pneus';

  @override
  String get vehicleMaintenanceCategoryBrakes => 'Freins';

  @override
  String get vehicleMaintenanceCategoryLights => 'Phares';

  @override
  String get vehicleMaintenanceCategoryCleaning => 'Nettoyage';

  @override
  String get vehicleMaintenanceCategoryOther => 'Autre';

  @override
  String get vehicleMaintenanceCost => 'Coût';

  @override
  String get vehicleMaintenanceNotes => 'Notes';

  @override
  String get vehicleViolationType => 'Type d\'infraction';

  @override
  String get vehicleViolationAmount => 'Montant';

  @override
  String vehicleMaintenanceAlertTile(String category, String remaining) {
    return '$category : $remaining restants';
  }

  @override
  String get vehicleGapAttributionTitle => 'Usage non enregistré';

  @override
  String vehicleGapAttributionPrompt(String gap) {
    return 'À qui le différentiel de $gap est-il attribuable ?';
  }

  @override
  String get vehicleGapAttributionUnknown => 'Je ne sais pas';

  @override
  String get vehicleGapAttributionSelf => 'Moi';

  @override
  String get vehicleGapOwnerNotified => 'Le propriétaire sera notifié.';

  @override
  String vehiclePositiveGapConfirmPrompt(String gap) {
    return 'Il s\'agit d\'un différentiel de $gap. Êtes-vous certain?';
  }

  @override
  String get vehiclePositiveGapConfirmNo => 'Non';

  @override
  String get vehiclePositiveGapConfirmYes => 'Oui';

  @override
  String get vehicleNegativeGapTitle => 'Relevé en baisse';

  @override
  String vehicleNegativeGapBody(String gap) {
    return 'Le nouveau relevé est inférieur de $gap au dernier relevé enregistré.';
  }

  @override
  String get vehicleNegativeGapMaintain =>
      'Conserver le relevé, vérifier plus tard';

  @override
  String get vehicleNegativeGapCancel => 'Annuler la saisie';

  @override
  String get vehicleBorrowerMeterRecheckTitle => 'Vérifie ce chiffre';

  @override
  String vehicleBorrowerMeterRecheckBody(String gap) {
    return 'Le nouveau relevé est inférieur de $gap au dernier relevé connu. Vérifie le chiffre avant de continuer.';
  }

  @override
  String get vehicleBorrowerMeterRecheckConfirm => 'Je confirme';

  @override
  String get vehicleBorrowerMeterRecheckCorrect => 'Je corrige';

  @override
  String get vehicleSuspiciousGapTitle => 'Différentiel inhabituellement élevé';

  @override
  String vehicleSuspiciousGapBody(String gap, String maxGap) {
    return 'Le différentiel de $gap dépasse ce qui est plausible avec un plein ($maxGap). Ce relevé est peut-être erroné.';
  }

  @override
  String get vehicleSuspiciousGapConfirm => 'Utiliser ce relevé quand même';

  @override
  String get vehicleSuspiciousGapCancel => 'Revoir la saisie';

  @override
  String get vehicleRoleOwner => 'Propriétaire';

  @override
  String get vehicleRoleBorrower => 'Emprunteur';

  @override
  String get vehicleSharingShareableTitle => 'Véhicule partageable';

  @override
  String get vehicleSharingShareableTitlePlural => 'Véhicules partageables';

  @override
  String get vehicleSharingAccessibleTitle => 'Véhicule accessible';

  @override
  String get vehicleSharingAccessibleTitlePlural => 'Véhicules accessibles';

  @override
  String get vehicleSharingPendingOfferTitle => 'Offre en attente';

  @override
  String get vehicleSharingPendingOfferTitlePlural => 'Offres en attente';

  @override
  String get vehicleSharingEmptyNone => 'Aucun';

  @override
  String get vehicleSharingEmptyNoneFeminine => 'Aucune';

  @override
  String get vehicleSharingSharesDetailTitle => 'Partages';

  @override
  String get vehicleSharingAddShare => 'Ajouter un partage';

  @override
  String get vehicleSharingNewShareTitle => 'Nouveau partage';

  @override
  String vehicleSharingInviteForContact(String name) {
    return 'Invitation pour $name';
  }

  @override
  String vehicleSharingInviteRateLabel(String unit) {
    return 'Sous par $unit d\'utilisation (optionnel)';
  }

  @override
  String get vehicleSharingInviteRateHelper => 'Compense l\'usure normale.';

  @override
  String get vehicleSharingInviteRateInvalid =>
      'Indiquez un nombre entier de sous (≥ 0).';

  @override
  String vehicleSharingInviteRatePer100Distance(String amount, String unit) {
    return '$amount pour 100 $unit';
  }

  @override
  String get vehicleSharingInviteAvailabilitySection =>
      'Période de disponibilité (optionnel)';

  @override
  String get vehicleSharingAvailabilityLevelPrimary => 'Disponible';

  @override
  String get vehicleSharingInviteAvailabilitySaveFirst =>
      'Enregistrez ou annulez la période de disponibilité avant d\'envoyer.';

  @override
  String get vehicleSharingInviteRulesLabel => 'Autres règles';

  @override
  String get vehicleSharingInviteSend => 'Envoyer l\'invitation';

  @override
  String vehicleSharingInviteDisclaimerBody1(String unit) {
    return 'Seul le montant par $unit sera suivi par l\'application.';
  }

  @override
  String get vehicleSharingInviteDisclaimerBody2 =>
      'La disponibilité et les autres règles ne sont qu\'à titre indicatif pour votre emprunteur.';

  @override
  String get vehicleSharingInviteDisclaimerDoNotShow => 'Ne plus afficher';

  @override
  String get vehicleSharingAccept => 'Accepter';

  @override
  String get vehicleSharingOffer => 'Proposer le partage';

  @override
  String get vehicleSharingOfferPickContact => 'Choisir un contact connecté';

  @override
  String get vehicleSharingNoContacts =>
      'Ajoutez d\'abord un contact connecté.';

  @override
  String get vehicleSharingOfferSent => 'Offre envoyée.';

  @override
  String get vehicleSharingOfferDeadlineTitle => 'Délai de réponse';

  @override
  String get vehicleSharingOfferDeadlineBody =>
      'L\'emprunteur a jusqu\'à cette durée pour accepter l\'invitation.';

  @override
  String vehicleSharingInvitationSentToAt(String name, String when) {
    return 'Invitation envoyée à $name le $when';
  }

  @override
  String get vehicleSharingOfferBlocked =>
      'Le partage nécessite les abonnements Véhicule et Partage de véhicule.';

  @override
  String get vehicleSharingForwarded =>
      'Enregistré sur le véhicule du propriétaire.';

  @override
  String vehicleSharingBorrowerLabel(String name) {
    return 'Emprunteur : $name';
  }

  @override
  String vehicleSharingOwnerLabel(String name) {
    return 'Propriétaire : $name';
  }

  @override
  String get vehicleSharingSessionStartAction => 'Débuter une session';

  @override
  String get vehicleSharingSessionEndAction => 'Terminer une session';

  @override
  String get vehicleSharingOtherActions => 'Autres actions';

  @override
  String get vehicleSharingOtherActionsTitle => 'Autres actions';

  @override
  String get vehicleSharingSessionRelayFailed =>
      'Session enregistrée ici, mais l\'envoi au propriétaire a échoué. Réessayez plus tard.';

  @override
  String get vehicleSharingFuelRelayFailed =>
      'Achat enregistré ici, mais l\'envoi au propriétaire a échoué. Réessayez plus tard.';

  @override
  String get vehicleSharingForwardRelayFailed =>
      'Enregistré ici, mais l\'envoi au propriétaire a échoué. Réessayez plus tard.';

  @override
  String get vehicleUsageBlockedOwnOnBorrowerPath =>
      'Ce véhicule est le vôtre. Utilisez le module Véhicule pour enregistrer votre usage — pas Partage de véhicule.';

  @override
  String get vehicleUsageBlockedNotOwnedOnOwnerPath =>
      'Ce véhicule n\'est pas dans vos véhicules possédés. Utilisez Partage de véhicule pour un véhicule partagé avec vous.';

  @override
  String get vehicleUsageBlockedMissingBorrowerIdentity =>
      'Identité emprunteur manquante pour ce formulaire.';

  @override
  String get vehicleUsageBlockedVehicleNotFound => 'Véhicule introuvable.';

  @override
  String get commonOk => 'Ok';

  @override
  String get sandboxRibbonLabel => 'Mode simulation';

  @override
  String get sandboxModeButton => 'Mode simulation';

  @override
  String get sandboxEnterDialogBody =>
      'Il est possible de simuler un plan avec de faux participants. Ceci vous permettra d\'avoir un excellent aperçu de l\'application.\n\nPour utiliser la « vraie » application, vous devez retourner en mode réel. Pour le faire, touchez le bandeau rouge au haut de l\'application. Il y aura un rappel dans 8 heures.';

  @override
  String get sandboxEnterConfirm => 'Simuler';

  @override
  String get sandboxEnterRestartMessage =>
      'L\'application va se fermer maintenant. Rouvrez-là de nouveau pour continuer.';

  @override
  String get sandboxHomeWelcomeBody =>
      'Les modules de véhicule ne peuvent être simulés.\n\nCommencez par explorer le module Contacts. Le processus d\'ajout de contact est simplifié pour cette simulation. Vous pouvez renommer ces faux contacts.\n\n';

  @override
  String get sandboxExitDialogTitle => 'Sortir du mode simulation?';

  @override
  String get sandboxRestartRequiredMessage =>
      'Fermez complètement l\'application, puis rouvrez-la pour continuer.';

  @override
  String get sandboxBotsExhausted => 'Vous avez invité tous les bots.';

  @override
  String get sandboxInvitingBot => 'Invitation du participant simulé…';

  @override
  String get sandboxBotExpenseTitle => 'Simuler une dépense d\'un Bot';

  @override
  String get sandboxBotExpenseSubtitle => 'Mode simulation';

  @override
  String get sandboxBotExpenseDescription => 'Dépense simulée';

  @override
  String get sandboxEightHourNudgeTitle => 'Mode simulation';

  @override
  String get sandboxEightHourNudgeBody =>
      'Vous êtes en mode simulation depuis 8 heures. Envisagez de revenir en mode réel pour ne pas manquer une invitation d\'un partenaire.';

  @override
  String get sandboxPortabilityBlocked =>
      'Export et import sont indisponibles en mode simulation.';

  @override
  String get sandboxEnterFailed =>
      'Impossible d\'entrer en mode simulation (vérification du point de reprise).';

  @override
  String get sandboxModuleDisabled =>
      'Ce module n\'est pas disponible en mode simulation.';
}
