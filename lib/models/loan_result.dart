/// How the loan principal is repaid
enum RepaymentType {
  /// Fixed monthly payment of principal + interest (שפיצר)
  spitzer,

  /// Interest-only monthly payments, full principal at the end (בלון)
  balloon,

  /// No payments for the first months; the accrued interest is added to the
  /// balance and repaid with it over the remaining months (גרייס)
  grace,
}

/// Represents the complete calculation result of a loan
class LoanResult {
  final double principal;
  final double prime;
  final double margin;
  final double annualRate;
  final int months;
  final RepaymentType repaymentType;
  final int graceMonths;

  /// One-time file-opening fee (עמלת פתיחת תיק)
  final double fee;

  /// Assumed yearly CPI change for a CPI-linked loan (0 = not linked)
  final double annualInflationPercent;

  /// The regular monthly payment: the Spitzer payment, the payment after the
  /// grace period, or the interest-only payment of a balloon loan.
  /// For a CPI-linked loan this is the first payment; later ones grow with CPI.
  final double monthlyPayment;

  /// The last payment (for a balloon loan this includes the whole principal)
  final double finalPayment;

  /// Sum of all monthly payments
  final double totalInstallments;

  /// Total CPI linkage added to the balance over the loan
  final double totalLinkage;

  /// Total interest paid
  final double totalInterest;

  /// Everything the customer pays: all payments + fee
  final double totalPaid;

  /// Effective annual cost of credit including fees (עלות אשראי שנתית), in %
  final double? effectiveAnnualCost;

  final List<AmortizationRow>? schedule;

  LoanResult({
    required this.principal,
    required this.prime,
    required this.margin,
    required this.annualRate,
    required this.months,
    required this.repaymentType,
    required this.graceMonths,
    required this.fee,
    required this.annualInflationPercent,
    required this.monthlyPayment,
    required this.finalPayment,
    required this.totalInstallments,
    required this.totalLinkage,
    required this.totalInterest,
    required this.totalPaid,
    required this.effectiveAnnualCost,
    this.schedule,
  });

  double get monthlyRate => annualRate / 100 / 12;

  bool get isCpiLinked => annualInflationPercent != 0;

  @override
  String toString() {
    return 'LoanResult(principal: ₪$principal, rate: $annualRate%, '
        'months: $months, type: ${repaymentType.name}, '
        'payment: ₪$monthlyPayment, effective: $effectiveAnnualCost%)';
  }
}

/// Represents one row in an amortization schedule
class AmortizationRow {
  final int month;
  final double payment;
  final double interestPortion;
  final double principalPortion;

  /// CPI linkage added to the balance this month
  final double linkage;
  final double remainingBalance;

  AmortizationRow({
    required this.month,
    required this.payment,
    required this.interestPortion,
    required this.principalPortion,
    this.linkage = 0,
    required this.remainingBalance,
  });
}
