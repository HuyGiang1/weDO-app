package com.wedo.backend.poll.service;

import com.wedo.backend.chat.realtime.ChatRealtimeEvents.DomainMutationEvent;
import com.wedo.backend.poll.entity.PollEntity;
import com.wedo.backend.poll.entity.VoteVisibility;
import java.time.Instant;
import java.util.UUID;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/** Participates in the canonical vote transaction; delivery is AFTER_COMMIT. */
@Component
public class PollChatActivityWriter {
    private final JdbcTemplate jdbc;
    private final ApplicationEventPublisher events;
    public PollChatActivityWriter(JdbcTemplate jdbc, ApplicationEventPublisher events) {
        this.jdbc = jdbc;
        this.events = events;
    }

    @Transactional(propagation = Propagation.MANDATORY)
    public void append(PollEntity poll, UUID actor, boolean firstVote) {
        // No per-vote anonymous timeline item: even a generic system sender
        // would expose voter timing. Anonymous resource hints contain no actor.
        if (poll.getVoteVisibility() == VoteVisibility.ANONYMOUS) return;
        var conversations = jdbc.queryForList(
                "SELECT conversation_id FROM messages WHERE poll_id=? AND type='POLL'", UUID.class, poll.getId());
        if (conversations.isEmpty()) return; // Standalone Activity Poll, no Chat card.
        UUID conversation = conversations.getFirst();
        long sequence = jdbc.queryForObject("UPDATE conversation_sequences SET current_sequence=current_sequence+1,updated_at=now() WHERE conversation_id=? RETURNING current_sequence", Long.class, conversation);
        UUID id = UUID.randomUUID();
        String name = jdbc.queryForObject("SELECT COALESCE(display_name,username::text,'Người dùng') FROM users WHERE id=?", String.class, actor);
        String type = firstVote ? "POLL_VOTED" : "POLL_VOTE_CHANGED";
        String text = name + (firstVote ? " đã tham gia bình chọn: " : " đã thay đổi bình chọn: ") + poll.getQuestion();
        jdbc.update("INSERT INTO messages(id,conversation_id,sender_id,sequence,type,content,poll_id) VALUES (?,?,?,?,?,?,?)",
                id, conversation, actor, sequence, type, text, poll.getId());
        jdbc.update("UPDATE conversations SET updated_at=now() WHERE id=?", conversation);
        events.publishEvent(new DomainMutationEvent(UUID.randomUUID(), "MESSAGE_CREATED", conversation,
                id, sequence, null, actor, Instant.now()));
    }
}
