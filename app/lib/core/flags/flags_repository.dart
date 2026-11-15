import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase_client.dart';

/// Whether this app shows the host entrance. Off means no Register or Switch to Host mode card and no Host mode
/// routes. A missing flag is on.
bool hostEntryFrom(List<dynamic> rows) {
  for (final r in rows) {
    if ((r as Map<String, dynamic>)['key'] == 'host_entry_enabled') {
      return r['value'] != false;
    }
  }
  return true;
}

abstract class FlagsRepository {
  Future<bool> hostEntryEnabled();
}

class SupabaseFlagsRepository implements FlagsRepository {
  SupabaseFlagsRepository(this._db);
  final SupabaseClient _db;

  // shortcut: a failed read keeps the entrance on, so a network blip does not hide it from an approved host.
  @override
  Future<bool> hostEntryEnabled() async {
    try {
      return hostEntryFrom(await _db.schema('app').rpc('get_flags') as List);
    } catch (_) {
      return true;
    }
  }
}

final flagsRepositoryProvider = Provider<FlagsRepository>(
  (ref) => SupabaseFlagsRepository(ref.watch(supabaseClientProvider)),
);

final hostEntryEnabledProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(flagsRepositoryProvider).hostEntryEnabled(),
);
