package com.wedo.backend.community;

import com.wedo.backend.security.AuthenticatedUserPrincipal;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import static com.wedo.backend.community.ModerationDtos.*;

@RestController
@RequestMapping("/api/v1")
public class ModerationController {
    private final ModerationService service;
    private final CommunityService community;
    public ModerationController(ModerationService service,CommunityService community){this.service=service;this.community=community;}
    @GetMapping("/moderation/access") public Access access(@AuthenticationPrincipal AuthenticatedUserPrincipal p){return service.capabilities(p.userId());}
    @GetMapping("/moderation/reports") public CommunityDtos.Page<Item> queue(@AuthenticationPrincipal AuthenticatedUserPrincipal p,@RequestParam(required=false) String status,@RequestParam(required=false) String reason,@RequestParam(required=false) Target type,@RequestParam(required=false) UUID before){return service.queue(p.userId(),status,reason,type,before);}
    @GetMapping("/moderation/reports/{id}") public Detail detail(@PathVariable UUID id,@AuthenticationPrincipal AuthenticatedUserPrincipal p){return service.detail(id,p.userId());}
    @GetMapping("/moderation/reports/{id}/media/{media}/access") public com.wedo.backend.media.dto.MediaAccessResponse media(@PathVariable UUID id,@PathVariable UUID media,@AuthenticationPrincipal AuthenticatedUserPrincipal p){return service.evidenceMedia(id,media,p.userId());}
    @PostMapping("/moderation/reports/{id}/actions") public Detail act(@PathVariable UUID id,@AuthenticationPrincipal AuthenticatedUserPrincipal p,@Valid @RequestBody Command command){return service.act(id,p.userId(),command);}
    @PostMapping("/users/{id}/reports") public UUID userReport(@PathVariable UUID id,@AuthenticationPrincipal AuthenticatedUserPrincipal p,@Valid @RequestBody Submit request){return service.submit(p.userId(),Target.USER,id,request.reason());}
    @PostMapping("/community/comments/{id}/reports") public UUID commentReport(@PathVariable UUID id,@AuthenticationPrincipal AuthenticatedUserPrincipal p,@Valid @RequestBody Submit request){return service.submit(p.userId(),Target.COMMENT,id,request.reason());}
    @GetMapping("/community/hidden-posts") public CommunityDtos.Page<Hidden> hidden(@AuthenticationPrincipal AuthenticatedUserPrincipal p,@RequestParam(required=false) UUID before){return community.hidden(p.userId(),before);}
    @DeleteMapping("/community/posts/{id}/hidden") public void unhide(@PathVariable UUID id,@AuthenticationPrincipal AuthenticatedUserPrincipal p){community.unhide(id,p.userId());}
}
