/// Every table of the `public` schema as typed rows, inserts, updates and
/// columns, generated from the migrations by `supabase_typegen` (`melos run
/// schema:generate`) and never edited by hand. Each repository that reads or
/// writes a table imports it from here, so a renamed column or a missing
/// required value fails to compile instead of failing at the server.
///
/// No tests of its own: it holds generated code only, which the coverage
/// gate excludes, and the repositories exercise it.
library;

export 'src/supabase_schema.g.dart';
