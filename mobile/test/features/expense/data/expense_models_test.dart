import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/expense/data/expense_models.dart';

void main() {
  group('ExpenseMoney', () {
    test('parses and formats exact minor units without floating point', () {
      final money = ExpenseMoney.parseInput('123456789012345.07')!;

      expect(money.minorUnits, BigInt.parse('12345678901234507'));
      expect(money.decimal, '123456789012345.07');
      expect(money.formatted, '123.456.789.012.345,07 ₫');
    });

    test('rejects invalid precision and non-positive input', () {
      expect(ExpenseMoney.parseInput('10.001'), isNull);
      expect(ExpenseMoney.parseInput('-1.00'), isNull);
      expect(ExpenseMoney.parseInput('abc'), isNull);
      expect(ExpenseMoney.parseInput('0.00')!.isPositive, isFalse);
    });

    test(
      'accepts API decimal strings and rejects non-zero sub-cent precision',
      () {
        expect(ExpenseMoney.fromJson('42.5').decimal, '42.50');
        expect(() => ExpenseMoney.fromJson('42.501'), throwsFormatException);
      },
    );
  });

  test(
    'expense DTOs preserve permissions, shares, and exact request amounts',
    () {
      final detail = ExpenseDetail.fromJson({
        'id': 'expense-1',
        'groupId': 'group-1',
        'title': 'Dinner',
        'amount': '100.01',
        'splitMethod': 'CUSTOM_AMOUNT',
        'status': 'ACTIVE',
        'occurredAt': '2026-09-28T10:00:00Z',
        'payer': {'id': 'user-1', 'displayName': 'A'},
        'creator': {'id': 'user-1', 'displayName': 'A'},
        'permissions': {'canEdit': true, 'canCancel': false},
        'shares': [
          {'userId': 'user-2', 'displayName': 'B', 'amount': '100.01'},
        ],
        'changeHistory': [],
        'createdAt': '2026-09-28T10:00:00Z',
        'updatedAt': '2026-09-28T10:00:00Z',
      });

      expect(detail.permissions.canEdit, isTrue);
      expect(detail.permissions.canCancel, isFalse);
      expect(detail.shares.single.amount.decimal, '100.01');

      final draft = ExpenseDraft(
        title: 'Dinner',
        amount: ExpenseMoney.parseInput('100.01')!,
        payerUserId: 'user-1',
        splitMethod: 'CUSTOM_AMOUNT',
        participantUserIds: const [],
        customShares: {'user-2': ExpenseMoney.parseInput('100.01')!},
        occurredAt: DateTime.utc(2026, 9, 28, 10),
        note: null,
      );
      final json = draft.toJson();

      expect(json['amount'], '100.01');
      expect(json['shares'], [
        {'userId': 'user-2', 'amount': '100.01'},
      ]);
      expect(json['occurredAt'], '2026-09-28T10:00:00.000Z');
    },
  );

  test(
    'settlement DTOs parse permissions, status history, and request payloads',
    () {
      final item = SettlementItem.fromJson({
        'id': 'settlement-1',
        'groupId': 'group-1',
        'fromUser': {'id': 'user-2', 'displayName': 'Bob'},
        'toUser': {'id': 'user-1', 'displayName': 'Alice'},
        'amount': '40.50',
        'declarationType': 'I_PAID',
        'status': 'COMPLETED',
        'createdBy': {'id': 'user-2', 'displayName': 'Bob'},
        'completedAt': '2026-09-28T11:00:00Z',
        'permissions': {
          'canConfirm': false,
          'canReject': false,
          'canCancel': false,
        },
        'statusHistory': [
          {
            'fromStatus': null,
            'toStatus': 'PENDING',
            'changedBy': {'id': 'user-2', 'displayName': 'Bob'},
            'createdAt': '2026-09-28T10:30:00Z',
          },
          {
            'fromStatus': 'PENDING',
            'toStatus': 'COMPLETED',
            'changedBy': {'id': 'user-1', 'displayName': 'Alice'},
            'createdAt': '2026-09-28T11:00:00Z',
          },
        ],
        'createdAt': '2026-09-28T10:30:00Z',
        'updatedAt': '2026-09-28T11:00:00Z',
      });

      expect(item.amount.decimal, '40.50');
      expect(item.status, 'COMPLETED');
      expect(item.fromUser.displayName, 'Bob');
      expect(item.toUser.displayName, 'Alice');
      expect(item.statusHistory.length, 2);
      expect(item.statusHistory.first.fromStatus, isNull);
      expect(item.statusHistory.last.toStatus, 'COMPLETED');

      final draft = CreateSettlementDraft(
        declarationType: 'I_PAID',
        otherUserId: 'user-1',
        amount: ExpenseMoney.parseInput('40.50')!,
      );
      expect(draft.toJson(), {
        'declarationType': 'I_PAID',
        'otherUserId': 'user-1',
        'amount': '40.50',
      });
    },
  );
}
