import 'package:flutter_test/flutter_test.dart';
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
        principal: 10000,
        prime: 30,
        margin: 25,
        months: 12,
      );

      expect(error, isNotNull);
      expect(error, contains('unreasonably high'));
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
