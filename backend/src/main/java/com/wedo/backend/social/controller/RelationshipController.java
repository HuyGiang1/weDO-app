package com.wedo.backend.social.controller;

import com.wedo.backend.security.AuthenticatedUserPrincipal;
import com.wedo.backend.social.dto.RelationshipState;
import com.wedo.backend.social.dto.RelationshipStatusResponse;
import com.wedo.backend.social.service.RelationshipService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/users")
public class RelationshipController {

    private final RelationshipService relationshipService;

    public RelationshipController(RelationshipService relationshipService) {
        this.relationshipService = relationshipService;
    }

    @GetMapping("/{userId}/relationship")
    public ResponseEntity<RelationshipStatusResponse> getRelationship(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable("userId") UUID userId
    ) {
        RelationshipState state = relationshipService.getRelationshipState(principal.userId(), userId);
        return ResponseEntity.ok(new RelationshipStatusResponse(userId, state));
    }
}
