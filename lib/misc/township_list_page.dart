import 'package:flutter/material.dart';

import '../data/myanmar_locations.dart';

/// 2. Main Stateful Widget Page
class MyanmarTownshipPage extends StatefulWidget {
  const MyanmarTownshipPage({super.key});

  @override
  State<MyanmarTownshipPage> createState() => _MyanmarTownshipPageState();
}

class _MyanmarTownshipPageState extends State<MyanmarTownshipPage> {
  // Controllers & Filtering States
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedStateCode;
  String? _selectedDistrictCode;

  List<Township> _filteredTownships = [];

  @override
  void initState() {
    super.initState();
    _filteredTownships = myanmarTownships; // Initialize with full list
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _applyFilters();
    });
  }

  /// Combined Filter and Search Logic
  void _applyFilters() {
    setState(() {
      _filteredTownships = myanmarTownships.where((ts) {
        // 1. Filter by State/Region
        if (_selectedStateCode != null && ts.srPcode != _selectedStateCode) {
          return false;
        }

        // 2. Filter by District
        if (_selectedDistrictCode != null && ts.dPcode != _selectedDistrictCode) {
          return false;
        }

        // 3. Multi-Field Global Search (English, Myanmar, and P-Codes)
        if (_searchQuery.isNotEmpty) {
          final matchesTownship = ts.township.toLowerCase().contains(_searchQuery) ||
              ts.townshipMya.contains(_searchQuery) ||
              ts.tsPcode.toLowerCase().contains(_searchQuery);

          final matchesDistrict = ts.district.toLowerCase().contains(_searchQuery) ||
              ts.districtMya.contains(_searchQuery) ||
              ts.dPcode.toLowerCase().contains(_searchQuery);

          final matchesState = ts.stateRegion.toLowerCase().contains(_searchQuery) ||
              ts.stateRegionMya.contains(_searchQuery) ||
              ts.srPcode.toLowerCase().contains(_searchQuery);

          return matchesTownship || matchesDistrict || matchesState;
        }

        return true;
      }).toList();
    });
  }

  /// Reset all criteria
  void _clearAllFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _selectedStateCode = null;
      _selectedDistrictCode = null;
      _filteredTownships = myanmarTownships;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Extract unique states available in the data source
    final states = {
      for (var ts in myanmarTownships) ts.srPcode: '${ts.stateRegion} (${ts.stateRegionMya})'
    };

    // Dynamically extract districts matching the currently selected State
    final districts = {
      for (var ts in myanmarTownships)
        if (_selectedStateCode == null || ts.srPcode == _selectedStateCode)
          ts.dPcode: '${ts.district} (${ts.districtMya})'
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Myanmar Locations Master'),
        centerTitle: false,
        actions: [
          if (_searchQuery.isNotEmpty || _selectedStateCode != null || _selectedDistrictCode != null)
            TextButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Reset'),
              onPressed: _clearAllFilters,
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter & Search Dashboard Container
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: Column(
              children: [
                // 1. Omnibox Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by township, district, state or P-Code...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => _searchController.clear(),
                    )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                  ),
                ),
                const SizedBox(height: 12),

                // 2. Dropdown Filters Row
                Row(
                  children: [
                    // State / Region Dropdown
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedStateCode,
                        hint: const Text('All States/Regions'),
                        isExpanded: true,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                        ),
                        items: states.entries.map((entry) {
                          return DropdownMenuItem(value: entry.key, child: Text(entry.value));
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedStateCode = value;
                            _selectedDistrictCode = null; // Reset district selection on state change
                            _applyFilters();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),

                    // District Dropdown
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedDistrictCode,
                        hint: const Text('All Districts'),
                        isExpanded: true,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                        ),
                        items: districts.entries.map((entry) {
                          return DropdownMenuItem(value: entry.key, child: Text(entry.value));
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedDistrictCode = value;
                            _applyFilters();
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Total Count Indicator Banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${_filteredTownships.length} Townships',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (myanmarTownships.length != _filteredTownships.length)
                  Text(
                    'Filtered from ${myanmarTownships.length}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),

          // 3. Dynamic Results List View
          Expanded(
            child: _filteredTownships.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_off_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No matching locations found',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: _filteredTownships.length,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemBuilder: (context, index) {
                final item = _filteredTownships[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  elevation: 0.5,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.2)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        item.township[0],
                        style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
                      ),
                    ),
                    title: Text(
                      '${item.township} / ${item.townshipMya}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${item.district} • ${item.stateRegion}',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Table(
                          columnWidths: const {
                            0: FixedColumnWidth(130),
                            1: FlexColumnWidth(),
                          },
                          children: [
                            _buildDataRow('Township P-Code', item.tsPcode),
                            _buildDataRow('District P-Code', item.dPcode),
                            _buildDataRow('District (Mya)', item.districtMya),
                            _buildDataRow('State P-Code', item.srPcode),
                            _buildDataRow('State (Mya)', item.stateRegionMya),
                            _buildDataRow('Source', item.source),
                          ],
                        ),
                      )
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  TableRow _buildDataRow(String label, String value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}
