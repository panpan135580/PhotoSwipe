import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

class PermissionService {
  static const MethodChannel _platform = MethodChannel(
    'com.example.photoswipe/photos',
  );

  static Future<String> requestPhotoLibraryPermission() async {
    try {
      final status = await _platform.invokeMethod<String>(
        'requestPhotoAuthorization',
      );
      return status ?? 'denied';
    } catch (_) {
      final status = await Permission.photos.request();
      if (status == PermissionStatus.granted) {
        return 'authorized';
      }
      if (status == PermissionStatus.limited) {
        return 'limited';
      }
      return 'denied';
    }
  }

  static Future<String> getPhotoLibraryPermission() async {
    try {
      final status = await _platform.invokeMethod<String>(
        'getPhotoAuthorizationStatus',
      );
      return status ?? 'denied';
    } catch (_) {
      final status = await Permission.photos.status;
      if (status == PermissionStatus.granted) {
        return 'authorized';
      }
      if (status == PermissionStatus.limited) {
        return 'limited';
      }
      return 'denied';
    }
  }

  static Future<bool> hasFullPhotoLibraryPermission() async {
    final status = await getPhotoLibraryPermission();
    return status == 'authorized';
  }

  static Future<bool> isLimitedPhotoAccess() async {
    final status = await getPhotoLibraryPermission();
    return status == 'limited';
  }

  static Future<void> manageLimitedAccess() async {
    try {
      await _platform.invokeMethod('presentLimitedLibraryPicker');
    } catch (_) {
      await openAppSettings();
      return;
    }
    await openAppSettings();
  }

  static Future<void> openSettings() async {
    await openAppSettings();
  }
}
