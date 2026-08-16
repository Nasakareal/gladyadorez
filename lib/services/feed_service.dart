import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/feed_item.dart';
import 'api_client.dart';

class FeedPage {
  const FeedPage({
    required this.items,
    required this.hasMore,
    required this.nextCursor,
  });
  final List<FeedItem> items;
  final bool hasMore;
  final String? nextCursor;
}

class FeedService {
  const FeedService(this.api);
  final ApiClient api;

  String _cacheKey(int ownerId) => 'feed_lonas_cache_v2_$ownerId';

  Future<List<FeedItem>> cached(int ownerId) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw =
          jsonDecode(prefs.getString(_cacheKey(ownerId)) ?? '[]') as List;
      return raw
          .map(
            (item) => FeedItem.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<FeedPage> fetch({required int ownerId, String? cursor}) async {
    final response = await api.dio.get(
      '/v1/feed',
      queryParameters: {
        'per_page': 8,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
    );
    final json = Map<String, dynamic>.from(response.data as Map);
    final items = (json['items'] as List? ?? const [])
        .map(
          (item) => FeedItem.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    if (cursor == null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey(ownerId),
        jsonEncode(items.map((item) => item.toJson()).toList()),
      );
    }
    return FeedPage(
      items: items,
      hasMore: json['has_more'] == true,
      nextCursor: json['next_cursor']?.toString(),
    );
  }
}
