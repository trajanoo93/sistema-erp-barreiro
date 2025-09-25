// lib/pages/conferir_pagamentos_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ConferirPagamentosPage extends StatelessWidget {
  const ConferirPagamentosPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Conferir Pagamentos',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.orange,
      ),
      body: Center(
        child: Text(
          'Página para conferir pagamentos (Em construção)',
          style: GoogleFonts.poppins(fontSize: 16),
        ),
      ),
    );
  }
}