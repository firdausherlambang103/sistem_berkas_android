import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Fungsi untuk mengecek token di memori HP
  Future<String?> _getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sistem Berkas',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue.shade900),
        useMaterial3: true,
      ),
      // Cek status login saat aplikasi pertama kali dibuka
      home: FutureBuilder<String?>(
        future: _getToken(),
        builder: (context, snapshot) {
          // Jika proses pengecekan masih berjalan, tampilkan loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          // Jika token ada (sudah login), ke Dashboard
          if (snapshot.hasData && snapshot.data != null) {
            return const DashboardScreen();
          }
          // Jika tidak ada token, ke Halaman Login
          return const LoginScreen();
        },
      ),
    );
  }
}