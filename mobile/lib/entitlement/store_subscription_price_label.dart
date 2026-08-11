import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../l10n/app_localizations.dart';

/// Billing period unit for subscription price display.
enum StoreBillingPeriodUnit {
  day,
  week,
  month,
  year,
}

/// True when Play's [ProductDetails.price] / formattedPrice is the free label.
///
/// Play Billing commonly returns `Free` / `FREE` for a zero-price phase.
/// Case-insensitive exact match after trim — not a money string like `0,00 $`.
bool isStoreFreePriceLabel(String price) =>
    price.trim().toLowerCase() == 'free';

/// ISO-8601 [billingPeriod] from Play PricingPhase (e.g. `P1M`, `P1Y`, `P7D`).
///
/// Returns null when the string is empty or unrecognized.
StoreBillingPeriodUnit? storeBillingPeriodUnitFromIso8601(String? iso) {
  if (iso == null) return null;
  final s = iso.trim().toUpperCase();
  if (s.isEmpty) return null;
  // Documented PricingPhase examples include P1W, P1M, P3M, P6M, P1Y.
  final match = RegExp(r'^P(\d+)([DWMY])$').firstMatch(s);
  if (match == null) return null;
  final count = int.tryParse(match.group(1)!);
  final unit = match.group(2)!;
  if (count == null || count <= 0) return null;
  switch (unit) {
    case 'D':
      if (count == 7) return StoreBillingPeriodUnit.week;
      if (count == 1) return StoreBillingPeriodUnit.day;
      return null;
    case 'W':
      if (count == 1) return StoreBillingPeriodUnit.week;
      return null;
    case 'M':
      if (count == 1) return StoreBillingPeriodUnit.month;
      return null;
    case 'Y':
      if (count == 1) return StoreBillingPeriodUnit.year;
      return null;
    default:
      return null;
  }
}

/// Play [GooglePlayProductDetails] pricing-phase billing period, if available.
///
/// Uses the same offer / first pricing phase that supplies [ProductDetails.price].
String? googlePlayBillingPeriodIso(ProductDetails product) {
  if (product is! GooglePlayProductDetails) return null;
  final index = product.subscriptionIndex;
  final offers = product.productDetails.subscriptionOfferDetails;
  if (index == null || offers == null || index < 0 || index >= offers.length) {
    return null;
  }
  final phases = offers[index].pricingPhases;
  if (phases.isEmpty) return null;
  return phases.first.billingPeriod;
}

/// Formatted price with recurrence suffix (e.g. `3,99 $/mois`).
///
/// When Play returns the free label (`Free` / `FREE`), returns the localized
/// « Gratuit » / « Free » / « Gratis » string with **no** period suffix.
///
/// Prefer Play's ISO billing period; when unknown, fall back to monthly
/// (catalog is monthly today).
String formatSubscriptionPriceWithPeriod({
  required ProductDetails product,
  required AppLocalizations l10n,
}) {
  final price = product.price.trim();
  if (price.isEmpty) return '';
  if (isStoreFreePriceLabel(price)) {
    return l10n.licensesPriceFree;
  }
  final unit = storeBillingPeriodUnitFromIso8601(
        googlePlayBillingPeriodIso(product),
      ) ??
      StoreBillingPeriodUnit.month;
  switch (unit) {
    case StoreBillingPeriodUnit.day:
      return l10n.licensesPricePerDay(price);
    case StoreBillingPeriodUnit.week:
      return l10n.licensesPricePerWeek(price);
    case StoreBillingPeriodUnit.month:
      return l10n.licensesPricePerMonth(price);
    case StoreBillingPeriodUnit.year:
      return l10n.licensesPricePerYear(price);
  }
}
