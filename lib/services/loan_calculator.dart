import 'dart:math';
import '../models/loan_result.dart';

/// Core loan calculation engine
class LoanCalculator {
  // Limits matching Mimun Yashir's consumer / car loans
  static const double minPrincipal = 15000;
  static const double maxPrincipal = 400000;
  static const int minMonths = 12;
  static const int maxMonths = 100;

  /// Grace period length used by Mimun Yashir
  static const int defaultGraceMonths = 3;

  /// Calculate monthly payment using standard amortization formula
  /// PMT = P × r / (1 − (1 + r)^(−n))
  static double calculateMonthlyPayment({
    required double principal,
    required double annualRatePercent,
    required int months,
  }) {
    return _annuity(principal, (annualRatePercent / 100) / 12, months);
  }

  static double _annuity(double balance, double monthlyRate, int months) {
    if (balance <= 0 || months <= 0) {
      return 0.0;
    }
    // Zero interest case - simple division
    if (monthlyRate <= 0) {
      return balance / months;
    }
    return balance * monthlyRate / (1 - pow(1 + monthlyRate, -months));
  }

  /// Calculate complete loan details.
  ///
  /// The loan is simulated month by month:
  ///   1. CPI linkage: the balance is indexed by the monthly inflation.
  ///   2. Interest is charged on the (indexed) balance.
  ///   3. The payment depends on the repayment type:
  ///      - Spitzer: annuity on the current balance over the remaining months
  ///        (constant when there is no CPI linkage).
  ///      - Balloon: interest only; the last payment adds the whole balance.
  ///      - Grace: nothing during the grace months (interest is added to the
  ///        balance), then Spitzer over the remaining months.
  static LoanResult calculate({
    required double principal,
    required double prime,
    required double margin,
    required int months,
    RepaymentType repaymentType = RepaymentType.spitzer,
    double fee = 0,
    double annualInflationPercent = 0,
    int graceMonths = defaultGraceMonths,
    bool generateSchedule = false,
  }) {
    final double annualRate = prime + margin;
    final double monthlyRate = (annualRate / 100) / 12;
    final double monthlyInflation = annualInflationPercent == 0
        ? 0.0
        : pow(1 + annualInflationPercent / 100, 1 / 12).toDouble() - 1;
    final int grace =
        repaymentType == RepaymentType.grace ? min(graceMonths, months - 1) : 0;

    final List<AmortizationRow> rows = [];
    double balance = principal;
    double totalLinkage = 0;

    for (int month = 1; month <= months; month++) {
      final double linkage = balance * monthlyInflation;
      balance += linkage;
      totalLinkage += linkage;

      final double interest = balance * monthlyRate;
      final int remaining = months - month + 1;

      double payment;
      if (month <= grace) {
        payment = 0; // interest accrues and is added to the balance
      } else if (repaymentType == RepaymentType.balloon) {
        payment = month == months ? interest + balance : interest;
      } else {
        payment = _annuity(balance, monthlyRate, remaining);
      }

      // During grace the unpaid interest grows the balance
      final double principalPortion = max(0.0, payment - interest);
      balance -= payment - interest;
      if (balance.abs() < 0.01) {
        balance = 0;
      }

      rows.add(AmortizationRow(
        month: month,
        payment: payment,
        interestPortion: interest,
        principalPortion: principalPortion,
        linkage: linkage,
        remainingBalance: balance,
      ));
    }

    final double totalInstallments =
        rows.fold(0.0, (sum, row) => sum + row.payment);
    final double totalInterest = totalInstallments - principal - totalLinkage;
    final double monthlyPayment =
        rows.isEmpty ? 0 : rows[min(grace, rows.length - 1)].payment;

    return LoanResult(
      principal: principal,
      prime: prime,
      margin: margin,
      annualRate: annualRate,
      months: months,
      repaymentType: repaymentType,
      graceMonths: grace,
      fee: fee,
      annualInflationPercent: annualInflationPercent,
      monthlyPayment: monthlyPayment,
      finalPayment: rows.isEmpty ? 0 : rows.last.payment,
      totalInstallments: totalInstallments,
      totalLinkage: totalLinkage,
      totalInterest: totalInterest,
      totalPaid: totalInstallments + fee,
      effectiveAnnualCost: effectiveAnnualRate(
        netReceived: principal - fee,
        payments: rows.map((row) => row.payment).toList(),
      ),
      schedule: generateSchedule ? rows : null,
    );
  }

  /// Effective annual cost of credit (עלות אשראי שנתית כוללת), in percent.
  ///
  /// Finds the monthly rate i at which the money actually received equals the
  /// present value of all payments, then compounds it: (1 + i)^12 − 1.
  /// Returns null when it cannot be computed.
  static double? effectiveAnnualRate({
    required double netReceived,
    required List<double> payments,
  }) {
    if (netReceived <= 0 || payments.isEmpty) {
      return null;
    }

    double presentValue(double i) {
      double pv = 0;
      for (int t = 0; t < payments.length; t++) {
        pv += payments[t] / pow(1 + i, t + 1);
      }
      return pv;
    }

    // presentValue decreases as i grows, so bisection is safe
    double low = -0.5;
    double high = 1.0;
    if (presentValue(low) < netReceived || presentValue(high) > netReceived) {
      return null;
    }
    for (int iteration = 0; iteration < 200; iteration++) {
      final double mid = (low + high) / 2;
      if (presentValue(mid) > netReceived) {
        low = mid;
      } else {
        high = mid;
      }
    }
    final double monthly = (low + high) / 2;
    return (pow(1 + monthly, 12) - 1) * 100;
  }

  /// Validate input values
  static String? validateInputs({
    required double principal,
    required double prime,
    required double margin,
    required int months,
    double fee = 0,
    double annualInflationPercent = 0,
  }) {
    if (principal <= 0) {
      return 'Principal must be greater than zero';
    }
    if (principal < minPrincipal) {
      return 'Minimum loan amount is ₪15,000';
    }
    if (principal > maxPrincipal) {
      return 'Principal exceeds maximum allowed (₪400,000)';
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
    if (months < minMonths) {
      return 'Minimum term is 12 months';
    }
    if (months > maxMonths) {
      return 'Maximum term is 100 months';
    }
    if (fee < 0) {
      return 'Fee cannot be negative';
    }
    if (fee >= principal) {
      return 'Fee must be smaller than the loan amount';
    }
    if (annualInflationPercent < -10 || annualInflationPercent > 30) {
      return 'Inflation assumption must be between -10% and 30%';
    }
    return null;
  }
}
