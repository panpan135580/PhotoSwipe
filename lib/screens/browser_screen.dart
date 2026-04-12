import 'package:flutter/material.dart';

import '../models/media_item.dart';
import '../services/photo_service.dart';
import '../widgets/date_filter_dialog.dart';
import '../widgets/media_viewer.dart';

class BrowserScreen extends StatefulWidget {
  final MediaAlbum album;
  final bool newestFirst;

  const BrowserScreen({
    super.key,
    required this.album,
    required this.newestFirst,
  });

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  late final PageController _pageController;
  List<MediaItem> _filteredAssets = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  DateTime? _startDate;
  DateTime? _endDate;

  MediaItem? get _currentItem {
    if (_filteredAssets.isEmpty || _currentIndex >= _filteredAssets.length) {
      return null;
    }
    return _filteredAssets[_currentIndex];
  }

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) {
      return '--';
    }
    final y = dateTime.year.toString().padLeft(4, '0');
    final m = dateTime.month.toString().padLeft(2, '0');
    final d = dateTime.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final items = await PhotoService.getAssetsFromAlbum(
        album: widget.album,
        startDate: _startDate,
        endDate: _endDate,
        newestFirst: widget.newestFirst,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _filteredAssets = items;
        _currentIndex = 0;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackbar('读取相册内容失败');
    }
  }

  void _toggleDeleteMarkForCurrentAsset() {
    if (_filteredAssets.isEmpty || _currentIndex >= _filteredAssets.length) {
      return;
    }

    final current = _filteredAssets[_currentIndex];
    final nextMarked = !current.isMarkedForDelete;
    _replaceCurrentItem(current, isMarkedForDelete: nextMarked);
  }

  Future<void> _toggleFavoriteForCurrentAsset() async {
    if (_filteredAssets.isEmpty || _currentIndex >= _filteredAssets.length) {
      return;
    }

    final current = _filteredAssets[_currentIndex];
    final nextFavorite = !current.isFavorite;
    try {
      await PhotoService.setFavoriteStatus(current, nextFavorite);
      _replaceCurrentItem(current, isFavorite: nextFavorite);
    } catch (_) {
      _showErrorSnackbar('收藏失败，请确认照片权限');
    }
  }

  Future<void> _applyMarkedDeletes() async {
    final markedItems = _filteredAssets
        .where((item) => item.isMarkedForDelete)
        .toList();
    if (markedItems.isEmpty) {
      return;
    }

    final currentId = _filteredAssets[_currentIndex].id;

    setState(() {
      _isLoading = true;
    });

    var batchSucceeded = false;
    try {
      await PhotoService.deleteAssets(markedItems);
      batchSucceeded = true;
    } catch (_) {
      batchSucceeded = false;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      if (batchSucceeded) {
        final markedIds = markedItems.map((e) => e.id).toSet();
        _filteredAssets = _filteredAssets
            .where((item) => !markedIds.contains(item.id))
            .toList();
      } else {
        _filteredAssets = _filteredAssets
            .map(
              (item) => item.isMarkedForDelete
                  ? MediaItem(
                      id: item.id,
                      type: item.type,
                      path: item.path,
                      createDateTime: item.createDateTime,
                      isFavorite: item.isFavorite,
                      isLivePhoto: item.isLivePhoto,
                      liveVideoPath: item.liveVideoPath,
                      isMarkedForDelete: false,
                    )
                  : item,
            )
            .toList();
      }

      final sameItemIndex = _filteredAssets.indexWhere(
        (item) => item.id == currentId,
      );
      if (sameItemIndex != -1) {
        _currentIndex = sameItemIndex;
      } else if (_currentIndex >= _filteredAssets.length && _currentIndex > 0) {
        _currentIndex = _filteredAssets.length - 1;
      }
      _isLoading = false;
    });

    if (_filteredAssets.isEmpty) {
      _showCompletionDialog();
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _filteredAssets.isEmpty) {
        return;
      }
      _pageController.jumpToPage(_currentIndex);
    });
  }

  void _replaceCurrentItem(
    MediaItem current, {
    bool? isFavorite,
    bool? isMarkedForDelete,
  }) {
    setState(() {
      _filteredAssets[_currentIndex] = MediaItem(
        id: current.id,
        type: current.type,
        path: current.path,
        createDateTime: current.createDateTime,
        isFavorite: isFavorite ?? current.isFavorite,
        isLivePhoto: current.isLivePhoto,
        liveVideoPath: current.liveVideoPath,
        isMarkedForDelete: isMarkedForDelete ?? current.isMarkedForDelete,
      );
    });
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showCompletionDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('已完成'),
        content: const Text('这个相册已经浏览完了。'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, true);
            },
            child: const Text('返回相册列表'),
          ),
        ],
      ),
    );
  }

  void _openDateFilter() {
    showDialog<void>(
      context: context,
      builder: (context) => DateFilterDialog(
        onFilter: (startDate, endDate) {
          Navigator.pop(context);
          setState(() {
            _startDate = startDate;
            _endDate = endDate;
          });
          _loadAssets();
        },
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _formatDate(_currentItem?.createDateTime),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
        ),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 0,
        toolbarHeight: 42,
        leadingWidth: 40,
        iconTheme: const IconThemeData(size: 20),
        actions: [
          if (_filteredAssets.any((item) => item.isMarkedForDelete))
            TextButton.icon(
              onPressed: _applyMarkedDeletes,
              icon: const Icon(Icons.delete_forever, size: 16),
              label: Text(
                '执行删除 (${_filteredAssets.where((item) => item.isMarkedForDelete).length})',
              ),
            ),
          IconButton(
            icon: const Icon(Icons.calendar_today, size: 20),
            onPressed: _openDateFilter,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredAssets.isEmpty
          ? const Center(child: Text('这个相册没有可显示的内容'))
          : Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  onPageChanged: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  itemCount: _filteredAssets.length,
                  itemBuilder: (context, index) {
                    final item = _filteredAssets[index];
                    return Stack(
                      children: [
                        Positioned.fill(child: MediaViewer(item: item)),
                      ],
                    );
                  },
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / ${_filteredAssets.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 88,
                  right: 24,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: _toggleFavoriteForCurrentAsset,
                        iconSize: 34,
                        splashRadius: 24,
                        color: Colors.white,
                        icon: Icon(
                          _filteredAssets[_currentIndex].isFavorite
                              ? Icons.favorite
                              : Icons.favorite_border,
                        ),
                      ),
                      const SizedBox(height: 12),
                      IconButton(
                        onPressed: _toggleDeleteMarkForCurrentAsset,
                        iconSize: 34,
                        splashRadius: 24,
                        color: Colors.white,
                        icon: Icon(
                          _filteredAssets[_currentIndex].isMarkedForDelete
                              ? Icons.history
                              : Icons.delete,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
