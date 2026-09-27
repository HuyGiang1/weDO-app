enum PollType { singleChoice, multipleChoice }

enum PollStatus { open, closed }

enum VoteVisibility { public, anonymous }

enum ResultVisibility { immediate, afterClose }

extension PollTypeWire on PollType {
  String get wire =>
      this == PollType.singleChoice ? 'SINGLE_CHOICE' : 'MULTIPLE_CHOICE';
  static PollType parse(String v) =>
      v == 'MULTIPLE_CHOICE' ? PollType.multipleChoice : PollType.singleChoice;
}

extension PollStatusWire on PollStatus {
  static PollStatus parse(String v) =>
      v == 'CLOSED' ? PollStatus.closed : PollStatus.open;
}

extension VoteVisibilityWire on VoteVisibility {
  String get wire => this == VoteVisibility.public ? 'PUBLIC' : 'ANONYMOUS';
  static VoteVisibility parse(String v) =>
      v == 'ANONYMOUS' ? VoteVisibility.anonymous : VoteVisibility.public;
}

extension ResultVisibilityWire on ResultVisibility {
  String get wire =>
      this == ResultVisibility.immediate ? 'IMMEDIATE' : 'AFTER_CLOSE';
  static ResultVisibility parse(String v) => v == 'AFTER_CLOSE'
      ? ResultVisibility.afterClose
      : ResultVisibility.immediate;
}

class PollOption {
  final String id, text;
  final int sortOrder, voteCount;
  final bool disabled, canEdit, canDisable, canDelete;
  final String? createdBy;
  const PollOption({
    required this.id,
    required this.text,
    required this.sortOrder,
    required this.voteCount,
    required this.disabled,
    required this.canEdit,
    required this.canDisable,
    required this.canDelete,
    this.createdBy,
  });
  factory PollOption.fromJson(Map<String, dynamic> j) => PollOption(
    id: j['id'] as String,
    text: j['text'] as String,
    sortOrder: (j['sortOrder'] as num).toInt(),
    voteCount: (j['voteCount'] as num? ?? 0).toInt(),
    disabled: j['disabled'] as bool? ?? false,
    canEdit: j['canEdit'] as bool? ?? false,
    canDisable: j['canDisable'] as bool? ?? false,
    canDelete: j['canDelete'] as bool? ?? false,
    createdBy: j['createdBy'] as String?,
  );
}

class PollPermissions {
  final bool canVote, canAddOption, canClose, canViewVoters;
  const PollPermissions({
    required this.canVote,
    required this.canAddOption,
    required this.canClose,
    required this.canViewVoters,
  });
  factory PollPermissions.fromJson(Map<String, dynamic>? json) =>
      PollPermissions(
        canVote: json?['canVote'] as bool? ?? false,
        canAddOption: json?['canAddOption'] as bool? ?? false,
        canClose: json?['canClose'] as bool? ?? false,
        canViewVoters: json?['canViewVoters'] as bool? ?? false,
      );
}

class Poll {
  final String id, activityId, createdBy, question;
  final PollType type;
  final bool allowMemberAddOption, resultsVisible;
  final int? maxSelections;
  final VoteVisibility voteVisibility;
  final ResultVisibility resultVisibility;
  final PollStatus status;
  final DateTime? deadlineAt, closedAt;
  final String? closedBy;
  final List<PollOption> options;
  final List<String> callerOptionIds;
  final PollPermissions permissions;
  const Poll({
    required this.id,
    required this.activityId,
    required this.createdBy,
    required this.question,
    required this.type,
    required this.allowMemberAddOption,
    required this.resultsVisible,
    this.maxSelections,
    required this.voteVisibility,
    required this.resultVisibility,
    required this.status,
    this.deadlineAt,
    this.closedAt,
    this.closedBy,
    required this.options,
    required this.callerOptionIds,
    required this.permissions,
  });
  factory Poll.fromJson(Map<String, dynamic> j) => Poll(
    id: j['id'] as String,
    activityId: j['activityId'] as String,
    createdBy: j['createdBy'] as String,
    question: j['question'] as String,
    type: PollTypeWire.parse(j['pollType'] as String),
    allowMemberAddOption: j['allowMemberAddOption'] as bool? ?? false,
    resultsVisible: j['resultsVisible'] as bool? ?? false,
    maxSelections: (j['maxSelections'] as num?)?.toInt(),
    voteVisibility: VoteVisibilityWire.parse(j['voteVisibility'] as String),
    resultVisibility: ResultVisibilityWire.parse(
      j['resultVisibility'] as String,
    ),
    status: PollStatusWire.parse(j['status'] as String),
    deadlineAt: j['deadlineAt'] == null
        ? null
        : DateTime.parse(j['deadlineAt'] as String),
    closedAt: j['closedAt'] == null
        ? null
        : DateTime.parse(j['closedAt'] as String),
    closedBy: j['closedBy'] as String?,
    options: (j['options'] as List? ?? const [])
        .map((e) => PollOption.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    callerOptionIds: (j['callerOptionIds'] as List? ?? const []).cast<String>(),
    permissions: PollPermissions.fromJson(
      j['permissions'] is Map
          ? Map<String, dynamic>.from(j['permissions'] as Map)
          : null,
    ),
  );
}

class CreatePollDraft {
  final String question;
  final List<String> options;
  final bool allowMemberAddOption, anonymous, showResultsImmediately;
  final DateTime? deadlineAt;
  const CreatePollDraft({
    required this.question,
    required this.options,
    required this.allowMemberAddOption,
    required this.anonymous,
    required this.showResultsImmediately,
    this.deadlineAt,
  });
  Map<String, dynamic> toJson() => {
    'question': question,
    'pollType': PollType.singleChoice.wire,
    'options': options,
    'allowMemberAddOption': allowMemberAddOption,
    'voteVisibility': anonymous ? 'ANONYMOUS' : 'PUBLIC',
    'resultVisibility': showResultsImmediately ? 'IMMEDIATE' : 'AFTER_CLOSE',
    'deadlineAt': deadlineAt?.toUtc().toIso8601String(),
  };
}

class PollVoters {
  final String optionId;
  final List<String> userIds;
  const PollVoters(this.optionId, this.userIds);
  factory PollVoters.fromJson(Map<String, dynamic> j) => PollVoters(
    j['optionId'] as String,
    (j['userIds'] as List? ?? const []).cast<String>(),
  );
}
