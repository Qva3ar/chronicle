import 'package:flutter/material.dart';

import '../colors.dart';
import '../l10n/app_localizations.dart';
import '../services/solar_time_service.dart';

/// Shows where sunrise/sunset are being computed for, and lets the user swap
/// between the timezone estimate and a one-off GPS fix.
///
/// Returns true when the location changed, so the caller can refresh anything
/// derived from it.
Future<bool> showSolarLocationSheet(BuildContext context) async {
  final changed = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _SolarLocationSheet(),
  );
  return changed ?? false;
}

class _SolarLocationSheet extends StatefulWidget {
  const _SolarLocationSheet();

  @override
  State<_SolarLocationSheet> createState() => _SolarLocationSheetState();
}

class _SolarLocationSheetState extends State<_SolarLocationSheet> {
  final _service = SolarTimeService.instance;
  bool _busy = false;
  String? _error;

  String _errorMessage(AppLocalizations l, SolarLocationResult result) {
    return switch (result) {
      SolarLocationResult.serviceDisabled => l.solarErrorServiceDisabled,
      SolarLocationResult.permissionDenied => l.solarErrorPermissionDenied,
      SolarLocationResult.permissionDeniedForever => l.solarErrorPermissionForever,
      _ => l.solarErrorFailed,
    };
  }

  Future<void> _useGps() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await _service.refreshFromGps();
    if (!mounted) return;

    if (result == SolarLocationResult.success) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _busy = false;
      _error = _errorMessage(l, result);
    });
  }

  Future<void> _useTimezone() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    final changed = await _service.useTimezoneLocation();
    if (!mounted) return;
    Navigator.pop(context, changed);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l.solarLocationTitle,
              style: const TextStyle(
                color: textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l.solarLocationDesc,
              style: const TextStyle(color: textMuted, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),
            _currentLocationCard(l),
            const SizedBox(height: 16),
            if (!_service.isFromGps)
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _useGps,
                  icon: const Icon(Icons.my_location_rounded, size: 18),
                  label: Text(l.solarUseGps),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MyColors.orangeDivider,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              )
            else
              SizedBox(
                height: 48,
                child: TextButton.icon(
                  onPressed: _busy ? null : _useTimezone,
                  icon: const Icon(Icons.schedule_rounded, size: 18),
                  label: Text(l.solarUseTimezone),
                  style: TextButton.styleFrom(foregroundColor: textSecondary),
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: MyColors.remove, fontSize: 13),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context, false),
                child: Text(
                  l.commonClose,
                  style: const TextStyle(color: textMuted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _currentLocationCard(AppLocalizations l) {
    final hasLocation = _service.hasLocation;
    final title = hasLocation
        ? (_service.label ??
            '${_service.latitude!.toStringAsFixed(3)}, '
                '${_service.longitude!.toStringAsFixed(3)}')
        : l.solarLocationNotSet;
    final subtitle = _service.isFromGps
        ? l.solarLocationSourceGps
        : l.solarLocationSourceTimezone;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardColor2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.place_outlined, color: infoColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: textPrimary, fontSize: 15),
                ),
                if (hasLocation) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: textMuted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          if (_busy)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}
