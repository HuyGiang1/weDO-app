package com.wedo.backend.activity.controller;

import com.wedo.backend.activity.dto.*;
import com.wedo.backend.activity.service.*;
import com.wedo.backend.common.dto.PagedResponse;
import com.wedo.backend.security.AuthenticatedUserPrincipal;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import java.util.UUID;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.security.core.annotation.AuthenticationPrincipal;

@RestController
@RequestMapping("/api/v1")
public class ActivityController {
    private final ActivityService activities; private final ActivityLifecycleService lifecycle; private final ActivityRsvpService rsvps; private final ActivityParticipantService participantService;
    public ActivityController(ActivityService activities, ActivityLifecycleService lifecycle, ActivityRsvpService rsvps, ActivityParticipantService participantService){this.activities=activities;this.lifecycle=lifecycle;this.rsvps=rsvps;this.participantService=participantService;}
    @PostMapping("/groups/{groupId}/activities") public ResponseEntity<ActivityDetailResponse> create(@AuthenticationPrincipal AuthenticatedUserPrincipal p,@PathVariable UUID groupId,@Valid @RequestBody CreateActivityRequest r){return ResponseEntity.status(201).body(activities.createFoundation(groupId,p.userId(),r));}
    @GetMapping("/groups/{groupId}/activities") public ResponseEntity<PagedResponse<ActivitySummaryResponse>> list(@AuthenticationPrincipal AuthenticatedUserPrincipal p,@PathVariable UUID groupId,@RequestParam(defaultValue="0")@Min(0)int page,@RequestParam(defaultValue="30")@Min(1)@Max(100)int size){return ResponseEntity.ok(activities.listFoundation(groupId,p.userId(),page,size));}
    @GetMapping("/activities/{id}") public ResponseEntity<ActivityDetailResponse> detail(@AuthenticationPrincipal AuthenticatedUserPrincipal p,@PathVariable UUID id){return ResponseEntity.ok(activities.getFoundation(id,p.userId()));}
    @PatchMapping("/activities/{id}") public ResponseEntity<ActivityDetailResponse> update(@AuthenticationPrincipal AuthenticatedUserPrincipal p,@PathVariable UUID id,@Valid @RequestBody UpdateActivityRequest r){return ResponseEntity.ok(lifecycle.update(id,p.userId(),r));}
    @PostMapping("/activities/{id}/confirm") public ResponseEntity<ActivityDetailResponse> confirm(@AuthenticationPrincipal AuthenticatedUserPrincipal p,@PathVariable UUID id){return ResponseEntity.ok(lifecycle.confirm(id,p.userId()));}
    @PostMapping("/activities/{id}/cancel") public ResponseEntity<ActivityDetailResponse> cancel(@AuthenticationPrincipal AuthenticatedUserPrincipal p,@PathVariable UUID id,@Valid @RequestBody(required=false) CancelActivityRequest r){return ResponseEntity.ok(lifecycle.cancel(id,p.userId(),r==null?null:r.reason()));}
    @PostMapping("/activities/{id}/complete") public ResponseEntity<ActivityDetailResponse> complete(@AuthenticationPrincipal AuthenticatedUserPrincipal p,@PathVariable UUID id){return ResponseEntity.ok(lifecycle.complete(id,p.userId()));}
    @PutMapping("/activities/{id}/rsvp") public ResponseEntity<ActivityRsvpResponse> rsvp(@AuthenticationPrincipal AuthenticatedUserPrincipal p,@PathVariable UUID id,@Valid @RequestBody ChangeRsvpRequest r){return ResponseEntity.ok(rsvps.changeRsvp(id,p.userId(),r));}
    @GetMapping("/activities/{id}/participants") public ResponseEntity<java.util.List<ActivityParticipantResponse>> participants(@AuthenticationPrincipal AuthenticatedUserPrincipal p,@PathVariable UUID id){return ResponseEntity.ok(participantService.list(id,p.userId()));}
}
