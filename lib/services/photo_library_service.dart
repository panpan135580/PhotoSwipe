import 'package:flutter/services.dart';

import '../models/media_item.dart';

class PhotoLibraryService {
  static const MethodChannel _platform = MethodChannel(
    'com.example.photoswipe/photos',
  );

  static Future<List<MediaAlbum>> getAlbums() async {
    final List<dynamic> result = await _platform.invokeMethod('getAlbums');
    return result
        .map((dynamic e) => MediaAlbum.fromMap(e as Map<dynamic, dynamic>))
        .where((album) => album.count > 0)
        .toList();
  }

  static Future<List<MediaItem>> getAssetsFromAlbum({
    required String albumId,
    DateTime? startDate,
    DateTime? endDate,
    bool newestFirst = true,
  }) async {
    final List<dynamic> result = await _platform
        .invokeMethod('getAssetsFromAlbum', {
          'albumId': albumId,
          'offset': 0,
          'limit': 0,
          'newestFirst': newestFirst,
          'startDate': startDate?.millisecondsSinceEpoch,
          'endDate': endDate?.millisecondsSinceEpoch,
        });

    return result
        .map((dynamic e) => MediaItem.fromMap(e as Map<dynamic, dynamic>))
        .where((item) => item.path.isNotEmpty)
        .toList();
  }

  static Future<void> deleteAsset(String assetId) async {
    await _platform.invokeMethod('deleteAsset', {'assetId': assetId});
  }

  static Future<void> deleteAssets(List<String> assetIds) async {
    await _platform.invokeMethod('deleteAssets', {'assetIds': assetIds});
  }

  static Future<void> setFavorite(String assetId, bool isFavorite) async {
    await _platform.invokeMethod('setFavorite', {
      'assetId': assetId,
      'isFavorite': isFavorite,
    });
  }
}
