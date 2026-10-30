import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserLocalStore {
  final SupabaseClient client;
  final Future<Directory> Function() _getDirectory;
  final bool _memoryOnly;
  final _webData = <String, Map<String, dynamic>>{};
  final _writes = <String, Future<void>>{};

  UserLocalStore(this.client, {Future<Directory> Function()? getDirectory})
    : _getDirectory = getDirectory ?? getApplicationSupportDirectory,
      _memoryOnly = false;

  UserLocalStore.memory(this.client)
    : _getDirectory = getApplicationSupportDirectory,
      _memoryOnly = true;

  String get userId =>
      client.auth.currentUser?.id ??
      (throw const AuthException('Sign in to continue.'));

  void checkUser(String expected) {
    if (client.auth.currentUser?.id != expected) {
      throw const AuthException('The signed-in account has changed.');
    }
  }

  Future<File> _file(String owner, String key) async {
    final directory = await _getDirectory();
    return File(
      '${directory.path}/offline_data/user_${Uri.encodeComponent(owner)}/'
      'data_${Uri.encodeComponent(key)}.json',
    );
  }

  Future<Map<String, dynamic>?> read(String key) async {
    final owner = userId;
    await _writes['$owner:$key'];
    checkUser(owner);
    if (kIsWeb || _memoryOnly) return _webData['$owner:$key'];
    final file = await _file(owner, key);
    if (!await file.exists()) return null;
    final saved = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    checkUser(owner);
    if (saved['user_id'] != owner) return null;
    return saved['data'] as Map<String, dynamic>;
  }

  Future<void> write(String key, Map<String, dynamic> data) {
    final owner = userId;
    final pending = _writes['$owner:$key'] ?? Future<void>.value();
    final writing = pending.then((_) => _write(owner, key, Map.of(data)));
    _writes['$owner:$key'] = writing.catchError((Object _) {});
    return writing;
  }

  Future<void> _write(
    String owner,
    String key,
    Map<String, dynamic> data,
  ) async {
    checkUser(owner);
    if (kIsWeb || _memoryOnly) {
      _webData['$owner:$key'] = Map.of(data);
      return;
    }
    final file = await _file(owner, key);
    await file.parent.create(recursive: true);
    final temporary = File(
      '${file.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    try {
      await temporary.writeAsString(
        jsonEncode({'user_id': owner, 'data': data}),
        flush: true,
      );
      checkUser(owner);
      await temporary.rename(file.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  Future<void> remove(String key) async {
    final owner = userId;
    await _writes['$owner:$key'];
    checkUser(owner);
    if (kIsWeb || _memoryOnly) {
      _webData.remove('$owner:$key');
      return;
    }
    final file = await _file(owner, key);
    checkUser(owner);
    if (await file.exists()) await file.delete();
  }
}
