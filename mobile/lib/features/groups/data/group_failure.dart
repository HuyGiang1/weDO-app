import '../../../core/network/api_exception.dart';

enum GroupFailureType {
  validation,
  groupNotFound,
  memberNotFound,
  archived,
  insufficientPermission,
  transferRequired,
  invalidOwnershipTarget,
  invalidRoleTransition,
  network,
  unauthorized,
  unknown,
}

class GroupFailure {
  final GroupFailureType type;
  final Map<String, String> fieldErrors;
  const GroupFailure(this.type, {this.fieldErrors = const {}});
  factory GroupFailure.fromApi(ApiException e) {
    final t = switch (e.code) {
      'VALIDATION_FAILED' => GroupFailureType.validation,
      'GROUP_NOT_FOUND' => GroupFailureType.groupNotFound,
      'GROUP_MEMBER_NOT_FOUND' => GroupFailureType.memberNotFound,
      'GROUP_ARCHIVED' => GroupFailureType.archived,
      'INSUFFICIENT_GROUP_PERMISSION' =>
        GroupFailureType.insufficientPermission,
      'TRANSFER_OWNERSHIP_REQUIRED' => GroupFailureType.transferRequired,
      'INVALID_OWNERSHIP_TARGET' => GroupFailureType.invalidOwnershipTarget,
      'INVALID_GROUP_ROLE_TRANSITION' => GroupFailureType.invalidRoleTransition,
      _ =>
        e.transportFailure == ApiTransportFailure.network
            ? GroupFailureType.network
            : e.statusCode == 401
            ? GroupFailureType.unauthorized
            : GroupFailureType.unknown,
    };
    return GroupFailure(t, fieldErrors: e.fieldErrors);
  }
}

class GroupException implements Exception {
  final GroupFailure failure;
  const GroupException(this.failure);
}
