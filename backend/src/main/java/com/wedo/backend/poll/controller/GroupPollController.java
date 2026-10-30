package com.wedo.backend.poll.controller;

import com.wedo.backend.poll.dto.PollResponse;
import com.wedo.backend.poll.service.PollService;
import com.wedo.backend.security.AuthenticatedUserPrincipal;
import java.util.List;
import java.util.UUID;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/groups/{groupId}/polls")
public class GroupPollController {
    private final PollService polls;
    public GroupPollController(PollService polls) { this.polls = polls; }
    @GetMapping
    public List<PollResponse> list(@PathVariable UUID groupId, @AuthenticationPrincipal AuthenticatedUserPrincipal p) {
        return polls.listGroup(groupId, p.userId());
    }
}
