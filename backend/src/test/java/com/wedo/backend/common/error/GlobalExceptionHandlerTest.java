package com.wedo.backend.common.error;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.validation.beanvalidation.LocalValidatorFactoryBean;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import static org.hamcrest.Matchers.not;
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.emptyOrNullString;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class GlobalExceptionHandlerTest {

    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        LocalValidatorFactoryBean validator = new LocalValidatorFactoryBean();
        validator.afterPropertiesSet();

        mockMvc = MockMvcBuilders.standaloneSetup(new TestErrorController())
                .setControllerAdvice(new GlobalExceptionHandler())
                .setValidator(validator)
                .build();
    }

    @Test
    void businessExceptionReturnsApiContractShape() throws Exception {
        mockMvc.perform(get("/test/business-error"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.timestamp").isString())
                .andExpect(jsonPath("$.status").value(409))
                .andExpect(jsonPath("$.code").value("CONFLICT"))
                .andExpect(jsonPath("$.message").value(ErrorCode.CONFLICT.defaultMessage()))
                .andExpect(jsonPath("$.path").value("/test/business-error"))
                .andExpect(jsonPath("$.errors").doesNotExist());
    }

    @Test
    void validationFailureReturnsFieldErrors() throws Exception {
        mockMvc.perform(post("/test/validation")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.timestamp").isString())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"))
                .andExpect(jsonPath("$.message").value(ErrorCode.VALIDATION_FAILED.defaultMessage()))
                .andExpect(jsonPath("$.path").value("/test/validation"))
                .andExpect(jsonPath("$.errors.name").value("must not be blank"));
    }

    @Test
    void unexpectedExceptionReturnsInternalServerErrorWithoutInternalDetails() throws Exception {
        mockMvc.perform(get("/test/unexpected-error"))
                .andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.timestamp").isString())
                .andExpect(jsonPath("$.status").value(500))
                .andExpect(jsonPath("$.code").value("INTERNAL_SERVER_ERROR"))
                .andExpect(jsonPath("$.message").value(ErrorCode.INTERNAL_SERVER_ERROR.defaultMessage()))
                .andExpect(jsonPath("$.message").value(not(containsString("database-password"))))
                .andExpect(jsonPath("$.path").value("/test/unexpected-error"))
                .andExpect(jsonPath("$.errors").doesNotExist())
                .andExpect(jsonPath("$.exception").doesNotExist())
                .andExpect(jsonPath("$.trace").doesNotExist());
    }

    @Test
    void customBusinessExceptionMessageCanBeReturnedWhenNeeded() throws Exception {
        mockMvc.perform(get("/test/custom-business-error"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.status").value(404))
                .andExpect(jsonPath("$.code").value("RESOURCE_NOT_FOUND"))
                .andExpect(jsonPath("$.message").value("The requested test resource does not exist."))
                .andExpect(jsonPath("$.path").value("/test/custom-business-error"));
    }

    @RestController
    static class TestErrorController {

        @GetMapping("/test/business-error")
        void businessError() {
            throw new BusinessException(ErrorCode.CONFLICT);
        }

        @GetMapping("/test/custom-business-error")
        void customBusinessError() {
            throw new BusinessException(
                    ErrorCode.RESOURCE_NOT_FOUND,
                    "The requested test resource does not exist."
            );
        }

        @PostMapping("/test/validation")
        void validationError(@Valid @RequestBody TestRequest request) {
        }

        @GetMapping("/test/unexpected-error")
        void unexpectedError() {
            throw new IllegalStateException("database-password leaked internal detail");
        }
    }

    record TestRequest(@NotBlank String name) {
    }
}
