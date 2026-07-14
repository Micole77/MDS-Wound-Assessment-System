import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:verdasense/screens/analysis/blocs/analysis_bloc.dart';
import 'package:wound_repository/wound_repository.dart';

class AnalysisResultsScreen extends StatefulWidget {
  const AnalysisResultsScreen({super.key});

  @override
  State<AnalysisResultsScreen> createState() => _AnalysisResultsScreenState();
}

class _AnalysisResultsScreenState extends State<AnalysisResultsScreen> {
  ProgressViewType _progressViewType = ProgressViewType.woundSize;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AnalysisBloc, AnalysisState>(
      builder: (context, state) {
        return RefreshIndicator(
          onRefresh: () async {
            context.read<AnalysisBloc>().add(const AnalysisRefreshRequested());
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Disclaimer Banner
                const _AIDisclaimerBanner(),
                const SizedBox(height: 24),

                // Image Analysis Section
                const _SectionTitle(title: 'Image Analysis'),
                const SizedBox(height: 12),
                _ImageAnalysisSection(
                  overlayUrl: state.latestOverlayUrl,
                  isLoading: state.status == AnalysisStatus.loading,
                ),

                const SizedBox(height: 32),

                // Tissue Breakdown Section
                const _SectionTitle(title: 'Tissue Breakdown'),
                const SizedBox(height: 12),
                _TissueBreakdownSection(
                  tissueUrl: state.latestTissueUrl,
                  isLoading: state.status == AnalysisStatus.loading,
                ),

                const SizedBox(height: 32),

                // TIME Assessment Section (IME Classification)
                const _SectionTitle(title: 'IME Assessment'),
                const SizedBox(height: 12),
                _TimeAssessmentSection(
                  imeResults: state.latestImeResults,
                  isLoading: state.status == AnalysisStatus.loading,
                ),

                const SizedBox(height: 32),

                // Progress History Section
                const _SectionTitle(title: 'Progress History'),
                const SizedBox(height: 12),
                _ProgressViewToggle(
                  currentType: _progressViewType,
                  onTypeChanged: (type) {
                    setState(() {
                      _progressViewType = type;
                    });
                  },
                ),
                const SizedBox(height: 12),
                _ProgressHistorySection(
                  wounds: state.recentWounds,
                  overlayUrls: state.recentWoundsOverlayUrls,
                  tissueUrls: state.recentWoundsTissueUrls,
                  viewType: _progressViewType,
                  isLoading: state.status == AnalysisStatus.loading,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}


class _AIDisclaimerBanner extends StatelessWidget {
  const _AIDisclaimerBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.gpp_maybe_outlined, 
               color: Theme.of(context).colorScheme.error, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'AI-generated analysis. Results are for monitoring assistance only and MUST be verified by a healthcare professional.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}


enum ProgressViewType { tissueClassification, woundSize }

class _SectionTitle extends StatelessWidget {
  final String title;
  
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class _ImageAnalysisSection extends StatelessWidget {
  const _ImageAnalysisSection({
    required this.overlayUrl,
    required this.isLoading,
  });

  final String? overlayUrl;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: SizedBox(
        height: 200,
        child: Center(
          child: _buildContent(context),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (isLoading) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text('Loading overlay image...'),
        ],
      );
    }

    if (overlayUrl == null || overlayUrl!.isEmpty) {
      return Text(
        'No overlay image available',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
      );
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FullScreenImageViewer(
              imageUrl: overlayUrl!,
              tag: 'latest_overlay', // Unique tag for Hero animation
            ),
          ),
        );
      },
      child: Hero(
        tag: 'latest_overlay',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: overlayUrl!,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            placeholder: (context, url) => const Center(
              child: CircularProgressIndicator(),
            ),
            errorWidget: (context, url, error) => Center(
              child: Text(
                'Failed to load overlay image',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TissueBreakdownSection extends StatelessWidget {
  const _TissueBreakdownSection({
    required this.tissueUrl,
    required this.isLoading,
  });

  final String? tissueUrl;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center, 
        children: [
          // Left side: Tissue classification image
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: () {
                if (tissueUrl != null && tissueUrl!.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FullScreenImageViewer(
                        imageUrl: tissueUrl!,
                        tag: 'tissue_breakdown_hero',
                      ),
                    ),
                  );
                }
              },
              child: Hero(
                tag: 'tissue_breakdown_hero',
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: _buildTissueImage(context),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Right side: Labels
          const Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, // Left aligned looks cleaner
              children: [
                _TissueLabel(color: Colors.red, label: 'Granulation'),
                SizedBox(height: 12),
                _TissueLabel(color: Colors.yellow, label: 'Slough'),
                SizedBox(height: 12),
                _TissueLabel(color: Colors.black, label: 'Necrotic'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTissueImage(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (tissueUrl == null || tissueUrl!.isEmpty) {
      return Center(
        child: Text(
          'Tissue Classification\nImage Not Available',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: tissueUrl!,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(),
        ),
        errorWidget: (context, url, error) => Center(
          child: Text(
            'Failed to load tissue image',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
          ),
        ),
      ),
    );
  }
}

class _TissueLabel extends StatelessWidget {
  const _TissueLabel({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 15,
          height: 15,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _ProgressViewToggle extends StatelessWidget {
  const _ProgressViewToggle({
    required this.currentType,
    required this.onTypeChanged,
  });

  final ProgressViewType currentType;
  final ValueChanged<ProgressViewType> onTypeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleButton(
              label: 'Wound Size',
              isSelected: currentType == ProgressViewType.woundSize,
              onTap: () => onTypeChanged(ProgressViewType.woundSize),
            ),
          ),
          Expanded(
            child: _ToggleButton(
              label: 'Tissue Classification',
              isSelected: currentType == ProgressViewType.tissueClassification,
              onTap: () => onTypeChanged(ProgressViewType.tissueClassification),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
        ),
      ),
    );
  }
}

class _ProgressHistorySection extends StatelessWidget {
  const _ProgressHistorySection({
    required this.wounds,
    required this.overlayUrls,
    required this.tissueUrls,
    required this.viewType,
    required this.isLoading,
  });

  final List<WoundImageModel> wounds;
  final Map<String, String> overlayUrls;
  final Map<String, String> tissueUrls;
  final ProgressViewType viewType;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const _LoadingPanel(height: 200, label: 'Loading progress history...');
    }

    if (wounds.isEmpty) {
      return _PlaceholderPanel(
        height: 150,
        label: 'No progress records available',
      );
    }

    return Column(
      children: wounds.asMap().entries.map((entry) {
        final index = entry.key;
        final wound = entry.value;
        return Padding(
          padding: EdgeInsets.only(bottom: index < wounds.length - 1 ? 16 : 0),
          child: _ProgressHistoryItem(
            wound: wound,
            overlayUrl: overlayUrls[wound.originalImageName],
            tissueUrl: tissueUrls[wound.originalImageName],
            viewType: viewType,
          ),
        );
      }).toList(),
    );
  }
}

class _ProgressHistoryItem extends StatelessWidget {
  const _ProgressHistoryItem({
    required this.wound,
    required this.overlayUrl,
    required this.tissueUrl,
    required this.viewType,
  });

  final WoundImageModel wound;
  final String? overlayUrl;
  final String? tissueUrl;
  final ProgressViewType viewType;

  @override
  Widget build(BuildContext context) {
    String? imageUrl;
    if (viewType == ProgressViewType.tissueClassification) {
      imageUrl = tissueUrl;
    } else {
      imageUrl = overlayUrl ?? wound.imageUrl;
    }

    final dateFormat = DateFormat('MMM dd, yyyy');
    final dateString = wound.createdAt != null
        ? dateFormat.format(wound.createdAt!)
        : 'Unknown date';

    // Using a unique key (like wound ID) for Hero to prevent animation glitches
    final String heroTag = 'history_$imageUrl';

    return GestureDetector(
      onTap: () {
        if (imageUrl != null && imageUrl.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FullScreenImageViewer(
                imageUrl: imageUrl!,
                tag: heroTag,
              ),
            ),
          );
        }
      },
      child: Container(
        height: 200,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Hero(
                tag: heroTag,
                child: Container(
                  height: 120, // Fixed height frame
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _buildImageContent(context, imageUrl),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Right side: Info
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dateString,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper to build the image with BoxFit.contain
  Widget _buildImageContent(BuildContext context, String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.contain,
      // Use placeholder instead of loadingBuilder for smoother transitions
      placeholder: (context, url) => const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      errorWidget: (context, url, error) => const Icon(Icons.broken_image),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel({
    required this.height,
    required this.label,
  });

  final double height;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderPanel extends StatelessWidget {
  const _PlaceholderPanel({
    required this.height,
    required this.label,
  });

  final double height;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
        ),
      ),
    );
  }
}

// ----- TIME Assessment Section (IME Classification) -----

class _TimeAssessmentSection extends StatelessWidget {
  const _TimeAssessmentSection({
    required this.imeResults,
    required this.isLoading,
  });

  final Map<String, dynamic>? imeResults;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const _LoadingPanel(height: 200, label: 'Loading TIME assessment...');
    }

    if (imeResults == null || imeResults!.isEmpty) {
      return _PlaceholderPanel(
        height: 150,
        label: 'No TIME assessment available.\nUpload a wound image to see results.',
      );
    }

    return Column(
      children: [
        _ImeResultCard(
          icon: Icons.coronavirus_outlined,
          title: 'Infection',
          label: imeResults!['infection_label'] as String? ?? 'N/A',
          confidence: (imeResults!['infection_conf'] as num?)?.toDouble(),
          color: _getInfectionColor(imeResults!['infection_label'] as String?),
        ),
        const SizedBox(height: 12),
        _ImeResultCard(
          icon: Icons.water_drop_outlined,
          title: 'Moisture',
          label: imeResults!['moisture_label'] as String? ?? 'N/A',
          confidence: (imeResults!['moisture_conf'] as num?)?.toDouble(),
          color: _getMoistureColor(imeResults!['moisture_label'] as String?),
        ),
        const SizedBox(height: 12),
        _ImeResultCard(
          icon: Icons.border_style_outlined,
          title: 'Edge',
          label: imeResults!['edge_label'] as String? ?? 'N/A',
          confidence: (imeResults!['edge_conf'] as num?)?.toDouble(),
          color: _getEdgeColor(imeResults!['edge_label'] as String?),
        ),
      ],
    );
  }

  Color _getInfectionColor(String? label) {
    if (label == 'Infected') return const Color(0xFFE53935);
    return const Color(0xFF43A047);
  }

  Color _getMoistureColor(String? label) {
    switch (label) {
      case 'Dry':
        return const Color(0xFFFFA726);
      case 'Moderate':
        return const Color(0xFF43A047);
      case 'Wet':
        return const Color(0xFF1E88E5);
      default:
        return Colors.grey;
    }
  }

  Color _getEdgeColor(String? label) {
    if (label == 'Advancing') return const Color(0xFF43A047);
    return const Color(0xFFFFA726);
  }
}

class _ImeResultCard extends StatelessWidget {
  const _ImeResultCard({
    required this.icon,
    required this.title,
    required this.label,
    required this.confidence,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String label;
  final double? confidence;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final confPercent = confidence != null
        ? '${(confidence! * 100).toStringAsFixed(1)}%'
        : '--';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          // Title + Label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                ),
              ],
            ),
          ),
          // Confidence
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                confPercent,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(
                'confidence',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String tag;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
    required this.tag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: Hero(
          tag: tag,
          child: InteractiveViewer(
            panEnabled: true, 
            minScale: 0.5,
            maxScale: 4.0,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              // Since it was already loaded on the previous screen, 
              // this will be nearly instantaneous.
              placeholder: (context, url) => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              errorWidget: (context, url, error) => const Icon(Icons.error),
            ),
          ),
        ),
      ),
    );
  }
}
