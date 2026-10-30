package com.wedo.backend.journey;
import static com.wedo.backend.journey.ActionDtos.*;
import com.wedo.backend.security.AuthenticatedUserPrincipal;
import com.wedo.backend.media.dto.MediaAccessResponse;
import jakarta.validation.Valid;
import java.util.*;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
@RestController @RequestMapping("/api/v1")
public class ActionController {
 final TaskEvidenceService evidence;final PollActionService actions;
 public ActionController(TaskEvidenceService evidence,PollActionService actions){this.evidence=evidence;this.actions=actions;}
 @GetMapping("/activities/{activity}/journey/stops/{stop}/tasks") public java.util.List<com.wedo.backend.task.dto.TaskResponse> stopTasks(@PathVariable UUID activity,@PathVariable UUID stop,@AuthenticationPrincipal AuthenticatedUserPrincipal p){return evidence.stopTasks(activity,stop,p.userId());}
 @GetMapping("/tasks/{task}/execution") public Execution task(@PathVariable UUID task,@AuthenticationPrincipal AuthenticatedUserPrincipal p,@RequestParam(required=false) UUID before){return evidence.get(task,p.userId(),before);}
 @PutMapping("/tasks/{task}/execution") public Execution configure(@PathVariable UUID task,@AuthenticationPrincipal AuthenticatedUserPrincipal p,@Valid @RequestBody Configure r){return evidence.configure(task,p.userId(),r);}
 @PostMapping("/tasks/{task}/evidence") public Execution submit(@PathVariable UUID task,@AuthenticationPrincipal AuthenticatedUserPrincipal p,@Valid @RequestBody Submit r){return evidence.submit(task,p.userId(),r);}
 @PostMapping("/tasks/{task}/evidence/{id}/review") public Execution review(@PathVariable UUID task,@PathVariable UUID id,@AuthenticationPrincipal AuthenticatedUserPrincipal p,@Valid @RequestBody Review r){return evidence.review(task,id,p.userId(),r);}
 @GetMapping("/tasks/{task}/evidence/media/{media}/access") public MediaAccessResponse media(@PathVariable UUID task,@PathVariable UUID media,@AuthenticationPrincipal AuthenticatedUserPrincipal p){return evidence.media(task,media,p.userId());}
 @GetMapping("/polls/{poll}/actions") public ConversionContext context(@PathVariable UUID poll,@AuthenticationPrincipal AuthenticatedUserPrincipal p){return actions.context(poll,p.userId());}
 @PostMapping("/polls/{poll}/actions") public Link convert(@PathVariable UUID poll,@AuthenticationPrincipal AuthenticatedUserPrincipal p,@Valid @RequestBody Convert r){return actions.convert(poll,p.userId(),r);}
 @GetMapping("/journey/targets/{target}/{id}/sources") public List<Link> sources(@PathVariable Target target,@PathVariable UUID id,@AuthenticationPrincipal AuthenticatedUserPrincipal p){return actions.targetSources(target,id,p.userId());}
}
