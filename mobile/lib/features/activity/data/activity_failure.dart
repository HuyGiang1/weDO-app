import '../../../core/network/api_exception.dart';

enum ActivityFailureType {
  validation,
  notFound,
  closed,
  alreadyStarted,
  alreadyCompleted,
  invalidTime,
  invalidCapacity,
  rsvpLocked,
  permission,
  network,
  unauthorized,
  unknown,
}

class ActivityFailure {
  final ActivityFailureType type;
  final Map<String, String> fieldErrors;
  const ActivityFailure(this.type, {this.fieldErrors = const {}});
  factory ActivityFailure.fromApi(ApiException e) =>
      ActivityFailure(switch (e.code) {
        'VALIDATION_FAILED' => ActivityFailureType.validation,
        'ACTIVITY_NOT_FOUND' => ActivityFailureType.notFound,
        'ACTIVITY_CLOSED' => ActivityFailureType.closed,
        'ACTIVITY_ALREADY_STARTED' => ActivityFailureType.alreadyStarted,
        'ACTIVITY_ALREADY_COMPLETED' => ActivityFailureType.alreadyCompleted,
        'INVALID_ACTIVITY_TIME' => ActivityFailureType.invalidTime,
        'ACTIVITY_CAPACITY_INVALID' => ActivityFailureType.invalidCapacity,
        'RSVP_LOCKED' => ActivityFailureType.rsvpLocked,
        'INSUFFICIENT_GROUP_PERMISSION' => ActivityFailureType.permission,
        _ =>
          e.transportFailure == ApiTransportFailure.network
              ? ActivityFailureType.network
              : e.statusCode == 401
              ? ActivityFailureType.unauthorized
              : ActivityFailureType.unknown,
      }, fieldErrors: e.fieldErrors);
}

class ActivityException implements Exception {
  final ActivityFailure failure;
  const ActivityException(this.failure);
}
