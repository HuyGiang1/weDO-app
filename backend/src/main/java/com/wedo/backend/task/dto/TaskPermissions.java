package com.wedo.backend.task.dto;
public record TaskPermissions(boolean canEdit,boolean canManageAssignees,boolean canClaim,boolean canChangeStatus,boolean canDelete){ }
