import 'dart:async';
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
  Timer? _driverMovementTimer;

  bool _isRequestActive = false;
  int _etaMinutes = 8;
  double _distanceKm = 2.4;

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

  @override
  void dispose() {
    _driverMovementTimer?.cancel();
    super.dispose();
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

  void _startDriverMovement() {
    _driverMovementTimer?.cancel();
    _driverMovementTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      setState(() {
        _driverLocations = _driverLocations.map((driverPos) {
          double newLat = driverPos.latitude + (_currentPosition.latitude - driverPos.latitude) * 0.02;
          double newLng = driverPos.longitude + (_currentPosition.longitude - driverPos.longitude) * 0.02;
          return LatLng(newLat, newLng);
        }).toList();

        if (_driverLocations.isNotEmpty) {
          double distanceInMeters = Geolocator.distanceBetween(
            _currentPosition.latitude,
            _currentPosition.longitude,
            _driverLocations[0].latitude,
            _driverLocations[0].longitude,
          );
          _distanceKm = distanceInMeters / 1000;
          _etaMinutes = (_distanceKm * 3).ceil();

          if (_distanceKm < 0.05) {
            _etaMinutes = 0;
            _driverMovementTimer?.cancel();
          }
        }
      });
    });
  }

  void _cancelRequest() {
    _driverMovementTimer?.cancel();
    setState(() {
      _isRequestActive = false;
      _generateMockDrivers(_currentPosition.latitude, _currentPosition.longitude);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Assistance request cancelled.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showDriverProfile(int driverIndex) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.redAccent,
                  child: Icon(Icons.person, color: Colors.white, size: 30),
                ),
                title: Text(
                  'Assigned Driver #${driverIndex + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                subtitle: const Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber, size: 18),
                    SizedBox(width: 4),
                    Text('4.9 (120 reviews)'),
                  ],
                ),
              ),
              const Divider(),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text('Vehicle', style: TextStyle(color: Colors.grey)),
                      SizedBox(height: 4),
                      Text('Tow Truck', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Column(
                    children: [
                      Text('License Plate', style: TextStyle(color: Colors.grey)),
                      SizedBox(height: 4),
                      Text('WP CAB-4821', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.phone, color: Colors.white),
                  label: const Text(
                    'CALL DRIVER',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Calling driver... (+94 77 123 4567)'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
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
              setState(() {
                _isRequestActive = true;
              });
              _startDriverMovement();
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
              if (_isRequestActive && _driverLocations.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [_currentPosition, _driverLocations[0]],
                      strokeWidth: 4.0,
                      color: Colors.redAccent,
                    ),
                  ],
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
                  for (int i = 0; i < _driverLocations.length; i++)
                    Marker(
                      point: _driverLocations[i],
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: () => _showDriverProfile(i),
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

          if (_isRequestActive)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Card(
                color: Colors.black87,
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const CircularProgressIndicator(
                        color: Colors.redAccent,
                        strokeWidth: 3,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _etaMinutes > 0
                                  ? 'Driver En Route ($_selectedService)'
                                  : 'Driver Arrived!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _etaMinutes > 0
                                  ? 'ETA: ~$_etaMinutes min (${_distanceKm.toStringAsFixed(1)} km away)'
                                  : 'Your assistance unit has reached your location.',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: _cancelRequest,
                      ),
                    ],
                  ),
                ),
              ),
            ),

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
                              onSelected: _isRequestActive
                                  ? null
                                  : (selected) {
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
                          backgroundColor: _isRequestActive
                              ? Colors.grey
                              : Colors.redAccent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: Icon(
                          _isRequestActive ? Icons.check : Icons.warning,
                          color: Colors.white,
                        ),
                        label: Text(
                          _isRequestActive
                              ? 'DISPATCH IN PROGRESS'
                              : 'REQUEST ${_selectedService.toUpperCase()}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: _isRequestActive
                            ? null
                            : _showRequestConfirmation,
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