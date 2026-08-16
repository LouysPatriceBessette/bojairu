import 'package:compartarenta/contacts/contact_display.dart';
import 'package:compartarenta/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

Contact _contact({
  required String displayName,
  String? localDisplayLabel,
}) {
  final now = DateTime.utc(2026, 8, 16);
  return Contact(
    id: 'contact:handshake:peer',
    kind: 'connected',
    displayName: displayName,
    avatarId: 'a01',
    notes: '',
    isBlocked: false,
    localDisplayLabel: localDisplayLabel,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('ContactDisplayX', () {
    test('effectiveDisplayName uses canonical when no local label', () {
      final c = _contact(displayName: 'Fafoin');
      expect(c.effectiveDisplayName, 'Fafoin');
      expect(c.showsDistinctPeerCanonicalForDisplay, isFalse);
    });

    test('effectiveDisplayName uses local label when set', () {
      final c = _contact(
        displayName: 'Fafoin',
        localDisplayLabel: 'Éric',
      );
      expect(c.effectiveDisplayName, 'Éric');
      expect(c.showsDistinctPeerCanonicalForDisplay, isTrue);
    });

    test('effectiveDisplayName treats blank local label as cleared', () {
      final c = _contact(
        displayName: 'Fafoin',
        localDisplayLabel: '   ',
      );
      expect(c.effectiveDisplayName, 'Fafoin');
      expect(c.showsDistinctPeerCanonicalForDisplay, isFalse);
    });

    test('effectiveDisplayName keeps empty canonical when no override', () {
      final c = _contact(displayName: '');
      expect(c.effectiveDisplayName, isEmpty);
    });

    test('showsDistinctPeerCanonicalForDisplay is false when label matches', () {
      final c = _contact(
        displayName: 'Éric',
        localDisplayLabel: 'Éric',
      );
      expect(c.effectiveDisplayName, 'Éric');
      expect(c.showsDistinctPeerCanonicalForDisplay, isFalse);
    });
  });
}
