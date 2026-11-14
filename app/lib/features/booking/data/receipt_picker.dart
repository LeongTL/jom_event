import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/booking.dart';

/// Picks a receipt photo from the camera (true) or the gallery (false); null when the guest backs out. Tests replace it.
typedef ReceiptPicker = Future<Uint8List?> Function(bool camera);

const maxReceiptBytes = 5 * 1024 * 1024;

// Shrinking happens in the picker (max 1600 px, quality 80), so a phone photo stays well under the 5 MB limit.
Future<Uint8List?> _pick(bool camera) async {
  final file = await ImagePicker().pickImage(
    source: camera ? ImageSource.camera : ImageSource.gallery,
    maxWidth: 1600,
    imageQuality: 80,
  );
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  if (bytes.length > maxReceiptBytes) throw BookingError('receipt_too_big');
  return bytes;
}

final receiptPickerProvider = Provider<ReceiptPicker>((ref) => _pick);
