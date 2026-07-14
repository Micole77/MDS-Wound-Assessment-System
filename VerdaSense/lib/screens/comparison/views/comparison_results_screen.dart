import 'dart:async';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:verdasense/components/my_app_bar.dart';
import 'package:verdasense/screens/analysis/views/analysis_results_screen.dart';
import 'package:verdasense/screens/comparison/blocs/comparison_bloc.dart';
import 'package:verdasense/screens/comparison/blocs/comparison_state.dart';
import 'package:wound_repository/wound_repository.dart';

class ComparisonResultsScreen extends StatefulWidget {
  const ComparisonResultsScreen({super.key});

  @override
  State<ComparisonResultsScreen> createState() =>
      _ComparisonResultsScreenState();
}

class _ComparisonResultsScreenState extends State<ComparisonResultsScreen> {
  ui.Image? _overlayImage;
  bool _isLoadingOverlay = false;
  String? _currentMaskAUrl;
  String? _currentMaskBUrl;

  Future<void> _loadOverlayImage(String? maskAUrl, String? maskBUrl) async {
    if (maskAUrl == null || maskBUrl == null || _isLoadingOverlay) return;

    setState(() {
      _isLoadingOverlay = true;
      _currentMaskAUrl = maskAUrl;
      _currentMaskBUrl = maskBUrl;
    });

    try {
      final overlay = await _createOverlayImage(maskAUrl, maskBUrl);
      if (mounted) {
        setState(() {
          _overlayImage = overlay;
          _isLoadingOverlay = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading overlay: $e");
      if (mounted) setState(() => _isLoadingOverlay = false);
    }
  }

  Future<ui.Image> _createOverlayImage(String maskAUrl, String maskBUrl) async {
    final responses = await Future.wait([
      http.get(Uri.parse(maskAUrl)),
      http.get(Uri.parse(maskBUrl)),
    ]);

    if (responses[0].statusCode != 200 || responses[1].statusCode != 200) {
      throw Exception('Failed to download mask images');
    }

    const int kDisplayWidth = 600;
    final codecA = await ui.instantiateImageCodec(responses[0].bodyBytes, targetWidth: kDisplayWidth);
    final codecB = await ui.instantiateImageCodec(responses[1].bodyBytes, targetWidth: kDisplayWidth);
    
    var imageA = (await codecA.getNextFrame()).image;
    final imageB = (await codecB.getNextFrame()).image;

    if (imageA.height != imageB.height) {
      imageA = await _resizeImage(imageA, imageB.width, imageB.height);
    }
    
    final width = imageA.width;
    final height = imageA.height;
    final bytesA = await imageA.toByteData(format: ui.ImageByteFormat.rawRgba);
    final bytesB = await imageB.toByteData(format: ui.ImageByteFormat.rawRgba);

    if (bytesA == null || bytesB == null) throw Exception("Error reading bytes");

    final isolateResult = await compute(
      processComparisonTask, 
      OverlayTaskData(bytesA, bytesB, width, height)
    );

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      isolateResult.rawOverlayBytes,
      width,
      height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }

  Future<ui.Image> _resizeImage(ui.Image image, int width, int height) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint(),
    );
    return recorder.endRecording().toImage(width, height);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ComparisonBloc, ComparisonState>(
      listener: (context, state) {
        if (state.previousWoundMaskUrl != null && state.currentWoundMaskUrl != null) {
          if (_overlayImage == null || 
              _currentMaskAUrl != state.previousWoundMaskUrl || 
              _currentMaskBUrl != state.currentWoundMaskUrl) {
             _loadOverlayImage(state.previousWoundMaskUrl, state.currentWoundMaskUrl);
          }
        }
      },
      child: BlocBuilder<ComparisonBloc, ComparisonState>(
        builder: (context, state) {
          if (state.status == ComparisonStatus.loading) {
            return Scaffold(
                appBar: MyAppBar(title: "Compare Progress"),
                body: const Center(child: CircularProgressIndicator()));
          }

          if (state.status == ComparisonStatus.failure) {
            return Scaffold(
              appBar: MyAppBar(title: "Compare Progress"),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Comparison Failed', style: Theme.of(context).textTheme.titleLarge),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(state.errorMessage ?? 'Error', textAlign: TextAlign.center),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            );
          }
          
          // Use chronological comparison results
          final previousWound = state.previousWound;
          final currentWound = state.currentWound;

          if (previousWound == null || currentWound == null) {
            return Scaffold(
              appBar: MyAppBar(title: "Compare Progress"),
              body: const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    'No comparison data available. Please select two wounds from the comparison screen.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }

          final dateString = state.comparisonDate != null
              ? DateFormat('yyyy-MM-dd').format(state.comparisonDate!)
              : null;

          return Scaffold(
            appBar: MyAppBar(title: dateString ?? "Comparison Result"),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle(title: 'Segmented wound images'),
                  const SizedBox(height: 12),
                  _SegmentedWoundsSection(
                    previousWound: previousWound,
                    currentWound: currentWound,
                    overlayA: state.previousWoundOverlayUrl,
                    overlayB: state.currentWoundOverlayUrl,
                  ),
                  const SizedBox(height: 32),
                  const _SectionTitle(title: 'Tissue Classification'),
                  const SizedBox(height: 12),
                  _TissueClassificationSection(
                    previousWound: previousWound,
                    currentWound: currentWound,
                    tissueA: state.previousWoundTissueUrl,
                    tissueB: state.currentWoundTissueUrl,
                  ),
                  const SizedBox(height: 32),
                  const _SectionTitle(title: 'IME Assessment Comparison'),
                  const SizedBox(height: 12),
                  _TimeAssessmentComparisonSection(
                    previousWound: previousWound,
                    currentWound: currentWound,
                  ),
                  const SizedBox(height: 32),
                  const _SectionTitle(title: 'Overlay View'),
                  const SizedBox(height: 12),
                  _OverlayViewSection(
                    overlayImage: _overlayImage,
                    woundSizeChange: state.woundSizeChange,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600));
  }
}

class _SegmentedWoundsSection extends StatelessWidget {
  const _SegmentedWoundsSection({
    required this.previousWound,
    required this.currentWound,
    this.overlayA,
    this.overlayB,
  });

  final WoundImageModel previousWound;
  final WoundImageModel currentWound;
  final String? overlayA;
  final String? overlayB;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _WoundDisplayItem(imageUrl: overlayA ?? previousWound.imageUrl, label: 'Image A (Previous)', date: previousWound.createdAt),
        const SizedBox(height: 16),
        _WoundDisplayItem(imageUrl: overlayB ?? currentWound.imageUrl, label: 'Image B (Latest)', date: currentWound.createdAt),
      ],
    );
  }
}

class _WoundDisplayItem extends StatelessWidget {
  const _WoundDisplayItem({required this.imageUrl, required this.label, this.date});
  final String imageUrl;
  final String label;
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final String heroTag = 'wound_display_$imageUrl';
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FullScreenImageViewer(
                      imageUrl: imageUrl,
                      tag: heroTag,
                    ),
                  ),
                );
              },
              child: Hero(
                tag: heroTag,
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
                  clipBehavior: Clip.antiAlias,
                  child: CachedNetworkImage(
                    key: ValueKey(imageUrl),
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    errorWidget: (context, url, error) => const Icon(Icons.broken_image),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.titleMedium),
                if (date != null) Text(DateFormat('yyyy/MM/dd').format(date!)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TissueClassificationSection extends StatelessWidget {
  const _TissueClassificationSection({
    required this.previousWound,
    required this.currentWound,
    this.tissueA,
    this.tissueB,
  });
  final WoundImageModel previousWound;
  final WoundImageModel currentWound;
  final String? tissueA;
  final String? tissueB;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TissueDisplayItem(imageUrl: tissueA, label: 'Image A (Previous)', date: previousWound.createdAt),
        const SizedBox(height: 16),
        _TissueDisplayItem(imageUrl: tissueB, label: 'Image B (Latest)', date: currentWound.createdAt),
      ],
    );
  }
}

class _TissueDisplayItem extends StatelessWidget {
  const _TissueDisplayItem({this.imageUrl, required this.label, this.date});
  final String? imageUrl;
  final String label;
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final String heroTag = 'tissue_display_${imageUrl ?? 'placeholder'}';
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: imageUrl != null && imageUrl!.isNotEmpty
                  ? () {
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
                  : null,
              child: Hero(
                tag: heroTag,
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(8)),
                  child: imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            key: ValueKey(imageUrl),
                            imageUrl: imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            errorWidget: (context, url, error) => const Icon(Icons.broken_image),
                          ),
                        )
                      : const Center(child: Text('Placeholder')),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.titleMedium),
                if (date != null) Text(DateFormat('yyyy/MM/dd').format(date!)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeAssessmentComparisonSection extends StatelessWidget {
  const _TimeAssessmentComparisonSection({
    required this.previousWound,
    required this.currentWound,
  });

  final WoundImageModel previousWound;
  final WoundImageModel currentWound;

  @override
  Widget build(BuildContext context) {
    final prevIme = previousWound.imeResults;
    final currIme = currentWound.imeResults;

    if (prevIme == null && currIme == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
        ),
        child: Center(
          child: Text(
            'No TIME assessment data available for these wounds.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          // Header row
          Row(
            children: [
              const Expanded(flex: 2, child: SizedBox()),
              Expanded(
                flex: 3,
                child: Text('Previous', textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: Text('Current', textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
              ),
              const Expanded(flex: 2, child: SizedBox()),
            ],
          ),
          const SizedBox(height: 12),
          _ImeComparisonRow(
            icon: Icons.coronavirus_outlined,
            title: 'Infection',
            prevLabel: prevIme?['infection_label'] as String?,
            prevConf: (prevIme?['infection_conf'] as num?)?.toDouble(),
            currLabel: currIme?['infection_label'] as String?,
            currConf: (currIme?['infection_conf'] as num?)?.toDouble(),
            getBetterLabel: 'Non-Infected',
          ),
          const Divider(height: 24),
          _ImeComparisonRow(
            icon: Icons.water_drop_outlined,
            title: 'Moisture',
            prevLabel: prevIme?['moisture_label'] as String?,
            prevConf: (prevIme?['moisture_conf'] as num?)?.toDouble(),
            currLabel: currIme?['moisture_label'] as String?,
            currConf: (currIme?['moisture_conf'] as num?)?.toDouble(),
            getBetterLabel: 'Moderate',
          ),
          const Divider(height: 24),
          _ImeComparisonRow(
            icon: Icons.border_style_outlined,
            title: 'Edge',
            prevLabel: prevIme?['edge_label'] as String?,
            prevConf: (prevIme?['edge_conf'] as num?)?.toDouble(),
            currLabel: currIme?['edge_label'] as String?,
            currConf: (currIme?['edge_conf'] as num?)?.toDouble(),
            getBetterLabel: 'Advancing',
          ),
        ],
      ),
    );
  }
}

class _ImeComparisonRow extends StatelessWidget {
  const _ImeComparisonRow({
    required this.icon,
    required this.title,
    this.prevLabel,
    this.prevConf,
    this.currLabel,
    this.currConf,
    required this.getBetterLabel,
  });

  final IconData icon;
  final String title;
  final String? prevLabel;
  final double? prevConf;
  final String? currLabel;
  final double? currConf;
  final String getBetterLabel; // The "good" label for this task

  @override
  Widget build(BuildContext context) {
    // Determine change status
    final changeIcon = _getChangeIcon();
    final changeColor = _getChangeColor();

    return Row(
      children: [
        // Task icon + title
        Expanded(
          flex: 2,
          child: Column(
            children: [
              Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
              const SizedBox(height: 4),
              Text(title, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
        // Previous label + confidence
        Expanded(
          flex: 3,
          child: _ImeLabelChip(
            label: prevLabel,
            confidence: prevConf,
            color: _getLabelColor(prevLabel),
          ),
        ),
        // Change arrow
        Expanded(
          flex: 2,
          child: Column(
            children: [
              Icon(changeIcon, color: changeColor, size: 24),
              if (prevLabel != null && currLabel != null && prevLabel != currLabel)
                Text(
                  prevLabel == getBetterLabel ? 'Worsened' : (currLabel == getBetterLabel ? 'Improved' : 'Changed'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: changeColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              if (prevLabel != null && currLabel != null && prevLabel == currLabel)
                Text(
                  'Unchanged',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: changeColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                ),
            ],
          ),
        ),
        // Current label + confidence
        Expanded(
          flex: 3,
          child: _ImeLabelChip(
            label: currLabel,
            confidence: currConf,
            color: _getLabelColor(currLabel),
          ),
        ),
      ],
    );
  }

  IconData _getChangeIcon() {
    if (prevLabel == null || currLabel == null) return Icons.horizontal_rule;
    if (prevLabel == currLabel) return Icons.horizontal_rule;
    if (currLabel == getBetterLabel) return Icons.trending_up;
    if (prevLabel == getBetterLabel) return Icons.trending_down;
    return Icons.swap_horiz;
  }

  Color _getChangeColor() {
    if (prevLabel == null || currLabel == null) return Colors.grey;
    if (prevLabel == currLabel) return Colors.grey;
    if (currLabel == getBetterLabel) return const Color(0xFF43A047);
    if (prevLabel == getBetterLabel) return const Color(0xFFE53935);
    return const Color(0xFFFFA726);
  }

  Color _getLabelColor(String? label) {
    switch (label) {
      case 'Non-Infected':
        return const Color(0xFF43A047);
      case 'Infected':
        return const Color(0xFFE53935);
      case 'Dry':
        return const Color(0xFFFFA726);
      case 'Moderate':
        return const Color(0xFF43A047);
      case 'Wet':
        return const Color(0xFF1E88E5);
      case 'Advancing':
        return const Color(0xFF43A047);
      case 'Not Advancing':
        return const Color(0xFFFFA726);
      default:
        return Colors.grey;
    }
  }
}

class _ImeLabelChip extends StatelessWidget {
  const _ImeLabelChip({
    this.label,
    this.confidence,
    required this.color,
  });

  final String? label;
  final double? confidence;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (label == null) {
      return Center(
        child: Text('N/A',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
      );
    }

    final confText = confidence != null
        ? '${(confidence! * 100).toStringAsFixed(0)}%'
        : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            label!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                  fontSize: 11,
                ),
            textAlign: TextAlign.center,
          ),
          if (confText.isNotEmpty)
            Text(
              confText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 10,
                  ),
            ),
        ],
      ),
    );
  }
}

class _OverlayViewSection extends StatelessWidget {
  const _OverlayViewSection({this.overlayImage, this.woundSizeChange});
  final ui.Image? overlayImage;
  final double? woundSizeChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: GestureDetector(
                  onTap: overlayImage != null
                      ? () {
                          // Convert ui.Image to bytes for full screen viewer
                          _showOverlayFullScreen(context, overlayImage!);
                        }
                      : null,
                  child: Container(
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: overlayImage != null
                        ? LayoutBuilder(
                            builder: (context, constraints) {
                              // Calculate size maintaining aspect ratio
                              final imageAspectRatio = overlayImage!.width / overlayImage!.height;
                              final containerAspectRatio = constraints.maxWidth / constraints.maxHeight;
                              
                              double displayWidth;
                              double displayHeight;
                              
                              if (imageAspectRatio > containerAspectRatio) {
                                // Image is wider - fit to width
                                displayWidth = constraints.maxWidth;
                                displayHeight = constraints.maxWidth / imageAspectRatio;
                              } else {
                                // Image is taller - fit to height
                                displayHeight = constraints.maxHeight;
                                displayWidth = constraints.maxHeight * imageAspectRatio;
                              }
                              
                              return Center(
                                child: CustomPaint(
                                  painter: _OverlayPainter(overlayImage!),
                                  size: Size(displayWidth, displayHeight),
                                ),
                              );
                            },
                          )
                        : const Center(child: CircularProgressIndicator()),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _LegendItem(color: Color(0x6600FF00), label: 'Healed Area'),
                    const SizedBox(height: 12),
                    const _LegendItem(color: Color(0x66FF0000), label: 'Remaining Wound'),
                    const SizedBox(height: 24),
                    Text('Wound Size Change (%)',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    if (woundSizeChange != null)
                      Text(
                        '${woundSizeChange! >= 0 ? '+' : ''}${woundSizeChange!.toStringAsFixed(1)}%',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: woundSizeChange! >= 0 ? Colors.red : Colors.green,
                            fontWeight: FontWeight.bold),
                      )
                    else
                      const Text('Calculating...'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showOverlayFullScreen(BuildContext context, ui.Image image) async {
    // Show full screen viewer
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _OverlayFullScreenViewer(image: image),
      ),
    );
  }
}

class _OverlayFullScreenViewer extends StatelessWidget {
  final ui.Image image;
  const _OverlayFullScreenViewer({required this.image});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate size to fit screen while maintaining aspect ratio
          final imageAspectRatio = image.width / image.height;
          final screenAspectRatio = constraints.maxWidth / constraints.maxHeight;
          
          double displayWidth;
          double displayHeight;
          
          if (imageAspectRatio > screenAspectRatio) {
            // Image is wider - fit to width
            displayWidth = constraints.maxWidth;
            displayHeight = constraints.maxWidth / imageAspectRatio;
          } else {
            // Image is taller - fit to height
            displayHeight = constraints.maxHeight;
            displayWidth = constraints.maxHeight * imageAspectRatio;
          }
          
          return Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: CustomPaint(
                painter: _OverlayPainter(image),
                size: Size(displayWidth, displayHeight),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 20, 
          height: 20, 
          decoration: BoxDecoration(shape: BoxShape.circle, color: color)
        ),
        const SizedBox(width: 8),
        // Wrapping Text in Expanded fixes the 13-pixel overflow
        Expanded(
          child: Text(
            label, 
            style: Theme.of(context).textTheme.bodyMedium,
            // Optional: you can add overflow behavior if you prefer dots over wrapping
            // overflow: TextOverflow.ellipsis, 
          ),
        ),
      ],
    );
  }
}

class _OverlayPainter extends CustomPainter {
  final ui.Image image;
  _OverlayPainter(this.image);
  @override
  void paint(Canvas canvas, Size size) {
    // Draw the image maintaining aspect ratio and filling the available size
    final srcRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dstRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(image, srcRect, dstRect, Paint());
  }
  @override
  bool shouldRepaint(_OverlayPainter old) => old.image != image;
}