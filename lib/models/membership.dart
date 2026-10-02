class Membership {
  const Membership({
    required this.effectivePlan,
    required this.subscriptionStatus,
    this.periodStart,
    this.periodEnd,
  });
  final String effectivePlan;
  final String subscriptionStatus;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  factory Membership.fromJson(Map<String, dynamic> json) => Membership(
    effectivePlan: json['effective_plan']?.toString() ?? 'free',
    subscriptionStatus: json['subscription_status']?.toString() ?? 'inactive',
    periodStart: DateTime.tryParse(json['period_start']?.toString() ?? ''),
    periodEnd: DateTime.tryParse(json['period_end']?.toString() ?? ''),
  );
  bool get isPremium =>
      effectivePlan == 'premium' &&
      ['active', 'canceled'].contains(subscriptionStatus) &&
      periodStart != null &&
      periodEnd != null &&
      !periodStart!.isAfter(DateTime.now()) &&
      periodEnd!.isAfter(DateTime.now());
}
