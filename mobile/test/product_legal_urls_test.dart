import 'dart:ui';

import 'package:compartarenta/util/product_legal_urls.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('privacyPolicyUrlForLocale uses FR / EN / ES paths', () {
    expect(
      privacyPolicyUrlForLocale(const Locale('fr')),
      Uri.parse(
        'https://bojairu.app/fr/legal/confidentialite/',
      ),
    );
    expect(
      privacyPolicyUrlForLocale(const Locale('en')),
      Uri.parse(
        'https://bojairu.app/en/legal/confidentialite/',
      ),
    );
    expect(
      privacyPolicyUrlForLocale(const Locale('es')),
      Uri.parse(
        'https://bojairu.app/es/legal/confidentialite/',
      ),
    );
  });

  test('privacyPolicyUrlForLocale falls back to EN', () {
    expect(
      privacyPolicyUrlForLocale(const Locale('de')),
      Uri.parse(
        'https://bojairu.app/en/legal/confidentialite/',
      ),
    );
  });

  test('faqIndexUrlForLocale uses FR / EN / ES paths', () {
    expect(
      faqIndexUrlForLocale(const Locale('fr')),
      Uri.parse('https://bojairu.app/fr/faq/'),
    );
    expect(
      faqIndexUrlForLocale(const Locale('en')),
      Uri.parse('https://bojairu.app/en/faq/'),
    );
    expect(
      faqIndexUrlForLocale(const Locale('es')),
      Uri.parse('https://bojairu.app/es/faq/'),
    );
  });

  test('faqIndexUrlForLocale falls back to EN', () {
    expect(
      faqIndexUrlForLocale(const Locale('de')),
      Uri.parse('https://bojairu.app/en/faq/'),
    );
  });

  test('contactDuplicateFaqUrlForLocale uses #reject', () {
    expect(
      contactDuplicateFaqUrlForLocale(const Locale('fr')),
      Uri.parse(
        'https://bojairu.app/fr/modules/contacts/faq/#reject',
      ),
    );
    expect(
      contactDuplicateFaqUrlForLocale(const Locale('en')),
      Uri.parse(
        'https://bojairu.app/en/modules/contacts/faq/#reject',
      ),
    );
  });

  test('housingModuleFaqUrlForLocale uses #housing-invite-participant', () {
    expect(
      housingModuleFaqUrlForLocale(const Locale('fr')),
      Uri.parse(
        'https://bojairu.app/fr/modules/logement/faq/#housing-invite-participant',
      ),
    );
    expect(
      housingModuleFaqUrlForLocale(const Locale('es')),
      Uri.parse(
        'https://bojairu.app/es/modules/logement/faq/#housing-invite-participant',
      ),
    );
  });

  test('vehicleModuleFaqUrlForLocale appends the requested fragment', () {
    expect(
      vehicleModuleFaqUrlForLocale(
        const Locale('fr'),
        fragment: ProductFaqAnchors.vehicleOwnershipExport,
      ),
      Uri.parse(
        'https://bojairu.app/fr/modules/vehicule/faq/#vehicle-ownership-export',
      ),
    );
    expect(
      vehicleModuleFaqUrlForLocale(
        const Locale('en'),
        fragment: ProductFaqAnchors.vehicleOwnershipImport,
      ),
      Uri.parse(
        'https://bojairu.app/en/modules/vehicule/faq/#vehicle-ownership-import',
      ),
    );
    expect(
      vehicleModuleFaqUrlForLocale(
        const Locale('es'),
        fragment: ProductFaqAnchors.vehicleFuelTank,
      ),
      Uri.parse(
        'https://bojairu.app/es/modules/vehicule/faq/#vehicle-fuel-tank',
      ),
    );
  });

  test('developerMessageUrlForLocale uses FR / EN / ES paths', () {
    expect(
      developerMessageUrlForLocale(const Locale('fr')),
      Uri.parse('https://bojairu.app/fr/message'),
    );
    expect(
      developerMessageUrlForLocale(const Locale('en')),
      Uri.parse('https://bojairu.app/en/message'),
    );
    expect(
      developerMessageUrlForLocale(const Locale('es')),
      Uri.parse('https://bojairu.app/es/mensaje'),
    );
    expect(
      developerMessageUrlForLocale(const Locale('de')),
      Uri.parse('https://bojairu.app/en/message'),
    );
  });
}
