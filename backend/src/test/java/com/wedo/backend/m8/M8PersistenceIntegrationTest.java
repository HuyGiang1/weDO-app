package com.wedo.backend.m8;

import static org.junit.jupiter.api.Assertions.assertEquals;

import com.wedo.backend.activity.entity.*;
import com.wedo.backend.activity.repository.ActivityRepository;
import com.wedo.backend.common.test.AbstractPostgresIntegrationTest;
import com.wedo.backend.discussion.entity.ActivityCommentEntity;
import com.wedo.backend.discussion.repository.ActivityCommentRepository;
import com.wedo.backend.group.entity.*;
import com.wedo.backend.group.repository.GroupRepository;
import com.wedo.backend.poll.entity.*;
import com.wedo.backend.poll.repository.*;
import com.wedo.backend.task.entity.*;
import com.wedo.backend.task.repository.*;
import com.wedo.backend.user.entity.*;
import com.wedo.backend.user.repository.UserRepository;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.transaction.annotation.Transactional;

class M8PersistenceIntegrationTest extends AbstractPostgresIntegrationTest {
    @Autowired UserRepository users; @Autowired GroupRepository groups; @Autowired ActivityRepository activities;
    @Autowired PollRepository polls; @Autowired PollOptionRepository options; @Autowired PollVoteRepository votes; @Autowired PollVoteChoiceRepository choices;
    @Autowired TaskRepository tasks; @Autowired TaskAssigneeRepository assignees; @Autowired TaskStatusHistoryRepository histories; @Autowired ActivityCommentRepository comments;

    @Test @Transactional void mapsEveryV6M8TableAgainstPostgres() {
        Instant now=Instant.parse("2026-09-26T00:00:00Z"); UUID userId=UUID.randomUUID();
        users.save(new UserEntity(userId,"m8-"+userId+"@test.local","m8_"+userId.toString().substring(0,8),"M8 User",UserStatus.ACTIVE,now,now));
        UUID groupId=UUID.randomUUID(); groups.save(new GroupEntity(groupId,"M8 group",null,null,GroupStatus.ACTIVE,userId,now,now));
        UUID activityId=UUID.randomUUID(); activities.save(new ActivityEntity(activityId,groupId,userId,"M8 activity",null,ActivityStatus.CONFIRMED,null,null,null,null,null,now,now));
        UUID pollId=UUID.randomUUID(); polls.save(new PollEntity(pollId,activityId,userId,"Choose",PollType.SINGLE_CHOICE,false,null,VoteVisibility.PUBLIC,ResultVisibility.IMMEDIATE,null,now));
        UUID optionId=UUID.randomUUID(); options.save(new PollOptionEntity(optionId,pollId,"One",0,userId,now)); UUID voteId=UUID.randomUUID(); votes.save(new PollVoteEntity(voteId,pollId,userId,now)); choices.save(new PollVoteChoiceEntity(UUID.randomUUID(),voteId,optionId,now));
        UUID taskId=UUID.randomUUID(); tasks.save(new TaskEntity(taskId,activityId,userId,"Task",null,null,now)); assignees.save(new TaskAssigneeEntity(UUID.randomUUID(),taskId,userId,userId,now)); histories.save(new TaskStatusHistoryEntity(UUID.randomUUID(),taskId,null,TaskStatus.TODO,userId,now));
        ActivityCommentEntity root=comments.save(new ActivityCommentEntity(UUID.randomUUID(),activityId,userId,null,"Root",now)); comments.save(new ActivityCommentEntity(UUID.randomUUID(),activityId,userId,root.getId(),"Reply",now));
        assertEquals(1,options.findByPollIdOrderBySortOrderAsc(pollId).size()); assertEquals(1,choices.findByVoteId(voteId).size()); assertEquals(1,assignees.findByTaskId(taskId).size()); assertEquals(1,histories.findByTaskIdOrderByCreatedAtAsc(taskId).size()); assertEquals(2,comments.findByActivityIdOrderByCreatedAtAsc(activityId).size());
    }
}
