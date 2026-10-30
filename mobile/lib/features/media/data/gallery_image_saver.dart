import 'package:flutter/services.dart';

import 'media_upload_service.dart';

/// Platform implementations add one original resource, never read the library.
class GalleryImageSaver {
  final MethodChannel channel;
  const GalleryImageSaver({
    this.channel = const MethodChannel('wedo/media_gallery'),
  });

  Future<void> save(DownloadedMediaImage image) async {
    await channel.invokeMethod<void>('saveImage', {
      'bytes': image.bytes,
      'contentType': image.contentType,
    });
  }
}
