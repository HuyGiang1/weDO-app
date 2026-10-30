package com.wedo.backend.community;

import static com.wedo.backend.community.CommunityDtos.*;
import com.wedo.backend.media.dto.MediaAccessResponse;
import com.wedo.backend.security.AuthenticatedUserPrincipal;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/community")
public class CommunityController {
    private final CommunityService service;
    public CommunityController(CommunityService service){this.service=service;}
    @GetMapping("/posts") public Page<Post> feed(@AuthenticationPrincipal AuthenticatedUserPrincipal p,
        @RequestParam(defaultValue="FOR_YOU") Feed feed,@RequestParam(required=false) UUID authorId,@RequestParam(required=false) String before){
        UUID cursor=null;
        if(before!=null) { try { cursor=UUID.fromString(before); if(!cursor.toString().equalsIgnoreCase(before)) throw new IllegalArgumentException(); }
          catch(IllegalArgumentException e) { throw new com.wedo.backend.common.error.BusinessException(com.wedo.backend.common.error.ErrorCode.COMMUNITY_FEED_CURSOR_INVALID); } }
        return service.feed(p.userId(),feed,authorId,cursor);
    }
    @PostMapping("/posts/refresh") public Page<Post> refresh(@AuthenticationPrincipal AuthenticatedUserPrincipal p,
        @Valid @RequestBody Refresh r){return service.refreshFeed(p.userId(),r);}
    @PostMapping("/posts") public Post create(@AuthenticationPrincipal AuthenticatedUserPrincipal p,@Valid @RequestBody Create r){return service.create(p.userId(),r);}
    @GetMapping("/posts/{id}") public Post get(@PathVariable UUID id,@AuthenticationPrincipal AuthenticatedUserPrincipal p){return service.get(id,p.userId());}
    @PatchMapping("/posts/{id}") public Post edit(@PathVariable UUID id,@AuthenticationPrincipal AuthenticatedUserPrincipal p,@Valid @RequestBody Edit r){return service.edit(id,p.userId(),r);}
    @DeleteMapping("/posts/{id}") public void delete(@PathVariable UUID id,@AuthenticationPrincipal AuthenticatedUserPrincipal p){service.delete(id,p.userId());}
    @PutMapping("/posts/{id}/reaction") public Post react(@PathVariable UUID id,@AuthenticationPrincipal AuthenticatedUserPrincipal p,@RequestBody Reaction r){return service.react(id,p.userId(),r.emoji());}
    @GetMapping("/posts/{id}/comments") public Page<Comment> comments(@PathVariable UUID id,@AuthenticationPrincipal AuthenticatedUserPrincipal p,@RequestParam(required=false) UUID before){return service.comments(id,p.userId(),before);}
    @PostMapping("/posts/{id}/comments") public Comment comment(@PathVariable UUID id,@AuthenticationPrincipal AuthenticatedUserPrincipal p,@Valid @RequestBody AddComment r){return service.addComment(id,p.userId(),r);}
    @DeleteMapping("/posts/{id}/comments/{comment}") public void deleteComment(@PathVariable UUID id,@PathVariable UUID comment,@AuthenticationPrincipal AuthenticatedUserPrincipal p){service.deleteComment(id,comment,p.userId());}
    @PutMapping("/posts/{id}/hidden") public void hide(@PathVariable UUID id,@AuthenticationPrincipal AuthenticatedUserPrincipal p){service.hide(id,p.userId());}
    @PostMapping("/posts/{id}/reports") public void report(@PathVariable UUID id,@AuthenticationPrincipal AuthenticatedUserPrincipal p,@Valid @RequestBody Report r){service.report(id,p.userId(),r.reason());}
    @GetMapping("/media/{id}/access") public MediaAccessResponse media(@PathVariable UUID id,@AuthenticationPrincipal AuthenticatedUserPrincipal p){return service.mediaAccess(id,p.userId());}
}
