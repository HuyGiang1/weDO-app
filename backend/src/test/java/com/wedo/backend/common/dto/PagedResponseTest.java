package com.wedo.backend.common.dto;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Collections;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;

class PagedResponseTest {

    @Test
    @DisplayName("Should correctly map metadata and items when page has content and next page exists")
    void shouldMapCorrectlyWhenPageHasContentAndNextPageExists() {
        // Given: page 0, size 2, total 5 elements -> 3 pages total, hasNext = true
        List<String> rawEntities = List.of("item1", "item2");
        PageRequest pageRequest = PageRequest.of(0, 2);
        Page<String> page = new PageImpl<>(rawEntities, pageRequest, 5);

        List<String> mappedDtos = List.of("ITEM1_DTO", "ITEM2_DTO");

        // When
        PagedResponse<String> response = PagedResponse.from(page, mappedDtos);

        // Then
        assertThat(response).isNotNull();
        assertThat(response.items()).containsExactly("ITEM1_DTO", "ITEM2_DTO");
        assertThat(response.page()).isEqualTo(0);
        assertThat(response.size()).isEqualTo(2);
        assertThat(response.totalElements()).isEqualTo(5L);
        assertThat(response.totalPages()).isEqualTo(3);
        assertThat(response.hasNext()).isTrue();
    }

    @Test
    @DisplayName("Should correctly map metadata when page is empty and has no next page")
    void shouldMapCorrectlyWhenPageIsEmpty() {
        // Given: empty page
        PageRequest pageRequest = PageRequest.of(0, 10);
        Page<String> emptyPage = new PageImpl<>(Collections.emptyList(), pageRequest, 0);

        List<String> emptyDtos = Collections.emptyList();

        // When
        PagedResponse<String> response = PagedResponse.from(emptyPage, emptyDtos);

        // Then
        assertThat(response).isNotNull();
        assertThat(response.items()).isEmpty();
        assertThat(response.page()).isEqualTo(0);
        assertThat(response.size()).isEqualTo(10);
        assertThat(response.totalElements()).isEqualTo(0L);
        assertThat(response.totalPages()).isEqualTo(0);
        assertThat(response.hasNext()).isFalse();
    }
}
