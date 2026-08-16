class FeedItem {
  const FeedItem({
    required this.type,
    required this.id,
    required this.author,
    required this.title,
    required this.body,
    required this.meta,
    required this.createdAt,
    required this.route,
    this.imageUrl,
  });

  final String type;
  final int id;
  final String author;
  final String title;
  final String body;
  final String meta;
  final String? imageUrl;
  final DateTime? createdAt;
  final String route;

  factory FeedItem.fromJson(Map<String, dynamic> json) => FeedItem(
    type: '${json['type'] ?? ''}',
    id: int.tryParse('${json['id'] ?? 0}') ?? 0,
    author: '${json['author'] ?? 'Equipo Gladyz'}',
    title: '${json['title'] ?? ''}',
    body: '${json['body'] ?? ''}',
    meta: '${json['meta'] ?? ''}',
    imageUrl: _text(json['image_url']),
    createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
    route: '${json['route'] ?? ''}',
  );

  Map<String, dynamic> toJson() => {
    'type': type,
    'id': id,
    'author': author,
    'title': title,
    'body': body,
    'meta': meta,
    'image_url': imageUrl,
    'created_at': createdAt?.toIso8601String(),
    'route': route,
  };

  static String? _text(Object? value) {
    final text = '${value ?? ''}'.trim();
    return text.isEmpty ? null : text;
  }
}
