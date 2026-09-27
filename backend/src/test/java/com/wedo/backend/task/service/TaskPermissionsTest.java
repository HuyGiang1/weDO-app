package com.wedo.backend.task.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.wedo.backend.activity.entity.ActivityEntity;
import com.wedo.backend.activity.entity.ActivityStatus;
import com.wedo.backend.activity.service.M8ActivityAccess;
import com.wedo.backend.activity.service.M8ActivityAccessService;
import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.group.entity.GroupEntity;
import com.wedo.backend.group.entity.GroupMembershipEntity;
import com.wedo.backend.group.entity.GroupMembershipStatus;
import com.wedo.backend.group.entity.GroupRole;
import com.wedo.backend.group.entity.GroupStatus;
import com.wedo.backend.group.repository.GroupMembershipRepository;
import com.wedo.backend.group.service.ReadableGroupAccess;
import com.wedo.backend.task.dto.TaskResponse;
import com.wedo.backend.task.dto.UpdateTaskStatusRequest;
import com.wedo.backend.task.entity.TaskAssigneeEntity;
import com.wedo.backend.task.entity.TaskEntity;
import com.wedo.backend.task.entity.TaskStatus;
import com.wedo.backend.task.repository.TaskAssigneeRepository;
import com.wedo.backend.task.repository.TaskRepository;
import com.wedo.backend.task.repository.TaskStatusHistoryRepository;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class TaskPermissionsTest {

    @Test
    void creatorOwnerAndAdminCanChangeStatusAndDelete() {
        assertManagerPermissions(GroupRole.MEMBER, true);
        assertManagerPermissions(GroupRole.OWNER, false);
        assertManagerPermissions(GroupRole.ADMIN, false);
    }

    @Test
    void assigneeCanChangeStatusButCannotDelete() {
        UUID actor = UUID.randomUUID();
        TaskResponse response = responseFor(actor, UUID.randomUUID(), GroupRole.MEMBER, List.of(actor));

        assertTrue(response.permissions().canChangeStatus());
        assertFalse(response.permissions().canDelete());
    }

    @Test
    void ordinaryMemberCannotChangeStatusOrDelete() {
        TaskResponse response = responseFor(UUID.randomUUID(), UUID.randomUUID(), GroupRole.MEMBER, List.of());

        assertFalse(response.permissions().canChangeStatus());
        assertFalse(response.permissions().canDelete());
    }

    @Test
    void statusTransitionsPersistForAnAuthorizedCreator() {
        UUID actor = UUID.randomUUID();
        Fixture fixture = fixture(actor, actor, GroupRole.MEMBER, List.of());
        when(fixture.tasks.findByIdForUpdate(fixture.task.getId())).thenReturn(Optional.of(fixture.task));
        when(fixture.access.requireMutable(fixture.task.getActivityId(), actor)).thenReturn(fixture.accessValue);

        assertEquals(TaskStatus.IN_PROGRESS, fixture.service.changeStatus(fixture.task.getId(), actor, new UpdateTaskStatusRequest(TaskStatus.IN_PROGRESS)).status());
        assertEquals(TaskStatus.DONE, fixture.service.changeStatus(fixture.task.getId(), actor, new UpdateTaskStatusRequest(TaskStatus.DONE)).status());
        verify(fixture.histories, org.mockito.Mockito.times(2)).save(org.mockito.ArgumentMatchers.any());
    }

    @Test
    void creatorCanDeleteAndOrdinaryMemberIsRejected() {
        UUID creator = UUID.randomUUID();
        Fixture creatorFixture = fixture(creator, creator, GroupRole.MEMBER, List.of());
        when(creatorFixture.tasks.findByIdForUpdate(creatorFixture.task.getId())).thenReturn(Optional.of(creatorFixture.task));
        when(creatorFixture.access.requireMutable(creatorFixture.task.getActivityId(), creator)).thenReturn(creatorFixture.accessValue);
        creatorFixture.service.delete(creatorFixture.task.getId(), creator);
        verify(creatorFixture.tasks).delete(creatorFixture.task);

        UUID member = UUID.randomUUID();
        Fixture memberFixture = fixture(member, UUID.randomUUID(), GroupRole.MEMBER, List.of());
        when(memberFixture.tasks.findByIdForUpdate(memberFixture.task.getId())).thenReturn(Optional.of(memberFixture.task));
        when(memberFixture.access.requireMutable(memberFixture.task.getActivityId(), member)).thenReturn(memberFixture.accessValue);
        BusinessException error = assertThrows(BusinessException.class, () -> memberFixture.service.delete(memberFixture.task.getId(), member));
        assertEquals(ErrorCode.TASK_DELETE_NOT_ALLOWED, error.errorCode());
    }

    private void assertManagerPermissions(GroupRole role, boolean actorIsCreator) {
        UUID actor = UUID.randomUUID();
        TaskResponse response = responseFor(actor, actorIsCreator ? actor : UUID.randomUUID(), role, List.of());
        assertTrue(response.permissions().canChangeStatus());
        assertTrue(response.permissions().canDelete());
    }

    private TaskResponse responseFor(UUID actor, UUID creator, GroupRole role, List<UUID> assigned) {
        Fixture fixture = fixture(actor, creator, role, assigned);
        when(fixture.tasks.findById(fixture.task.getId())).thenReturn(Optional.of(fixture.task));
        when(fixture.access.requireReadable(fixture.task.getActivityId(), actor)).thenReturn(fixture.accessValue);
        return fixture.service.get(fixture.task.getId(), actor);
    }

    private Fixture fixture(UUID actor, UUID creator, GroupRole role, List<UUID> assigned) {
        UUID groupId = UUID.randomUUID();
        UUID activityId = UUID.randomUUID();
        TaskRepository tasks = mock(TaskRepository.class);
        TaskAssigneeRepository assignees = mock(TaskAssigneeRepository.class);
        TaskStatusHistoryRepository histories = mock(TaskStatusHistoryRepository.class);
        M8ActivityAccessService access = mock(M8ActivityAccessService.class);
        Instant now = Instant.parse("2030-01-01T00:00:00Z");
        TaskEntity task = new TaskEntity(UUID.randomUUID(), activityId, creator, "Task", null, null, now);
        GroupEntity group = new GroupEntity(groupId, "Group", null, null, GroupStatus.ACTIVE, creator, now, now);
        GroupMembershipEntity membership = new GroupMembershipEntity(UUID.randomUUID(), groupId, actor, role, GroupMembershipStatus.ACTIVE, now, null);
        ActivityEntity activity = new ActivityEntity(activityId, groupId, UUID.randomUUID(), "Activity", null, ActivityStatus.CONFIRMED, null, null, null, null, null, now, now);
        M8ActivityAccess accessValue = new M8ActivityAccess(activity, new ReadableGroupAccess(group, membership));
        List<TaskAssigneeEntity> assigneeRows = assigned.stream().map(id -> new TaskAssigneeEntity(UUID.randomUUID(), task.getId(), id, actor, now)).toList();
        when(assignees.findByTaskId(task.getId())).thenReturn(assigneeRows);
        when(histories.findByTaskIdOrderByCreatedAtAsc(task.getId())).thenReturn(List.of());
        TaskService service = new TaskService(access, mock(GroupMembershipRepository.class), tasks, assignees, histories, Clock.fixed(now, ZoneOffset.UTC));
        return new Fixture(service, access, tasks, histories, task, accessValue);
    }

    private record Fixture(TaskService service, M8ActivityAccessService access, TaskRepository tasks, TaskStatusHistoryRepository histories, TaskEntity task, M8ActivityAccess accessValue) { }
}
