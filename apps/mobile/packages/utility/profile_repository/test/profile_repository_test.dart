import 'package:flutter_test/flutter_test.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:testing/testing.dart';

DisplayName _name(String raw) =>
    (DisplayName.check(raw) as DisplayNameAccepted).name;

void main() {
  group(ProfileRepository, () {
    late SupabaseStub supabase;
    late ProfileRepository repository;

    setUp(() {
      supabase = SupabaseStub();
      repository = ProfileRepository(supabase: supabase.supabase);
    });

    group('profile', () {
      test("reads the signed-in user's row", () async {
        supabase.rest(profileRead, [
          rows([profileRow(displayName: 'Peter')]),
        ]);

        expect(
          await repository.profile(),
          const Profile(displayName: 'Peter', nameIsPlaceholder: false),
        );
        // No filter by user: row-level security answers with the caller's
        // own row and nobody else's (ADR 0010).
        final read = supabase.to(profileRead).single;
        expect(read.query.keys, isNot(contains('user_id')));
      });

      test('says when the name is a placeholder', () async {
        supabase.rest(profileRead, [
          rows([profileRow(displayName: 'Pebble', nameIsPlaceholder: true)]),
        ]);

        expect(
          await repository.profile(),
          const Profile(displayName: 'Pebble', nameIsPlaceholder: true),
        );
      });

      test('is nothing when the user has no profile yet', () async {
        supabase.rest(profileRead, [rows(const [])]);

        expect(await repository.profile(), isNull);
      });

      test('passes a refusal on', () async {
        supabase.rest(profileRead, [restRefused()]);

        await expectLater(
          repository.profile(),
          throwsA(isA<PostgrestApiException>()),
        );
      });
    });

    group('saveDisplayName', () {
      test("upserts the name on the user's own row", () async {
        supabase.rest(profileSave, [rowsChanged()]);

        final saved = await repository.saveDisplayName(_name(' Peter '));

        expect(
          saved,
          const Profile(displayName: 'Peter', nameIsPlaceholder: false),
        );
        final write = supabase.to(profileSave).single;
        expect(write.query['on_conflict'], 'user_id');
        // Only the columns the user may write: the key defaults to the
        // caller, and the timestamps are the server's (a client that sends
        // them is refused with 42501).
        expect(write.body, {
          'display_name': 'Peter',
          'name_is_placeholder': false,
        });
      });

      test('marks a placeholder as one', () async {
        supabase.rest(profileSave, [rowsChanged()]);

        final saved = await repository.saveDisplayName(
          _name('Pebble'),
          isPlaceholder: true,
        );

        expect(saved.nameIsPlaceholder, isTrue);
        expect(supabase.bodies(profilesPath).single, {
          'display_name': 'Pebble',
          'name_is_placeholder': true,
        });
      });

      test('passes a refusal on', () async {
        supabase.rest(profileSave, [restRefused()]);

        await expectLater(
          repository.saveDisplayName(_name('Peter')),
          throwsA(isA<PostgrestApiException>()),
        );
      });
    });

    group('saved', () {
      test('tells every listener the profile as each save left it '
          '(#264)', () async {
        supabase.always(profileSave, rowsChanged());
        final first = <Profile>[];
        final second = <Profile>[];
        repository.saved.listen(first.add);
        repository.saved.listen(second.add);

        await repository.saveDisplayName(_name('Peter'));
        await repository.saveDisplayName(_name('Pebble'), isPlaceholder: true);
        await pumpEventQueue();

        const saves = [
          Profile(displayName: 'Peter', nameIsPlaceholder: false),
          Profile(displayName: 'Pebble', nameIsPlaceholder: true),
        ];
        expect(first, saves);
        expect(second, saves);
      });

      test('says nothing of a save Supabase refused', () async {
        supabase.rest(profileSave, [restRefused()]);
        final saves = <Profile>[];
        repository.saved.listen(saves.add);

        await expectLater(
          repository.saveDisplayName(_name('Peter')),
          throwsA(isA<PostgrestApiException>()),
        );
        await pumpEventQueue();

        expect(saves, isEmpty);
      });

      test('keeps nothing for a listener that comes later', () async {
        supabase.rest(profileSave, [rowsChanged()]);
        await repository.saveDisplayName(_name('Peter'));
        final saves = <Profile>[];

        repository.saved.listen(saves.add);
        await pumpEventQueue();

        expect(saves, isEmpty);
      });
    });

    group('signIn', () {
      test('is nothing while nobody is signed in', () {
        expect(repository.signIn(), isNull);
      });

      test("is the signed-in user's address and method", () async {
        await supabase.signedIn(provider: 'google');

        expect(
          repository.signIn(),
          const SignInIdentity(
            email: SupabaseStub.email,
            method: SignInVia.google,
          ),
        );
      });
    });
  });

  group(Profile, () {
    test('says nothing of the name when printed', () {
      const profile = Profile(displayName: 'Needle', nameIsPlaceholder: false);

      expect('$profile', isNot(contains('Needle')));
    });
  });
}
