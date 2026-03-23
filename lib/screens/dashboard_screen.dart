import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

// Import halaman-halaman menu
import 'login_screen.dart';
import 'berkas_screen.dart';
import 'webgis_screen.dart';
import 'ruang_kerja_screen.dart';
import 'laporan_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // PENTING: Ganti IP ini dengan IP server Laravel Anda (10.0.2.2 untuk emulator)
  static const String _baseUrl = 'http://10.0.2.2:8000'; 

  String _userName = '';
  String? _fotoProfilFullUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? 'Petugas BPN';
      
      // Logika perbaikan URL Foto Profil
      String? rawFoto = prefs.getString('foto_profil'); 
      if (rawFoto != null && rawFoto.isNotEmpty) {
        if (rawFoto.startsWith('http')) {
          _fotoProfilFullUrl = rawFoto;
        } else {
          _fotoProfilFullUrl = '$_baseUrl/storage/$rawFoto';
        }
      } else {
        _fotoProfilFullUrl = null;
      }
    });
  }

  Future<void> logout() async {
    // Tampilkan konfirmasi dialog sebelum logout
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Logout', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Apakah Anda yakin ingin keluar dari aplikasi?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Keluar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      if (token != null) {
        try {
          await http.post(
            Uri.parse('$_baseUrl/api/logout'),
            headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
          );
        } catch (e) {
          debugPrint("Logout API error: $e");
        }
      }
      
      await prefs.clear();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'selesai': return Colors.green.shade600;
      case 'diproses': return Colors.teal;
      case 'ditolak': return Colors.redAccent;
      default: return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Definisi Warna Tema
    const Color themePrimary = Color(0xFF0D47A1); // Deep Blue
    const Color themeTeal = Color(0xFF00897B); // Teal

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: themePrimary,
        title: const Text('Sistem Berkas Mobile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.white),
              onPressed: logout,
              tooltip: 'Logout'),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ==========================================
            // HEADER SECTION (Melengkung & Foto Profil)
            // ==========================================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: themePrimary,
                borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30)),
                boxShadow: [
                  BoxShadow(color: themePrimary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Selamat Datang,', style: TextStyle(color: Colors.blue.shade100, fontSize: 14)),
                        const SizedBox(height: 6),
                        Text(
                          _userName,
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // FOTO PROFIL SECTION
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white24),
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.white,
                      backgroundImage: (_fotoProfilFullUrl != null) ? NetworkImage(_fotoProfilFullUrl!) : null,
                      child: (_fotoProfilFullUrl == null)
                          ? Icon(Icons.person, size: 40, color: Colors.blue.shade900)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ==========================================
            // STATISTIK SECTION (Grid View)
            // ==========================================
            _buildSectionTitle('Ringkasan Statistik Berkas'),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.6,
                children: [
                  // Placeholder nilai statistik, nantinya bisa di-fetch dari API
                  _buildStatCard('Total Berkas', '124', Icons.folder_copy, themeTeal),
                  _buildStatCard('Selesai', '86', Icons.check_circle_outline, _getStatusColor('selesai')),
                  _buildStatCard('Diproses', '32', Icons.history, _getStatusColor('diproses')),
                  _buildStatCard('Tertunda', '6', Icons.warning_amber_rounded, _getStatusColor('ditolak')),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ==========================================
            // MENU UTAMA (List Memanjang)
            // ==========================================
            _buildSectionTitle('Menu Utama'),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _buildMenuButton(
                    title: 'Daftar Berkas',
                    subtitle: 'Kelola & tracking dokumen',
                    icon: Icons.folder_copy_rounded,
                    color: Colors.orange,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BerkasScreen())),
                  ),
                  const SizedBox(height: 12),
                  _buildMenuButton(
                    title: 'Ruang Kerja',
                    subtitle: 'Tugas yang sedang dikerjakan',
                    icon: Icons.work_history_rounded,
                    color: Colors.purple,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RuangKerjaScreen())),
                  ),
                  const SizedBox(height: 12),
                  _buildMenuButton(
                    title: 'Peta WebGIS',
                    subtitle: 'Visualisasi bidang tanah',
                    icon: Icons.map_rounded,
                    color: Colors.green,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const WebgisScreen())),
                  ),
                  const SizedBox(height: 12),
                  _buildMenuButton(
                    title: 'Laporan Rincian',
                    subtitle: 'Statistik & performa',
                    icon: Icons.analytics_rounded,
                    color: Colors.redAccent,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LaporanScreen())),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            
            // Footer Copyright
            const Icon(Icons.fingerprint_rounded, size: 30, color: Colors.blueGrey),
            const SizedBox(height: 8),
            Text('Copyright © Sistem Berkas Mobile 2026', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---
  
  Widget _buildSectionTitle(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton({required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: color.withOpacity(0.1),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}