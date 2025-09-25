// lib/pages/criar_link_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CriarLinkPage extends StatelessWidget {
  const CriarLinkPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Criar Link Cartão/Pix',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.orange,
      ),
      body: Center(
        child: Text(
          'Página para criar link de pagamento (Em construção)',
          style: GoogleFonts.poppins(fontSize: 16),
        ),
      ),
    );
  }
}