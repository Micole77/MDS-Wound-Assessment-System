import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:verdasense/screens/analysis/views/analysis_results_screen.dart';
import 'package:verdasense/screens/comparison/blocs/comparison_bloc.dart';
import 'package:verdasense/screens/comparison/blocs/comparison_event.dart';
import 'package:verdasense/screens/comparison/views/comparison_history_screen.dart';
import 'package:verdasense/screens/comparison/views/comparison_results_screen.dart';
import 'package:verdasense/screens/home/blocs/home_bloc.dart';
import 'package:wound_repository/wound_repository.dart';

import '../../../main.dart';
import 'app_shell.dart';
import 'past_records_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  // This triggers when user navigates BACK to Home
  @override
  void didPopNext() {
    context.read<HomeBloc>().add(const HomeRefreshRequested());
  }
  
  
  @override
  Widget build(BuildContext context) {

    final screenWidth = MediaQuery.of(context).size.width;

    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, state) {

        // Refresh
        return RefreshIndicator(
          onRefresh: () async {context.read<HomeBloc>().add(const HomeRefreshRequested());},

          child: 
            SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle(title: 'Quick Actions'),
                  const SizedBox(height: 12),

                  GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: screenWidth < 400 ? 0.85 : 1.0,
                    children: [
                      _QuickActionCard(icon: Icons.cloud_upload, title: "Upload Wound Image", onTap: (){AppShell.of(context)?.switchTab(1);}),
                      _QuickActionCard(icon: Icons.history, title: "View Past Records", onTap: (){Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PastRecordsScreen()));}),
                      _QuickActionCard(
                        icon: Icons.compare,
                        title: "Access Latest Comparison Results",
                        onTap: () async {
                          final repo = context.read<WoundRepository>();
                          
                          // Get latest snapshot once
                          final comparisons = await repo.getComparisons().first;

                          if (comparisons.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("No comparison results available yet.")),
                            );
                            return;
                          }

                          // Sort by date (newest first)
                          comparisons.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
                          final latest = comparisons.first;

                          // Navigate to Comparison Bloc
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => BlocProvider(
                                create: (ctx) => ComparisonBloc(
                                  woundRepository: ctx.read<WoundRepository>(),
                                )..add(ComparisonLoadFromHistory(latest)),
                                child: const ComparisonResultsScreen(),
                              ),
                            ),
                          );
                        }),
                    ],
                  ),

                  const SizedBox(height: 24),

                  _SectionHeader(title: 'View Past Records', onViewAll: () {Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PastRecordsScreen()));}),
                  const SizedBox(height: 12),
                  if (state.status == HomeStatus.loading && state.wounds.isEmpty)
                    const _LoadingPanel(height: 140, label: 'Loading records...')
                  else if (state.status == HomeStatus.failure)
                    _PlaceholderPanel(height: 140, label: state.errorMessage ?? 'Failed to load records')
                  else
                    _RecordsPreview(records: state.wounds),
                  const SizedBox(height: 24),

                  _SectionHeader(
                    title: 'Recent Comparison Results',
                    onViewAll: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ComparisonHistoryScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<List<WoundComparisonModel>>(
                    stream: context.read<WoundRepository>().getComparisons(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const _LoadingPanel(
                          height: 140,
                          label: 'Loading comparison results...',
                        );
                      }

                      final comparisons = snapshot.data ?? [];
                      return _ComparisonsPreview(comparisons: comparisons);
                    },
                  ),
                ],
              ),
            ),
        );
        
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 18,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onViewAll; // callback function
  const _SectionHeader({required this.title, required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    // Arrange the widgets horizontally
    return Row( 
      mainAxisAlignment: MainAxisAlignment.spaceBetween, // spaces the children to opposite ends of the row (left: title, right: View All)
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        
        // Detects taps & triggers the callback
        GestureDetector(
          onTap: onViewAll,
          child: Text(
            'View All >',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// Displays a small card with an icon and title (Quick Actions section)
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _QuickActionCard({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final backgroundColor = Theme.of(context).colorScheme.surface;
    return Material(
      color: backgroundColor,
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      
      // Makes the card tappable, showing a ripple animation when pressed
      child: InkWell(
        borderRadius: BorderRadius.circular(12), // ensure the ripple stays within the rounded edges
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          
          // Arrange icon and text vertically
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 2),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceholderPanel extends StatelessWidget {
  final double height;
  final String label;
  const _PlaceholderPanel({required this.height, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
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
      child: Center(
        child: Text(
          label,
          style: TextStyle(color: Colors.grey.shade600),
        ),
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  final double height;
  final String label;
  const _LoadingPanel({required this.height, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
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
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}

// Horizontal scrolling list of record cards (View Past Records section)
class _RecordsPreview extends StatelessWidget {
  final List<dynamic> records; 
  const _RecordsPreview({required this.records});

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const _PlaceholderPanel(height: 140, label: 'No records yet');
    }
    
    return SizedBox(
      height: 150, // Slightly increased height to accommodate labels comfortably
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: records.length,
        itemBuilder: (context, index) {
          final record = records[index];
          // Unique Hero tag for the home screen preview
          final String heroTag = 'home_preview_${record.imageUrl}';

          return Container(
            width: 160,
            margin: EdgeInsets.only(right: index < records.length - 1 ? 12 : 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
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
                    child: Column(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FullScreenImageViewer(
                                    imageUrl: record.imageUrl,
                                    tag: heroTag,
                                  ),
                                ),
                              );
                            },
                            child: Hero(
                              tag: heroTag,
                              child: ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  topRight: Radius.circular(12),
                                ),
                                child: CachedNetworkImage(
                                  imageUrl: record.imageUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  placeholder: (context, url) => Container(
                                    color: Colors.grey.shade200,
                                    child: const Center(
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.broken_image, color: Colors.grey),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Align(
                            alignment: Alignment.bottomLeft,
                             child: Text(
                              'On ${_formatDate(record.createdAt)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;
    
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (difference < 7) return '$difference days ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

// Display a preview of recent wound comparisons result
class _ComparisonsPreview extends StatelessWidget {
  final List<WoundComparisonModel> comparisons;
  const _ComparisonsPreview({required this.comparisons});

  @override
  Widget build(BuildContext context) {
    if (comparisons.isEmpty) {
      return const _PlaceholderPanel(height: 140, label: 'No comparisons yet');
    }
    return Column(
      children: [
        for (final comparison in comparisons.take(3)) // limit to the first 3 comparisons
          InkWell(
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
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
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
              child: Row(
                children: [
                  const Icon(Icons.compare_arrows, color: Colors.blueGrey),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          comparison.createdAt != null
                              ? 'Comparison result on ${DateFormat('yyyy-MM-dd').format(comparison.createdAt!)}'
                              : 'Comparison result',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Size change: ${comparison.sizeChangePct.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
      ],
    );
  }
}