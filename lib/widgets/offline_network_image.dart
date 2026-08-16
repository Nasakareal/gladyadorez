import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../services/api_client.dart';

class OfflineNetworkImage extends StatefulWidget {
  const OfflineNetworkImage({
    super.key,
    required this.url,
    required this.api,
    this.fit = BoxFit.cover,
  });

  final String url;
  final ApiClient api;
  final BoxFit fit;

  @override
  State<OfflineNetworkImage> createState() => _OfflineNetworkImageState();
}

class _OfflineNetworkImageState extends State<OfflineNetworkImage> {
  File? _file;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant OfflineNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      final previous = _file;
      _file = null;
      if (previous != null) FileImage(previous).evict();
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final root = await getApplicationSupportDirectory();
    final directory = Directory(p.join(root.path, 'feed_images'));
    await directory.create(recursive: true);
    final file = File(p.join(directory.path, '${_stableHash(widget.url)}.img'));
    if (await file.exists() && await file.length() > 0) {
      if (mounted && generation == _generation) setState(() => _file = file);
      final modified = await file.lastModified();
      if (DateTime.now().difference(modified) < const Duration(hours: 24)) {
        return;
      }
    }
    try {
      final response = await widget.api.dio.get<List<int>>(
        widget.url,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) return;
      await file.writeAsBytes(bytes, flush: false);
      await _prune(directory, keep: file);
      if (mounted && generation == _generation) setState(() => _file = file);
    } catch (_) {
      // Conserva la copia local cuando no hay conexión.
    }
  }

  static Future<void> _prune(Directory directory, {required File keep}) async {
    try {
      final files = await directory
          .list()
          .where((item) => item is File)
          .cast<File>()
          .toList();
      if (files.length <= 40) return;
      files.sort(
        (a, b) => a.statSync().modified.compareTo(b.statSync().modified),
      );
      for (final file in files.take(files.length - 40)) {
        if (file.path != keep.path) await file.delete();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _generation++;
    final file = _file;
    if (file != null) FileImage(file).evict();
    super.dispose();
  }

  static String _stableHash(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash.toRadixString(16);
  }

  @override
  Widget build(BuildContext context) {
    final file = _file;
    if (file == null) {
      return const ColoredBox(
        color: Color(0xFFE7DEE1),
        child: Center(
          child: Icon(Icons.image_outlined, size: 42, color: Colors.black38),
        ),
      );
    }
    return Image.file(
      file,
      fit: widget.fit,
      cacheWidth: 1080,
      filterQuality: FilterQuality.low,
    );
  }
}
