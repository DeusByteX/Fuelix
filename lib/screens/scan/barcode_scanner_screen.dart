import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../providers/providers.dart';
import '../../services/food_scan_service.dart';
import '../../utils/theme.dart';
import 'scan_result_screen.dart';

class BarcodeScannerScreen extends ConsumerStatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  ConsumerState<BarcodeScannerScreen> createState() =>
      _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends ConsumerState<BarcodeScannerScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isProcessing = false;
  bool _torchOn = false;
  String? _scannedCode;

  // Manual search fallback
  bool _showManualSearch = false;
  final _searchController = TextEditingController();

  // Animated scanner line
  late AnimationController _lineController;
  late Animation<double> _lineAnim;

  @override
  void initState() {
    super.initState();
    _lineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _lineAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _lineController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _lineController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onBarcodeDetected(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final code = barcode.rawValue!;
    if (code == _scannedCode) return;

    setState(() {
      _isProcessing = true;
      _scannedCode = code;
    });

    await _controller.stop();

    try {
      final service = ref.read(foodScanServiceProvider);
      final result = await service.scanBarcode(code);

      if (mounted) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ScanResultScreen(
              nutritionResult: result,
              scanMode: ScanMode.barcode,
            ),
          ),
        );
      }
    } on BarcodeNotFoundException catch (e) {
      if (mounted) {
        setState(() {
          _showManualSearch = true;
          _isProcessing = false;
        });
        _showSnack(e.message, isError: true);
        await _controller.start();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _scannedCode = null;
        });
        _showSnack('Error: $e', isError: true);
        await _controller.start();
      }
    }
  }

  Future<void> _searchManually() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isProcessing = true);
    FocusScope.of(context).unfocus();

    try {
      final service = ref.read(foodScanServiceProvider);
      final result = await service.searchFood(query);
      if (mounted) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ScanResultScreen(
              nutritionResult: result,
              scanMode: ScanMode.barcode,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showSnack('Search failed: $e', isError: true);
      }
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.redAccent : Colors.green,
      duration: const Duration(seconds: 4),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scanBoxSize = size.width * 0.72;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Live camera feed
          MobileScanner(
            controller: _controller,
            onDetect: _onBarcodeDetected,
          ),

          // Dark overlay with transparent cutout
          _buildScanOverlay(size, scanBoxSize),

          // Animated scan line inside the cutout
          if (!_isProcessing)
            Positioned(
              left: (size.width - scanBoxSize) / 2,
              top: (size.height - scanBoxSize) / 2,
              width: scanBoxSize,
              height: scanBoxSize,
              child: AnimatedBuilder(
                animation: _lineAnim,
                builder: (ctx, _) => Stack(
                  children: [
                    Positioned(
                      top: _lineAnim.value * (scanBoxSize - 4),
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              FuelixTheme.accentOrange,
                              FuelixTheme.accentOrange,
                              Colors.transparent,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: FuelixTheme.accentOrange.withValues(alpha: 0.8),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Text(
                      'Scan Barcode',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _torchOn ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
                        color: _torchOn ? FuelixTheme.accentOrange : Colors.white,
                      ),
                      onPressed: () {
                        setState(() => _torchOn = !_torchOn);
                        _controller.toggleTorch();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomPanel(),
          ),

          // Loading overlay
          if (_isProcessing)
            Container(
              color: Colors.black.withValues(alpha: 0.7),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                        color: FuelixTheme.accentOrange, strokeWidth: 3),
                    SizedBox(height: 20),
                    Text(
                      'Fetching nutrition data…',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScanOverlay(Size size, double boxSize) {
    return CustomPaint(
      size: size,
      painter: _ScanOverlayPainter(
        boxSize: boxSize,
        center: Offset(size.width / 2, size.height / 2),
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withValues(alpha: 0.9), Colors.transparent],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_showManualSearch) ...[
            const Text(
              'Point camera at a barcode',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Works with any packaged food',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => setState(() => _showManualSearch = true),
              child: const Text(
                'Can\'t scan? Search manually →',
                style: TextStyle(
                    color: FuelixTheme.accentOrange,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ] else ...[
            const Text(
              'Search manually',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: FuelixTheme.accentOrange.withValues(alpha: 0.4)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'e.g. "Greek Yogurt"',
                        hintStyle: TextStyle(color: Colors.white38),
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        prefixIcon:
                            Icon(Icons.search_rounded, color: Colors.white54),
                      ),
                      onSubmitted: (_) => _searchManually(),
                      textInputAction: TextInputAction.search,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _searchManually,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: FuelixTheme.accentOrange,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.arrow_forward_rounded,
                        color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => setState(() => _showManualSearch = false),
              child: const Text('← Back to barcode scan',
                  style: TextStyle(color: Colors.white54)),
            ),
          ],
        ],
      ),
    );
  }
}

// Custom dark overlay painter with rectangular cutout
class _ScanOverlayPainter extends CustomPainter {
  final double boxSize;
  final Offset center;

  _ScanOverlayPainter({required this.boxSize, required this.center});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.6);
    final cornerPaint = Paint()
      ..color = FuelixTheme.accentOrange
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final left = center.dx - boxSize / 2;
    final top = center.dy - boxSize / 2;
    final rect = Rect.fromLTWH(left, top, boxSize, boxSize);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(16));

    // Dark overlay with hole
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);

    // Corner accents
    const cl = 28.0;
    final corners = [
      [Offset(left, top + cl), Offset(left, top), Offset(left + cl, top)],
      [Offset(left + boxSize - cl, top), Offset(left + boxSize, top), Offset(left + boxSize, top + cl)],
      [Offset(left + boxSize, top + boxSize - cl), Offset(left + boxSize, top + boxSize), Offset(left + boxSize - cl, top + boxSize)],
      [Offset(left + cl, top + boxSize), Offset(left, top + boxSize), Offset(left, top + boxSize - cl)],
    ];

    for (final pts in corners) {
      final p = Path()
        ..moveTo(pts[0].dx, pts[0].dy)
        ..lineTo(pts[1].dx, pts[1].dy)
        ..lineTo(pts[2].dx, pts[2].dy);
      canvas.drawPath(p, cornerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
