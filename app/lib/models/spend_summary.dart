class DailySpendPoint {
  final String date;
  final double amount;
  final int rides;

  DailySpendPoint({
    required this.date,
    required this.amount,
    required this.rides,
  });

  factory DailySpendPoint.fromJson(Map<String, dynamic> json) {
    return DailySpendPoint(
      date: json['date'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      rides: json['rides'] ?? 0,
    );
  }
}

class SpendSummaryModel {
  final String monthName;
  final double totalSpend;
  final int rideCount;
  final double lastMonthSpend;
  final double percentageChange;
  final List<DailySpendPoint> dailySpend;

  SpendSummaryModel({
    required this.monthName,
    required this.totalSpend,
    required this.rideCount,
    required this.lastMonthSpend,
    required this.percentageChange,
    required this.dailySpend,
  });

  factory SpendSummaryModel.fromJson(Map<String, dynamic> json) {
    return SpendSummaryModel(
      monthName: json['month_name'] ?? 'This Month',
      totalSpend: (json['total_spend'] as num?)?.toDouble() ?? 0.0,
      rideCount: json['ride_count'] ?? 0,
      lastMonthSpend: (json['last_month_spend'] as num?)?.toDouble() ?? 0.0,
      percentageChange: (json['percentage_change'] as num?)?.toDouble() ?? 0.0,
      dailySpend: (json['daily_spend'] as List<dynamic>?)
              ?.map((d) => DailySpendPoint.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
