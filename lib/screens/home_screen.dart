import 'package:flutter/material.dart';

import '../models/media_item.dart';
import '../services/permission_service.dart';
import '../services/photo_service.dart';
import 'browser_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  bool _hasPhotoAccess = false;
  bool _isLimited = false;
  List<MediaAlbum> _albums = [];
  MediaAlbum? _selectedAlbum;

  @override
  void initState() {
    super.initState();
    _init();
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
      backgroundColor: Colors.grey[900],
      builder: (context) {
        return SafeArea(
          child: ListView.separated(
            itemCount: _albums.length,
            separatorBuilder: (_, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final album = _albums[index];
              return ListTile(
                title: Text(album.name),
                trailing: Text('${album.count}'),
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
      backgroundColor: Colors.grey[900],
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  '选择浏览顺序',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.new_releases_outlined),
                title: const Text('从最新日期开始'),
                onTap: () => Navigator.pop(context, true),
              ),
              ListTile(
                leading: const Icon(Icons.history_toggle_off),
                title: const Text('从最早日期开始'),
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
            const Icon(Icons.lock, size: 52, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              '需要照片权限',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(hint, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _init,
              icon: const Icon(Icons.refresh),
              label: const Text('重新检测权限'),
            ),
            if (_isLimited) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: PermissionService.manageLimitedAccess,
                icon: const Icon(Icons.photo_library),
                label: const Text('管理已选照片'),
              ),
            ],
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: PermissionService.openSettings,
              icon: const Icon(Icons.settings),
              label: const Text('打开系统设置'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadyView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          const Text(
            'PhotoSwipe',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text('下滑浏览照片和视频，可直接收藏或删除到系统相册。', textAlign: TextAlign.center),
          if (_isLimited) ...[
            const SizedBox(height: 12),
            const Text(
              '当前为部分访问，仅显示已授权照片/视频。要使用全部相册，请去系统设置改为“完全访问”。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.amber),
            ),
          ],
          const SizedBox(height: 36),
          Card(
            color: Colors.white10,
            child: ListTile(
              title: Text(_selectedAlbum?.name ?? '未选择相册'),
              subtitle: Text(
                _selectedAlbum == null
                    ? '点击选择相册'
                    : '共 ${_selectedAlbum!.count} 项',
              ),
              trailing: const Icon(Icons.keyboard_arrow_up),
              onTap: _chooseAlbum,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _chooseAlbum,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('选择相册'),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _openBrowser,
            icon: const Icon(Icons.play_arrow),
            label: const Text('开始浏览'),
          ),
          if (_isLimited) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: PermissionService.openSettings,
              icon: const Icon(Icons.settings),
              label: const Text('前往设置开启完全访问'),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PhotoSwipe'), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_hasPhotoAccess ? _buildReadyView() : _buildPermissionHint()),
    );
  }
}
