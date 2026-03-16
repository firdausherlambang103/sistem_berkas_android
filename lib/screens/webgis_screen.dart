import 'package:flutter/material.dart';

class WebgisScreen extends StatelessWidget {
  const WebgisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Peta WebGIS', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.satellite_alt_rounded, size: 100, color: Colors.green.shade200),
            const SizedBox(height: 20),
            const Text('Integrasi Peta WebGIS', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 30),
              child: Text(
                'Karena Laravel Anda memakai Leaflet (Web), di Flutter kita punya 2 opsi:\n1. Menggunakan package "webview_flutter" untuk membuka URL Laravel langsung.\n2. Menggunakan package "flutter_map" untuk menggambar ulang SHP/GeoJSON secara Native.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}