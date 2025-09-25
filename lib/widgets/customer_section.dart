import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class CustomerSection extends StatelessWidget {
  final TextEditingController phoneController;
  final ValueChanged<String?> onPhoneChanged;
  final VoidCallback onFetchCustomer;
  final TextEditingController nameController;
  final ValueChanged<String?> onNameChanged;
  final TextEditingController emailController;
  final ValueChanged<String?> onEmailChanged;
  final FormFieldValidator<String>? validator;
  final bool isLoading;

  const CustomerSection({
    Key? key,
    required this.phoneController,
    required this.onPhoneChanged,
    required this.onFetchCustomer,
    required this.nameController,
    required this.onNameChanged,
    required this.emailController,
    required this.onEmailChanged,
    required this.validator,
    required this.isLoading,
  }) : super(key: key);

  Future<void> logToFile(String message) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/sistema-erp-barreiro/app_logs.txt');
      await file.writeAsString('[${DateTime.now()}] $message\n', mode: FileMode.append);
    } catch (e) {
      debugPrint('Falha ao escrever log: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFFF28C38);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Text(
            'Dados do Cliente',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        TextFormField(
          controller: phoneController,
          decoration: InputDecoration(
            labelText: 'Telefone',
            labelStyle: GoogleFonts.poppins(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryColor.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryColor.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryColor, width: 2),
            ),
            prefixIcon: Icon(Icons.phone, color: primaryColor),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            suffixIcon: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    icon: Icon(Icons.search, color: primaryColor),
                    onPressed: onFetchCustomer,
                  ),
          ),
          keyboardType: TextInputType.phone,
          inputFormatters: [
            MaskTextInputFormatter(
              mask: '(##) #####-####',
              filter: {'#': RegExp(r'[0-9]')},
            ),
          ],
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
          onChanged: onPhoneChanged,
          validator: validator,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: 'Nome',
            labelStyle: GoogleFonts.poppins(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryColor.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryColor.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryColor, width: 2),
            ),
            prefixIcon: Icon(Icons.person, color: primaryColor),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
          onChanged: onNameChanged,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Por favor, insira o nome do cliente';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: emailController,
          decoration: InputDecoration(
            labelText: 'E-mail',
            labelStyle: GoogleFonts.poppins(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryColor.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryColor.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryColor, width: 2),
            ),
            prefixIcon: Icon(Icons.email, color: primaryColor),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          keyboardType: TextInputType.emailAddress,
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
          onChanged: onEmailChanged,
          validator: validator,
        ),
      ],
    );
  }
}