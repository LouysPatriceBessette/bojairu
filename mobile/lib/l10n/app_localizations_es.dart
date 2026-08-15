// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Bojairũ';

  @override
  String get commonContinue => 'Continuar';

  @override
  String get commonFinishSetup => 'Finalizar configuración';

  @override
  String get commonRetry => 'Reintentar';

  @override
  String get commonRestart => 'Reiniciar';

  @override
  String get commonComingSoon => 'Próximamente';

  @override
  String get commonNotSet => 'No configurado';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonSave => 'Guardar';

  @override
  String get commonSend => 'Enviar';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get commonYes => 'Sí';

  @override
  String get commonNo => 'No';

  @override
  String get commonEdit => 'Editar';

  @override
  String get commonDone => 'Listo';

  @override
  String get commonCopy => 'Copiar';

  @override
  String get commonPaste => 'Pegar';

  @override
  String get commonBlock => 'Bloquear';

  @override
  String get commonUnblock => 'Desbloquear';

  @override
  String get navHome => 'Inicio';

  @override
  String get navSettings => 'Ajustes';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsLanguageTitle => 'Idioma';

  @override
  String get settingsLanguageSubtitle => 'Cambiar el idioma de la aplicación';

  @override
  String get languageSystem => 'Sistema';

  @override
  String get languageEnglish => 'Inglés';

  @override
  String get languageFrench => 'Francés';

  @override
  String get languageSpanish => 'Español';

  @override
  String get settingsProfileTitle => 'Perfil';

  @override
  String get settingsCurrencyTitle => 'Moneda';

  @override
  String get settingsDateFormatTitle => 'Formato de fecha';

  @override
  String get settingsDistanceUnitTitle => 'Unidad de distancia';

  @override
  String get settingsPrivacyPolicyTitle => 'Política de privacidad';

  @override
  String get settingsPrivacyPolicySubtitle =>
      'Cómo se tratan sus datos personales';

  @override
  String get settingsAppVersionTitle => 'Versión de la aplicación';

  @override
  String get settingsEnvironmentTitle => 'Entorno';

  @override
  String get settingsApiBaseUrlTitle => 'URL base de la API';

  @override
  String get settingsNotificationsTitle => 'Notificaciones';

  @override
  String get settingsNotificationsSubtitle => 'Permisos, categorías y sonido';

  @override
  String get settingsUnitsTitle => 'Unidades';

  @override
  String get settingsUnitsSubtitle => 'Varios formatos de unidades';

  @override
  String get settingsAboutTitle => 'Acerca de';

  @override
  String get settingsAboutSubtitle => 'Entorno, URL de API y versión';

  @override
  String get settingsExportImportTitle => 'Exportar / importar datos';

  @override
  String get settingsExportImportSubtitle =>
      'Copia de seguridad y restauración completa del dispositivo';

  @override
  String get deviceDataExportSecurityWarning =>
      'El archivo de copia de seguridad es JSON sin cifrar. Guárdelo de forma segura y no lo comparta por canales no confiables.';

  @override
  String get deviceDataExportAction => 'Exportar todos los datos';

  @override
  String get deviceDataImportAction => 'Importar copia de seguridad';

  @override
  String get deviceDataExportCopiedToClipboard =>
      'JSON de copia de seguridad copiado al portapapeles.';

  @override
  String get deviceDataExportLastSavedTitle => 'Archivo guardado';

  @override
  String deviceDataExportSavedLocation(String fileName) {
    return 'Documents/Bojairũ/$fileName';
  }

  @override
  String deviceDataExportFailed(String error) {
    return 'Error al exportar: $error';
  }

  @override
  String get deviceDataImportDisabledNoSubscription =>
      'La importación requiere una suscripción de vivienda activa y de pago en este dispositivo.';

  @override
  String get deviceDataImportDisabledWeb =>
      'La importación no está disponible en la web (solo desarrollo).';

  @override
  String get deviceDataReplaceConfirmTitle =>
      '¿Reemplazar todos los datos locales?';

  @override
  String get deviceDataReplaceConfirmBody =>
      'Esta copia de seguridad reemplazará todos los datos operativos en este dispositivo. Está pensado principalmente para un cambio de dispositivo.';

  @override
  String get deviceDataImportSuccess =>
      'Copia de seguridad restaurada. La sincronización relay vuelve a estar disponible.';

  @override
  String deviceDataImportFailed(String error) {
    return 'Error al importar: $error';
  }

  @override
  String deviceDataImportValidationFailed(String code) {
    return 'Archivo de copia de seguridad no válido ($code).';
  }

  @override
  String get deviceDataMigrationNetworkFailure =>
      'Los datos locales se restauraron pero no se pudo contactar el relay. Verifique su conexión y reintente la sincronización del servidor.';

  @override
  String deviceDataMigrationFailed(String code) {
    return 'Error al actualizar la identidad del servidor ($code).';
  }

  @override
  String get deviceDataMigrationPendingTitle =>
      'Sincronización del servidor pendiente';

  @override
  String get deviceDataMigrationPendingBody =>
      'Sus datos están en este dispositivo pero el servidor aún debe vincular su nueva identidad de instalación.';

  @override
  String get deviceDataRetryMigrationAction =>
      'Reintentar sincronización del servidor';

  @override
  String get deviceDataCanonicalRestoreTitle =>
      '¿Restaurar datos para qué participante?';

  @override
  String get settingsNotificationsGeneralSection => 'Permiso general';

  @override
  String get settingsNotificationsSystemPermissionTitle =>
      'Permiso del sistema';

  @override
  String get settingsNotificationsSystemPermissionBody =>
      'La app lo pedirá después de una acción relevante, como invitar a alguien.';

  @override
  String get settingsNotificationsSystemPermissionChecking =>
      'Comprobando permiso…';

  @override
  String get settingsNotificationsSystemPermissionUnsupported =>
      'No compatible con esta plataforma';

  @override
  String get settingsNotificationsSystemPermissionUnknown =>
      'Aún no solicitado';

  @override
  String get settingsNotificationsSystemPermissionGranted =>
      'Permitido por el sistema';

  @override
  String get settingsNotificationsSystemPermissionDenied =>
      'Bloqueado por el sistema';

  @override
  String get settingsNotificationsSystemPermissionProvisional =>
      'Permitido en silencio';

  @override
  String get settingsNotificationsRequestAction => 'Permitir';

  @override
  String get settingsNotificationsGeneralSwitchTitle =>
      'Permitir notificaciones de la app';

  @override
  String get settingsNotificationsGeneralSwitchBody =>
      'Interruptor principal para las categorías de notificación de esta app.';

  @override
  String get settingsNotificationsWakeFromSleepBody =>
      'Si está permitido, la app se registra en el relé para que, estando cerrada, pueda despertarse brevemente y comprobar nuevas solicitudes de contacto o recordatorios de pago, sin mostrar el contenido del mensaje en la notificación push.';

  @override
  String get settingsNotificationsContactsSection => 'Contactos';

  @override
  String get settingsNotificationsContactAddRequest =>
      'Solicitudes/confirmaciones de incorporación';

  @override
  String get settingsNotificationsContactDisconnection =>
      'Avisos de desconexión';

  @override
  String get settingsNotificationsContactInvitationExpiration =>
      'Caducidad de una invitación sin usar';

  @override
  String get settingsNotificationsCountryStatsSection =>
      'Estadísticas de usuarios';

  @override
  String get settingsNotificationsCountryStatsSwitchTitle =>
      '¿En qué país te encuentras?';

  @override
  String get settingsNotificationsCountryStatsSwitchSubtitle =>
      'Permite compartir el nombre de tu país. No se utilizará ningún otro contenido personal. El dato se agrega a un total de usuarios por país.';

  @override
  String get settingsNotificationsCountryStatsPickerLabel => 'País';

  @override
  String get settingsNotificationsCountryStatsSearchHint => 'Buscar por nombre';

  @override
  String get settingsNotificationsCountryStatsEmpty => 'Ningún país coincide';

  @override
  String get settingsNotificationsHousingSection => 'Vivienda';

  @override
  String get settingsNotificationsHousingPlanSubmission =>
      'Propuesta de plan recibida';

  @override
  String get settingsNotificationsHousingDecisionChange =>
      'Cambios de estado de decisión de un participante';

  @override
  String get settingsNotificationsHousingOfferExpiration =>
      'Caducidad de una oferta de plan sin aceptación unánime';

  @override
  String get settingsNotificationsSoundSection => 'Sonido';

  @override
  String get settingsNotificationsSoundSwitchTitle => 'Reproducir un sonido';

  @override
  String get settingsNotificationsSoundSwitchBody =>
      'Las notificaciones se mostrarán en silencio cuando esté desactivado.';

  @override
  String get settingsNotificationsSoundPickerTitle => 'Sonido de notificación';

  @override
  String get settingsNotificationsSoundPickerBody =>
      'La selección de sonidos del dispositivo se añadirá más adelante donde las plataformas lo permitan de forma segura.';

  @override
  String get settingsNotificationsEnableBlocked =>
      'El permiso del sistema para notificaciones no está concedido.';

  @override
  String get notificationFlowPermissionPromptTitle =>
      '¿Activar notificaciones útiles?';

  @override
  String get notificationFlowPermissionPromptBody =>
      'La app puede activar los permisos de notificación necesarios para lo que estás a punto de hacer.';

  @override
  String get notificationFlowPermissionEnableAction =>
      'Sí, activarlas y continuar';

  @override
  String get notificationFlowPermissionReviewAction =>
      'Quiero revisarlo yo mismo';

  @override
  String get notificationFlowPermissionNoAction => 'No, continuar';

  @override
  String get onboardingTitle => 'Configuración';

  @override
  String get onboardingLanguageTitle => 'Idioma';

  @override
  String get onboardingLanguageBody =>
      'Elige el idioma de la aplicación. Puedes cambiarlo en cualquier momento en Ajustes.';

  @override
  String get onboardingWelcomeTitle => 'Bienvenido';

  @override
  String get onboardingWelcomeIntro =>
      'Bojairũ es una aplicación desarrollada para ayudar a los compañeros de piso a llevarse mejor.\n\nAl usar esta aplicación, evitarás malentendidos, olvidos y errores de cálculo que a menudo generan conflictos. Para sacarle el máximo partido, introduce los datos a medida que se conozcan.';

  @override
  String get onboardingWelcomeConfidentialTitle => 'Confidencial';

  @override
  String get onboardingWelcomeConfidentialBody =>
      'Por fin, una verdadera confidencialidad. Puedes introducir tus datos sin ningún temor. Nadie más que tú y tus compañeros de piso tendrá acceso. Esta afirmación no es una simple promesa: es un hecho demostrable. Todo el código de la aplicación es público y puede inspeccionarse y auditarse.\n\nEsto implica, sin embargo, un compromiso importante: no hay forma de recuperar tus datos si los pierdes (pérdida, robo o rotura de tu dispositivo). La aplicación incluye una función de importación/exportación de datos que se recomienda encarecidamente usar periódicamente para conservar una copia de seguridad. Eres libre de guardar el archivo exportado donde quieras. La custodia segura de esa copia será tu responsabilidad.';

  @override
  String get onboardingOk => 'OK';

  @override
  String get onboardingProfileTitle => 'Tu perfil';

  @override
  String get onboardingNameLabel => 'Nombre';

  @override
  String get onboardingNameHint => 'Nombre para mostrar';

  @override
  String get onboardingAvatarTitle => 'Elige un avatar';

  @override
  String get onboardingPreferencesTitle => 'Preferencias';

  @override
  String get prefsCurrencyLabel => 'Moneda';

  @override
  String get prefsCurrencySearchHint => 'Buscar por código o nombre';

  @override
  String get prefsDateFormatLabel => 'Formato de fecha';

  @override
  String get prefsDistanceUnitLabel => 'Unidad de distancia';

  @override
  String get prefsDistanceUnitKm => 'Kilómetros (km)';

  @override
  String get prefsDistanceUnitMiles => 'Millas';

  @override
  String get prefsLiquidVolumeUnitLabel => 'Unidad de volumen líquido';

  @override
  String get prefsLiquidVolumeUnitLiter => 'Litro';

  @override
  String get prefsLiquidVolumeUnitUsGallon => 'Galón US (3,785 L)';

  @override
  String get prefsLiquidVolumeUnitImperialGallon => 'Galón imperial (4,546 L)';

  @override
  String get prefsWeekStartLabel => 'Inicio de la semana';

  @override
  String get prefsWeekStartSunday => 'Domingo';

  @override
  String get prefsWeekStartMonday => 'Lunes';

  @override
  String get prefsTimeZoneLabel => 'Zona horaria';

  @override
  String get prefsTimeZoneDevice => 'Usar hora local del dispositivo';

  @override
  String get prefsTimeZoneSearchHint => 'Buscar zona horaria';

  @override
  String get errorSomethingWentWrongTitle => 'Algo salió mal';

  @override
  String get errorSomethingWentWrongBody =>
      'Por favor, haz una captura de pantalla ahora y envíala con una descripción de los pasos que te llevaron a este error.';

  @override
  String get errorReportBugLink => 'Informar de este error';

  @override
  String get errorUnknownOnboardingStep => 'Paso de configuración desconocido.';

  @override
  String get homeHousingPlan => 'Plan de vivienda';

  @override
  String get homeModuleContacts => 'Contactos';

  @override
  String get homeModuleHousing => 'Vivienda';

  @override
  String get homeModuleVehicle => 'Vehículo';

  @override
  String get homeModuleVehicleSharing => 'Uso compartido del vehículo';

  @override
  String get homeModuleLicenses => 'Licencias';

  @override
  String get licensesEffectiveHeading => 'Estado por módulo';

  @override
  String get licensesProductsHeading => 'Suscripciones';

  @override
  String get licensesActiveHeading => 'Licencia activa:';

  @override
  String get licensesNoActiveSubscription => 'Ninguna suscripción activa';

  @override
  String get licensesAddSubscription => 'Añadir suscripción';

  @override
  String get licensesAddNothing => 'No añadir nada';

  @override
  String get licensesSelectModule => 'Seleccionar';

  @override
  String get licensesDeselectModule => 'Deseleccionar';

  @override
  String get licensesSelectModuleToAdd => 'Seleccione un módulo para añadir';

  @override
  String get licensesCancelThisSubscription => 'Cancelar esta suscripción';

  @override
  String get licensesPriceFree => 'Gratis';

  @override
  String licensesPricePerMonth(String price) {
    return '$price/mes';
  }

  @override
  String licensesPricePerYear(String price) {
    return '$price/año';
  }

  @override
  String licensesPricePerWeek(String price) {
    return '$price/semana';
  }

  @override
  String licensesPricePerDay(String price) {
    return '$price/día';
  }

  @override
  String get licensesProductHousing => 'Vivienda';

  @override
  String get licensesProductVehicle => 'Vehículo';

  @override
  String get licensesProductSharing => 'Compartir';

  @override
  String get licensesProductBundleHousingSharing =>
      'Paquete Vivienda + Compartir';

  @override
  String get licensesProductBundleVehicleSharing =>
      'Paquete Vehículo + Compartir';

  @override
  String get licensesProductBundleHousingVehicle =>
      'Paquete Vivienda + Vehículo';

  @override
  String get licensesProductBundleAllModules => 'Paquete los tres';

  @override
  String get licensesRestorePurchases => 'Restaurar compras';

  @override
  String get licensesSubscribe => 'Suscribirse';

  @override
  String get licensesUnsubscribe => 'Cancelar suscripción';

  @override
  String get licensesResubscribe => 'Volver a suscribirse';

  @override
  String licensesStatusAutoRenewOn(String when) {
    return 'Se renovará el\n$when';
  }

  @override
  String licensesStatusValidUntil(String when) {
    return 'Termina el\n$when';
  }

  @override
  String get licensesCancelAccessUntilTitle => 'Suscripción cancelada';

  @override
  String licensesCancelAccessUntilBody(String when) {
    return 'Tu suscripción sigue activa hasta el $when. No se renovará automáticamente.';
  }

  @override
  String get licensesCancelAccessUntilOk => 'OK';

  @override
  String get licensesStoreUnavailable =>
      'Tienda no disponible en este dispositivo.';

  @override
  String get licensesPlaySyncFailed =>
      'No se pudieron verificar las suscripciones con Google Play. Inténtalo de nuevo.';

  @override
  String get licensesNoProducts =>
      'Ningún producto de tienda disponible por ahora.';

  @override
  String get licensesEntitlementUnavailable =>
      'Servicio de licencias no inicializado.';

  @override
  String get licensesStateFree => 'Libre';

  @override
  String get licensesStateLinkedNotActive => 'Vinculado, no activo';

  @override
  String get licensesStateActiveTrial => 'Prueba';

  @override
  String get licensesStateActivePaid => 'De pago';

  @override
  String get licensesStateGrace => 'Gracia';

  @override
  String get licensesStateReadonly => 'Solo lectura';

  @override
  String get housingPlanSummaryMonthlyTotal => 'Total mensual';

  @override
  String housingPlanLoadError(String error) {
    return 'No se pudieron cargar los datos del plan.\n$error';
  }

  @override
  String get housingPlanStepParticipants => 'Participantes';

  @override
  String get housingPlanStepPlanDates => 'Fechas del plan';

  @override
  String get housingPlanStepExpenseCategories => 'Categorías de gastos';

  @override
  String get housingPlanStepExpenses => 'Gastos';

  @override
  String get housingPlanStepSplit => 'Reparto';

  @override
  String get housingPlanStepAgreementRules => 'Reglas del acuerdo';

  @override
  String get housingAgreementRulesIntro =>
      'Activa o desactiva cada regla. Las reglas fijas siguen listadas aunque estén desactivadas para dejar claro qué se negoció. Puedes añadir reglas y quitarlas mientras no haya una propuesta aceptada.';

  @override
  String get housingAgreementRulesAmendmentIntro =>
      'Activa o desactiva las reglas opcionales, edítalas, añade nuevas o retíralas. Las reglas fijas (toque de queda, retiro anticipado, edificio) siguen listadas aunque estén desactivadas. Las reglas nuevas deben estar activadas para incluirse en la propuesta.';

  @override
  String get housingAgreementRuleCurfewTitle =>
      'Calendario de horas de silencio';

  @override
  String get housingAgreementRuleCurfewPlaceholder =>
      'Semana orientativa (sin fechas): elige la letra del día y usa la cuadrícula. En edición, toca una celda de 30 minutos para alternar sin regla → silencio absoluto (rojo) → silencio moderado (amarillo).';

  @override
  String get housingQuietHoursAbsolute => 'Silencio absoluto';

  @override
  String get housingQuietHoursModerate => 'Silencio moderado';

  @override
  String get housingQuietHoursNoneThisDay => 'Sin horario';

  @override
  String get housingQuietHoursCopyDayTooltip => 'Copiar este día a otros días';

  @override
  String housingQuietHoursCopyDayDialogMessage(String sourceDay) {
    return '¿Copiar el horario del día $sourceDay a qué otros días?';
  }

  @override
  String get housingAgreementRuleEarlyWithdrawalTitle => 'Retirada anticipada';

  @override
  String get housingAgreementRuleBuildingTitle =>
      'Normas del edificio / vivienda';

  @override
  String get housingAgreementRuleBuildingHint =>
      'Sugerencias que puedes copiar o adaptar:\nNo fumadores\nSin mascotas\nNada en los pasillos\n…';

  @override
  String get housingAgreementRuleEdit => 'Editar';

  @override
  String get housingAgreementRuleFinishEditing => 'Terminar edición';

  @override
  String get housingAgreementRuleTitleRequired =>
      'Escribe un título para esta regla.';

  @override
  String get housingAgreementSuggestionLabel => 'Sugerencia';

  @override
  String get housingAgreementSuggestionCleanlinessTitle =>
      'Limpieza de zonas comunes';

  @override
  String get housingAgreementSuggestionCleanlinessBody =>
      'Guarda la ropa solo en los espacios asignados.\nLimpia ducha e inodoro tras usar.\nSeca la encimera tras cocinar.';

  @override
  String get housingAgreementSuggestionFridgeTitle => 'Gestión del frigorífico';

  @override
  String get housingAgreementSuggestionFridgeBody =>
      'Etiqueta lo que no compartes.\nTira lo caducado con regularidad.\nMantén baldas y puerta limpias.';

  @override
  String get housingAgreementRuleRemove => 'Quitar regla';

  @override
  String get housingAgreementRuleDismissSuggestion => 'Quitar de la lista';

  @override
  String get housingAgreementRuleAdd => 'Añadir regla';

  @override
  String get housingAgreementRuleAddTitle => 'Añadir regla al acuerdo';

  @override
  String get housingAgreementRuleCustomTitleLabel => 'Título';

  @override
  String get housingAgreementRuleCustomBodyLabel => 'Detalles (opcional)';

  @override
  String get housingAgreementRulesRemovalLockedHint =>
      'Las reglas incluidas en una propuesta aceptada no se pueden quitar; aún puedes desactivarlas.';

  @override
  String get housingAgreementRuleEarlyWithdrawalDisabledHint =>
      'Activa la regla para indicar preaviso y penalización.';

  @override
  String housingPlanParticipantsCount(int count) {
    return '$count participantes';
  }

  @override
  String get housingPlanFewerParticipantsTooltip => 'Menos participantes';

  @override
  String get housingPlanMoreParticipantsTooltip => 'Más participantes';

  @override
  String get housingPlanAddCategoryTooltip => 'Añadir categoría de gasto';

  @override
  String get housingPlanAddExpenseTooltip => 'Añadir gasto';

  @override
  String get housingPlanBack => 'Atrás';

  @override
  String get housingPlanNext => 'Siguiente';

  @override
  String get housingPlanFinish => 'Finalizar';

  @override
  String get housingPlanSplitValidationMessage =>
      'Cada gasto o categoría debe sumar el 100 % entre los participantes.';

  @override
  String housingPlanCouldNotContinue(String error) {
    return 'No se pudo continuar: $error';
  }

  @override
  String get housingPlanInviteComingSoon =>
      'Invitar a los participantes (próximamente)';

  @override
  String get housingPlanPreviousPerson => 'Anterior';

  @override
  String get housingPlanNextPerson => 'Siguiente';

  @override
  String get housingPlanParticipantNameLabel => 'Nombre';

  @override
  String get housingPlanChooseContactAction => 'Elegir contacto';

  @override
  String get housingPlanChangeContactAction => 'Cambiar contacto';

  @override
  String get housingPlanRemoveParticipantHint =>
      'Arrastra y suelta un contacto aquí para quitarlo.';

  @override
  String get housingPlanContactRequired =>
      'Elige un contacto para cada participante antes de continuar.';

  @override
  String get housingPlanParticipantsMustBeConnected =>
      'Cada co-participante debe ser un contacto conectado (usa la app con su propia cuenta). Invítalo desde Contactos primero y elígelo aquí después.';

  @override
  String get housingPlanParticipantsPlaceholderNote =>
      'Los co-participantes deben ser contactos conectados. El plan conserva una copia del nombre y del avatar para mantener legible el historial.';

  @override
  String get housingPlanYou => 'Tú';

  @override
  String housingPlanCoParticipantUnnamed(int index) {
    return 'Co-participante $index';
  }

  @override
  String get housingPlanPlanStart => 'Inicio del plan';

  @override
  String get housingPlanPlanEnd => 'Fin del plan';

  @override
  String get housingPlanDurationLabel => 'Duración';

  @override
  String get housingPlanEndDateError =>
      'La fecha de fin debe ser posterior a la de inicio (al menos un día calendario).';

  @override
  String get housingPlanCategoriesEmptyHint =>
      'Pulsa + para añadir una categoría. En el siguiente paso podrás asignar cada gasto a una categoría para mantener juntos los conceptos relacionados.';

  @override
  String get housingPlanDeleteCategoryTitle => 'Eliminar categoría';

  @override
  String get housingPlanDeleteCategoryBody =>
      'Los gastos de esta categoría dejarán de estar asignados a ella. No se eliminan los gastos.';

  @override
  String get housingPlanCancel => 'Cancelar';

  @override
  String get housingPlanDelete => 'Eliminar';

  @override
  String get housingPlanTapToAddExpense => 'Pulsa + para añadir un gasto.';

  @override
  String get housingPlanAddExpensesFirst => 'Añade gastos primero.';

  @override
  String get housingPlanAddAtLeastOneExpense => '¡Añade al menos un gasto!';

  @override
  String get housingPlanExpenseAmountsIncomplete =>
      'Cada gasto debe tener un importe mayor que cero.';

  @override
  String get housingPlanExpenseRecurrenceIncomplete =>
      'Indica la recurrencia de cada gasto recurrente.';

  @override
  String get housingPlanExpenseSplitsIncomplete =>
      'El reparto de cada gasto debe sumar el 100 %.';

  @override
  String get housingPlanExpenseParticipantsMissing =>
      'Faltan participantes para validar los gastos.';

  @override
  String get housingPlanSplitNoCategory => 'Sin categoría';

  @override
  String get housingPlanWithdrawalIntro => 'Reglas de retirada anticipada.';

  @override
  String get housingPlanWithdrawalSameForAll =>
      'Misma regla para todos los participantes';

  @override
  String get housingPlanMinimumNoticeDays => 'Preaviso mínimo (días)';

  @override
  String get housingPlanPenaltyAmount => 'Importe de la penalización';

  @override
  String get housingPlanSummaryMissingAgreement => 'Falta el acuerdo';

  @override
  String get housingPlanSummaryMissingParticipants =>
      'No hay participantes en este plan. Edite el plan para configurarlos de nuevo.';

  @override
  String get housingPlanSummaryEditPlan => 'Editar plan';

  @override
  String get housingPlanSummaryInvite => 'Enviar mi plan';

  @override
  String get housingWorkbenchTitle => 'Planes de vivienda';

  @override
  String get housingWorkbenchDraftsSection => 'Borrador(es)';

  @override
  String get housingWorkbenchPendingSection => 'Pendiente';

  @override
  String get housingWorkbenchArchivedSection => 'Archivada(s)';

  @override
  String get housingWorkbenchActiveSection => 'Planes activos';

  @override
  String get housingWorkbenchSettlementSection => 'Liquidación en curso';

  @override
  String housingWorkbenchSettlementOpenLabel(String planTitle) {
    return '$planTitle — liquidación';
  }

  @override
  String get housingWorkbenchOpenPlan => 'Abrir';

  @override
  String get housingWorkbenchEmpty =>
      'No hay planes de vivienda con su perfil en este dispositivo.';

  @override
  String get housingActiveHubTitle => 'Acuerdo activo';

  @override
  String housingActiveHubPeriod(String dateRange) {
    return '$dateRange';
  }

  @override
  String get housingActiveHubEnterExpense => 'Enviar un gasto';

  @override
  String get housingActiveHubEnterSettlementDue => 'Registrar un pago de deuda';

  @override
  String housingActiveHubSettlementAvailableUntil(String date) {
    return 'Disponible hasta el $date';
  }

  @override
  String get housingLicenseReadonlyBannerTitle => 'Vivienda en solo lectura';

  @override
  String get housingLicenseReadonlyBannerBody =>
      'El periodo de prueba y el de gracia terminaron sin una suscripción de vivienda. Puede consultar el historial, pero no registrar un gasto nuevo. La exportación sigue disponible en Ajustes. Abra Licencias para suscribirse.';

  @override
  String get housingLicenseGraceBannerTitle => 'Periodo de gracia';

  @override
  String housingLicenseGraceBannerBody(int days, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'La vivienda sigue utilizable hasta el $date ($days días restantes). Abra Licencias para suscribirse.',
      one:
          'La vivienda sigue utilizable hasta el $date (1 día restante). Abra Licencias para suscribirse.',
    );
    return '$_temp0';
  }

  @override
  String get housingSettlementDueTitle => 'Pago de deuda';

  @override
  String get housingSettlementDueSubmit =>
      'Proponer transferencia de liquidación';

  @override
  String get housingSettlementDueSuccess =>
      'Transferencia de liquidación propuesta.';

  @override
  String get housingSettlementDueTransferDescription =>
      'Liquidación al fin del acuerdo';

  @override
  String get housingSettlementDueNoCounterparties =>
      'No hay saldo pendiente con otros participantes.';

  @override
  String get housingActiveHubMonthlyExpenses => 'Gastos aceptados';

  @override
  String get housingActiveHubBalances => 'Deudas entre participantes';

  @override
  String get housingActiveHubPaymentStatus => 'Gastos corrientes';

  @override
  String get housingActiveHubViewPlan => 'Consultar el plan';

  @override
  String get housingActiveHubRequestAmendment => 'Modificar el plan';

  @override
  String get housingActiveHubJournals => 'Diarios';

  @override
  String get housingActiveHubExportImport => 'Copia de seguridad';

  @override
  String get housingExportSecurityWarning =>
      'El archivo exportado es JSON sin cifrar. Guárdelo de forma segura y no lo comparta por canales no confiables.';

  @override
  String get housingExportAction => 'Exportar datos del acuerdo';

  @override
  String get housingExportCopiedToClipboard =>
      'JSON exportado copiado al portapapeles.';

  @override
  String get housingExportLastSavedTitle => 'Archivo guardado';

  @override
  String housingExportSavedLocation(String fileName) {
    return 'Almacenamiento interno/Documentos/Bojairũ/$fileName';
  }

  @override
  String housingExportFailed(String error) {
    return 'Error de exportación: $error';
  }

  @override
  String get housingImportNotAvailableTitle => 'Importación';

  @override
  String get housingImportNotAvailableBody =>
      'La importación requiere un derecho de vivienda válido y se habilitará en una versión posterior.';

  @override
  String get housingActiveHubPassPlaceholderTitle => 'Próximamente';

  @override
  String get housingActiveHubPassPlaceholderBody =>
      'Esta pantalla estará disponible en la siguiente fase de implementación.';

  @override
  String get housingRealizedExpenseTitle => 'Enviar un gasto';

  @override
  String get housingRealizedExpensePlanLine => 'Línea del plan';

  @override
  String get housingRealizedExpenseAmount => 'Importe';

  @override
  String get housingRealizedExpensePaymentDate => 'Fecha de pago';

  @override
  String get housingRealizedExpenseTransferDate => 'Fecha de la transferencia';

  @override
  String get housingRealizedExpensePaymentDatePick => 'Elegir una fecha';

  @override
  String get housingRealizedExpensePayer => 'Quién pagó';

  @override
  String get housingRealizedExpenseKind => 'Tipo de gasto';

  @override
  String get housingRealizedExpenseKindNormal => 'Pago';

  @override
  String get housingRealizedExpenseKindReimbursement => 'Reembolso';

  @override
  String get housingRealizedExpenseKindAdvance => 'Anticipo';

  @override
  String get housingRealizedExpenseKindTransfer => 'Transferencia';

  @override
  String get housingRealizedExpenseBeneficiary => 'Parte reembolsada de';

  @override
  String get housingRealizedExpenseTransferRecipient =>
      'Participante que recibió el importe';

  @override
  String housingRealizedExpenseTransferRecipientSummary(String name) {
    return 'Importe entregado a $name';
  }

  @override
  String get housingRealizedExpenseTransferDescription =>
      'Descripción / comentario (opcional)';

  @override
  String get housingRealizedExpenseProofSection => 'Prueba (opcional)';

  @override
  String get housingRealizedExpenseProofEncourage =>
      'Añadir un recibo o factura ayuda al grupo a validar este gasto.';

  @override
  String get housingRealizedExpenseAddProof => 'Añadir prueba';

  @override
  String get housingRealizedExpensePickCamera => 'Tomar una foto';

  @override
  String get housingRealizedExpenseCapturePhoto => 'Capturar la foto';

  @override
  String get housingRealizedExpenseCameraStartFailed =>
      'No se pudo acceder a la cámara en este dispositivo.';

  @override
  String get housingRealizedExpensePickGallery => 'Elegir de la galería';

  @override
  String get housingRealizedExpensePickDocument => 'Elegir un documento';

  @override
  String housingRealizedExpenseStoragePath(String path) {
    return 'Guardado en: $path';
  }

  @override
  String get housingRealizedExpenseSaveDraft => 'Guardar borrador';

  @override
  String get housingRealizedExpenseSubmit => 'Enviar al grupo';

  @override
  String get housingRealizedExpenseDraftSaved =>
      'Borrador guardado en este dispositivo';

  @override
  String get housingRealizedExpenseProposedSnackbar =>
      'Gasto enviado para revisión del grupo';

  @override
  String get housingRealizedExpenseValidationLine =>
      'Seleccione una línea del plan';

  @override
  String get housingRealizedExpenseValidationAmount =>
      'Introduzca un importe válido';

  @override
  String get housingRealizedExpenseValidationPayer => 'Indique quién pagó';

  @override
  String get housingRealizedExpenseValidationDate =>
      'Seleccione una fecha de pago';

  @override
  String get housingRealizedExpenseValidationBeneficiary =>
      'Indique el participante que recibió el importe';

  @override
  String get housingRealizedExpenseNoPlanLines =>
      'Este acuerdo aún no tiene líneas de gasto. Añádalas mediante una modificación del plan.';

  @override
  String get housingRealizedExpenseLoadFailed =>
      'No se pudieron cargar los datos del acuerdo';

  @override
  String get housingRealizedExpenseCropTitle => 'Recortar prueba';

  @override
  String get housingRealizedExpenseCropConfirm => 'Usar imagen recortada';

  @override
  String get housingRealizedExpenseCropFailed =>
      'No se pudo recortar la imagen';

  @override
  String get housingRealizedExpenseProofTapToSaveCopy =>
      'Toque para guardar una copia';

  @override
  String get housingRealizedExpenseProofSaveCopyFailed =>
      'No se pudo guardar una copia del archivo';

  @override
  String get housingRealizedExpenseProofImagesOnly =>
      'Seleccione solo un archivo de imagen (jpg, jpeg, png, webp, heic).';

  @override
  String get housingRealizedExpenseProofImageTooLarge =>
      'Esta imagen es demasiado grande para procesarla en la aplicación web. Elija una imagen más pequeña o envíela de otra manera.';

  @override
  String housingActiveHubReviewPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gastos pendientes de revisión',
      one: '1 gasto pendiente de revisión',
    );
    return '$_temp0';
  }

  @override
  String get housingRealizedExpenseReviewListTitle => 'Revisar gastos';

  @override
  String get housingRealizedExpenseReviewEmpty => 'No hay gastos que revisar.';

  @override
  String get housingRealizedExpenseReviewWaitingForYou =>
      'Pendiente de su revisión';

  @override
  String get housingRealizedExpenseReviewWaitingForOthers =>
      'Pendiente de otros participantes';

  @override
  String get housingRealizedExpenseReviewPublished => 'Publicado';

  @override
  String get housingRealizedExpenseReviewRejected => 'Rechazado';

  @override
  String get housingRealizedExpenseReviewTitle => 'Revisión de gasto';

  @override
  String get housingRealizedExpenseReviewTypeLabel => 'Tipo';

  @override
  String get housingRealizedExpenseReviewMadeByLabel => 'Hecha por';

  @override
  String get housingRealizedExpenseReviewPlanLineLabel => 'Línea del plan';

  @override
  String get housingRealizedExpenseReviewDescriptionLabel =>
      'Descripción / comentario';

  @override
  String housingRealizedExpenseTransferToYouBy(String name) {
    return 'Transferido a usted por: $name';
  }

  @override
  String housingRealizedExpenseTransferToParticipant(String name) {
    return 'Transferido a: $name';
  }

  @override
  String get housingRealizedExpenseReviewDescriptionNone => 'Ninguno';

  @override
  String get housingRealizedExpenseReviewAcceptedWord => 'Aceptado';

  @override
  String get housingRealizedExpenseReviewRejectedWord => 'Rechazado';

  @override
  String get housingRealizedExpenseReviewDecisionsTitle => 'Decisiones';

  @override
  String get housingRealizedExpenseReviewDecisionTableNameColumn => 'Nombre';

  @override
  String get housingRealizedExpenseReviewDecisionTableDateColumn => 'Fecha';

  @override
  String get housingRealizedExpenseReviewDecisionPendingShort => 'Pendiente';

  @override
  String get housingRealizedExpenseReviewDecisionUnknown => 'Desconocida';

  @override
  String get housingRealizedExpenseReviewMotifLabel => 'Motivo';

  @override
  String housingRealizedExpenseReviewDecisionPending(String name) {
    return '$name: pendiente';
  }

  @override
  String housingRealizedExpenseReviewDecisionAccepted(String name) {
    return '$name: aceptado';
  }

  @override
  String housingRealizedExpenseReviewDecisionRejected(String name) {
    return '$name: rechazado';
  }

  @override
  String housingRealizedExpenseReviewByName(String name) {
    return 'por $name';
  }

  @override
  String housingRealizedExpenseReviewAcceptedByOn(String name, String when) {
    return 'Aceptado por $name el $when';
  }

  @override
  String housingRealizedExpenseReviewRejectedByOn(String name, String when) {
    return 'Rechazado por $name el $when';
  }

  @override
  String get housingRealizedExpenseTransferReviewHint =>
      'Verifique que realmente recibió la transferencia antes de aceptar. No hay límite de tiempo.';

  @override
  String housingRealizedExpenseReviewPayer(String name) {
    return 'Pagado por $name';
  }

  @override
  String get housingRealizedExpenseReviewRejections => 'Rechazos';

  @override
  String get housingRealizedExpenseAccept => 'Aceptar';

  @override
  String get housingRealizedExpenseReject => 'Rechazar';

  @override
  String get housingRealizedExpenseRejectTitle => 'Rechazar gasto';

  @override
  String get housingRealizedExpenseRejectJustification =>
      'Motivo (obligatorio)';

  @override
  String get housingRealizedExpenseRejectConfirm => 'Rechazar';

  @override
  String get housingRealizedExpenseAccepted => 'Gasto aceptado';

  @override
  String get housingRealizedExpenseRejected => 'Gasto rechazado';

  @override
  String get housingRealizedExpenseResubmit => 'Corregir y reenviar';

  @override
  String get housingMonthlyExpensesTitle => 'Gastos aceptados';

  @override
  String housingMonthlyExpensesMonthLabel(int year, int month) {
    return '$year-$month';
  }

  @override
  String get housingMonthlyExpensesEmpty =>
      'No hay gastos publicados para este mes.';

  @override
  String get housingRejectedExpensesTitle => 'Gastos rechazados';

  @override
  String get housingRejectedExpensesEmpty =>
      'No hay gastos rechazados para este mes.';

  @override
  String get housingBalancesTitle => 'Deudas entre participantes';

  @override
  String get housingBalancesEmpty =>
      'Aún no hay saldos. Los gastos publicados aparecerán aquí.';

  @override
  String housingBalancesOwes(String from, String to, String amount) {
    return '$from debe $amount a $to';
  }

  @override
  String get housingBalancesModeReal => 'Reales';

  @override
  String get housingBalancesModeOptimized => 'Optimizados';

  @override
  String get housingBalancesLegendTitle => 'Leyenda';

  @override
  String get housingBalancesOwesNobody => 'No debe nada a nadie.';

  @override
  String housingBalancesOwesAmountTo(String amount, String to) {
    return '$amount a $to';
  }

  @override
  String get housingBalancesInactiveMarker => '(participante anterior)';

  @override
  String get housingExpensePaymentStatusTitle => 'Gastos corrientes';

  @override
  String get housingExpensePaymentStatusEmpty =>
      'No hay gastos del plan para mostrar.';

  @override
  String housingExpensePaymentStatusDetailsTitle(String expenseName) {
    return 'Pagos — $expenseName';
  }

  @override
  String get housingExpensePaymentStatusDetailsEmpty =>
      'No hay pagos publicados para este gasto este mes.';

  @override
  String housingExpensePaymentStatusDetailsLine(
    String amount,
    String date,
    String payer,
  ) {
    return '$amount — $date — $payer';
  }

  @override
  String get housingRealizedExpenseBudgetCapTitle =>
      'Presupuesto mensual superado';

  @override
  String housingRealizedExpenseBudgetCapBody(String cap) {
    return 'Este importe supera el tope mensual ($cap) de esta línea. ¿Enviar de todos modos?';
  }

  @override
  String get housingRealizedExpenseBudgetCapConfirm => 'Enviar de todos modos';

  @override
  String get housingRealizedExpensePaymentChartCarryTitle =>
      'Importe mensual superado';

  @override
  String housingRealizedExpensePaymentChartCarryBody(
    String monthlyTotal,
    String excess,
  ) {
    return 'Este pago supera el importe mensualizado ($monthlyTotal) de este gasto en $excess. ¿Trasladar el excedente al mes siguiente en el gráfico de estado de pagos?';
  }

  @override
  String get housingRealizedExpensePaymentChartCarryNextMonth =>
      'Trasladar al mes siguiente';

  @override
  String get housingRealizedExpensePaymentChartCarryCurrentMonth =>
      'Mostrar en el mes actual';

  @override
  String get housingActivePlanReadOnlyTitle => 'Detalle del plan';

  @override
  String get housingActivePlanDatesLabel => 'Fechas del plan';

  @override
  String get housingActivePlanReadOnlyExpenses => 'Ver líneas de gasto';

  @override
  String get housingAmendmentRequestTitle => 'Modificar el plan';

  @override
  String get housingAmendmentRequestIntro =>
      'Elija un solo cambio por propuesta. El grupo debe aceptarlo por unanimidad.';

  @override
  String get housingAmendmentPendingBlocks =>
      'Ya hay una modificación pendiente de respuesta.';

  @override
  String get housingAmendmentPickLine => 'Elegir una línea';

  @override
  String get housingAmendmentTypeLineEdit => 'Modificar un gasto';

  @override
  String get housingAmendmentTypeLineEditHint =>
      'Título, importe, descripción, pagador, recurrencia o reparto';

  @override
  String get housingAmendmentTypeLineAmount => 'Cambiar un importe';

  @override
  String get housingAmendmentTypeLineAmountHint =>
      'Actualizar el precio de una línea';

  @override
  String get housingAmendmentTypeLineRecurrence => 'Cambiar recurrencia';

  @override
  String get housingAmendmentTypeLineRecurrenceHint =>
      'Cambiar la frecuencia de una línea';

  @override
  String get housingAmendmentTypeLinePayer => 'Cambiar quién paga';

  @override
  String get housingAmendmentTypeLinePayerHint =>
      'Cambiar el responsable del pago';

  @override
  String get housingAmendmentTypeLineAdd => 'Añadir un gasto';

  @override
  String get housingAmendmentTypeLineAddHint => 'Añadir un gasto nuevo al plan';

  @override
  String get housingAmendmentTypeLineRemove => 'Quitar un gasto';

  @override
  String get housingAmendmentTypeLineRemoveHint =>
      'Retirar una línea (los gastos pasados siguen vinculados)';

  @override
  String get housingAmendmentLineRemoveConfirm =>
      '¿Quitar esta línea del plan? Los gastos realizados existentes se conservan.';

  @override
  String get housingAmendmentLineRemoveConfirmAction => 'Quitar línea';

  @override
  String get housingAmendmentTypeAgreementEnd => 'Modificar fecha de fin';

  @override
  String get housingAmendmentTypeAgreementEndHint =>
      'Ampliar o acortar el periodo';

  @override
  String housingAmendmentEndDateSet(String date) {
    return 'Fin fijado al $date';
  }

  @override
  String get housingAmendmentTypeRuleChange => 'Cambiar reglas';

  @override
  String get housingAmendmentTypeRuleChangeHint =>
      'Toque de queda, retirada, etc.';

  @override
  String get housingAmendmentRosterChangeTitle => 'Cambio importante';

  @override
  String get housingAmendmentRosterChangeHint =>
      'Añadir o quitar un compañero requiere un nuevo acuerdo';

  @override
  String get housingAmendmentRosterChangeBody =>
      'Los cambios de participantes no son una modificación en vigor. Finalice el acuerdo o inicie un nuevo periodo derivado del plan actual.';

  @override
  String get housingAgreementRenewalTitle => 'Nuevo periodo de acuerdo';

  @override
  String get housingAgreementRenewalIntro =>
      'Al terminar el periodo o cambiar el grupo, inicie una nueva propuesta unánime. Puede derivarla del plan actual.';

  @override
  String get housingAgreementRenewalFork => 'Nuevo periodo desde este plan';

  @override
  String get housingAgreementEndNow => 'Finalizar acuerdo hoy';

  @override
  String get housingAgreementEndConfirmTitle => '¿Finalizar acuerdo?';

  @override
  String get housingAgreementEndConfirmBody =>
      'No se podrán registrar nuevos gastos realizados después de hoy. Puede iniciar un nuevo periodo más tarde.';

  @override
  String get housingAgreementEndConfirmAction => 'Finalizar hoy';

  @override
  String get housingAgreementEndedSnackbar =>
      'Periodo del acuerdo cerrado en este dispositivo';

  @override
  String get housingAgreementExpiredTitle => 'Periodo finalizado';

  @override
  String get housingAgreementExpiredBody =>
      'No puede registrar gastos realizados para este periodo. Inicie un nuevo acuerdo para continuar.';

  @override
  String get housingAmendmentDetailTitle => 'Cambio solicitado';

  @override
  String housingAmendmentDetailIntro(String proposer, String subject) {
    return '$proposer propone cambiar $subject.';
  }

  @override
  String get housingAmendmentDetailCurrent => 'Actualmente';

  @override
  String get housingAmendmentDetailPrevious => 'Anteriormente';

  @override
  String get housingAmendmentDetailAtRequestTime =>
      'En el momento de la solicitud';

  @override
  String get housingAmendmentDetailProposed => 'Propuesto';

  @override
  String get housingAmendmentSubjectAgreementEnd =>
      'la fecha de fin del acuerdo';

  @override
  String housingAmendmentSubjectLineEdit(String line) {
    return 'el gasto « $line »';
  }

  @override
  String housingAmendmentSubjectLineAmount(String line) {
    return 'el importe de « $line »';
  }

  @override
  String housingAmendmentSubjectLineRecurrence(String line) {
    return 'la recurrencia de « $line »';
  }

  @override
  String housingAmendmentSubjectLinePayer(String line) {
    return 'quién paga « $line »';
  }

  @override
  String get housingAmendmentSubjectLineAdd => 'el plan (nueva línea de gasto)';

  @override
  String housingAmendmentSubjectLineRemove(String line) {
    return 'el plan (quitar « $line »)';
  }

  @override
  String get housingAmendmentSubjectRuleChange => 'las reglas del acuerdo';

  @override
  String get housingAmendmentValueNotSet => 'Sin definir';

  @override
  String get housingAmendmentValueNone => 'Ninguna';

  @override
  String get housingAmendmentValueRemoved => 'Retirada del plan';

  @override
  String get housingAmendmentUnknownLine => 'esta línea';

  @override
  String get housingAmendmentRulesCurrentPlaceholder =>
      'Reglas actuales (resumen próximamente)';

  @override
  String get housingAmendmentRulesProposedPlaceholder =>
      'Reglas propuestas (resumen próximamente)';

  @override
  String get housingActiveHubPendingAmendment => 'Hay una solicitud de cambio';

  @override
  String get housingAmendmentDetailLoading => 'Cargando…';

  @override
  String get housingAmendmentAccept => 'Aceptar';

  @override
  String get housingAmendmentReject => 'Rechazar';

  @override
  String get housingAmendmentSubmitToGroup => 'Enviar al grupo';

  @override
  String get housingAmendmentRulesContinue => 'Continuar';

  @override
  String get housingAmendmentRulesModifiedWhileDisabledBody =>
      'Ha modificado una regla sin activarla. ¿Está seguro de no haber olvidado nada?';

  @override
  String get housingAmendmentRulesModifiedWhileDisabledReview =>
      'Quiero verificar';

  @override
  String get housingAmendmentRulesModifiedWhileDisabledContinue =>
      'Continuar de todos modos';

  @override
  String get housingAgreementRuleStatusEnabled => 'Activada';

  @override
  String get housingAgreementRuleStatusDisabled => 'Desactivada';

  @override
  String get housingAmendmentPreviewTitle => 'Vista previa de la solicitud';

  @override
  String housingAmendmentPreviewIntro(String subject) {
    return 'Revise el cambio propuesto en $subject antes de enviarlo al grupo.';
  }

  @override
  String get housingAmendmentNoMeaningfulChange =>
      'No hay cambio respecto al plan actual.';

  @override
  String get housingAmendmentRequestStatusAction => 'Estado de la solicitud';

  @override
  String get housingAmendmentJournalTitle => 'Cambios al plan';

  @override
  String get housingJournalsTitle => 'Diarios';

  @override
  String get housingAmendmentJournalSubtitle =>
      'Solicitudes aceptadas y rechazadas';

  @override
  String get housingAmendmentJournalSubjectAgreementEnd =>
      'Fecha de fin del acuerdo';

  @override
  String housingAmendmentJournalLineAdd(String title, String amount) {
    return 'Alta de gasto - $title - $amount';
  }

  @override
  String housingAmendmentJournalLineEdit(String title, String amount) {
    return 'Modificación de gasto - $title - $amount';
  }

  @override
  String housingAmendmentJournalLineRemove(String title, String amount) {
    return 'Retiro de gasto - $title - $amount';
  }

  @override
  String get housingAmendmentJournalEmpty => 'Aún no hay cambios al plan.';

  @override
  String get housingAmendmentJournalAccepted => 'Aceptada';

  @override
  String get housingAmendmentJournalRefused => 'Rechazada';

  @override
  String housingAmendmentJournalCardTitle(String subject, String status) {
    return '$subject — $status';
  }

  @override
  String housingAmendmentJournalCardSubtitle(String name, String date) {
    return 'Por $name · $date';
  }

  @override
  String get housingAmendmentRulesSummaryShort =>
      'Reglas del acuerdo actualizadas';

  @override
  String housingAmendmentRulesGroupAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Reglas añadidas ($count)',
      one: 'Regla añadida ($count)',
    );
    return '$_temp0';
  }

  @override
  String housingAmendmentRulesGroupModified(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Reglas modificadas ($count)',
      one: 'Regla modificada ($count)',
    );
    return '$_temp0';
  }

  @override
  String housingAmendmentRulesGroupRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Reglas retiradas ($count)',
      one: 'Regla retirada ($count)',
    );
    return '$_temp0';
  }

  @override
  String housingAmendmentRulesGroupUnchanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Reglas sin cambios ($count)',
      one: 'Regla sin cambios ($count)',
    );
    return '$_temp0';
  }

  @override
  String get housingAmendmentRulesBeforeSubtitle => 'Antes';

  @override
  String get housingAmendmentRulesProposedSubtitle => 'Propuesto';

  @override
  String get housingAmendmentRulesUnchangedDetailHint =>
      'Esta regla no cambia en la propuesta.';

  @override
  String get housingAmendmentRejectTitle => 'Rechazar solicitud';

  @override
  String get housingAmendmentRejectMessageLabel => 'Mensaje (opcional)';

  @override
  String get housingAmendmentRejectConfirm => 'Rechazar';

  @override
  String get housingAmendmentRefusalMessageLabel => 'Mensaje de rechazo';

  @override
  String get housingActiveHubViewPendingAmendment => 'Cambio solicitado';

  @override
  String get housingInviteResponseWindowTitle => 'Plazo de respuesta';

  @override
  String get housingInviteResponseWindowBody =>
      'Los participantes tienen hasta esta fecha y hora para responder (UTC).';

  @override
  String get housingInvitePeriodOverlapTitle =>
      'Conflicto de periodo del acuerdo';

  @override
  String get housingInvitePeriodOverlapBody =>
      'Este acuerdo se solapa en más de un día calendario con otro plan de vivienda en el que usted participa. Cambie las fechas o resuelva el otro plan antes de enviar.';

  @override
  String housingInvitePeriodOverlapDetail(String planTitle, String dateRange) {
    return 'Este acuerdo se solapa en más de un día calendario con «$planTitle» ($dateRange). Cambie las fechas o resuelva ese plan antes de enviar.';
  }

  @override
  String get housingPlanParticipantMustBeConnectedContact =>
      'Cada co-participante debe ser un contacto conectado en este dispositivo antes de enviar la propuesta.';

  @override
  String get housingInviteResponseDeadlineTitle => 'Plazo de respuesta:';

  @override
  String housingInviteResponseDeadlineInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'En $count días',
      one: 'En 1 día',
    );
    return '$_temp0';
  }

  @override
  String get housingInviteResponseDeadlineToday => 'Hoy';

  @override
  String deadlineRemainingInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'En $count días',
      one: 'En 1 día',
    );
    return '$_temp0';
  }

  @override
  String get deadlineRemainingToday => 'Hoy';

  @override
  String deadlineRemainingCountdown(String time) {
    return 'En $time';
  }

  @override
  String get deadlineRemainingExpired => 'Caducado';

  @override
  String housingInviteResponseDeadlineCountdown(String time) {
    return 'En $time';
  }

  @override
  String get housingInviteOfferClosedHint =>
      'Esta oferta ya no admite respuestas.';

  @override
  String housingInviteForkedFromLabel(String revisionId) {
    return 'Versión derivada de una propuesta anterior ($revisionId).';
  }

  @override
  String get housingArchiveExpiredTitle => 'Propuesta caducada';

  @override
  String get settingsActivityLogTitle => 'Diario de eventos';

  @override
  String get settingsActivityLogSubtitle =>
      'Eventos del relé en este dispositivo';

  @override
  String get activityLogEmpty => 'Ningún evento coincide con los filtros.';

  @override
  String get activityLogNoEntries => 'Aún no hay eventos en el registro.';

  @override
  String get activityLogFiltersTitle => 'Filtros';

  @override
  String get activityLogFilterDatesLabel => 'Fechas';

  @override
  String get activityLogFilterInitiatorLabel => 'Iniciador';

  @override
  String get activityLogFilterInitiatorAll => 'Todos';

  @override
  String get activityLogFilterInitiatorSelf => 'Yo';

  @override
  String get activityLogFilterInitiatorContact => 'Contacto';

  @override
  String get activityLogFilterEmitterLabel => 'Emisor';

  @override
  String get activityLogFilterEmitterAll => 'Todos';

  @override
  String get activityLogFilterEmitterSystem => 'Sistema';

  @override
  String get activityLogFilterFromLabel => 'Desde (fecha)';

  @override
  String get activityLogFilterToLabel => 'Hasta (fecha)';

  @override
  String get activityLogApplyFilters => 'Aplicar filtros';

  @override
  String get activityLogKindContactHandshakeReceived =>
      'Solicitud de conexión recibida';

  @override
  String get activityLogKindContactDisconnected => 'Contacto desconectado';

  @override
  String get activityLogKindContactDeleted => 'Contacto eliminado';

  @override
  String get activityLogKindHousingProposalSent =>
      'Propuesta de vivienda enviada';

  @override
  String get activityLogKindHousingProposalReceived =>
      'Propuesta de vivienda recibida';

  @override
  String get activityLogKindHousingProposalResponse =>
      'Respuesta a propuesta de vivienda';

  @override
  String get activityLogKindHousingProposalInvalidated =>
      'Propuesta de vivienda cerrada';

  @override
  String get activityLogKindHousingProposalExpired =>
      'Propuesta de vivienda caducada';

  @override
  String get activityLogKindHousingProposalForkCreated =>
      'Versión derivada de vivienda iniciada';

  @override
  String get activityLogKindHousingAgreementActivated =>
      'Acuerdo de vivienda activado';

  @override
  String get activityLogKindHousingProposalAgreementExpired =>
      'Voto sobre modificación del plan abandonado (acuerdo terminado)';

  @override
  String get activityLogKindHousingParticipationChangeAgreementExpired =>
      'Voto sobre expulsión abandonado (acuerdo terminado)';

  @override
  String get activityLogKindVehicleSharingOfferSent =>
      'Oferta de compartición de vehículo enviada';

  @override
  String get activityLogKindVehicleSharingOfferReceived =>
      'Oferta de compartición de vehículo recibida';

  @override
  String get activityLogKindVehicleSharingOfferResponse =>
      'Respuesta a oferta de compartición de vehículo';

  @override
  String get activityLogKindVehicleSharingOfferExpired =>
      'Oferta de compartición de vehículo caducada';

  @override
  String get activityLogKindVehicleSharingRevokeSent =>
      'Acceso de compartido revocado (enviado)';

  @override
  String get activityLogKindVehicleSharingRevokeReceived =>
      'Acceso de compartido revocado (recibido)';

  @override
  String get activityLogKindVehicleSharingReactivateProposeSent =>
      'Reactivación de compartido propuesta (enviada)';

  @override
  String get activityLogKindVehicleSharingReactivateProposeReceived =>
      'Reactivación de compartido propuesta (recibida)';

  @override
  String get activityLogKindVehicleSharingReactivateAcceptSent =>
      'Reactivación de compartido aceptada (enviada)';

  @override
  String get activityLogKindVehicleSharingReactivateAcceptReceived =>
      'Reactivación de compartido aceptada (recibida)';

  @override
  String get activityLogKindVehicleUseSessionStartSent =>
      'Inicio de sesión de compartición enviado';

  @override
  String get activityLogKindVehicleUseSessionStartReceived =>
      'Inicio de sesión de compartición recibido';

  @override
  String get activityLogKindVehicleUseSessionEndSent =>
      'Fin de sesión de compartición enviada';

  @override
  String get activityLogKindVehicleUseSessionEndReceived =>
      'Fin de sesión de compartición recibida';

  @override
  String get activityLogKindVehicleUseSessionEndByOwnerSent =>
      'Fin de sesión forzada por el propietario (enviada)';

  @override
  String get activityLogKindVehicleUseSessionEndByOwnerReceived =>
      'Fin de sesión forzada por el propietario (recibida)';

  @override
  String get housingInvitePlanActivating =>
      'Todos los participantes han aceptado. Activando el acuerdo…';

  @override
  String get housingInviteProposalAppBarTitle => 'Propuesta de invitación';

  @override
  String get housingInviteProposalIntroTitle =>
      'Esta es la propuesta que se enviará a cada uno de tus participantes.';

  @override
  String get housingInviteProposalSentIntroTitle =>
      'Esta es la propuesta enviada a cada uno de tus participantes.';

  @override
  String get housingInviteParticipantsSectionTitle => 'Participantes';

  @override
  String get housingInviteExpensesSectionTitle => 'Gastos y reparto';

  @override
  String get housingInviteRulesSectionTitle => 'Normas del acuerdo';

  @override
  String get housingInviteStatusAccepted => 'Aceptado';

  @override
  String get housingInviteStatusPending => 'Pendiente';

  @override
  String get housingInviteStatusNegotiating => 'En negociación';

  @override
  String get housingInviteStatusRejected => 'Rechazado';

  @override
  String get housingInviteAcceptFull => 'Acepto en su totalidad';

  @override
  String get housingInviteMissingContactsAction => 'Contactos faltantes';

  @override
  String housingInviteMissingContactsRedeemBanner(String name) {
    return 'Para aceptar este plan, conéctate primero con $name. Introduce su código de invitación abajo.';
  }

  @override
  String get housingInviteMissingContactsBlocked =>
      'Conéctate con cada co-participante antes de poder aceptar.';

  @override
  String get housingPlanMissingContactsTitle => 'Contactos del plan';

  @override
  String get housingPlanMissingContactsIntro =>
      'Cada co-participante debe ser un contacto conectado en este dispositivo antes de que puedas aceptar el plan. Pulsa Establecer contacto para quien aún te falte.';

  @override
  String get housingPlanMissingContactsEmpty =>
      'Este plan no tiene otros participantes en este dispositivo.';

  @override
  String get housingPlanMissingContactsAllReady =>
      'Todos los co-participantes están conectados. Puedes volver atrás y aceptar el plan.';

  @override
  String get housingPlanMissingContactsEstablishContact =>
      'Establecer contacto';

  @override
  String get housingPlanMissingContactsPendingOutbound =>
      'Solicitud enviada — esperando su respuesta.';

  @override
  String housingPlanMissingContactsRefusedAt(String when) {
    return 'Rechazado $when';
  }

  @override
  String housingPlanMissingContactsInboundPrompt(String requester) {
    return '$requester desea establecer contacto contigo para este plan de vivienda.';
  }

  @override
  String get housingPlanMissingContactsAccept => 'Aceptar';

  @override
  String get housingPlanMissingContactsRefuse => 'Rechazar';

  @override
  String get housingInviteNegotiate => 'Me gustaría negociar';

  @override
  String get housingInviteRejectBlock => 'Rechazo por completo';

  @override
  String get housingInviteNegotiateMessageLabel =>
      'Mensaje a enviar con la solicitud de negociación';

  @override
  String get housingInviteResponseSent => 'Respuesta enviada.';

  @override
  String get housingArchiveEntryTitle => 'Planes de vivienda';

  @override
  String get housingArchiveEntryBody =>
      'Elija una propuesta para revisar, edite un borrador o cree un plan nuevo.';

  @override
  String get housingArchiveNegotiatingTitle => 'Plan en negociación';

  @override
  String housingArchivePendingTitle(int count) {
    return 'Plan en espera de $count respuesta(s)';
  }

  @override
  String get housingArchiveRejectedTitle => 'Plan rechazado';

  @override
  String get housingArchiveAmendmentRejectedTitle => 'Modificación rechazada';

  @override
  String get housingArchiveDraftTitle => 'Borrador de plan';

  @override
  String housingArchiveDraftParticipantsTitle(int count) {
    return 'Plan de $count participantes';
  }

  @override
  String get housingArchiveCreateDerivedAction => 'Crear una versión derivada';

  @override
  String get housingArchiveEditDraftAction => 'Editar';

  @override
  String get housingArchiveViewAction => 'Ver';

  @override
  String get housingArchiveCreateNewPlan => 'Crear un nuevo plan';

  @override
  String get housingArchiveForkPromptTitle => 'Su respuesta fue enviada.';

  @override
  String get housingArchiveForkPromptBody =>
      '¿Quiere crear una versión derivada de esta propuesta ahora para hacer sus cambios?';

  @override
  String get housingArchiveForkPromptLaterHint =>
      'Puede hacerlo más tarde desde el menú principal.';

  @override
  String get housingArchiveForkLaterAction => 'Más tarde';

  @override
  String get housingArchiveForkPromptCreateAction => 'Crear';

  @override
  String get housingInviteProposalLockedHint =>
      'Otro participante está negociando o ha rechazado esta propuesta. Las respuestas quedan en pausa hasta revisar el plan.';

  @override
  String get housingInviteInvitationStatusAction =>
      'Estado de las invitaciones';

  @override
  String get housingInviteStatusDialogTitle => 'Estado de las invitaciones';

  @override
  String housingInviteStatusSentAtLabel(String when) {
    return 'Enviado: $when';
  }

  @override
  String housingInviteStatusDeadlineLabel(String when) {
    return 'Plazo de respuesta: $when';
  }

  @override
  String get housingInviteStatusDeadlineNotSet => 'Sin definir';

  @override
  String get housingInviteStatusTableSectionTitle => 'Invitados';

  @override
  String get housingInviteStatusTableInvitee => 'Invitado';

  @override
  String get housingInviteStatusTableStatus => 'Estado';

  @override
  String get housingInviteStatusMessagesSectionTitle => 'Mensajes';

  @override
  String get housingInviteStatusNoPending =>
      'No hay invitación pendiente para este plan.';

  @override
  String housingInviteTransportSent(int sentCount) {
    return 'Propuesta enviada a $sentCount participante(s).';
  }

  @override
  String housingInviteTransportPartial(int sentCount, int failedCount) {
    return 'Propuesta enviada a $sentCount participante(s); no se pudo contactar a $failedCount participante(s).';
  }

  @override
  String get housingInviteTransportFailed =>
      'No se pudo entregar la propuesta a ningún participante. Puede editar el plan e intentarlo de nuevo.';

  @override
  String get housingInviteResendProposalAction => 'Reenviar propuesta';

  @override
  String get housingInviteViewSentProposalAction => 'Ver propuesta enviada';

  @override
  String get housingInviteReceivedWhileEditingSnack =>
      'Ha recibido una propuesta de vivienda de un participante.';

  @override
  String get housingInviteReceivedOpenAction => 'Ver';

  @override
  String get pushNotificationHousingProposalTitle => 'Propuesta de vivienda';

  @override
  String get pushNotificationHousingProposalBody =>
      'Abra la aplicación para revisar la propuesta.';

  @override
  String get pushNotificationVehicleSharingOfferTitle =>
      'Oferta de uso compartido de vehículo';

  @override
  String get pushNotificationVehicleSharingOfferBody =>
      'Abra Uso compartido de vehículo para revisar la oferta.';

  @override
  String pushNotificationVehicleSharingOfferBodyFrom(
    String name,
    String vehicle,
  ) {
    return '$name le ofrece compartir $vehicle.';
  }

  @override
  String get pushNotificationVehicleSharingOfferAcceptTitle =>
      'Uso compartido de vehículo aceptado';

  @override
  String get pushNotificationVehicleSharingOfferAcceptBody =>
      'Abra Uso compartido de vehículo para ver el compartido activo.';

  @override
  String pushNotificationVehicleSharingOfferAcceptBodyFrom(
    String name,
    String vehicle,
  ) {
    return '$name aceptó compartir $vehicle.';
  }

  @override
  String get pushNotificationVehicleSharingRevokeTitle =>
      'Acceso de compartido revocado';

  @override
  String pushNotificationVehicleSharingRevokeBody(String name, String vehicle) {
    return '$name revocó su acceso de compartido del vehículo $vehicle';
  }

  @override
  String get pushNotificationVehicleSharingReactivateProposeTitle =>
      'Reactivación de compartido';

  @override
  String pushNotificationVehicleSharingReactivateProposeBody(
    String name,
    String vehicle,
  ) {
    return '$name reactivó su acceso de compartido del vehículo $vehicle';
  }

  @override
  String get pushNotificationVehicleSharingReactivateAcceptTitle =>
      'Reactivación aceptada';

  @override
  String pushNotificationVehicleSharingReactivateAcceptBody(
    String name,
    String vehicle,
  ) {
    return '$name aceptó la reactivación del compartido de $vehicle.';
  }

  @override
  String get pushNotificationVehicleUseSessionEndByOwnerTitle =>
      'Sesión cerrada';

  @override
  String pushNotificationVehicleUseSessionEndByOwnerBody(String name) {
    return 'Su sesión de uso fue cerrada por el $name';
  }

  @override
  String get pushNotificationVehicleSessionGapTitle =>
      'Posible diferencia de kilometraje';

  @override
  String get pushNotificationVehicleSessionGapBody =>
      'Es posible que una sesión no se haya cerrado. Abra las correcciones pendientes para revisar la lectura.';

  @override
  String pushNotificationVehicleSessionGapBodyFrom(
    String name,
    String vehicle,
  ) {
    return '$name inició una sesión en $vehicle. Es posible que una sesión anterior siga abierta.';
  }

  @override
  String get pushNotificationVehicleMaintenanceTitle =>
      'Mantenimiento registrado';

  @override
  String get pushNotificationVehicleMaintenanceBody =>
      'Un prestatario registró un mantenimiento en un vehículo compartido.';

  @override
  String pushNotificationVehicleMaintenanceBodyFrom(
    String name,
    String vehicle,
  ) {
    return '$name registró un mantenimiento en $vehicle.';
  }

  @override
  String get pushNotificationVehicleTrafficViolationTitle =>
      'Daño o infracción';

  @override
  String get pushNotificationVehicleTrafficViolationBody =>
      'Un prestatario registró un daño o una infracción en un vehículo compartido.';

  @override
  String pushNotificationVehicleTrafficViolationBodyFrom(
    String name,
    String vehicle,
  ) {
    return '$name registró un daño o una infracción en $vehicle.';
  }

  @override
  String get pushNotificationUsageBalanceFreezeProposeTitle => 'Fijar el saldo';

  @override
  String pushNotificationUsageBalanceFreezeProposeBody(String name) {
    return '$name pide fijar el saldo de uso.';
  }

  @override
  String get pushNotificationUsageBalanceFreezeAcceptedTitle => 'Saldo fijado';

  @override
  String pushNotificationUsageBalanceFreezeAcceptedBody(String name) {
    return '$name aceptó fijar el saldo de uso.';
  }

  @override
  String get pushNotificationUsageBalanceFreezeRejectedTitle =>
      'Fijación rechazada';

  @override
  String pushNotificationUsageBalanceFreezeRejectedBody(String name) {
    return '$name rechazó fijar el saldo de uso.';
  }

  @override
  String get pushNotificationUsageBalanceTransferProposeTitle =>
      'Transferencia declarada';

  @override
  String pushNotificationUsageBalanceTransferProposeBody(String name) {
    return '$name declaró una transferencia para el saldo de uso.';
  }

  @override
  String get pushNotificationUsageBalanceTransferAcceptedTitle =>
      'Transferencia aceptada';

  @override
  String pushNotificationUsageBalanceTransferAcceptedBody(String name) {
    return '$name confirmó la recepción de la transferencia.';
  }

  @override
  String get pushNotificationUsageBalanceTransferRejectedTitle =>
      'Transferencia rechazada';

  @override
  String pushNotificationUsageBalanceTransferRejectedBody(String name) {
    return '$name rechazó la declaración de transferencia.';
  }

  @override
  String get vehicleSharingOfferRelayFailed =>
      'Oferta guardada aquí, pero el envío al contacto falló. Inténtelo más tarde.';

  @override
  String get vehicleSharingAcceptRelayFailed =>
      'Aceptación guardada aquí, pero el envío al propietario falló. Inténtelo más tarde.';

  @override
  String get pushNotificationHousingAgreementActivatedTitle =>
      'Acuerdo unánime';

  @override
  String get pushNotificationHousingAgreementActivatedBody =>
      'Su grupo ha alcanzado un acuerdo de vivienda unánime.';

  @override
  String get pushNotificationHousingRealizedExpenseTitle => 'Gasto por revisar';

  @override
  String get pushNotificationHousingRealizedExpenseBody =>
      'Un participante envió un gasto para su acuerdo.';

  @override
  String pushNotificationHousingRealizedExpenseBodyFrom(String name) {
    return '$name envió un gasto por revisar.';
  }

  @override
  String get pushNotificationHousingRealizedExpenseAcceptedTitle =>
      'Gasto aceptado';

  @override
  String get pushNotificationHousingRealizedExpenseAcceptedBody =>
      'Un participante aceptó su gasto.';

  @override
  String pushNotificationHousingRealizedExpenseAcceptedBodyFrom(String name) {
    return '$name aceptó su gasto.';
  }

  @override
  String pushNotificationHousingRealizedExpenseAcceptedBodyFromPeer(
    String name,
    String payer,
  ) {
    return '$name aceptó el gasto de $payer.';
  }

  @override
  String get pushNotificationHousingRealizedTransferAcceptedTitle =>
      'Transferencia aceptada';

  @override
  String get pushNotificationHousingRealizedTransferAcceptedBody =>
      'Un participante aceptó su transferencia.';

  @override
  String pushNotificationHousingRealizedTransferAcceptedBodyFrom(String name) {
    return '$name aceptó su transferencia.';
  }

  @override
  String pushNotificationHousingRealizedTransferAcceptedBodyFromPeer(
    String name,
    String payer,
  ) {
    return '$name aceptó la transferencia de $payer.';
  }

  @override
  String get pushNotificationHousingRealizedExpenseRejectedTitle =>
      'Gasto rechazado';

  @override
  String get pushNotificationHousingRealizedExpenseRejectedBody =>
      'Un participante rechazó su gasto.';

  @override
  String pushNotificationHousingRealizedExpenseRejectedBodyFrom(String name) {
    return '$name rechazó su gasto.';
  }

  @override
  String get pushNotificationHousingDecisionTitle =>
      'Respuesta a una propuesta de vivienda';

  @override
  String get pushNotificationHousingDecisionBody =>
      'Un participante respondió a una propuesta de vivienda.';

  @override
  String pushNotificationHousingDecisionBodyFrom(String name) {
    return '$name respondió a una propuesta de vivienda.';
  }

  @override
  String get pushNotificationHousingAmendmentDecisionTitle =>
      'Respuesta a una solicitud de cambio';

  @override
  String get pushNotificationHousingAmendmentDecisionBody =>
      'Un participante respondió a una solicitud de cambio del acuerdo.';

  @override
  String pushNotificationHousingAmendmentDecisionBodyFrom(String name) {
    return '$name respondió a una solicitud de cambio del acuerdo.';
  }

  @override
  String get pushNotificationHousingPaymentReminderBeforeDueTitle =>
      'Recordatorio de pago';

  @override
  String pushNotificationHousingPaymentReminderBeforeDueBody(String lineTitle) {
    return 'Pronto vence $lineTitle.';
  }

  @override
  String get pushNotificationHousingPaymentReminderOverdueTitle =>
      'Pago atrasado';

  @override
  String pushNotificationHousingPaymentReminderOverdueBody(String lineTitle) {
    return 'El pago de $lineTitle no se completó para este período.';
  }

  @override
  String get pushNotificationContactInvitationBeforeExpiryTitle =>
      'Invitación a punto de caducar';

  @override
  String get pushNotificationContactInvitationBeforeExpiryBody =>
      'Una invitación pendiente caducará pronto.';

  @override
  String get pushNotificationContactInvitationExpiredTitle =>
      'Invitación caducada';

  @override
  String get pushNotificationContactInvitationExpiredBody =>
      'Una invitación no se usó y ha caducado.';

  @override
  String get pushNotificationHousingProposalDeadlineTitle =>
      'Plazo de propuesta próximo';

  @override
  String get pushNotificationHousingProposalDeadlineBody =>
      'Una oferta de plan de vivienda caduca pronto. Abre Vivienda para responder o comprobar el estado.';

  @override
  String get pushNotificationHousingTrialStartedTitle =>
      'Prueba de vivienda iniciada';

  @override
  String pushNotificationHousingTrialStartedBody(String date) {
    return 'Puede usar vivienda hasta el $date. Las compras están en Licencias.';
  }

  @override
  String get pushNotificationHousingTrialReminderTitle =>
      'Recordatorio de prueba de vivienda';

  @override
  String pushNotificationHousingTrialWeekLeftBody(String date) {
    return 'La prueba de vivienda termina el $date (quedan 7 días). Abra Licencias cuando esté listo.';
  }

  @override
  String pushNotificationHousingTrialDaysLeftBody(int days, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'La prueba de vivienda termina el $date ($days días restantes). Abra Licencias cuando esté listo.',
      one:
          'La prueba de vivienda termina el $date (1 día restante). Abra Licencias cuando esté listo.',
    );
    return '$_temp0';
  }

  @override
  String get pushNotificationHousingGraceReminderTitle =>
      'Periodo de gracia de vivienda';

  @override
  String pushNotificationHousingGraceReminderBody(int days, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'Quedan $days días (hasta el $date) para suscribirse en Licencias. La vivienda sigue utilizable.',
      one:
          'Queda 1 día (hasta el $date) para suscribirse en Licencias. La vivienda sigue utilizable.',
    );
    return '$_temp0';
  }

  @override
  String get notificationHousingPaymentRemindersLabel =>
      'Recordatorios de pago';

  @override
  String housingOverdueJournalCardBody(String lineTitle) {
    return 'El pago de $lineTitle no se completó para este período.';
  }

  @override
  String housingBeforeDueJournalCardBody(
    String dueDate,
    String lineTitle,
    String amount,
  ) {
    return 'Recordatorio del vencimiento del $dueDate\n$lineTitle - $amount';
  }

  @override
  String housingDueDayJournalCardBody(String lineTitle, String amount) {
    return 'Recordatorio del vencimiento de hoy\n$lineTitle - $amount';
  }

  @override
  String get pushNotificationHousingResponseFailureRelayUnavailableBody =>
      'El servidor de relevo no está disponible temporalmente.';

  @override
  String get pushNotificationHousingResponseFailureUnknownBody =>
      'No se encontró la propuesta a la que intentas responder. Puede haber varios motivos. Contacta directamente con la persona.';

  @override
  String get pushNotificationHousingResponseFailureSendBody =>
      'Se produjo un error al enviar la respuesta.';

  @override
  String get pushNotificationHousingResponseFailureLocalErrorBody =>
      'Se produjo un error desconocido.';

  @override
  String get pushNotificationContactAddRequestTitle => 'Solicitud de contacto';

  @override
  String pushNotificationContactAddRequestBody(String name) {
    return '$name quiere conectarse contigo.';
  }

  @override
  String pushNotificationContactAddedViaInvitationBody(String name) {
    return '$name ya está en tus contactos.';
  }

  @override
  String get pushNotificationContactDuplicateModuleAnchorRejectedBody =>
      'La persona con la que intentaste conectarte ya tiene tu contacto. Debes restaurar tus datos antes de volver a conectarte.';

  @override
  String get contactsDuplicateDialogOk => 'OK';

  @override
  String get contactsDuplicateReadMore => 'Leer más sobre esto';

  @override
  String get contactsDuplicateAnchorHousingActive =>
      'un plan de vivienda activo';

  @override
  String get contactsDuplicateAnchorVehicleSharing =>
      'un uso compartido de vehículo';

  @override
  String get contactsDuplicateAnchorHousingAndVehicle =>
      'Texto por determinar para el caso Vivienda Y Vehículo';

  @override
  String contactsDuplicateInviterRejectedIntro(String anchor) {
    return 'El contacto que acaba de usar un código de invitación ya estaba en tus contactos. Es un duplicado. El contacto existente está vinculado a $anchor.';
  }

  @override
  String get contactsDuplicateInviterNotAdded =>
      'El contacto NO se ha añadido.';

  @override
  String get contactsDuplicateInviterInformRestore =>
      'Indícale que debe restaurar sus datos en su dispositivo para restablecer la conexión contigo.';

  @override
  String get contactsDuplicateInviterMergedBody =>
      'El contacto que acaba de usar un código de invitación ya estaba en tus contactos. Se ha asociado al contacto existente.';

  @override
  String contactsDuplicateInviteeRejectedIntro(String anchor) {
    return 'La persona con la que intentaste conectarte ya tiene tu contacto. Estás vinculado a $anchor.';
  }

  @override
  String get contactsDuplicateInviteeMustRestore =>
      'DEBES restaurar tus datos. Eso es lo que debes hacer para restablecer correctamente el contacto.';

  @override
  String get contactsDuplicateInviteeRejectedBannerBody =>
      'No se puede restablecer la conexión de esta manera porque participas en un plan de uso compartido.';

  @override
  String pushNotificationContactAddRequestAcceptedBody(String name) {
    return 'Tu solicitud de conexión con $name fue aceptada.';
  }

  @override
  String pushNotificationContactAddRequestRejectedBody(String name) {
    return 'Tu solicitud de conexión con $name fue rechazada.';
  }

  @override
  String get pushNotificationContactAddRequestExpiredCodeBody =>
      'El código de conexión que usaste ha caducado.';

  @override
  String get pushNotificationContactAddRequestInvalidCodeBody =>
      'El código de conexión que usaste no es válido.';

  @override
  String get pushNotificationContactAddRequestRelayErrorBody =>
      'Se produjo un error en el servidor de relevo. Inténtalo de nuevo.';

  @override
  String get pushNotificationContactAddRequestRelayUnavailableBody =>
      'El servidor de relevo no está disponible temporalmente.';

  @override
  String get pushNotificationContactAddRequestUnknownFailureBody =>
      'Tu solicitud de conexión falló.';

  @override
  String pushNotificationPlanPeerEstablishmentRequestBody(
    String requester,
    String proposer,
  ) {
    return '$requester desea establecer contacto contigo, en el contexto de la propuesta de vivienda de $proposer.';
  }

  @override
  String get pushNotificationContactDisconnectionTitle =>
      'Contacto desconectado';

  @override
  String pushNotificationContactDisconnectionBody(String name) {
    return '$name se desconectó de ti.';
  }

  @override
  String get housingInviteGenerateCodes => 'Generar códigos de invitación';

  @override
  String get housingInviteCodesDialogTitle => 'Códigos de invitación';

  @override
  String get housingInviteCodesDialogBody =>
      'Cada código es para un co-participante. Compártelos como prefieras; el registro en el servidor relé se añadirá más adelante.';

  @override
  String get housingInviteCodesCopyAll => 'Copiar todo';

  @override
  String get housingInviteCodesCopied => 'Copiado al portapapeles';

  @override
  String get housingInviteRuleOffHint =>
      'Esta norma está desactivada en esta propuesta.';

  @override
  String get housingInviteWithdrawalPerParticipantIntro =>
      'Preaviso y penalización varían por participante (ver abajo).';

  @override
  String get housingInviteHousingAgreementTitle => 'Acuerdo de vivienda';

  @override
  String get housingInviteDateRangeSeparator => ' a ';

  @override
  String get housingInviteSunburstCenterLabel => 'En conjunto';

  @override
  String housingInviteSunburstCenterParticipation(String pct) {
    return 'Participación global $pct %';
  }

  @override
  String get housingInviteViewExpensesDetail => 'Ver gastos en detalle';

  @override
  String get housingInviteExpensesDetailTitle => 'Gastos en detalle';

  @override
  String get housingInviteExpensesDetailSwipeHint =>
      'Deslice a la izquierda o derecha para ver cada gasto.';

  @override
  String housingInviteExpensesDetailPageIndicator(int current, int total) {
    return '$current de $total';
  }

  @override
  String get housingInviteExpensesDetailLoadError =>
      'No se pudo cargar este gasto.';

  @override
  String get housingInviteExpensesDetailPrevious => 'Gasto anterior';

  @override
  String get housingInviteExpensesDetailNext => 'Gasto siguiente';

  @override
  String housingExpenseSunburstBudgetLabel(String name) {
    return '$name (presupuesto máx.)';
  }

  @override
  String get housingInviteSunburstEmptyHint =>
      'No hay datos de gastos para este gráfico en este plan.';

  @override
  String housingInviteSunburstLegendAgreementShare(String name, String pct) {
    return '$name - $pct % del acuerdo';
  }

  @override
  String get housingInviteSunburstMonthlyNormalizedFootnote =>
      'Importe mensualizado (equivalente a 30 días).';

  @override
  String housingInviteSunburstLegendYouParticipation(
    String participantName,
    String userAmount,
    String totalAmount,
    String pct,
  ) {
    return 'Parte de $participantName: $userAmount/$totalAmount ($pct %)';
  }

  @override
  String get housingPlanSummaryDestroy => 'Eliminar plan';

  @override
  String get housingPlanDestroyTitle => 'Eliminar plan';

  @override
  String get housingPlanDestroyBody =>
      'Esto elimina en este dispositivo este plan de vivienda, los gastos, las ratios, el acuerdo y los participantes borrador.';

  @override
  String get housingPlanDestroyConfirm => 'Eliminar';

  @override
  String get housingPlanRemovedSnackbar => 'Plan eliminado';

  @override
  String get housingPlanAddCategoryTitle => 'Añadir categoría';

  @override
  String get housingPlanEditCategoryTitle => 'Editar categoría';

  @override
  String get housingPlanCategoryNameLabel => 'Nombre de la categoría';

  @override
  String get housingPlanCategoryDescriptionLabel =>
      'Qué debe incluir esta categoría (opcional)';

  @override
  String get housingPlanSave => 'Guardar';

  @override
  String get housingPlanAddExpenseTitle => 'Añadir gasto';

  @override
  String get housingPlanEditExpenseTitle => 'Editar gasto';

  @override
  String get housingPlanRecurringSwitch => 'Recurrente';

  @override
  String get housingPlanApproximateAmountSwitch => 'Importe aproximado';

  @override
  String get housingPlanExpenseTitleLabel => 'Título';

  @override
  String get housingPlanCategoryOptionalLabel => 'Categoría (opcional)';

  @override
  String get housingPlanCategoryNone => 'Ninguna';

  @override
  String get housingPlanExpenseDescriptionLabel => 'Descripción (opcional)';

  @override
  String get housingPlanDayOfMonthLabel => 'Día del mes';

  @override
  String get housingPlanMinLabel => 'Mín';

  @override
  String get housingPlanMaxLabel => 'Máx';

  @override
  String get housingPlanAmountLabel => 'Importe';

  @override
  String get housingExpenseNameLabel => 'Nombre';

  @override
  String get housingExpenseAmountTypeLabel => 'Tipo de importe';

  @override
  String get housingExpenseAmountDetermined => 'Determinado';

  @override
  String get housingExpenseAmountBudgetMax => 'Presupuestado (máx.)';

  @override
  String get housingExpensePaymentResponsibleLabel => 'Responsable del pago';

  @override
  String get housingExpensePaymentResponsibleAll => 'Todos';

  @override
  String get housingExpenseSplitSectionTitle => 'Reparto';

  @override
  String get housingExpenseEqualParts => 'Partes iguales';

  @override
  String get housingExpenseLikeLabel => 'Como para';

  @override
  String get housingExpenseLikeBlankHint => '—';

  @override
  String get housingExpenseSplitAmountColumn => 'Importe';

  @override
  String get housingExpenseSplitParticipantColumn => 'Participante';

  @override
  String get housingExpenseSplitPercentColumn => 'Parte';

  @override
  String get housingExpenseSplitCorrectRow => '¡Corrija!';

  @override
  String get housingExpenseRecurrenceTapToSet => 'Definir recurrencia';

  @override
  String get housingExpenseRecurrenceSet => 'Recurrencia definida';

  @override
  String get housingExpenseRecurrenceConfirmTitle => 'Confirmar recurrencia';

  @override
  String housingExpenseRecurrenceMonthlyDay(int day, String anchor) {
    return 'El día $day de cada mes, desde $anchor';
  }

  @override
  String get housingExpenseRecurrenceUseRange => 'Usar';

  @override
  String housingExpenseRecurrenceEveryNDays(int days, String anchor) {
    return 'Cada $days días, a partir del $anchor';
  }

  @override
  String housingExpenseRecurrenceNthWeekdayOfMonth(
    String ordinal,
    String weekday,
    String anchor,
  ) {
    return '$ordinal $weekday del mes, desde $anchor';
  }

  @override
  String get housingRecurrenceOrdinalFirst => 'Primer';

  @override
  String get housingRecurrenceOrdinalSecond => 'Segundo';

  @override
  String get housingRecurrenceOrdinalThird => 'Tercer';

  @override
  String get housingRecurrenceOrdinalFourth => 'Cuarto';

  @override
  String get housingRecurrenceOrdinalFifth => 'Quinto';

  @override
  String get housingRecurrenceWeekdayMonday => 'lunes';

  @override
  String get housingRecurrenceWeekdayTuesday => 'martes';

  @override
  String get housingRecurrenceWeekdayWednesday => 'miércoles';

  @override
  String get housingRecurrenceWeekdayThursday => 'jueves';

  @override
  String get housingRecurrenceWeekdayFriday => 'viernes';

  @override
  String get housingRecurrenceWeekdaySaturday => 'sábado';

  @override
  String get housingRecurrenceWeekdaySunday => 'domingo';

  @override
  String get housingExpenseEnterAmountForSplit =>
      'Introduzca un importe para este gasto';

  @override
  String housingPlanDurationMonthsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count meses',
      one: '1 mes',
    );
    return '$_temp0';
  }

  @override
  String housingPlanDurationDaysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count días',
      one: '1 día',
    );
    return '$_temp0';
  }

  @override
  String get carSharingPlanTitle => 'Plan de coche compartido';

  @override
  String get carSharingPlanFinish => 'Listo';

  @override
  String carSharingOwnerPrompt(String name) {
    return '$name: indica si es tu vehículo o un alquiler.';
  }

  @override
  String get carSharingStepVehicle => 'Vehículo';

  @override
  String get carSharingStepOwner => 'Propietario';

  @override
  String get carSharingStepParticipants => 'Participantes';

  @override
  String get carSharingStepInsurance => 'Seguro y matrícula';

  @override
  String get carSharingStepCurrentState => 'Estado actual';

  @override
  String get carSharingStepMaintenance => 'Mantenimiento previsto';

  @override
  String get carSharingStepAvailability => 'Disponibilidad ofrecida';

  @override
  String get carSharingStepFuel => 'Gestión de combustible';

  @override
  String get carSharingStepClauses => 'Otras cláusulas';

  @override
  String get carSharingFieldMake => 'Marca';

  @override
  String get carSharingFieldModel => 'Modelo';

  @override
  String get carSharingFieldColor => 'Color';

  @override
  String get carSharingFieldYear => 'Año';

  @override
  String get carSharingOwnerIsOwner => 'Vehículo propio';

  @override
  String get carSharingOwnerIsRental => 'Vehículo de alquiler';

  @override
  String get carSharingRentalSharePermission =>
      'Derecho de compartir obtenido del arrendador';

  @override
  String get carSharingRentalContractCopy =>
      'Entregará copia del contrato de alquiler al aceptar el acuerdo';

  @override
  String get carSharingInsuranceNotify =>
      'Informará a las aseguradoras al aceptar el acuerdo';

  @override
  String get carSharingInsuranceAssumeIncrease =>
      'Asumirá un posible aumento de prima (si no, y sube la prima, el acuerdo puede renegociarse)';

  @override
  String get carSharingInsuranceProvideDocs =>
      'Entregará copias de seguro y matrícula al aceptar el acuerdo';

  @override
  String get carSharingEstimatedValueLabel => 'Valor estimado';

  @override
  String get carSharingPhotoFront => 'Foto frontal — ruta (opcional)';

  @override
  String get carSharingPhotoLeft => 'Foto lado izquierdo — ruta (opcional)';

  @override
  String get carSharingPhotoRight => 'Foto lado derecho — ruta (opcional)';

  @override
  String get carSharingPhotoRear => 'Foto trasera — ruta (opcional)';

  @override
  String get carSharingPhotoSeatsFront =>
      'Foto asientos delanteros — ruta (opcional)';

  @override
  String get carSharingPhotoSeatsRear =>
      'Foto asientos traseros — ruta (opcional)';

  @override
  String get carSharingPhotoDashboard => 'Foto salpicadero — ruta (opcional)';

  @override
  String get carSharingPhotoOdometer => 'Foto odómetro — ruta (opcional)';

  @override
  String get carSharingMaintenanceIntro =>
      'Como los gastos del plan de vivienda; contarán en la categoría «mantenimiento».';

  @override
  String get carSharingMaintenanceAdd => 'Añadir mantenimiento';

  @override
  String get carSharingMaintenanceEditTitle => 'Editar mantenimiento';

  @override
  String get carSharingMaintenanceEmpty =>
      'Aún no hay partidas de mantenimiento.';

  @override
  String get carSharingMaintenanceTitleLabel => 'Título';

  @override
  String get carSharingMaintenanceAmountLabel => 'Importe';

  @override
  String get carSharingAvailabilityIntro =>
      'Marca medias horas en las que el coche se ofrece a los coparticipantes; el resto del tiempo queda para el propietario.';

  @override
  String get carSharingAvailabilityAvailable => 'Ofrecido a coparticipantes';

  @override
  String get carSharingAvailabilityOwner => 'Uso del propietario';

  @override
  String get carSharingFuelIntro =>
      'Con el seguimiento en la app, cada compra guarda: fecha/hora, coste total, volumen, odómetro y si fue llenado completo. Los llenados completos anclan el consumo entre repostajes. El odómetro también sirve para la distancia por uso.';

  @override
  String get carSharingFuelUseAppTracking =>
      'Usar seguimiento de combustible y odómetro de la app';

  @override
  String get carSharingFuelCustomHint =>
      'Describe otro modo (no gestionado por la app)';

  @override
  String get carSharingClausesIntro =>
      'Cláusulas opcionales y sugerencias. No se incluyen reglas específicas de vivienda (toque de queda, retirada anticipada, edificio).';

  @override
  String get contactsTitle => 'Contactos';

  @override
  String get contactsPickerTitle => 'Elegir un contacto';

  @override
  String get contactsPickerEmptyTitle => 'Aún no hay contactos seleccionables';

  @override
  String get contactsPickerEmptyBody =>
      'Invita a las personas y completa la conexión en Contactos primero. Solo los contactos conectados pueden unirse a este módulo.';

  @override
  String get contactsEmptyTitle => 'Aún no hay contactos';

  @override
  String get contactsEmptyBody =>
      'Invita a alguien y conéctate mediante el relevo. Los contactos conectados se reutilizan entre módulos.';

  @override
  String get contactsAddContactAction => 'Invitar a alguien';

  @override
  String get contactsAddLocalOnlyAction => 'Añadir contacto local';

  @override
  String get contactsAddLocalOnlyTitle => 'Nuevo contacto';

  @override
  String get contactsEditTitle => 'Editar contacto';

  @override
  String get contactsDetailTitle => 'Contacto';

  @override
  String get contactsDetailMissing => 'Este contacto ya no existe.';

  @override
  String get contactsInviteAction => 'Invitar a un contacto';

  @override
  String get contactsInviteTitle => 'Invitar a un contacto';

  @override
  String get contactsInviteIntroTitle => 'Compartir un código de un solo uso';

  @override
  String get contactsInviteIntroBody =>
      'Genera un código de un solo uso y compártelo fuera de la app (SMS, correo, en persona). Quien reciba el código podrá añadirse a tus contactos mientras el código sea válido.';

  @override
  String get contactsInviteValidityLabel => 'Código válido durante';

  @override
  String get contactsInviteGenerateAction => 'Generar código';

  @override
  String get contactsInviteShareWarning =>
      'Comparte este código solo con una persona. Expira automáticamente y deja de funcionar tras su uso o revocación.';

  @override
  String get contactsInviteQrLabel =>
      'Escanea este código QR desde el otro dispositivo, o usa el código de texto de abajo.';

  @override
  String get contactsInviteQrSemantics => 'Código QR de invitación';

  @override
  String get contactsInviteShortCodeLabel => 'Código';

  @override
  String get contactsInviteCopyDeepLink => 'Copiar enlace';

  @override
  String get contactsInviteCopyShareText => 'Copiar invitación';

  @override
  String contactsInviteShareText(String link, String code) {
    return 'Te invitan a conectarte en Bojairũ.\n\nCódigo de un solo uso:\n$code\n\nPara usarlo: abre la app Bojairũ, ve a Contactos, toca el icono de escanear/introducir código en la parte superior de la pantalla y pega este código. Desde el dispositivo donde la app esté instalada también puedes abrir: $link';
  }

  @override
  String contactsInviteExpiresAt(String when) {
    return 'Expira $when';
  }

  @override
  String get contactsInviteDeadlineTitle => 'Validez el código hasta:';

  @override
  String get contactsInvitationStubTitle => 'Código de invitación';

  @override
  String get contactsInviteRevokeAction => 'Revocar';

  @override
  String get contactsInvitationsTitle => 'Invitaciones enviadas';

  @override
  String get contactsInvitationsEmpty => 'Aún no se han enviado invitaciones.';

  @override
  String contactsInvitationsItemTitle(String createdAt) {
    return 'Invitación · $createdAt';
  }

  @override
  String get contactsInvitationsStatusPending => 'Pendiente';

  @override
  String get contactsInvitationsStatusUsed => 'Usada';

  @override
  String get contactsInvitationsStatusExpired => 'Expirada';

  @override
  String get contactsInvitationsStatusRevoked => 'Revocada';

  @override
  String get contactsEnterInviteCodeTitle => 'Introducir un código';

  @override
  String get contactsEnterInviteCodeIntro =>
      'Pega o escribe el código recibido de un contacto.';

  @override
  String get contactsEnterInviteCodeFieldLabel => 'Código de invitación';

  @override
  String get contactsEnterInviteCodeScanQr => 'Escanear código QR';

  @override
  String get contactsEnterInviteCodeScanQrHint =>
      'Apunta la cámara a un código QR de invitación de Bojairũ.';

  @override
  String get contactsEnterInviteCodeSubmit => 'Conectar';

  @override
  String get contactsEnterInviteCodeValid => 'El formato del código es válido';

  @override
  String contactsEnterInviteCodeInvitationId(String id) {
    return 'ID de invitación: $id';
  }

  @override
  String get contactsHandshakeNotAvailableYet =>
      'El intercambio con el relevo aún no está disponible. El código es válido localmente, pero no se puede canjear hasta que el relevo esté en línea.';

  @override
  String get contactsHandshakeDispatching => 'Enviando la solicitud al relevo…';

  @override
  String get contactsHandshakeDispatched =>
      'Código aceptado. Estableciendo el contacto…';

  @override
  String get contactsHandshakeCompleted =>
      'Conectado. El contacto se ha añadido a tu lista.';

  @override
  String get contactsHandshakeRejected =>
      'La otra persona rechazó la conexión. Pídele una nueva invitación si lo necesitas.';

  @override
  String get contactsHandshakeFailed =>
      'El intento de conexión falló. Puedes reintentar con una nueva invitación.';

  @override
  String get contactsHandshakeErrorRelayUnavailable =>
      'No se puede conectar con el relevo. Verifica tu red e inténtalo de nuevo.';

  @override
  String get contactsHandshakeErrorAlreadyCompleted =>
      'Este código ya se ha utilizado.';

  @override
  String get contactsHandshakeErrorNonceConsumed =>
      'Esta invitación ya se ha canjeado.';

  @override
  String get contactsHandshakeErrorExpired => 'Esta invitación ha expirado.';

  @override
  String get contactsHandshakeErrorUnknown =>
      'Algo salió mal al contactar con el relevo.';

  @override
  String get contactsIncomingTitle => 'Solicitudes de conexión';

  @override
  String get contactsIncomingEmpty =>
      'No hay solicitudes de conexión pendientes.';

  @override
  String contactsIncomingBody(String name) {
    return '$name quiere conectarse.';
  }

  @override
  String get contactsIncomingAccept => 'Aceptar';

  @override
  String get contactsIncomingReject => 'Rechazar';

  @override
  String get contactsIncomingBannerOne => '1 nueva solicitud de conexión';

  @override
  String contactsIncomingBannerMany(int count) {
    return '$count nuevas solicitudes de conexión';
  }

  @override
  String get contactsRefreshIncomingTooltip => 'Buscar solicitudes de conexión';

  @override
  String contactsRefreshIncomingFound(int count) {
    return '$count solicitud(es) de conexión pendiente(s).';
  }

  @override
  String get contactsRefreshIncomingNone =>
      'No se encontraron solicitudes de conexión pendientes.';

  @override
  String contactsRefreshIncomingNoneWithActivePolls(int count) {
    return 'No se encontraron solicitudes de conexión pendientes. Sondeo(s) de relevo activo(s): $count.';
  }

  @override
  String contactsRefreshIncomingDiagnostics(
    int activeCount,
    int totalCount,
    String latestState,
  ) {
    return 'No se encontraron solicitudes de conexión pendientes. Sondeo(s) de relevo activo(s): $activeCount. Fila(s) handshake local(es): $totalCount. Último estado: $latestState.';
  }

  @override
  String get contactsCodeErrorEmpty => 'Introduce un código para continuar.';

  @override
  String get contactsCodeErrorTooShort => 'Este código es demasiado corto.';

  @override
  String get contactsCodeErrorTooLong => 'Este código es demasiado largo.';

  @override
  String get contactsCodeErrorInvalidCharacters =>
      'Este código contiene caracteres no permitidos.';

  @override
  String get contactsCodeErrorBadChecksum =>
      'Este código parece mal escrito. Revisa los caracteres e inténtalo de nuevo.';

  @override
  String get contactsCodeErrorUnsupportedVersion =>
      'Este código se creó con una versión más reciente de la app.';

  @override
  String get contactsKindLocalOnly => 'Solo local';

  @override
  String get contactsKindDisconnected => 'Desconectado';

  @override
  String get contactsKindConnected => 'Conectado';

  @override
  String get contactsKindBlocked => 'Bloqueado';

  @override
  String get contactsKindDeleted => 'Eliminado';

  @override
  String get contactsFieldNameLabel => 'Nombre';

  @override
  String get contactsFieldNameHint => 'Cómo aparece esta persona en la app';

  @override
  String get contactsFieldAvatarReadOnlyFootnote =>
      'Puede asignarle otro nombre.\n\nAtención: el contacto será informado en:\n    Ajustes >\n        Perfil >\n            Cómo le llaman los demás.';

  @override
  String get contactsFieldAvatarLabel => 'Avatar';

  @override
  String get contactsFieldNotesLabel => 'Notas';

  @override
  String get contactsFieldNotesHint => 'Recordatorio personal, no compartido';

  @override
  String get contactsFieldNotesFootnote =>
      'Sus notas personales. No se compartirán.';

  @override
  String get contactsDeleteTitle => '¿Eliminar este contacto?';

  @override
  String get contactsDeleteBody =>
      'Las entradas existentes (vivienda o vehículo) que hacen referencia a este contacto conservarán el nombre y el avatar guardados en el momento de su creación. Para volver a trabajar con esta persona, crea un nuevo contacto local o envíale una nueva invitación.';

  @override
  String get contactsDeletePreservesHistory =>
      'Las entradas existentes que hacen referencia a este contacto conservan su nombre y avatar.';

  @override
  String get contactsDeleteBlockedByPlansTitle =>
      'Aún no se puede eliminar este contacto';

  @override
  String contactsDeleteBlockedByPlansBody(int count, String plans) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count planes',
      one: 'un plan',
    );
    return 'Este contacto sigue figurando como participante en $_temp0: $plans. Retíralo primero de esos planes y luego podrás eliminar el contacto.';
  }

  @override
  String get contactsDeleteBlockedConnectedTitle => 'Usa Desconectar primero';

  @override
  String get contactsDeleteBlockedConnectedBody =>
      'Este contacto está actualmente conectado. Eliminarlo solo en este dispositivo dejaría a la otra persona pensando que la conexión sigue activa. Usa primero «Desconectar»: se envía una señal de desconexión cifrada al par a través del relevo y el contacto pasa a ser solo local en este dispositivo. Luego podrás eliminarlo normalmente.';

  @override
  String get contactsDeleteBlockedConnectedAction => 'Desconectar primero';

  @override
  String get contactsBlockTitle => '¿Bloquear este contacto?';

  @override
  String get contactsBlockBody =>
      'Los mensajes entrantes de este contacto se ignorarán localmente. El relevo no recibe ninguna información del bloqueo.';

  @override
  String get contactsUnblockTitle => '¿Desbloquear este contacto?';

  @override
  String get contactsUnblockBody =>
      'Los mensajes entrantes de este contacto se procesarán de nuevo.';

  @override
  String get contactsDisconnectAction => 'Desconectar';

  @override
  String get contactsDisconnectTitle => '¿Desconectar de este contacto?';

  @override
  String get contactsDisconnectBody =>
      'Se enviará un aviso de desconexión al relevo. Ambos lados volverán a ser contactos solo locales.';

  @override
  String get contactsDisconnectSent =>
      'Aviso de desconexión enviado. El contacto ahora es solo local.';

  @override
  String get contactsReconnectAction => 'Solicitar reconexión';

  @override
  String get contactsLabelEditorTitle => 'Renombrar localmente';

  @override
  String get contactsLabelEditorScreenTitle => '¿Renombrar localmente?';

  @override
  String get contactsLabelEditorHint =>
      'En blanco para conservar el nombre original';

  @override
  String get contactsFieldTheirNameLabel => 'Su nombre';

  @override
  String get settingsProfileIdentityTitle => 'Tu perfil';

  @override
  String get settingsProfileIdentitySubtitle =>
      'Nombre y avatar que ven tus contactos';

  @override
  String get settingsProfileAppearancesTitle => 'Cómo te nombran los demás';

  @override
  String get settingsProfileAppearancesBody =>
      'Cada contacto conectado puede compartir el nombre que usa para ti en su lista. Solo viaja dentro de actualizaciones de perfil cifradas.';

  @override
  String get settingsProfileAppearancesColumnPeer => 'Contacto';

  @override
  String get settingsProfileAppearancesColumnTheirLabel =>
      'Su etiqueta para ti';

  @override
  String get settingsProfileAppearancesEmpty =>
      'Aún no hay contactos conectados. Empareja con alguien para ver aquí cómo te nombran.';

  @override
  String get settingsProfileAppearancesNoSharedLabels =>
      'Ningún contacto ha compartido aún un nombre personalizado para ti en su lista.';

  @override
  String settingsProfileRenameBlockedBody(String plans) {
    return 'Formas parte de una votación de vivienda abierta en este dispositivo: $plans. Finaliza o resuelve esa votación antes de cambiar tu nombre mostrado.';
  }

  @override
  String get peerNameConflictTitle => 'El contacto cambió de nombre';

  @override
  String peerNameConflictBody(String label, String canonical) {
    return 'Muestras a este contacto como «$label». Ahora usa «$canonical» en su dispositivo.';
  }

  @override
  String get peerNameConflictUseTheirs => 'Usar su nombre';

  @override
  String get peerNameConflictKeepMine => 'Conservar mi etiqueta';

  @override
  String get housingPastHubTitle => 'Acuerdo pasado';

  @override
  String get housingParticipationChangeIntroLine1 =>
      'Un cambio de participante no es una simple modificación del acuerdo en vigor.';

  @override
  String get housingParticipationChangeIntroLine2 =>
      'Todas las opciones terminan el plan actual para quien se va.';

  @override
  String get housingParticipationChangeWithdrawalAction =>
      'Quiero retirarme del acuerdo';

  @override
  String get housingParticipationChangeEjectionAction =>
      'Quiero expulsar a un participante';

  @override
  String get housingParticipationChangeInviteParticipantAction =>
      'Quiero invitar a un participante';

  @override
  String get housingParticipationChangeInviteParticipantTitle =>
      'Invitar a un participante';

  @override
  String get housingParticipationChangeInviteParticipantBody =>
      'Añadir a alguien a un acuerdo activo exige terminar el plan actual y negociar uno nuevo con el consentimiento de todos. Consulte las preguntas frecuentes para saber por qué.';

  @override
  String get housingParticipationChangeInviteParticipantFaqLink =>
      'Ver preguntas frecuentes';

  @override
  String get helpFaqTitle => 'Preguntas frecuentes';

  @override
  String get helpFaqIntro =>
      'Respuestas a preguntas habituales sobre el funcionamiento de Bojairũ';

  @override
  String get housingVoteRefusedByAgreementExpiration =>
      'Rechazado por vencimiento del acuerdo';

  @override
  String get contactsDisconnectBlockedByPlansTitle =>
      'No se puede desconectar este contacto todavía';

  @override
  String contactsDisconnectBlockedByPlansBody(String plans) {
    return 'Este contacto forma parte de un acuerdo activo o de una votación abierta en este dispositivo: $plans. Finalice o resuelva esa actividad antes de desconectar.';
  }

  @override
  String get housingParticipationChangeConfirmAction => 'Sí';

  @override
  String get housingParticipationChangeWithdrawalConfirmTitle =>
      '¿Confirmar su retiro?';

  @override
  String housingParticipationChangeWithdrawalConfirmBody(String date) {
    return 'Fecha de salida prevista: $date. Los demás participantes deben acusar recibo del aviso en un plazo de cinco días naturales. La salida surte efecto en esa fecha una vez que todos hayan acusado recibo.';
  }

  @override
  String housingParticipationChangeWithdrawalPenaltyHint(String amount) {
    return 'Se aplica una penalización por retiro anticipado de $amount.';
  }

  @override
  String get housingEarlyWithdrawalPenaltyDescription =>
      'Penalización por salida anticipada';

  @override
  String housingEarlyWithdrawalPenaltyOwedTo(String name) {
    return 'Este importe se debe a $name.';
  }

  @override
  String get housingParticipationChangeEjectionConfirmTitle =>
      '¿Expulsar a un participante?';

  @override
  String get housingParticipationChangeEjectionConfirmBody =>
      'Los demás participantes deben aceptar. El candidato se elimina si se acepta por unanimidad.';

  @override
  String get housingParticipationChangeDetailTitle => 'Cambio mayor';

  @override
  String housingParticipationChangeDetailWithdrawalBody(
    String name,
    String date,
  ) {
    return '$name se retira del acuerdo el $date.';
  }

  @override
  String housingParticipationChangeDetailEjectionBody(
    String initiator,
    String target,
  ) {
    return '$initiator solicita expulsar a $target.';
  }

  @override
  String get housingParticipationChangeAccept => 'Aceptar';

  @override
  String get housingParticipationChangeReject => 'Rechazar';

  @override
  String get housingParticipationChangeAcknowledge => 'Acusar recibo';

  @override
  String get housingParticipationChangeAcknowledgementStatusTitle =>
      'Acuses de recibo';

  @override
  String housingParticipationChangeWithdrawalPeerNotice(
    String departureDate,
    String ackDeadline,
  ) {
    return 'Introduzca los gastos útiles antes del $departureDate. Puede acusar recibo de este aviso hasta el $ackDeadline.';
  }

  @override
  String get housingParticipationChangeEjectionCandidateNotice =>
      'Usted es la persona objetivo de esta solicitud de expulsión. Los demás participantes deben votar; no puede aceptar ni rechazar aquí.';

  @override
  String get housingParticipationChangeDecisionStatusTitle => 'Votos';

  @override
  String housingParticipationChangeDecisionPending(String name) {
    return '$name: pendiente';
  }

  @override
  String housingParticipationChangeDecisionAccepted(String name) {
    return '$name: aceptado';
  }

  @override
  String housingParticipationChangeDecisionRejected(String name) {
    return '$name: rechazado';
  }

  @override
  String get housingParticipationChangePenaltyApplies =>
      'Se aplicará una penalización por retiro anticipado.';

  @override
  String get housingParticipationChangePenaltyDoesNotApply =>
      'No se aplicará penalización por retiro anticipado.';

  @override
  String housingParticipationChangeBannerWithdrawal(String name) {
    return '$name se retira del acuerdo';
  }

  @override
  String housingParticipationChangeBannerEjection(
    String initiator,
    String target,
  ) {
    return '$initiator solicita expulsar a $target.';
  }

  @override
  String get housingParticipationChangeEjectionHubSubtitle =>
      'Solicitud de expulsión en curso...';

  @override
  String get pushNotificationHousingParticipationChangeTitle => 'Cambio mayor';

  @override
  String get pushNotificationHousingParticipationChangeBody =>
      'Un co-participante solicitó un cambio mayor.';

  @override
  String pushNotificationHousingParticipationChangeBodyFrom(String name) {
    return '$name solicitó un cambio mayor.';
  }

  @override
  String get housingParticipationJournalSubjectWithdrawal =>
      'Retiro voluntario';

  @override
  String get housingParticipationJournalSubjectEjection =>
      'Expulsión de participante';

  @override
  String get housingParticipationJournalProposed => 'Propuesto';

  @override
  String get housingParticipationJournalDecisionAccepted => 'Aceptado';

  @override
  String get housingParticipationJournalDecisionRejected => 'Rechazado';

  @override
  String get housingParticipationJournalEffective => 'Efectivo';

  @override
  String get housingParticipationJournalAborted => 'Abortado';

  @override
  String housingParticipationJournalSubjectLine(String kind, String event) {
    return '$kind — $event';
  }

  @override
  String get housingInactiveSettlementTitle =>
      'Liquidar con participante inactivo';

  @override
  String get housingInactiveSettlementTileSubtitle =>
      'Registrar una transferencia para cerrar el saldo';

  @override
  String housingInactiveSettlementParticipantLabel(String name) {
    return 'Participante anterior: $name';
  }

  @override
  String housingInactiveSettlementCurrentBalance(String amount) {
    return 'Saldo actual: $amount';
  }

  @override
  String get housingInactiveSettlementAmountLabel =>
      'Monto de la transferencia';

  @override
  String get housingInactiveSettlementAmountHint =>
      'Positivo: usted paga. Negativo: le pagan a usted.';

  @override
  String get housingInactiveSettlementSubmit =>
      'Publicar transferencia de cierre';

  @override
  String get housingInactiveSettlementSuccess =>
      'Transferencia de cierre registrada.';

  @override
  String get housingInactiveSettlementTransferDescription =>
      'Liquidación con participante anterior';

  @override
  String get housingInactiveSettlementErrorZero =>
      'Ingrese un monto distinto de cero.';

  @override
  String get housingInactiveSettlementErrorCannotCreateCredit =>
      'Esta transferencia crearía un saldo a su favor.';

  @override
  String get housingInactiveSettlementErrorExceedsDebt =>
      'El monto supera lo que deben.';

  @override
  String get housingInactiveSettlementErrorCannotIncreaseDebt =>
      'Esta transferencia aumentaría lo que deben.';

  @override
  String get housingInactiveSettlementErrorExceedsCredit =>
      'El monto supera lo que se les debe.';

  @override
  String get vehicleLicensingRequired =>
      'El módulo Vehículo requiere una suscripción activa.';

  @override
  String get vehicleSharingLicensingRequired =>
      'El uso compartido de vehículo requiere una suscripción activa.';

  @override
  String get vehicleQuickActionsTitle => 'Acciones rápidas';

  @override
  String get vehicleMyVehiclesTitle => 'Mis vehículos';

  @override
  String get vehicleMyVehiclesEmpty =>
      'Sin vehículos. Pulse + para añadir uno.';

  @override
  String get vehicleOwnedActiveLimitReached =>
      'Límite alcanzado: máximo 3 vehículos activos.';

  @override
  String vehicleDeactivatedLabel(String date) {
    return 'Desactivado $date';
  }

  @override
  String get vehicleDeactivateAction => 'Desactivar este vehículo';

  @override
  String get vehicleDeactivateDialogTitle => '¿Desactivar este vehículo?';

  @override
  String get vehicleDeactivateDialogBody =>
      'Esta acción es definitiva. Podrá consultar el historial, pero ya no se podrá registrar nada para este vehículo.';

  @override
  String get vehicleDeactivateConfirm => 'Desactivar';

  @override
  String get vehicleDeactivateBlockedOpenSession =>
      'Termine primero la sesión de uso en curso.';

  @override
  String get vehicleExportDataAction => 'Exportar datos';

  @override
  String get vehicleExportConfirmBody =>
      'Exportación solo de datos factuales del vehículo.\n\nCaso de uso: proporcionar los datos a otro usuario en una transferencia de propiedad.';

  @override
  String get vehicleExportConfirmExport => 'Exportar';

  @override
  String get vehicleExportSuccessTitle => 'Exportación terminada';

  @override
  String vehicleExportSuccessBody(String fileName) {
    return 'Archivo guardado en Documents/Bojairũ/\n$fileName';
  }

  @override
  String get vehicleExportFileDataOfSegment => 'Datos-de';

  @override
  String get vehicleExportFailed =>
      'La exportación ha fallado. Inténtelo de nuevo.';

  @override
  String get vehicleImportAction => 'Importar';

  @override
  String get vehicleImportConfirmBody =>
      'Aquí puede importar datos de un vehículo exportados por otro usuario.\n\nNecesita haber obtenido el archivo de exportación y haberlo copiado localmente en este aparato.';

  @override
  String get vehicleImportConfirmImport => 'Importar';

  @override
  String get vehicleImportFailInvalid =>
      'Este archivo no es una exportación de vehículo válida.';

  @override
  String get vehicleImportFailCorrupt =>
      'La importación ha fallado. El archivo parece estar corrupto. Inténtelo de nuevo con otra copia.';

  @override
  String get vehicleImportFailOther =>
      'La importación ha fallado. Inténtelo de nuevo.';

  @override
  String get vehicleSaleImportUndoAction => 'Deshacer la importación';

  @override
  String vehicleSaleImportUndoConfirmBody(String label) {
    return 'Los datos importados de « $label » se eliminarán de forma permanente.';
  }

  @override
  String get vehicleSaleImportConfirmActionBody =>
      'Esta acción confirma la importación de este vehículo. Ya no podrá deshacer la importación.';

  @override
  String get vehicleSaleImportConfirmActionConfirm => 'Confirmar';

  @override
  String get vehicleAddVehicle => 'Añadir vehículo';

  @override
  String get vehicleAddFirst => 'Añada primero un vehículo.';

  @override
  String get vehicleFieldLabel => 'Nombre';

  @override
  String get vehicleFieldKind => 'Tipo de vehículo';

  @override
  String get vehicleFieldMake => 'Marca';

  @override
  String get vehicleFieldModel => 'Modelo';

  @override
  String get vehicleFieldColor => 'Color';

  @override
  String get vehicleFieldYear => 'Año';

  @override
  String get vehicleFieldInitialOdometer => 'Odómetro inicial';

  @override
  String get vehicleFieldInitialHorometer => 'Cronómetro del motor inicial';

  @override
  String get vehicleFieldLicensePlate => 'Matrícula';

  @override
  String get vehicleFieldVin => 'Número de identificación del vehículo (VIN)';

  @override
  String get vehicleFieldOptional => 'Opcional';

  @override
  String get vehicleAddPhotosSection => 'Fotos';

  @override
  String get vehicleAddPhotosOptionalHint =>
      'Archivo visual del estado del vehículo (opcional).';

  @override
  String get vehicleAddGalleryStart => 'Añadir una galería';

  @override
  String get vehicleAddPhotoGalleryStart => 'Añadir una galería de fotos';

  @override
  String vehicleAddGalleryTitle(int index) {
    return 'Galería $index';
  }

  @override
  String get vehicleAddGalleryEmpty => 'Sin fotos en esta galería.';

  @override
  String get vehicleAddGalleryDescription => 'Descripción';

  @override
  String get vehicleAddGalleryAddPhoto => 'Añadir foto';

  @override
  String get vehicleAddGalleryAddGallery => 'Añadir otra galería';

  @override
  String get vehicleAddValidationLabelRequired => 'El nombre es obligatorio.';

  @override
  String get vehicleAddValidationMakeRequired => 'La marca es obligatoria.';

  @override
  String get vehicleAddValidationModelRequired => 'El modelo es obligatorio.';

  @override
  String get vehicleAddValidationColorRequired => 'El color es obligatorio.';

  @override
  String get vehicleAddValidationYearInvalid =>
      'El año debe ser un valor válido de cuatro dígitos.';

  @override
  String get vehicleAddValidationMeterRequired =>
      'La lectura inicial del cuentakilómetros es obligatoria.';

  @override
  String get vehicleAddValidationFluidChangeFrequencyRequired =>
      'Los cambios de aceite son obligatorios.';

  @override
  String get vehicleAddValidationRequiredFields =>
      'Complete todos los campos obligatorios, incluida la foto del odómetro.';

  @override
  String get vehicleOdometerPhotoLabel => 'Foto del odómetro';

  @override
  String get vehicleEditDetailsTitle => 'Editar detalles';

  @override
  String get vehicleJournalsTitle => 'Registros';

  @override
  String get vehicleJournalSelectorLabel => 'Registro';

  @override
  String get vehicleFormVehicleLabel => 'Vehículo';

  @override
  String get vehicleJournalEmpty => 'Sin entradas por ahora.';

  @override
  String get vehicleLogRecordedAt => 'Registrado el';

  @override
  String get vehicleLogReadingRole => 'Tipo de lectura';

  @override
  String vehicleLogReadingRoleSessionEnd(String userName) {
    return '$userName - Fin';
  }

  @override
  String vehicleLogReadingRoleSessionStart(String userName) {
    return '$userName - Inicio';
  }

  @override
  String get vehicleLogReadingRoleStandalone => 'Lectura puntual';

  @override
  String get vehicleLogReadingRoleFuelPurchase => 'Compra de combustible';

  @override
  String get vehicleLogReadingRoleMaintenance => 'Mantenimiento';

  @override
  String get vehicleLogReadingRoleCorrection => 'Corrección';

  @override
  String vehicleLogReadingRoleCorrectionBy(String userName) {
    return 'Corrección por $userName';
  }

  @override
  String vehicleLogReadingRoleCorrectionSessionStart(String userName) {
    return 'Corrección por $userName al inicio de sesión';
  }

  @override
  String vehicleLogReadingRoleCorrectionStandalone(String userName) {
    return 'Corrección por $userName en una lectura puntual';
  }

  @override
  String get vehicleLogCorrectionJournalSubtitle =>
      'Corrección de odómetro por verificar';

  @override
  String get vehicleLogCorrectionLabel => 'Corrección';

  @override
  String vehicleLogCorrectionMustBeAttributed(String gap) {
    return '$gap deben ser atribuidos';
  }

  @override
  String vehicleLogCorrectionGapMustBeAdded(String gap) {
    return '$gap deben ser añadidos';
  }

  @override
  String vehicleLogCorrectionGapMustBeRemoved(String gap) {
    return '$gap deben ser retirados';
  }

  @override
  String get vehiclePendingCorrectionsTitle => 'Correcciones pendientes';

  @override
  String get vehicleBorrowerBalancesTitle => 'Saldos de los prestatarios';

  @override
  String get vehicleBorrowerBalancesEmpty =>
      'Aún no hay prestatarios aceptados.';

  @override
  String get vehicleUsageBalanceTitle => 'Saldo de uso';

  @override
  String get vehicleUsageBalanceTileOwner => 'Saldos de los prestatarios';

  @override
  String get vehicleUsageBalanceTileBorrower => 'Saldo de uso';

  @override
  String get vehicleUsageBalanceUnavailableConsumption =>
      'El saldo de uso no está disponible hasta que el vehículo tenga una estimación fiable del consumo.';

  @override
  String get vehicleUsageBalanceUnavailableFuelPrice =>
      'El saldo de uso no está disponible hasta que se registre al menos una compra de combustible con volumen y precio.';

  @override
  String get vehicleUsageBalanceNetLabel => 'Saldo';

  @override
  String get vehicleUsageBalanceOwedToOwner => 'Importe debido al propietario';

  @override
  String get vehicleUsageBalanceCreditForBorrower =>
      'Crédito para el prestatario';

  @override
  String get vehicleUsageBalanceMyMileage => 'Mi kilometraje';

  @override
  String get vehicleUsageBalanceMyMileageMiles => 'Mi mileage';

  @override
  String get vehicleUsageBalanceEstimatedFuel => 'Combustible usado';

  @override
  String get vehicleUsageBalanceBorrowerFuel => 'Compras de combustible';

  @override
  String get vehicleUsageBalanceBorrowerMaintenance => 'Mantenimientos';

  @override
  String get vehicleUsageBalanceCompensation => 'Compensación por uso';

  @override
  String get vehicleUsageBalanceConsumption => 'Consumo medio (C)';

  @override
  String get vehicleUsageBalanceDistance => 'Distancia atribuida (D)';

  @override
  String get vehicleUsageBalanceFuelPrice => 'Precio medio del combustible (P)';

  @override
  String get vehicleUsageBalanceRatePerKm => 'Compensación por km (T)';

  @override
  String get vehicleUsageBalanceInformativeNote =>
      'Este saldo es informativo. Registrar un pago entre propietario y prestatario será un paso aparte (próximamente).';

  @override
  String get vehicleUsageBalanceMileageSessionDatesBlurb =>
      'Según las fechas de fin de sesión de uso';

  @override
  String vehicleUsageBalanceCompensationDistanceBlurb(
    String distance,
    String unit,
  ) {
    return 'Distancia recorrida: $distance $unit';
  }

  @override
  String vehicleUsageBalanceCompensationRateBlurb(String rate, String unit) {
    return 'Compensación por uso: $rate \$ / $unit';
  }

  @override
  String vehicleUsageBalanceFuelPriceBlurb(String price, String volumeUnit) {
    return 'Precio medio del combustible: $price / $volumeUnit';
  }

  @override
  String vehicleUsageBalanceFuelConsumptionBlurb(
    String consumption,
    String volumeUnit,
    String distanceUnit,
  ) {
    return 'Consumo medio: $consumption $volumeUnit / 100 $distanceUnit';
  }

  @override
  String vehicleUsageBalanceFuelDistanceBlurb(String distance, String unit) {
    return 'Distancia recorrida: $distance $unit';
  }

  @override
  String get vehicleUsageBalanceFuelPurchasesDeductedBlurb =>
      'Se deduce la suma de las compras de combustible que ha realizado';

  @override
  String get vehicleUsageBalanceMaintenanceDeductedBlurb =>
      'Se deduce la suma de los mantenimientos que ha realizado';

  @override
  String vehicleUsageBalanceDistanceAmount(String distance, String unit) {
    return '$distance $unit';
  }

  @override
  String get vehicleDistanceUnitKilometre => 'kilómetro';

  @override
  String get vehicleDistanceUnitMile => 'milla';

  @override
  String get vehicleUsageBalanceRevokedSuffix => ' (revocado)';

  @override
  String get vehicleUsageBalanceFreezeButton => 'Fijar este saldo';

  @override
  String get vehicleUsageBalanceTransferButton => 'Transferencia';

  @override
  String get vehicleUsageBalanceFreezeProposeBody =>
      'Se enviará una solicitud de acuerdo para fijar este saldo.';

  @override
  String get vehicleUsageBalanceTransferProposeBody =>
      'Importe transferido al propietario:';

  @override
  String get vehicleUsageBalanceTransferProposeBodyToBorrower =>
      'Importe transferido al prestatario:';

  @override
  String get vehicleUsageBalanceFreezeConfirmTitle => '¿Fijar el saldo?';

  @override
  String vehicleUsageBalanceFreezeConfirmBody(
    String name,
    String amount,
    String when,
  ) {
    return '$name pide fijar $amount.\n\n$when';
  }

  @override
  String get vehicleUsageBalanceTransferConfirmTitle =>
      'Confirmar la recepción de una transferencia';

  @override
  String get vehicleUsageBalanceDecisionLater => 'Más tarde';

  @override
  String get vehicleUsageBalanceDecisionReject => 'Rechazar';

  @override
  String get vehicleUsageBalanceDecisionConfirm => 'Confirmar';

  @override
  String get vehicleUsageBalanceCancel => 'Cancelar';

  @override
  String get vehicleUsageBalanceSubmit => 'Enviar';

  @override
  String get vehicleUsageBalanceNotInCurrent =>
      'No incluido en el saldo actual';

  @override
  String get vehicleUsageBalanceCarriedForward => 'Saldo diferido';

  @override
  String get vehicleUsageBalanceCarriedFreezeLabel => 'Saldo';

  @override
  String get vehicleUsageBalanceCarriedTransferSent => 'Transferencia enviada';

  @override
  String get vehicleUsageBalanceCarriedTransferReceived =>
      'Transferencia recibida';

  @override
  String get vehicleUsageBalancePendingDecision => 'Decisión pendiente';

  @override
  String vehicleUsageBalanceHistoricalTitle(String date) {
    return 'Saldo del $date';
  }

  @override
  String get vehicleUsageBalanceBack => 'Volver';

  @override
  String get vehiclePendingCorrectionsEmpty =>
      'No hay correcciones pendientes.';

  @override
  String get vehiclePendingCorrectionDetailTitle => 'Corrección de odómetro';

  @override
  String vehicleCorrectReadingButton(String date) {
    return 'Corregir la entrada del $date';
  }

  @override
  String get vehicleAddMissingSessionButton => 'Añadir una sesión de uso';

  @override
  String get vehicleSplitSessionButton => 'Dividir la sesión';

  @override
  String get vehicleGapResolutionSubmit => 'Enviar';

  @override
  String get vehicleLogReadingRoleCorrectionApplied => 'Corrección aplicada';

  @override
  String vehicleLogCorrectionAppliedSummary(String km, String name) {
    return '$km se atribuyeron a $name';
  }

  @override
  String vehicleLogCorrectionAppliedSplitSummary(String km) {
    return '$km se atribuyeron (reparto)';
  }

  @override
  String vehicleLogReadingRoleCorrectionReplaces(String label) {
    return 'Corrección — reemplaza $label';
  }

  @override
  String vehicleLogCorrectionAppliedDivergence(String gap) {
    return 'Diferencia observada: $gap';
  }

  @override
  String get vehicleGapResolutionPreviousReading => 'Lectura anterior';

  @override
  String get vehicleGapResolutionTriggerReading => 'Lectura subsiguiente';

  @override
  String get vehicleGapResolutionValidationMonotonicity =>
      'Este valor entraría en conflicto con otra lectura.';

  @override
  String get vehicleGapResolutionValidationSegment =>
      'Los segmentos no cubren correctamente la diferencia.';

  @override
  String get vehicleGapResolutionValidationDateOverlap =>
      'Las fechas de los segmentos se solapan.';

  @override
  String get vehicleGapResolutionAssignTo => 'Atribuir a';

  @override
  String get vehicleGapResolutionDates => 'Fecha(s)';

  @override
  String get vehicleGapResolutionStartMeter => 'Odómetro de inicio';

  @override
  String get vehicleGapResolutionEndMeter => 'Odómetro de fin';

  @override
  String get vehicleLogMeterTitle => 'Registro — odómetro';

  @override
  String get vehicleLogMeterFuelTitle => 'Odómetro y combustible';

  @override
  String get vehicleLogSharingSessionsTitle => 'Otro';

  @override
  String get vehicleLogMeterDetailTitle => 'Detalle de la lectura';

  @override
  String get vehicleLogFuelTitle => 'Registro — combustible';

  @override
  String get vehicleLogFuelDetailTitle => 'Detalle de la compra';

  @override
  String vehicleFuelPurchaseMadeBy(String name) {
    return 'Compra realizada por: $name';
  }

  @override
  String get vehicleLogMaintenanceTitle => 'Mantenimiento';

  @override
  String get vehicleLogMaintenanceDetailTitle => 'Detalle del mantenimiento';

  @override
  String get vehicleLogViolationTitle => 'Daños e infracciones';

  @override
  String get vehicleLogViolationDetailTitle => 'Detalle de la infracción';

  @override
  String get vehicleKindCar => 'Coche';

  @override
  String get vehicleKindTruck => 'Camión';

  @override
  String get vehicleKindMotorcycle => 'Moto';

  @override
  String get vehicleKindBoat => 'Barco';

  @override
  String get vehicleQuickActionOdometer => 'Lectura del odómetro';

  @override
  String get vehicleUseSessionStartAction => 'Iniciar una sesión de uso';

  @override
  String get vehicleUseSessionEndAction => 'Terminar una sesión de uso';

  @override
  String vehicleUseSessionStartedOn(String dateTime) {
    return 'iniciada el $dateTime';
  }

  @override
  String get vehicleQuickActionFuel => 'Compra de combustible';

  @override
  String get vehicleQuickActionMaintenance => 'Mantenimiento';

  @override
  String get vehicleQuickActionViolation => 'Daño o infracción';

  @override
  String get vehicleOdometerLabel => 'Odómetro';

  @override
  String get vehicleHorometerLabel => 'Cronómetro del motor';

  @override
  String get vehicleMeterPhotoRequired =>
      'Se requiere una foto del cuentakilómetros.';

  @override
  String get vehicleMeterPhotoAdd => 'Añadir foto';

  @override
  String get vehicleMeterPhotoAttached => 'Foto adjunta';

  @override
  String get vehicleMeterKnownUnchangedNoPhotoOdometer =>
      'Odómetro conocido sin cambio. No se registró foto.';

  @override
  String get vehicleMeterKnownUnchangedNoPhotoHorometer =>
      'Cronómetro del motor conocido sin cambio. No se registró foto.';

  @override
  String get vehicleMeterPhotoCamera => 'Cámara';

  @override
  String get vehicleMeterPhotoGallery => 'Galería';

  @override
  String get vehicleUseSessionStart => 'Inicio de uso';

  @override
  String get vehicleUseSessionEnd => 'Fin de uso';

  @override
  String get vehicleUseSessionStarted =>
      'Sesión iniciada. Ciérrela al terminar.';

  @override
  String get vehicleUseSessionEnded => 'Sesión terminada.';

  @override
  String get vehicleConsumptionTitle => 'Consumo';

  @override
  String get vehicleConsumptionInsufficient =>
      'Datos insuficientes para el consumo';

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
  String get vehicleDrivingConditionColumn => 'Condición';

  @override
  String get vehicleDrivingConditionProportionColumn =>
      'Proporción (del kilometraje recorrido)';

  @override
  String get vehicleDrivingConditionRoute => 'Carretera';

  @override
  String get vehicleDrivingConditionCity => 'Ciudad';

  @override
  String get vehicleDrivingConditionTraffic => 'Tráfico';

  @override
  String get vehicleConsumptionReliabilityNone =>
      'No hay suficientes datos para calcular el consumo de combustible.';

  @override
  String get vehicleConsumptionReliabilityPreliminary =>
      'Esta estimación es preliminar. Se precisará con más datos.';

  @override
  String get vehicleConsumptionReliabilityReliable =>
      'Esta estimación es fiable según la fórmula de cálculo y los datos que ha introducido.';

  @override
  String get vehicleConsumptionReliabilityVeryReliable =>
      'Esta estimación es muy fiable porque se basa en muchos datos que ha introducido.';

  @override
  String get vehicleConsumptionEstimationModeTitle =>
      'Modo de estimación del consumo de combustible';

  @override
  String get vehicleConsumptionEstimationModeSimpleTitle => 'Simple';

  @override
  String vehicleConsumptionEstimationModeSimpleDescription(
    String volumeUnitWord,
    String distanceUnit,
  ) {
    return 'Solo $volumeUnitWord por 100 $distanceUnit';
  }

  @override
  String get vehicleConsumptionEstimationModeDetailedTitle => 'Detallado';

  @override
  String vehicleConsumptionEstimationModeDetailedDescription(
    String volumeUnitWordCap,
    String distanceUnit,
  ) {
    return '$volumeUnitWordCap por 100 $distanceUnit para conducción en carretera / ciudad / tráfico';
  }

  @override
  String get vehicleDistanceUnitKilometres => 'kilómetros';

  @override
  String get vehicleDistanceUnitMiles => 'millas';

  @override
  String get vehicleLiquidVolumeUnitLitres => 'litros';

  @override
  String get vehicleLiquidVolumeUnitUsGallons => 'galones US';

  @override
  String get vehicleLiquidVolumeUnitImperialGallons => 'galones imperiales';

  @override
  String get vehicleLiquidVolumeUnitLitresCap => 'Litros';

  @override
  String get vehicleLiquidVolumeUnitUsGallonsCap => 'Galones US';

  @override
  String get vehicleLiquidVolumeUnitImperialGallonsCap => 'Galones imperiales';

  @override
  String get vehicleConsumptionRequireDetailedForBorrowers =>
      'Exigir a los prestatarios los porcentajes carretera / ciudad / tráfico';

  @override
  String vehicleConsumptionSimpleEstimate(
    String value,
    String volumeUnit,
    String distanceUnit,
  ) {
    return 'Consumo: $value $volumeUnit/100 $distanceUnit';
  }

  @override
  String get vehicleConsumptionInsufficientDetailedData =>
      'No hay datos suficientes para una estimación detallada (carretera / ciudad / tráfico). Se muestra la estimación simple hasta que se registren más sesiones detalladas.';

  @override
  String get vehicleConsumptionCarriedFromDetailedMode =>
      'Esta estimación procede de su modo detallado anterior. Se afinará con nuevos períodos entre repostajes completos en modo simple.';

  @override
  String get vehicleStatisticsConsumptionHistoryTitle =>
      'Historial de estimaciones fiables';

  @override
  String vehicleConsumptionHistoryBlended(
    String date,
    String value,
    String volumeUnit,
    String distanceUnit,
  ) {
    return '$date: $value $volumeUnit/100 $distanceUnit';
  }

  @override
  String get vehicleSessionEndTankConfirmTitle =>
      'Confirmar nivel del depósito';

  @override
  String vehicleSessionEndTankConfirmBody(String distance, int percent) {
    return 'Ha declarado el depósito al $percent % después de $distance desde la última compra de combustible. Confirme que es correcto.';
  }

  @override
  String get vehicleSessionEndTankConfirmReview => 'Revisar la entrada';

  @override
  String get vehicleSessionEndTankConfirmProceed => 'Confirmar';

  @override
  String get vehicleStatisticsTitle => 'Estadísticas';

  @override
  String get vehicleStatisticsMileageTitle => 'Mi kilometraje';

  @override
  String get vehicleStatisticsExpensesTitle => 'Mis gastos';

  @override
  String get vehicleExpenseFuel => 'Combustible';

  @override
  String get vehicleExpenseMaintenance => 'Mantenimiento';

  @override
  String get vehicleExpenseViolations => 'Infracciones';

  @override
  String get vehicleFuelCost => 'Coste total';

  @override
  String get vehicleFuelVolume => 'Volumen';

  @override
  String get vehicleFuelMeter => 'Odómetro';

  @override
  String get vehicleFuelFullTank => 'Depósito lleno';

  @override
  String get vehicleFuelTankState => 'Estado del depósito';

  @override
  String get vehicleFuelApproximateLevel => 'Aproximadamente:';

  @override
  String get vehicleFieldFuelTankCapacity =>
      'Capacidad del depósito de combustible';

  @override
  String get vehicleFieldFluidChangeFrequency => 'Cambios de aceite';

  @override
  String get vehicleOilChangeIntervalRequired =>
      'Indique un intervalo de cambio de aceite.';

  @override
  String get vehicleOilChangeIntervalInvalid => 'Valor numérico no válido.';

  @override
  String get vehicleOilChangeIntervalLandMin =>
      'Mínimo: 1 (1 000 km o millas).';

  @override
  String get vehicleOilChangeIntervalLandMax =>
      'Máximo: 20 (20 000 km o millas).';

  @override
  String get vehicleOilChangeIntervalBoatMin => 'Mínimo: 50 h.';

  @override
  String get vehicleOilChangeIntervalBoatMax => 'Máximo: 500 h.';

  @override
  String get vehicleDetailEarlierPhotos => 'Fotos anteriores';

  @override
  String vehicleFuelTankInTank(String volume) {
    return '$volume en el depósito';
  }

  @override
  String get vehicleFuelTankInfoTooltip =>
      'Acerca de la estimación del depósito';

  @override
  String get vehicleMaintenanceCategory => 'Categoría';

  @override
  String get vehicleMaintenanceCategoryOil => 'Aceite';

  @override
  String get vehicleMaintenanceCategoryOtherFluids => 'Otros fluidos';

  @override
  String get vehicleMaintenanceCategoryTires => 'Neumáticos';

  @override
  String get vehicleMaintenanceCategoryBrakes => 'Frenos';

  @override
  String get vehicleMaintenanceCategoryLights => 'Faros';

  @override
  String get vehicleMaintenanceCategoryCleaning => 'Limpieza';

  @override
  String get vehicleMaintenanceCategoryOther => 'Otro';

  @override
  String get vehicleMaintenanceCost => 'Coste';

  @override
  String get vehicleMaintenanceNotes => 'Notas';

  @override
  String get vehicleViolationType => 'Tipo de infracción';

  @override
  String get vehicleViolationAmount => 'Importe';

  @override
  String vehicleMaintenanceAlertTile(String category, String remaining) {
    return '$category: $remaining restantes';
  }

  @override
  String get vehicleGapAttributionTitle => 'Uso no registrado';

  @override
  String vehicleGapAttributionPrompt(String gap) {
    return '¿A quién es atribuible la diferencia de $gap?';
  }

  @override
  String get vehicleGapAttributionUnknown => 'No lo sé';

  @override
  String get vehicleGapAttributionSelf => 'Yo';

  @override
  String get vehicleGapOwnerNotified => 'Se notificará al propietario.';

  @override
  String vehiclePositiveGapConfirmPrompt(String gap) {
    return 'Se trata de una diferencia de $gap. ¿Está seguro?';
  }

  @override
  String get vehiclePositiveGapConfirmNo => 'No';

  @override
  String get vehiclePositiveGapConfirmYes => 'Sí';

  @override
  String get vehicleNegativeGapTitle => 'Lectura menor';

  @override
  String vehicleNegativeGapBody(String gap) {
    return 'La nueva lectura es $gap inferior a la última guardada.';
  }

  @override
  String get vehicleNegativeGapMaintain =>
      'Mantener lectura, investigar después';

  @override
  String get vehicleNegativeGapCancel => 'Cancelar entrada';

  @override
  String get vehicleBorrowerMeterRecheckTitle => 'Comprueba esta lectura';

  @override
  String vehicleBorrowerMeterRecheckBody(String gap) {
    return 'La nueva lectura es $gap inferior a la última lectura conocida. Verifica el número antes de continuar.';
  }

  @override
  String get vehicleBorrowerMeterRecheckConfirm => 'Confirmo';

  @override
  String get vehicleBorrowerMeterRecheckCorrect => 'Lo corrijo';

  @override
  String get vehicleSuspiciousGapTitle => 'Diferencia inusualmente grande';

  @override
  String vehicleSuspiciousGapBody(String gap, String maxGap) {
    return 'La diferencia de $gap supera lo plausible con un tanque lleno ($maxGap). Esta lectura puede ser incorrecta.';
  }

  @override
  String get vehicleSuspiciousGapConfirm => 'Usar esta lectura de todos modos';

  @override
  String get vehicleSuspiciousGapCancel => 'Revisar la entrada';

  @override
  String get vehicleRoleOwner => 'Propietario';

  @override
  String get vehicleRoleBorrower => 'Prestatario';

  @override
  String get vehicleSharingShareableTitle => 'Vehículo compartible';

  @override
  String get vehicleSharingShareableTitlePlural => 'Vehículos compartibles';

  @override
  String get vehicleSharingAccessibleTitle => 'Vehículo accesible';

  @override
  String get vehicleSharingAccessibleTitlePlural => 'Vehículos accesibles';

  @override
  String get vehicleSharingPendingOfferTitle => 'Oferta pendiente';

  @override
  String get vehicleSharingPendingOfferTitlePlural => 'Ofertas pendientes';

  @override
  String get vehicleSharingEmptyNone => 'Ninguno';

  @override
  String get vehicleSharingEmptyNoneFeminine => 'Ninguna';

  @override
  String get vehicleSharingSharesDetailTitle => 'Compartidos';

  @override
  String get vehicleSharingAddShare => 'Añadir un compartido';

  @override
  String get vehicleSharingRevoke => 'Revocar';

  @override
  String get vehicleSharingReactivate => 'Reactivar';

  @override
  String vehicleSharingRevokeConfirmBody(
    String borrowerName,
    String vehicleName,
  ) {
    return '¿Revocar el acceso de $borrowerName para $vehicleName?';
  }

  @override
  String vehicleSharingRevokeForceSessionBody(String name, String when) {
    return 'Hay una sesión de uso en curso para $name desde $when.\n\nSi el vehículo no está realmente en uso y puede hacer una lectura del odómetro, puede forzar el cierre de esta sesión.\n\n¿Desea cerrar esta sesión?';
  }

  @override
  String get vehicleSharingRevokeForceSessionYes => 'Sí';

  @override
  String get vehicleSharingReactivatePendingSent => 'Reactivación enviada';

  @override
  String get vehicleSharingPendingReactivateTitle => 'Reactivación pendiente';

  @override
  String get vehicleSharingPendingReactivateTitlePlural =>
      'Reactivaciones pendientes';

  @override
  String get vehicleSharingNewShareTitle => 'Nuevo compartido';

  @override
  String vehicleSharingInviteForContact(String name) {
    return 'Invitación para $name';
  }

  @override
  String vehicleSharingInviteRateLabel(String unit) {
    return 'Centavos por $unit de uso (opcional)';
  }

  @override
  String get vehicleSharingInviteRateHelper => 'Compensa el desgaste normal.';

  @override
  String get vehicleSharingInviteRateInvalid =>
      'Indica un número entero de centavos (≥ 0).';

  @override
  String vehicleSharingInviteRatePer100Distance(String amount, String unit) {
    return '$amount por 100 $unit';
  }

  @override
  String get vehicleSharingInviteAvailabilitySection =>
      'Periodo de disponibilidad (opcional)';

  @override
  String get vehicleSharingAvailabilityLevelPrimary => 'Disponible';

  @override
  String get vehicleSharingInviteAvailabilitySaveFirst =>
      'Guarda o cancela el periodo de disponibilidad antes de enviar.';

  @override
  String get vehicleSharingInviteRulesLabel => 'Otras reglas';

  @override
  String get vehicleSharingInviteSend => 'Enviar invitación';

  @override
  String vehicleSharingInviteDisclaimerBody1(String unit) {
    return 'Solo el importe por $unit es seguido por la aplicación.';
  }

  @override
  String get vehicleSharingInviteDisclaimerBody2 =>
      'La disponibilidad y las demás reglas son solo orientativas para su prestatario.';

  @override
  String get vehicleSharingInviteDisclaimerDoNotShow => 'No volver a mostrar';

  @override
  String get vehicleSharingAccept => 'Aceptar';

  @override
  String get vehicleSharingOffer => 'Ofrecer uso compartido';

  @override
  String get vehicleSharingOfferPickContact => 'Elegir un contacto conectado';

  @override
  String get vehicleSharingNoContacts => 'Añada primero un contacto conectado.';

  @override
  String get vehicleSharingOfferSent => 'Oferta enviada.';

  @override
  String get vehicleSharingOfferDeadlineTitle => 'Plazo de respuesta';

  @override
  String get vehicleSharingOfferDeadlineBody =>
      'El prestatario tiene este plazo para aceptar la invitación.';

  @override
  String get vehicleSharingReactivateDeadlineTitle => 'Plazo de respuesta';

  @override
  String get vehicleSharingReactivateDeadlineBody =>
      'El prestatario tiene este plazo para aceptar la reactivación.';

  @override
  String get vehicleEmprunteurCapLimitReached =>
      'Límite alcanzado: máximo 5 prestatarios (activos o pendientes).';

  @override
  String get vehicleEmprunteurCapLastSlotTitle =>
      'Último puesto de prestatario';

  @override
  String get vehicleEmprunteurCapLastSlotBody =>
      'Esta persona ocupa el quinto y último puesto. Mientras siga activa o pendiente, no podrá invitar a otro contacto distinto. ¿Continuar?';

  @override
  String vehicleSharingInvitationSentToAt(String name, String when) {
    return 'Invitación enviada a $name el $when';
  }

  @override
  String get vehicleSharingOfferBlocked =>
      'Compartir requiere las suscripciones Vehículo y Uso compartido.';

  @override
  String get vehicleSharingForwarded =>
      'Registrado en el vehículo del propietario.';

  @override
  String vehicleSharingBorrowerLabel(String name) {
    return 'Prestatario: $name';
  }

  @override
  String vehicleSharingOwnerLabel(String name) {
    return 'Propietario: $name';
  }

  @override
  String get vehicleSharingSessionStartAction => 'Iniciar una sesión';

  @override
  String get vehicleSharingSessionEndAction => 'Terminar una sesión';

  @override
  String get vehicleSharingOtherActions => 'Otras acciones';

  @override
  String get vehicleSharingOtherActionsTitle => 'Otras acciones';

  @override
  String get vehicleSharingSessionRelayFailed =>
      'Sesión guardada aquí, pero el envío al propietario falló. Inténtelo más tarde.';

  @override
  String get vehicleSharingFuelRelayFailed =>
      'Compra guardada aquí, pero el envío al propietario falló. Inténtelo más tarde.';

  @override
  String get vehicleSharingForwardRelayFailed =>
      'Guardado aquí, pero el envío al propietario falló. Inténtelo más tarde.';

  @override
  String get vehicleUsageBlockedOwnOnBorrowerPath =>
      'Este vehículo es suyo. Use el módulo Vehículo para registrar su uso — no Uso compartido.';

  @override
  String get vehicleUsageBlockedNotOwnedOnOwnerPath =>
      'Este vehículo no está en su lista de vehículos propios. Use Uso compartido para un vehículo compartido con usted.';

  @override
  String get vehicleUsageBlockedMissingBorrowerIdentity =>
      'Falta la identidad del prestatario para este formulario.';

  @override
  String get vehicleUsageBlockedVehicleNotFound => 'Vehículo no encontrado.';

  @override
  String get commonOk => 'Ok';

  @override
  String get sandboxRibbonLabel => 'Modo simulación';

  @override
  String get sandboxModeButton => 'Modo simulación';

  @override
  String get sandboxEnterDialogBody =>
      'Puede simular un plan con participantes ficticios. Esto le da una excelente vista previa de la aplicación.\n\nPara usar la aplicación «real», debe volver al modo real. Para ello, toque la cinta roja en la parte superior de la aplicación. Se le recordará hacerlo en 8 horas.';

  @override
  String get sandboxEnterConfirm => 'Simular';

  @override
  String get sandboxEnterRestartMessage =>
      'La aplicación se cerrará ahora. Vuelva a abrirla para continuar.';

  @override
  String get sandboxHomeWelcomeBody =>
      'Los módulos de vehículo no pueden simularse.\n\nEmpiece explorando el módulo Contactos. El proceso de añadir contactos está simplificado para esta simulación. Puede renombrar estos contactos ficticios.\n\n';

  @override
  String get sandboxExitDialogTitle => '¿Salir del modo simulación?';

  @override
  String get sandboxRestartRequiredMessage =>
      'Cierre completamente la aplicación y vuelva a abrirla para continuar.';

  @override
  String get sandboxBotsExhausted => 'Ha invitado a todos los bots.';

  @override
  String get sandboxInvitingBot => 'Invitando al participante simulado…';

  @override
  String get sandboxBotExpenseTitle => 'Simular un gasto de un bot';

  @override
  String get sandboxBotExpenseSubtitle => 'Modo simulación';

  @override
  String get sandboxBotExpenseDescription => 'Gasto simulado';

  @override
  String get sandboxEightHourNudgeTitle => 'Modo simulación';

  @override
  String get sandboxEightHourNudgeBody =>
      'Lleva 8 horas en modo simulación. Considere volver al modo real para no perder una invitación de un socio.';

  @override
  String get sandboxPortabilityBlocked =>
      'La exportación e importación no están disponibles en modo simulación.';

  @override
  String get sandboxEnterFailed =>
      'No se pudo entrar en modo simulación (falló la verificación del punto de restauración).';

  @override
  String get sandboxModuleDisabled =>
      'Este módulo no está disponible en modo simulación.';
}
