import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

bool isConnectionError(Object error) {
  if (error is TimeoutException ||
      error is SocketException ||
      error is http.ClientException ||
      error is AuthRetryableFetchException) {
    return true;
  }
  if (error is PostgrestException) {
    return [
      '500',
      '502',
      '503',
      '504',
      'PGRST000',
      'PGRST001',
      'PGRST002',
      'PGRST003',
    ].contains(error.code);
  }
  return false;
}

class ConnectionFailure implements Exception {
  final String message;
  const ConnectionFailure(this.message);

  @override
  String toString() => message;
}
