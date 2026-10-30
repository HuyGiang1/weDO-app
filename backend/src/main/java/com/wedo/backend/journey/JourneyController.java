package com.wedo.backend.journey;
import static com.wedo.backend.journey.JourneyDtos.*;
import com.wedo.backend.security.AuthenticatedUserPrincipal;
import com.wedo.backend.moment.MomentDtos;
import jakarta.validation.Valid;
import java.time.Instant;
import java.util.UUID;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
@RestController @RequestMapping("/api/v1/activities/{activity}/journey")
public class JourneyController {
 final JourneyService service;public JourneyController(JourneyService service){this.service=service;}
 @GetMapping public Journey journey(@PathVariable UUID activity,@AuthenticationPrincipal AuthenticatedUserPrincipal p){return service.journey(activity,p.userId());}
 @PostMapping("/stops") public Stop create(@PathVariable UUID activity,@AuthenticationPrincipal AuthenticatedUserPrincipal p,@Valid @RequestBody Save r){return service.create(activity,p.userId(),r);}
 @GetMapping("/stops/{stop}") public Stop get(@PathVariable UUID activity,@PathVariable UUID stop,@AuthenticationPrincipal AuthenticatedUserPrincipal p){return service.get(activity,stop,p.userId());}
 @PatchMapping("/stops/{stop}") public Stop edit(@PathVariable UUID activity,@PathVariable UUID stop,@AuthenticationPrincipal AuthenticatedUserPrincipal p,@Valid @RequestBody Save r){return service.edit(activity,stop,p.userId(),r);}
 @PutMapping("/stops/{stop}/status") public Stop state(@PathVariable UUID activity,@PathVariable UUID stop,@AuthenticationPrincipal AuthenticatedUserPrincipal p,@Valid @RequestBody State r){return service.state(activity,stop,p.userId(),r);}
 @DeleteMapping("/stops/{stop}") public void delete(@PathVariable UUID activity,@PathVariable UUID stop,@AuthenticationPrincipal AuthenticatedUserPrincipal p,@RequestParam Instant expectedUpdatedAt){service.delete(activity,stop,p.userId(),expectedUpdatedAt);}
 @PutMapping("/order") public Journey reorder(@PathVariable UUID activity,@AuthenticationPrincipal AuthenticatedUserPrincipal p,@Valid @RequestBody Reorder r){return service.reorder(activity,p.userId(),r);}
 @GetMapping("/stops/{stop}/checkins") public MomentDtos.Page<CheckInView> checkins(@PathVariable UUID activity,@PathVariable UUID stop,@AuthenticationPrincipal AuthenticatedUserPrincipal p,@RequestParam(required=false) UUID before){return service.checkIns(activity,stop,p.userId(),before);}
 @PostMapping("/stops/{stop}/checkins") public CheckInView checkin(@PathVariable UUID activity,@PathVariable UUID stop,@AuthenticationPrincipal AuthenticatedUserPrincipal p,@Valid @RequestBody CheckIn r){return service.checkIn(activity,stop,p.userId(),r);}
}
