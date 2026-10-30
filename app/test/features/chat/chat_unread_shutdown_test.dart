import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jom/core/supabase_client.dart';
import 'package:jom/features/chat/data/chat_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'the_unread_badge_stream_can_be_cancelled_while_the_app_shuts_down',
    () async {
      final c = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(
            SupabaseClient('http://127.0.0.1:1', 'key'),
          ),
        ],
      );
      final sub = c.read(chatRepositoryProvider).unread().listen((_) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      c.dispose(); // the app closing: providers go first, then the stream's subscription is cancelled
      await sub.cancel();
    },
  );
}
