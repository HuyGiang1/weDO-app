package com.wedo.backend.chat.controller;

import com.wedo.backend.chat.dto.ChatRequests;
import com.wedo.backend.chat.dto.ChatResponses;
import com.wedo.backend.chat.service.ChatService;
import com.wedo.backend.security.AuthenticatedUserPrincipal;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
public class ChatController {
    private final ChatService service;
    public ChatController(ChatService service) { this.service = service; }

    @GetMapping("/conversations")
    public List<ChatResponses.Conversation> list(@AuthenticationPrincipal AuthenticatedUserPrincipal p) {
        return service.list(p.userId());
    }

    @PostMapping("/groups/{groupId}/conversation")
    public ChatResponses.Conversation openGroup(@AuthenticationPrincipal AuthenticatedUserPrincipal p,
                                                @PathVariable UUID groupId) {
        return service.openGroup(groupId,p.userId());
    }

    @PostMapping("/direct-conversations")
    public ChatResponses.DirectOpen openDirect(@AuthenticationPrincipal AuthenticatedUserPrincipal p,
                                               @Valid @RequestBody ChatRequests.OpenDirect request) {
        return service.openDirect(p.userId(),request.userId());
    }

    @GetMapping("/message-requests")
    public List<ChatResponses.MessageRequest> requests(@AuthenticationPrincipal AuthenticatedUserPrincipal p) {
        return service.requests(p.userId());
    }

    @PostMapping("/message-requests/{id}/accept")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void accept(@AuthenticationPrincipal AuthenticatedUserPrincipal p,@PathVariable UUID id) {
        service.resolveRequest(id,p.userId(),true);
    }

    @PostMapping("/message-requests/{id}/decline")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void decline(@AuthenticationPrincipal AuthenticatedUserPrincipal p,@PathVariable UUID id) {
        service.resolveRequest(id,p.userId(),false);
    }

    @GetMapping("/conversations/{id}/messages")
    public ChatResponses.MessagePage history(@AuthenticationPrincipal AuthenticatedUserPrincipal p,
                                             @PathVariable UUID id,
                                             @RequestParam(required=false) Long beforeSequence,
                                             @RequestParam(defaultValue="30") int limit) {
        return service.history(id,p.userId(),beforeSequence,limit);
    }

    @PostMapping("/conversations/{id}/messages")
    public ResponseEntity<ChatResponses.Message> send(@AuthenticationPrincipal AuthenticatedUserPrincipal p,
                                                       @PathVariable UUID id,
                                                       @Valid @RequestBody ChatRequests.SendMessage request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(service.send(id,p.userId(),request));
    }

    @PatchMapping("/messages/{id}")
    public ChatResponses.Message edit(@AuthenticationPrincipal AuthenticatedUserPrincipal p,
                                      @PathVariable UUID id,
                                      @Valid @RequestBody ChatRequests.EditMessage request) {
        return service.edit(id,p.userId(),request);
    }

    @PostMapping("/messages/{id}/unsend")
    public ChatResponses.Message unsend(@AuthenticationPrincipal AuthenticatedUserPrincipal p,@PathVariable UUID id) {
        return service.unsend(id,p.userId());
    }

    @DeleteMapping("/messages/{id}/me")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteForMe(@AuthenticationPrincipal AuthenticatedUserPrincipal p,@PathVariable UUID id) {
        service.deleteForMe(id,p.userId());
    }

    @GetMapping("/messages/{id}/reactions")
    public List<ChatResponses.ReactionDetail> reactions(@AuthenticationPrincipal AuthenticatedUserPrincipal p,
                                                       @PathVariable UUID id) {
        return service.reactionDetails(id,p.userId());
    }

    @PutMapping("/messages/{id}/reaction")
    public ChatResponses.Message reaction(@AuthenticationPrincipal AuthenticatedUserPrincipal p,
                                          @PathVariable UUID id,
                                          @Valid @RequestBody ChatRequests.Reaction request) {
        return service.react(id,p.userId(),request);
    }

    @PutMapping("/conversations/{id}/read-state")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void read(@AuthenticationPrincipal AuthenticatedUserPrincipal p,@PathVariable UUID id,
                     @RequestBody ChatRequests.ReadState request) {
        service.read(id,p.userId(),request.lastReadSequence());
    }

    @PostMapping("/messages/{id}/pin")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void pin(@AuthenticationPrincipal AuthenticatedUserPrincipal p,@PathVariable UUID id) {
        service.pin(id,p.userId(),true);
    }

    @DeleteMapping("/messages/{id}/pin")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void unpin(@AuthenticationPrincipal AuthenticatedUserPrincipal p,@PathVariable UUID id) {
        service.pin(id,p.userId(),false);
    }

    @GetMapping("/conversations/{id}/pins")
    public List<ChatResponses.Message> pins(@AuthenticationPrincipal AuthenticatedUserPrincipal p,@PathVariable UUID id) {
        return service.pins(id,p.userId());
    }

    @GetMapping("/conversations/{id}/messages/search")
    public List<ChatResponses.Message> search(@AuthenticationPrincipal AuthenticatedUserPrincipal p,
                                             @PathVariable UUID id,@RequestParam String q) {
        return service.search(id,p.userId(),q);
    }
}
