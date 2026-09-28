package com.wedo.backend.chat;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

import com.wedo.backend.chat.controller.ChatController;
import com.wedo.backend.chat.dto.ChatResponses;
import com.wedo.backend.chat.service.ChatService;
import com.wedo.backend.security.AuthenticatedUserPrincipal;
import java.util.Arrays;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.web.bind.annotation.GetMapping;

class ChatControllerTest {
    @Test
    void reactionReadForwardsAuthenticatedUserAndExposesOnlyPublicReactorFields() throws Exception {
        ChatService service=mock(ChatService.class);
        UUID message=UUID.randomUUID(),user=UUID.randomUUID();
        var details=List.of(new ChatResponses.ReactionDetail(new ChatResponses.Reactor(user,"Member",null),"👍"));
        when(service.reactionDetails(message,user)).thenReturn(details);
        assertSame(details,new ChatController(service).reactions(new AuthenticatedUserPrincipal(user),message));
        verify(service).reactionDetails(message,user);
        assertEquals(List.of("id","displayName","avatarUrl"),Arrays.stream(ChatResponses.Reactor.class.getRecordComponents())
                .map(c->c.getName()).toList());
        assertEquals("/messages/{id}/reactions",ChatController.class
                .getMethod("reactions",AuthenticatedUserPrincipal.class,UUID.class)
                .getAnnotation(GetMapping.class).value()[0]);
    }
}
