import 'package:flutter/material.dart';

import '../controllers/dashboard_controller.dart';
import '../theme/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  final DashboardController dashboardController;

  const AnalyticsDashboardScreen({
    super.key,
    required this.dashboardController,
  });

  @override
  State<AnalyticsDashboardScreen> createState() =>
      _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState
    extends State<AnalyticsDashboardScreen> {
  late Future<List<dynamic>> _dashboardFuture;

  @override
  void initState() {
    super.initState();

    _dashboardFuture = Future.wait([
      widget.dashboardController.loadBq1(),
      widget.dashboardController.loadBq2(),
      widget.dashboardController.loadBq3(),
      widget.dashboardController.loadBq4(),
      widget.dashboardController.loadBq5(),
      widget.dashboardController.loadBq6(),
    ]);
  }

  Future<void> _refresh() async {
    setState(() {
      _dashboardFuture = Future.wait([
        widget.dashboardController.loadBq1(),
        widget.dashboardController.loadBq2(),
        widget.dashboardController.loadBq3(),
        widget.dashboardController.loadBq4(),
        widget.dashboardController.loadBq5(),
        widget.dashboardController.loadBq6(),
      ]);
    });

    await _dashboardFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FutureBuilder<List<dynamic>>(
          future: _dashboardFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Error loading dashboard:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final data = snapshot.data!;

            final bq1 =
                data[0] as List<Map<String, dynamic>>;
            final bq2 =
                data[1] as List<Map<String, dynamic>>;
            final bq3 =
                data[2] as List<Map<String, dynamic>>;
            final bq4 =
                data[3] as List<Map<String, dynamic>>;
            final bq5 =
                data[4] as List<Map<String, dynamic>>;
            final bq6 =
                data[5] as List<Map<String, dynamic>>;
            final totalStarts = bq1.fold<int>(
              0,
              (sum, row) =>
                  sum +
                  ((row['parking_sessions_started'] ?? 0) as num)
                      .toInt(),
            );

            final totalCompleted = bq2.fold<int>(
              0,
              (sum, row) =>
                  sum +
                  ((row['completed_sessions'] ?? 0) as num)
                      .toInt(),
            );

            final totalFavorites = bq4.isEmpty
                ? 0
                : ((bq4.first['favorite_add_events'] ?? 0) as num)
                    .toInt();
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  24,
                  24,
                  24,
                  40,
                ),
                children: [
                  const Text(
                    'ParkU Analytics',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkText,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Business Questions Dashboard',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.greyText,
                    ),
                  ),
  
                  const SizedBox(height: 28),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _KpiCard(
                        title: 'Parking starts',
                        value: totalStarts.toString(),
                        subtitle: 'Last 7 days',
                      ),
                      
                      _KpiCard(
                        title: 'Top 3 completed',
                        value: totalCompleted.toString(),
                        subtitle: 'Last 7 days',
                      ),
                      
                      _KpiCard(
                        title: 'Favorite additions',
                        value: totalFavorites.toString(),
                        subtitle: 'Last 7 days',
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),


                  _DashboardCard(
                    title:
                        'BQ1 · Parking starts by day',
                    child: _Bq1Content(data: bq1),
                  ),

                  const SizedBox(height: 18),

                  _DashboardCard(
                    title:
                        'BQ2 · Top completed parking lots',
                    child: _Bq2Content(data: bq2),
                  ),

                  const SizedBox(height: 18),

                  _DashboardCard(
                    title:
                        'BQ3 · Parking flow abandonment',
                    child: _Bq3Content(data: bq3),
                  ),

                  const SizedBox(height: 18),

                  _DashboardCard(
                    title:
                        'BQ4 · Favorite additions',
                    child: _Bq4Content(data: bq4),
                  ),

                  const SizedBox(height: 18),

                  _DashboardCard(
                    title:
                        'BQ5 · Action usage',
                    child: _Bq5Content(data: bq5),
                  ),

                  const SizedBox(height: 18),

                  _DashboardCard(
                    title:
                        'BQ6 · Top parking by time slot',
                    child: _Bq6Content(data: bq6),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _DashboardCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.darkText,
            ),
          ),

          const SizedBox(height: 16),

          child,
        ],
      ),
    );
  }
}

class _Bq1Content extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const _Bq1Content({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Text(
        'No data available.',
        style: TextStyle(
          color: AppColors.greyText,
        ),
      );
    }

    final maxValue = data
        .map(
          (row) =>
              (row['parking_sessions_started'] as num).toDouble(),
        )
        .reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 230,
      child: BarChart(
        BarChartData(
          maxY: maxValue + 1,
          alignment: BarChartAlignment.spaceAround,

          borderData: FlBorderData(
            show: false,
          ),

          gridData: const FlGridData(
            show: false,
          ),

          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(
                showTitles: false,
              ),
            ),

            rightTitles: const AxisTitles(
              sideTitles: SideTitles(
                showTitles: false,
              ),
            ),

            leftTitles: const AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
              ),
            ),

            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();

                  if (index < 0 ||
                      index >= data.length) {
                    return const SizedBox.shrink();
                  }

                  final date =
                      data[index]['day'].toString();

                  final label =
                      date.length >= 10
                          ? date.substring(5, 10)
                          : date;

                  return Padding(
                    padding:
                        const EdgeInsets.only(
                      top: 8,
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        color:
                            AppColors.greyText,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          barGroups:
              List.generate(data.length, (index) {
            final value =
                (data[index]
                            ['parking_sessions_started']
                        as num)
                    .toDouble();

            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: value,
                  width: 22,
                  borderRadius:
                      BorderRadius.circular(6),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _Bq2Content extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const _Bq2Content({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Text(
        'No data available.',
        style: TextStyle(
          color: AppColors.greyText,
        ),
      );
    }

    return Column(
      children:
          List.generate(data.length, (index) {
        final row = data[index];

        return Container(
          margin:
              const EdgeInsets.only(bottom: 10),
          padding:
              const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius:
                BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration:
                    const BoxDecoration(
                  color: AppColors.lightPurple,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '#${index + 1}',
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w700,
                    color:
                        AppColors.primary,
                  ),
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Text(
                  row['parking_name']
                      .toString(),
                  style:
                      const TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w600,
                    color:
                        AppColors.darkText,
                  ),
                ),
              ),

              Text(
                '${row['completed_sessions']}',
                style:
                    const TextStyle(
                  fontSize: 20,
                  fontWeight:
                      FontWeight.w700,
                  color:
                      AppColors.primary,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _Bq3Content extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const _Bq3Content({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Text(
        'No data available.',
        style: TextStyle(
          color: AppColors.greyText,
        ),
      );
    }

    final maxValue = data
        .map(
          (row) =>
              (row['abandonment_count'] as num)
                  .toDouble(),
        )
        .reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 240,
      child: BarChart(
        BarChartData(
          maxY: maxValue + 1,
          alignment:
              BarChartAlignment.spaceAround,

          borderData: FlBorderData(
            show: false,
          ),

          gridData: const FlGridData(
            show: false,
          ),

          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles:
                  SideTitles(showTitles: false),
            ),

            rightTitles: const AxisTitles(
              sideTitles:
                  SideTitles(showTitles: false),
            ),

            leftTitles: const AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
              ),
            ),

            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 54,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();

                  if (index < 0 ||
                      index >= data.length) {
                    return const SizedBox.shrink();
                  }

                  final flowStep =
                    data[index]['flow_step'].toString();

                  final label =
                    flowStep.contains('Parking details')
                        ? 'Details →\nPickup'
                        : 'Pickup →\nStart';

                  return Padding(
                    padding:
                        const EdgeInsets.only(
                      top: 8,
                    ),
                    child: Text(
                      label,
                      textAlign:
                          TextAlign.center,
                      style:
                          const TextStyle(
                        fontSize: 11,
                        color:
                            AppColors.greyText,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          barGroups:
              List.generate(data.length, (index) {
            final value =
                (data[index]
                            ['abandonment_count']
                        as num)
                    .toDouble();

            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: value,
                  width: 38,
                  borderRadius:
                      BorderRadius.circular(8),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _Bq4Content extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const _Bq4Content({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final value = data.isEmpty
        ? 0
        : data.first['favorite_add_events'] ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.lightPurple,
        borderRadius:
            BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            'Favorite additions',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.darkText,
            ),
          ),

          const SizedBox(height: 4),

          const Text(
            'Last 7 days',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.greyText,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bq5Content extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const _Bq5Content({
    required this.data,
  });

  String _shortName(String event) {
    switch (event) {
      case 'pickup_time_changed':
        return 'Pickup';
      case 'navigation_opened':
        return 'Navigation';
      case 'favorite_added':
        return 'Favorite';
      case 'parking_ended':
        return 'End';
      default:
        return event;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Text(
        'No data available.',
        style: TextStyle(
          color: AppColors.greyText,
        ),
      );
    }

    final maxValue = data
        .map(
          (row) =>
              (row['usage_count'] as num)
                  .toDouble(),
        )
        .reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 240,
      child: BarChart(
        BarChartData(
          maxY: maxValue + 1,

          alignment:
              BarChartAlignment.spaceAround,

          borderData: FlBorderData(
            show: false,
          ),

          gridData: const FlGridData(
            show: false,
          ),

          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles:
                  SideTitles(showTitles: false),
            ),

            rightTitles: const AxisTitles(
              sideTitles:
                  SideTitles(showTitles: false),
            ),

            leftTitles: const AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
              ),
            ),

            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();

                  if (index < 0 ||
                      index >= data.length) {
                    return const SizedBox.shrink();
                  }

                  return Padding(
                    padding:
                        const EdgeInsets.only(
                      top: 8,
                    ),
                    child: Text(
                      _shortName(
                        data[index]
                                ['event_type']
                            .toString(),
                      ),
                      style:
                          const TextStyle(
                        fontSize: 10,
                        color:
                            AppColors.greyText,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          barGroups:
              List.generate(data.length, (index) {
            final value =
                (data[index]['usage_count']
                        as num)
                    .toDouble();

            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: value,
                  width: 28,
                  borderRadius:
                      BorderRadius.circular(7),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _Bq6Content extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const _Bq6Content({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Text(
        'No data available.',
        style: TextStyle(
          color: AppColors.greyText,
        ),
      );
    }

    final maxStarts = data
      .map(
        (row) =>
            (row['parking_starts'] as num).toDouble(),
      )
      .reduce((a, b) => a > b ? a : b);

    return Column(
      children: data.map(
        (row) {
          final starts =
              (row['parking_starts'] as num).toDouble();

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        row['time_slot'].toString(),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.greyText,
                        ),
                      ),
                    ),
                    Text(
                      '${row['parking_starts']} starts',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                Text(
                  row['parking_name'].toString(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkText,
                  ),
                ),

                const SizedBox(height: 10),

                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: maxStarts == 0
                        ? 0
                        : starts / maxStarts,
                    minHeight: 9,
                    backgroundColor: AppColors.lightPurple,
                  ),
                ),
              ],
            ),
          );
        },
      ).toList(),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.greyText,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            value,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.greyText,
            ),
          ),
        ],
      ),
    );
  }
}