import 'package:contract/contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(UserContext, () {
    test('encodes a chosen name in the agent wire shape', () {
      const context = UserContext(displayName: 'Maya');

      expect(context.toJson(), {
        'display_name': 'Maya',
        'name_is_placeholder': false,
      });
    });

    test('encodes a placeholder emotely picked as one', () {
      const context = UserContext(
        displayName: 'Pebble',
        nameIsPlaceholder: true,
      );

      expect(context.toJson(), {
        'display_name': 'Pebble',
        'name_is_placeholder': true,
      });
    });

    test('leaves out a name it does not have', () {
      expect(const UserContext().toJson(), {'name_is_placeholder': false});
    });

    test('decodes what it encodes', () {
      const context = UserContext(
        displayName: 'Pebble',
        nameIsPlaceholder: true,
      );

      expect(UserContext.fromJson(context.toJson()), context);
    });

    test('never prints the name, so a log cannot carry it', () {
      const context = UserContext(displayName: 'NEEDLE_NAME');

      expect('$context', isNot(contains('NEEDLE_NAME')));
    });
  });
}
