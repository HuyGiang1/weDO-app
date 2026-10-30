package com.wedo.backend.community;
import com.wedo.backend.security.AuthenticatedUserPrincipal;
import jakarta.validation.Valid;
import java.time.Instant;
import java.util.*;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
@RestController @RequestMapping("/api/v1/community")
public class RecruitmentController {
 private final RecruitmentService service;public RecruitmentController(RecruitmentService service){this.service=service;}
 @GetMapping("/recruitment-options") public List<RecruitmentDtos.Option> options(@AuthenticationPrincipal AuthenticatedUserPrincipal p){return service.options(p.userId());}
 @GetMapping("/recruitments") public CommunityDtos.Page<CommunityDtos.Post> discover(@AuthenticationPrincipal AuthenticatedUserPrincipal p,@RequestParam(required=false) String keyword,@RequestParam(required=false) String tag,@RequestParam(required=false) String location,@RequestParam(required=false) Instant from,@RequestParam(required=false) Instant to,@RequestParam(required=false) UUID before){return service.discover(p.userId(),new RecruitmentDtos.Filter(keyword,tag,location,from,to,before));}
 @PostMapping("/recruitments") public CommunityDtos.Post create(@AuthenticationPrincipal AuthenticatedUserPrincipal p,@Valid @RequestBody RecruitmentDtos.Create r){return service.create(p.userId(),r);}
 @GetMapping("/recruitments/{id}/preview") public RecruitmentDtos.View preview(@PathVariable UUID id,@AuthenticationPrincipal AuthenticatedUserPrincipal p){return service.preview(id,p.userId());}
 @PostMapping("/recruitments/{id}/join") public RecruitmentDtos.View join(@PathVariable UUID id,@AuthenticationPrincipal AuthenticatedUserPrincipal p){return service.request(id,p.userId());}
 @PostMapping("/recruitments/{id}/cancel") public RecruitmentDtos.View cancel(@PathVariable UUID id,@AuthenticationPrincipal AuthenticatedUserPrincipal p){return service.cancel(id,p.userId());}
 @PostMapping("/recruitments/{id}/close") public RecruitmentDtos.View close(@PathVariable UUID id,@AuthenticationPrincipal AuthenticatedUserPrincipal p){return service.close(id,p.userId());}
 @GetMapping("/recruitments/{id}/requests") public List<com.wedo.backend.group.dto.JoinRequestResponse> requests(@PathVariable UUID id,@AuthenticationPrincipal AuthenticatedUserPrincipal p){return service.requests(id,p.userId());}
 @PostMapping("/recruitments/{id}/requests/{request}/approve") public RecruitmentDtos.View approve(@PathVariable UUID id,@PathVariable UUID request,@AuthenticationPrincipal AuthenticatedUserPrincipal p){return service.resolve(id,request,p.userId(),true);}
 @PostMapping("/recruitments/{id}/requests/{request}/reject") public RecruitmentDtos.View reject(@PathVariable UUID id,@PathVariable UUID request,@AuthenticationPrincipal AuthenticatedUserPrincipal p){return service.resolve(id,request,p.userId(),false);}
}
