package com.wedo.backend.chat;

import static org.junit.jupiter.api.Assertions.*;

import com.wedo.backend.chat.dto.ChatRequests;
import com.wedo.backend.chat.dto.ChatResponses;
import com.wedo.backend.chat.service.ChatService;
import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.common.test.AbstractPostgresIntegrationTest;
import com.wedo.backend.group.entity.GroupEntity;
import com.wedo.backend.group.entity.GroupMembershipEntity;
import com.wedo.backend.group.entity.GroupMembershipStatus;
import com.wedo.backend.group.entity.GroupRole;
import com.wedo.backend.group.entity.GroupSettingsEntity;
import com.wedo.backend.group.entity.GroupStatus;
import com.wedo.backend.group.repository.GroupMembershipRepository;
import com.wedo.backend.group.repository.GroupRepository;
import com.wedo.backend.group.repository.GroupSettingsRepository;
import com.wedo.backend.media.storage.InMemoryObjectStorageService;
import com.wedo.backend.social.service.BlockService;
import com.wedo.backend.user.entity.UserEntity;
import com.wedo.backend.user.entity.UserStatus;
import com.wedo.backend.user.repository.UserRepository;
import java.time.Instant;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

class ChatServiceIntegrationTest extends AbstractPostgresIntegrationTest {
    @Autowired ChatService chat;
    @Autowired UserRepository users;
    @Autowired GroupRepository groups;
    @Autowired GroupMembershipRepository memberships;
    @Autowired GroupSettingsRepository settings;
    @Autowired BlockService blockService;
    @Autowired JdbcTemplate jdbc;
    @Autowired InMemoryObjectStorageService objectStorage;

    @Test
    void imageMessagePersistsOrderedAttachmentsAndPrivateVisibility() {
        Fixture f = fixture();
        UUID conversationId = chat.openGroup(f.groupId, f.owner).id();
        String first = chatImageKey(conversationId, f.member);
        String second = chatImageKey(conversationId, f.member);

        ChatResponses.Message image = chat.send(conversationId, f.member,
                new ChatRequests.SendMessage("  ", null, null, List.of(first, second)));

        assertEquals("IMAGE", image.type());
        assertEquals("", image.content());
        assertEquals(List.of(first, second), image.attachments().stream()
                .map(ChatResponses.MessageAttachment::storageKey).toList());
        assertEquals(List.of(0, 1), image.attachments().stream()
                .map(ChatResponses.MessageAttachment::sortOrder).toList());
        assertEquals(2, jdbc.queryForObject(
                "SELECT count(*) FROM message_attachments WHERE message_id=?", Integer.class, image.id()));
        assertDoesNotThrow(() -> chat.requireAttachmentReadable(first, f.owner));
        assertThrows(BusinessException.class, () -> chat.requireAttachmentReadable(first, f.outsider));

        String crossConversation = chatImageKey(UUID.randomUUID(), f.member);
        assertThrows(BusinessException.class, () -> chat.send(conversationId, f.member,
                new ChatRequests.SendMessage("caption", null, null, List.of(crossConversation))));
        assertEquals(1, jdbc.queryForObject("SELECT count(*) FROM messages WHERE conversation_id=?",
                Integer.class, conversationId));
    }

    @Test
    void imagePresignPermissionRevocationIsRecheckedAtMessageCreation() {
        Fixture f = fixture();
        UUID conversationId = chat.openGroup(f.groupId, f.owner).id();
        String key = chatImageKey(conversationId, f.member);
        assertTrue(chat.canSendInConversation(conversationId, f.member));
        var membership = memberships.findFirstByGroupIdAndUserIdAndStatus(
                f.groupId, f.member, GroupMembershipStatus.ACTIVE).orElseThrow();
        membership.endAsLeft(Instant.now());
        memberships.save(membership);
        assertFalse(chat.canSendInConversation(conversationId, f.member));
        assertThrows(BusinessException.class, () -> chat.send(conversationId, f.member,
                new ChatRequests.SendMessage(null, null, null, List.of(key))));
        assertEquals(0, jdbc.queryForObject("SELECT count(*) FROM messages WHERE conversation_id=?",
                Integer.class, conversationId));
    }

    private String chatImageKey(UUID conversationId, UUID uploaderId) {
        String key = "chat/" + conversationId + "/" + uploaderId + "/" + UUID.randomUUID();
        objectStorage.putForTest(key, "image/jpeg", 128);
        return key;
    }

    @Test
    void groupChatUsesOneConversationAndEnforcesMembershipAndLifecycle() {
        Fixture f=fixture();
        ChatResponses.Conversation opened=chat.openGroup(f.groupId,f.owner);
        assertEquals(opened.id(),chat.openGroup(f.groupId,f.member).id());
        ChatResponses.Message sent=chat.send(opened.id(),f.member,new ChatRequests.SendMessage("Xin chào",null));
        assertEquals(1,sent.sequence());
        assertEquals("MEMBER",sent.author().displayName());
        assertTrue(sent.permissions().canEdit());
        ChatResponses.Message ownerMessage=chat.send(opened.id(),f.owner,new ChatRequests.SendMessage("Pin được",null));
        assertTrue(ownerMessage.permissions().canPin());
        chat.pin(ownerMessage.id(),f.owner,true);
        assertEquals(1,chat.pins(opened.id(),f.member).size());
        assertThrows(BusinessException.class,()->chat.pin(sent.id(),f.member,true));
        ChatResponses.Message reacted=chat.react(sent.id(),f.owner,new ChatRequests.Reaction("👍"));
        assertEquals("👍",reacted.myReaction());
        assertEquals(1,reacted.reactions().get(0).count());
        assertEquals(ErrorCode.VALIDATION_FAILED,assertThrows(BusinessException.class,
                ()->chat.react(sent.id(),f.owner,new ChatRequests.Reaction("🔥"))).errorCode());
        chat.react(sent.id(),f.owner,new ChatRequests.Reaction("👍"));
        assertTrue(chat.history(opened.id(),f.owner,null,30).messages().stream()
                .filter(m->m.id().equals(sent.id())).findFirst().orElseThrow().reactions().isEmpty());
        ChatResponses.MessagePage history=chat.history(opened.id(),f.owner,null,30);
        assertEquals(2,history.messages().size());
        chat.read(opened.id(),f.owner,1);
        assertEquals(0,chat.list(f.owner).stream().filter(c->c.id().equals(opened.id())).findFirst().orElseThrow().unreadCount());
        assertEquals(ErrorCode.GROUP_NOT_FOUND,assertThrows(BusinessException.class,()->chat.history(opened.id(),f.outsider,null,30)).errorCode());
        f.group.archive(Instant.now()); groups.save(f.group);
        assertThrows(BusinessException.class,()->chat.send(opened.id(),f.member,new ChatRequests.SendMessage("blocked",null)));
        assertEquals(2,chat.history(opened.id(),f.member,null,30).messages().size());
    }

    @Test
    void conversationListMaterializesEmptyGroupsOnceAndFiltersMembershipLifecycle() {
        Fixture f=fixture();
        assertEquals(0,jdbc.queryForObject("SELECT count(*) FROM group_conversations WHERE group_id=?",Integer.class,f.groupId));
        ChatResponses.Conversation listed=chat.list(f.owner).stream()
                .filter(c->f.groupId.equals(c.groupId())).findFirst().orElseThrow();
        assertNull(listed.lastMessagePreview());
        assertEquals("Chat test",listed.title());
        assertEquals(listed.id(),chat.openGroup(f.groupId,f.owner).id());
        assertEquals(listed.id(),chat.list(f.member).stream()
                .filter(c->f.groupId.equals(c.groupId())).findFirst().orElseThrow().id());
        assertEquals(1,jdbc.queryForObject("SELECT count(*) FROM group_conversations WHERE group_id=?",Integer.class,f.groupId));
        assertTrue(chat.list(f.outsider).stream().noneMatch(c->f.groupId.equals(c.groupId())));

        f.group.archive(Instant.now());
        groups.save(f.group);
        ChatResponses.Conversation archived=chat.list(f.owner).stream()
                .filter(c->f.groupId.equals(c.groupId())).findFirst().orElseThrow();
        assertTrue(archived.permissions().readOnly());

        var endedMembership=memberships.findFirstByGroupIdAndUserIdAndStatus(f.groupId,f.member,GroupMembershipStatus.ACTIVE)
                .orElseThrow();
        endedMembership.endAsLeft(Instant.now());
        memberships.save(endedMembership);
        UUID banned=UUID.randomUUID();
        saveUser(banned,"BANNED",UUID.randomUUID(),Instant.now());
        memberships.save(new GroupMembershipEntity(UUID.randomUUID(),f.groupId,banned,GroupRole.MEMBER,
                GroupMembershipStatus.BANNED,Instant.now(),Instant.now()));
        assertTrue(chat.list(f.member).stream().noneMatch(c->f.groupId.equals(c.groupId())));
        assertTrue(chat.list(banned).stream().noneMatch(c->f.groupId.equals(c.groupId())));
    }

    @Test
    void concurrentListAndOpenConvergeOnOneGroupConversation() throws Exception {
        Fixture f=fixture();
        var executor=Executors.newFixedThreadPool(6);
        var ready=new CountDownLatch(6);
        var start=new CountDownLatch(1);
        try {
            var calls=java.util.stream.IntStream.range(0,6).mapToObj(i->executor.submit(()->{
                ready.countDown();
                start.await();
                return i%2==0 ? chat.list(f.owner).stream().filter(c->f.groupId.equals(c.groupId()))
                        .findFirst().orElseThrow().id() : chat.openGroup(f.groupId,f.owner).id();
            })).toList();
            ready.await();
            start.countDown();
            UUID expected=calls.get(0).get();
            for(var call:calls) assertEquals(expected,call.get());
            assertEquals(1,jdbc.queryForObject("SELECT count(*) FROM group_conversations WHERE group_id=?",Integer.class,f.groupId));
        } finally {
            executor.shutdownNow();
        }
    }

    @Test
    void historyProjectsReaderSequencesOnlyForItsConversation() {
        Fixture f=fixture();
        UUID conversation=chat.openGroup(f.groupId,f.owner).id();
        ChatResponses.Message message=chat.send(conversation,f.member,new ChatRequests.SendMessage("Read me",null));
        chat.read(conversation,f.owner,message.sequence());
        ChatResponses.MessagePage page=chat.history(conversation,f.member,null,30);
        assertEquals(1,page.readers().size());
        assertEquals(f.owner,page.readers().get(0).userId());
        assertEquals(message.sequence(),page.readers().get(0).lastReadSequence());

        Fixture other=fixture();
        UUID otherConversation=chat.openGroup(other.groupId,other.owner).id();
        assertTrue(chat.history(otherConversation,other.member,null,30).readers().isEmpty());
    }

    @Test
    void directStrangerUsesRequestLimitAndAcceptOpensRestMessaging() {
        Fixture f=fixture();
        ChatResponses.DirectOpen direct=chat.openDirect(f.owner,f.outsider);
        assertEquals("REQUEST_PENDING",direct.accessStatus());
        String imageKey = chatImageKey(direct.conversation().id(), f.owner);
        assertTrue(chat.canSendInConversation(direct.conversation().id(), f.owner));
        assertFalse(chat.canSendImageInConversation(direct.conversation().id(), f.owner));
        assertThrows(BusinessException.class, () -> chat.send(direct.conversation().id(), f.owner,
                new ChatRequests.SendMessage("caption", null, null, List.of(imageKey))));
        for(int i=0;i<3;i++) chat.send(direct.conversation().id(),f.owner,new ChatRequests.SendMessage("hello "+i,null));
        assertThrows(BusinessException.class,()->chat.send(direct.conversation().id(),f.owner,new ChatRequests.SendMessage("fourth",null)));
        assertTrue(chat.requests(f.outsider).size()>0);
        UUID request=chat.requests(f.outsider).get(0).id();
        chat.resolveRequest(request,f.outsider,true);
        assertEquals("OPEN",chat.openDirect(f.owner,f.outsider).accessStatus());
        assertTrue(chat.canSendImageInConversation(direct.conversation().id(), f.owner));
        assertEquals(4,chat.send(direct.conversation().id(),f.outsider,new ChatRequests.SendMessage("accepted",null)).sequence());
    }

    @Test
    void messageEditUnsendAndDeleteForMeRespectOwnershipAndHistory() {
        Fixture f=fixture();
        UUID conversation=chat.openGroup(f.groupId,f.owner).id();
        ChatResponses.Message message=chat.send(conversation,f.owner,new ChatRequests.SendMessage("original",null));
        assertThrows(BusinessException.class,()->chat.edit(message.id(),f.member,new ChatRequests.EditMessage("wrong author")));
        ChatResponses.Message edited=chat.edit(message.id(),f.owner,new ChatRequests.EditMessage("updated"));
        assertEquals("updated",edited.content());
        chat.react(message.id(),f.owner,new ChatRequests.Reaction("😂"));
        chat.react(message.id(),f.member,new ChatRequests.Reaction("❤️"));
        assertEquals(2,chat.history(conversation,f.owner,null,30).messages().get(0).reactions().size());
        chat.deleteForMe(message.id(),f.member);
        assertTrue(chat.history(conversation,f.member,null,30).messages().isEmpty());
        assertEquals(1,chat.history(conversation,f.owner,null,30).messages().size());
        ChatResponses.Message withdrawn=chat.unsend(message.id(),f.owner);
        assertEquals("UNSENT",withdrawn.status());
        assertNull(withdrawn.content());
        assertNull(withdrawn.myReaction());
        assertTrue(withdrawn.reactions().isEmpty());
        assertFalse(withdrawn.permissions().canReact());
        ChatResponses.Message reloaded=chat.history(conversation,f.owner,null,30).messages().get(0);
        assertNull(reloaded.content());
        assertTrue(reloaded.reactions().isEmpty());
        assertThrows(BusinessException.class,()->chat.react(message.id(),f.member,new ChatRequests.Reaction("😂")));

        ChatResponses.Message old=chat.send(conversation,f.owner,new ChatRequests.SendMessage("too late",null));
        jdbc.update("UPDATE messages SET created_at=now()-interval '16 minutes' WHERE id=?",old.id());
        assertThrows(BusinessException.class,()->chat.edit(old.id(),f.owner,new ChatRequests.EditMessage("late edit")));
        assertThrows(BusinessException.class,()->chat.unsend(old.id(),f.owner));
    }

    @Test
    void declineCooldownAndBlockCancelDirectRequestAccess() {
        Fixture f=fixture();
        ChatResponses.DirectOpen opened=chat.openDirect(f.owner,f.outsider);
        UUID request=chat.requests(f.outsider).get(0).id();
        chat.resolveRequest(request,f.outsider,false);
        assertThrows(BusinessException.class,()->chat.openDirect(f.owner,f.outsider));

        ChatResponses.DirectOpen second=chat.openDirect(f.owner,f.member);
        UUID pending=chat.requests(f.member).get(0).id();
        blockService.blockUser(f.owner,f.member);
        String status=jdbc.queryForObject("SELECT status FROM message_requests WHERE id=?",String.class,pending);
        assertEquals("CANCELLED",status);
        assertThrows(BusinessException.class,()->chat.history(second.conversation().id(),f.owner,null,30));
    }

    @Test
    void reactionDetailsProjectPublicProfilesAndAggregateOneReactionPerUser() {
        Fixture f=fixture();
        UUID conversation=chat.openGroup(f.groupId,f.owner).id();
        var message=chat.send(conversation,f.owner,new ChatRequests.SendMessage("Reactions",null));
        jdbc.update("UPDATE users SET avatar_storage_key='avatars/reactor.png' WHERE id=?",f.member);
        chat.react(message.id(),f.owner,new ChatRequests.Reaction("❤️"));
        chat.react(message.id(),f.member,new ChatRequests.Reaction("❤️"));
        for(int i=0;i<3;i++) {
            UUID id=UUID.randomUUID();
            saveUser(id,"REACTOR",UUID.randomUUID(),Instant.now());
            memberships.save(new GroupMembershipEntity(UUID.randomUUID(),f.groupId,id,GroupRole.MEMBER,
                    GroupMembershipStatus.ACTIVE,Instant.now(),null));
            chat.react(message.id(),id,new ChatRequests.Reaction("❤️"));
        }
        var aggregate=chat.history(conversation,f.owner,null,30).messages().get(0);
        assertEquals(1,aggregate.reactions().size());
        assertEquals(5,aggregate.reactions().get(0).count());
        assertEquals("❤️",aggregate.myReaction());
        var details=chat.reactionDetails(message.id(),f.owner);
        assertEquals(5,details.size());
        assertEquals(5,details.stream().map(d->d.user().id()).distinct().count());
        assertTrue(details.stream().allMatch(d->d.emoji().equals("❤️")));
        var member=details.stream().filter(d->d.user().id().equals(f.member)).findFirst().orElseThrow();
        assertEquals("MEMBER",member.user().displayName());
        assertEquals("/api/v1/media/avatars/reactor.png",member.user().avatarUrl());
        assertTrue(details.stream().anyMatch(d->d.user().id().equals(f.owner)));
        chat.react(message.id(),f.member,new ChatRequests.Reaction("😂"));
        aggregate=chat.history(conversation,f.owner,null,30).messages().get(0);
        assertEquals(2,aggregate.reactions().size());
        assertEquals(5,aggregate.reactions().stream().mapToLong(ChatResponses.Reaction::count).sum());
        assertEquals(1,chat.reactionDetails(message.id(),f.owner).stream().filter(d->d.emoji().equals("😂")).count());
    }

    @Test
    void reactionDetailsEnforceGroupVisibilityHiddenHistoryAndWithdrawnState() {
        Fixture f=fixture();
        UUID conversation=chat.openGroup(f.groupId,f.owner).id();
        var message=chat.send(conversation,f.owner,new ChatRequests.SendMessage("Private",null));
        chat.react(message.id(),f.owner,new ChatRequests.Reaction("👍"));
        assertThrows(BusinessException.class,()->chat.reactionDetails(message.id(),f.outsider));
        Fixture other=fixture();
        chat.openGroup(other.groupId,other.owner);
        assertThrows(BusinessException.class,()->chat.reactionDetails(message.id(),other.owner));

        jdbc.update("UPDATE group_settings SET chat_history_policy='FROM_JOIN_TIME' WHERE group_id=?",f.groupId);
        jdbc.update("UPDATE messages SET created_at=now()-interval '1 minute' WHERE id=?",message.id());
        assertEquals(ErrorCode.RESOURCE_NOT_FOUND,assertThrows(BusinessException.class,
                ()->chat.reactionDetails(message.id(),f.member)).errorCode());
        jdbc.update("UPDATE group_settings SET chat_history_policy='FULL_HISTORY' WHERE group_id=?",f.groupId);
        chat.deleteForMe(message.id(),f.member);
        assertEquals(ErrorCode.RESOURCE_NOT_FOUND,assertThrows(BusinessException.class,
                ()->chat.reactionDetails(message.id(),f.member)).errorCode());
        f.group.archive(Instant.now()); groups.save(f.group);
        assertEquals(1,chat.reactionDetails(message.id(),f.owner).size());
        jdbc.update("UPDATE groups SET status='ACTIVE' WHERE id=?",f.groupId);
        for(String status:java.util.List.of("LEFT","BANNED")) {
            jdbc.update("UPDATE group_memberships SET status=?,ended_at=now() WHERE group_id=? AND user_id=?",status,f.groupId,f.member);
            assertThrows(BusinessException.class,()->chat.reactionDetails(message.id(),f.member));
        }
        chat.unsend(message.id(),f.owner);
        assertTrue(chat.reactionDetails(message.id(),f.owner).isEmpty());
        assertThrows(BusinessException.class,()->chat.react(message.id(),f.owner,new ChatRequests.Reaction("👍")));
    }

    @Test
    void reactionDetailsDenyDirectOutsidersAndBlockedParticipants() {
        Fixture f=fixture();
        UUID conversation=chat.openDirect(f.owner,f.member).conversation().id();
        var message=chat.send(conversation,f.owner,new ChatRequests.SendMessage("Direct",null));
        chat.react(message.id(),f.owner,new ChatRequests.Reaction("👍"));
        assertEquals(1,chat.reactionDetails(message.id(),f.member).size());
        assertEquals(ErrorCode.RESOURCE_NOT_FOUND,assertThrows(BusinessException.class,
                ()->chat.reactionDetails(message.id(),f.outsider)).errorCode());
        blockService.blockUser(f.member,f.owner);
        assertThrows(BusinessException.class,()->chat.reactionDetails(message.id(),f.owner));
        assertThrows(BusinessException.class,()->chat.reactionDetails(message.id(),f.member));
    }

    private Fixture fixture() {
        UUID suffix=UUID.randomUUID(),owner=UUID.randomUUID(),member=UUID.randomUUID(),outsider=UUID.randomUUID();
        Instant now=Instant.now();
        saveUser(owner,"OWNER",suffix,now); saveUser(member,"MEMBER",suffix,now); saveUser(outsider,"OUTSIDER",suffix,now);
        UUID groupId=UUID.randomUUID();
        GroupEntity group=groups.save(new GroupEntity(groupId,"Chat test",null,null,GroupStatus.ACTIVE,owner,now,now));
        memberships.save(new GroupMembershipEntity(UUID.randomUUID(),groupId,owner,GroupRole.OWNER,GroupMembershipStatus.ACTIVE,now,null));
        memberships.save(new GroupMembershipEntity(UUID.randomUUID(),groupId,member,GroupRole.MEMBER,GroupMembershipStatus.ACTIVE,now,null));
        settings.save(GroupSettingsEntity.createDefault(groupId,now));
        return new Fixture(groupId,owner,member,outsider,group);
    }

    private void saveUser(UUID id,String name,UUID suffix,Instant now) {
        users.save(new UserEntity(id,name.toLowerCase()+"+"+suffix+"@chat.test",name.toLowerCase()+suffix.toString().substring(0,8),name,UserStatus.ACTIVE,now,now));
    }

    private record Fixture(UUID groupId,UUID owner,UUID member,UUID outsider,GroupEntity group) { }
}
