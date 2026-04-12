import 'package:flutter/material.dart';
import 'dart:io';

class PhotoBrowserScreen extends StatefulWidget {
  final String imagePath;

  const PhotoBrowserScreen({super.key, required this.imagePath});

  @override
  State<PhotoBrowserScreen> createState() => _PhotoBrowserScreenState();
}

class _PhotoBrowserScreenState extends State<PhotoBrowserScreen> {
  late PageController _pageController;
  int _currentIndex = 0;
  final List<String> _photos = [];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _photos.add(widget.imagePath);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _deleteCurrentPhoto() {
    setState(() {
      _photos.removeAt(_currentIndex);
      if (_photos.isEmpty) {
        Navigator.pop(context);
      } else if (_currentIndex >= _photos.length) {
        _currentIndex--;
      }
    });
    if (_photos.isNotEmpty) {
      _pageController.jumpToPage(_currentIndex);
    }
  }

  void _saveFavorite() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saved to Favorites'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PhotoSwipe'),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: _photos.isEmpty
          ? const Center(child: Text('No photos'))
          : Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() => _currentIndex = index);
                  },
                  itemCount: _photos.length,
                  itemBuilder: (context, index) {
                    return InteractiveViewer(
                      child: Image.file(
                        File(_photos[index]),
                        fit: BoxFit.contain,
                      ),
                    );
                  },
                ),
                // Counter
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
                      '${_currentIndex + 1} / ${_photos.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 14),

                    ),
                  ),
                ),
                // Action buttons
                Positioned(
                  bottom: 24,
                  right: 24,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FloatingActionButton(
                        onPressed: _saveFavorite,
                        heroTag: 'favorite',
                        backgroundColor: Colors.blue,
                        child: const Icon(Icons.favorite),
                      ),
                      const SizedBox(height: 12),
                      FloatingActionButton(
                        onPressed: _deleteCurrentPhoto,
                        heroTag: 'delete',
                        backgroundColor: Colors.red,
                        child: const Icon(Icons.delete),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
