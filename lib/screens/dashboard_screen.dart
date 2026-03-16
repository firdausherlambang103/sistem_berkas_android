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
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() => _userName = prefs.getString('user_name') ?? 'Petugas');
  }

  Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    if (token != null) {
      await http.post(
        Uri.parse('http://10.0.2.2:8000/api/logout'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
    }
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue.shade900,
        title: const Text('Beranda', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.logout, color: Colors.white), onPressed: logout, tooltip: 'Logout'),
        ],
      ),
      body: Column(
        children: [
          // Header Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blue.shade900,
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
              boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Selamat Datang,', style: TextStyle(color: Colors.blue.shade100, fontSize: 16)),
                const SizedBox(height: 8),
                Text(_userName, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Menu Grid Section
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildMenuCard(
                  title: 'Daftar Berkas',
                  icon: Icons.folder_copy_rounded,
                  color: Colors.orange,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BerkasScreen())),
                ),
                _buildMenuCard(
                  title: 'Ruang Kerja',
                  icon: Icons.work_history_rounded,
                  color: Colors.purple,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RuangKerjaScreen())),
                ),
                _buildMenuCard(
                  title: 'Peta WebGIS',
                  icon: Icons.map_rounded,
                  color: Colors.green,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const WebgisScreen())),
                ),
                _buildMenuCard(
                  title: 'Laporan Rincian',
                  icon: Icons.analytics_rounded,
                  color: Colors.redAccent,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LaporanScreen())),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard({required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 36, color: color),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
          ],
        ),
      ),
    );
  }
}