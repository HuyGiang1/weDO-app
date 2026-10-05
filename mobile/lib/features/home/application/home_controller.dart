import 'package:flutter/foundation.dart';

import '../data/home_models.dart';
import '../data/home_repository.dart';

class HomeController extends ChangeNotifier {
  final HomeGateway repository;
  HomeController(this.repository);

  HomeResponse? value;
  Object? error;
  bool loading = false;
  bool _disposed = false;
  int _generation = 0;

  Future<void> load() async {
    final generation = ++_generation;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await repository.load();
      if (_disposed || generation != _generation) return;
      value = result;
    } catch (exception) {
      if (_disposed || generation != _generation) return;
      error = exception;
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
