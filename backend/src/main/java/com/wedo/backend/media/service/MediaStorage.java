package com.wedo.backend.media.service;

import java.util.Optional;

public interface MediaStorage {
    MediaUploadResult storeAvatar(byte[] bytes, String contentType, String originalFilename);
    Optional<MediaResource> load(String storageKey);
}
