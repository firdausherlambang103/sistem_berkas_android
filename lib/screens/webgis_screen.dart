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
  // Titik tengah default Nganjuk/Kediri sesuai konteks MapController.php
  LatLng _initialCenter = const LatLng(-7.8200, 112.0118);

  @override
  void initState() {
    super.initState();
    // Memastikan koordinat awal siap sebelum memanggil API
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchSpatialData());
  }

  // ==============================================================
  // TOOLS 1: FETCH DATA BERBASIS VISIBLE BOUNDS (LOGIKA MapController.php)
  // ==============================================================
  Future<void> _fetchSpatialData() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    // Mengambil batas koordinat yang terlihat di layar HP (Bounding Box)
    final bounds = _mapController.camera.visibleBounds;
    final zoom = _mapController.camera.zoom.toInt();

    // Memanggil endpoint apiData sesuai rute di Laravel
    final url = Uri.parse(
      'http://10.0.2.2:8000/api/map/api-data?'
      'north=${bounds.north}&'
      'south=${bounds.south}&'
      'east=${bounds.east}&'
      'west=${bounds.west}&'
      'zoom=$zoom'
    );

    try {
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json'
      });

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        // MapController.php mengembalikan format FeatureCollection
        final List<dynamic> features = jsonResponse['features'] ?? [];
        _processWebFeatures(features);
      }
    } catch (e) {
      debugPrint("Error Sinkronisasi WebGIS: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ==============================================================
  // TOOLS 2: RENDER POLYGON & WARNA (LOGIKA MapLayer.php)
  // ==============================================================
  void _processWebFeatures(List<dynamic> features) {
    List<Polygon> tempPolygons = [];

    for (var feature in features) {
      var geometry = feature['geometry'];
      var props = feature['properties'];

      if (geometry != null && (geometry['type'] == 'Polygon' || geometry['type'] == 'MultiPolygon')) {
        List<LatLng> points = [];
        
        // Handle struktur koordinat GeoJSON (Polygon vs MultiPolygon)
        var coordsRaw = geometry['type'] == 'MultiPolygon' 
            ? geometry['coordinates'][0][0] 
            : geometry['coordinates'][0];

        for (var c in coordsRaw) {
          points.add(LatLng(c[1].toDouble(), c[0].toDouble()));
        }

        if (points.isNotEmpty) {
          // Mengambil warna dinamis (layer_color) yang sudah diproses oleh Laravel
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

  // ==============================================================
  // TOOLS 3: POPUP INFORMASI (SEPERTI popup content DI index.blade.php)
  // ==============================================================
  void _showPopup(LatLng point) {
    // Mencari polygon terdekat dari titik sentuh (simulasi click event)
    // Untuk pengembangan lanjut, gunakan MarkerLayer atau GestureDetector pada Polygon
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WebGIS Pertanahan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D47A1),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // KONTROL PETA UTAMA
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: 15.0,
              // Update data otomatis saat peta berhenti digeser (Idle)
              onPositionChanged: (position, hasGesture) {
                if (!hasGesture) _fetchSpatialData();
              },
            ),
            children: [
              // LAYERS 1: BASEMAP DINAMIS
              TileLayer(
                urlTemplate: _currentBasemap == 'satellite'
                    ? 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}' // Google Hybrid
                    : 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', // OSM
                userAgentPackageName: 'com.example.sistem_berkas_mobile',
              ),
              // LAYERS 2: DATA SPASIAL ASET
              if (_showLayerAset) PolygonLayer(polygons: _polygons),
            ],
          ),

          // ==============================================================
          // TOOLS PANEL: SIDEBAR KONTROL (SEPERTI DI resources/views/map/index.blade.php)
          // ==============================================================
          Positioned(
            top: 20, right: 15,
            child: Column(
              children: [
                // Ganti Basemap
                _buildSideButton(
                  icon: _currentBasemap == 'satellite' ? Icons.map : Icons.satellite_alt,
                  tooltip: "Ganti Tampilan Peta",
                  onTap: () => setState(() => _currentBasemap = _currentBasemap == 'satellite' ? 'osm' : 'satellite'),
                ),
                const SizedBox(height: 12),
                // Toggle Layer Aset
                _buildSideButton(
                  icon: _showLayerAset ? Icons.layers : Icons.layers_clear,
                  tooltip: "Tampilkan/Sembunyikan Layer",
                  color: _showLayerAset ? Colors.blue.shade900 : Colors.grey,
                  onTap: () => setState(() => _showLayerAset = !_showLayerAset),
                ),
                const SizedBox(height: 12),
                // Reset Kamera / Lokasi Berkas
                _buildSideButton(
                  icon: Icons.my_location,
                  tooltip: "Reset Posisi",
                  onTap: () => _mapController.move(_initialCenter, 15.0),
                ),
              ],
            ),
          ),

          // Indikator Sinkronisasi Data (Loading)
          if (_isLoading)
            Positioned(
              top: 20, left: 0, right: 0,
              child: Center(
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                        const SizedBox(width: 10),
                        Text("Memuat Data Spasial...", style: TextStyle(fontSize: 12, color: Colors.blue.shade900, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
          // LEGENDA TIPE HAK (Sama dengan resources/views/map/index.blade.php)
          Positioned(
            bottom: 20, left: 15,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("LEGENDA HAK", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  const Divider(height: 10),
                  _buildLegendItem("Hak Milik (HM)", const Color(0xFF28A745)),
                  _buildLegendItem("HGB", const Color(0xFFFFC107)),
                  _buildLegendItem("Hak Pakai (HP)", const Color(0xFF17A2B8)),
                  _buildLegendItem("Tanah Wakaf", const Color(0xFF6F42C1)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSideButton({required IconData icon, required VoidCallback onTap, Color? color, String? tooltip}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: IconButton(
        icon: Icon(icon, color: color ?? Colors.blue.shade900, size: 24),
        onPressed: onTap,
        tooltip: tooltip,
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}