import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/media_item.dart';
import '../services/permission_service.dart';
import '../services/photo_service.dart';
import 'browser_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const _bg = Color(0xFFFFFFFF);
  static const _secondary = Color(0xFFFFE6F2);
  static const _muted = Color(0xFFFFF0F7);
  static const _primary = Color(0xFFFFB3D9);
  static const _title = Color(0xFF333333);
  static const _sub = Color(0xFF999999);
  static const _accentText = Color(0xFFFF66B3);

  bool _isLoading = true;
  bool _hasPhotoAccess = false;
  bool _isLimited = false;
  bool _isAlbumCardExpanded = false;
  List<MediaAlbum> _albums = [];
  MediaAlbum? _selectedAlbum;
  VideoPlayerController? _cornerVideoController;
  bool _cornerVideoReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
    _initCornerVideo();
  }

  Future<void> _initCornerVideo() async {
    final controller = VideoPlayerController.asset(
      'assets/videos/home_corner.mov',
    );
    await controller.initialize();
    await controller.setLooping(true);
    await controller.setVolume(0);
    await controller.play();

    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() {
      _cornerVideoController = controller;
      _cornerVideoReady = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      final activeController = _cornerVideoController;
      if (activeController != null && !activeController.value.isPlaying) {
        await activeController.play();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cornerVideoController;
    if (controller == null) {
      return;
    }
    if (state == AppLifecycleState.resumed) {
      controller.play();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      controller.pause();
    }
  }

  Future<void> _init() async {
    setState(() {
      _isLoading = true;
    });

    await PermissionService.requestPhotoLibraryPermission();
    final limited = await PermissionService.isLimitedPhotoAccess();
    final fullAccess = await PermissionService.hasFullPhotoLibraryPermission();

    if (!mounted) {
      return;
    }

    if (!fullAccess && !limited) {
      setState(() {
        _isLoading = false;
        _hasPhotoAccess = false;
        _isLimited = limited;
      });
      return;
    }

    await _loadAlbums(isLimited: limited);
  }

  Future<void> _loadAlbums({bool isLimited = false}) async {
    try {
      final albums = await PhotoService.getAlbums();
      if (!mounted) {
        return;
      }
      setState(() {
        _albums = albums;
        _selectedAlbum = albums.isNotEmpty ? albums.first : null;
        _hasPhotoAccess = true;
        _isLimited = isLimited;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _hasPhotoAccess = true;
        _isLimited = isLimited;
        _isLoading = false;
      });
      _showSnack('读取相册失败');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _chooseAlbum() async {
    if (_albums.isEmpty) {
      _showSnack('没有可用相册');
      return;
    }

    final selected = await showModalBottomSheet<MediaAlbum>(
      context: context,
      backgroundColor: _bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: ListView.separated(
            itemCount: _albums.length,
            separatorBuilder: (_, index) =>
                const Divider(height: 1, color: Color(0xFFFFE6F2)),
            itemBuilder: (context, index) {
              final album = _albums[index];
              return ListTile(
                title: Text(album.name, style: const TextStyle(color: _title)),
                trailing: Text(
                  '${album.count}',
                  style: const TextStyle(color: _sub),
                ),
                onTap: () => Navigator.pop(context, album),
              );
            },
          ),
        );
      },
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _selectedAlbum = selected;
    });
  }

  Future<void> _openBrowser() async {
    final album = _selectedAlbum;
    if (album == null) {
      _showSnack('请先选择相册');
      return;
    }

    final newestFirst = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: _bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  '选择浏览顺序',
                  style: TextStyle(fontWeight: FontWeight.bold, color: _title),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.new_releases_outlined,
                  color: _accentText,
                ),
                title: const Text('从最新日期开始', style: TextStyle(color: _title)),
                onTap: () => Navigator.pop(context, true),
              ),
              ListTile(
                leading: const Icon(
                  Icons.history_toggle_off,
                  color: _accentText,
                ),
                title: const Text('从最早日期开始', style: TextStyle(color: _title)),
                onTap: () => Navigator.pop(context, false),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (newestFirst == null || !mounted) {
      return;
    }

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BrowserScreen(album: album, newestFirst: newestFirst),
      ),
    );

    if (mounted) {
      _loadAlbums();
    }
  }

  Widget _buildCornerVideoPreview() {
    final controller = _cornerVideoController;
    if (!_cornerVideoReady || controller == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: 16,
      bottom: 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 80,
          height: 120,
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionHint() {
    final hint = _isLimited
        ? '当前是“部分访问”，请到设置改成“完全访问”。\n设置 > 隐私与安全性 > 照片 > PhotoSwipe > 完全访问'
        : '需要照片权限才能使用。';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock, size: 52, color: _accentText),
            const SizedBox(height: 16),
            const Text(
              '需要照片权限',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _title,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _sub),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _init,
              icon: const Icon(Icons.refresh),
              label: const Text('重新检测权限'),
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
              ),
            ),
            if (_isLimited) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: PermissionService.manageLimitedAccess,
                icon: const Icon(Icons.photo_library),
                label: const Text('管理已选照片'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _accentText,
                  side: const BorderSide(color: Color(0xFFFFC9E6)),
                ),
              ),
            ],
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: PermissionService.openSettings,
              icon: const Icon(Icons.settings),
              label: const Text('打开系统设置'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _accentText,
                side: const BorderSide(color: Color(0xFFFFC9E6)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadyView() {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 80),
              const Text(
                'PhotoSwipe',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w500,
                  color: _title,
                  letterSpacing: -0.8,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              GestureDetector(
                onTap: () async {
                  setState(() {
                    _isAlbumCardExpanded = !_isAlbumCardExpanded;
                  });
                  await _chooseAlbum();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    color: _secondary,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedAlbum?.name ?? '最近项目',
                            style: const TextStyle(
                              color: _accentText,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _selectedAlbum == null
                                ? '点击选择相册'
                                : '共 ${_selectedAlbum!.count} 项',
                            style: const TextStyle(
                              color: Color(0xFFCC8DB0),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      AnimatedRotation(
                        turns: _isAlbumCardExpanded ? 0 : 0.5,
                        duration: const Duration(milliseconds: 180),
                        child: const Icon(
                          Icons.keyboard_arrow_up,
                          color: _accentText,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _chooseAlbum,
                icon: const Icon(Icons.photo_outlined, size: 20),
                label: const Text('选择相册'),
                style: FilledButton.styleFrom(
                  backgroundColor: _muted,
                  foregroundColor: _accentText,
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _openBrowser,
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: const Text('开始浏览'),
                style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
              if (_isLimited) ...[
                const SizedBox(height: 12),
                const Text(
                  '当前为部分访问，仅显示已授权照片/视频。要使用全部相册，请去系统设置改为“完全访问”。',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _accentText),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: PermissionService.openSettings,
                  icon: const Icon(Icons.settings),
                  label: const Text('前往设置开启完全访问'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _accentText,
                    side: const BorderSide(color: Color(0xFFFFC9E6)),
                  ),
                ),
              ],
            ],
          ),
        ),
        _buildCornerVideoPreview(),
      ],
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cornerVideoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_hasPhotoAccess ? _buildReadyView() : _buildPermissionHint()),
    );
  }
}
