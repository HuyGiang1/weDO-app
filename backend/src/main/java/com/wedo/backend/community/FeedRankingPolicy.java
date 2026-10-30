package com.wedo.backend.community;

import java.time.Duration;
import java.time.Instant;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/** Integer-only V1 scoring; no client/private behavioral features. */
@Component
public final class FeedRankingPolicy {
    final int freshnessWeight, socialWeight, engagementWeight, recruitmentWeight, actorCap;
    final long halfLifeSeconds;

    public FeedRankingPolicy(
            @Value("${wedo.community.ranking.freshness-weight:600}") int freshnessWeight,
            @Value("${wedo.community.ranking.social-weight:150}") int socialWeight,
            @Value("${wedo.community.ranking.engagement-weight:150}") int engagementWeight,
            @Value("${wedo.community.ranking.recruitment-weight:100}") int recruitmentWeight,
            @Value("${wedo.community.ranking.actor-cap:20}") int actorCap,
            @Value("${wedo.community.ranking.half-life-seconds:86400}") long halfLifeSeconds) {
        if (freshnessWeight < 0 || socialWeight < 0 || engagementWeight < 0 || recruitmentWeight < 0
                || freshnessWeight + socialWeight + engagementWeight + recruitmentWeight != 1000
                || actorCap < 1 || actorCap > 1000 || halfLifeSeconds < 1 || halfLifeSeconds > 31536000)
            throw new IllegalArgumentException("Invalid Community ranking policy");
        this.freshnessWeight = freshnessWeight; this.socialWeight = socialWeight;
        this.engagementWeight = engagementWeight; this.recruitmentWeight = recruitmentWeight;
        this.actorCap = actorCap; this.halfLifeSeconds = halfLifeSeconds;
    }

    public long score(Instant created, Instant reference, long distinctActors, boolean friend, boolean openRecruitment) {
        long age = Math.max(0, Duration.between(created, reference).getSeconds());
        long fresh = 1000L * halfLifeSeconds / (halfLifeSeconds + age);
        long engagement = 1000L * Math.min(actorCap, Math.max(0, distinctActors)) / actorCap;
        return freshnessWeight * fresh + socialWeight * (friend ? 1000L : 0)
                + engagementWeight * engagement + recruitmentWeight * (openRecruitment ? 1000L : 0);
    }
}
