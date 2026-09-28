package com.wedo.backend.chat.service;

import com.wedo.backend.chat.dto.ChatRequests;
import com.wedo.backend.chat.dto.ChatResponses;
import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.group.entity.ChatHistoryPolicy;
import com.wedo.backend.group.entity.GroupMembershipEntity;
import com.wedo.backend.group.entity.GroupMembershipStatus;
import com.wedo.backend.group.entity.GroupRole;
import com.wedo.backend.group.entity.GroupStatus;
import com.wedo.backend.group.repository.GroupMembershipRepository;
import com.wedo.backend.group.repository.GroupRepository;
import com.wedo.backend.group.repository.GroupSettingsRepository;
import com.wedo.backend.social.repository.FriendshipRepository;
import com.wedo.backend.social.repository.UserBlockRepository;
import com.wedo.backend.user.entity.DmPolicy;
import com.wedo.backend.user.repository.UserPrivacySettingsRepository;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional
public class ChatService {
    private static final Duration MESSAGE_WINDOW = Duration.ofMinutes(15);
    private static final Duration REQUEST_COOLDOWN = Duration.ofHours(72);
    private static final java.util.Set<String> SUPPORTED_REACTIONS = java.util.Set.of("👍", "❤️", "😂", "😮", "😢", "😡");
    private final JdbcTemplate jdbc;
    private final GroupMembershipRepository memberships;
    private final GroupRepository groups;
    private final GroupSettingsRepository settings;
    private final FriendshipRepository friendships;
    private final UserBlockRepository blocks;
    private final UserPrivacySettingsRepository privacy;
    private final org.springframework.context.ApplicationEventPublisher events;

    public ChatService(JdbcTemplate jdbc, GroupMembershipRepository memberships,
                       GroupRepository groups, GroupSettingsRepository settings,
                       FriendshipRepository friendships, UserBlockRepository blocks,
                       UserPrivacySettingsRepository privacy) {
        this(jdbc, memberships, groups, settings, friendships, blocks, privacy, event -> { });
    }

    @org.springframework.beans.factory.annotation.Autowired
    public ChatService(JdbcTemplate jdbc, GroupMembershipRepository memberships,
                       GroupRepository groups, GroupSettingsRepository settings,
                       FriendshipRepository friendships, UserBlockRepository blocks,
                       UserPrivacySettingsRepository privacy,
                       org.springframework.context.ApplicationEventPublisher events) {
        this.jdbc = jdbc;
        this.memberships = memberships;
        this.groups = groups;
        this.settings = settings;
        this.friendships = friendships;
        this.blocks = blocks;
        this.privacy = privacy;
        this.events = events;
    }

    public List<ChatResponses.Conversation> list(UUID userId) {
        List<UUID> groupIds = jdbc.query("""
                SELECT gm.group_id FROM group_memberships gm JOIN groups g ON g.id=gm.group_id
                WHERE gm.user_id=? AND gm.status='ACTIVE' AND g.status IN ('ACTIVE','ARCHIVED')
                ORDER BY gm.created_at,gm.group_id
                """, (rs,n)->rs.getObject(1,UUID.class), userId);
        groupIds.forEach(this::ensureGroupConversation);
        return jdbc.query("""
                SELECT c.id, c.type, gc.group_id, g.name AS title,g.avatar_storage_key,
                       dc.user_id_1, dc.user_id_2,
                       COALESCE(s.current_sequence,0) AS last_sequence,
                       (SELECT CASE WHEN m.status='UNSENT' THEN 'Tin nhắn đã được thu hồi' ELSE m.content END FROM messages m WHERE m.conversation_id=c.id ORDER BY m.sequence DESC LIMIT 1) AS preview,
                       (SELECT m.created_at FROM messages m WHERE m.conversation_id=c.id ORDER BY m.sequence DESC LIMIT 1) AS last_at,
                       COALESCE(rs.last_read_sequence,0) AS last_read
                FROM conversations c
                LEFT JOIN group_conversations gc ON gc.conversation_id=c.id
                LEFT JOIN groups g ON g.id=gc.group_id
                LEFT JOIN direct_conversations dc ON dc.conversation_id=c.id
                LEFT JOIN conversation_sequences s ON s.conversation_id=c.id
                LEFT JOIN conversation_read_states rs ON rs.conversation_id=c.id AND rs.user_id=?
                WHERE (c.type='GROUP' AND g.status IN ('ACTIVE','ARCHIVED') AND EXISTS(SELECT 1 FROM group_memberships gm WHERE gm.group_id=gc.group_id AND gm.user_id=? AND gm.status='ACTIVE'))
                   OR (c.type='DIRECT' AND (dc.user_id_1=? OR dc.user_id_2=?)
                       AND NOT EXISTS(SELECT 1 FROM user_blocks ub WHERE
                         (ub.blocker_id=dc.user_id_1 AND ub.blocked_id=dc.user_id_2)
                         OR (ub.blocker_id=dc.user_id_2 AND ub.blocked_id=dc.user_id_1)))
                ORDER BY last_at DESC NULLS LAST, c.created_at DESC
                """, (rs, n) -> conversation(rs, userId), userId, userId, userId, userId);
    }

    public ChatResponses.Conversation openGroup(UUID groupId, UUID userId) {
        var group = groups.findById(groupId).orElseThrow(() -> new BusinessException(ErrorCode.GROUP_NOT_FOUND));
        if (group.getStatus() == GroupStatus.DELETED) throw new BusinessException(ErrorCode.GROUP_DELETED);
        membership(groupId, userId);
        UUID conversationId = ensureGroupConversation(groupId);
        return getConversation(conversationId, userId);
    }

    private UUID ensureGroupConversation(UUID groupId) {
        UUID existing = jdbc.query("SELECT conversation_id FROM group_conversations WHERE group_id=?",
                rs -> rs.next() ? rs.getObject(1,UUID.class) : null, groupId);
        if (existing == null) {
            UUID candidate = UUID.randomUUID();
            jdbc.update("INSERT INTO conversations(id,type) VALUES (?,'GROUP')", candidate);
            int inserted = jdbc.update("INSERT INTO group_conversations(conversation_id,group_id) VALUES (?,?) ON CONFLICT(group_id) DO NOTHING", candidate, groupId);
            if (inserted == 0) jdbc.update("DELETE FROM conversations WHERE id=?", candidate);
            existing = jdbc.queryForObject("SELECT conversation_id FROM group_conversations WHERE group_id=?", UUID.class, groupId);
        }
        jdbc.update("INSERT INTO conversation_sequences(conversation_id) VALUES (?) ON CONFLICT DO NOTHING", existing);
        return existing;
    }

    public ChatResponses.DirectOpen openDirect(UUID userId, UUID peerId) {
        if (userId.equals(peerId)) throw new BusinessException(ErrorCode.VALIDATION_FAILED, "Cannot message yourself.");
        Map<String, Object> target = one("SELECT id,status FROM users WHERE id=?", peerId);
        if (!"ACTIVE".equals(target.get("status"))) throw new BusinessException(ErrorCode.RESOURCE_NOT_FOUND);
        if (blocks.existsBlockBetween(userId, peerId)) throw new BusinessException(ErrorCode.USER_BLOCKED);
        boolean friend = friendships.existsActiveBetween(userId, peerId);
        DmPolicy policy = privacy.findById(peerId).map(p -> p.getDmPolicy()).orElse(DmPolicy.EVERYONE);
        boolean mutualGroup = Boolean.TRUE.equals(jdbc.queryForObject("""
                SELECT EXISTS(SELECT 1 FROM group_memberships a JOIN group_memberships b ON a.group_id=b.group_id
                    JOIN groups g ON g.id=a.group_id WHERE a.user_id=? AND b.user_id=? AND a.status='ACTIVE'
                    AND b.status='ACTIVE' AND g.status='ACTIVE')
                """, Boolean.class, userId, peerId));
        if (!friend && (policy == DmPolicy.FRIENDS_ONLY || (policy == DmPolicy.MUTUAL_GROUPS && !mutualGroup)))
            throw new BusinessException(ErrorCode.ACCESS_DENIED);
        UUID low = jdbc.queryForObject("SELECT LEAST(?::uuid,?::uuid)",UUID.class,userId,peerId);
        UUID high = jdbc.queryForObject("SELECT GREATEST(?::uuid,?::uuid)",UUID.class,userId,peerId);
        UUID existing = jdbc.query("SELECT conversation_id FROM direct_conversations WHERE user_id_1=? AND user_id_2=?",
                rs -> rs.next() ? rs.getObject(1, UUID.class) : null, low, high);
        if (existing == null) existing = createDirect(low, high);
        String access = friend ? "OPEN" : requestStatus(existing, userId);
        boolean accepted = Boolean.TRUE.equals(jdbc.queryForObject(
                "SELECT EXISTS(SELECT 1 FROM message_requests WHERE conversation_id=? AND status='ACCEPTED')",
                Boolean.class, existing));
        if (!friend && !accepted && !"REQUEST_PENDING".equals(access) && !"REQUEST_RECEIVED".equals(access)) {
            Instant declinedAt = jdbc.query("SELECT updated_at FROM message_requests WHERE conversation_id=? AND sender_id=? AND status='DECLINED' ORDER BY updated_at DESC LIMIT 1",
                    rs -> rs.next() ? rs.getTimestamp(1).toInstant() : null, existing, userId);
            if (declinedAt != null && Instant.now().isBefore(declinedAt.plus(REQUEST_COOLDOWN)))
                throw new BusinessException(ErrorCode.ACCESS_DENIED, "Message request cooldown is active.");
            UUID requestId = UUID.randomUUID();
            jdbc.update("INSERT INTO message_requests(id,conversation_id,sender_id,receiver_id) VALUES (?,?,?,?) ON CONFLICT DO NOTHING",
                    requestId, existing, userId, peerId);
            access = requestStatus(existing, userId);
        }
        return new ChatResponses.DirectOpen(getConversation(existing, userId), access);
    }

    @Transactional(readOnly = true)
    public List<ChatResponses.MessageRequest> requests(UUID userId) {
        return jdbc.query("""
                SELECT mr.id,mr.conversation_id,mr.sender_id,mr.receiver_id,mr.status,mr.created_at,
                       (SELECT count(*) FROM messages m WHERE m.conversation_id=mr.conversation_id AND m.sender_id=mr.sender_id) AS message_count
                FROM message_requests mr WHERE mr.receiver_id=? AND mr.status='PENDING' ORDER BY mr.created_at DESC
                """, (rs,n) -> new ChatResponses.MessageRequest(rs.getObject("id",UUID.class),
                rs.getObject("conversation_id",UUID.class), user(rs.getObject("sender_id",UUID.class)),
                user(rs.getObject("receiver_id",UUID.class)), rs.getString("status"), rs.getTimestamp("created_at").toInstant(),
                rs.getLong("message_count")), userId);
    }

    public void resolveRequest(UUID requestId, UUID userId, boolean accept) {
        Map<String,Object> req = one("SELECT receiver_id,status FROM message_requests WHERE id=?", requestId);
        if (!userId.equals(req.get("receiver_id"))) throw new BusinessException(ErrorCode.RESOURCE_NOT_FOUND);
        if (!"PENDING".equals(req.get("status"))) throw new BusinessException(ErrorCode.CONFLICT);
        jdbc.update("UPDATE message_requests SET status=?,resolved_at=now(),updated_at=now() WHERE id=?",
                accept ? "ACCEPTED" : "DECLINED", requestId);
    }

    @Transactional(readOnly = true)
    public ChatResponses.MessagePage history(UUID conversationId, UUID userId, Long before, int limit) {
        Access access = access(conversationId,userId,false);
        int size = Math.max(1, Math.min(limit, 100));
        String joinCutoff = access.groupId == null || access.historyPolicy == ChatHistoryPolicy.FULL_HISTORY
                ? "" : " AND m.created_at >= (SELECT gm.created_at FROM group_memberships gm WHERE gm.group_id=? AND gm.user_id=? AND gm.status='ACTIVE' ORDER BY gm.created_at DESC LIMIT 1)";
        String sql = """
                SELECT m.id,m.conversation_id,m.sequence,m.sender_id,u.display_name,u.avatar_storage_key,
                       m.content,m.status,m.reply_to_message_id,m.created_at,m.edited_at,m.unsent_at
                FROM messages m LEFT JOIN users u ON u.id=m.sender_id
                WHERE m.conversation_id=? AND (?::bigint IS NULL OR m.sequence < ?)
                  AND NOT EXISTS(SELECT 1 FROM message_hidden_users h WHERE h.message_id=m.id AND h.user_id=?)
                """ + joinCutoff + " ORDER BY m.sequence DESC LIMIT ?";
        List<Object> args = new java.util.ArrayList<>(java.util.Arrays.asList(conversationId,before,before,userId));
        if (!joinCutoff.isEmpty()) { args.add(access.groupId); args.add(userId); }
        args.add(size + 1);
        List<MessageRow> rows = jdbc.query(sql, this::messageRow, args.toArray());
        boolean more = rows.size() > size;
        if (more) rows = rows.subList(0,size);
        java.util.Collections.reverse(rows);
        Long next = more && !rows.isEmpty() ? rows.get(0).sequence() : null;
        return new ChatResponses.MessagePage(conversationId, toMessages(rows,userId,access), next, more,
                readerStates(conversationId,userId,access));
    }

    private List<ChatResponses.ReaderState> readerStates(UUID conversationId, UUID userId, Access access) {
        String participants = access.groupId != null
                ? "JOIN group_conversations gc ON gc.conversation_id=rs.conversation_id JOIN group_memberships gm ON gm.group_id=gc.group_id AND gm.user_id=rs.user_id AND gm.status='ACTIVE' WHERE rs.conversation_id=? AND rs.user_id<>? AND rs.last_read_sequence>0"
                : "JOIN direct_conversations dc ON dc.conversation_id=rs.conversation_id WHERE rs.conversation_id=? AND rs.user_id<>? AND rs.last_read_sequence>0 AND rs.user_id IN (dc.user_id_1,dc.user_id_2)";
        return jdbc.query("SELECT u.id,u.display_name,u.avatar_storage_key,rs.last_read_sequence FROM conversation_read_states rs JOIN users u ON u.id=rs.user_id "+participants+" ORDER BY rs.last_read_sequence DESC, u.id",
                (rs,n)->new ChatResponses.ReaderState(rs.getObject("id",UUID.class),
                        rs.getString("display_name"),rs.getString("avatar_storage_key"),rs.getLong("last_read_sequence")),
                conversationId,userId);
    }

    public ChatResponses.Message send(UUID conversationId, UUID userId, ChatRequests.SendMessage request) {
        Access access = access(conversationId,userId,true);
        ensureSendAllowed(access,userId);
        String content = request.content().trim();
        if (content.isEmpty()) throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        if (access.type.equals("DIRECT") && "REQUEST_PENDING".equals(access.accessStatus)) {
            long sent = jdbc.queryForObject("SELECT count(*) FROM messages WHERE conversation_id=? AND sender_id=? AND status='ACTIVE'",Long.class,conversationId,userId);
            if (sent >= 3) throw new BusinessException(ErrorCode.ACCESS_DENIED);
        }
        if (request.replyToMessageId()!=null) {
            Integer valid = jdbc.queryForObject("SELECT count(*) FROM messages WHERE id=? AND conversation_id=?",Integer.class,request.replyToMessageId(),conversationId);
            if (valid == null || valid == 0) throw new BusinessException(ErrorCode.RESOURCE_NOT_FOUND);
        }
        Long sequence = jdbc.queryForObject("UPDATE conversation_sequences SET current_sequence=current_sequence+1,updated_at=now() WHERE conversation_id=? RETURNING current_sequence",Long.class,conversationId);
        UUID id=UUID.randomUUID();
        jdbc.update("INSERT INTO messages(id,conversation_id,sender_id,sequence,type,content,reply_to_message_id) VALUES (?,?,?,?,'TEXT',?,?)",
                id,conversationId,userId,sequence,content,request.replyToMessageId());
        jdbc.update("UPDATE conversations SET updated_at=now() WHERE id=?",conversationId);
        ChatResponses.Message created = messageById(id,userId);
        events.publishEvent(new com.wedo.backend.chat.realtime.ChatRealtimeEvents.DomainMutationEvent(
                UUID.randomUUID(), "MESSAGE_CREATED", conversationId, id, sequence, request.clientMessageId(), userId, Instant.now()));
        return created;
    }

    public ChatResponses.Message edit(UUID messageId, UUID userId, ChatRequests.EditMessage request) {
        Map<String,Object> row=one("SELECT conversation_id,sender_id,content,status,created_at FROM messages WHERE id=?",messageId);
        UUID conversationId = (UUID) row.get("conversation_id");
        Access access=access(conversationId,userId,true);
        if (!userId.equals(row.get("sender_id")) || !"ACTIVE".equals(row.get("status")) || Duration.between(toInstant(row.get("created_at")),Instant.now()).compareTo(MESSAGE_WINDOW)>=0)
            throw new BusinessException(ErrorCode.ACCESS_DENIED);
        String content=request.content().trim(); if(content.isEmpty()) throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        jdbc.update("INSERT INTO message_edit_history(id,message_id,previous_content,edited_by) VALUES (?,?,?,?)",UUID.randomUUID(),messageId,row.get("content"),userId);
        jdbc.update("UPDATE messages SET content=?,edited_at=now() WHERE id=?",content,messageId);
        ChatResponses.Message edited = messageById(messageId,userId);
        events.publishEvent(new com.wedo.backend.chat.realtime.ChatRealtimeEvents.DomainMutationEvent(
                UUID.randomUUID(), "MESSAGE_EDITED", conversationId, messageId, edited.sequence(), null, userId, Instant.now()));
        return edited;
    }

    public ChatResponses.Message unsend(UUID messageId, UUID userId) {
        Map<String,Object> row=one("SELECT conversation_id,sender_id,status,created_at FROM messages WHERE id=? FOR UPDATE",messageId);
        UUID conversationId = (UUID) row.get("conversation_id");
        access(conversationId,userId,true);
        if (!userId.equals(row.get("sender_id")) || !"ACTIVE".equals(row.get("status")) || Duration.between(toInstant(row.get("created_at")),Instant.now()).compareTo(MESSAGE_WINDOW)>=0)
            throw new BusinessException(ErrorCode.ACCESS_DENIED);
        jdbc.update("UPDATE messages SET status='UNSENT',content=NULL,unsent_at=now() WHERE id=?",messageId);
        jdbc.update("DELETE FROM message_pins WHERE message_id=?",messageId);
        jdbc.update("DELETE FROM message_reactions WHERE message_id=?",messageId);
        ChatResponses.Message withdrawn = messageById(messageId,userId);
        events.publishEvent(new com.wedo.backend.chat.realtime.ChatRealtimeEvents.DomainMutationEvent(
                UUID.randomUUID(), "MESSAGE_UNSENT", conversationId, messageId, withdrawn.sequence(), null, userId, Instant.now()));
        return withdrawn;
    }

    public void deleteForMe(UUID messageId, UUID userId) {
        Map<String,Object> row=one("SELECT conversation_id FROM messages WHERE id=?",messageId);
        access((UUID)row.get("conversation_id"),userId,false);
        jdbc.update("INSERT INTO message_hidden_users(message_id,user_id) VALUES (?,?) ON CONFLICT DO NOTHING",messageId,userId);
    }

    @Transactional(readOnly = true)
    public List<ChatResponses.ReactionDetail> reactionDetails(UUID messageId, UUID userId) {
        Map<String,Object> row=one("SELECT conversation_id,status,created_at FROM messages WHERE id=?",messageId);
        Access access=access((UUID)row.get("conversation_id"),userId,false);
        boolean hidden=Boolean.TRUE.equals(jdbc.queryForObject(
                "SELECT EXISTS(SELECT 1 FROM message_hidden_users WHERE message_id=? AND user_id=?)",
                Boolean.class,messageId,userId));
        if(hidden) throw new BusinessException(ErrorCode.RESOURCE_NOT_FOUND);
        if(access.groupId!=null && access.historyPolicy!=ChatHistoryPolicy.FULL_HISTORY) {
            Instant joined=jdbc.queryForObject("SELECT created_at FROM group_memberships WHERE group_id=? AND user_id=? AND status='ACTIVE' ORDER BY created_at DESC LIMIT 1",
                    (rs,n)->rs.getTimestamp(1).toInstant(),access.groupId,userId);
            if(toInstant(row.get("created_at")).isBefore(joined))
                throw new BusinessException(ErrorCode.RESOURCE_NOT_FOUND);
        }
        if(!"ACTIVE".equals(row.get("status"))) return List.of();
        return jdbc.query("""
                SELECT u.id,COALESCE(u.display_name,u.username::text,'Người dùng') AS display_name,
                       u.avatar_storage_key,r.emoji
                FROM message_reactions r JOIN users u ON u.id=r.user_id
                JOIN messages m ON m.id=r.message_id
                WHERE r.message_id=? AND m.status='ACTIVE' ORDER BY r.emoji,u.display_name,u.id
                """,(rs,n)-> {
                    String key=rs.getString("avatar_storage_key");
                    String avatarUrl=key==null?null:"/api/v1/media/"+
                            org.springframework.web.util.UriUtils.encodePath(key,java.nio.charset.StandardCharsets.UTF_8);
                    return new ChatResponses.ReactionDetail(new ChatResponses.Reactor(
                            rs.getObject("id",UUID.class),rs.getString("display_name"),avatarUrl),rs.getString("emoji"));
                },messageId);
    }

    public ChatResponses.Message react(UUID messageId, UUID userId, ChatRequests.Reaction request) {
        if (!SUPPORTED_REACTIONS.contains(request.emoji())) throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        Map<String,Object> row=one("SELECT conversation_id,status FROM messages WHERE id=? FOR UPDATE",messageId);
        UUID conversationId = (UUID) row.get("conversation_id");
        access(conversationId,userId,true);
        if (!"ACTIVE".equals(row.get("status"))) throw new BusinessException(ErrorCode.CONFLICT);
        String old=jdbc.query("SELECT emoji FROM message_reactions WHERE message_id=? AND user_id=?",rs->rs.next()?rs.getString(1):null,messageId,userId);
        if (request.emoji().equals(old)) jdbc.update("DELETE FROM message_reactions WHERE message_id=? AND user_id=?",messageId,userId);
        else jdbc.update("INSERT INTO message_reactions(id,message_id,user_id,emoji) VALUES (?,?,?,?) ON CONFLICT(message_id,user_id) DO UPDATE SET emoji=excluded.emoji,updated_at=now()",UUID.randomUUID(),messageId,userId,request.emoji());
        ChatResponses.Message updated = messageById(messageId,userId);
        events.publishEvent(new com.wedo.backend.chat.realtime.ChatRealtimeEvents.DomainMutationEvent(
                UUID.randomUUID(), "MESSAGE_REACTION_UPDATED", conversationId, messageId, updated.sequence(), null, userId, Instant.now()));
        return updated;
    }

    public void read(UUID conversationId, UUID userId, long sequence) {
        access(conversationId,userId,false);
        long max=jdbc.queryForObject("SELECT current_sequence FROM conversation_sequences WHERE conversation_id=?",Long.class,conversationId);
        if(sequence<0 || sequence>max) throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        jdbc.update("INSERT INTO conversation_read_states(conversation_id,user_id,last_read_sequence) VALUES (?,?,?) ON CONFLICT(conversation_id,user_id) DO UPDATE SET last_read_sequence=GREATEST(conversation_read_states.last_read_sequence,excluded.last_read_sequence),updated_at=now()",conversationId,userId,sequence);
        Long persisted = jdbc.query("SELECT last_read_sequence FROM conversation_read_states WHERE conversation_id=? AND user_id=?",
                rs -> rs.next() ? rs.getLong(1) : 0L, conversationId, userId);
        if (persisted != null && persisted > 0) {
            ChatResponses.User readerUser = user(userId);
            events.publishEvent(new com.wedo.backend.chat.realtime.ChatRealtimeEvents.DomainReadEvent(
                    UUID.randomUUID(), conversationId,
                    new ChatResponses.ReaderState(userId, readerUser.displayName(), readerUser.avatarStorageKey(), persisted),
                    Instant.now()));
        }
    }

    public void pin(UUID messageId, UUID userId, boolean pin) {
        Map<String,Object> row=one("SELECT m.conversation_id,m.status,m.sequence,gc.group_id FROM messages m LEFT JOIN group_conversations gc ON gc.conversation_id=m.conversation_id WHERE m.id=?",messageId);
        Access access=access((UUID)row.get("conversation_id"),userId,true);
        if(access.groupId==null) throw new BusinessException(ErrorCode.ACCESS_DENIED);
        if(pin) {
            if(!"ACTIVE".equals(row.get("status"))) throw new BusinessException(ErrorCode.CONFLICT);
            var membership=membership(access.groupId,userId);
            boolean allowed=membership.getRole()!=GroupRole.MEMBER || settings.findById(access.groupId).map(s->s.isMemberPinMessageAllowed()).orElse(false);
            if(!allowed) throw new BusinessException(ErrorCode.INSUFFICIENT_GROUP_PERMISSION);
            jdbc.queryForObject("SELECT current_sequence FROM conversation_sequences WHERE conversation_id=? FOR UPDATE",Long.class,access.conversationId);
            Long count=jdbc.queryForObject("SELECT count(*) FROM message_pins mp JOIN messages m ON m.id=mp.message_id WHERE m.conversation_id=?",Long.class,access.conversationId);
            if(count!=null&&count>=20) throw new BusinessException(ErrorCode.CONFLICT);
            jdbc.update("INSERT INTO message_pins(id,message_id,pinned_by) VALUES (?,?,?) ON CONFLICT(message_id) DO NOTHING",UUID.randomUUID(),messageId,userId);
        } else jdbc.update("DELETE FROM message_pins WHERE message_id=?",messageId);
        Long seq = row.get("sequence") instanceof Number num ? num.longValue() : null;
        events.publishEvent(new com.wedo.backend.chat.realtime.ChatRealtimeEvents.DomainMutationEvent(
                UUID.randomUUID(), pin ? "MESSAGE_PINNED" : "MESSAGE_UNPINNED", access.conversationId, messageId, seq, null, userId, Instant.now()));
    }

    @Transactional(readOnly = true)
    public List<ChatResponses.Message> pins(UUID conversationId, UUID userId) {
        Access access=access(conversationId,userId,false);
        List<MessageRow> rows=jdbc.query("SELECT m.id,m.conversation_id,m.sequence,m.sender_id,u.display_name,u.avatar_storage_key,m.content,m.status,m.reply_to_message_id,m.created_at,m.edited_at,m.unsent_at FROM message_pins p JOIN messages m ON m.id=p.message_id LEFT JOIN users u ON u.id=m.sender_id WHERE m.conversation_id=? ORDER BY p.pinned_at DESC",this::messageRow,conversationId);
        return toMessages(rows,userId,access);
    }

    @Transactional(readOnly = true)
    public List<ChatResponses.Message> search(UUID conversationId, UUID userId, String query) {
        Access access=access(conversationId,userId,false);
        if(query==null||query.isBlank()) throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        String cutoff=access.groupId!=null&&access.historyPolicy==ChatHistoryPolicy.FROM_JOIN_TIME
                ? " AND m.created_at >= (SELECT gm.created_at FROM group_memberships gm WHERE gm.group_id=? AND gm.user_id=? AND gm.status='ACTIVE' ORDER BY gm.created_at DESC LIMIT 1)" : "";
        List<Object> args=new java.util.ArrayList<>(List.of(conversationId,"%"+query.trim()+"%",userId));
        if(!cutoff.isEmpty()){args.add(access.groupId);args.add(userId);}
        List<MessageRow> rows=jdbc.query("SELECT m.id,m.conversation_id,m.sequence,m.sender_id,u.display_name,u.avatar_storage_key,m.content,m.status,m.reply_to_message_id,m.created_at,m.edited_at,m.unsent_at FROM messages m LEFT JOIN users u ON u.id=m.sender_id WHERE m.conversation_id=? AND m.status='ACTIVE' AND m.content ILIKE ? AND NOT EXISTS(SELECT 1 FROM message_hidden_users h WHERE h.message_id=m.id AND h.user_id=?)"+cutoff+" ORDER BY m.sequence DESC LIMIT 100",this::messageRow,args.toArray());
        return toMessages(rows,userId,access);
    }

    private UUID createDirect(UUID low, UUID high) {
        UUID id=UUID.randomUUID();
        jdbc.update("INSERT INTO conversations(id,type) VALUES (?,'DIRECT')",id);
        jdbc.update("INSERT INTO conversation_sequences(conversation_id) VALUES (?)",id);
        jdbc.update("INSERT INTO direct_conversations(conversation_id,user_id_1,user_id_2) VALUES (?,?,?) ON CONFLICT(user_id_1,user_id_2) DO NOTHING",id,low,high);
        UUID actual=jdbc.queryForObject("SELECT conversation_id FROM direct_conversations WHERE user_id_1=? AND user_id_2=?",UUID.class,low,high);
        if(!id.equals(actual)) jdbc.update("DELETE FROM conversations WHERE id=?",id);
        return actual;
    }

    private String requestStatus(UUID conversationId, UUID userId) {
        return jdbc.query("SELECT status,sender_id FROM message_requests WHERE conversation_id=? ORDER BY created_at DESC LIMIT 1",
                rs -> {
                    if (!rs.next()) return "OPEN";
                    String state=rs.getString("status");
                    if ("PENDING".equals(state)) return userId.equals(rs.getObject("sender_id",UUID.class)) ? "REQUEST_PENDING" : "REQUEST_RECEIVED";
                    return "ACCEPTED".equals(state) ? "OPEN" : "REQUEST_DECLINED";
                },conversationId);
    }

    private ChatResponses.Conversation getConversation(UUID id,UUID userId) {
        return jdbc.queryForObject("""
                SELECT c.id,c.type,gc.group_id,g.name AS title,g.avatar_storage_key,dc.user_id_1,dc.user_id_2,COALESCE(s.current_sequence,0) AS last_sequence,
                (SELECT CASE WHEN status='UNSENT' THEN 'Tin nhắn đã được thu hồi' ELSE content END FROM messages WHERE conversation_id=c.id ORDER BY sequence DESC LIMIT 1) AS preview,
                (SELECT created_at FROM messages WHERE conversation_id=c.id ORDER BY sequence DESC LIMIT 1) AS last_at
                FROM conversations c LEFT JOIN group_conversations gc ON gc.conversation_id=c.id LEFT JOIN groups g ON g.id=gc.group_id
                LEFT JOIN direct_conversations dc ON dc.conversation_id=c.id LEFT JOIN conversation_sequences s ON s.conversation_id=c.id WHERE c.id=?
                """,(rs,n)->conversation(rs,userId),id);
    }

    private ChatResponses.Conversation conversation(ResultSet rs,UUID userId) throws SQLException {
        UUID groupId=rs.getObject("group_id",UUID.class);
        UUID peerId=null;
        if("DIRECT".equals(rs.getString("type"))) { UUID a=rs.getObject("user_id_1",UUID.class),b=rs.getObject("user_id_2",UUID.class); peerId=userId.equals(a)?b:a; }
        String access="OPEN";
        if(peerId!=null) access=requestStatus(rs.getObject("id",UUID.class),userId);
        boolean writable=permissions(rs.getString("type"),groupId,userId,access,true);
        Long seq=rs.getLong("last_sequence");
        long read=jdbc.query("SELECT last_read_sequence FROM conversation_read_states WHERE conversation_id=? AND user_id=?",r->r.next()?r.getLong(1):0L,rs.getObject("id",UUID.class),userId);
        long unread=jdbc.queryForObject("SELECT count(*) FROM messages m WHERE m.conversation_id=? AND m.sequence>? AND m.sender_id<>? AND NOT EXISTS(SELECT 1 FROM message_hidden_users h WHERE h.message_id=m.id AND h.user_id=?)",Long.class,rs.getObject("id",UUID.class),read,userId,userId);
        return new ChatResponses.Conversation(rs.getObject("id",UUID.class),rs.getString("type"),groupId,rs.getString("title"),rs.getString("avatar_storage_key"),
                peerId==null?null:user(peerId),access,seq,rs.getString("preview"),rs.getTimestamp("last_at")==null?null:rs.getTimestamp("last_at").toInstant(),unread,
                new ChatResponses.Permissions(writable,false,false,false,writable,false,!writable));
    }

    private MessageRow messageRow(ResultSet rs,int row) throws SQLException {
        return new MessageRow(rs.getObject("id",UUID.class),rs.getObject("conversation_id",UUID.class),
                rs.getLong("sequence"),rs.getObject("sender_id",UUID.class),rs.getString("display_name"),
                rs.getString("avatar_storage_key"),rs.getString("content"),rs.getString("status"),
                rs.getObject("reply_to_message_id",UUID.class),rs.getTimestamp("created_at").toInstant(),
                rs.getTimestamp("edited_at")==null?null:rs.getTimestamp("edited_at").toInstant(),
                rs.getTimestamp("unsent_at")==null?null:rs.getTimestamp("unsent_at").toInstant());
    }

    private List<ChatResponses.Message> toMessages(List<MessageRow> rows,UUID userId,Access access) {
        if(rows.isEmpty()) return List.of();
        String marks=String.join(",",java.util.Collections.nCopies(rows.size(),"?"));
        List<Object> args=new java.util.ArrayList<>(); args.add(userId);
        rows.forEach(row->args.add(row.id()));
        Map<UUID,List<ChatResponses.Reaction>> reactions=new java.util.HashMap<>();
        Map<UUID,String> myReactions=new java.util.HashMap<>();
        jdbc.query("SELECT message_id,emoji,count(*) AS reaction_count,bool_or(user_id=?) AS mine FROM message_reactions WHERE message_id IN ("+marks+") GROUP BY message_id,emoji ORDER BY message_id,emoji",rs->{
            UUID messageId=rs.getObject("message_id",UUID.class); String emoji=rs.getString("emoji");
            boolean mine=rs.getBoolean("mine");
            reactions.computeIfAbsent(messageId,k->new java.util.ArrayList<>())
                    .add(new ChatResponses.Reaction(emoji,rs.getLong("reaction_count"),mine));
            if(mine) myReactions.put(messageId,emoji);
        },args.toArray());
        boolean writable=permissions(access.type,access.groupId,userId,access.accessStatus,true);
        boolean canPin=writable&&access.groupId!=null&&membership(access.groupId,userId).getRole()!=GroupRole.MEMBER;
        if(writable&&access.groupId!=null&&!canPin) canPin=settings.findById(access.groupId)
                .map(s->s.isMemberPinMessageAllowed()).orElse(false);
        Instant now=Instant.now();
        final boolean canPinMessages=canPin;
        final boolean readOnly=!writable;
        return rows.stream().map(row->{
            boolean owner=userId.equals(row.senderId());
            boolean active="ACTIVE".equals(row.status());
            boolean within=Duration.between(row.createdAt(),now).compareTo(MESSAGE_WINDOW)<0;
            ChatResponses.User author=row.senderId()==null?null:new ChatResponses.User(
                    row.senderId(),row.displayName()==null?"Người dùng":row.displayName(),row.avatarStorageKey());
            return new ChatResponses.Message(row.id(),row.sequence(),owner,author,
                    active?row.content():null,row.status(),row.replyToMessageId(),row.createdAt(),
                    row.editedAt(),row.unsentAt(),myReactions.get(row.id()),
                    reactions.getOrDefault(row.id(),List.of()),
                    new ChatResponses.Permissions(writable&&owner&&active&&within,
                            writable&&owner&&active&&within,writable&&owner&&active&&within,
                            writable,writable&&active,canPinMessages&&active,readOnly));
        }).toList();
    }

    private ChatResponses.Message messageById(UUID id,UUID userId) {
        MessageRow row=jdbc.queryForObject("SELECT m.id,m.conversation_id,m.sequence,m.sender_id,u.display_name,u.avatar_storage_key,m.content,m.status,m.reply_to_message_id,m.created_at,m.edited_at,m.unsent_at FROM messages m LEFT JOIN users u ON u.id=m.sender_id WHERE m.id=?",this::messageRow,id);
        return toMessages(List.of(row),userId,access(row.conversationId(),userId,false)).get(0);
    }

    private ChatResponses.User user(UUID id) {
        return jdbc.queryForObject("SELECT id,COALESCE(display_name,username::text,'Người dùng') AS display_name,avatar_storage_key FROM users WHERE id=?",
                (rs,n)->new ChatResponses.User(rs.getObject("id",UUID.class),rs.getString("display_name"),rs.getString("avatar_storage_key")),id);
    }

    private Map<String,Object> one(String sql,Object... args) {
        List<Map<String,Object>> rows=jdbc.queryForList(sql,args);
        if(rows.isEmpty()) throw new BusinessException(ErrorCode.RESOURCE_NOT_FOUND);
        return rows.get(0);
    }

    private GroupMembershipEntity membership(UUID groupId,UUID userId) {
        return memberships.findFirstByGroupIdAndUserIdAndStatus(groupId,userId,GroupMembershipStatus.ACTIVE)
                .orElseThrow(()->new BusinessException(ErrorCode.GROUP_NOT_FOUND));
    }

    private Access access(UUID conversationId,UUID userId,boolean mutation) {
        Map<String,Object> row=one("SELECT c.type,gc.group_id,g.status,dc.user_id_1,dc.user_id_2 FROM conversations c LEFT JOIN group_conversations gc ON gc.conversation_id=c.id LEFT JOIN groups g ON g.id=gc.group_id LEFT JOIN direct_conversations dc ON dc.conversation_id=c.id WHERE c.id=?",conversationId);
        String type=(String)row.get("type"); UUID groupId=(UUID)row.get("group_id"); String request="OPEN";
        ChatHistoryPolicy history=ChatHistoryPolicy.FULL_HISTORY;
        if(groupId!=null) {
            membership(groupId,userId);
            if("DELETED".equals(row.get("status"))) throw new BusinessException(ErrorCode.GROUP_DELETED);
            if("ARCHIVED".equals(row.get("status"))&&mutation) throw new BusinessException(ErrorCode.GROUP_ARCHIVED);
            history=settings.findById(groupId).map(s->s.getChatHistoryPolicy()).orElse(ChatHistoryPolicy.FULL_HISTORY);
        } else {
            UUID a=(UUID)row.get("user_id_1"),b=(UUID)row.get("user_id_2");
            if(!userId.equals(a)&&!userId.equals(b)) throw new BusinessException(ErrorCode.RESOURCE_NOT_FOUND);
            UUID peer=userId.equals(a)?b:a;
            if(blocks.existsBlockBetween(userId,peer)) throw new BusinessException(ErrorCode.ACCESS_DENIED);
            request=requestStatus(conversationId,userId);
        }
        return new Access(conversationId,type,groupId,history,request);
    }

    private void ensureSendAllowed(Access access,UUID userId) {
        if(access.groupId!=null) { if(groups.findById(access.groupId).map(g->g.getStatus()==GroupStatus.ACTIVE).orElse(false)) return; }
        else if("OPEN".equals(access.accessStatus)||"REQUEST_PENDING".equals(access.accessStatus)) return;
        throw new BusinessException(ErrorCode.ACCESS_DENIED);
    }

    private boolean permissions(String type,UUID groupId,UUID userId,String request,boolean mutation) {
        if("GROUP".equals(type)) {
            if(groupId==null) return false;
            return memberships.findFirstByGroupIdAndUserIdAndStatus(groupId,userId,GroupMembershipStatus.ACTIVE).isPresent()
                    && groups.findById(groupId).map(g->g.getStatus()==GroupStatus.ACTIVE).orElse(false);
        }
        return "OPEN".equals(request)||"REQUEST_PENDING".equals(request);
    }

    private Instant toInstant(Object value) {
        if (value instanceof Instant instant) return instant;
        if (value instanceof java.sql.Timestamp timestamp) return timestamp.toInstant();
        if (value instanceof java.time.OffsetDateTime offset) return offset.toInstant();
        throw new IllegalStateException("Unexpected database timestamp type");
    }

    @Transactional(readOnly = true)
    public boolean isUserActive(UUID userId) {
        if (userId == null) return false;
        return Boolean.TRUE.equals(jdbc.queryForObject(
                "SELECT EXISTS(SELECT 1 FROM users WHERE id=? AND status='ACTIVE')",
                Boolean.class, userId));
    }

    @Transactional(readOnly = true)
    public boolean canSubscribeConversation(UUID conversationId, UUID userId) {
        if (conversationId == null || userId == null) return false;
        try {
            access(conversationId, userId, false);
            return true;
        } catch (RuntimeException ex) {
            return false;
        }
    }

    @Transactional(readOnly = true)
    public boolean canSendInConversation(UUID conversationId, UUID userId) {
        if (conversationId == null || userId == null) return false;
        try {
            Access access = access(conversationId, userId, true);
            ensureSendAllowed(access, userId);
            if ("DIRECT".equals(access.type) && "REQUEST_PENDING".equals(access.accessStatus)) {
                Long sent = jdbc.queryForObject(
                        "SELECT count(*) FROM messages WHERE conversation_id=? AND sender_id=? AND status='ACTIVE'",
                        Long.class, conversationId, userId);
                if (sent != null && sent >= 3) return false;
            }
            return true;
        } catch (RuntimeException ex) {
            return false;
        }
    }

    @Transactional(readOnly = true)
    public java.util.Set<UUID> eligibleRecipientUserIds(UUID conversationId) {
        List<Map<String, Object>> rows = jdbc.queryForList("""
                SELECT c.type, gc.group_id, g.status AS group_status, dc.user_id_1, dc.user_id_2
                FROM conversations c
                LEFT JOIN group_conversations gc ON gc.conversation_id = c.id
                LEFT JOIN groups g ON g.id = gc.group_id
                LEFT JOIN direct_conversations dc ON dc.conversation_id = c.id
                WHERE c.id = ?
                """, conversationId);
        if (rows.isEmpty()) return java.util.Set.of();
        Map<String, Object> row = rows.get(0);
        String type = (String) row.get("type");
        if ("GROUP".equals(type)) {
            UUID groupId = (UUID) row.get("group_id");
            String groupStatus = (String) row.get("group_status");
            if (groupId == null || "DELETED".equals(groupStatus)) return java.util.Set.of();
            return new java.util.LinkedHashSet<>(jdbc.query(
                    "SELECT user_id FROM group_memberships WHERE group_id=? AND status='ACTIVE'",
                    (rs, n) -> rs.getObject(1, UUID.class), groupId));
        }
        UUID a = (UUID) row.get("user_id_1");
        UUID b = (UUID) row.get("user_id_2");
        if (a == null || b == null || blocks.existsBlockBetween(a, b)) return java.util.Set.of();
        return java.util.Set.of(a, b);
    }

    @Transactional(readOnly = true)
    public java.util.Set<UUID> sharedPeerUserIds(UUID userId) {
        java.util.Set<UUID> peers = new java.util.LinkedHashSet<>();
        peers.addAll(jdbc.query("""
                SELECT DISTINCT gm2.user_id
                FROM group_memberships gm1
                JOIN group_memberships gm2 ON gm1.group_id = gm2.group_id
                JOIN groups g ON g.id = gm1.group_id
                WHERE gm1.user_id = ? AND gm1.status = 'ACTIVE'
                  AND gm2.status = 'ACTIVE' AND gm2.user_id <> ?
                  AND g.status IN ('ACTIVE', 'ARCHIVED')
                """, (rs, n) -> rs.getObject(1, UUID.class), userId, userId));
        peers.addAll(jdbc.query("""
                SELECT CASE WHEN dc.user_id_1 = ? THEN dc.user_id_2 ELSE dc.user_id_1 END AS peer_id
                FROM direct_conversations dc
                WHERE (dc.user_id_1 = ? OR dc.user_id_2 = ?)
                  AND NOT EXISTS (
                      SELECT 1 FROM user_blocks ub
                      WHERE (ub.blocker_id = dc.user_id_1 AND ub.blocked_id = dc.user_id_2)
                         OR (ub.blocker_id = dc.user_id_2 AND ub.blocked_id = dc.user_id_1)
                  )
                """, (rs, n) -> rs.getObject(1, UUID.class), userId, userId, userId));
        return peers;
    }

    @Transactional(readOnly = true)
    public java.util.Optional<ChatResponses.Message> messageForViewer(UUID messageId, UUID viewerUserId) {
        try {
            List<MessageRow> rows = jdbc.query("""
                    SELECT m.id,m.conversation_id,m.sequence,m.sender_id,u.display_name,u.avatar_storage_key,
                           m.content,m.status,m.reply_to_message_id,m.created_at,m.edited_at,m.unsent_at
                    FROM messages m LEFT JOIN users u ON u.id=m.sender_id WHERE m.id=?
                    """, this::messageRow, messageId);
            if (rows.isEmpty()) return java.util.Optional.empty();
            MessageRow row = rows.get(0);
            Access access = access(row.conversationId(), viewerUserId, false);
            boolean hidden = Boolean.TRUE.equals(jdbc.queryForObject(
                    "SELECT EXISTS(SELECT 1 FROM message_hidden_users WHERE message_id=? AND user_id=?)",
                    Boolean.class, messageId, viewerUserId));
            if (hidden) return java.util.Optional.empty();
            if (access.groupId != null && access.historyPolicy == ChatHistoryPolicy.FROM_JOIN_TIME) {
                Instant joined = jdbc.queryForObject(
                        "SELECT created_at FROM group_memberships WHERE group_id=? AND user_id=? AND status='ACTIVE' ORDER BY created_at DESC LIMIT 1",
                        (rs, n) -> rs.getTimestamp(1).toInstant(), access.groupId, viewerUserId);
                if (joined != null && row.createdAt().isBefore(joined)) {
                    return java.util.Optional.empty();
                }
            }
            return java.util.Optional.of(toMessages(List.of(row), viewerUserId, access).get(0));
        } catch (RuntimeException ex) {
            return java.util.Optional.empty();
        }
    }

    @Transactional(readOnly = true)
    public ChatResponses.User userSummary(UUID userId) {
        return user(userId);
    }

    @Transactional(readOnly = true)
    public boolean canViewPresence(UUID targetUserId, UUID viewerUserId) {
        if (targetUserId == null || viewerUserId == null) return false;
        if (targetUserId.equals(viewerUserId)) return true;
        if (blocks.existsBlockBetween(targetUserId, viewerUserId)) return false;
        boolean targetShows = privacy.findById(targetUserId).map(p -> p.isShowOnlineStatus()).orElse(true);
        boolean viewerShows = privacy.findById(viewerUserId).map(p -> p.isShowOnlineStatus()).orElse(true);
        return targetShows && viewerShows;
    }

    public void recordLastSeenSnapshot(UUID userId, Instant lastSeenAt) {
        if (userId == null || lastSeenAt == null) return;
        jdbc.update("""
                INSERT INTO user_presence_snapshots(user_id, last_seen_at, updated_at)
                VALUES (?, ?, now())
                ON CONFLICT (user_id) DO UPDATE
                SET last_seen_at = EXCLUDED.last_seen_at, updated_at = now()
                """, userId, java.sql.Timestamp.from(lastSeenAt));
    }

    private record Access(UUID conversationId,String type,UUID groupId,ChatHistoryPolicy historyPolicy,String accessStatus) { }
    private record MessageRow(UUID id,UUID conversationId,long sequence,UUID senderId,String displayName,
                              String avatarStorageKey,String content,String status,UUID replyToMessageId,
                              Instant createdAt,Instant editedAt,Instant unsentAt) { }
}
