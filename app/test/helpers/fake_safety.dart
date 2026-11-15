import 'package:jom/features/safety/data/safety_repository.dart';
import 'package:jom/features/safety/domain/safety.dart';

/// Records what the user reported and blocked; [blockedUsers] is the list the Blocked users screen shows.
class FakeSafety implements SafetyRepository {
  FakeSafety({List<BlockedUser> blockedUsers = const []})
    : blockedUsers = [...blockedUsers];

  final List<BlockedUser> blockedUsers;
  final blocks = <String>[];
  final unblocks = <String>[];
  final reports = <(ReportTarget, String, ReportReason, String?)>[];
  Object? reportError;

  /// Lets a test hide the person elsewhere, as the database does once a block exists.
  void Function(String userId)? onBlock;

  @override
  Future<void> block(String userId) async {
    blocks.add(userId);
    onBlock?.call(userId);
  }

  @override
  Future<void> unblock(String userId) async {
    unblocks.add(userId);
    blockedUsers.removeWhere((b) => b.userId == userId);
  }

  @override
  Future<List<BlockedUser>> blocked() async => [...blockedUsers];

  @override
  Future<void> report({
    required ReportTarget target,
    required String targetId,
    required ReportReason reason,
    String? note,
  }) async {
    if (reportError != null) throw reportError!;
    reports.add((target, targetId, reason, note));
  }
}
