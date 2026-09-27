import 'package:flutter_test/flutter_test.dart';
import 'package:profile_repository/profile_repository.dart';

/// What [DisplayName.check] made of [raw]: the accepted name, or the
/// problem it refused it for.
Object? _outcome(String raw) => switch (DisplayName.check(raw)) {
  DisplayNameAccepted(:final name) => name.value,
  DisplayNameRefused(:final problem) => problem,
};

void main() {
  group(DisplayName, () {
    test('accepts a name, trimmed as Dart trims', () {
      expect(_outcome('Peter'), 'Peter');
      expect(_outcome('  Peter \n'), 'Peter');
      // A no-break space and the byte order mark are trimmed too, as the
      // table's check expects.
      expect(_outcome(' ﻿Peter　'), 'Peter');
      expect(_outcome('Anna Lena'), 'Anna Lena');
    });

    test('accepts any script', () {
      expect(_outcome('ペーター'), 'ペーター');
      expect(_outcome('Zoë'), 'Zoë');
      expect(_outcome('محمد'), 'محمد');
    });

    test('refuses a name that is empty once trimmed', () {
      expect(_outcome(''), DisplayNameProblem.empty);
      expect(_outcome('   '), DisplayNameProblem.empty);
      expect(_outcome(' \n'), DisplayNameProblem.empty);
    });

    test('counts forty code points, not UTF-16 units or graphemes', () {
      expect(_outcome('a' * 40), 'a' * 40);
      expect(_outcome('a' * 41), DisplayNameProblem.tooLong);
      // An emoji outside the basic plane is two UTF-16 units but one code
      // point: forty of them fit, as they do in the table.
      expect(_outcome('😀' * 40), '😀' * 40);
      expect(_outcome('😀' * 41), DisplayNameProblem.tooLong);
      // A family emoji is one grapheme of seven code points; six of them
      // are 42 code points, which the table refuses, so this does too.
      expect(_outcome('👨‍👩‍👧‍👦' * 6), DisplayNameProblem.tooLong);
    });

    test('measures the length after trimming', () {
      expect(_outcome('  ${'a' * 40}  '), 'a' * 40);
    });

    test('refuses a control character anywhere in the name', () {
      expect(_outcome('Pe\nter'), DisplayNameProblem.controlCharacter);
      expect(_outcome('Pe\tter'), DisplayNameProblem.controlCharacter);
      expect(_outcome('Pe\u0000ter'), DisplayNameProblem.controlCharacter);
      expect(_outcome('Pe\u007fter'), DisplayNameProblem.controlCharacter);
      expect(_outcome('Pe\u0085ter'), DisplayNameProblem.controlCharacter);
      expect(_outcome('Pe\u009fter'), DisplayNameProblem.controlCharacter);
    });

    test('says nothing of the name when printed', () {
      final check = DisplayName.check('Needle');

      expect('$check', isNot(contains('Needle')));
      expect(
        '${(check as DisplayNameAccepted).name}',
        isNot(contains('Needle')),
      );
    });

    test('equals another accepted name with the same text', () {
      final peter = (DisplayName.check('Peter') as DisplayNameAccepted).name;

      expect(peter, (DisplayName.check(' Peter') as DisplayNameAccepted).name);
      expect(peter.hashCode, 'Peter'.hashCode);
      expect(
        peter,
        isNot((DisplayName.check('Petra') as DisplayNameAccepted).name),
      );
    });
  });
}
