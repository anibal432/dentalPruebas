// lib/screens/dental_tips_screen.dart
import 'package:flutter/material.dart';
import '../models/dental_tip.dart';
import '../services/dental_tips_service.dart';
import 'tip_detail_screen.dart';

// ── Paleta institucional unificada ────────────────────────────
const Color _kPrimaryDark  = Color(0xFF2A2A6E);
const Color _kPrimary      = Color(0xFF3D3D8F);
const Color _kPrimaryLight = Color(0xFF5C5CAF);
const Color _kAccent       = Color(0xFF8888C8);
const Color _kLightFill    = Color(0xFFD0D0F0);
const Color _kSurface      = Color(0xFFF0F0FA);

class DentalTipsScreen extends StatefulWidget {
  const DentalTipsScreen({super.key});

  @override
  State<DentalTipsScreen> createState() => _DentalTipsScreenState();
}

class _DentalTipsScreenState extends State<DentalTipsScreen> {
  final DentalTipsService _service = DentalTipsService();

  String? _selectedCategory;
  List<String> _categories = ['Todos'];
  bool _isLoadingCategories = true;

  // ✅ FIX RENDIMIENTO: Cache de todos los tips cargados una sola vez
  List<DentalTip> _allTips = [];
  bool _isLoadingTips = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  // ✅ FIX RENDIMIENTO: Carga todo de una vez en lugar de recargar por categoría
  Future<void> _loadInitialData() async {
    try {
      final categories = await _service.getCategories();
      if (mounted) {
        setState(() {
          _categories = ['Todos', ...categories];
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _categories = ['Todos', 'Niños', 'Adultos', 'Higiene', 'Prevención', 'Emergencias'];
          _isLoadingCategories = false;
        });
      }
    }

    // Suscribe al stream solo una vez y guarda los datos localmente
    _service.getAllTips().listen((tips) {
      if (mounted) {
        setState(() {
          _allTips = tips;
          _isLoadingTips = false;
        });
      }
    });
  }

  // ✅ FIX RENDIMIENTO: Filtrado local, sin llamadas adicionales a Firestore
  List<DentalTip> get _filteredTips {
    if (_selectedCategory == null) return _allTips;
    return _allTips.where((t) => t.category == _selectedCategory).toList();
  }

  // ── Color unificado: siempre variaciones del azul institucional ──
  Color _categoryColor(String category) => _kPrimary;

  // ── Ícono según categoría ─────────────────────────────────────
  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'niños':
        return Icons.child_care;
      case 'adultos':
        return Icons.person_outline;
      case 'higiene':
      case 'higiene básica':
        return Icons.clean_hands_outlined;
      case 'prevención':
        return Icons.health_and_safety_outlined;
      case 'emergencias':
        return Icons.medical_services_outlined;
      case 'alimentación':
        return Icons.restaurant_outlined;
      case 'problemas comunes':
        return Icons.tips_and_updates_outlined;
      default:
        return Icons.tips_and_updates_outlined;
    }
  }

  Widget _buildCategoryFilter() {
    if (_isLoadingCategories) {
      return Container(
        height: 56,
        color: Colors.white,
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(color: _kPrimary, strokeWidth: 2),
          ),
        ),
      );
    }

    return Container(
      height: 56,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category ||
              (_selectedCategory == null && category == 'Todos');

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                // ✅ FIX RENDIMIENTO: Solo cambia estado local, sin Firestore
                setState(() {
                  _selectedCategory = category == 'Todos' ? null : category;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? _kPrimary : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? _kPrimary : _kLightFill,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    color: isSelected ? Colors.white : _kPrimaryLight,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTipItem(DentalTip tip) {
    final icon = _categoryIcon(tip.category);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _kLightFill, width: 1),
      ),
      color: Colors.white,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TipDetailScreen(tip: tip)),
        ),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Ícono con fondo azul suave ────────────────────
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _kSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kLightFill),
                ),
                child: Icon(icon, color: _kPrimary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Etiqueta de categoría ─────────────────────
                    Text(
                      tip.category,
                      style: const TextStyle(
                        color: _kPrimaryLight,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 3),
                    // ── Título ─────────────────────────────────────
                    Text(
                      tip.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A3E),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // ── Descripción corta ─────────────────────────
                    Text(
                      tip.description,
                      style: TextStyle(
                        color: Colors.grey[600],
                        height: 1.4,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, color: _kAccent, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 72, color: _kLightFill),
          const SizedBox(height: 16),
          Text(
            _selectedCategory == null
                ? 'No hay consejos disponibles'
                : 'No hay consejos en "$_selectedCategory"',
            style: const TextStyle(color: _kAccent, fontSize: 15),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTips;

    return Scaffold(
      backgroundColor: _kSurface,
      appBar: AppBar(
        title: const Text('Consejos Dentales'),
        backgroundColor: _kPrimaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // ── Filtros de categoría ──────────────────────────────
          _buildCategoryFilter(),

          // ── Contador de resultados ────────────────────────────
          if (!_isLoadingTips && filtered.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
              child: Row(
                children: [
                  const Icon(Icons.tips_and_updates_outlined,
                      size: 14, color: _kAccent),
                  const SizedBox(width: 6),
                  Text(
                    '${filtered.length} consejo${filtered.length != 1 ? 's' : ''}',
                    style: const TextStyle(color: _kAccent, fontSize: 13),
                  ),
                ],
              ),
            ),

          // ── Contenido principal ───────────────────────────────
          Expanded(
            child: _isLoadingTips
                ? const Center(
                    child: CircularProgressIndicator(color: _kPrimary),
                  )
                : filtered.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                        itemCount: filtered.length,
                        // ✅ FIX RENDIMIENTO: addAutomaticKeepAlives y
                        // addRepaintBoundaries mejoran el scroll fluido
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries: true,
                        itemBuilder: (_, i) => _buildTipItem(filtered[i]),
                      ),
          ),
        ],
      ),
    );
  }
}