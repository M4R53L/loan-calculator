import 'dart:math';
import '../models/loan_result.dart';

/// Core loan calculation engine
class LoanCalculator {
  /// Calculate monthly payment using standard amortization formula
  /// PMT = P × r / (1 − (1 + r)^(−n))
  static double calculateMonthlyPayment({
    required double principal,
    required double annualRatePercent,
    required int months,
  }) {
    if (principal <= 0 || months <= 0) {
      return 0.0;
    }

    // Zero interest case - simple division
    if (annualRatePercent <= 0) {
      return principal / months;
    }

    // Convert annual percentage to monthly decimal rate
    final double monthlyRate = (annualRatePercent / 100) / 12;

    // Standard amortization formula
    final double payment = principal *
        monthlyRate /
        (1 - pow(1 + monthlyRate, -months));

    return payment;
  }

  /// Calculate complete loan details
  static LoanResult calculate({
    required double principal,
    required double prime,
    required double margin,
    required int months,
    bool generateSchedule = false,
  }) {
    final double annualRate = prime + margin;
    final double monthlyPayment = calculateMonthlyPayment(
      principal: principal,
      annualRatePercent: annualRate,
      months: months,
    );

    final double totalPaid = monthlyPayment * months;
    final double totalInterest = totalPaid - principal;

    List<AmortizationRow>? schedule;
    if (generateSchedule) {
      schedule = _generateAmortizationSchedule(
        principal: principal,
        annualRatePercent: annualRate,
        months: months,
        monthlyPayment: monthlyPayment,
      );
    }

    return LoanResult(
      principal: principal,
      prime: prime,
      margin: margin,
      annualRate: annualRate,
      months: months,
      monthlyPayment: monthlyPayment,
      totalPaid: totalPaid,
      totalInterest: totalInterest,
      schedule: schedule,
    );
  }

  /// Generate full amortization schedule showing month-by-month breakdown
  static List<AmortizationRow> _generateAmortizationSchedule({
    required double principal,
    required double annualRatePercent,
    required int months,
    required double monthlyPayment,
  }) {
    final List<AmortizationRow> schedule = [];
    double remainingBalance = principal;
    final double monthlyRate = (annualRatePercent / 100) / 12;

    for (int month = 1; month <= months; month++) {
      // Calculate interest on remaining balance
      final double interestPortion = remainingBalance * monthlyRate;
      
      // Principal portion is payment minus interest
      double principalPortion = monthlyPayment - interestPortion;
      
      // Handle last payment rounding issues
      if (month == months) {
        principalPortion = remainingBalance;
      }
      
      remainingBalance -= principalPortion;
      
      // Ensure balance doesn't go negative due to rounding
      if (remainingBalance < 0.01) {
        remainingBalance = 0;
      }

      schedule.add(AmortizationRow(
        month: month,
        payment: monthlyPayment,
        interestPortion: interestPortion,
        principalPortion: principalPortion,
        remainingBalance: remainingBalance,
      ));
    }

    return schedule;
  }

  /// Validate input values
  static String? validateInputs({
    required double principal,
    required double prime,
    required double margin,
    required int months,
  }) {
    if (principal <= 0) {
      return 'Principal must be greater than zero';
    }
    if (principal > 10000000) {
      return 'Principal exceeds maximum allowed';
    }
    if (prime < 0) {
      return 'Prime rate cannot be negative';
    }
    if (margin < 0) {
      return 'Margin rate cannot be negative';
    }
    if (prime + margin > 50) {
      return 'Total interest rate seems unreasonably high';
    }
    if (months <= 0) {
      return 'Number of months must be greater than zero';
    }
    if (months > 360) {
      return 'Loan term exceeds 30 years';
    }
    return null;
  }
}
