package com.wedo.backend.task.dto;
public record TaskPermissions(boolean canEdit,boolean canManageAssignees,boolean canClaim,boolean canChangeStatus,boolean canDelete,boolean canCompleteWithoutEvidence){
 public TaskPermissions(boolean edit,boolean assign,boolean claim,boolean status,boolean delete){this(edit,assign,claim,status,delete,true);}
}
