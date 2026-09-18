import 'package:flutter/material.dart';
import '../models/ride_session.dart';
import '../models/spend_summary.dart';
import '../services/api_service.dart';

class SpendProvider extends ChangeNotifier {
  final ApiService apiService;
  final String riderId;

  SpendSummaryModel? _spendSummary;
  List<RideHistoryItemModel> _history = [];
  bool _isLoading = false;

  SpendProvider({
    required this.apiService,
    this.riderId = 'demo_rider',
  }) {
    fetchData();
  }

  SpendSummaryModel? get spendSummary => _spendSummary;
  List<RideHistoryItemModel> get history => _history;
  bool get isLoading => _isLoading;

  Future<void> fetchData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final summary = await apiService.fetchSpendSummary(riderId);
      final historyList = await apiService.fetchRideHistory(riderId);
      _spendSummary = summary;
      _history = historyList;
    } catch (e) {
      // Handled
    }

    _isLoading = false;
    notifyListeners();
  }
}
