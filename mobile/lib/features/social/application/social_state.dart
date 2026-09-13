import '../data/social_failure.dart';

/// Enum representing the loading and pagination status of a social entity list.
enum SocialListStatus {
  initial,
  loading,
  loaded,
  empty,
  error,
  loadingMore,
  errorMore,
}

/// Generic immutable state representing a paginated list of social items.
class SocialListState<T> {
  final SocialListStatus status;
  final List<T> items;
  final int page;
  final int totalElements;
  final int totalPages;
  final bool hasNext;
  final SocialFailure? failure;

  const SocialListState({
    required this.status,
    this.items = const [],
    this.page = 0,
    this.totalElements = 0,
    this.totalPages = 0,
    this.hasNext = false,
    this.failure,
  });

  const SocialListState.initial()
      : status = SocialListStatus.initial,
        items = const [],
        page = 0,
        totalElements = 0,
        totalPages = 0,
        hasNext = false,
        failure = null;

  const SocialListState.loading()
      : status = SocialListStatus.loading,
        items = const [],
        page = 0,
        totalElements = 0,
        totalPages = 0,
        hasNext = false,
        failure = null;

  bool get isInitial => status == SocialListStatus.initial;
  bool get isLoading => status == SocialListStatus.loading;
  bool get isLoaded => status == SocialListStatus.loaded;
  bool get isEmpty => status == SocialListStatus.empty;
  bool get isError => status == SocialListStatus.error;
  bool get isLoadingMore => status == SocialListStatus.loadingMore;
  bool get isErrorMore => status == SocialListStatus.errorMore;

  bool get hasItems => items.isNotEmpty;

  SocialListState<T> copyWith({
    SocialListStatus? status,
    List<T>? items,
    int? page,
    int? totalElements,
    int? totalPages,
    bool? hasNext,
    SocialFailure? failure,
  }) =>
      SocialListState<T>(
        status: status ?? this.status,
        items: items ?? this.items,
        page: page ?? this.page,
        totalElements: totalElements ?? this.totalElements,
        totalPages: totalPages ?? this.totalPages,
        hasNext: hasNext ?? this.hasNext,
        failure: failure ?? this.failure,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SocialListState<T> &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          page == other.page &&
          totalElements == other.totalElements &&
          totalPages == other.totalPages &&
          hasNext == other.hasNext &&
          failure == other.failure &&
          items.length == other.items.length;

  @override
  int get hashCode =>
      status.hashCode ^
      page.hashCode ^
      totalElements.hashCode ^
      totalPages.hashCode ^
      hasNext.hashCode ^
      failure.hashCode ^
      items.length.hashCode;
}

/// Enum representing the execution status of a single social action.
enum SocialActionStatus {
  idle,
  submitting,
  success,
  error,
}

/// Generic immutable state representing the outcome of a social mutation.
class SocialActionState<T> {
  final SocialActionStatus status;
  final T? data;
  final SocialFailure? failure;

  const SocialActionState({
    required this.status,
    this.data,
    this.failure,
  });

  const SocialActionState.idle()
      : status = SocialActionStatus.idle,
        data = null,
        failure = null;

  const SocialActionState.submitting()
      : status = SocialActionStatus.submitting,
        data = null,
        failure = null;

  const SocialActionState.success([this.data])
      : status = SocialActionStatus.success,
        failure = null;

  const SocialActionState.error(this.failure)
      : status = SocialActionStatus.error,
        data = null;

  bool get isIdle => status == SocialActionStatus.idle;
  bool get isSubmitting => status == SocialActionStatus.submitting;
  bool get isSuccess => status == SocialActionStatus.success;
  bool get isError => status == SocialActionStatus.error;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SocialActionState<T> &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          data == other.data &&
          failure == other.failure;

  @override
  int get hashCode => status.hashCode ^ data.hashCode ^ failure.hashCode;
}
