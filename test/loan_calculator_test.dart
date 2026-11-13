import 'package:flutter_test/flutter_test.dart';
import 'package:loan_calculator/models/loan_result.dart';
import 'package:loan_calculator/services/loan_calculator.dart';

void main() {
  group('LoanCalculator Tests', () {
    test('Golden Test Case 1: 76,500 ILS, 9.1%, 60 months', () {
      final result = LoanCalculator.calculate(
        principal: 76500,
        prime: 4.5,
        margin: 4.6,
        months: 60,
      );

      expect(result.annualRate, equals(9.1));
      expect(result.monthlyPayment, closeTo(1591.73, 0.5));
      expect(result.totalInterest, closeTo(19003.77, 50));
    });

    test('Golden Test Case 2: 20,000 ILS, 7%, 48 months', () {
      final result = LoanCalculator.calculate(
        principal: 20000,
        prime: 4,
        margin: 3,
        months: 48,
      );

      expect(result.annualRate, equals(7.0));
      expect(result.monthlyPayment, closeTo(478.92, 0.5));
      expect(result.totalInterest, closeTo(2988.39, 50));
    });

    test('Golden Test Case 3: 50,000 ILS, 6.7%, 60 months', () {
      final result = LoanCalculator.calculate(
        principal: 50000,
        prime: 1.6,
        margin: 5.1,
        months: 60,
      );

      expect(result.annualRate, closeTo(6.7, 0.1));
      expect(result.monthlyPayment, closeTo(983.00, 0.5));
      expect(result.totalInterest, closeTo(8979.89, 50));
    });

    test('Zero interest case', () {
      final result = LoanCalculator.calculate(
        principal: 20000,
        prime: 0,
        margin: 0,
        months: 48,
      );

      expect(result.monthlyPayment, closeTo(416.67, 0.01));
      expect(result.totalInterest, closeTo(0, 0.01));
    });

    test('Amortization schedule generation', () {
      final result = LoanCalculator.calculate(
        principal: 10000,
        prime: 2,
        margin: 3,
        months: 12,
        generateSchedule: true,
      );

      expect(result.schedule, isNotNull);
      expect(result.schedule!.length, equals(12));
      expect(result.schedule!.first.month, equals(1));
      expect(result.schedule!.last.month, equals(12));
      expect(result.schedule!.last.remainingBalance, closeTo(0, 1));
    });

    test('Mimun Yashir example: ₪30,000, 8.5%, 55 payments, ₪490 fee', () {
      // Published: total cost 9.66%, total customer payments ₪36,817
      final result = LoanCalculator.calculate(
        principal: 30000,
        prime: 4.75,
        margin: 3.75,
        months: 55,
        fee: 490,
      );

      expect(result.monthlyPayment, closeTo(660.51, 0.05));
      expect(result.totalPaid, closeTo(36817, 2));
      expect(result.effectiveAnnualCost, closeTo(9.66, 0.02));
    });

    test('No fee: effective annual cost equals compounded nominal rate', () {
      final result = LoanCalculator.calculate(
        principal: 50000,
        prime: 6,
        margin: 0,
        months: 36,
      );
      // (1 + 0.06/12)^12 - 1 = 6.1678%
      expect(result.effectiveAnnualCost, closeTo(6.1678, 0.001));
    });

    test('Balloon: interest-only payments, principal at the end', () {
      final result = LoanCalculator.calculate(
        principal: 60000,
        prime: 4,
        margin: 2,
        months: 24,
        repaymentType: RepaymentType.balloon,
        generateSchedule: true,
      );

      expect(result.monthlyPayment, closeTo(300, 0.01)); // 60,000 × 0.5%
      expect(result.finalPayment, closeTo(60300, 0.01));
      expect(result.totalInterest, closeTo(300 * 24, 0.01));
      expect(result.schedule!.last.remainingBalance, closeTo(0, 0.01));
    });

    test('Grace: Mimun Yashir example ₪65,000, 24 months → ~₪3,430', () {
      // 3 months without payments, then 21 payments. ~9% reproduces their figure.
      final result = LoanCalculator.calculate(
        principal: 65000,
        prime: 4.75,
        margin: 4.25,
        months: 24,
        repaymentType: RepaymentType.grace,
        generateSchedule: true,
      );

      final schedule = result.schedule!;
      expect(schedule.take(3).every((row) => row.payment == 0), isTrue);
      expect(schedule[2].remainingBalance, closeTo(65000 * 1.0075 * 1.0075 * 1.0075, 0.01));
      expect(result.graceMonths, equals(3));
      expect(result.monthlyPayment, closeTo(3433, 2));
      expect(schedule.last.remainingBalance, closeTo(0, 0.01));
      // Grace costs more interest than a regular loan
      final regular = LoanCalculator.calculate(
          principal: 65000, prime: 4.75, margin: 4.25, months: 24);
      expect(result.totalInterest, greaterThan(regular.totalInterest));
    });

    test('CPI-linked: payments grow with inflation and balance clears', () {
      final linked = LoanCalculator.calculate(
        principal: 30000,
        prime: 4.75,
        margin: 3.75,
        months: 55,
        annualInflationPercent: 3,
        generateSchedule: true,
      );
      final unlinked = LoanCalculator.calculate(
          principal: 30000, prime: 4.75, margin: 3.75, months: 55);

      final schedule = linked.schedule!;
      expect(schedule.last.payment, greaterThan(schedule.first.payment));
      expect(schedule.last.remainingBalance, closeTo(0, 0.01));
      expect(linked.totalLinkage, greaterThan(0));
      expect(linked.totalPaid, greaterThan(unlinked.totalPaid));
      // Interest itself stays a separate figure from linkage
      expect(linked.totalInstallments,
          closeTo(30000 + linked.totalInterest + linked.totalLinkage, 0.01));
    });

    test('Input validation - negative principal', () {
      final error = LoanCalculator.validateInputs(
        principal: -1000,
        prime: 2,
        margin: 3,
        months: 12,
      );

      expect(error, isNotNull);
      expect(error, contains('greater than zero'));
    });

    test('Input validation - excessive rate', () {
      final error = LoanCalculator.validateInputs(
        principal: 20000,
        prime: 30,
        margin: 25,
        months: 12,
      );

      expect(error, isNotNull);
      expect(error, contains('unreasonably high'));
    });

    test('Input validation - Mimun Yashir limits', () {
      String? validate({double principal = 50000, int months = 60, double fee = 0}) =>
          LoanCalculator.validateInputs(
            principal: principal,
            prime: 4.75,
            margin: 3,
            months: months,
            fee: fee,
          );

      expect(validate(principal: 10000), contains('Minimum loan'));
      expect(validate(principal: 500000), contains('exceeds maximum'));
      expect(validate(months: 6), contains('Minimum term'));
      expect(validate(months: 120), contains('Maximum term'));
      expect(validate(fee: -1), contains('negative'));
      expect(validate(fee: 490), isNull);
    });

    test('Input validation - valid inputs', () {
      final error = LoanCalculator.validateInputs(
        principal: 50000,
        prime: 2,
        margin: 4,
        months: 60,
      );

      expect(error, isNull);
    });
  });
}
