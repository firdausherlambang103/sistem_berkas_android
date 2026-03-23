import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/berkas_model.dart';

class DetailBerkasScreen extends StatefulWidget {
  final Berkas berkas;

  const DetailBerkasScreen({super.key, required this.berkas});

  @override
  State<DetailBerkasScreen> createState() => _DetailBerkasScreenState();
}

class _DetailBerkasScreenState extends State<DetailBerkasScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _detailData;

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

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _detailData = jsonDecode(response.body)['data'];
          _isLoading = false;
        });
      } else {
        throw Exception('Gagal memuat data');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
                ? const Center(child: Text("Gagal memuat detail berkas"))
                : TabBarView(
                    children: [
                      // TAB 1: Rincian Berkas
                      _buildRincianTab(),
                      
                      // TAB 2: Linimasa / Riwayat
                      _buildLinimasaTab(),
                      
                      // TAB 3: Peta GeoJSON
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
    String noBerkas = _detailData!['nomer_berkas'] ?? widget.berkas.noBerkas;
    String tahun = _detailData!['tahun']?.toString() ?? '-';
    String status = _detailData!['status'] ?? widget.berkas.status;

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
    String jenisPermohonan = _detailData!['jenis_permohonan']?['nama_permohonan'] ?? '-';
    String desa = _detailData!['desa'] ?? '-';
    String kecamatan = _detailData!['kecamatan'] ?? '-';
    
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
            _buildDataRow("Jenis Alas Hak", _detailData!['jenis_alas_hak'] ?? '-'),
            _buildDataRow("Nomer Hak", _detailData!['nomer_hak'] ?? '-'),
            _buildDataRow("Buku Tanah", _detailData!['status_buku_tanah'] ?? '-'),
          ],
        ),
      ),
    );
  }

  Widget _buildPemohonCard() {
    String namaKuasa = _detailData!['penerima_kuasa']?['nama_kuasa'] ?? '-';
    String telpKuasa = _detailData!['penerima_kuasa']?['nomer_wa'] ?? '';
    String kuasaTeks = telpKuasa.isNotEmpty ? "$namaKuasa ($telpKuasa)" : namaKuasa;

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
            _buildDataRow("Nama Pemohon", _detailData!['nama_pemohon'] ?? '-'),
            _buildDataRow("No. WhatsApp", _detailData!['nomer_wa'] ?? '-'),
            _buildDataRow("Kuasa", kuasaTeks),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPosisiCard() {
    String posisiNama = _detailData!['posisi_sekarang']?['name'] ?? '-';
    String posisiJabatan = _detailData!['posisi_sekarang']?['jabatan']?['nama_jabatan'] ?? 'Belum diterima';
    String posisiBerkas = posisiNama != '-' ? "${posisiJabatan.toUpperCase()}\n($posisiNama)" : posisiJabatan;

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
            _buildDataRow("Status", _detailData!['status'] ?? '-'),
            _buildDataRow("Posisi", posisiBerkas),
            _buildDataRow("Waktu Mulai", _formatWaktu(_detailData!['waktu_mulai_proses'])),
            _buildDataRow("Catatan", _detailData!['catatan'] ?? '-'),
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
        String waktu = _formatWaktu(item['waktu_kirim'] ?? item['created_at']);
        String catatan = item['catatan_pengiriman'] ?? '-';
        
        String dariNama = item['dari_user']?['name'] ?? 'Sistem';
        String dariJabatan = item['dari_user']?['jabatan']?['nama_jabatan'] ?? '';
        
        String keNama = item['ke_user']?['name'] ?? '-';
        String keJabatan = item['ke_user']?['jabatan']?['nama_jabatan'] ?? '';

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
  // TAB 3: PETA (DATA GEOJSON)
  // ==========================================
  Widget _buildPetaTab() {
    var geojson = _detailData!['geojson_geometry'];
    String desa = _detailData!['desa'] ?? '-';
    String kecamatan = _detailData!['kecamatan'] ?? '-';

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Data Spatial (WebGIS)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
          const SizedBox(height: 8),
          Text("Lokasi: Desa $desa, Kec. $kecamatan", style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
          const SizedBox(height: 20),
          
          if (geojson == null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map_outlined, size: 80, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text("Peta bidang tanah belum dipetakan.", style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade300, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 8),
                        Text("Data Peta Tersedia", style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(),
                    const Text("Koordinat GeoJSON:", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          jsonEncode(geojson), // Menampilkan data GeoJSON mentah
                          style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.grey.shade800),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text("*Untuk merender polygon peta ke dalam visual secara nyata (seperti Google Maps), aplikasi Flutter memerlukan instalasi package 'flutter_map' atau 'google_maps_flutter'.", style: TextStyle(fontSize: 11, color: Colors.orange.shade700, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            )
        ],
      ),
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
            child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}