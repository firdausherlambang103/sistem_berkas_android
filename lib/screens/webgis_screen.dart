import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../api_config.dart';

class WebgisScreen extends StatefulWidget {
  const WebgisScreen({super.key});

  @override
  State<WebgisScreen> createState() => _WebgisScreenState();
}

class _WebgisScreenState extends State<WebgisScreen> {
  final MapController _mapController = MapController();
  List<Polygon> polygons = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchSpatialData();
    });
  }

  Future<void> _fetchSpatialData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final bounds = _mapController.camera.visibleBounds;
      final north = bounds.north;
      final south = bounds.south;
      final east = bounds.east;
      final west = bounds.west;

      SharedPreferences prefs = await SharedPreferences.getInstance();
      // SESUAIKAN: Pastikan key di bawah ('token') sama dengan key yang Anda pakai saat Login
      String? token = prefs.getString('token'); 

      final url = Uri.parse('${ApiConfig.baseUrl}/api/map/spatial-data?north=$north&south=$south&east=$east&west=$west');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // --- DEBUGGING: Cek apakah data benar-benar masuk ---
        final featuresCount = (data['features'] as List?)?.length ?? 0;
        debugPrint("SUKSES API: Menerima $featuresCount data aset polygon di area ini.");
        // ----------------------------------------------------

        _parseGeoJsonToPolygons(data);
      } else {
        debugPrint("GAGAL API: Status ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      debugPrint("ERROR FETCHING: $e");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _parseGeoJsonToPolygons(Map<String, dynamic> geoJsonData) {
    List<Polygon> newPolygons = [];
    final features = geoJsonData['features'] as List?;

    if (features == null) return;

    for (var feature in features) {
      final geometry = feature['geometry'];
      if (geometry == null) continue;

      final type = geometry['type'];
      final coordinates = geometry['coordinates'];
      final properties = feature['properties'] ?? {};

      String colorHex = properties['layer_color'] ?? '#3388ff';
      Color layerColor = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));

      // PERBAIKAN: Handle struktur Geometry Polygon & MultiPolygon dari SHP
      try {
        if (type == 'Polygon') {
          newPolygons.add(_createPolygon(coordinates[0], layerColor, properties));
        } else if (type == 'MultiPolygon') {
          for (var polygonCoords in coordinates) {
            newPolygons.add(_createPolygon(polygonCoords[0], layerColor, properties));
          }
        }
      } catch (e) {
        debugPrint("Error parsing geometri: $e");
      }
    }

    setState(() {
      polygons = newPolygons;
    });
  }

  Polygon _createPolygon(List<dynamic> coords, Color color, Map<String, dynamic> props) {
    List<LatLng> points = [];
    for (var coord in coords) {
      points.add(LatLng(coord[1], coord[0]));
    }

    return Polygon(
      points: points,
      color: color.withOpacity(0.5), // Transparansi isian poligon
      borderColor: color,            // Warna outline
      borderStrokeWidth: 2.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WebGIS Native'),
        actions: [
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchSpatialData,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(-7.8228, 112.0118), // Pusat awal (Alun-Alun Kediri)
              initialZoom: 14.0,
              minZoom: 5.0,
              maxZoom: 19.0,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) {
                  _fetchSpatialData();
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.sistem_berkas_android',
              ),
              PolygonLayer(
                polygons: polygons,
              ),
            ],
          ),
          
          Positioned(
            bottom: 20,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5)
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.bolt, color: Colors.green, size: 16),
                  SizedBox(width: 5),
                  Text(
                    "Native Map Engine",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}