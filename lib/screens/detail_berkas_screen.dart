import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/berkas_model.dart';

// --- IMPORT UNTUK LEAFLET (FLUTTER MAP) ---
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class DetailBerkasScreen extends StatefulWidget {
  final Berkas berkas;

  const DetailBerkasScreen({super.key, required this.berkas});

  @override
  State<DetailBerkasScreen> createState() => _DetailBerkasScreenState();
}

class _DetailBerkasScreenState extends State<DetailBerkasScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _detailData;

  // --- STATE UNTUK PETA LEAFLET ---
  List<Polygon> _polygons = [];
  LatLng? _initialCameraPosition;

  @override
  void initState() {
    super.initState();
    _fetchDetailBerkas();
  }

  Future<void> _fetchDetailBerkas() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    
    // Ganti dengan IP server/emulator Anda (contoh: 192.168.1.x jika HP asli)
    final url = Uri.parse('http://10.0.2.2:8000/api/berkas/${widget.berkas.id}');
    print("Memanggil API Detail: $url"); // LOG UNTUK CEK URL

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );

      print("Status Code API Detail: ${response.statusCode}"); // LOG CEK STATUS
      print("Isi Body API Detail: ${response.body}"); // LOG CEK ISI DATA

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        setState(() {
          // Jika dibungkus 'data' maka ambil, jika tidak pakai jsonResponse langsung
          final data = jsonResponse['data'] ?? jsonResponse; 
          _detailData = data;
          
          // --- PROSES DATA PETA SETELAH DATA LOAD ---
          _prosesDataGeoJson(data['geojson_geometry']);

          _isLoading = false;
        });
      } else {
        throw Exception('Gagal memuat data (Status: ${response.statusCode})');
      }
    } catch (e) {
      print("ERROR FETCH DETAIL: $e"); // LOG JIKA TERJADI ERROR
      setState(() => _isLoading = false);
      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // ==============================================================
  // FUNGSI: MENGUBAH GEOJSON MENJADI POLIGON FLUTTER_MAP (LEAFLET)
  // ==============================================================
  void _prosesDataGeoJson(dynamic geoJsonRaw) {
    if (geoJsonRaw == null) return;

    try {
      if (geoJsonRaw['type'] == 'MultiPolygon') {
        List<LatLng> polygonPoints = [];
        
        // Membaca array koordinat dari format MultiPolygon
        var coordinatesList = geoJsonRaw['coordinates'][0][0];

        for (var coord in coordinatesList) {
          // PENTING: GeoJSON = [longitude, latitude]
          // latlong2 = LatLng(latitude, longitude)
          double lng = coord[0].toDouble();
          double lat = coord[1].toDouble();
          polygonPoints.add(LatLng(lat, lng));
        }

        if (polygonPoints.isNotEmpty) {
          setState(() {
            // Tambahkan data Polygon ala Leaflet
            _polygons.add(Polygon(
              points: polygonPoints,
              // isFilled: true sudah dihapus karena otomatis terisi jika ada color
              color: Colors.green.withOpacity(0.4), // Warna fill transparan
              borderColor: Colors.green.shade800, // Warna garis batas
              borderStrokeWidth: 3,
            ));

            // Set kamera awal tepat di titik pertama bidang
            _initialCameraPosition = polygonPoints.first;
          });
        }
      }
    } catch (e) {
      print("Error parsing GeoJSON ke Polygon: $e");
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'selesai': return Colors.teal;
      case 'diproses': return Colors.amber.shade700;
      case 'ditolak': return Colors.redAccent;
      case 'menunggu': return Colors.blue.shade600;
      case 'pending': return Colors.orange;
      default: return Colors.blueGrey;
    }
  }

  String _formatWaktu(String? datetime) {
    if (datetime == null || datetime.isEmpty) return '-';
    try {
      DateTime dt = DateTime.parse(datetime).toLocal();
      const monthNames = ["Jan", "Feb", "Mar", "Apr", "Mei", "Jun", "Jul", "Agt", "Sep", "Okt", "Nov", "Des"];
      return "${dt.day.toString().padLeft(2, '0')} ${monthNames[dt.month - 1]} ${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return datetime;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Kita gunakan DefaultTabController dengan 3 Tab
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          title: const Text('Rincian Berkas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.blue.shade900,
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 4,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: [
              Tab(icon: Icon(Icons.info_outline), text: "Rincian"),
              Tab(icon: Icon(Icons.history), text: "Linimasa"),
              Tab(icon: Icon(Icons.map_outlined), text: "Peta"),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _detailData == null
                ? const Center(child: Text("Gagal memuat detail berkas. Silakan periksa koneksi atau hubungi admin."))
                : TabBarView(
                    children: [
                      // TAB 1: Rincian Berkas
                      _buildRincianTab(),
                      
                      // TAB 2: Linimasa / Riwayat
                      _buildLinimasaTab(),
                      
                      // TAB 3: Peta GeoJSON (LEAFLET / FLUTTER MAP)
                      _buildPetaTab(),
                    ],
                  ),
      ),
    );
  }

  // ==========================================
  // TAB 1: RINCIAN BERKAS (INFO, PEMOHON, POSISI)
  // ==========================================
  Widget _buildRincianTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(),
          const SizedBox(height: 16),
          _buildInfoBerkasCard(),
          const SizedBox(height: 16),
          _buildPemohonCard(),
          const SizedBox(height: 16),
          _buildStatusPosisiCard(),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    String noBerkas = _detailData!['nomer_berkas']?.toString() ?? widget.berkas.noBerkas;
    String tahun = _detailData!['tahun']?.toString() ?? '-';
    String status = _detailData!['status']?.toString() ?? widget.berkas.status;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100, width: 1),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("NOMOR BERKAS", style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(status.toUpperCase(), style: TextStyle(color: _getStatusColor(status), fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text("$noBerkas / $tahun", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
        ],
      ),
    );
  }

  Widget _buildInfoBerkasCard() {
    String jenisPermohonan = _detailData!['jenis_permohonan']?['nama_permohonan']?.toString() ?? '-';
    String desa = _detailData!['desa']?.toString() ?? '-';
    String kecamatan = _detailData!['kecamatan']?.toString() ?? '-';
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("Informasi Berkas", Icons.folder_copy_rounded),
            const Divider(),
            _buildDataRow("Jenis Permohonan", jenisPermohonan),
            _buildDataRow("Lokasi", "Desa $desa, Kec. $kecamatan"),
            _buildDataRow("Jenis Alas Hak", _detailData!['jenis_alas_hak']?.toString() ?? '-'),
            _buildDataRow("Nomer Hak", _detailData!['nomer_hak']?.toString() ?? '-'),
            _buildDataRow("Buku Tanah", _detailData!['status_buku_tanah']?.toString() ?? '-'),
          ],
        ),
      ),
    );
  }

  Widget _buildPemohonCard() {
    String namaKuasa = _detailData!['penerima_kuasa']?['nama_kuasa']?.toString() ?? '-';
    String telpKuasa = _detailData!['penerima_kuasa']?['nomer_wa']?.toString() ?? '';
    String kuasaTeks = telpKuasa.isNotEmpty && telpKuasa != 'null' ? "$namaKuasa ($telpKuasa)" : namaKuasa;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("Data Pemohon", Icons.person),
            const Divider(),
            _buildDataRow("Nama Pemohon", _detailData!['nama_pemohon']?.toString() ?? '-'),
            _buildDataRow("No. WhatsApp", _detailData!['nomer_wa']?.toString() ?? '-'),
            _buildDataRow("Kuasa", kuasaTeks),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPosisiCard() {
    String posisiNama = _detailData!['posisi_sekarang']?['name']?.toString() ?? '-';
    String posisiJabatan = _detailData!['posisi_sekarang']?['jabatan']?['nama_jabatan']?.toString() ?? 'Belum diterima';
    String posisiBerkas = posisiNama != '-' && posisiNama != 'null' ? "${posisiJabatan.toUpperCase()}\n($posisiNama)" : posisiJabatan;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("Status & Posisi Saat Ini", Icons.track_changes_rounded),
            const Divider(),
            _buildDataRow("Status", _detailData!['status']?.toString() ?? '-'),
            _buildDataRow("Posisi", posisiBerkas),
            _buildDataRow("Waktu Mulai", _formatWaktu(_detailData!['waktu_mulai_proses']?.toString())),
            _buildDataRow("Catatan", _detailData!['catatan']?.toString() ?? '-'),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 2: LINIMASA (RIWAYAT PERGERAKAN BERKAS)
  // ==========================================
  Widget _buildLinimasaTab() {
    List<dynamic> riwayat = _detailData!['riwayat'] ?? [];

    if (riwayat.isEmpty) {
      return Center(
        child: Text("Belum ada riwayat pergerakan berkas.", style: TextStyle(color: Colors.grey.shade600)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: riwayat.length,
      itemBuilder: (context, index) {
        final item = riwayat[index];
        String waktu = _formatWaktu(item['waktu_kirim']?.toString() ?? item['created_at']?.toString());
        String catatan = item['catatan_pengiriman']?.toString() ?? '-';
        
        String dariNama = item['dari_user']?['name']?.toString() ?? 'Sistem';
        String dariJabatan = item['dari_user']?['jabatan']?['nama_jabatan']?.toString() ?? '';
        
        String keNama = item['ke_user']?['name']?.toString() ?? '-';
        String keJabatan = item['ke_user']?['jabatan']?['nama_jabatan']?.toString() ?? '';

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Garis dan Titik Timeline
            Column(
              children: [
                Container(
                  width: 16, height: 16,
                  decoration: BoxDecoration(
                    color: index == 0 ? Colors.green : Colors.blue.shade300,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
                if (index != riwayat.length - 1)
                  Container(width: 2, height: 120, color: Colors.blue.shade100),
              ],
            ),
            const SizedBox(width: 12),
            // Isi Card Riwayat
            Expanded(
              child: Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(waktu, style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.bold)),
                      const Divider(height: 16),
                      Text("Dari: $dariJabatan ($dariNama)", style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 4),
                      Text("Ke: $keJabatan ($keNama)", style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                        child: Text("Catatan:\n$catatan", style: TextStyle(fontSize: 13, color: Colors.black87, fontStyle: FontStyle.italic)),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ==========================================
  // TAB 3: PETA (LEAFLET / FLUTTER MAP)
  // ==========================================
  Widget _buildPetaTab() {
    String desa = _detailData!['desa']?.toString() ?? '-';
    String kecamatan = _detailData!['kecamatan']?.toString() ?? '-';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Visual Spatial (Leaflet)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
              const SizedBox(height: 4),
              Text("Lokasi Bidang Tanah: Desa $desa, Kec. $kecamatan", style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
            ],
          ),
        ),
        
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 8)],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              
              // Render flutter_map
              child: _initialCameraPosition == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.location_off, size: 60, color: Colors.orange.shade300),
                          const SizedBox(height: 16),
                          Text("Data Koordinat Tidak Valid/Kosong", style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      ),
                    )
                  : FlutterMap(
                      options: MapOptions(
                        initialCenter: _initialCameraPosition!,
                        initialZoom: 18.0, // Zoom detail bidang tanah
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all,
                        ),
                      ),
                      children: [
                        // 1. TILE LAYER (BASEMAP OPENSTREETMAP)
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.sistem_berkas_mobile',
                        ),
                        
                        // 2. POLYGON LAYER (DATA GEOJSON)
                        PolygonLayer(
                          polygons: _polygons,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  // --- HELPER WIDGETS ---
  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue.shade900, size: 20),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
      ],
    );
  }

  Widget _buildDataRow(String label, String value) {
    // Jika value dari API kebetulan berisi string 'null', kita jadikan '-'
    String safeValue = (value == 'null') ? '-' : value;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          ),
          const Text(" :  ", style: TextStyle(color: Colors.grey)),
          Expanded(
            flex: 3,
            child: Text(safeValue, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}