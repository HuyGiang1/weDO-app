import '../../../core/network/api_exception.dart';

/// Enum classifying domain-level social failure categories.
enum SocialFailureType {
  cannotFriendSelf,
  cannotBlockSelf,
  userBlocked,
  alreadyFriends,
  friendRequestAlreadyPending,
  friendRequestCooldownActive,
  friendRequestNotAllowed,
  friendRequestNotFound,
  friendshipNotFound,
  resourceNotFound,
  accessDenied,
  conflict,
  authTokenExpired,
  authTokenInvalid,
  network,
  timeout,
  unexpected,
}

/// Represents a domain failure originating from Social API interactions,
/// preserving raw backend error codes, messages, and HTTP status codes.
class SocialFailure {
  final SocialFailureType type;
  final String? backendCode;
  final String? backendMessage;
  final int? statusCode;
  final Map<String, String> fieldErrors;

  const SocialFailure(
    this.type, {
    this.backendCode,
    this.backendMessage,
    this.statusCode,
    this.fieldErrors = const {},
  });

  factory SocialFailure.fromApi(ApiException exception) {
    const codeMapping = <String, SocialFailureType>{
      'CANNOT_FRIEND_SELF': SocialFailureType.cannotFriendSelf,
      'CANNOT_BLOCK_SELF': SocialFailureType.cannotBlockSelf,
      'USER_BLOCKED': SocialFailureType.userBlocked,
      'ALREADY_FRIENDS': SocialFailureType.alreadyFriends,
      'FRIEND_REQUEST_ALREADY_PENDING':
          SocialFailureType.friendRequestAlreadyPending,
      'FRIEND_REQUEST_COOLDOWN_ACTIVE':
          SocialFailureType.friendRequestCooldownActive,
      'FRIEND_REQUEST_NOT_ALLOWED': SocialFailureType.friendRequestNotAllowed,
      'FRIEND_REQUEST_NOT_FOUND': SocialFailureType.friendRequestNotFound,
      'FRIENDSHIP_NOT_FOUND': SocialFailureType.friendshipNotFound,
      'RESOURCE_NOT_FOUND': SocialFailureType.resourceNotFound,
      'ACCESS_DENIED': SocialFailureType.accessDenied,
      'CONFLICT': SocialFailureType.conflict,
      'AUTH_TOKEN_EXPIRED': SocialFailureType.authTokenExpired,
      'AUTH_TOKEN_INVALID': SocialFailureType.authTokenInvalid,
    };

    SocialFailureType resolveType() {
      if (exception.code != null && codeMapping.containsKey(exception.code)) {
        return codeMapping[exception.code]!;
      }

      switch (exception.statusCode) {
        case 401:
          return SocialFailureType.authTokenInvalid;
        case 403:
          return SocialFailureType.accessDenied;
        case 404:
          return SocialFailureType.resourceNotFound;
        case 409:
          return SocialFailureType.conflict;
        case 429:
          return SocialFailureType.friendRequestCooldownActive;
      }

      switch (exception.transportFailure) {
        case ApiTransportFailure.network:
          return SocialFailureType.network;
        case ApiTransportFailure.timeout:
          return SocialFailureType.timeout;
        case ApiTransportFailure.unexpected:
          return SocialFailureType.unexpected;
      }
    }

    return SocialFailure(
      resolveType(),
      backendCode: exception.code,
      backendMessage: exception.message,
      statusCode: exception.statusCode,
      fieldErrors: exception.fieldErrors,
    );
  }

  @override
  String toString() =>
      'SocialFailure(type: $type, code: $backendCode, message: $backendMessage, status: $statusCode)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SocialFailure &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          backendCode == other.backendCode &&
          statusCode == other.statusCode;

  @override
  int get hashCode => type.hashCode ^ backendCode.hashCode ^ statusCode.hashCode;
}

/// Domain exception thrown by Social repository operations.
class SocialException implements Exception {
  final SocialFailure failure;

  const SocialException(this.failure);

  @override
  String toString() => 'SocialException: $failure';
}
