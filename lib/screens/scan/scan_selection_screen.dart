import 'package:flutter/material.dart';
import '../../utils/theme.dart';
import 'barcode_scanner_screen.dart';
import 'camera_screen.dart';

class ScanSelectionScreen extends StatefulWidget {
  const ScanSelectionScreen({super.key});

  @override
  State<ScanSelectionScreen> createState() => _ScanSelectionScreenState();
}

class _ScanSelectionScreenState extends State<ScanSelectionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? FuelixTheme.darkBg : FuelixTheme.lightBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: isDark ? Colors.white : FuelixTheme.textDarkPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // Header
              Text(
                'Scan Food',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : FuelixTheme.textDarkPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose how to identify your food',
                style: TextStyle(
                  fontSize: 15,
                  color: isDark
                      ? FuelixTheme.textLightSecondary
                      : FuelixTheme.textDarkSecondary,
                ),
              ),
              const SizedBox(height: 40),

              // Animated Icon
              Center(
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) => Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          colors: [
                            Color(0x33FF6B35),
                            Color(0x00FF6B35),
                          ],
                        ),
                        border: Border.all(
                            color: FuelixTheme.accentOrange.withValues(alpha: 0.3),
                            width: 2),
                      ),
                      child: const Icon(
                        Icons.document_scanner_rounded,
                        size: 56,
                        color: FuelixTheme.accentOrange,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 48),

              // Option Cards
              _ScanOptionCard(
                icon: Icons.qr_code_scanner_rounded,
                title: 'Scan Barcode',
                subtitle: 'For packaged & branded foods\nInstant nutrition from Open Food Facts',
                accentColor: FuelixTheme.accentOrange,
                badge: 'UNLIMITED',
                badgeColor: Colors.green,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const BarcodeScannerScreen()),
                ),
              ),
              const SizedBox(height: 16),
              _ScanOptionCard(
                icon: Icons.camera_enhance_rounded,
                title: 'Scan Meal Photo',
                subtitle: 'For home-cooked or restaurant meals\nGemini AI identifies dish & portions',
                accentColor: FuelixTheme.accentLime,
                badge: '5/DAY',
                badgeColor: Colors.deepPurple,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CameraScreen()),
                ),
              ),
              const Spacer(),

              // Info note
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 18, color: Colors.grey),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'AI scans are limited to 5 per day to keep the service free. Barcode scans are always unlimited.',
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? FuelixTheme.textLightSecondary
                                : FuelixTheme.textDarkSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanOptionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final String badge;
  final Color badgeColor;
  final VoidCallback onTap;

  const _ScanOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.badge,
    required this.badgeColor,
    required this.onTap,
  });

  @override
  State<_ScanOptionCard> createState() => _ScanOptionCardState();
}

class _ScanOptionCardState extends State<_ScanOptionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? FuelixTheme.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.accentColor.withValues(alpha: 0.25),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.accentColor.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: widget.accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(widget.icon, color: widget.accentColor, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? Colors.white
                                : FuelixTheme.textDarkPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: widget.badgeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            widget.badge,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: widget.badgeColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: isDark
                            ? FuelixTheme.textLightSecondary
                            : FuelixTheme.textDarkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: widget.accentColor.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
