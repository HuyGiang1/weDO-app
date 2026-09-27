package com.wedo.backend.poll.entity;
import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;
@Entity @Table(name = "polls")
public class PollEntity {
 @Id private UUID id; @Column(name="activity_id",nullable=false) private UUID activityId; @Column(name="created_by") private UUID createdBy;
 @Column(nullable=false) private String question; @Enumerated(EnumType.STRING) @Column(name="poll_type",nullable=false) private PollType pollType;
 @Column(name="allow_member_add_option",nullable=false) private boolean allowMemberAddOption; @Column(name="max_selections") private Integer maxSelections;
 @Enumerated(EnumType.STRING) @Column(name="vote_visibility",nullable=false) private VoteVisibility voteVisibility; @Enumerated(EnumType.STRING) @Column(name="result_visibility",nullable=false) private ResultVisibility resultVisibility;
 @Enumerated(EnumType.STRING) @Column(nullable=false) private PollStatus status; @Column(name="deadline_at") private Instant deadlineAt; @Column(name="closed_at") private Instant closedAt; @Column(name="closed_by") private UUID closedBy;
 @Column(name="created_at",nullable=false) private Instant createdAt; @Column(name="updated_at",nullable=false) private Instant updatedAt;
 protected PollEntity() { }
 public PollEntity(UUID id,UUID activityId,UUID createdBy,String question,PollType pollType,boolean allowMemberAddOption,Integer maxSelections,VoteVisibility voteVisibility,ResultVisibility resultVisibility,Instant deadlineAt,Instant now){this.id=id;this.activityId=activityId;this.createdBy=createdBy;this.question=question;this.pollType=pollType;this.allowMemberAddOption=allowMemberAddOption;this.maxSelections=maxSelections;this.voteVisibility=voteVisibility;this.resultVisibility=resultVisibility;this.status=PollStatus.OPEN;this.deadlineAt=deadlineAt;this.createdAt=now;this.updatedAt=now;}
 public UUID getId(){return id;} public UUID getActivityId(){return activityId;} public UUID getCreatedBy(){return createdBy;} public String getQuestion(){return question;} public PollType getPollType(){return pollType;} public boolean isAllowMemberAddOption(){return allowMemberAddOption;} public Integer getMaxSelections(){return maxSelections;} public VoteVisibility getVoteVisibility(){return voteVisibility;} public ResultVisibility getResultVisibility(){return resultVisibility;} public PollStatus getStatus(){return status;} public Instant getDeadlineAt(){return deadlineAt;} public Instant getClosedAt(){return closedAt;} public UUID getClosedBy(){return closedBy;} public Instant getCreatedAt(){return createdAt;}
 public boolean closeIfDue(Instant now){if(status==PollStatus.OPEN&&deadlineAt!=null&&!deadlineAt.isAfter(now)){status=PollStatus.CLOSED;closedAt=now;closedBy=null;updatedAt=now;return true;}return false;} public void close(UUID actor,Instant now){if(status==PollStatus.OPEN){status=PollStatus.CLOSED;closedAt=now;closedBy=actor;updatedAt=now;}}
}
