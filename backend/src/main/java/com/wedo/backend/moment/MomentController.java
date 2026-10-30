package com.wedo.backend.moment;

import static com.wedo.backend.moment.MomentDtos.*;
import com.wedo.backend.media.dto.MediaAccessResponse;
import com.wedo.backend.security.AuthenticatedUserPrincipal;
import jakarta.validation.Valid;
import java.util.*;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController @RequestMapping("/api/v1")
public class MomentController {
 private final MomentService service;
 public MomentController(MomentService service){this.service=service;}
 @GetMapping("/groups/{group}/moments") public Page<Moment> feed(@PathVariable UUID group,@AuthenticationPrincipal AuthenticatedUserPrincipal p,@RequestParam(required=false) UUID activityId,@RequestParam(required=false) UUID before){return service.feed(group,p.userId(),activityId,before);}
 @PostMapping("/groups/{group}/moments") public Moment create(@PathVariable UUID group,@AuthenticationPrincipal AuthenticatedUserPrincipal p,@Valid @RequestBody CreateMoment r){return service.create(group,p.userId(),r);}
 @GetMapping("/moments/{id}") public Moment get(@PathVariable UUID id,@AuthenticationPrincipal AuthenticatedUserPrincipal p){return service.get(id,p.userId());}
 @PatchMapping("/moments/{id}") public Moment edit(@PathVariable UUID id,@AuthenticationPrincipal AuthenticatedUserPrincipal p,@Valid @RequestBody EditMoment r){return service.edit(id,p.userId(),r);}
 @DeleteMapping("/moments/{id}") public void delete(@PathVariable UUID id,@AuthenticationPrincipal AuthenticatedUserPrincipal p){service.delete(id,p.userId());}
 @PutMapping("/moments/{id}/reaction") public Moment react(@PathVariable UUID id,@AuthenticationPrincipal AuthenticatedUserPrincipal p,@RequestBody React r){return service.react(id,p.userId(),r.emoji());}
 @GetMapping("/moments/{id}/comments") public Page<Comment> comments(@PathVariable UUID id,@AuthenticationPrincipal AuthenticatedUserPrincipal p,@RequestParam(required=false) UUID before){return service.comments(id,p.userId(),before);}
 @PostMapping("/moments/{id}/comments") public Comment comment(@PathVariable UUID id,@AuthenticationPrincipal AuthenticatedUserPrincipal p,@Valid @RequestBody AddComment r){return service.addComment(id,p.userId(),r);}
 @DeleteMapping("/moments/{id}/comments/{comment}") public void deleteComment(@PathVariable UUID id,@PathVariable UUID comment,@AuthenticationPrincipal AuthenticatedUserPrincipal p){service.deleteComment(id,comment,p.userId());}
 @GetMapping("/groups/{group}/albums") public Page<Album> albums(@PathVariable UUID group,@AuthenticationPrincipal AuthenticatedUserPrincipal p,@RequestParam(required=false) UUID activityId,@RequestParam(required=false) UUID before){return service.albums(group,p.userId(),activityId,before);}
 @PostMapping("/groups/{group}/albums") public Album createAlbum(@PathVariable UUID group,@AuthenticationPrincipal AuthenticatedUserPrincipal p,@Valid @RequestBody SaveAlbum r){return service.saveAlbum(group,p.userId(),r,false);}
 @PatchMapping("/groups/{group}/albums") public Album editAlbum(@PathVariable UUID group,@AuthenticationPrincipal AuthenticatedUserPrincipal p,@Valid @RequestBody SaveAlbum r){return service.saveAlbum(group,p.userId(),r,true);}
 @GetMapping("/albums/{id}") public Album album(@PathVariable UUID id,@AuthenticationPrincipal AuthenticatedUserPrincipal p){return service.album(id,p.userId());}
 @DeleteMapping("/albums/{id}") public void deleteAlbum(@PathVariable UUID id,@AuthenticationPrincipal AuthenticatedUserPrincipal p){service.deleteAlbum(id,p.userId());}
 @GetMapping("/albums/{id}/media") public Page<Media> media(@PathVariable UUID id,@AuthenticationPrincipal AuthenticatedUserPrincipal p,@RequestParam(required=false) UUID before){return service.albumMedia(id,p.userId(),before);}
 @PutMapping("/albums/{id}/media") public Album addMedia(@PathVariable UUID id,@AuthenticationPrincipal AuthenticatedUserPrincipal p,@Valid @RequestBody AddItems r){return service.items(id,p.userId(),r.mediaIds(),true);}
 @DeleteMapping("/albums/{id}/media/{media}") public Album removeMedia(@PathVariable UUID id,@PathVariable UUID media,@AuthenticationPrincipal AuthenticatedUserPrincipal p){return service.items(id,p.userId(),List.of(media),false);}
 @GetMapping("/moment-media/{id}/access") public MediaAccessResponse access(@PathVariable UUID id,@AuthenticationPrincipal AuthenticatedUserPrincipal p){return service.mediaAccess(id,p.userId());}
}
