package com.wedo.backend.task.controller;

import com.wedo.backend.common.error.GlobalExceptionHandler;
import com.wedo.backend.security.AuthenticatedUserPrincipal;
import com.wedo.backend.task.service.TaskService;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.core.MethodParameter;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.bind.support.WebDataBinderFactory;
import org.springframework.web.context.request.NativeWebRequest;
import org.springframework.web.method.support.HandlerMethodArgumentResolver;
import org.springframework.web.method.support.ModelAndViewContainer;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class TaskControllerTest {

    private MockMvc mvc;

    @BeforeEach
    void setUp() {
        HandlerMethodArgumentResolver principalResolver = new HandlerMethodArgumentResolver() {
            @Override
            public boolean supportsParameter(MethodParameter parameter) {
                return parameter.getParameterType() == AuthenticatedUserPrincipal.class;
            }

            @Override
            public Object resolveArgument(
                    MethodParameter parameter,
                    ModelAndViewContainer mavContainer,
                    NativeWebRequest webRequest,
                    WebDataBinderFactory binderFactory
            ) {
                return new AuthenticatedUserPrincipal(UUID.randomUUID());
            }
        };

        mvc = MockMvcBuilders.standaloneSetup(new TaskController(org.mockito.Mockito.mock(TaskService.class)))
                .setCustomArgumentResolvers(principalResolver)
                .setControllerAdvice(new GlobalExceptionHandler())
                .build();
    }

    @Test
    void createRejectsDueAtWithoutAnInstantOffset() throws Exception {
        UUID activityId = UUID.fromString("11111111-2222-3333-4444-555555555555");

        mvc.perform(post("/api/v1/activities/{activityId}/tasks", activityId)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "title": "Bring drinks",
                                  "description": null,
                                  "assigneeUserIds": [],
                                  "dueAt": "2030-05-01T09:30:00.000"
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"))
                .andExpect(jsonPath("$.message").value("Request validation failed."))
                .andExpect(jsonPath("$.path").value("/api/v1/activities/" + activityId + "/tasks"))
                .andExpect(jsonPath("$.errors.request").value("Malformed request body."));
    }
}
