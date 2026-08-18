import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/allowed_service.dart';
import '../repositories/allowed_services_repository.dart';

class SelectedServicesNotifier extends StateNotifier<List<AllowedService>> {
  SelectedServicesNotifier() : super(AllowedServicesRepository.getAllServices());

  static const List<String> alwaysAllowedHosts = [
    'accounts.google.com', // Firebase Auth
    'firebaseio.com',      // Firebase RTDB
    'googleapis.com',      // Firebase SDK
  ];

  void toggle(String serviceId) {
    state = state.map((service) {
      if (service.id == serviceId) {
        return service.copyWith(isSelected: !service.isSelected);
      }
      return service;
    }).toList();
  }

  void selectAll(String category) {
    state = state.map((service) {
      if (service.category == category) {
        return service.copyWith(isSelected: true);
      }
      return service;
    }).toList();
  }

  void deselectAll(String category) {
    state = state.map((service) {
      if (service.category == category) {
        return service.copyWith(isSelected: false);
      }
      return service;
    }).toList();
  }

  void addCustomDomain(String domain) {
    final customService = AllowedService(
      id: 'custom-$domain',
      name: domain,
      category: 'Custom',
      hosts: [domain],
      iconAsset: 'assets/icons/custom.png',
      isSelected: true,
    );
    state = [...state, customService];
  }

  List<String> get flatHostList {
    final selectedHosts = state
        .where((service) => service.isSelected)
        .expand((service) => service.hosts)
        .toList();
    return [...alwaysAllowedHosts, ...selectedHosts];
  }
}

final selectedServicesProvider =
    StateNotifierProvider<SelectedServicesNotifier, List<AllowedService>>(
  (ref) => SelectedServicesNotifier(),
);