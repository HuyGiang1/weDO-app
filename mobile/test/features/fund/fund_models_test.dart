import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/fund/data/fund_models.dart';

void main() {
  test(
    'Fund decimal strings preserve collection totals and personal amounts',
    () {
      final json = <String, dynamic>{
        'totalExpectedAmount': '1234567.89',
        'totalConfirmedAmount': '60000.00',
        'totalPendingAmount': '0.00',
        'totalRemainingAmount': '1174567.89',
        'myAmountDue': '1234567.89',
        'myConfirmedAmount': '60000.00',
        'myPendingAmount': '0.00',
        'myRemainingAmount': '1174567.89',
      };
      final summary = FundCollectionSummary.fromJson(json);
      final detail = FundCollectionDetail.fromJson(json);
      final totals = [
        summary.totalExpectedAmount,
        summary.totalConfirmedAmount,
        summary.totalPendingAmount,
        summary.totalRemainingAmount,
        detail.totalExpectedAmount,
        detail.totalConfirmedAmount,
        detail.totalPendingAmount,
        detail.totalRemainingAmount,
      ];
      expect(totals.map((amount) => amount.decimal), [
        '1234567.89',
        '60000.00',
        '0.00',
        '1174567.89',
        '1234567.89',
        '60000.00',
        '0.00',
        '1174567.89',
      ]);
      expect(summary.myAmountDue.minorUnits, BigInt.from(123456789));
      expect(summary.myConfirmedAmount.minorUnits, BigInt.from(6000000));
      expect(summary.myPendingAmount.minorUnits, BigInt.zero);
      expect(summary.myRemainingAmount.minorUnits, BigInt.from(117456789));
      expect(summary.myAmountDue.formatted, contains('1.234.567,89'));

      final fund = FundDetail.fromJson({
        'ledgerBalance': '1234567.89',
        'availableBalance': '1174567.89',
        'pendingReimbursements': '60000.00',
        'totalInflow': '1234567.89',
        'totalOutflow': '0.00',
      });
      expect(fund.ledgerBalance.decimal, '1234567.89');
      expect(fund.availableBalance.decimal, '1174567.89');
      expect(fund.pendingReimbursements.decimal, '60000.00');
      expect(fund.totalInflow.decimal, '1234567.89');
      expect(fund.totalOutflow.decimal, '0.00');
    },
  );
}
