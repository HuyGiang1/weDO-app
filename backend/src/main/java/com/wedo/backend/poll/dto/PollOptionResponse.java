package com.wedo.backend.poll.dto;
import com.wedo.backend.poll.entity.PollOptionEntity; import java.util.UUID;
public record PollOptionResponse(UUID id,String text,int sortOrder,boolean disabled,UUID createdBy,long voteCount,boolean canEdit,boolean canDisable,boolean canDelete){ }
