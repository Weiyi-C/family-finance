import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:family_finance_app/core/utils/format_utils.dart';
import 'package:family_finance_app/features/statistics/providers/stats_provider.dart';
import 'package:family_finance_app/features/transaction/providers/transaction_provider.dart';

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  String _selectedPeriod = 'month';
  late DateTime _selectedDate;

  static const _periodLabels = {'week': '周', 'month': '月', 'year': '年'};

  static const _categoryColors = [
    Color(0xFFFF6B6B),
    Color(0xFF4ECDC4),
    Color(0xFFFFE66D),
    Color(0xFF95E1D3),
    Color(0xFFF38181),
    Color(0xFFAA96DA),
    Color(0xFFFCBDAD),
    Color(0xFF6C5CE7),
    Color(0xFF00B894),
    Color(0xFFFD79A8),
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  void _prevPeriod() {
    setState(() {
      switch (_selectedPeriod) {
        case 'week':
          _selectedDate = _selectedDate.subtract(const Duration(days: 7));
          break;
        case 'month':
          _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1);
          break;
        case 'year':
          _selectedDate = DateTime(_selectedDate.year - 1, _selectedDate.month);
          break;
      }
    });
  }

  void _nextPeriod() {
    setState(() {
      switch (_selectedPeriod) {
        case 'week':
          _selectedDate = _selectedDate.add(const Duration(days: 7));
          break;
        case 'month':
          _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1);
          break;
        case 'year':
          _selectedDate = DateTime(_selectedDate.year + 1, _selectedDate.month);
          break;
      }
    });
  }

  String _periodTitle() {
    switch (_selectedPeriod) {
      case 'week':
        final start = _selectedDate.subtract(
          Duration(days: _selectedDate.weekday - 1),
        );
        final end = start.add(const Duration(days: 6));
        return '${start.month}月${start.day}日 - ${end.month}月${end.day}日';
      case 'month':
        return '${_selectedDate.year}年${_selectedDate.month}月';
      case 'year':
        return '${_selectedDate.year}年';
      default:
        return '';
    }
  }

  ({String start, String end}) _dateRange() {
    switch (_selectedPeriod) {
      case 'week':
        final start = _selectedDate.subtract(
          Duration(days: _selectedDate.weekday - 1),
        );
        final end = start.add(const Duration(days: 6));
        return (
          start: formatDate(start),
          end: formatDate(end),
        );
      case 'month':
        final start = DateTime(_selectedDate.year, _selectedDate.month, 1);
        final end = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
        return (
          start: formatDate(start),
          end: formatDate(end),
        );
      case 'year':
        final start = DateTime(_selectedDate.year, 1, 1);
        final end = DateTime(_selectedDate.year, 12, 31);
        return (
          start: formatDate(start),
          end: formatDate(end),
        );
      default:
        final now = DateTime.now();
        return (
          start: formatDate(DateTime(now.year, now.month, 1)),
          end: formatDate(DateTime(now.year, now.month + 1, 0)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(statsSummaryProvider(_selectedDate));
    final categoryAsync = ref.watch(statsByCategoryProvider(_selectedDate));
    final range = _dateRange();
    final dayAsync = ref.watch(
      statsByDayProvider((start: range.start, end: range.end, type: 'expense')),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('统计'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTimeSelector(),
            const SizedBox(height: 16),
            _buildOverviewCard(summaryAsync),
            const SizedBox(height: 16),
            _buildCategoryCard(categoryAsync),
            const SizedBox(height: 16),
            _buildTrendCard(dayAsync),
            const SizedBox(height: 16),
            _buildRankingCard(categoryAsync),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSelector() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: _prevPeriod,
            ),
            Text(
              _periodTitle(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _nextPeriod,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _periodLabels.entries.map((entry) {
            final selected = _selectedPeriod == entry.key;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(entry.value),
                selected: selected,
                onSelected: (_) {
                  setState(() => _selectedPeriod = entry.key);
                },
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildOverviewCard(AsyncValue<Map<String, dynamic>> summaryAsync) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '收支概览',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            summaryAsync.when(
              loading: () => const SizedBox(
                height: 60,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SizedBox(
                height: 60,
                child: Center(child: Text('加载失败: $e')),
              ),
              data: (data) {
                final income = (data['income'] as num?)?.toInt() ?? 0;
                final expense = (data['expense'] as num?)?.toInt() ?? 0;
                final balance = income - expense;
                return Row(
                  children: [
                    Expanded(
                      child: _buildStatItem('收入', formatMoney(income), Colors.green),
                    ),
                    Expanded(
                      child: _buildStatItem('支出', formatMoney(expense), Colors.red),
                    ),
                    Expanded(
                      child: _buildStatItem('结余', formatMoney(balance), Colors.blue),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String amount, Color color) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          amount,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(AsyncValue<Map<String, dynamic>> categoryAsync) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '分类占比',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            categoryAsync.when(
              loading: () => const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SizedBox(
                height: 200,
                child: Center(child: Text('加载失败: $e')),
              ),
              data: (data) {
                final items = _parseCategoryItems(data);
                if (items.isEmpty) {
                  return const SizedBox(
                    height: 200,
                    child: Center(child: Text('暂无数据')),
                  );
                }
                return Column(
                  children: [
                    SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 50,
                          sections: items.asMap().entries.map((entry) {
                            final color =
                                _categoryColors[entry.key % _categoryColors.length];
                            return PieChartSectionData(
                              value: entry.value.amount.toDouble(),
                              color: color,
                              radius: 40,
                              showTitle: false,
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: items.asMap().entries.map((entry) {
                        final color =
                            _categoryColors[entry.key % _categoryColors.length];
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              entry.value.name,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendCard(AsyncValue<Map<String, dynamic>> dayAsync) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '每日趋势',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            dayAsync.when(
              loading: () => const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SizedBox(
                height: 200,
                child: Center(child: Text('加载失败: $e')),
              ),
              data: (data) {
                final points = _parseDayPoints(data);
                if (points.isEmpty) {
                  return const SizedBox(
                    height: 200,
                    child: Center(child: Text('暂无数据')),
                  );
                }
                final maxY = points
                    .map((p) => p.$2)
                    .reduce((a, b) => a > b ? a : b)
                    .toDouble();
                return SizedBox(
                  height: 200,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: maxY > 0 ? maxY / 4 : 1,
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 50,
                            getTitlesWidget: (value, _) {
                              return Text(
                                formatMoneyShort(value.toInt()),
                                style: const TextStyle(fontSize: 10),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, _) {
                              final idx = value.toInt();
                              if (idx >= 0 && idx < points.length) {
                                return Text(
                                  '${points[idx].$1}',
                                  style: const TextStyle(fontSize: 10),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: points.asMap().entries.map((entry) {
                            return FlSpot(
                              entry.key.toDouble(),
                              entry.value.$2.toDouble(),
                            );
                          }).toList(),
                          isCurved: true,
                          color: Theme.of(context).colorScheme.primary,
                          barWidth: 2,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.1),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankingCard(AsyncValue<Map<String, dynamic>> categoryAsync) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '支出排行',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            categoryAsync.when(
              loading: () => const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SizedBox(
                height: 100,
                child: Center(child: Text('加载失败: $e')),
              ),
              data: (data) {
                final items = _parseCategoryItems(data);
                if (items.isEmpty) {
                  return const SizedBox(
                    height: 100,
                    child: Center(child: Text('暂无数据')),
                  );
                }
                final total = items.fold<int>(0, (sum, item) => sum + item.amount);
                return Column(
                  children: items.map((item) {
                    final percentage = total > 0 ? item.amount / total : 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(item.name),
                              Text(
                                '${formatMoney(item.amount)} (${(percentage * 100).toStringAsFixed(1)}%)',
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: percentage,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<_CategoryItem> _parseCategoryItems(Map<String, dynamic> data) {
    final list = data['items'] as List? ?? data['categories'] as List? ?? [];
    return list.map((item) {
      return _CategoryItem(
        name: item['category_name'] as String? ?? item['name'] as String? ?? '未知',
        amount: (item['amount'] as num?)?.toInt() ?? 0,
      );
    }).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
  }

  List<(int, int)> _parseDayPoints(Map<String, dynamic> data) {
    final list = data['items'] as List? ?? data['days'] as List? ?? [];
    return list.map((item) {
      final day = (item['day'] as num?)?.toInt() ?? 0;
      final amount = (item['amount'] as num?)?.toInt() ?? 0;
      return (day, amount);
    }).toList()
      ..sort((a, b) => a.$1.compareTo(b.$1));
  }
}

class _CategoryItem {
  final String name;
  final int amount;

  const _CategoryItem({required this.name, required this.amount});
}
