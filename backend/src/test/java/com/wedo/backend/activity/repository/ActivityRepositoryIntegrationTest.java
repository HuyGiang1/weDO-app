package com.wedo.backend.activity.repository;

import com.wedo.backend.activity.entity.ActivityEntity;
import com.wedo.backend.activity.entity.ActivityLocation;
import com.wedo.backend.activity.entity.ActivityStatus;
import com.wedo.backend.common.test.AbstractPostgresIntegrationTest;
import com.wedo.backend.group.entity.GroupEntity;
import com.wedo.backend.group.entity.GroupStatus;
import com.wedo.backend.group.repository.GroupRepository;
import com.wedo.backend.user.entity.UserEntity;
import com.wedo.backend.user.entity.UserStatus;
import com.wedo.backend.user.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.PageRequest;
import org.springframework.transaction.annotation.Transactional;
import java.time.Instant;
import java.util.UUID;
import static org.junit.jupiter.api.Assertions.*;

class ActivityRepositoryIntegrationTest extends AbstractPostgresIntegrationTest {
    @Autowired ActivityRepository activities;
    @Autowired GroupRepository groups;
    @Autowired UserRepository users;

    @Test @Transactional void mapsJsonb_listsByGroupAndAcquiresPessimisticActivityRowLock() {
        Instant now=Instant.parse("2026-09-15T10:00:00Z");
        UUID userId=UUID.randomUUID();
        users.save(new UserEntity(userId,"activity-"+userId+"@test.local","activity_"+userId.toString().substring(0,8),"Activity User", UserStatus.ACTIVE,now,now));
        UUID groupId=UUID.randomUUID();
        groups.save(new GroupEntity(groupId,"Activity group",null,null, GroupStatus.ACTIVE,userId,now,now));
        ActivityEntity activity=activities.saveAndFlush(new ActivityEntity(UUID.randomUUID(),groupId,userId,"Early","d",ActivityStatus.PLANNING,now.plusSeconds(60),null,"UTC",new ActivityLocation("PHYSICAL","Venue","Address",10.0,106.0),20,now,now));
        assertEquals("Venue",activities.findByIdForUpdate(activity.getId()).orElseThrow().getLocation().name());
        assertEquals(1,activities.findByGroupIdOrderByStartAtAsc(groupId, PageRequest.of(0,30)).getTotalElements());
    }
}
