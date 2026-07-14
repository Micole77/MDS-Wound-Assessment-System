import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:verdasense/components/my_app_bar.dart';
import 'package:verdasense/screens/analysis/views/analysis_results_screen.dart';
import 'package:verdasense/screens/home/blocs/past_records_bloc.dart';
import 'package:wound_repository/wound_repository.dart';

class PastRecordsScreen extends StatelessWidget {
  const PastRecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PastRecordsBloc(
        woundRepository: context.read<WoundRepository>(),
      )..add(const PastRecordsStarted()),
      child: const _PastRecordsView(),
    );
  }
}

class _PastRecordsView extends StatefulWidget {
  const _PastRecordsView();

  @override
  State<_PastRecordsView> createState() => _PastRecordsViewState();
}

class _PastRecordsViewState extends State<_PastRecordsView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppBar(title: 'Past Records'),

      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Wound Images'),
              Tab(text: 'Tissue Segmentation'),
            ],
            dividerColor: Colors.transparent,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _WoundImagesTab(),
                _TissueSegmentationTab(),
              ],
            )
          )
        ],
      ),
    );
  }
}

class _WoundImagesTab extends StatelessWidget {
  const _WoundImagesTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PastRecordsBloc, PastRecordsState>(
      builder: (context, state) {
        if (state.status == PastRecordsStatus.loading && state.wounds.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (state.status == PastRecordsStatus.failure) {
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
                  state.errorMessage ?? 'Failed to load records',
                  style: TextStyle(color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (state.wounds.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.image_outlined,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No wound records yet',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: state.wounds.length,
          itemBuilder: (context, index) {
            final wound = state.wounds[index];
            return _WoundRecordCard(wound: wound);
          },
        );
      },
    );
  }
}

class _WoundRecordCard extends StatelessWidget {
  final WoundImageModel wound;
  const _WoundRecordCard({required this.wound});

  @override
  Widget build(BuildContext context) {
    // Generate a unique Hero tag for this specific wound image
    final String heroTag = 'past_wound_${wound.imageUrl}';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Wound image on the left with Tap to Zoom
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FullScreenImageViewer(
                    imageUrl: wound.imageUrl,
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
                  bottomLeft: Radius.circular(12),
                ),
                child: CachedNetworkImage(
                  imageUrl: wound.imageUrl,
                  width: 150,
                  height: 120,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 150,
                    height: 120,
                    color: Colors.grey.shade200,
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 150,
                    height: 120,
                    color: Colors.grey.shade200,
                    child: Icon(Icons.broken_image, color: Colors.grey.shade400, size: 48),
                  ),
                ),
              ),
            ),
          ),
          // Timestamp section... (keep your existing Expanded/Padding code here)
          _buildInfoSection(context),
        ],
      ),
    );
  }

  // Refactored UI for clarity
  Widget _buildInfoSection(BuildContext context) {
    final dateTime = _formatDateTimeUtcToAsia(wound.createdAt!);
    return Expanded(
      child: SizedBox(
        height: 120,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dateTime['date']!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
              const SizedBox(height: 4),
              Text(dateTime['time']!, style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, String> _formatDateTimeUtcToAsia(DateTime utcDateTime) {
    // Convert to Asia/Kuala_Lumpur timezone (UTC+8)
    final asiaTime = utcDateTime.toUtc().add(const Duration(hours: 8));

    // Format date and time separately
    final dateString = DateFormat('dd/MM/yyyy').format(asiaTime); // e.g., 19/11/2025
    final timeString = DateFormat('HH:mm').format(asiaTime);      // e.g., 15:44

    return {
      'date': dateString,
      'time': timeString
    };
  }
}

class _TissueSegmentationTab extends StatelessWidget {
  const _TissueSegmentationTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PastRecordsBloc, PastRecordsState>(
      builder: (context, state) {
        if (state.status == PastRecordsStatus.loading && state.wounds.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (state.status == PastRecordsStatus.failure) {
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
                  state.errorMessage ?? 'Failed to load records',
                  style: TextStyle(color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        // Filter wounds that have tissue classification images
        final woundsWithTissue = state.wounds.where((wound) {
          return state.tissueUrls.containsKey(wound.originalImageName) &&
                 state.tissueUrls[wound.originalImageName] != null &&
                 state.tissueUrls[wound.originalImageName]!.isNotEmpty;
        }).toList();

        if (woundsWithTissue.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.image_outlined,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No tissue classification images yet',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: woundsWithTissue.length,
          itemBuilder: (context, index) {
            final wound = woundsWithTissue[index];
            final tissueUrl = state.tissueUrls[wound.originalImageName]!;
            return _TissueRecordCard(
              wound: wound,
              tissueUrl: tissueUrl,
            );
          },
        );
      },
    );
  }
}

class _TissueRecordCard extends StatelessWidget {
  final WoundImageModel wound;
  final String tissueUrl;
  const _TissueRecordCard({required this.wound, required this.tissueUrl});

  @override
  Widget build(BuildContext context) {

    final String heroTag = 'past_tissue_$tissueUrl';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FullScreenImageViewer(
                    imageUrl: tissueUrl,
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
                  bottomLeft: Radius.circular(12),
                ),
                child: CachedNetworkImage(
                  imageUrl: tissueUrl,
                  width: 150,
                  height: 120,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 150,
                    height: 120,
                    color: Colors.grey.shade200,
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 150,
                    height: 120,
                    color: Colors.grey.shade200,
                    child: Icon(Icons.broken_image, color: Colors.grey.shade400, size: 48),
                  ),
                ),
              ),
            ),
          ),
          // Timestamp on the right
          Expanded(
            child: SizedBox(
              width: 150,
              height: 120,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDateTimeUtcToAsia(wound.createdAt!)['date']!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDateTimeUtcToAsia(wound.createdAt!)['time']!,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            )
            
          ),
        ],
      ),
    );
  }

  Map<String, String> _formatDateTimeUtcToAsia(DateTime utcDateTime) {
    // Convert to Asia/Kuala_Lumpur timezone (UTC+8)
    final asiaTime = utcDateTime.toUtc().add(const Duration(hours: 8));

    // Format date and time separately
    final dateString = DateFormat('dd/MM/yyyy').format(asiaTime); // e.g., 19/11/2025
    final timeString = DateFormat('HH:mm').format(asiaTime);      // e.g., 15:44

    return {
      'date': dateString,
      'time': timeString
    };
  }
}

