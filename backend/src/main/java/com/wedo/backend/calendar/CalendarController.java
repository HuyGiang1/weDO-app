package com.wedo.backend.calendar;

import com.wedo.backend.activity.entity.ActivityRsvpStatus;
import com.wedo.backend.activity.entity.ActivityStatus;
import com.wedo.backend.activity.reminder.ActivityReminderDtos.Request;
import com.wedo.backend.activity.reminder.ActivityReminderDtos.Response;
import com.wedo.backend.activity.reminder.ActivityReminderService;
import com.wedo.backend.security.AuthenticatedUserPrincipal;
import jakarta.validation.Valid;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class CalendarController {
    private final CalendarService calendar;
    private final ActivityReminderService reminders;

    public CalendarController(CalendarService calendar, ActivityReminderService reminders) {
        this.calendar = calendar;
        this.reminders = reminders;
    }

    @GetMapping("/api/v1/calendar/activities")
    public List<CalendarActivityResponse> activities(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @RequestParam(required = false) OffsetDateTime from,
            @RequestParam(required = false) OffsetDateTime to,
            @RequestParam(required = false) ActivityRsvpStatus rsvp,
            @RequestParam(required = false) UUID groupId,
            @RequestParam(required = false) ActivityStatus status) {
        return calendar.activities(from, to, rsvp, groupId, status, principal.userId());
    }

    @GetMapping("/api/v1/activities/{activityId}/reminder")
    public Response reminder(@AuthenticationPrincipal AuthenticatedUserPrincipal principal,
                             @PathVariable UUID activityId) {
        return reminders.get(activityId, principal.userId());
    }

    @PutMapping("/api/v1/activities/{activityId}/reminder")
    public Response updateReminder(@AuthenticationPrincipal AuthenticatedUserPrincipal principal,
                                   @PathVariable UUID activityId,
                                   @Valid @RequestBody Request request) {
        return reminders.put(activityId, principal.userId(), request);
    }
}
