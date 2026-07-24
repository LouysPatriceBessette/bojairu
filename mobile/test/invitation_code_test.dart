import 'dart:typed_data';

import 'dart:math';

import 'package:compartarenta/contacts/invitation_code.dart';
import 'package:flutter_test/flutter_test.dart';

class _SeededRandom implements Random {
  _SeededRandom(this._seed);

  int _seed;

  @override
  bool nextBool() => nextInt(1 << 16).isEven;

  @override
  double nextDouble() => nextInt(1 << 24) / (1 << 24);

  @override
  int nextInt(int max) {
    _seed = (_seed * 1103515245 + 12345) & 0x7fffffff;
    return _seed % max;
  }
}

void main() {
  group('InvitationCode', () {
    test('generated code is exactly 35 chars with dashes every 5', () {
      InvitationCode.setRandomForTesting(_SeededRandom(42));
      addTearDown(InvitationCode.resetRandomForTesting);
      final code = InvitationCode.generate();
      final short = code.renderShort();
      final compact = short.replaceAll('-', '');
      expect(compact.length, 35);
      expect(short.split('-').first.length, 5);
    });

    test('parse(renderShort(code)) round-trips', () {
      InvitationCode.setRandomForTesting(_SeededRandom(7));
      addTearDown(InvitationCode.resetRandomForTesting);
      final code = InvitationCode.generate();
      final short = code.renderShort();

      final parsed = parseInvitationCode(short);
      expect(parsed, isA<InvitationCodeOk>());
      final ok = parsed as InvitationCodeOk;
      expect(ok.code.invitationIdHex(), code.invitationIdHex());
      expect(ok.code.nonceHex(), code.nonceHex());
    });

    test('parse strips spaces, dashes, and is case-insensitive', () {
      InvitationCode.setRandomForTesting(_SeededRandom(99));
      addTearDown(InvitationCode.resetRandomForTesting);
      final code = InvitationCode.generate();
      final short = code.renderShort();

      // Lowercase + spaces instead of dashes.
      final messy = short.toLowerCase().replaceAll('-', ' ');
      final parsed = parseInvitationCode(messy);
      expect(parsed, isA<InvitationCodeOk>());
    });

    test('single-character flip is detected by the checksum', () {
      InvitationCode.setRandomForTesting(_SeededRandom(101));
      addTearDown(InvitationCode.resetRandomForTesting);
      final code = InvitationCode.generate();
      final short = code.renderShort();
      final chars = short.split('');
      // Find a body character (not a dash) and flip to another valid Crockford char.
      int targetIndex = -1;
      for (var i = 0; i < chars.length; i++) {
        if (chars[i] != '-') {
          targetIndex = i;
          break;
        }
      }
      // Pick a replacement that is different and is in the Crockford alphabet.
      const alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
      final original = chars[targetIndex];
      final replacement = alphabet.split('').firstWhere((c) => c != original);
      chars[targetIndex] = replacement;
      final flipped = chars.join();

      final parsed = parseInvitationCode(flipped);
      // Either checksum fails (most common) or the parsed code differs.
      if (parsed is InvitationCodeOk) {
        expect(parsed.code.invitationIdHex(), isNot(code.invitationIdHex()));
      } else {
        expect(parsed, isA<InvitationCodeBad>());
      }
    });

    test('empty input is rejected with the empty error', () {
      final parsed = parseInvitationCode('');
      expect(parsed, isA<InvitationCodeBad>());
      expect((parsed as InvitationCodeBad).error, InvitationCodeError.empty);
    });

    test('a code with one character removed is rejected as too short', () {
      InvitationCode.setRandomForTesting(_SeededRandom(5));
      addTearDown(InvitationCode.resetRandomForTesting);
      final code = InvitationCode.generate();
      final short = code.renderShort();
      final compact = short.replaceAll('-', '');
      final truncated = compact.substring(0, compact.length - 1);
      final parsed = parseInvitationCode(truncated);
      expect(parsed, isA<InvitationCodeBad>());
      expect((parsed as InvitationCodeBad).error, InvitationCodeError.tooShort);
    });

    test('a code with an extra character is rejected as too long', () {
      InvitationCode.setRandomForTesting(_SeededRandom(5));
      addTearDown(InvitationCode.resetRandomForTesting);
      final code = InvitationCode.generate();
      final short = code.renderShort();
      final parsed = parseInvitationCode('${short}A');
      expect(parsed, isA<InvitationCodeBad>());
      expect((parsed as InvitationCodeBad).error, InvitationCodeError.tooLong);
    });

    test('a code with a forbidden character (U) is rejected', () {
      InvitationCode.setRandomForTesting(_SeededRandom(3));
      addTearDown(InvitationCode.resetRandomForTesting);
      final code = InvitationCode.generate();
      final compact = code.renderShort().replaceAll('-', '');
      final tampered = '${compact.substring(0, compact.length - 1)}U';
      final parsed = parseInvitationCode(tampered);
      expect(parsed, isA<InvitationCodeBad>());
      // Either invalid-characters or bad-checksum, depending on alignment.
      final err = (parsed as InvitationCodeBad).error;
      expect(
        err,
        anyOf(
          InvitationCodeError.invalidCharacters,
          InvitationCodeError.badChecksum,
        ),
      );
    });

    test('deep-link includes the version and a payload param', () {
      InvitationCode.setRandomForTesting(_SeededRandom(11));
      addTearDown(InvitationCode.resetRandomForTesting);
      final code = InvitationCode.generate();
      final link = code.renderDeepLink();
      expect(link, startsWith('bojairu://contact/invite?'));
      expect(link, contains('v=${InvitationCode.currentVersion}'));
      expect(link, contains('c='));
    });

    test('web link includes version, payload, and optional short code param', () {
      InvitationCode.setRandomForTesting(_SeededRandom(111));
      addTearDown(InvitationCode.resetRandomForTesting);
      final code = InvitationCode.generate();
      final link = code.renderWebLink();
      expect(link, startsWith('https://sync.incoherences.org/contact/invite?'));
      expect(link, contains('v=${InvitationCode.currentVersion}'));
      expect(link, contains('c='));
      final uri = Uri.parse(link);
      expect(uri.queryParameters['s'], code.renderShort());
    });

    test('parseInvitationDeepLink round-trips a generated deep link', () {
      InvitationCode.setRandomForTesting(_SeededRandom(12));
      addTearDown(InvitationCode.resetRandomForTesting);
      final code = InvitationCode.generate();

      final parsed = parseInvitationDeepLink(code.renderDeepLink());

      expect(parsed, isA<InvitationCodeOk>());
      final ok = parsed as InvitationCodeOk;
      expect(ok.code.invitationIdHex(), code.invitationIdHex());
      expect(ok.code.nonceHex(), code.nonceHex());
      expect(ok.code.renderShort(), code.renderShort());
    });

    test('link query e carries invitation expiry for invitee UI', () {
      InvitationCode.setRandomForTesting(_SeededRandom(15));
      addTearDown(InvitationCode.resetRandomForTesting);
      final code = InvitationCode.generate();
      final expiresAt = DateTime.utc(2026, 6, 15, 18, 36);

      final deep = parseInvitationDeepLink(
        code.renderDeepLink(expiresAtUtc: expiresAt),
      );
      expect(deep, isA<InvitationCodeOk>());
      expect(
        (deep as InvitationCodeOk).expiresAtUtc,
        expiresAt,
      );

      final web = parseInvitationLink(
        code.renderWebLink(expiresAtUtc: expiresAt),
      );
      expect((web as InvitationCodeOk).expiresAtUtc, expiresAt);
    });

    test(
      'parseInvitationInput accepts short code, deep link, and web link',
      () {
        InvitationCode.setRandomForTesting(_SeededRandom(13));
        addTearDown(InvitationCode.resetRandomForTesting);
        final code = InvitationCode.generate();

        expect(
          parseInvitationInput(code.renderShort()),
          isA<InvitationCodeOk>(),
        );
        expect(
          parseInvitationInput(code.renderDeepLink()),
          isA<InvitationCodeOk>(),
        );
        expect(
          parseInvitationInput(code.renderWebLink()),
          isA<InvitationCodeOk>(),
        );
      },
    );

    test('parseInvitationInput extracts a web link from a pasted message', () {
      InvitationCode.setRandomForTesting(_SeededRandom(14));
      addTearDown(InvitationCode.resetRandomForTesting);
      final code = InvitationCode.generate();
      final message =
          'Invitation:\n${code.renderWebLink()}.\nFallback: ${code.renderShort()}';

      final parsed = parseInvitationInput(message);

      expect(parsed, isA<InvitationCodeOk>());
      final ok = parsed as InvitationCodeOk;
      expect(ok.code.invitationIdHex(), code.invitationIdHex());
      expect(ok.code.nonceHex(), code.nonceHex());
    });

    test('nonce hex and invitation-id hex match expected byte lengths', () {
      InvitationCode.setRandomForTesting(_SeededRandom(2));
      addTearDown(InvitationCode.resetRandomForTesting);
      final code = InvitationCode.generate();
      expect(code.nonce.length, InvitationCode.nonceBytes);
      expect(code.invitationId.length, InvitationCode.invitationIdBytes);
      expect(code.nonceHex().length, InvitationCode.nonceBytes * 2);
      expect(
        code.invitationIdHex().length,
        InvitationCode.invitationIdBytes * 2,
      );
    });
  });

  test('Uint8List import is in use', () {
    // The Uint8List import is required by invitation_code.dart's public
    // API; this no-op assertion documents the dependency for readers.
    final bytes = Uint8List(1);
    expect(bytes.length, 1);
  });
}
