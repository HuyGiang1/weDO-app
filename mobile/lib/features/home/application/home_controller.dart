import 'package:flutter/foundation.dart';
import '../../../core/network/api_exception.dart';

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

  void invalidateAccess() {
    if (_disposed) return;
    _generation++;
    value = null;
    notifyListeners();
  }

  Future<void> load({bool silent = false}) async {
    if (_disposed) return;
    final generation = ++_generation;
    loading = !silent;
    error = null;
    notifyListeners();
    try {
      final result = await repository.load();
      if (_disposed || generation != _generation) return;
      value = result;
    } catch (exception) {
      if (_disposed || generation != _generation) return;
      error = exception;
      if (exception is ApiException && [401,403,404].contains(exception.statusCode)) value = null;
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
