import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const RoadsideApp());
}

class RoadsideApp extends StatelessWidget {
  const RoadsideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Roadside Assistance',
      theme: ThemeData(primarySwatch: Colors.red),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  LatLng _currentPosition = const LatLng(6.9271, 79.8612);
  bool _isLoading = true;
  String _selectedService = 'Towing';

  List<LatLng> _driverLocations = [];

  final List<Map<String, dynamic>> _services = [
    {'name': 'Towing', 'icon': Icons.car_repair},
    {'name': 'Flat Tire', 'icon': Icons.tire_repair},
    {'name': 'Battery', 'icon': Icons.battery_charging_full},
    {'name': 'Fuel', 'icon': Icons.local_gas_station},
  ];

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _isLoading = false);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _isLoading = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: WebSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        ),
      );

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _generateMockDrivers(position.latitude, position.longitude);
        _isLoading = false;
      });

      _recenterMap();
    } catch (e) {
      Position? lastPosition = await Geolocator.getLastKnownPosition();
      if (lastPosition != null) {
        setState(() {
          _currentPosition = LatLng(lastPosition.latitude, lastPosition.longitude);
          _generateMockDrivers(lastPosition.latitude, lastPosition.longitude);
          _isLoading = false;
        });
        _recenterMap();
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  void _generateMockDrivers(double lat, double lng) {
    _driverLocations = [
      LatLng(lat + 0.003, lng + 0.002),
      LatLng(lat - 0.002, lng + 0.004),
      LatLng(lat + 0.004, lng - 0.003),
    ];
  }

  void _recenterMap() {
    _mapController.move(_currentPosition, 16.0);
  }

  void _showRequestConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.redAccent),
            const SizedBox(width: 8),
            Text('Confirm $_selectedService'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Service: $_selectedService'),
            const SizedBox(height: 6),
            Text(
              'Coordinates: ${_currentPosition.latitude.toStringAsFixed(4)}, ${_currentPosition.longitude.toStringAsFixed(4)}',
            ),
            const SizedBox(height: 12),
            const Text(
              'Are you sure you want to dispatch emergency help to this location?',
              style: TextStyle(color: Colors.black87),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$_selectedService unit dispatched to your location!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('CONFIRM', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Roadside Assistance'),
        backgroundColor: Colors.redAccent,
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 150.0),
        child: FloatingActionButton(
          backgroundColor: Colors.white,
          foregroundColor: Colors.redAccent,
          onPressed: _recenterMap,
          child: const Icon(Icons.my_location),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition,
              initialZoom: 16.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.roadside_app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _currentPosition,
                    width: 50,
                    height: 50,
                    child: const Icon(
                      Icons.my_location,
                      color: Colors.blueAccent,
                      size: 35,
                    ),
                  ),
                  ..._driverLocations.map(
                    (loc) => Marker(
                      point: loc,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.directions_car,
                        color: Colors.black87,
                        size: 30,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Select Assistance Type',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: _services.map((service) {
                          final isSelected = _selectedService == service['name'];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: ChoiceChip(
                              avatar: Icon(
                                service['icon'],
                                size: 18,
                                color: isSelected ? Colors.white : Colors.black87,
                              ),
                              label: Text(service['name']),
                              selected: isSelected,
                              selectedColor: Colors.redAccent,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : Colors.black,
                              ),
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _selectedService = service['name'];
                                  });
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.warning, color: Colors.white),
                        label: Text(
                          'REQUEST ${_selectedService.toUpperCase()}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: _showRequestConfirmation,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}