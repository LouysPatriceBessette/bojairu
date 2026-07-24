import 'package:compartarenta/contacts/contact_invitations_repository.dart';
import 'package:compartarenta/db/app_database.dart';
import 'package:compartarenta/db/repositories/contacts_repository.dart';
import 'package:drift/drift.dart' show QueryExecutor;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabaseForTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('ContactsRepository', () {
    test('upsertLocalOnly creates and rename updates the same row', () async {
      final repo = ContactsRepository(db);
      await repo.upsertLocalOnly(
        id: 'c1',
        displayName: 'Alice',
        avatarId: 'mdi:0',
      );
      final created = await repo.get('c1');
      expect(created, isNotNull);
      expect(created!.kind, 'local-only');
      expect(created.displayName, 'Alice');
      expect(created.deletedAt, isNull);

      await repo.rename(id: 'c1', displayName: 'Alicia', avatarId: 'mdi:3');
      final renamed = await repo.get('c1');
      expect(renamed!.displayName, 'Alicia');
      expect(renamed.avatarId, 'mdi:3');
    });

    test('deleteLocally sets deletedAt but the row remains readable', () async {
      final repo = ContactsRepository(db);
      await repo.upsertLocalOnly(
        id: 'c2',
        displayName: 'Bob',
        avatarId: 'mdi:1',
      );
      await repo.deleteLocally('c2');
      final deleted = await repo.get('c2');
      expect(deleted, isNotNull);
      expect(deleted!.deletedAt, isNotNull);
      // Default list() excludes deleted contacts.
      final visible = await repo.list();
      expect(visible.where((c) => c.id == 'c2'), isEmpty);
      // includeDeleted true returns the row again so module snapshots resolve.
      final all = await repo.list(includeDeleted: true);
      expect(all.where((c) => c.id == 'c2'), isNotEmpty);
    });

    test('setBlocked flips the local block flag', () async {
      final repo = ContactsRepository(db);
      await repo.upsertLocalOnly(
        id: 'c3',
        displayName: 'Eve',
        avatarId: 'mdi:5',
      );
      await repo.setBlocked(id: 'c3', blocked: true);
      expect((await repo.get('c3'))!.isBlocked, isTrue);
      await repo.setBlocked(id: 'c3', blocked: false);
      expect((await repo.get('c3'))!.isBlocked, isFalse);
    });

    test('list omits legacy manual local ids (contact:local:*)', () async {
      final repo = ContactsRepository(db);
      await repo.upsertLocalOnly(
        id: 'contact:local:111',
        displayName: 'Manual',
        avatarId: 'mdi:0',
      );
      await repo.upsertLocalOnly(
        id: 'contact:handshake:deadbeef',
        displayName: 'Stub',
        avatarId: 'mdi:1',
      );
      final visible = await repo.list();
      expect(visible.map((c) => c.id).toList(), ['contact:handshake:deadbeef']);
    });
  });

  group('ContactInvitationsRepository', () {
    test('generate persists a pending row and produces a renderable code',
        () async {
      final repo = ContactInvitationsRepository(db);
      final result = await repo.generate(validFor: const Duration(hours: 1));
      expect(result.row.status, InvitationStatus.pending);
      expect(result.shortCode, isNotEmpty);
      expect(result.deepLink, startsWith('bojairu://'));
      // The on-device row id matches the invitation id embedded in the code.
      expect(result.row.id, result.code.invitationIdHex());
    });

    test('revoke transitions a pending row to revoked', () async {
      final repo = ContactInvitationsRepository(db);
      final result = await repo.generate(validFor: const Duration(hours: 1));
      final ok = await repo.revoke(result.row.id);
      expect(ok, isTrue);
      final rows = await repo.listWithFreshStatus();
      final updated = rows.firstWhere((r) => r.id == result.row.id);
      expect(updated.status, InvitationStatus.revoked);
      // Second revoke is a no-op.
      final second = await repo.revoke(result.row.id);
      expect(second, isFalse);
    });

    test('listWithFreshStatus auto-expires past-deadline pending rows',
        () async {
      final repo = ContactInvitationsRepository(db);
      final inThePast = DateTime.now().toUtc().subtract(const Duration(hours: 2));
      final result = await repo.generate(
        validFor: const Duration(hours: 1),
        now: inThePast,
      );
      expect(result.row.status, InvitationStatus.pending);
      final rows = await repo.listWithFreshStatus();
      final refreshed = rows.firstWhere((r) => r.id == result.row.id);
      expect(refreshed.status, InvitationStatus.expired);
    });

    test(
        'markUsed transitions pending to used; expired rows cannot be marked used',
        () async {
      final repo = ContactInvitationsRepository(db);
      final result = await repo.generate(validFor: const Duration(hours: 1));
      final ok = await repo.markUsed(result.row.id);
      expect(ok, isTrue);
      // Trying again is a no-op since the row is no longer pending.
      final second = await repo.markUsed(result.row.id);
      expect(second, isFalse);

      final expired = await repo.generate(
        validFor: const Duration(hours: 1),
        now: DateTime.now().toUtc().subtract(const Duration(hours: 2)),
      );
      final third = await repo.markUsed(expired.row.id);
      expect(third, isFalse);
      final rows = await repo.listWithFreshStatus();
      final ref = rows.firstWhere((r) => r.id == expired.row.id);
      expect(ref.status, InvitationStatus.expired);
    });
  });
}

class AppDatabaseForTesting extends AppDatabase {
  // ignore: use_super_parameters
  AppDatabaseForTesting(QueryExecutor e) : super.forTesting(e);
}
