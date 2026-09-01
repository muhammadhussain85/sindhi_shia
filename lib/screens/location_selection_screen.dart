import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/settings_controller.dart';
import '../database/db_helper.dart';
import '../utils/app_colors.dart';

class LocationSelectionScreen extends StatefulWidget {
  const LocationSelectionScreen({super.key});

  @override
  State<LocationSelectionScreen> createState() => _LocationSelectionScreenState();
}

class _LocationSelectionScreenState extends State<LocationSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  final SettingsController settings = Get.find<SettingsController>();

  bool _isLoading = true;
  Timer? _searchDebounce;

  // State lists driven entirely by your local Database
  List<String> _dbCountries = [];
  List<Map<String, dynamic>> _dbCountryCities = [];
  List<Map<String, dynamic>> _searchResults = [];
  List<dynamic> _recentSearches = [];

  String? _viewingCitiesForCountry;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    // 1. Load recents from GetStorage
    _recentSearches = settings.storage.read('recent_locations') ?? [];

    // 2. Load all available countries from your local SQLite DB
    try {
      _dbCountries = await DBHelper.getCountries();
    } catch (e) {
      debugPrint("Error loading countries: $e");
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // ✨ INSTANT OFFLINE SEARCH USING LOCAL DB
  Future<void> _searchCity(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _viewingCitiesForCountry = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _viewingCitiesForCountry = null;
    });

    try {
      final results = await DBHelper.searchCities(query.trim());
      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
      });
    }

    setState(() => _isLoading = false);
  }

  // ✨ LOAD CITIES WHEN A COUNTRY IS TAPPED
  Future<void> _loadCitiesForCountry(String country) async {
    setState(() => _isLoading = true);

    try {
      final cities = await DBHelper.getCitiesByCountry(country);
      setState(() {
        _dbCountryCities = cities;
        _viewingCitiesForCountry = country;
      });
    } catch (e) {
      debugPrint("Error loading cities: $e");
    }

    setState(() => _isLoading = false);
  }

  void _selectCity(String cityName, String countryName, double lat, double lng) {
    String fullName = "$cityName, $countryName";

    // ✨ SAVE TO RECENT SEARCHES
    List<dynamic> recents = List.from(_recentSearches);
    recents.removeWhere((item) => item['name'] == fullName); // Remove duplicate
    recents.insert(0, {'name': fullName, 'city': cityName, 'country': countryName, 'lat': lat, 'lng': lng});
    if (recents.length > 5) recents = recents.sublist(0, 5); // Keep max 5

    settings.storage.write('recent_locations', recents);
    setState(() => _recentSearches = recents);

    // Update App Settings
    settings.setCity(fullName, lat, lng);
    settings.isManualLocation.value = true;
    settings.storage.write('isManualLocation', true);
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final bgColor = AppColors.background;
      final cardColor = AppColors.card;
      final textColor = AppColors.text;
      final goldColor = AppColors.gold;

      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          toolbarHeight: 70,
          title: Text('شهر جي ڳولا', style: TextStyle(fontFamily: 'MBLateefi', fontSize: 26, fontWeight: FontWeight.bold, color: textColor)),
          backgroundColor: cardColor,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: goldColor, size: 22),
            onPressed: () {
              // If we are looking at cities, go back to countries. Otherwise, exit screen.
              if (_viewingCitiesForCountry != null) {
                setState(() => _viewingCitiesForCountry = null);
              } else {
                Get.back();
              }
            },
          ),
        ),
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              // ✨ AUTO-DETECT BUTTON
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: InkWell(
                  onTap: () async {
                    await settings.setAutoMode(true);
                    if (!settings.isManualLocation.value) Get.back();
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [goldColor.withValues(alpha:0.9), goldColor]),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: goldColor.withValues(alpha:0.3), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha:0.2), shape: BoxShape.circle),
                          child: const Icon(Icons.my_location_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("موجوده لوڪيشن (Auto Detect)", style: TextStyle(fontFamily: 'MBLateefi', fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                              Text("GPS ذريعي پنهنجو شهر ڳوليو", style: TextStyle(fontFamily: 'MBLateefi', fontSize: 16, color: Colors.white70)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ✨ SEARCH BAR WITH ENGLISH EXAMPLES
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  controller: _searchController,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  style: TextStyle(fontFamily: 'MBLateefi', fontSize: 20, color: textColor),
                  decoration: InputDecoration(
                    hintText: "Search city (e.g., Karachi, Najaf...)",
                    hintStyle: TextStyle(fontFamily: 'Arial', fontSize: 16, color: textColor.withValues(alpha:0.4)),
                    prefixIcon: Icon(Icons.search_rounded, color: goldColor),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                      icon: Icon(Icons.clear_rounded, color: textColor.withValues(alpha:0.5)),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchResults = [];
                          _viewingCitiesForCountry = null;
                        });
                      },
                    )
                        : null,
                    filled: true,
                    fillColor: cardColor,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: goldColor, width: 1.5)),
                  ),
                  onSubmitted: _searchCity,
                  onChanged: (val) {
                    // Debounce: wait 300 ms after the user stops typing before hitting the DB
                    _searchDebounce?.cancel();
                    _searchDebounce = Timer(const Duration(milliseconds: 300), () => _searchCity(val));
                  },
                ),
              ),
              const SizedBox(height: 10),

              // ✨ DYNAMIC UI ROUTER
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: goldColor))
                    : _viewingCitiesForCountry != null
                    ? _buildCountryCitiesList(cardColor, textColor, goldColor)
                    : _searchController.text.isEmpty
                    ? _buildDefaultLists(cardColor, textColor, goldColor)
                    : _buildSearchResults(cardColor, textColor, goldColor),
              ),
            ],
          ),
        ),
      );
    });
  }

  // ✨ VIEW 1: DEFAULT (Recents + DB Countries)
  Widget _buildDefaultLists(Color cardColor, Color textColor, Color goldColor) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        if (_recentSearches.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0, right: 8.0, top: 8.0),
            child: Text("تازو ڳوليل (Recent Searches)", style: TextStyle(fontFamily: 'MBLateefi', fontSize: 18, fontWeight: FontWeight.bold, color: goldColor)),
          ),
          ..._recentSearches.map((item) => _buildSimpleTile(
              item['name'],
              Icons.history_rounded,
              cardColor, textColor, goldColor,
              onTap: () => _selectCity(item['city'], item['country'], item['lat'], item['lng'])
          )).toList(),
          const SizedBox(height: 16),
        ],

        Padding(
          padding: const EdgeInsets.only(bottom: 12.0, right: 8.0, top: 8.0),
          child: Text("ملڪ (Countries)", style: TextStyle(fontFamily: 'MBLateefi', fontSize: 20, fontWeight: FontWeight.bold, color: goldColor)),
        ),

        if (_dbCountries.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text("No countries found in database.", style: TextStyle(color: textColor.withValues(alpha:0.5))),
          )
        else
          ..._dbCountries.map((country) => _buildSimpleTile(
              country,
              Icons.public_rounded,
              cardColor, textColor, goldColor,
              isCountry: true,
              onTap: () => _loadCitiesForCountry(country)
          )).toList(),
      ],
    );
  }

  // ✨ VIEW 2: SEARCH RESULTS FROM DB
  Widget _buildSearchResults(Color cardColor, Color textColor, Color goldColor) {
    if (_searchResults.isEmpty) {
      return Center(
        child: Text("ڪو به نتيجو نه مليو", style: TextStyle(fontFamily: 'MBLateefi', fontSize: 20, color: textColor.withValues(alpha:0.5))),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        final String city = result['city'] ?? 'Unknown';
        final String country = result['country'] ?? 'Unknown';
        final double lat = (result['lat'] as num).toDouble();
        final double lng = (result['lng'] as num).toDouble();

        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0, right: 8.0),
                child: Text("ڳولا جا نتيجا (Search Results)", style: TextStyle(fontFamily: 'MBLateefi', fontSize: 18, fontWeight: FontWeight.bold, color: goldColor)),
              ),
              _buildDetailedResultCard(city, country, lat, lng, cardColor, textColor, goldColor),
            ],
          );
        }

        return _buildDetailedResultCard(city, country, lat, lng, cardColor, textColor, goldColor);
      },
    );
  }

  // ✨ VIEW 3: CITIES INSIDE A SELECTED COUNTRY
  Widget _buildCountryCitiesList(Color cardColor, Color textColor, Color goldColor) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text("شهر چونڊيو ($_viewingCitiesForCountry)", style: TextStyle(fontFamily: 'MBLateefi', fontSize: 18, fontWeight: FontWeight.bold, color: goldColor)),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _viewingCitiesForCountry = null),
              icon: Icon(Icons.arrow_forward_rounded, size: 16, color: textColor.withValues(alpha:0.6)),
              label: Text("واپس", style: TextStyle(fontFamily: 'MBLateefi', color: textColor.withValues(alpha:0.6))),
            )
          ],
        ),
        const SizedBox(height: 10),

        if (_dbCountryCities.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: goldColor.withValues(alpha:0.2))),
            child: Column(
              children: [
                Icon(Icons.location_off_rounded, color: goldColor.withValues(alpha:0.5), size: 40),
                const SizedBox(height: 10),
                Text("هن ملڪ ۾ ڪوبه شهر نه مليو.", textAlign: TextAlign.center, style: TextStyle(fontFamily: 'MBLateefi', fontSize: 18, color: textColor.withValues(alpha:0.8), height: 1.5)),
              ],
            ),
          )
        else
          ..._dbCountryCities.map((cityData) => _buildSimpleTile(
              cityData['city'],
              Icons.location_city_rounded,
              cardColor, textColor, goldColor,
              onTap: () {
                _selectCity(cityData['city'], _viewingCitiesForCountry!, (cityData['lat'] as num).toDouble(), (cityData['lng'] as num).toDouble());
              }
          )).toList(),
      ],
    );
  }

  // --- UI HELPER COMPONENTS ---

  Widget _buildDetailedResultCard(String city, String country, double lat, double lng, Color cardColor, Color textColor, Color goldColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: goldColor.withValues(alpha:0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _selectCity(city, country, lat, lng),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.public_rounded, color: goldColor.withValues(alpha:0.7), size: 24),
                    const SizedBox(width: 12),
                    Text("ملڪ (Country):", style: TextStyle(fontFamily: 'MBLateefi', fontSize: 18, color: textColor.withValues(alpha:0.6))),
                    const SizedBox(width: 12),
                    Expanded(child: Text(country, textDirection: TextDirection.ltr, textAlign: TextAlign.right, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor))),
                  ],
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Divider(color: goldColor.withValues(alpha:0.1), height: 1),
                ),

                Row(
                  children: [
                    Icon(Icons.location_city_rounded, color: goldColor.withValues(alpha:0.7), size: 24),
                    const SizedBox(width: 12),
                    Text("شهر (City):", style: TextStyle(fontFamily: 'MBLateefi', fontSize: 18, color: textColor.withValues(alpha:0.6))),
                    const SizedBox(width: 12),
                    Expanded(child: Text(city, textDirection: TextDirection.ltr, textAlign: TextAlign.right, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor))),
                  ],
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: goldColor.withValues(alpha:0.1),
                      foregroundColor: goldColor,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: goldColor.withValues(alpha:0.3))),
                    ),
                    onPressed: () => _selectCity(city, country, lat, lng),
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text("هن جڳهه کي چونڊيو (Select)", style: TextStyle(fontFamily: 'MBLateefi', fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleTile(String name, IconData icon, Color cardColor, Color textColor, Color goldColor, {bool isCountry = false, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: goldColor.withValues(alpha:0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
        leading: Icon(icon, color: goldColor.withValues(alpha:0.7)),
        title: Text(name, textDirection: TextDirection.ltr, textAlign: TextAlign.right, style: TextStyle(fontFamily: 'MBLateefi', fontSize: 20, color: textColor, fontWeight: FontWeight.bold)),
        trailing: Icon(isCountry ? Icons.arrow_back_ios_new_rounded : Icons.add_location_alt_rounded, color: textColor.withValues(alpha:0.3), size: 18),
        onTap: onTap,
      ),
    );
  }
}