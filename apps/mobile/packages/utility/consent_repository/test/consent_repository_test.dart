import 'package:consent_repository/consent_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testing/testing.dart';

void main() {
  const version = '2026-09-15';

  late SupabaseStub supabase;
  late ConsentRepository repository;

  setUp(() {
    supabase = SupabaseStub();
    repository = ConsentRepository(
      supabase: supabase.supabase,
      version: version,
    );
  });

  group(ConsentRepository, () {
    test('asks the server whether consent to this version stands', () async {
      supabase.rest('POST /rest/v1/rpc/consent_stands', [rpcReturned(true)]);

      expect(await repository.isGranted(), isTrue);
      expect(supabase.bodies('/rest/v1/rpc/consent_stands').single, {
        'version': version,
      });
    });

    test(
      'a consent that does not stand is false, whatever the reason',
      () async {
        supabase.rest('POST /rest/v1/rpc/consent_stands', [rpcReturned(false)]);

        expect(await repository.isGranted(), isFalse);
      },
    );

    test('records consent to this version', () async {
      supabase.rest('POST /rest/v1/rpc/record_consent', [rpcReturned(null)]);

      await repository.grant();

      expect(supabase.bodies('/rest/v1/rpc/record_consent').single, {
        'version': version,
      });
    });

    test('reads when the journal consent was last given', () async {
      supabase.rest('GET /rest/v1/consent_events', [
        rows([
          {'recorded_at': '2026-09-20T18:30:00+00:00'},
        ]),
      ]);

      expect(await repository.grantedAt(), DateTime.utc(2026, 9, 20, 18, 30));
      final query = supabase.to('GET /rest/v1/consent_events').single.query;
      expect(query, {
        'select': 'recorded_at',
        'purpose': 'eq.journal',
        'version': 'eq.$version',
        'action': 'eq.granted',
        'order': 'seq.desc.nullslast',
        'limit': '1',
      });
    });

    test('knows no date for a consent never given', () async {
      supabase.rest('GET /rest/v1/consent_events', [rows(const [])]);

      expect(await repository.grantedAt(), isNull);
    });

    test('withdraws consent to this version', () async {
      supabase.rest('POST /rest/v1/rpc/withdraw_consent', [rpcReturned(null)]);

      await repository.withdraw();

      expect(supabase.bodies('/rest/v1/rpc/withdraw_consent').single, {
        'version': version,
      });
    });
  });
}
