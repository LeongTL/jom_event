import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Now", so tests can hold the clock still.
final nowProvider = Provider<DateTime Function()>((ref) => DateTime.now);
