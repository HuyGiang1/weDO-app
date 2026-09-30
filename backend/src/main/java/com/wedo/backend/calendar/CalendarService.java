package com.wedo.backend.calendar;

import com.wedo.backend.activity.entity.ActivityRsvpStatus;
import com.wedo.backend.activity.entity.ActivityStatus;
import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class CalendarService {
    private final CalendarRepository calendar;

    public CalendarService(CalendarRepository calendar) { this.calendar = calendar; }

    @Transactional(readOnly = true)
    public List<CalendarActivityResponse> activities(OffsetDateTime from, OffsetDateTime to,
                                                    ActivityRsvpStatus rsvp, UUID groupId,
                                                    ActivityStatus status, UUID userId) {
        if (from != null && to != null && from.isAfter(to)) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED, "Calendar from must not be after to.");
        }
        return calendar.findActivities(userId, from == null ? null : from.toInstant(),
                to == null ? null : to.toInstant(), rsvp, groupId, status);
    }
}
