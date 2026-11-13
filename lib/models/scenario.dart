import 'loan_result.dart';

/// A loan the user pinned, to compare the current inputs against.
class SavedScenario {
  const SavedScenario({
    required this.principal,
    required this.months,
    required this.repaymentType,
    required this.annualRate,
    required this.monthlyPayment,
    required this.totalPaid,
  });

  factory SavedScenario.fromResult(LoanResult r) => SavedScenario(
        principal: r.principal,
        months: r.months,
        repaymentType: r.repaymentType,
        annualRate: r.annualRate,
        monthlyPayment: r.monthlyPayment,
        totalPaid: r.totalPaid,
      );

  final double principal;
  final int months;
  final RepaymentType repaymentType;
  final double annualRate;
  final double monthlyPayment;
  final double totalPaid;

  Map<String, Object> toJson() => {
        'principal': principal,
        'months': months,
        'type': repaymentType.name,
        'rate': annualRate,
        'monthly': monthlyPayment,
        'total': totalPaid,
      };

  static SavedScenario? fromJson(Map<String, dynamic> j) {
    try {
      return SavedScenario(
        principal: (j['principal'] as num).toDouble(),
        months: j['months'] as int,
        repaymentType: RepaymentType.values.byName(j['type'] as String),
        annualRate: (j['rate'] as num).toDouble(),
        monthlyPayment: (j['monthly'] as num).toDouble(),
        totalPaid: (j['total'] as num).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }
}
