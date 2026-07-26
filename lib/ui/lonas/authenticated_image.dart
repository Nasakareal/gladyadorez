import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_client.dart';

class AuthenticatedImage extends StatefulWidget {
  const AuthenticatedImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
  });

  final String url;
  final BoxFit fit;

  @override
  State<AuthenticatedImage> createState() => _AuthenticatedImageState();
}

class _AuthenticatedImageState extends State<AuthenticatedImage> {
  late Future<Map<String, String>> _headers;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _headers = context.read<ApiClient>().authorizationHeaders();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: _headers,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const ColoredBox(
            color: Color(0xFFECEFF1),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return Image.network(
          widget.url,
          headers: snapshot.data,
          fit: widget.fit,
          errorBuilder: (_, _, _) => const ColoredBox(
            color: Color(0xFFECEFF1),
            child: Center(child: Icon(Icons.broken_image_outlined)),
          ),
        );
      },
    );
  }
}
