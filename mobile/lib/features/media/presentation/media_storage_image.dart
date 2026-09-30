import 'package:flutter/material.dart';

import '../data/media_upload_service.dart';

class MediaStorageImage extends StatefulWidget {
  static MediaUploadService? service;

  final String storageKey;
  final String baseUrl;
  final double width;
  final double height;
  final BoxFit fit;
  final Widget Function(BuildContext context) fallback;

  const MediaStorageImage({
    super.key,
    required this.storageKey,
    required this.baseUrl,
    required this.width,
    required this.height,
    required this.fallback,
    this.fit = BoxFit.cover,
  });

  @override
  State<MediaStorageImage> createState() => _MediaStorageImageState();
}

class _MediaStorageImageState extends State<MediaStorageImage> {
  late Future<String?> _url;

  @override
  void initState() {
    super.initState();
    _url = _resolve();
  }

  @override
  void didUpdateWidget(covariant MediaStorageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storageKey != widget.storageKey ||
        oldWidget.baseUrl != widget.baseUrl) {
      _url = _resolve();
    }
  }

  Future<String?> _resolve() {
    final key = widget.storageKey.trim();
    if (key.startsWith('http://') || key.startsWith('https://')) {
      return Future.value(key);
    }
    if (key.startsWith('avatar/') ||
        key.startsWith('group-avatar/') ||
        key.startsWith('chat/') ||
        key.startsWith('expense-receipt/') ||
        key.startsWith('fund-contribution-proof/') ||
        key.startsWith('fund-expense-receipt/') ||
        key.startsWith('fund-reimbursement-receipt/')) {
      final service = MediaStorageImage.service;
      return service == null
          ? Future.value(null)
          : service.authorizedReadUrl(key);
    }
    final base = widget.baseUrl.endsWith('/')
        ? widget.baseUrl.substring(0, widget.baseUrl.length - 1)
        : widget.baseUrl;
    final cleanKey = key.startsWith('/') ? key.substring(1) : key;
    final path = cleanKey.startsWith('api/v1/media/')
        ? cleanKey
        : 'api/v1/media/$cleanKey';
    return Future.value('$base/$path');
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
    future: _url,
    builder: (context, snapshot) {
      final url = snapshot.data;
      if (url == null) return widget.fallback(context);
      return Image.network(
        url,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) => widget.fallback(context),
      );
    },
  );
}
