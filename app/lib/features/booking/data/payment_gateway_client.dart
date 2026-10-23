import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';
import '../domain/booking.dart';

/// Takes the payment on the gateway's page. The real provider's client is a later task; dev and staging use
/// [MockGatewayClient]. The webhook, not this call, decides the outcome: pay() only says the attempt was made.
abstract class PaymentGatewayClient {
  /// True for the mock: the Gateway screen then offers to force success, failure or a slow answer.
  bool get canSimulate;

  /// [simulate] (success | failed | pending) is honoured by the mock only, so a tester can force an outcome.
  Future<void> pay(PaymentSession session, String method, {String? simulate});
}

class MockGatewayClient implements PaymentGatewayClient {
  MockGatewayClient(this._ref);
  final Ref _ref;

  @override
  bool get canSimulate => true;

  @override
  Future<void> pay(PaymentSession session, String method, {String? simulate}) async {
    await _ref.read(supabaseClientProvider).functions.invoke('mock-gateway-pay', body: {
      'attemptId': session.attemptId,
      'method': method,
      'forceOutcome': ?simulate,
    });
  }
}

final paymentGatewayClientProvider = Provider<PaymentGatewayClient>((ref) => MockGatewayClient(ref));
