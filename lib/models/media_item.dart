class MediaAlbum {
  final String id;
  final String name;
  final int count;

  const MediaAlbum({required this.id, required this.name, required this.count});

  factory MediaAlbum.fromMap(Map<dynamic, dynamic> map) {
    return MediaAlbum(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Unnamed Album',
      count: (map['count'] as num?)?.toInt() ?? 0,
    );
  }
}

enum MediaType { image, video }

class MediaItem {
  final String id;
  final MediaType type;
  final String path;
  final DateTime? createDateTime;
  final bool isFavorite;
  final bool isLivePhoto;
  final String? liveVideoPath;
  final bool isMarkedForDelete;

  const MediaItem({
    required this.id,
    required this.type,
    required this.path,
    this.createDateTime,
    required this.isFavorite,
    required this.isLivePhoto,
    this.liveVideoPath,
    this.isMarkedForDelete = false,
  });

  bool get isVideo => type == MediaType.video;
  bool get isImage => type == MediaType.image;

  factory MediaItem.fromMap(Map<dynamic, dynamic> map) {
    final createdAt = map['createDateTime'] as int?;
    return MediaItem(
      id: map['id'] as String? ?? '',
      type: (map['type'] as String?) == 'video'
          ? MediaType.video
          : MediaType.image,
      path: map['path'] as String? ?? '',
      createDateTime: createdAt != null
          ? DateTime.fromMillisecondsSinceEpoch(createdAt)
          : null,
      isFavorite: map['isFavorite'] as bool? ?? false,
      isLivePhoto: map['isLivePhoto'] as bool? ?? false,
      liveVideoPath: map['liveVideoPath'] as String?,
      isMarkedForDelete: map['isMarkedForDelete'] as bool? ?? false,
    );
  }
}
