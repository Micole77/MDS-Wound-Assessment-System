import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:verdasense/components/confirm_button.dart';
import 'package:verdasense/screens/comparison/blocs/comparison_bloc.dart';
import 'package:verdasense/screens/comparison/blocs/comparison_event.dart';
import 'package:verdasense/screens/comparison/blocs/comparison_state.dart';
import 'package:verdasense/screens/comparison/views/comparison_results_screen.dart';
import 'package:wound_repository/wound_repository.dart';

class CompareProgressScreen extends StatefulWidget {
  const CompareProgressScreen({super.key});

  @override
  State<CompareProgressScreen> createState() => _CompareProgressScreenState();
}

class _CompareProgressScreenState extends State<CompareProgressScreen> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ComparisonBloc, ComparisonState>(
      builder: (context, state) {
        return Scaffold(
          body: SafeArea(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // --- Wound A Card ---
                      _WoundSelectionCard(
                        label: 'Select Image A',
                        wound: state.woundA,
                        onTap: () {
                          if (state.woundA != null) {
                            // Logic to deselect is handled inside the card's X button,
                            // but tapping the card itself can also trigger re-selection if desired.
                            // Here we just open the dialog to allow changing it.
                             _showWoundSelectionDialog(
                              context,
                              (wound) => context
                                  .read<ComparisonBloc>()
                                  .add(ComparisonWoundASelected(wound)),
                              state.woundB,
                            );
                          } else {
                            _showWoundSelectionDialog(
                              context,
                              (wound) => context
                                  .read<ComparisonBloc>()
                                  .add(ComparisonWoundASelected(wound)),
                              state.woundB,
                            );
                          }
                        },
                        onClear: () {
                          context.read<ComparisonBloc>().add(const ComparisonWoundADeselected());
                        },
                      ),
                      const SizedBox(height: 16),

                      // --- Wound B Card ---
                      _WoundSelectionCard(
                        label: 'Select Image B',
                        wound: state.woundB,
                        onTap: () {
                          if (state.woundB != null) {
                             _showWoundSelectionDialog(
                              context,
                              (wound) => context
                                  .read<ComparisonBloc>()
                                  .add(ComparisonWoundBSelected(wound)),
                              state.woundA,
                            );
                          } else {
                            _showWoundSelectionDialog(
                              context,
                              (wound) => context
                                  .read<ComparisonBloc>()
                                  .add(ComparisonWoundBSelected(wound)),
                              state.woundA,
                            );
                          }
                        },
                        onClear: () {
                          context.read<ComparisonBloc>().add(const ComparisonWoundBDeselected());
                        },
                      ),

                      const SizedBox(height: 80), 
                    ],
                  ),
                ),

                // --- Compare Button ---
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 48),
                    child: ConfirmButton(
                      label: 'Compare',
                      width: MediaQuery.of(context).size.width * 0.7,
                      onPressed: state.woundA != null && state.woundB != null
                          ? () {
                              context
                                  .read<ComparisonBloc>()
                                  .add(const ComparisonCompareRequested());
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => BlocProvider.value(
                                    value: context.read<ComparisonBloc>(),
                                    child: const ComparisonResultsScreen(),
                                  ),
                                ),
                              );
                            }
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showWoundSelectionDialog(
    BuildContext context,
    Function(WoundImageModel) onWoundSelected,
    WoundImageModel? excludeWound,
  ) {
    // 1. CAPTURE THE BLOC INSTANCE HERE (Use the parent context)
    final comparisonBloc = context.read<ComparisonBloc>();

    // 2. Trigger refresh using the captured bloc
    comparisonBloc.add(const ComparisonWoundsRefreshed());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (modalContext) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        // Renamed 'context' to 'sheetContext' to avoid confusion
        builder: (sheetContext, scrollController) {
          
          return BlocBuilder<ComparisonBloc, ComparisonState>(
            // 3. PASS THE CAPTURED INSTANCE EXPLICITLY
            bloc: comparisonBloc, 
            builder: (context, state) {
              
              final availableWounds = state.availableWounds
                  .where((w) =>
                      w.originalImageName != excludeWound?.originalImageName)
                  .toList();

              return Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Select a wound image',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 16),

                    if (state.availableWounds.isEmpty &&
                        state.status == ComparisonStatus.loading)
                      const Expanded(
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (availableWounds.isEmpty)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.image_not_supported_outlined,
                                  size: 48,
                                  color: Theme.of(context).colorScheme.outline),
                              const SizedBox(height: 16),
                              const Text("No available wounds found."),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: availableWounds.length,
                          itemBuilder: (context, index) {
                            final wound = availableWounds[index];
                            final dateFormat = DateFormat('MMM dd, yyyy');
                            final dateString = wound.createdAt != null
                                ? dateFormat.format(wound.createdAt!)
                                : 'Unknown date';

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 4),
                              leading: Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outline
                                        .withValues(alpha: 0.2),
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: wound.imageUrl.isNotEmpty
                                    ? CachedNetworkImage(
                                        key: ValueKey(wound.imageUrl),
                                        imageUrl: wound.imageUrl,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => const Center(
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                        errorWidget: (context, url, error) => Icon(
                                          Icons.broken_image,
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                                        ),
                                      )
                                    : Icon(
                                        Icons.image,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.4),
                                      ),
                              ),
                              title: const Text('Captured at'),
                              subtitle: Text(dateString),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                onWoundSelected(wound);
                                Navigator.of(context).pop();
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _WoundSelectionCard extends StatelessWidget {
  const _WoundSelectionCard({
    required this.label,
    this.wound,
    required this.onTap,
    required this.onClear,
  });

  final String label;
  final WoundImageModel? wound;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      width: double.infinity,
      child: Card(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              // --- Main Content ---
              Padding(
                padding: const EdgeInsets.all(24),
                child: wound == null
                    ? _buildEmptyState(context)
                    : _buildSelectedState(context),
              ),

              // --- "X" Remove Button (Only visible if wound selected) ---
              if (wound != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: "Remove image",
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      foregroundColor:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    onPressed: onClear, // Call the clear callback
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 48, 
            color: Colors.grey.shade400
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade400,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedState(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.2),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: CachedNetworkImage(
                imageUrl: wound!.imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(),
                ),
                errorWidget: (context, url, error) => const Icon(Icons.broken_image),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
        if (wound!.createdAt != null) ...[
          const SizedBox(height: 4),
          Text(
            DateFormat('MMM dd, yyyy').format(wound!.createdAt!),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
          ),
        ],
      ],
    );
  }
}