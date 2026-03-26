import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class WebgisScreen extends StatefulWidget {
  const WebgisScreen({super.key});

  @override
  State<WebgisScreen> createState() => _WebgisScreenState();
}

class _WebgisScreenState extends State<WebgisScreen> {
  final MapController _mapController = MapController();
  bool _isLoading = false;
  bool _showLayerAset = true;
  String _currentBasemap = 'satellite';
  List<Polygon> _polygons = [];
  LatLng _initialCenter = const LatLng(-7.6043, 111.9034);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchSpatialData());
  }

  Future<void> _fetchSpatialData() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      final bounds = _mapController.camera.visibleBounds;

      final url = Uri.parse(
        'http://10.0.2.2:8000/api/map/spatial-data?'
        'north=${bounds.north}&'
        'south=${bounds.south}&'
        'east=${bounds.east}&'
        'west=${bounds.west}'
      );

      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json'
      });

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final List<dynamic> features = jsonResponse['features'] ?? [];
        _processWebFeatures(features);
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _processWebFeatures(List<dynamic> features) {
    List<Polygon> tempPolygons = [];
    for (var feature in features) {
      var geometry = feature['geometry'];
      var props = feature['properties'];
      if (geometry != null) {
        List<LatLng> points = [];
        var coordsRaw = geometry['type'] == 'MultiPolygon' 
            ? geometry['coordinates'][0][0] 
            : geometry['coordinates'][0];

        for (var c in coordsRaw) {
          points.add(LatLng(c[1].toDouble(), c[0].toDouble()));
        }

        if (points.isNotEmpty) {
          String colorHex = props['layer_color'] ?? '#3388ff';
          Color polyColor = Color(int.parse(colorHex.replaceFirst('#', '0xff')));
          tempPolygons.add(Polygon(
            points: points,
            color: polyColor.withOpacity(0.5),
            borderColor: polyColor,
            borderStrokeWidth: 2,
          ));
        }
      }
    }
    setState(() => _polygons = tempPolygons);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WebGIS PostGIS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D47A1),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: 15.0,
              onPositionChanged: (pos, hasGesture) {
                if (!hasGesture) _fetchSpatialData();
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _currentBasemap == 'satellite'
                    ? 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}'
                    : 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              ),
              if (_showLayerAset) PolygonLayer(polygons: _polygons),
            ],
          ),
          Positioned(
            top: 20, right: 15,
            child: Column(
              children: [
                _buildSideButton(
                  icon: _currentBasemap == 'satellite' ? Icons.map : Icons.satellite_alt,
                  onTap: () => setState(() => _currentBasemap = _currentBasemap == 'satellite' ? 'osm' : 'satellite'),
                ),
                const SizedBox(height: 12),
                _buildSideButton(
                  icon: Icons.layers,
                  color: _showLayerAset ? Colors.blue : Colors.grey,
                  onTap: () => setState(() => _showLayerAset = !_showLayerAset),
                ),
              ],
            ),
          ),
          if (_isLoading)
            const Positioned(top: 20, left: 0, right: 0, child: Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }

  Widget _buildSideButton({required IconData icon, required VoidCallback onTap, Color? color}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]),
      child: IconButton(icon: Icon(icon, color: color ?? const Color(0xFF0D47A1)), onPressed: onTap),
    );
  }
}