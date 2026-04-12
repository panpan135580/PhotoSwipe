import Flutter
import AVFoundation
import Photos
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let channelName = "com.example.photoswipe/photos"
  private let recentProjectsAlbumId = "__recent_projects__"
  private let exportCacheFolderName = "PhotoSwipeExportCache"
  private var photoChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let ok = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    setupLifecycleObservers()
    clearExportCache()

    if let registrar = self.registrar(forPlugin: "PhotoLibraryChannel") {
      let channel = FlutterMethodChannel(
        name: channelName,
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { [weak self] call, result in
        self?.handleMethodCall(call: call, result: result)
      }
      photoChannel = channel
    }

    return ok
  }

  private func setupLifecycleObservers() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleDidEnterBackground),
      name: UIApplication.didEnterBackgroundNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleWillTerminate),
      name: UIApplication.willTerminateNotification,
      object: nil
    )
  }

  @objc private func handleDidEnterBackground() {
    clearExportCache()
  }

  @objc private func handleWillTerminate() {
    clearExportCache()
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  private func handleMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPhotoAuthorizationStatus":
      result(photoAuthorizationStatus())
    case "requestPhotoAuthorization":
      requestPhotoAuthorization(result: result)
    case "presentLimitedLibraryPicker":
      presentLimitedLibraryPicker(result: result)
    case "getAlbums":
      DispatchQueue.global(qos: .userInitiated).async {
        let albums = self.getAlbums()
        DispatchQueue.main.async {
          result(albums)
        }
      }
    case "getAssetsFromAlbum":
      guard
        let args = call.arguments as? [String: Any],
        let albumId = args["albumId"] as? String
      else {
        result(FlutterError(code: "invalid_args", message: "albumId is required", details: nil))
        return
      }

      let offset = args["offset"] as? Int ?? 0
      let limit = args["limit"] as? Int ?? 200
      let newestFirst = args["newestFirst"] as? Bool ?? true
      let startDateMs = args["startDate"] as? Int64
      let endDateMs = args["endDate"] as? Int64

      DispatchQueue.global(qos: .userInitiated).async {
        let items = self.getAssetsFromAlbum(
          albumId: albumId,
          offset: offset,
          limit: limit,
          newestFirst: newestFirst,
          startDateMs: startDateMs,
          endDateMs: endDateMs
        )
        DispatchQueue.main.async {
          result(items)
        }
      }
    case "deleteAsset":
      guard
        let args = call.arguments as? [String: Any],
        let assetId = args["assetId"] as? String
      else {
        result(FlutterError(code: "invalid_args", message: "assetId is required", details: nil))
        return
      }
      deleteAsset(assetId: assetId, result: result)
    case "deleteAssets":
      guard
        let args = call.arguments as? [String: Any],
        let assetIds = args["assetIds"] as? [String]
      else {
        result(FlutterError(code: "invalid_args", message: "assetIds is required", details: nil))
        return
      }
      deleteAssets(assetIds: assetIds, result: result)
    case "setFavorite":
      guard
        let args = call.arguments as? [String: Any],
        let assetId = args["assetId"] as? String,
        let isFavorite = args["isFavorite"] as? Bool
      else {
        result(
          FlutterError(code: "invalid_args", message: "assetId and isFavorite are required", details: nil)
        )
        return
      }
      setFavorite(assetId: assetId, isFavorite: isFavorite, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func photoAuthorizationStatus() -> String {
    let status: PHAuthorizationStatus
    if #available(iOS 14, *) {
      status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    } else {
      status = PHPhotoLibrary.authorizationStatus()
    }
    return mapAuthorizationStatus(status)
  }

  private func requestPhotoAuthorization(result: @escaping FlutterResult) {
    if #available(iOS 14, *) {
      PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
        DispatchQueue.main.async {
          result(self.mapAuthorizationStatus(status))
        }
      }
    } else {
      PHPhotoLibrary.requestAuthorization { status in
        DispatchQueue.main.async {
          result(self.mapAuthorizationStatus(status))
        }
      }
    }
  }

  private func mapAuthorizationStatus(_ status: PHAuthorizationStatus) -> String {
    if #available(iOS 14, *) {
      switch status {
      case .authorized:
        return "authorized"
      case .limited:
        return "limited"
      case .denied:
        return "denied"
      case .restricted:
        return "restricted"
      case .notDetermined:
        return "notDetermined"
      @unknown default:
        return "denied"
      }
    } else {
      switch status {
      case .authorized:
        return "authorized"
      case .denied:
        return "denied"
      case .restricted:
        return "restricted"
      case .notDetermined:
        return "notDetermined"
      default:
        return "denied"
      }
    }
  }

  private func presentLimitedLibraryPicker(result: @escaping FlutterResult) {
    // Some Xcode/SDK combinations do not expose presentLimitedLibraryPicker.
    // Keep this method as a no-op and rely on opening system settings instead.
    result(nil)
  }

  private func getAlbums() -> [[String: Any]] {
    var output: [[String: Any]] = []
    var seenIds: Set<String> = []
    let options = assetFetchOptions()
    let allAssetsCount = PHAsset.fetchAssets(with: options).count
    if allAssetsCount > 0 {
      output.append([
        "id": recentProjectsAlbumId,
        "name": "最近项目",
        "count": allAssetsCount,
      ])
      seenIds.insert(recentProjectsAlbumId)
    }

    let topLevel = PHAssetCollection.fetchTopLevelUserCollections(with: nil)
    topLevel.enumerateObjects { collection, _, _ in
      guard let album = collection as? PHAssetCollection else { return }
      let assets = PHAsset.fetchAssets(in: album, options: options)
      guard assets.count > 0, !seenIds.contains(album.localIdentifier) else { return }
      seenIds.insert(album.localIdentifier)
      output.append([
        "id": album.localIdentifier,
        "name": album.localizedTitle ?? "Unnamed Album",
        "count": assets.count,
      ])
    }

    let smart = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil)
    smart.enumerateObjects { album, _, _ in
      let assets = PHAsset.fetchAssets(in: album, options: options)
      guard assets.count > 0, !seenIds.contains(album.localIdentifier) else { return }
      seenIds.insert(album.localIdentifier)
      output.append([
        "id": album.localIdentifier,
        "name": self.chineseSystemAlbumName(for: album),
        "count": assets.count,
      ])
    }

    return output.sorted {
      let lhsId = ($0["id"] as? String) ?? ""
      let rhsId = ($1["id"] as? String) ?? ""
      if lhsId == recentProjectsAlbumId { return true }
      if rhsId == recentProjectsAlbumId { return false }
      return (($0["name"] as? String) ?? "") < (($1["name"] as? String) ?? "")
    }
  }

  private func getAssetsFromAlbum(
    albumId: String,
    offset: Int,
    limit: Int,
    newestFirst: Bool,
    startDateMs: Int64?,
    endDateMs: Int64?
  ) -> [[String: Any]] {
    // Rebuild exported files every time assets are (re)loaded to avoid
    // unbounded cache growth on device storage.
    clearExportCache()

    let options = assetFetchOptions()
    var predicates: [NSPredicate] = [
      NSPredicate(format: "mediaType == %d OR mediaType == %d", PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue)
    ]

    if let startDateMs {
      let startDate = Date(timeIntervalSince1970: TimeInterval(startDateMs) / 1000)
      predicates.append(NSPredicate(format: "creationDate >= %@", startDate as NSDate))
    }

    if let endDateMs {
      let endDate = Date(timeIntervalSince1970: TimeInterval(endDateMs) / 1000)
      predicates.append(NSPredicate(format: "creationDate <= %@", endDate as NSDate))
    }

    options.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: !newestFirst)]
    let fetchResult: PHFetchResult<PHAsset>
    if albumId == recentProjectsAlbumId {
      fetchResult = PHAsset.fetchAssets(with: options)
    } else {
      let collections = PHAssetCollection.fetchAssetCollections(
        withLocalIdentifiers: [albumId],
        options: nil
      )
      guard let album = collections.firstObject else {
        return []
      }
      fetchResult = PHAsset.fetchAssets(in: album, options: options)
    }
    if fetchResult.count == 0 {
      return []
    }

    let safeOffset = max(0, offset)
    let endIndex: Int
    if limit <= 0 {
      endIndex = fetchResult.count
    } else {
      endIndex = min(fetchResult.count, safeOffset + limit)
    }
    if safeOffset >= endIndex {
      return []
    }

    var output: [[String: Any]] = []
    for index in safeOffset..<endIndex {
      let asset = fetchResult.object(at: index)
      guard let filePath = exportAssetToTemporaryFile(asset: asset) else {
        continue
      }

      let mediaType = asset.mediaType == .video ? "video" : "image"
      let createdAtMs = asset.creationDate?.timeIntervalSince1970
      let baseName = asset.localIdentifier.replacingOccurrences(of: "/", with: "_")
      let liveVideoPath = asset.mediaSubtypes.contains(.photoLive)
        ? exportLivePhotoMotion(asset: asset, tempDir: exportCacheDirectory(), baseName: baseName)
        : nil
      output.append([
        "id": asset.localIdentifier,
        "type": mediaType,
        "path": filePath,
        "createDateTime": createdAtMs != nil ? Int64(createdAtMs! * 1000) : NSNull(),
        "isFavorite": asset.isFavorite,
        "isLivePhoto": asset.mediaSubtypes.contains(.photoLive),
        "liveVideoPath": liveVideoPath ?? NSNull(),
      ])
    }

    return output
  }

  private func exportCacheDirectory() -> URL {
    let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
      ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    let dir = root.appendingPathComponent(exportCacheFolderName, isDirectory: true)
    if !FileManager.default.fileExists(atPath: dir.path) {
      try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    return dir
  }

  private func clearExportCache() {
    let dir = exportCacheDirectory()
    let fileManager = FileManager.default
    guard let children = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
      return
    }
    for child in children {
      try? fileManager.removeItem(at: child)
    }
  }

  private func chineseSystemAlbumName(for album: PHAssetCollection) -> String {
    switch album.assetCollectionSubtype {
    case .smartAlbumUserLibrary:
      return "最近项目"
    case .smartAlbumFavorites:
      return "个人收藏"
    case .smartAlbumVideos:
      return "视频"
    case .smartAlbumSelfPortraits:
      return "自拍"
    case .smartAlbumScreenshots:
      return "屏幕快照"
    case .smartAlbumDepthEffect:
      return "人像"
    case .smartAlbumLivePhotos:
      return "实况照片"
    case .smartAlbumAnimated:
      return "动图"
    case .smartAlbumSlomoVideos:
      return "慢动作"
    case .smartAlbumTimelapses:
      return "延时摄影"
    case .smartAlbumBursts:
      return "连拍快照"
    case .smartAlbumPanoramas:
      return "全景照片"
    case .smartAlbumRecentlyAdded:
      return "最近添加"
    default:
      return album.localizedTitle ?? "系统相册"
    }
  }

  private func assetFetchOptions() -> PHFetchOptions {
    let options = PHFetchOptions()
    options.includeHiddenAssets = false
    options.includeAssetSourceTypes = [.typeUserLibrary, .typeiTunesSynced, .typeCloudShared]
    return options
  }

  private func exportAssetToTemporaryFile(asset: PHAsset) -> String? {
    let tempDir = exportCacheDirectory()
    let baseName = asset.localIdentifier.replacingOccurrences(of: "/", with: "_")

    if asset.mediaType == .video {
      return exportVideo(asset: asset, tempDir: tempDir, baseName: baseName)
    }

    return exportImage(asset: asset, tempDir: tempDir, baseName: baseName)
  }

  private func exportImage(asset: PHAsset, tempDir: URL, baseName: String) -> String? {
    let resources = PHAssetResource.assetResources(for: asset)
    guard
      let resource = resources.first(where: { $0.type == .photo || $0.type == .fullSizePhoto })
        ?? resources.first
    else {
      return nil
    }

    let ext = (resource.originalFilename as NSString).pathExtension
    let fileExt = ext.isEmpty ? "jpg" : ext
    let destination = tempDir.appendingPathComponent("\(baseName).\(fileExt)")
    try? FileManager.default.removeItem(at: destination)

    let semaphore = DispatchSemaphore(value: 0)
    var success = false
    PHAssetResourceManager.default().writeData(for: resource, toFile: destination, options: nil) { error in
      success = (error == nil)
      semaphore.signal()
    }
    semaphore.wait()

    return success ? destination.path : nil
  }

  private func exportVideo(asset: PHAsset, tempDir: URL, baseName: String) -> String? {
    let manager = PHImageManager.default()
    let options = PHVideoRequestOptions()
    options.version = .current
    options.deliveryMode = .highQualityFormat
    options.isNetworkAccessAllowed = true

    let destination = tempDir.appendingPathComponent("\(baseName).mov")
    try? FileManager.default.removeItem(at: destination)

    let semaphore = DispatchSemaphore(value: 0)
    var exportedPath: String?

    manager.requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
      defer { semaphore.signal() }

      if let urlAsset = avAsset as? AVURLAsset {
        do {
          try FileManager.default.copyItem(at: urlAsset.url, to: destination)
          exportedPath = destination.path
        } catch {
          exportedPath = urlAsset.url.path
        }
        return
      }

      let resources = PHAssetResource.assetResources(for: asset)
      guard let resource = resources.first(where: { $0.type == .video || $0.type == .fullSizeVideo }) else {
        return
      }

      let innerSemaphore = DispatchSemaphore(value: 0)
      PHAssetResourceManager.default().writeData(for: resource, toFile: destination, options: nil) { error in
        if error == nil {
          exportedPath = destination.path
        }
        innerSemaphore.signal()
      }
      innerSemaphore.wait()
    }

    semaphore.wait()
    return exportedPath
  }

  private func exportLivePhotoMotion(asset: PHAsset, tempDir: URL, baseName: String) -> String? {
    let resources = PHAssetResource.assetResources(for: asset)
    guard let pairedVideo = resources.first(where: { $0.type == .pairedVideo }) else {
      return nil
    }

    let destination = tempDir.appendingPathComponent("\(baseName)_live.mov")
    try? FileManager.default.removeItem(at: destination)

    let semaphore = DispatchSemaphore(value: 0)
    var success = false
    PHAssetResourceManager.default().writeData(for: pairedVideo, toFile: destination, options: nil) { error in
      success = (error == nil)
      semaphore.signal()
    }
    semaphore.wait()

    return success ? destination.path : nil
  }

  private func deleteAsset(assetId: String, result: @escaping FlutterResult) {
    let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
    guard let asset = fetch.firstObject else {
      result(FlutterError(code: "not_found", message: "Asset not found", details: nil))
      return
    }

    PHPhotoLibrary.shared().performChanges({
      PHAssetChangeRequest.deleteAssets([asset] as NSArray)
    }) { success, error in
      DispatchQueue.main.async {
        if success {
          result(nil)
        } else {
          result(FlutterError(code: "delete_failed", message: error?.localizedDescription, details: nil))
        }
      }
    }
  }

  private func deleteAssets(assetIds: [String], result: @escaping FlutterResult) {
    if assetIds.isEmpty {
      result(nil)
      return
    }

    let fetch = PHAsset.fetchAssets(withLocalIdentifiers: assetIds, options: nil)
    if fetch.count == 0 {
      result(FlutterError(code: "not_found", message: "No assets found", details: nil))
      return
    }

    PHPhotoLibrary.shared().performChanges({
      PHAssetChangeRequest.deleteAssets(fetch)
    }) { success, error in
      DispatchQueue.main.async {
        if success {
          result(nil)
        } else {
          result(FlutterError(code: "delete_failed", message: error?.localizedDescription, details: nil))
        }
      }
    }
  }

  private func setFavorite(assetId: String, isFavorite: Bool, result: @escaping FlutterResult) {
    let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
    guard let asset = fetch.firstObject else {
      result(FlutterError(code: "not_found", message: "Asset not found", details: nil))
      return
    }

    PHPhotoLibrary.shared().performChanges({
      let request = PHAssetChangeRequest(for: asset)
      request.isFavorite = isFavorite
    }) { success, error in
      DispatchQueue.main.async {
        if success {
          result(nil)
        } else {
          result(FlutterError(code: "favorite_failed", message: error?.localizedDescription, details: nil))
        }
      }
    }
  }
}
