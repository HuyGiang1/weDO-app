package com.wedo.backend.common.dto;

import java.util.List;
import org.springframework.data.domain.Page;

/**
 * Generic API response wrapper for paginated endpoints.
 * Decouples client API contracts from Spring Data's internal Page structure.
 *
 * @param <T> the type of items in the page
 */
public record PagedResponse<T>(
    List<T> items,
    int page,
    int size,
    long totalElements,
    int totalPages,
    boolean hasNext
) {
    /**
     * Factory method creating a PagedResponse from a Spring Data Page metadata object and mapped items.
     *
     * @param page Spring Data page holding pagination metadata
     * @param items transformed DTO items for response
     * @return PagedResponse containing metadata and items
     */
    public static <T> PagedResponse<T> from(Page<?> page, List<T> items) {
        return new PagedResponse<>(
            items,
            page.getNumber(),
            page.getSize(),
            page.getTotalElements(),
            page.getTotalPages(),
            page.hasNext()
        );
    }
}
