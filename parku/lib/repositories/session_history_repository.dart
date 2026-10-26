import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/parking_summary.dart';

class SessionHistoryRepository {
  final SupabaseClient client;
  final Future<Directory> Function() _getDirectory;

  SessionHistoryRepository(
    this.client, {
    Future<Directory> Function()? getDirectory,
  }) : _getDirectory = getDirectory ?? getApplicationSupportDirectory;

  bool get isAvailable => !kIsWeb;

  String get _userId =>
      client.auth.currentUser?.id ??
      (throw const AuthException('Sign in to view your saved parking.'));

  Future<Directory> _userDirectory(String userId) async {
    final root = await _getDirectory();
    return Directory(
      '${root.path}/parking_history/user_${Uri.encodeComponent(userId)}',
    );
  }

  Future<void> saveSummary(ParkingSummary summary) async {
    final userId = _userId;
    if (summary.userId != userId) {
      throw const AuthException(
        'This parking summary belongs to another user.',
      );
    }
    if (!isAvailable) {
      throw UnsupportedError('Saved parking is available in the mobile app.');
    }

    final directory = await _userDirectory(userId);
    await directory.create(recursive: true);
    final file = File(
      '${directory.path}/session_${Uri.encodeComponent(summary.sessionId)}.json',
    );
    final temporary = File(
      '${file.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );

    try {
      await temporary.writeAsString(jsonEncode(summary.toMap()), flush: true);
      if (client.auth.currentUser?.id != userId) {
        throw const AuthException('The signed-in account has changed.');
      }
      await temporary.rename(file.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  Future<List<ParkingSummary>> getSavedSessions() async {
    final userId = _userId;
    if (!isAvailable) {
      throw UnsupportedError('Saved parking is available in the mobile app.');
    }

    final directory = await _userDirectory(userId);
    if (!await directory.exists()) return [];

    final summaries = <ParkingSummary>[];
    await for (final entry in directory.list()) {
      if (entry is! File || !entry.path.endsWith('.json')) continue;

      final data = jsonDecode(await entry.readAsString());
      final summary = ParkingSummary.fromMap(data as Map<String, dynamic>);
      if (summary.userId == userId) summaries.add(summary);
    }

    if (client.auth.currentUser?.id != userId) return [];
    summaries.sort((first, second) => second.endedAt.compareTo(first.endedAt));
    return summaries;
  }
}
