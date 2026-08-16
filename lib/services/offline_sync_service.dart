import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

class OfflineSubmitResult {
  const OfflineSubmitResult({required this.queued});
  final bool queued;
}

class OfflineSyncService with WidgetsBindingObserver {
  OfflineSyncService._();
  static final instance = OfflineSyncService._();

  static const _queueKey = 'gladyz_offline_queue_v1';
  final ValueNotifier<int> pendingCount = ValueNotifier(0);
  final ValueNotifier<bool> syncing = ValueNotifier(false);
  final ValueNotifier<bool> offline = ValueNotifier(false);

  ApiClient? _api;
  int? _ownerId;
  Timer? _timer;
  bool _flushing = false;

  Future<void> initialize(ApiClient api, {required int ownerId}) async {
    _api = api;
    _ownerId = ownerId;
    WidgetsBinding.instance.removeObserver(this);
    WidgetsBinding.instance.addObserver(this);
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 25),
      (_) => unawaited(flush()),
    );
    await _refreshCount();
    unawaited(flush());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(flush());
  }

  Future<OfflineSubmitResult> submitLona({
    required int ownerId,
    required Map<String, String> fields,
    required String photoPath,
    required String photoName,
  }) async {
    final api = _api;
    if (api == null) throw StateError('Sincronización no inicializada.');
    final stashed = await _stashFile(photoPath, photoName);
    final operation = <String, dynamic>{
      'id': '${DateTime.now().microsecondsSinceEpoch}-$ownerId',
      'owner_id': ownerId,
      'method': 'POST',
      'path': '/v1/lonas',
      'fields': fields,
      'file_path': stashed.path,
      'file_name': photoName,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'attempts': 0,
    };

    try {
      await _send(operation);
      await _deleteQuietly(stashed.path);
      offline.value = false;
      unawaited(flush());
      return const OfflineSubmitResult(queued: false);
    } on DioException catch (error) {
      if (!_retryable(error)) {
        await _deleteQuietly(stashed.path);
        rethrow;
      }
      await _enqueue(operation);
      offline.value = true;
      return const OfflineSubmitResult(queued: true);
    } catch (_) {
      await _enqueue(operation);
      offline.value = true;
      return const OfflineSubmitResult(queued: true);
    }
  }

  Future<void> flush() async {
    if (_flushing || _api == null || _ownerId == null) return;
    _flushing = true;
    syncing.value = true;
    try {
      final queue = await _load();
      final remaining = <Map<String, dynamic>>[];
      var reachedNetworkFailure = false;
      for (final operation in queue) {
        if (operation['owner_id'] != _ownerId || reachedNetworkFailure) {
          remaining.add(operation);
          continue;
        }
        try {
          await _send(operation);
          await _deleteQuietly('${operation['file_path'] ?? ''}');
          offline.value = false;
        } on DioException catch (error) {
          if (_retryable(error)) {
            operation['attempts'] = (operation['attempts'] as num? ?? 0) + 1;
            remaining.add(operation);
            reachedNetworkFailure = true;
            offline.value = true;
          } else {
            // Un 4xx no mejorará al recuperar señal: se conserva para que el
            // usuario no pierda la captura y pueda reintentarse tras corregir servidor/permisos.
            operation['last_error'] = _errorMessage(error);
            remaining.add(operation);
          }
        } catch (_) {
          remaining.add(operation);
          reachedNetworkFailure = true;
          offline.value = true;
        }
      }
      await _save(remaining);
    } finally {
      _flushing = false;
      syncing.value = false;
      await _refreshCount();
    }
  }

  Future<void> _send(Map<String, dynamic> operation) async {
    final fields = Map<String, dynamic>.from(operation['fields'] as Map);
    final filePath = '${operation['file_path']}';
    final form = FormData.fromMap({
      ...fields,
      'foto': await MultipartFile.fromFile(
        filePath,
        filename: '${operation['file_name'] ?? p.basename(filePath)}',
      ),
    });
    await _api!.dio.post(
      '${operation['path']}',
      data: form,
      options: Options(sendTimeout: const Duration(seconds: 20)),
    );
  }

  static bool _retryable(DioException error) {
    final status = error.response?.statusCode;
    return status == null || status == 408 || status == 429 || status >= 500;
  }

  static String _errorMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['message'] != null) return '${data['message']}';
    return error.message ?? 'Error de sincronización';
  }

  Future<File> _stashFile(String sourcePath, String name) async {
    final root = await getApplicationSupportDirectory();
    final directory = Directory(p.join(root.path, 'offline_uploads'));
    await directory.create(recursive: true);
    final safeName = name.replaceAll(RegExp(r'[^0-9A-Za-z._-]'), '_');
    final target = File(
      p.join(
        directory.path,
        '${DateTime.now().microsecondsSinceEpoch}_$safeName',
      ),
    );
    return File(sourcePath).copy(target.path);
  }

  Future<void> _enqueue(Map<String, dynamic> operation) async {
    final queue = await _load()
      ..add(operation);
    await _save(queue);
  }

  static Future<List<Map<String, dynamic>>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = jsonDecode(prefs.getString(_queueKey) ?? '[]') as List;
      return raw.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _save(List<Map<String, dynamic>> queue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_queueKey, jsonEncode(queue));
  }

  Future<void> _refreshCount() async {
    final queue = await _load();
    pendingCount.value = queue
        .where((item) => item['owner_id'] == _ownerId)
        .length;
  }

  static Future<void> _deleteQuietly(String filePath) async {
    if (filePath.isEmpty) return;
    try {
      final file = File(filePath);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
