package com.wedo.backend.social.service;

import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import org.springframework.stereotype.Component;

import java.util.UUID;

@Component
public class MutualGroupChecker {

    @PersistenceContext
    private EntityManager entityManager;

    public boolean haveMutualActiveGroup(UUID userA, UUID userB) {
        Number count = (Number) entityManager.createNativeQuery(
                "SELECT COUNT(*) FROM group_memberships m1 " +
                "JOIN group_memberships m2 ON m1.group_id = m2.group_id " +
                "WHERE m1.user_id = :userA AND m2.user_id = :userB " +
                "AND m1.status = 'ACTIVE' AND m2.status = 'ACTIVE'"
        )
        .setParameter("userA", userA)
        .setParameter("userB", userB)
        .getSingleResult();

        return count != null && count.longValue() > 0;
    }
}
