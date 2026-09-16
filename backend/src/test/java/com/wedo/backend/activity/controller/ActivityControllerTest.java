package com.wedo.backend.activity.controller;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

import com.wedo.backend.activity.dto.*;
import com.wedo.backend.activity.entity.ActivityRsvpStatus;
import com.wedo.backend.activity.service.*;
import com.wedo.backend.security.AuthenticatedUserPrincipal;
import java.time.Instant;
import java.util.*;
import org.junit.jupiter.api.Test;

/** Focused HTTP-adapter tests: command forwarding and response shape stay independent of persistence. */
class ActivityControllerTest {
    @Test void everyCommandForwardsPrincipalAndPathIdentifierToItsApplicationService() {
        ActivityService activities=mock(ActivityService.class); ActivityLifecycleService lifecycle=mock(ActivityLifecycleService.class);
        ActivityRsvpService rsvps=mock(ActivityRsvpService.class); ActivityParticipantService participants=mock(ActivityParticipantService.class);
        ActivityController controller=new ActivityController(activities,lifecycle,rsvps,participants);
        UUID user=UUID.randomUUID(), group=UUID.randomUUID(), activity=UUID.randomUUID(); AuthenticatedUserPrincipal principal=new AuthenticatedUserPrincipal(user);
        CreateActivityRequest create=new CreateActivityRequest("title",null,Instant.now().plusSeconds(1),null,"UTC",null,3);
        UpdateActivityRequest update=new UpdateActivityRequest("new",null,null,null,null,null,null);
        ChangeRsvpRequest rsvp=new ChangeRsvpRequest(ActivityRsvpStatus.GOING);
        assertEquals(201,controller.create(principal,group,create).getStatusCode().value());
        controller.list(principal,group,0,30); controller.detail(principal,activity); controller.update(principal,activity,update);
        controller.confirm(principal,activity); controller.cancel(principal,activity,new CancelActivityRequest("reason"));
        controller.complete(principal,activity); controller.rsvp(principal,activity,rsvp); controller.participants(principal,activity);
        verify(activities).createFoundation(group,user,create); verify(activities).listFoundation(group,user,0,30); verify(activities).getFoundation(activity,user);
        verify(lifecycle).update(activity,user,update); verify(lifecycle).confirm(activity,user); verify(lifecycle).cancel(activity,user,"reason"); verify(lifecycle).complete(activity,user);
        verify(rsvps).changeRsvp(activity,user,rsvp); verify(participants).list(activity,user);
    }

    @Test void rsvpCommandDoesNotAcceptBackendAssignedWaitlistAsClientIntent() {
        assertFalse(new ChangeRsvpRequest(ActivityRsvpStatus.WAITLIST).isClientAllowed());
        assertTrue(new ChangeRsvpRequest(ActivityRsvpStatus.MAYBE).isClientAllowed());
    }

    @Test void readDtosAreExplicitSafeRecordsWithoutAccountOrCredentialMembers() {
        for (Class<?> type : List.of(ActivityDetailResponse.class, ActivitySummaryResponse.class, ActivityParticipantResponse.class, ActivityCreatorResponse.class)) {
            List<String> names=Arrays.stream(type.getRecordComponents()).map(c->c.getName().toLowerCase()).toList();
            assertTrue(names.stream().noneMatch(n->n.contains("email")||n.contains("phone")||n.contains("password")||n.contains("credential")||n.contains("refresh")||n.contains("lock")));
        }
    }
}
