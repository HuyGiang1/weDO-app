package com.wedo.backend.search.controller;

import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.search.dto.SearchCategory;
import com.wedo.backend.search.dto.SearchDtos.Response;
import com.wedo.backend.search.service.SearchService;
import com.wedo.backend.security.AuthenticatedUserPrincipal;
import java.util.Locale;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/search")
public class SearchController {
    private final SearchService searchService;

    public SearchController(SearchService searchService) {
        this.searchService = searchService;
    }

    @GetMapping
    public Response search(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @RequestParam(required = false) String q,
            @RequestParam(required = false) String type,
            @RequestParam(required = false) String page,
            @RequestParam(required = false) String size
    ) {
        if (q == null) throw invalid();
        String query = q.trim();
        if (query.length() < 2 || query.length() > 100) throw invalid();

        SearchCategory category = parseCategory(type);
        if (category == null) {
            if (page != null || size != null) throw invalid();
            return searchService.searchAll(principal.userId(), query);
        }
        return searchService.searchCategory(
                principal.userId(), query, category, parseInteger(page, 0), parseInteger(size, 20));
    }

    private SearchCategory parseCategory(String value) {
        if (value == null) return null;
        try {
            return SearchCategory.valueOf(value.toUpperCase(Locale.ROOT));
        } catch (IllegalArgumentException exception) {
            throw invalid();
        }
    }

    private int parseInteger(String value, int defaultValue) {
        if (value == null) return defaultValue;
        try {
            return Integer.parseInt(value);
        } catch (NumberFormatException exception) {
            throw invalid();
        }
    }

    private BusinessException invalid() {
        return new BusinessException(ErrorCode.VALIDATION_FAILED);
    }
}
