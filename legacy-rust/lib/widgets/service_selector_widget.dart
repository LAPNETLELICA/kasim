import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/allowed_service.dart';
import '../providers/selected_services_provider.dart';

class ServiceSelectorWidget extends ConsumerStatefulWidget {
  const ServiceSelectorWidget({super.key});

  @override
  ConsumerState<ServiceSelectorWidget> createState() => _ServiceSelectorWidgetState();
}

class _ServiceSelectorWidgetState extends ConsumerState<ServiceSelectorWidget> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customDomainController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customDomainController.dispose();
    super.dispose();
  }

  List<AllowedService> _getFilteredServices(List<AllowedService> services) {
    if (_searchQuery.isEmpty) return services;
    return services.where((service) =>
        service.name.toLowerCase().contains(_searchQuery) ||
        service.category.toLowerCase().contains(_searchQuery) ||
        service.hosts.any((host) => host.toLowerCase().contains(_searchQuery))
    ).toList();
  }

  Map<String, List<AllowedService>> _groupByCategory(List<AllowedService> services) {
    final grouped = <String, List<AllowedService>>{};
    for (final service in services) {
      grouped.putIfAbsent(service.category, () => []).add(service);
    }
    return grouped;
  }

  bool _isCategoryFullySelected(String category, List<AllowedService> services) {
    final categoryServices = services.where((s) => s.category == category);
    return categoryServices.isNotEmpty && categoryServices.every((s) => s.isSelected);
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(selectedServicesProvider);
    final notifier = ref.read(selectedServicesProvider.notifier);
    final filteredServices = _getFilteredServices(services);
    final groupedServices = _groupByCategory(filteredServices);

    return Row(
      children: [
        // Left panel: Service selector
        Expanded(
          flex: 2,
          child: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search services...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),

              // Custom domain input
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _customDomainController,
                        decoration: const InputDecoration(
                          hintText: 'Add custom domain...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        final domain = _customDomainController.text.trim();
                        if (domain.isNotEmpty) {
                          notifier.addCustomDomain(domain);
                          _customDomainController.clear();
                        }
                      },
                      child: const Text('Add'),
                    ),
                  ],
                ),
              ),

              // Services list
              Expanded(
                child: ListView(
                  children: groupedServices.entries.map((entry) {
                    final category = entry.key;
                    final categoryServices = entry.value;
                    final isFullySelected = _isCategoryFullySelected(category, services);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category header with select all toggle
                        Container(
                          color: Colors.grey[200],
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              Text(
                                category,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () {
                                  if (isFullySelected) {
                                    notifier.deselectAll(category);
                                  } else {
                                    notifier.selectAll(category);
                                  }
                                },
                                child: Text(isFullySelected ? 'Deselect All' : 'Select All'),
                              ),
                            ],
                          ),
                        ),

                        // Services in category
                        ...categoryServices.map((service) => CheckboxListTile(
                          title: Text(service.name),
                          subtitle: Text(service.hosts.join(', ')),
                          value: service.isSelected,
                          onChanged: (value) => notifier.toggle(service.id),
                          secondary: const Icon(Icons.web), // Placeholder for icon
                        )),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        // Right panel: Selected summary
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Allowed during this exam',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Always Allowed:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Wrap(
                  spacing: 8,
                  children: SelectedServicesNotifier.alwaysAllowedHosts
                      .map((host) => Chip(label: Text(host)))
                      .toList(),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Selected Services:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: services
                        .where((service) => service.isSelected)
                        .expand((service) => service.hosts)
                        .map((host) => Chip(label: Text(host)))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}