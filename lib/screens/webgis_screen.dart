import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import '../api_config.dart'; // Import ApiConfig untuk baseUrl

// Model untuk menyimpan data poligon dan atributnya agar bisa diklik
class AssetFeature {
  final Map<String, dynamic> properties;
  final List<List<LatLng>> polygons;
  final Color color;

  AssetFeature({
    required this.properties,
    required this.polygons,
    required this.color,
  });
}

class WebgisScreen extends StatefulWidget {
  const WebgisScreen({super.key});

  @override
  State<WebgisScreen> createState() => _WebgisScreenState();
}

class _WebgisScreenState extends State<WebgisScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  
  List<AssetFeature> assetFeatures = [];
  List<dynamic> availableLayers = [];
  Set<int> activeLayerIds = {};
  
  bool isLoading = false;
  double currentZoom = 14.0;
  bool isSatelliteMode = false; // Variabel untuk Toggle Satelit / Normal

  // --- VARIABEL UNTUK MODE MENGGAMBAR (DIGITASI) ---
  bool isDrawingMode = false;
  String drawingType = 'Polygon'; // 'Polygon' atau 'Point'
  List<LatLng> draftPoints = []; // Titik sementara saat menggambar

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchLayers(); // Ambil daftar layer dulu
      _fetchSpatialData();
    });
  }

  // --- 1. FUNGSI MENGAMBIL DAFTAR LAYER DARI API ---
  Future<void> _fetchLayers() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      
      final url = Uri.parse('${ApiConfig.baseUrl}/api/map/layers');
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      if (response.statusCode == 200) {
        setState(() {
          availableLayers = json.decode(response.body);
          activeLayerIds = availableLayers.map<int>((l) => l['id'] as int).toSet();
        });
      }
    } catch (e) {
      debugPrint("Gagal load layer: $e");
    }
  }

  // --- 2. FUNGSI MENGAMBIL DATA PETA ---
  Future<void> _fetchSpatialData() async {
    setState(() => isLoading = true);
    try {
      final bounds = _mapController.camera.visibleBounds;
      String token = (await SharedPreferences.getInstance()).getString('token') ?? '';
      String layerParam = activeLayerIds.join(',');

      final url = Uri.parse(
          '${ApiConfig.baseUrl}/api/map/spatial-data?north=${bounds.north}&south=${bounds.south}&east=${bounds.east}&west=${bounds.west}&layer_id=$layerParam'
      );

      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $token', 
        'Accept': 'application/json'
      });

      if (response.statusCode == 200) {
        _parseGeoJson(json.decode(response.body));
      }
    } catch (e) {
      debugPrint("Error Fetch Data: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _parseGeoJson(Map<String, dynamic> data) {
    List<AssetFeature> newFeatures = [];
    final features = data['features'] as List?;
    if (features == null) return;

    for (var feature in features) {
      final geom = feature['geometry'];
      final props = feature['properties'] ?? {};
      if (geom == null) continue;

      Color color = Color(int.parse((props['layer_color'] ?? '#3388ff').replaceFirst('#', '0xFF')));
      List<List<LatLng>> polyList = [];

      if (geom['type'] == 'Polygon') {
        polyList.add(_coordsToLatLng(geom['coordinates'][0]));
      } else if (geom['type'] == 'MultiPolygon') {
        for (var p in geom['coordinates']) {
          polyList.add(_coordsToLatLng(p[0]));
        }
      }

      if (polyList.isNotEmpty) {
        newFeatures.add(AssetFeature(properties: props, polygons: polyList, color: color));
      }
    }
    setState(() => assetFeatures = newFeatures);
  }

  List<LatLng> _coordsToLatLng(List<dynamic> coords) {
    return coords.map((c) => LatLng(c[1], c[0])).toList();
  }

  // --- 3. FUNGSI PENCARIAN ASET ---
  Future<void> _searchAsset(String query) async {
    if (query.isEmpty) return;
    setState(() => isLoading = true);
    try {
      String token = (await SharedPreferences.getInstance()).getString('token') ?? '';
      final url = Uri.parse('${ApiConfig.baseUrl}/api/map/search?q=$query');
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $token', 
        'Accept': 'application/json'
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          LatLng target = LatLng(data['lat'], data['lng']);
          _mapController.move(target, 18.0);
          _fetchSpatialData(); 
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aset tidak ditemukan')));
        }
      }
    } catch (e) {
      debugPrint("Search error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  // --- 4. LOKASI SAYA (GPS) ---
  Future<void> _goToMyLocation() async {
    setState(() => isLoading = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw 'Izin lokasi ditolak';
      }
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _mapController.move(LatLng(position.latitude, position.longitude), 16.0);
      _fetchSpatialData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() => isLoading = false);
    }
  }

  // --- 5. DETEKSI KLIK PETA (MENGGAMBAR ATAU INFO) ---
  void _handleMapTap(LatLng tapPosition) {
    if (isDrawingMode) {
      // Jika mode menggambar aktif, simpan titik yang disentuh
      setState(() {
        if (drawingType == 'Point') {
          draftPoints = [tapPosition]; // Point hanya 1 titik
        } else {
          draftPoints.add(tapPosition); // Polygon tambah terus
        }
      });
      return;
    }

    // Jika mode normal, cek apakah mengklik area poligon aset
    for (var asset in assetFeatures) {
      for (var polygon in asset.polygons) {
        if (_isPointInPolygon(tapPosition, polygon)) {
          _showAssetBottomSheet(asset.properties);
          return; 
        }
      }
    }
  }

  bool _isPointInPolygon(LatLng tap, List<LatLng> vertices) {
    int intersectCount = 0;
    for (int j = 0; j < vertices.length - 1; j++) {
      if (_rayCastIntersect(tap, vertices[j], vertices[j + 1])) intersectCount++;
    }
    return (intersectCount % 2) == 1;
  }

  bool _rayCastIntersect(LatLng tap, LatLng vertA, LatLng vertB) {
    double aY = vertA.latitude, bY = vertB.latitude;
    double aX = vertA.longitude, bX = vertB.longitude;
    double pY = tap.latitude, pX = tap.longitude;

    if ((aY > pY && bY > pY) || (aY < pY && bY < pY) || (aX < pX && bX < pX)) return false;
    double m = (aY - bY) / (aX - bX);
    double bee = (-aX) * m + aY;
    double x = (pY - bee) / m;
    return x > pX;
  }

  // --- 6. FUNGSI PENYIMPANAN DIGITALISASI ASET ---
  void _saveDrawnFeature() {
    if (draftPoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gambar aset terlebih dahulu!')));
      return;
    }
    if (drawingType == 'Polygon' && draftPoints.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Poligon butuh minimal 3 titik!')));
      return;
    }

    int? selectedLayer;
    TextEditingController ketController = TextEditingController(text: 'belum ada');

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Simpan Data $drawingType'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    value: selectedLayer,
                    hint: const Text('Pilih Layer Peta'),
                    items: availableLayers.map<DropdownMenuItem<int>>((layer) {
                      return DropdownMenuItem<int>(
                        value: layer['id'],
                        child: Text(layer['nama_layer']),
                      );
                    }).toList(),
                    onChanged: (val) => setDialogState(() => selectedLayer = val),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: ketController,
                    decoration: const InputDecoration(
                      labelText: 'Keterangan',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedLayer == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih Layer!')));
                      return;
                    }
                    Navigator.pop(context);
                    await _postFeatureToApi(selectedLayer!, ketController.text);
                  },
                  child: const Text('Simpan'),
                )
              ],
            );
          }
        );
      }
    );
  }

  Future<void> _postFeatureToApi(int layerId, String keterangan) async {
    setState(() => isLoading = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      
      List<Map<String, double>> coords = draftPoints.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList();

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/map/store-feature'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'layer_id': layerId,
          'type': drawingType,
          'coordinates': coords,
          'keterangan': keterangan,
        })
      );

      if (response.statusCode == 200) {
        // SUDAH DIPERBAIKI DI SINI
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aset Berhasil Disimpan!'), backgroundColor: Colors.green)
        );
        setState(() {
          draftPoints.clear();
          isDrawingMode = false;
        });
        _fetchSpatialData(); // Muat ulang peta agar aset baru muncul
      } else {
        // SUDAH DIPERBAIKI DI SINI
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyimpan aset'), backgroundColor: Colors.red)
        );
      }
    } catch (e) {
      debugPrint("Save error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  // --- 7. MENAMPILKAN INFO ASET (BOTTOM SHEET) ---
  void _showAssetBottomSheet(Map<String, dynamic> props) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.indigo),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          props['name'] ?? 'Informasi Aset', 
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const Divider(thickness: 1, height: 30),
                  _buildInfoRow('Jenis Hak', props['kategori_hak'] ?? '-'),
                  _buildInfoRow('Keterangan', props['keterangan'] ?? '-'),
                  _buildInfoRow('Status', props['status'] ?? '-'),
                  _buildInfoRow('Layer ID', props['layer_id'].toString()),
                  const SizedBox(height: 10),
                  const Text('Data Mentah (Atribut):', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: (props['raw_data'] as Map<String, dynamic>? ?? props).entries.map((e) {
                        if (['kategori_hak', 'keterangan', 'status', 'layer_color', 'raw_data', 'geojson', 'sumber'].contains(e.key)) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 2, child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w500))),
                              const Text(": "),
                              Expanded(flex: 3, child: Text(e.value.toString())),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
          const Text(": "),
          Expanded(flex: 3, child: Text(value)),
        ],
      ),
    );
  }

  // --- 8. PENGATURAN FILTER LAYER ---
  void _showLayerSettings() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Pengaturan Layer Peta", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(),
                  Expanded(
                    child: availableLayers.isEmpty
                        ? const Center(child: Text("Tidak ada layer tersedia"))
                        : ListView.builder(
                            itemCount: availableLayers.length,
                            itemBuilder: (context, index) {
                              final layer = availableLayers[index];
                              final layerId = layer['id'] as int;
                              return CheckboxListTile(
                                title: Text(layer['nama_layer']),
                                subtitle: Text(layer['tipe_layer'] ?? ''),
                                value: activeLayerIds.contains(layerId),
                                activeColor: Colors.indigo,
                                onChanged: (bool? value) {
                                  setModalState(() {
                                    if (value == true) {
                                      activeLayerIds.add(layerId);
                                    } else {
                                      activeLayerIds.remove(layerId);
                                    }
                                  });
                                  setState(() {});
                                  _fetchSpatialData();
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Polygon> mapPolygons = assetFeatures.expand((asset) {
      return asset.polygons.map((coords) => Polygon(
        points: coords,
        color: asset.color.withOpacity(0.5),
        borderColor: asset.color,
        borderStrokeWidth: 2,
      ));
    }).toList();

    return Scaffold(
      body: Stack(
        children: [
          // 1. Peta Utama
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(-7.8228, 112.0118),
              initialZoom: currentZoom,
              minZoom: 5.0,
              maxZoom: 20.0,
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture) {
                  currentZoom = pos.zoom ?? currentZoom;
                  if (!isDrawingMode) _fetchSpatialData(); // Jangan load ulang data saat menggambar
                }
              },
              onTap: (tapPosition, point) => _handleMapTap(point),
            ),
            children: [
              TileLayer(
                urlTemplate: isSatelliteMode
                    ? 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}'
                    : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.sistem_berkas_mobile',
              ),
              PolygonLayer(polygons: mapPolygons),
              
              // LAYER KHUSUS GAMBARAN SEMENTARA (DRAFT)
              if (isDrawingMode && drawingType == 'Polygon')
                PolylineLayer(polylines: [Polyline(points: draftPoints, color: Colors.red, strokeWidth: 3.0)]),
              if (isDrawingMode && drawingType == 'Polygon' && draftPoints.length > 2)
                PolygonLayer(polygons: [Polygon(points: draftPoints, color: Colors.red.withOpacity(0.3), borderColor: Colors.red, borderStrokeWidth: 2.0)]),
              if (isDrawingMode && drawingType == 'Point' && draftPoints.isNotEmpty)
                MarkerLayer(markers: [Marker(point: draftPoints.first, width: 40, height: 40, child: const Icon(Icons.location_on, color: Colors.red, size: 40))]),
            ],
          ),

          // 2. Kotak Pencarian / Header Digitalisasi
          Positioned(
            top: 50, left: 16, right: 16,
            child: isDrawingMode 
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Mode Digitalisasi", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      TextButton(
                        onPressed: () => setState(() { isDrawingMode = false; draftPoints.clear(); }), 
                        child: const Text("Batal", style: TextStyle(color: Colors.white))
                      )
                    ],
                  ),
                )
              : Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)]),
                  child: TextField(
                    controller: _searchController, textInputAction: TextInputAction.search, onSubmitted: _searchAsset,
                    decoration: InputDecoration(
                      hintText: "Cari NIB, Hak, atau Nama...",
                      prefixIcon: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
                      suffixIcon: IconButton(icon: const Icon(Icons.search, color: Colors.indigo), onPressed: () => _searchAsset(_searchController.text)),
                      border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    ),
                  ),
                ),
          ),

          // 3. Tombol-tombol Kontrol Kanan
          Positioned(
            right: 16, bottom: 40,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Tombol Draw / Digitalisasi
                FloatingActionButton(
                  heroTag: "drawBtn", mini: true, 
                  backgroundColor: isDrawingMode ? Colors.red : Colors.white, 
                  onPressed: () => setState(() { isDrawingMode = !isDrawingMode; draftPoints.clear(); }), 
                  child: Icon(Icons.draw, color: isDrawingMode ? Colors.white : Colors.indigo)
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: "satelliteBtn", mini: true, backgroundColor: Colors.white,
                  onPressed: () => setState(() => isSatelliteMode = !isSatelliteMode),
                  child: Icon(isSatelliteMode ? Icons.map : Icons.satellite_alt, color: isSatelliteMode ? Colors.green : Colors.indigo),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(heroTag: "layerBtn", mini: true, backgroundColor: Colors.white, onPressed: _showLayerSettings, child: const Icon(Icons.layers, color: Colors.indigo)),
                const SizedBox(height: 10),
                FloatingActionButton(heroTag: "gpsBtn", mini: true, backgroundColor: Colors.white, onPressed: _goToMyLocation, child: const Icon(Icons.my_location, color: Colors.blue)),
                const SizedBox(height: 20),
                FloatingActionButton(heroTag: "zoomInBtn", mini: true, backgroundColor: Colors.white, onPressed: () { currentZoom++; _mapController.move(_mapController.camera.center, currentZoom); }, child: const Icon(Icons.add, color: Colors.black87)),
                const SizedBox(height: 5),
                FloatingActionButton(heroTag: "zoomOutBtn", mini: true, backgroundColor: Colors.white, onPressed: () { currentZoom--; _mapController.move(_mapController.camera.center, currentZoom); }, child: const Icon(Icons.remove, color: Colors.black87)),
              ],
            ),
          ),

          // 4. Panel Bawah (Peralatan Menggambar)
          if (isDrawingMode)
            Positioned(
              bottom: 40, left: 16, right: 80, // Hindari tombol sebelah kanan
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)]),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ChoiceChip(label: 'Point', isSelected: drawingType == 'Point', onSelected: () => setState(() { drawingType = 'Point'; draftPoints.clear(); })),
                        ChoiceChip(label: 'Polygon', isSelected: drawingType == 'Polygon', onSelected: () => setState(() { drawingType = 'Polygon'; draftPoints.clear(); })),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(onPressed: () => setState(() => draftPoints.clear()), icon: const Icon(Icons.delete_sweep, color: Colors.red), label: const Text('Hapus', style: TextStyle(color: Colors.red))),
                        ElevatedButton.icon(onPressed: _saveDrawnFeature, icon: const Icon(Icons.save), label: const Text('Simpan Aset')),
                      ],
                    )
                  ],
                ),
              ),
            ),

          if (isLoading)
            const Positioned(
              top: 110, right: 20,
              child: CircleAvatar(backgroundColor: Colors.white, radius: 15, child: SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))),
            ),
        ],
      ),
    );
  }
}

// Widget Helper untuk Tombol Pemilihan (Point/Polygon)
class ChoiceChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const ChoiceChip({super.key, required this.label, required this.isSelected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: isSelected ? Colors.indigo : Colors.grey.shade200, borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
      ),
    );
  }
}