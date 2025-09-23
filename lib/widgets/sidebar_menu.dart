// lib/widgets/sidebar_menu.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../enums.dart';

class SidebarMenu extends StatefulWidget {
  final MenuItem selectedMenu;
  final Function(MenuItem) onMenuItemSelected;

  const SidebarMenu({
    Key? key,
    required this.selectedMenu,
    required this.onMenuItemSelected,
  }) : super(key: key);

  @override
  State<SidebarMenu> createState() => _SidebarMenuState();
}

class _SidebarMenuState extends State<SidebarMenu> {
  bool _isCollapsed = false;

  static const _logoUrl =
      'https://aogosto.com.br/delivery/wp-content/uploads/2025/03/go-laranja-maior-1.png';

  @override
  Widget build(BuildContext context) {
    final double sidebarWidth = _isCollapsed ? 76 : 260;
    final primary = const Color(0xFFF28C38);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: sidebarWidth,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.orange.shade50.withOpacity(0.55)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(right: BorderSide(color: Colors.black.withOpacity(0.06))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
        // ===== BRAND HEADER (LOGO) =====
Padding(
  padding: EdgeInsets.symmetric(
    horizontal: _isCollapsed ? 0 : 8,
    vertical: 14,
  ),
  child: Column(
    children: [
      SizedBox(
        height: _isCollapsed ? 44 : 86,
        child: Image.network(
          _logoUrl,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Text(
            'GO',
            style: GoogleFonts.poppins(
              color: const Color(0xFFF28C38),
              fontSize: _isCollapsed ? 18 : 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      // divisor sutil e moderno
      Container(
        height: 1,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.08),
              Colors.transparent,
            ],
          ),
        ),
      ),
    ],
  ),
),

          const SizedBox(height: 14),
          _item(icon: Icons.dashboard_rounded, label: 'Dashboard', menuItem: MenuItem.dashboard),
          _item(icon: Icons.list_alt_rounded, label: 'Pedidos', menuItem: MenuItem.pedidos),
          _item(icon: Icons.motorcycle_rounded, label: 'Motoboys', menuItem: MenuItem.motoboys),
          _item(icon: Icons.update_rounded, label: 'Atualizações', menuItem: MenuItem.atualizacoes),
          const Spacer(),
          const SizedBox(height: 8),
          _collapseButton(primary),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _item({
    required IconData icon,
    required String label,
    required MenuItem menuItem,
  }) {
    final bool isSelected = widget.selectedMenu == menuItem;
    final primary = const Color(0xFFF28C38);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => widget.onMenuItemSelected(menuItem),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? primary.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? primary.withOpacity(0.35) : Colors.black12.withOpacity(0.06),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected ? primary : primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: isSelected ? Colors.white : primary),
              ),
              if (!_isCollapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _collapseButton(Color primary) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Tooltip(
          message: _isCollapsed ? 'Expandir' : 'Recolher',
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => setState(() => _isCollapsed = !_isCollapsed),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: primary.withOpacity(0.35)),
              ),
              child: Icon(
                _isCollapsed ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
                size: 22,
                color: primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
