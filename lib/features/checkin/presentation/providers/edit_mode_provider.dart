import 'package:flutter/material.dart';

/// Provider for managing edit mode state in checkin screen
class EditModeProvider with ChangeNotifier {
  bool _isEditMode = false;

  /// Get current edit mode state
  bool get isEditMode => _isEditMode;

  /// Toggle edit mode on/off
  void toggleEditMode() {
    _isEditMode = !_isEditMode;
    notifyListeners();
  }

  /// Set edit mode explicitly
  void setEditMode(bool value) {
    if (_isEditMode != value) {
      _isEditMode = value;
      notifyListeners();
    }
  }

  /// Exit edit mode
  void exitEditMode() {
    if (_isEditMode) {
      _isEditMode = false;
      notifyListeners();
    }
  }
}
