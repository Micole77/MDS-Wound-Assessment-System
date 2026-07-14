import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:verdasense/components/confirm_button.dart';
import 'package:verdasense/components/my_app_bar.dart';
import 'package:verdasense/screens/upload/blocs/upload_bloc.dart';

/// Screen allowing user to draw/adjust a bounding box on the selected image.
class BoundingBoxScreen extends StatefulWidget {
  final VoidCallback onAnalysisRequested;
  
  const BoundingBoxScreen({super.key, required this.onAnalysisRequested});

  @override
  State<BoundingBoxScreen> createState() => _BoundingBoxScreenState();
}

// lets the user draw multiple bounding boxes
class _BoundingBoxScreenState extends State<BoundingBoxScreen> {
  List<Rect> _boxes = [];
  Offset? _dragStart;
  Rect? _startBox;
  int? _draggedBoxIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MyAppBar(title: "Mark Wound Regions"),
      // FIX: Move button to bottomNavigationBar to prevent overlap
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: BlocConsumer<UploadBloc, UploadState>(
            listener: (context, state) async {
              if (state.status == UploadStatus.success) {
                await _showSuccessDialog(context);
              } else if (state.status == UploadStatus.error) {
                _showErrorDialog(context, state.errorMessage);
              }
            },
            builder: (context, state) {
              return ConfirmButton(
                label: _boxes.isEmpty ? 'Draw wound region' : 'Complete ${_boxes.length} wound region${_boxes.length != 1 ? 's' : ''}',
                icon: Icons.check,
                isLoading: state.status == UploadStatus.saving,
                onPressed: _boxes.isEmpty ? null : () {
                  context.read<UploadBloc>().add(UploadSaved(_boxes));
                },
              );
            },
          ),
        ),
      ),
      body: BlocBuilder<UploadBloc, UploadState>(
        builder: (context, state) {
          final file = state.imageFile;
          if (file == null) return const Center(child: Text('No image selected'));

          return LayoutBuilder(
            builder: (context, constraints) {
              final uiWidth = constraints.maxWidth;
              final uiHeight = constraints.maxHeight;

              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.read<UploadBloc>().add(UploadUiImageSizeUpdated(uiWidth, uiHeight));
              });
              
              return Stack(
                children: [
                  Positioned.fill(
                    child: Image.file(File(file.path), fit: BoxFit.contain),
                  ),
                  Positioned.fill(
                    child: GestureDetector(
                      onPanStart: (details) {
                        final start = details.localPosition;
                        final deleteIndex = _getDeleteButtonAtPosition(start);
                        if (deleteIndex != null) {
                          setState(() => _boxes.removeAt(deleteIndex));
                          return;
                        }
                        _draggedBoxIndex = _getBoxAtPosition(start);
                        if (_draggedBoxIndex != null) {
                          _dragStart = start;
                          _startBox = _boxes[_draggedBoxIndex!];
                        } else {
                          _dragStart = start;
                          _startBox = Rect.fromLTWH(start.dx, start.dy, 0, 0);
                          _boxes.add(_startBox!);
                        }
                        setState(() {});
                      },
                      onPanUpdate: (details) {
                        if (_dragStart == null || _startBox == null) return;
                        final current = details.localPosition;
                        if (_draggedBoxIndex != null) {
                          final dx = current.dx - _dragStart!.dx;
                          final dy = current.dy - _dragStart!.dy;
                          var newBox = _startBox!.translate(dx, dy);
                          newBox = Rect.fromLTWH(
                            newBox.left.clamp(0.0, constraints.maxWidth - newBox.width),
                            newBox.top.clamp(0.0, constraints.maxHeight - newBox.height),
                            newBox.width,
                            newBox.height,
                          );
                          _boxes[_draggedBoxIndex!] = newBox;
                        } else {
                          final left = math.min(_dragStart!.dx, current.dx);
                          final top = math.min(_dragStart!.dy, current.dy);
                          final right = math.max(_dragStart!.dx, current.dx);
                          final bottom = math.max(_dragStart!.dy, current.dy);
                          _boxes[_boxes.length - 1] = Rect.fromLTRB(left, top, right, bottom);
                        }
                        setState(() {});
                      },
                      onPanEnd: (_) {
                        if (_draggedBoxIndex == null && _boxes.isNotEmpty) {
                          if (_boxes.last.width < 15 || _boxes.last.height < 15) _boxes.removeLast();
                        }
                        _dragStart = null;
                        _startBox = null;
                        _draggedBoxIndex = null;
                        setState(() {});
                      },
                      child: CustomPaint(painter: _BoxPainter(_boxes)),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(16)),
                      child: Text('${_boxes.length} wound region${_boxes.length != 1 ? 's' : ''}',
                        style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showSuccessDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Analysis Ready'),
        content: const Text('The wound segmentation is successful. You will be directed to the Analysis Tab.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onAnalysisRequested();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String? message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message ?? 'An unexpected error occurred.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  int? _getBoxAtPosition(Offset position) {
    for (int i = _boxes.length - 1; i >= 0; i--) {
      if (_boxes[i].contains(position)) return i;
    }
    return null;
  }

  int? _getDeleteButtonAtPosition(Offset position) {
    const btnSize = 28.0;
    for (int i = 0; i < _boxes.length; i++) {
      final box = _boxes[i];
      final deleteRect = Rect.fromLTWH(box.right - btnSize/2, box.top - btnSize/2, btnSize, btnSize);
      if (deleteRect.contains(position)) return i;
    }
    return null;
  }
}

class _BoxPainter extends CustomPainter {
  final List<Rect> boxes;
  _BoxPainter(this.boxes);

  @override
  void paint(Canvas canvas, Size size) {
    if (boxes.isEmpty) return;
    final fillPaint = Paint()..color = Colors.blueAccent.withOpacity(0.3)..style = PaintingStyle.fill;
    final strokePaint = Paint()..color = Colors.blue.shade900..style = PaintingStyle.stroke..strokeWidth = 2;
    final delBg = Paint()..color = Colors.red..style = PaintingStyle.fill;
    final xStroke = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2..strokeCap = StrokeCap.round;

    for (final box in boxes) {
      canvas.drawRect(box, fillPaint);
      canvas.drawRect(box, strokePaint);
      final center = Offset(box.right, box.top);
      canvas.drawCircle(center, 12, delBg);
      const p = 5.0;
      canvas.drawLine(center + const Offset(-p, -p), center + const Offset(p, p), xStroke);
      canvas.drawLine(center + const Offset(p, -p), center + const Offset(-p, p), xStroke);
    }
  }

  @override
  bool shouldRepaint(covariant _BoxPainter oldDelegate) => true;
}


