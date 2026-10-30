package com.wedo.backend.community;

import static com.wedo.backend.community.CommunityDtos.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import com.wedo.backend.common.test.AbstractPostgresIntegrationTest;
import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.user.entity.*;
import com.wedo.backend.user.repository.UserRepository;
import java.time.*;
import java.sql.Timestamp;
import java.util.*;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.transaction.annotation.Transactional;

@Transactional
class FeedRankingIntegrationTest extends AbstractPostgresIntegrationTest {
    @Autowired CommunityService service;
    @Autowired CommunityAccess access;
    @Autowired CommunityFeedRanking ranking;
    @Autowired CommunityPostReader reader;
    @Autowired jakarta.persistence.EntityManager entities;
    @Autowired FeedRankingPolicy policy;
    @org.springframework.test.context.bean.override.mockito.MockitoSpyBean JdbcTemplate db;
    @Autowired UserRepository users;
    @MockitoBean Clock clock;
    @MockitoBean com.wedo.backend.activity.reminder.ActivityReminderDeliveryScheduler reminderScheduler;
    @MockitoBean com.google.firebase.FirebaseApp firebase;
    @MockitoBean com.google.firebase.messaging.FirebaseMessaging messaging;
    final Instant now=Instant.parse("2026-10-29T08:00:00Z");
    UUID viewer, author;
    @BeforeEach void setup() {
        when(clock.instant()).thenReturn(now);when(clock.getZone()).thenReturn(ZoneOffset.UTC);
        viewer=user(); author=user();
        // Existing test classes may leave public fixtures. Isolate this viewer only.
        db.update("INSERT INTO user_blocks(id,blocker_id,blocked_id) SELECT gen_random_uuid(),?,a.author_id FROM (SELECT DISTINCT author_id FROM community_posts) a WHERE a.author_id<>?",viewer,viewer);
    }
    UUID user() {
        UUID id=UUID.randomUUID();users.saveAndFlush(new UserEntity(id,id+"@r8.test","u"+id.toString().substring(0,8),"Ranking QA",UserStatus.ACTIVE,now,now));return id;
    }
    void friend(UUID a,UUID b) {db.update("INSERT INTO friendships(id,user_id_1,user_id_2) VALUES (?,LEAST(?::uuid,?::uuid),GREATEST(?::uuid,?::uuid))",UUID.randomUUID(),a,b,a,b);}
    UUID post(UUID actor,Visibility visibility,long ageSeconds) {
        UUID id=service.create(actor,new Create(UUID.randomUUID(),"Ranking QA",visibility,null,List.of())).id();
        db.update("UPDATE community_posts SET created_at=? WHERE id=?",Timestamp.from(now.minusSeconds(ageSeconds)),id);return id;
    }
    List<UUID> ids(Page<Post> p){return p.items().stream().map(Post::id).toList();}
    Page<Post> feed(UUID cursor){return service.feed(viewer,Feed.FOR_YOU,null,cursor);}
    UUID group(UUID owner,UUID member) {
        UUID id=UUID.randomUUID();db.update("INSERT INTO groups(id,name,status,created_by) VALUES (?,'R8 isolated','ACTIVE',?)",id,owner);
        db.update("INSERT INTO group_settings(group_id,join_policy) VALUES (?,'APPROVAL_REQUIRED')",id);
        db.update("INSERT INTO group_memberships(id,group_id,user_id,role,status) VALUES (?,?,?,'OWNER','ACTIVE')",UUID.randomUUID(),id,owner);
        if(member!=null)db.update("INSERT INTO group_memberships(id,group_id,user_id,role,status) VALUES (?,?,?,'MEMBER','ACTIVE')",UUID.randomUUID(),id,member);
        return id;
    }
    UUID recruit(String state) {
        UUID id=post(author,Visibility.PUBLIC,0),g=group(author,null);
        db.update("UPDATE community_posts SET post_type='LOOKING_FOR_MEMBERS' WHERE id=?",id);
        db.update("INSERT INTO community_recruitment(post_id,group_id,requested_count,expires_at,planned_at,public_group_name,closed_at) VALUES (?,?,1,?,?, 'R8 safe preview',?)",
                id,g,Timestamp.from(state.equals("EXPIRED")?now.minusSeconds(1):now.plusSeconds(86400)),
                Timestamp.from(state.equals("PAST")?now.minusSeconds(1):now.plusSeconds(3600)),state.equals("CLOSED")?Timestamp.from(now):null);
        if(state.equals("FILLED")) {
            UUID m=user(),q=UUID.randomUUID();
            db.update("INSERT INTO group_join_requests(id,group_id,user_id,status,responded_at) VALUES (?,?,?,'APPROVED',now())",q,g,m);
            db.update("INSERT INTO recruitment_applications(request_id,post_id) VALUES (?,?)",q,id);
        }
        return id;
    }
    @Test void freshnessAndColdStartNeedNoFriendsOrEngagement() {
        UUID old=post(author,Visibility.PUBLIC,7*86400),fresh=post(author,Visibility.PUBLIC,0);
        assertEquals(List.of(fresh,old),ids(feed(null)));
        assertTrue(policy.score(now,now,0,false,false)>policy.score(now.minusSeconds(86400),now,0,false,false));
        assertEquals(600000,policy.score(now,now,0,false,false));
    }
    @Test void friendBoostUsesConfirmedGraphAndMissingInterestIsNeutral() {
        UUID x=user();friend(viewer,author);UUID friend=post(author,Visibility.PUBLIC,0),stranger=post(x,Visibility.PUBLIC,0);
        assertEquals(List.of(friend,stranger),ids(feed(null)));
        assertEquals(150000,policy.score(now,now,0,true,false)-policy.score(now,now,0,false,false));
    }
    @Test void engagementCapsDistinctActorsAndAuthorCannotFarmComments() {
        UUID engaged=post(author,Visibility.PUBLIC,0),other=post(user(),Visibility.PUBLIC,0),actor=user();
        for(int i=0;i<25;i++)service.addComment(engaged,actor,new AddComment(UUID.randomUUID(),"same actor"));
        service.react(engaged,actor,"❤️");service.react(engaged,actor,"👍");
        for(int i=0;i<10;i++)service.addComment(other,author,new AddComment(UUID.randomUUID(),"actor"));
        // Remove the other actor's comments; only self-author comments should have zero boost.
        db.update("UPDATE community_comments SET author_id=(SELECT author_id FROM community_posts WHERE id=?) WHERE post_id=?",other,other);
        assertEquals(engaged,ids(feed(null)).getFirst());
        assertEquals(policy.score(now,now,20,false,false),policy.score(now,now,200000,false,false));
        assertTrue(policy.score(now,now,0,false,false)>policy.score(now.minusSeconds(86400*30),now,200000,false,false));
        db.update("INSERT INTO user_blocks(id,blocker_id,blocked_id) VALUES (?,?,?)",UUID.randomUUID(),viewer,actor);
        assertEquals(0,service.get(engaged,viewer).reactionCount());
    }
    @Test void onlyOpenFutureRecruitmentGetsBoundedBoost() {
        var closed=recruit("CLOSED");var filled=recruit("FILLED");var expired=recruit("EXPIRED");var past=recruit("PAST");var open=recruit("OPEN");var normal=post(author,Visibility.PUBLIC,0);
        var rows=feed(null);assertEquals(open,rows.items().getFirst().id());
        assertEquals("OPEN",rows.items().getFirst().recruitment().status());
        assertTrue(ids(rows).containsAll(List.of(closed,filled,expired,past,normal)));
        assertEquals(100000,policy.score(now,now,0,false,true)-policy.score(now,now,0,false,false));
    }
    @Test void deterministicTiesUseTimestampThenUnsignedUuid() {
        for(int i=0;i<8;i++)post(author,Visibility.PUBLIC,0);
        var a=ids(feed(null));var b=ids(feed(null));assertEquals(a,b);
        var sorted=new ArrayList<>(a);sorted.sort(Comparator.comparing(UUID::toString).reversed());assertEquals(sorted,a);
    }
    @Test void snapshotSurvivesNewPostsAndEngagementChangesWithoutMissingIds() {
        var original=new HashSet<UUID>();for(int i=0;i<47;i++)original.add(post(author,Visibility.PUBLIC,i));
        var first=feed(null);UUID cursor=first.nextBefore();var seen=new HashSet<>(ids(first));
        UUID newPost=post(author,Visibility.PUBLIC,0);
        UUID actor=user();for(UUID id:original)service.react(id,actor,"❤️");
        when(clock.instant()).thenReturn(now.plusSeconds(60));
        while(cursor!=null){var p=feed(cursor);for(UUID id:ids(p))assertTrue(seen.add(id),"duplicate");cursor=p.nextBefore();}
        assertEquals(original,seen);assertFalse(seen.contains(newPost));var freshSeen=new HashSet<UUID>();UUID next=null;do{var page=feed(next);freshSeen.addAll(ids(page));next=page.nextBefore();}while(next!=null);assertTrue(freshSeen.contains(newPost));
    }
    @Test void replayingCursorIsStableAndDoesNotRecomputeEngagement() {
        for(int i=0;i<25;i++)post(author,Visibility.PUBLIC,i);
        var first=feed(null);var before=ids(feed(first.nextBefore()));
        UUID actor=user();service.react(before.getLast(),actor,"❤️");
        assertEquals(before,ids(feed(first.nextBefore())));
    }
    @Test void oldContentRemainsReachableAcrossBoundedWindows() {
        var small=new CommunityFeedRanking(access,policy,clock,20,100,900);
        Set<UUID> expected=new HashSet<>();for(int i=0;i<65;i++)expected.add(post(author,Visibility.PUBLIC,i*86400L));
        Set<UUID> seen=new HashSet<>();UUID cursor=null;int requests=0;
        do {var page=small.page(viewer,cursor,id->service.get(id,viewer));for(UUID id:ids(page))assertTrue(seen.add(id));cursor=page.nextBefore();assertTrue(++requests<10);}while(cursor!=null);
        assertEquals(expected,seen);assertEquals(4,requests);
    }
    @Test void cursorTamperingCrossViewerAndExpiryFailWithoutContent() {
        for(int i=0;i<21;i++)post(author,Visibility.PUBLIC,0);
        var first=feed(null);UUID cursor=first.nextBefore();assertNotNull(cursor);
        assertEquals(ErrorCode.COMMUNITY_FEED_CURSOR_INVALID,assertThrows(BusinessException.class,()->feed(UUID.randomUUID())).errorCode());
        assertThrows(BusinessException.class,()->service.feed(user(),Feed.FOR_YOU,null,cursor));
        when(clock.instant()).thenReturn(now.plusSeconds(901));assertThrows(BusinessException.class,()->feed(cursor));
    }
    @Test void evictionRequiresExplicitRefreshRatherThanSilentReranking() {
        for(int i=0;i<21;i++)post(author,Visibility.PUBLIC,0);
        var small=new CommunityFeedRanking(access,policy,clock,20,1,900);
        var first=small.page(viewer,null,id->service.get(id,viewer));small.page(viewer,null,id->service.get(id,viewer));
        assertThrows(BusinessException.class,()->small.page(viewer,first.nextBefore(),id->service.get(id,viewer)));
    }
    @Test void privacyFriendsFofAndGroupAreCheckedBeforeRanking() {
        UUID bridge=user(),x=user();friend(author,bridge);friend(bridge,viewer);
        UUID pub=post(author,Visibility.PUBLIC,0),fof=post(author,Visibility.FRIENDS_OF_FRIENDS,0),friends=post(author,Visibility.FRIENDS,0);
        UUID g=group(author,viewer),groupPost=service.create(author,new Create(UUID.randomUUID(),"Group private",Visibility.GROUP_ONLY,g,List.of())).id();
        db.update("UPDATE community_posts SET created_at=? WHERE id=?",Timestamp.from(now),groupPost);
        assertTrue(ids(feed(null)).containsAll(List.of(pub,fof,groupPost)));assertFalse(ids(feed(null)).contains(friends));
        assertFalse(ids(service.feed(x,Feed.FOR_YOU,null,null)).contains(fof));assertFalse(ids(service.feed(x,Feed.FOR_YOU,null,null)).contains(groupPost));
        db.update("UPDATE group_memberships SET status='LEFT',ended_at=now() WHERE group_id=? AND user_id=?",g,viewer);
        assertFalse(ids(feed(null)).contains(groupPost));
        db.update("INSERT INTO user_blocks(id,blocker_id,blocked_id) VALUES (?,?,?)",UUID.randomUUID(),viewer,bridge);assertFalse(ids(feed(null)).contains(fof));
    }
    @Test void deletedHiddenReportedRemovedAndBlockedAreRecheckedDuringTraversal() {
        Set<UUID> all=new HashSet<>();for(int i=0;i<30;i++)all.add(post(author,Visibility.PUBLIC,i));
        var first=feed(null);all.removeAll(ids(first));var tail=new ArrayList<>(all);assertEquals(10,tail.size());
        service.delete(tail.get(0),author);service.hide(tail.get(1),viewer);service.report(tail.get(2),viewer,ReportReason.SPAM);
        db.update("UPDATE community_posts SET moderation_status='REMOVED' WHERE id=?",tail.get(3));
        var second=feed(first.nextBefore());for(int i=0;i<4;i++)assertFalse(ids(second).contains(tail.get(i)));
        assertEquals(6,second.items().size());
        db.update("INSERT INTO user_blocks(id,blocker_id,blocked_id) VALUES (?,?,?)",UUID.randomUUID(),viewer,author);assertTrue(feed(first.nextBefore()).items().isEmpty());
    }
    @Test void mediaCannotBeHydratedAfterSnapshotMembershipLoss() {
        UUID g=group(author,viewer);
        for(int i=0;i<25;i++){UUID id=service.create(author,new Create(UUID.randomUUID(),"Private",Visibility.GROUP_ONLY,g,List.of())).id();db.update("UPDATE community_posts SET created_at=? WHERE id=?",Timestamp.from(now),id);}
        var first=feed(null);db.update("UPDATE group_memberships SET status='LEFT',ended_at=now() WHERE group_id=? AND user_id=?",g,viewer);
        assertTrue(feed(first.nextBefore()).items().isEmpty());assertFalse(access.canRead(first.items().getFirst().id(),viewer));
    }
    @Test void friendsAndProfileKeepChronologicalUuidCursors() {
        friend(viewer,author);UUID old=post(author,Visibility.PUBLIC,86400),fresh=post(author,Visibility.FRIENDS,0);post(user(),Visibility.PUBLIC,0);
        assertEquals(List.of(fresh,old),ids(service.feed(viewer,Feed.FRIENDS,null,null)));
        assertEquals(List.of(fresh,old),ids(service.feed(viewer,Feed.PROFILE,author,null)));
        assertEquals(List.of(old),ids(service.feed(viewer,Feed.FRIENDS,null,fresh)));
    }
    @Test void targetedRefreshPreservesOrderAndExcludesReportsOnlyFromDiscovery() {
        friend(viewer,author);UUID a=post(author,Visibility.PUBLIC,0),b=post(author,Visibility.FRIENDS,1);
        service.report(a,viewer,ReportReason.SPAM);
        assertEquals(List.of(b),ids(service.refreshFeed(viewer,new Refresh(Feed.FOR_YOU,null,List.of(a,b)))));
        assertEquals(List.of(b,a),ids(service.refreshFeed(viewer,new Refresh(Feed.FRIENDS,null,List.of(b,a)))));
        assertNotNull(service.get(a,viewer)); // report alone is not a global takedown
        db.update("INSERT INTO user_blocks(id,blocker_id,blocked_id) VALUES (?,?,?)",UUID.randomUUID(),viewer,author);
        assertTrue(service.refreshFeed(viewer,new Refresh(Feed.FOR_YOU,null,List.of(a,b))).items().isEmpty());
    }
    @Test void refreshCannotUseIdsToBypassAudienceOrFriendFilter() {
        UUID privatePost=post(author,Visibility.FRIENDS,0),pub=post(author,Visibility.PUBLIC,0);
        assertEquals(List.of(pub),ids(service.refreshFeed(viewer,new Refresh(Feed.FOR_YOU,null,List.of(privatePost,pub,pub)))));
        assertTrue(service.refreshFeed(viewer,new Refresh(Feed.FRIENDS,null,List.of(pub))).items().isEmpty());
        assertThrows(BusinessException.class,()->service.refreshFeed(viewer,new Refresh(Feed.PROFILE,null,List.of(pub))));
    }
    @Test void r9BulkHydrationMatchesCanonicalMediaCountsAndCurrentPermissions() {
        friend(author,viewer);UUID actor=user(),blocked=user();
        UUID pub=post(author,Visibility.PUBLIC,0),own=post(viewer,Visibility.PUBLIC,0),privateOther=post(user(),Visibility.FRIENDS,0);
        UUID g=group(author,viewer),gp=service.create(author,new Create(UUID.randomUUID(),"Group privacy",Visibility.GROUP_ONLY,g,List.of())).id();
        for(int order:List.of(1,0))db.update("INSERT INTO community_media(id,post_id,storage_key,content_type,file_name,file_size,sort_order) VALUES (?,?,?,'image/png',?,10,?)",UUID.randomUUID(),gp,"r9-private-"+UUID.randomUUID(),"qa"+order+".png",order);
        service.react(pub,viewer,"❤️");service.react(pub,actor,"👍");service.react(pub,blocked,"😂");
        service.addComment(pub,actor,new AddComment(UUID.randomUUID(),"visible"));service.addComment(pub,blocked,new AddComment(UUID.randomUUID(),"blocked"));
        db.update("INSERT INTO user_blocks(id,blocker_id,blocked_id) VALUES (?,?,?)",UUID.randomUUID(),viewer,blocked);
        var ids=List.of(gp,pub,own,gp,privateOther,UUID.randomUUID());
        assertEquals(List.of(service.get(gp,viewer),service.get(pub,viewer),service.get(own,viewer)),reader.read(ids,viewer));
        assertEquals(2,reader.read(List.of(pub),viewer).getFirst().reactionCount());
        assertEquals(1,reader.read(List.of(pub),viewer).getFirst().commentCount());
        db.update("UPDATE group_memberships SET role='ADMIN' WHERE group_id=? AND user_id=?",g,viewer);entities.clear();
        assertEquals(service.get(gp,viewer),reader.read(List.of(gp),viewer).getFirst());
        db.update("UPDATE groups SET status='ARCHIVED' WHERE id=?",g);entities.clear();
        assertEquals(service.get(gp,viewer),reader.read(List.of(gp),viewer).getFirst());
        assertFalse(reader.read(List.of(gp),viewer).getFirst().permissions().canInteract());
        db.update("UPDATE group_memberships SET status='LEFT',ended_at=now() WHERE group_id=? AND user_id=?",g,viewer);entities.clear();
        assertTrue(reader.read(List.of(gp),viewer).isEmpty());
    }
    @Test void r9BulkRecruitmentPreservesCanonicalLifecycleRequestsAndBlockedManagers() {
        var ids=List.of(recruit("OPEN"),recruit("CLOSED"),recruit("FILLED"),recruit("EXPIRED"),recruit("PAST"));
        assertEquals(ids.stream().map(id->service.get(id,viewer)).toList(),reader.read(ids,viewer));
        UUID open=ids.getFirst(),g=service.get(open,viewer).recruitment().groupId();
        db.update("INSERT INTO group_join_requests(id,group_id,user_id,status) VALUES (?,?,?,'PENDING')",UUID.randomUUID(),g,viewer);
        assertEquals(service.get(open,viewer),reader.read(List.of(open),viewer).getFirst());
        UUID admin=user();db.update("INSERT INTO group_memberships(id,group_id,user_id,role,status) VALUES (?,?,?,'ADMIN','ACTIVE')",UUID.randomUUID(),g,admin);
        db.update("INSERT INTO user_blocks(id,blocker_id,blocked_id) VALUES (?,?,?)",UUID.randomUUID(),viewer,admin);
        assertEquals(service.get(open,viewer),reader.read(List.of(open),viewer).getFirst());
        db.update("INSERT INTO group_memberships(id,group_id,user_id,role,status) VALUES (?,?,?,'MEMBER','ACTIVE')",UUID.randomUUID(),g,viewer);entities.clear();
        assertEquals(service.get(open,viewer),reader.read(List.of(open),viewer).getFirst());
        db.update("UPDATE groups SET status='ARCHIVED' WHERE id=?",g);entities.clear();
        assertEquals(service.get(open,viewer),reader.read(List.of(open),viewer).getFirst());
    }
    @Test void r9LargerBoundedFixtureKeepsQueryBudgetAndTraversesAllPosts() {
        db.update("INSERT INTO community_posts(id,author_id,caption,visibility,created_at) SELECT gen_random_uuid(),?,'R9 scale','PUBLIC',?::timestamptz-n*interval '1 second' FROM generate_series(1,1200) n",author,Timestamp.from(now));
        clearInvocations(db);long start=System.nanoTime();var first=feed(null);long firstMs=(System.nanoTime()-start)/1000000;
        long firstQueries=queryExecutions();assertTrue(firstQueries<=12,"N+1 at1200posts: "+firstQueries);
        var seen=new HashSet<>(ids(first));UUID next=first.nextBefore();int pages=1;
        while(next!=null){var page=feed(next);for(UUID id:ids(page))assertTrue(seen.add(id));next=page.nextBefore();pages++;assertTrue(pages<=60);}
        long totalMs=(System.nanoTime()-start)/1000000;
        assertEquals(1200,seen.size());assertEquals(60,pages);
        System.out.println("R9 SCALE posts=1200 firstPageQueries="+firstQueries+" firstPageMs="+firstMs+" pages="+pages+" traversalMs="+totalMs);
    }
    private long queryExecutions() {
        return mockingDetails(db).getInvocations().stream().filter(i->i.getMethod().getName().equals("query")
            && i.getMethod().getParameterCount()==3
            && i.getMethod().getParameterTypes()[0]==org.springframework.jdbc.core.PreparedStatementCreator.class).count();
    }
    @Test void r9BatchHydrationBudgetPreservesRankingAndAttributesLegacyCost() {
        for(int i=0;i<240;i++)post(author,Visibility.PUBLIC,i);
        clearInvocations(db);long[] hydration={0};long start=System.nanoTime();
        var baseline=ranking.page(viewer,null,id->{long before=queryExecutions();var value=service.get(id,viewer);hydration[0]+=queryExecutions()-before;return value;});
        long before=queryExecutions(),ms=(System.nanoTime()-start)/1000000;
        System.out.println("R9 BEFORE total="+before+" hydration="+hydration[0]+" candidateAndEligibility="+(before-hydration[0])+" elapsedMs="+ms);
        clearInvocations(db);start=System.nanoTime();var page=feed(null);long after=queryExecutions();ms=(System.nanoTime()-start)/1000000;
        System.out.println("R9 AFTER total="+after+" elapsedMs="+ms);
        assertEquals(baseline.items(),page.items());
        assertTrue(after<=12,"R9 bounded bulk hydration budget exceeded: "+after);
    }
    @Test void boundedSqlPlanAndCurrentDatasetLatencyAreObservable() {
        for(int i=0;i<240;i++)post(author,Visibility.PUBLIC,i);
        clearInvocations(db);
        long start=System.nanoTime();var page=feed(null);long ms=(System.nanoTime()-start)/1000000;
        long queries=mockingDetails(db).getInvocations().stream().filter(i->i.getMethod().getName().equals("query")
            && i.getMethod().getParameterCount()==3
            && i.getMethod().getParameterTypes()[0]==org.springframework.jdbc.core.PreparedStatementCreator.class).count();
        System.out.println("R8 actual JDBC query executions="+queries+"; elapsedMs="+ms);
        assertTrue(queries>0 && queries<=12,"Unexpected SQL query expansion: "+queries);
        assertEquals(20,page.items().size());assertNotNull(page.nextBefore());assertTrue(ms<5000,"R8 isolated page took "+ms+"ms");
        String plan=db.queryForObject("EXPLAIN (FORMAT JSON) SELECT id FROM community_posts WHERE deleted_at IS NULL AND moderation_status='ACTIVE' ORDER BY created_at DESC,id DESC LIMIT 201",String.class);
        assertNotNull(plan);assertTrue(plan.contains("Limit"));System.out.println("R8 first page240 fixtures elapsedMs="+ms+"; candidateLimit=201; JdbcTemplate query calls="+queries);
    }
}
