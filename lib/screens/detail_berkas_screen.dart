import 'package:flutter/material.dart';
import '../models/berkas_model.dart';

class DetailBerkasScreen extends StatelessWidget {
  final Berkas berkas;

  const DetailBerkasScreen({super.key, required this.berkas});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Berkas', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue.shade900,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Nomor Berkas:", style: TextStyle(color: Colors.grey.shade600)),
            Text(berkas.noBerkas, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Text("Nama Pemohon:", style: TextStyle(color: Colors.grey.shade600)),
            Text(berkas.namaPemohon, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            Text("Status:", style: TextStyle(color: Colors.grey.shade600)),
            Chip(
              label: Text(berkas.status.toUpperCase(), style: const TextStyle(color: Colors.white)),
              backgroundColor: berkas.status.toLowerCase() == 'selesai' ? Colors.teal : Colors.amber.shade700,
            ),
            // Anda bisa menambahkan detail lain di sini nanti
          ],
        ),
      ),
    );
  }
}