/// Where my host application stands (identity.my_host_status).
enum HostState { none, pending, approved, rejected, suspended }

class HostStatus {
  const HostStatus(this.state, {this.reason});
  final HostState state;

  /// Why an application was rejected.
  final String? reason;

  static const none = HostStatus(HostState.none);

  /// [rows] is what `identity.my_host_status()` returned; an empty list or a word we do not know is [none].
  factory HostStatus.fromRows(List<dynamic> rows) {
    if (rows.isEmpty) return none;
    final r = rows.first as Map<String, dynamic>;
    final state = HostState.values.asNameMap()[r['status']] ?? HostState.none;
    return HostStatus(state, reason: r['reason'] as String?);
  }
}
