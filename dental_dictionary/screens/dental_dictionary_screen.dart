// lib/dental_dictionary/screens/dental_dictionary_screen.dart
import 'package:flutter/material.dart';
import '../models/dental_dictionary_entry.dart';
import '../services/dental_dictionary_service.dart';
import 'dental_dictionary_detail_screen.dart';
import '../../utils/error_messages.dart';

// ── Paleta institucional unificada ────────────────────────────
const Color _kPrimaryDark  = Color(0xFF2A2A6E);
const Color _kPrimary      = Color(0xFF3D3D8F);
const Color _kPrimaryLight = Color(0xFF5C5CAF);
const Color _kAccent       = Color(0xFF8888C8);
const Color _kLightFill    = Color(0xFFD0D0F0);
const Color _kSurface      = Color(0xFFF0F0FA);

class DentalDictionaryScreen extends StatefulWidget {
  const DentalDictionaryScreen({super.key});

  @override
  State<DentalDictionaryScreen> createState() =>
      _DentalDictionaryScreenState();
}

class _DentalDictionaryScreenState extends State<DentalDictionaryScreen> {
  final DentalDictionaryService _service = DentalDictionaryService();

  // ── Estado ────────────────────────────────────────────────
  List<DentalDictionaryEntry> _allEntries = [];
  bool _isLoading = true;
  Object? _error;

  // Filtros
  String? _selectedCategory;
  List<String> _categories = ['Todas'];
  String? _selectedLetter;

  static const List<String> _alphabet = [
    'A','B','C','D','E','F','G','H','I','J','K','L','M',
    'N','O','P','Q','R','S','T','U','V','W','X','Y','Z',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ── Carga única — filtrado 100% local ─────────────────────
  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _service.getAllEntries(),
        _service.getCategories(),
      ]);

      if (!mounted) return;
      setState(() {
        _allEntries = results[0] as List<DentalDictionaryEntry>;
        _categories = ['Todas', ...(results[1] as List<String>)];
        _isLoading  = false;
      });
    } catch (e) {
      // El detalle técnico solo va a la consola de depuración;
      // el usuario ve un mensaje amigable (ver _buildErrorState).
      debugPrint('❌ DentalDictionaryScreen._loadData error: $e');
      if (!mounted) return;
      setState(() {
        _error     = e;
        _isLoading = false;
      });
    }
  }

  // ── Filtrado local (sin Firestore) ────────────────────────
  List<DentalDictionaryEntry> get _filtered {
    var list = _allEntries;

    if (_selectedCategory != null) {
      list = list.where((e) => e.category == _selectedCategory).toList();
    }

    if (_selectedLetter != null) {
      list = list
          .where((e) => e.title.toUpperCase().startsWith(_selectedLetter!))
          .toList();
    }

    return list;
  }

  Set<String> get _availableLetters {
    var list = _allEntries;
    if (_selectedCategory != null) {
      list = list.where((e) => e.category == _selectedCategory).toList();
    }
    return list
        .where((e) => e.title.isNotEmpty)
        .map((e) => e.title[0].toUpperCase())
        .toSet();
  }

  // ── Color único por categoría (variaciones del azul) ─────
  Color _catColor(String category) {
    switch (category.toLowerCase()) {
      case 'enfermedades comunes':
        return _kPrimary;
      case 'procedimientos':
        return _kPrimaryDark;
      case 'anatomía':
      case 'anatomía dental':
        return _kPrimaryLight;
      case 'ortodoncia':
        return _kAccent;
      case 'higiene':
        return _kPrimary;
      case 'materiales':
        return _kPrimaryDark;
      case 'tratamientos dentales':
      case 'tratamientos':
        return _kPrimaryLight;
      default:
        return _kPrimary;
    }
  }

  IconData _catIcon(String category) {
    switch (category.toLowerCase()) {
      case 'enfermedades comunes':
        return Icons.sick_outlined;
      case 'procedimientos':
        return Icons.medical_services_outlined;
      case 'anatomía':
      case 'anatomía dental':
        return Icons.biotech_outlined;
      case 'ortodoncia':
        return Icons.straighten;
      case 'higiene':
        return Icons.clean_hands_outlined;
      case 'materiales':
        return Icons.science_outlined;
      case 'tratamientos dentales':
      case 'tratamientos':
        return Icons.healing_outlined;
      default:
        return Icons.menu_book_outlined;
    }
  }

  // ── Filtro de categorías ──────────────────────────────────
  Widget _buildCategoryFilter() {
    return Container(
      height: 52,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selectedCategory == cat ||
              (_selectedCategory == null && cat == 'Todas');
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() {
                _selectedCategory = cat == 'Todas' ? null : cat;
                _selectedLetter   = null;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected ? _kPrimary : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? _kPrimary : _kLightFill,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  cat,
                  style: TextStyle(
                    color: isSelected ? Colors.white : _kPrimaryLight,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
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

  // ── Índice alfabético ─────────────────────────────────────
  Widget _buildAlphabetIndex() {
    // ✅ FIX: usa _availableLetters que respeta la categoría activa
    final available = _availableLetters;

    return Container(
      height: 44,
      color: Colors.grey[50],
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        children: [
          _letterChip('Todas', _selectedLetter == null, true),
          for (final l in _alphabet)
            _letterChip(l, _selectedLetter == l, available.contains(l)),
        ],
      ),
    );
  }

  Widget _letterChip(String label, bool selected, bool active) {
    return GestureDetector(
      onTap: active
          ? () => setState(() {
                _selectedLetter = label == 'Todas' ? null : label;
              })
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? _kPrimaryDark
              : active
                  ? Colors.white
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? _kPrimaryDark
                : active
                    ? _kLightFill
                    : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected
                ? Colors.white
                : active
                    ? _kPrimaryLight
                    : Colors.grey[400],
          ),
        ),
      ),
    );
  }

  // ── Tarjeta de entrada ────────────────────────────────────
  Widget _buildEntryCard(DentalDictionaryEntry entry) {
    final color = _catColor(entry.category);
    final icon  = _catIcon(entry.category);

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
          MaterialPageRoute(
            builder: (_) => DentalDictionaryDetailScreen(entry: entry),
          ),
        ),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Avatar con inicial ──────────────────────
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _kSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kLightFill),
                ),
                child: Center(
                  child: Text(
                    entry.title.isNotEmpty
                        ? entry.title[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: color,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Título ──────────────────────────────
                    Text(
                      entry.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A3E),
                      ),
                    ),
                    const SizedBox(height: 5),
                    // ── Badge de categoría ──────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _kSurface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _kLightFill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 11, color: color),
                          const SizedBox(width: 4),
                          Text(
                            entry.category,
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    // ── Descripción corta ───────────────────
                    Text(
                      entry.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                        height: 1.4,
                      ),
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

  Widget _buildEmptyState(String msg) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book_outlined, size: 72, color: _kLightFill),
            const SizedBox(height: 16),
            Text(
              msg,
              style: const TextStyle(color: _kAccent, fontSize: 15),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

  Widget _buildErrorState() {
    final friendly = obtenerErrorAmigable(_error ?? 'Error desconocido');
    final icon = friendly.esProblemaDeConexion
        ? Icons.wifi_off_rounded
        : Icons.sentiment_dissatisfied_rounded;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Icono dentro de un círculo con la paleta institucional ──
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: _kSurface,
                shape: BoxShape.circle,
                border: Border.all(color: _kLightFill, width: 1.5),
              ),
              child: Icon(icon, size: 40, color: _kPrimary),
            ),
            const SizedBox(height: 24),
            Text(
              friendly.titulo,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A3E),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              friendly.mensaje,
              style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: _kSurface,
      appBar: AppBar(
        title: const Text('Diccionario Dental'),
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
          // Filtro de categorías
          if (_categories.length > 1) _buildCategoryFilter(),

          // Índice alfabético
          if (!_isLoading && _error == null) _buildAlphabetIndex(),

          // Contador
          if (!_isLoading && _error == null && filtered.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
              child: Row(
                children: [
                  const Icon(Icons.menu_book_outlined,
                      size: 14, color: _kAccent),
                  const SizedBox(width: 6),
                  Text(
                    '${filtered.length} término${filtered.length != 1 ? 's' : ''}',
                    style: const TextStyle(color: _kAccent, fontSize: 13),
                  ),
                ],
              ),
            ),

          // Contenido
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: _kPrimary),
                  )
                : _error != null
                    ? _buildErrorState()
                    : filtered.isEmpty
                        ? _buildEmptyState(
                            _selectedLetter != null
                                ? 'No hay términos con la letra "$_selectedLetter"'
                                : _allEntries.isEmpty
                                    ? 'No hay entradas en el diccionario'
                                    : 'No hay entradas en esta categoría',
                          )
                        : RefreshIndicator(
                            color: _kPrimary,
                            onRefresh: _loadData,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                  12, 4, 12, 16),
                              itemCount: filtered.length,
                              addAutomaticKeepAlives: false,
                              addRepaintBoundaries: true,
                              itemBuilder: (_, i) =>
                                  _buildEntryCard(filtered[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}