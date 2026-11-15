import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';

/// A row of the pending list. No contact details: the reviewer decides from the application.
class PendingApplication {
  const PendingApplication({
    required this.userId,
    required this.hostName,
    required this.area,
    required this.createdAt,
  });
  final String userId;
  final String hostName;
  final String area;
  final DateTime createdAt;

  factory PendingApplication.fromJson(Map<String, dynamic> j) =>
      PendingApplication(
        userId: j['user_id'] as String,
        hostName: j['host_name'] as String,
        area: j['area'] as String? ?? '',
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class Application {
  const Application({
    required this.hostName,
    required this.area,
    required this.bio,
    required this.ssmNumber,
    required this.accountHolder,
    required this.bank,
    required this.accountNumber,
    required this.qrPath,
    required this.status,
    required this.rejectReason,
  });
  final String hostName;
  final String area;
  final String? bio;
  final String? ssmNumber;
  final String? accountHolder;
  final String? bank;
  final String? accountNumber;
  final String? qrPath;
  final String status;
  final String? rejectReason;

  factory Application.fromJson(Map<String, dynamic> j) => Application(
    hostName: j['host_name'] as String,
    area: j['area'] as String? ?? '',
    bio: j['bio'] as String?,
    ssmNumber: j['ssm_number'] as String?,
    accountHolder: j['account_holder'] as String?,
    bank: j['bank'] as String?,
    accountNumber: j['account_number'] as String?,
    qrPath: j['qr_path'] as String?,
    status: j['status'] as String,
    rejectReason: j['reject_reason'] as String?,
  );
}

/// What an admin does with host applications. Every call needs an admin who has given the second factor.
abstract class AdminRepository {
  Future<List<PendingApplication>> pendingHosts();
  Future<Application> application(String userId);

  /// [decision] is `approve` or `reject` (a reject needs a [reason]). The database records who decided and when.
  Future<void> review(String userId, String decision, {String? reason});

  /// A short-lived link to the payment QR the host uploaded.
  Future<String?> qrUrl(String path);
}

class SupabaseAdminRepository implements AdminRepository {
  SupabaseAdminRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<List<PendingApplication>> pendingHosts() async {
    final rows =
        await _client.schema('identity').rpc('pending_hosts') as List<dynamic>;
    return [
      for (final r in rows)
        PendingApplication.fromJson(r as Map<String, dynamic>),
    ];
  }

  @override
  Future<Application> application(String userId) async {
    final rows =
        await _client
                .schema('identity')
                .rpc('host_application', params: {'p_user_id': userId})
            as List<dynamic>;
    return Application.fromJson(rows.first as Map<String, dynamic>);
  }

  @override
  Future<void> review(String userId, String decision, {String? reason}) =>
      _client
          .schema('identity')
          .rpc(
            'admin_review_host',
            params: {
              'p_user_id': userId,
              'p_decision': decision,
              'p_reason': reason,
            },
          );

  @override
  Future<String?> qrUrl(String path) =>
      _client.storage.from('payment-qr').createSignedUrl(path, 300);
}

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => SupabaseAdminRepository(ref.watch(supabaseClientProvider)),
);

final pendingApplicationsProvider =
    FutureProvider.autoDispose<List<PendingApplication>>(
      (ref) => ref.watch(adminRepositoryProvider).pendingHosts(),
    );

/// Plain words for what the database refuses.
String adminMessage(Object e) {
  final m = e is PostgrestException ? e.message : '$e';
  return switch (m) {
    'mfa_required' =>
      'Your session needs the two-factor code. Sign out and sign in again.',
    'not_admin' => 'This account is not an admin.',
    'bad_state' => 'This application has already been decided.',
    'reason_required' => 'Give a reason first.',
    _ => 'Something went wrong. Check your connection and try again.',
  };
}
