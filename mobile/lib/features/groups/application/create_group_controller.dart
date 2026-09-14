import 'package:flutter/foundation.dart';

import '../data/group_failure.dart';
import '../data/group_repository.dart';
import '../data/models/group_models.dart';

class CreateGroupState {
  final bool submitting;
  final GroupFailure? failure;
  const CreateGroupState({this.submitting = false, this.failure});
}

class CreateGroupController extends ValueNotifier<CreateGroupState> {
  final GroupRepository repository;
  CreateGroupController(this.repository) : super(const CreateGroupState());
  Future<GroupDetail?> submit(CreateGroupRequest request) async {
    if (value.submitting) return null;
    value = const CreateGroupState(submitting: true);
    try {
      final created = await repository.createGroup(request);
      final detail = await repository.getGroup(created.id);
      value = const CreateGroupState();
      return detail;
    } on GroupException catch (e) {
      value = CreateGroupState(failure: e.failure);
      return null;
    }
  }
}
