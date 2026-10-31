class PickupChoiceSummary {
  final int suggested;
  final int manual;
  final int notRecorded;
  final double suggestedPercentage;
  final double manualPercentage;
  final double notRecordedPercentage;
  final DateTime updatedAt;
  final bool isFromCache;

  const PickupChoiceSummary({
    required this.suggested,
    required this.manual,
    required this.notRecorded,
    required this.suggestedPercentage,
    required this.manualPercentage,
    required this.notRecordedPercentage,
    required this.updatedAt,
    this.isFromCache = false,
  });

  int get total => suggested + manual + notRecorded;

  factory PickupChoiceSummary.fromRows(
    List<Map<String, dynamic>> rows, {
    required DateTime updatedAt,
  }) {
    final counts = {
      for (final row in rows)
        row['pickup_choice'] as String: (row['successful_starts'] as num)
            .toInt(),
    };
    final percentages = {
      for (final row in rows)
        row['pickup_choice'] as String: (row['percentage'] as num).toDouble(),
    };
    if (rows.length != 3 ||
        !counts.keys.toSet().containsAll([
          'Suggested',
          'Manual',
          'Not recorded',
        ]) ||
        counts.values.any((count) => count < 0) ||
        percentages.values.any(
          (value) => !value.isFinite || value < 0 || value > 100,
        )) {
      throw const FormatException('Invalid pickup choice summary.');
    }
    final summary = PickupChoiceSummary(
      suggested: counts['Suggested']!,
      manual: counts['Manual']!,
      notRecorded: counts['Not recorded']!,
      suggestedPercentage: percentages['Suggested']!,
      manualPercentage: percentages['Manual']!,
      notRecordedPercentage: percentages['Not recorded']!,
      updatedAt: updatedAt,
    );
    if (rows.any((row) => row['total_successful_starts'] != summary.total)) {
      throw const FormatException('Invalid pickup choice total.');
    }
    return summary;
  }

  factory PickupChoiceSummary.fromMap(Map<String, dynamic> data) {
    final summary = PickupChoiceSummary(
      suggested: data['suggested'] as int,
      manual: data['manual'] as int,
      notRecorded: data['not_recorded'] as int,
      suggestedPercentage: (data['suggested_percentage'] as num).toDouble(),
      manualPercentage: (data['manual_percentage'] as num).toDouble(),
      notRecordedPercentage: (data['not_recorded_percentage'] as num)
          .toDouble(),
      updatedAt: DateTime.parse(data['updated_at'] as String),
      isFromCache: true,
    );
    if (summary.suggested < 0 ||
        summary.manual < 0 ||
        summary.notRecorded < 0 ||
        [
          summary.suggestedPercentage,
          summary.manualPercentage,
          summary.notRecordedPercentage,
        ].any((value) => !value.isFinite || value < 0 || value > 100)) {
      throw const FormatException('Invalid saved pickup choices.');
    }
    return summary;
  }

  Map<String, dynamic> toMap() => {
    'suggested': suggested,
    'manual': manual,
    'not_recorded': notRecorded,
    'suggested_percentage': suggestedPercentage,
    'manual_percentage': manualPercentage,
    'not_recorded_percentage': notRecordedPercentage,
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };
}
