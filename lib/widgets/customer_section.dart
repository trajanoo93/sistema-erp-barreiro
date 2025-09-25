import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:flutter/foundation.dart';

class CustomerSection extends StatefulWidget {
  final TextEditingController phoneController;
  final Function(String) onPhoneChanged;
  final VoidCallback onFetchCustomer;
  final TextEditingController nameController;
  final Function(String) onNameChanged;
  final TextEditingController emailController;
  final Function(String) onEmailChanged;
  final String selectedVendedor;
  final Function(String?) onVendedorChanged;
  final String? Function(String?)? validator;
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
    required this.selectedVendedor,
    required this.onVendedorChanged,
    this.validator,
    required this.isLoading,
  }) : super(key: key);

  @override
  _CustomerSectionState createState() => _CustomerSectionState();
}

void logToFile(String message) {
  debugPrint(message);
  // aqui você pode implementar escrita em arquivo se quiser
}


class _CustomerSectionState extends State<CustomerSection> {
  final primaryColor = const Color(0xFFF28C38);
  final phoneMaskFormatter = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {'#': RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  @override
  void initState() {
    super.initState();
    widget.phoneController.addListener(() {
      // Removido setState para evitar reconstruções desnecessárias
      logToFile('phoneController changed: ${widget.phoneController.text}');
    });
  }

  @override
  void dispose() {
    widget.phoneController.removeListener(() {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cleanedPhone = widget.phoneController.text.replaceAll(RegExp(r'\D'), '').trim();
    final isPhoneValid = cleanedPhone.length == 11;

    // Mover o log para logToFile em vez de debugPrint
    logToFile('Phone: ${widget.phoneController.text}, Cleaned: $cleanedPhone, isPhoneValid: $isPhoneValid');

    final List<String> vendedores = ['Alline', 'Cássio Vinicius', 'Maria Eduarda'];
    final String dropdownValue = vendedores.contains(widget.selectedVendedor)
        ? widget.selectedVendedor
        : vendedores.first;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dados do Cliente',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: widget.phoneController,
                  decoration: InputDecoration(
                    labelText: 'Telefone do Cliente (DDD + Número)',
                    labelStyle: GoogleFonts.poppins(
                      color: isDarkMode ? Colors.white70 : Colors.black54,
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
                      borderSide: BorderSide(
                        color: primaryColor,
                        width: 2,
                      ),
                    ),
                    prefixIcon: Icon(
                      Icons.phone,
                      color: primaryColor,
                    ),
                    filled: true,
                    fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [phoneMaskFormatter],
                  onChanged: widget.onPhoneChanged,
                  validator: widget.validator,
                ),
              ),
              const SizedBox(width: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: ElevatedButton(
                  onPressed: (widget.isLoading || !isPhoneValid) ? null : () {
                    logToFile('Botão Buscar Cliente clicado');
                    widget.onFetchCustomer();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    shadowColor: Colors.black.withOpacity(0.2),
                    disabledBackgroundColor: primaryColor.withOpacity(0.5),
                  ),
                  child: widget.isLoading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Buscar Cliente',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: dropdownValue,
            decoration: InputDecoration(
              labelText: 'Vendedor',
              labelStyle: GoogleFonts.poppins(
                color: isDarkMode ? Colors.white70 : Colors.black54,
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
                borderSide: BorderSide(
                  color: primaryColor,
                  width: 2,
                ),
              ),
              prefixIcon: Icon(
                Icons.person_pin,
                color: primaryColor,
              ),
              filled: true,
              fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            items: vendedores.map((vendedor) {
              return DropdownMenuItem<String>(
                value: vendedor,
                child: Text(vendedor),
              );
            }).toList(),
            onChanged: widget.onVendedorChanged,
            validator: null,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: widget.nameController,
            decoration: InputDecoration(
              labelText: 'Nome do Cliente',
              labelStyle: GoogleFonts.poppins(
                color: isDarkMode ? Colors.white70 : Colors.black54,
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
                borderSide: BorderSide(
                  color: primaryColor,
                  width: 2,
                ),
              ),
              prefixIcon: Icon(
                Icons.person,
                color: primaryColor,
              ),
              filled: true,
              fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            onChanged: widget.onNameChanged,
            validator: null,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: widget.emailController,
            decoration: InputDecoration(
              labelText: 'E-mail do Cliente (opcional)',
              labelStyle: GoogleFonts.poppins(
                color: isDarkMode ? Colors.white70 : Colors.black54,
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
                borderSide: BorderSide(
                  color: primaryColor,
                  width: 2,
                ),
              ),
              prefixIcon: Icon(
                Icons.email,
                color: primaryColor,
              ),
              filled: true,
              fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            keyboardType: TextInputType.emailAddress,
            onChanged: widget.onEmailChanged,
            validator: null,
          ),
        ],
      ),
    );
  }
}