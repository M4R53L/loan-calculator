/// Represents the complete calculation result of a loan
class LoanResult {
  final double principal;
  final double prime;
  final double margin;
  final double annualRate;
  final int months;
  final double monthlyPayment;
  final double totalPaid;
  final double totalInterest;
  final List<AmortizationRow>? schedule;

  LoanResult({
    required this.principal,
    required this.prime,
    required this.margin,
    required this.annualRate,
    required this.months,
    required this.monthlyPayment,
    required this.totalPaid,
    required this.totalInterest,
    this.schedule,
  });

  double get monthlyRate => annualRate / 100 / 12;

  @override
  String toString() {
    return 'LoanResult(principal: ₪$principal, rate: $annualRate%, '
        'months: $months, payment: ₪$monthlyPayment)';
  }
}

/// Represents one row in an amortization schedule
class AmortizationRow {
  final int month;
  final double payment;
  final double interestPortion;
  final double principalPortion;
  final double remainingBalance;

  AmortizationRow({
    required this.month,
    required this.payment,
    required this.interestPortion,
    required this.principalPortion,
    required this.remainingBalance,
  });
}
