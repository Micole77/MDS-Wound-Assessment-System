import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:verdasense/components/my_app_bar.dart';
import 'package:verdasense/screens/comparison/blocs/comparison_bloc.dart';
import 'package:verdasense/screens/comparison/blocs/comparison_event.dart';
import 'package:verdasense/screens/comparison/views/comparison_results_screen.dart';
import 'package:wound_repository/wound_repository.dart';

class ComparisonHistoryScreen extends StatelessWidget {
  const ComparisonHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppBar(title: 'Comparison History'),
      body: StreamBuilder<List<WoundComparisonModel>>(
        stream: context.read<WoundRepository>().getComparisons(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load comparison history',
                    style: TextStyle(color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final comparisons = snapshot.data ?? [];

          if (comparisons.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.compare_arrows,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No comparison results yet',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: comparisons.length,
            itemBuilder: (context, index) {
              final comparison = comparisons[index];
              return _ComparisonCard(comparison: comparison);
            },
          );
        },
      ),
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  final WoundComparisonModel comparison;
  const _ComparisonCard({required this.comparison});

  @override
  Widget build(BuildContext context) {
    final dateString = comparison.createdAt != null
        ? DateFormat('yyyy-MM-dd').format(comparison.createdAt!)
        : 'Unknown date';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Navigate to comparison results screen with saved comparison data
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BlocProvider(
                create: (ctx) => ComparisonBloc(
                  woundRepository: ctx.read<WoundRepository>(),
                )..add(ComparisonLoadFromHistory(comparison)),
                child: const ComparisonResultsScreen(),
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                child: Icon(
                  Icons.compare_arrows,
                  color: Colors.blueGrey,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Comparison on $dateString',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Size change: ${comparison.sizeChangePct.toStringAsFixed(1)}%',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: comparison.sizeChangePct >= 0
                                ? Colors.red
                                : Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    if (comparison.previousDate != null &&
                        comparison.currentDate != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${DateFormat('MMM dd, yyyy').format(comparison.previousDate!)} → ${DateFormat('MMM dd, yyyy').format(comparison.currentDate!)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

