import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';
import 'package:path_provider/path_provider.dart';

final Uint8List _transparentTileBytes = Uint8List.fromList(<int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0xF8,
  0xCF,
  0xC0,
  0x00,
  0x00,
  0x03,
  0x01,
  0x01,
  0x00,
  0xC9,
  0xFE,
  0x92,
  0xEF,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

final MemoryImage _transparentTileImage = MemoryImage(_transparentTileBytes);

class _CachedOsmClient extends http.BaseClient {
  _CachedOsmClient() : _inner = RetryClient(http.Client(), retries: 1);

  final http.BaseClient _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final cacheFile = await _cacheFile(request.url);
    final cached = await _readCached(request, cacheFile);
    if (cached != null) return cached;

    try {
      final response = await _inner.send(request);
      if (response.statusCode >= 400) return _blank(request);
      final bytes = await response.stream.toBytes();
      if (cacheFile != null && bytes.isNotEmpty) {
        try {
          await cacheFile.parent.create(recursive: true);
          await cacheFile.writeAsBytes(bytes, flush: false);
        } catch (_) {}
      }
      return _bytes(request, bytes, headers: response.headers);
    } catch (_) {
      return _blank(request);
    }
  }

  static Future<File?> _cacheFile(Uri uri) async {
    if (kIsWeb || uri.pathSegments.length < 3) return null;
    try {
      final root = await getApplicationSupportDirectory();
      final parts = uri.pathSegments;
      final z = parts[parts.length - 3];
      final x = parts[parts.length - 2];
      final y = parts.last.replaceAll(RegExp(r'[^0-9A-Za-z_.-]'), '');
      return File(
        '${root.path}${Platform.pathSeparator}osm_tiles'
        '${Platform.pathSeparator}$z${Platform.pathSeparator}$x'
        '${Platform.pathSeparator}$y',
      );
    } catch (_) {
      return null;
    }
  }

  static Future<http.StreamedResponse?> _readCached(
    http.BaseRequest request,
    File? file,
  ) async {
    if (file == null) return null;
    try {
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      return bytes.isEmpty ? null : _bytes(request, bytes);
    } catch (_) {
      return null;
    }
  }

  static http.StreamedResponse _bytes(
    http.BaseRequest request,
    List<int> bytes, {
    Map<String, String> headers = const {},
  }) => http.StreamedResponse(
    Stream<List<int>>.value(bytes),
    200,
    request: request,
    headers: {
      ...headers,
      'content-type': headers['content-type'] ?? 'image/png',
      'content-length': '${bytes.length}',
    },
  );

  static http.StreamedResponse _blank(http.BaseRequest request) =>
      _bytes(request, _transparentTileBytes);

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

TileLayer buildSafeOpenStreetMapTileLayer({
  required String userAgentPackageName,
}) {
  return TileLayer(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    userAgentPackageName: userAgentPackageName,
    maxZoom: 19,
    panBuffer: 0,
    keepBuffer: 1,
    tileProvider: NetworkTileProvider(httpClient: _CachedOsmClient()),
    errorImage: _transparentTileImage,
    errorTileCallback: (_, __, ___) {},
  );
}
