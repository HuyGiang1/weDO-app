import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/poll/data/poll_models.dart';

void main() {
  test('Poll parses the server visibility and caller vote state', () {
    final poll = Poll.fromJson({
      'id': 'poll-1',
      'activityId': 'activity-1',
      'createdBy': 'user-1',
      'question': 'Where?',
      'pollType': 'MULTIPLE_CHOICE',
      'allowMemberAddOption': true,
      'maxSelections': 2,
      'voteVisibility': 'ANONYMOUS',
      'resultVisibility': 'AFTER_CLOSE',
      'status': 'OPEN',
      'resultsVisible': false,
      'options': [
        {
          'id': 'option-1',
          'text': 'A',
          'sortOrder': 0,
          'disabled': false,
          'voteCount': 3,
        },
      ],
      'callerOptionIds': ['option-1'],
    });

    expect(poll.type, PollType.multipleChoice);
    expect(poll.voteVisibility, VoteVisibility.anonymous);
    expect(poll.resultsVisible, isFalse);
    expect(poll.callerOptionIds, ['option-1']);
  });

  test('CreatePollDraft always sends the single-choice consumer contract', () {
    final data = CreatePollDraft(
      question: 'Question',
      options: const ['A', 'B'],
      allowMemberAddOption: false,
      anonymous: true,
      showResultsImmediately: false,
    ).toJson();
    expect(data['pollType'], 'SINGLE_CHOICE');
    expect(data.containsKey('maxSelections'), isFalse);
    expect(data['voteVisibility'], 'ANONYMOUS');
    expect(data['resultVisibility'], 'AFTER_CLOSE');
  });

  test('CreatePollDraft serializes a local deadline as an Instant', () {
    final deadline = DateTime(2030, 5, 1, 9, 30);
    final data = CreatePollDraft(
      question: 'Question',
      options: const ['A', 'B'],
      allowMemberAddOption: false,
      anonymous: false,
      showResultsImmediately: true,
      deadlineAt: deadline,
    ).toJson();

    expect(data['deadlineAt'], deadline.toUtc().toIso8601String());
    expect((data['deadlineAt'] as String).endsWith('Z'), isTrue);
  });
}
