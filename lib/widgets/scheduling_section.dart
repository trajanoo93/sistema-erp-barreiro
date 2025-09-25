import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class SchedulingSection extends StatefulWidget {
  final String shippingMethod;
  final String storeFinal;
  final Function(String, String) onDateTimeUpdated;
  final Function() onSchedulingChanged;
  final DateTime? initialDate;
  final String? initialTimeSlot;

  const SchedulingSection({
    Key? key,
    required this.shippingMethod,
    required this.storeFinal,
    required this.onDateTimeUpdated,
    required this.onSchedulingChanged,
    this.initialDate,
    this.initialTimeSlot,
  }) : super(key: key);

  @override
  State<SchedulingSection> createState() => _SchedulingSectionState();
}

class _SchedulingSectionState extends State<SchedulingSection> {
  DateTime? _selectedDate;
  String? _selectedTimeSlot;
  List<String> _availableTimeSlots = [];
  final primaryColor = const Color(0xFFF28C38);

  Future<void> logToFile(String message) async {
    // desativado
  }

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    _updateTimeSlots();
    _selectedTimeSlot = widget.initialTimeSlot != null && _availableTimeSlots.contains(widget.initialTimeSlot)
        ? widget.initialTimeSlot
        : _availableTimeSlots.isNotEmpty
            ? _availableTimeSlots.first
            : null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateParent();
      }
    });
  }

  @override
  void didUpdateWidget(SchedulingSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shippingMethod != oldWidget.shippingMethod ||
        widget.storeFinal != oldWidget.storeFinal ||
        widget.initialDate != oldWidget.initialDate ||
        widget.initialTimeSlot != oldWidget.initialTimeSlot) {
      setState(() {
        _selectedDate = widget.initialDate ?? DateTime.now();
        _updateTimeSlots();
        _selectedTimeSlot = widget.initialTimeSlot != null && _availableTimeSlots.contains(widget.initialTimeSlot)
            ? widget.initialTimeSlot
            : _availableTimeSlots.isNotEmpty
                ? _availableTimeSlots.first
                : null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _updateParent();
        }
      });
    }
  }

  void _updateTimeSlots() {
    final now = DateTime.now();
    final isToday = _selectedDate != null &&
        _selectedDate!.year == now.year &&
        _selectedDate!.month == now.month &&
        _selectedDate!.day == now.day;
    final isSunday = _selectedDate?.weekday == DateTime.sunday;
    final currentHour = now.hour + (now.minute / 60.0);

    setState(() {
      if (isSunday) {
        if (widget.shippingMethod == 'pickup') {
          _availableTimeSlots = ['09:00 - 12:00'];
        } else {
          _availableTimeSlots = ['09:00 - 12:00', '12:00 - 15:00'];
        }
      } else {
        if (widget.shippingMethod == 'pickup') {
          _availableTimeSlots = ['09:00 - 12:00', '12:00 - 15:00', '15:00 - 18:00'];
        } else {
          _availableTimeSlots = ['09:00 - 12:00', '12:00 - 15:00', '15:00 - 18:00', '18:00 - 21:00'];
        }
      }
      if (isToday) {
        _availableTimeSlots = _availableTimeSlots.where((slot) {
          final parts = slot.split('-').map((s) => s.trim()).toList();
          final startHour = double.parse(parts[0].split(':')[0]) + (double.parse(parts[0].split(':')[1]) / 60.0);
          final endHour = double.parse(parts[1].split(':')[0]) + (double.parse(parts[1].split(':')[1]) / 60.0);
          return currentHour <= endHour;
        }).toList();
      }
      if (_availableTimeSlots.isEmpty && isToday) {
        _availableTimeSlots = ['18:00 - 21:00'];
      }
      if (_selectedTimeSlot == null || !_availableTimeSlots.contains(_selectedTimeSlot)) {
        _selectedTimeSlot = _availableTimeSlots.isNotEmpty ? _availableTimeSlots.first : null;
      }
    });
    logToFile('Available time slots: $_availableTimeSlots, isToday: $isToday, currentHour: $currentHour, isSunday: $isSunday');
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      locale: const Locale('pt', 'BR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              secondary: primaryColor.withOpacity(0.3),
              onSecondary: Colors.black87,
              surface: Colors.white,
              onSurface: Colors.black87,
              background: Colors.white,
              onBackground: Colors.black87,
              error: Colors.redAccent,
              onError: Colors.white,
            ),
            dialogBackgroundColor: Colors.white,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: primaryColor,
                textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              child!,
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Cancelar', style: GoogleFonts.poppins(color: Colors.redAccent)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(_selectedDate),
                      child: Text('Confirmar', style: GoogleFonts.poppins(color: primaryColor)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );

    if (picked != null && picked != _selectedDate && mounted) {
      setState(() {
        _selectedDate = picked;
        _updateTimeSlots();
      });
      _updateParent();
      await logToFile('Data selecionada: ${DateFormat('dd/MM/yyyy').format(picked)}');
    }
  }

  void _updateParent() {
    if (mounted && _selectedDate != null && _selectedTimeSlot != null) {
      String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      widget.onDateTimeUpdated(formattedDate, _selectedTimeSlot!);
      widget.onSchedulingChanged();
      logToFile('Parent atualizado: date=$formattedDate, time=$_selectedTimeSlot');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _selectDate(context),
                child: AbsorbPointer(
                  child: TextFormField(
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: widget.shippingMethod == 'delivery' ? 'Data de Entrega' : 'Data de Retirada',
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
                      prefixIcon: Icon(Icons.calendar_today, color: primaryColor),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    controller: TextEditingController(
                      text: _selectedDate != null
                          ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
                          : 'Selecione a data',
                    ),
                    validator: (value) => value == null || value.isEmpty ? 'Selecione a data' : null,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          value: _selectedTimeSlot,
          decoration: InputDecoration(
            labelText: widget.shippingMethod == 'delivery' ? 'Horário de Entrega' : 'Horário de Retirada',
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
            prefixIcon: Icon(Icons.access_time, color: primaryColor),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
          items: _availableTimeSlots.map((slot) {
            return DropdownMenuItem<String>(
              value: slot,
              child: Text(slot, style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87)),
            );
          }).toList(),
          onChanged: (value) {
            if (mounted && value != null) {
              setState(() => _selectedTimeSlot = value);
              _updateParent();
              logToFile('Horário selecionado: $value');
            }
          },
          validator: (value) => value == null ? 'Selecione um horário' : null,
        ),
      ],
    );
  }
}