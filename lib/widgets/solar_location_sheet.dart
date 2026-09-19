import 'package:flutter/material.dart';

import '../colors.dart';
import '../l10n/app_localizations.dart';
import '../services/solar_time_service.dart';

/// Lets the user set the coordinates used for sunrise/sunset calculation,
/// either from a single GPS reading or by typing them in.
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
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _latController =
        TextEditingController(text: _service.latitude?.toStringAsFixed(4) ?? '');
    _lngController =
        TextEditingController(text: _service.longitude?.toStringAsFixed(4) ?? '');
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

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

  Future<void> _saveManual() async {
    final l = AppLocalizations.of(context);
    final lat = double.tryParse(_latController.text.trim().replaceAll(',', '.'));
    final lng = double.tryParse(_lngController.text.trim().replaceAll(',', '.'));

    if (lat == null || lng == null || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      setState(() => _error = l.solarCoordinatesInvalid);
      return;
    }

    setState(() => _busy = true);
    await _service.setManualLocation(lat, lng);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
            SizedBox(
              width: double.infinity,
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
            ),
            const SizedBox(height: 20),
            Text(
              l.solarEnterManually,
              style: const TextStyle(
                color: textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _coordinateField(_latController, l.solarLatitude)),
                const SizedBox(width: 12),
                Expanded(child: _coordinateField(_lngController, l.solarLongitude)),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: MyColors.remove, fontSize: 13),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _busy ? null : () => Navigator.pop(context, false),
                  child: Text(
                    l.commonCancel,
                    style: const TextStyle(color: textMuted),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _busy ? null : _saveManual,
                  child: Text(
                    l.commonSave,
                    style: const TextStyle(
                      color: MyColors.orangeDivider,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _coordinateField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: textPrimary),
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: textMuted),
        border: OutlineInputBorder(
          borderSide: const BorderSide(color: cardBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: cardBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: MyColors.orangeDivider, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
