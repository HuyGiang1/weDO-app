package com.wedo.backend.media.service;

import com.wedo.backend.common.error.*;
import com.wedo.backend.media.dto.UploadCategory;
import java.util.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
public class MomentMediaPolicy {
 @Value("${media.moments.max-image-bytes:10485760}") private long imageLimit=10485760;
 @Value("${media.moments.max-video-bytes:52428800}") private long videoLimit=52428800;
 public void validate(UploadCategory category,String mime,String name,long size) {
  String ext=name==null?"":name.toLowerCase(Locale.ROOT);
  boolean video=category==UploadCategory.MOMENT_VIDEO;
  boolean type=video?"video/mp4".equals(mime)&&ext.endsWith(".mp4"):
    ("image/jpeg".equals(mime)&&(ext.endsWith(".jpg")||ext.endsWith(".jpeg")))||
    ("image/png".equals(mime)&&ext.endsWith(".png"))||("image/webp".equals(mime)&&ext.endsWith(".webp"));
  if(!type||size<=0||size>(video?videoLimit:imageLimit))throw new BusinessException(ErrorCode.VALIDATION_FAILED);
 }
}
