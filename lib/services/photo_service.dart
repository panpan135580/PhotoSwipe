import '../models/media_item.dart';
import 'photo_library_service.dart';

class PhotoService {
  static Future<List<MediaAlbum>> getAlbums() {
    return PhotoLibraryService.getAlbums();
  }

  static Future<List<MediaItem>> getAssetsFromAlbum({
    required MediaAlbum album,
    DateTime? startDate,
    DateTime? endDate,
    bool newestFirst = true,
  }) {
    return PhotoLibraryService.getAssetsFromAlbum(
      albumId: album.id,
      startDate: startDate,
      endDate: endDate,
      newestFirst: newestFirst,
    );
  }

  static Future<void> deleteAsset(MediaItem asset) {
    return PhotoLibraryService.deleteAsset(asset.id);
  }

  static Future<void> deleteAssets(List<MediaItem> assets) {
    final ids = assets.map((asset) => asset.id).toList();
    return PhotoLibraryService.deleteAssets(ids);
  }

  static Future<void> setFavoriteStatus(MediaItem asset, bool isFavorite) {
    return PhotoLibraryService.setFavorite(asset.id, isFavorite);
  }
}
