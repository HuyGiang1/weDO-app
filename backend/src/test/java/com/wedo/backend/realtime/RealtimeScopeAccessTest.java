package com.wedo.backend.realtime;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import com.wedo.backend.activity.service.M8ActivityAccessService;
import com.wedo.backend.chat.service.ChatService;
import com.wedo.backend.group.service.GroupPermissionService;
import com.wedo.backend.user.service.UserService;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class RealtimeScopeAccessTest {
    @Test void userScopeIsSelfOnlyAndMalformedScopesFailClosed() {
        var users = mock(UserService.class);
        var access = new RealtimeScopeAccess(mock(GroupPermissionService.class), mock(M8ActivityAccessService.class), mock(ChatService.class), users);
        var self = UUID.randomUUID();
        assertTrue(access.allowed("user:" + self, self));
        assertFalse(access.allowed("user:" + UUID.randomUUID(), self));
        assertFalse(access.allowed("group:not-a-uuid", self));
        assertFalse(access.allowed("unknown:" + self, self));
        assertFalse(access.allowed(null, self));
        doThrow(new IllegalStateException()).when(users).requireActiveUser(self);
        assertFalse(access.allowed("user:" + self, self));
    }
}
