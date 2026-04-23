// lib/dental_dictionary/screens/dental_dictionary_screen.dart
import 'package:flutter/material.dart';
import '../models/dental_dictionary_entry.dart';
import '../services/dental_dictionary_service.dart';
import 'dental_dictionary_detail_screen.dart';

// ─── Helpers de categoría ───────────────────────────────────

Color _catColor(String category) {
  switch (category.toLowerCase()) {
    case 'enfermedades comunes':
      return Colors.red;
    case 'procedimientos':
      return Colors.blue;
    case 'anatomía':
      return Colors.green;
    case 'ortodoncia':
      return Colors.orange;
    case 'higiene':
      return Colors.purple;
    case 'materiales':
      return Colors.brown;
    default:
      return Colors.teal;
  }
}

IconData _catIcon(String category) {
  switch (category.toLowerCase()) {
    case 'enfermedades comunes':
      return Icons.sick;
    case 'procedimientos':
      return Icons.medical_services;
    case 'anatomía':
      return Icons.biotech;
    case 'ortodoncia':
      return Icons.straighten;
    case 'higiene':
      return Icons.cleaning_services;
    case 'materiales':
      return Icons.science;
    default:
      return Icons.menu_book;
  }
}

// ───────────────────────────────────────────────────────────

class DentalDictionaryScreen extends StatefulWidget {
  const DentalDictionaryScreen({super.key});

  @override
  State<DentalDictionaryScreen> createState() =>
      _DentalDictionaryScreenState();
}

class _DentalDictionaryScreenState extends State<DentalDictionaryScreen> {
  final DentalDictionaryService _service = DentalDictionaryService();

  // Estado principal
  List<DentalDictionaryEntry> _allEntries = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Filtros
  String? _selectedCategory;
  List<String> _categories = ['Todas'];
  String? _selectedLetter;

  static const List<String> _alphabet = [
    'A','B','C','D','E','F','G','H','I','J','K','L','M',
    'N','O','P','Q','R','S','T','U','V','W','X','Y','Z',
  ];

  // ── Lifecycle ─────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ── Carga de datos ────────────────────────────────────────

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
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
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadByCategory(String category) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final entries = await _service.getEntriesByCategory(category);
      if (!mounted) return;
      setState(() {
        _allEntries = entries;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error al filtrar por categoría.';
        _isLoading = false;
      });
    }
  }

  // ── Filtrado por letra ────────────────────────────────────

  List<DentalDictionaryEntry> get _filtered {
    if (_selectedLetter == null) return _allEntries;
    return _allEntries
        .where((e) => e.title.toUpperCase().startsWith(_selectedLetter!))
        .toList();
  }

  // ── Widgets ───────────────────────────────────────────────

  Widget _buildCategoryFilter() {
    return Container(
      height: 52,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selectedCategory == cat ||
              (_selectedCategory == null && cat == 'Todas');
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              label: Text(cat, style: const TextStyle(fontSize: 13)),
              selected: isSelected,
              onSelected: (_) {
                final newCat = cat == 'Todas' ? null : cat;
                setState(() {
                  _selectedCategory = newCat;
                  _selectedLetter = null;
                });
                if (newCat == null) {
                  _loadData();
                } else {
                  _loadByCategory(newCat);
                }
              },
              selectedColor: const Color(0xFF3D3D8F).withAlpha(51),
              checkmarkColor: const Color(0xFF3D3D8F),
              backgroundColor: Colors.grey[100],
              labelStyle: TextStyle(
                color: isSelected ? const Color(0xFF3D3D8F) : Colors.grey[700],
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAlphabetIndex() {
    final available = _allEntries
        .where((e) => e.title.isNotEmpty)
        .map((e) => e.title[0].toUpperCase())
        .toSet();

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
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? Color(0xFF2A2A6E)
              : active
                  ? Colors.white
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? Color(0xFF2A2A6E)
                : active
                    ? Colors.grey.shade300
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
                    ? Colors.grey[800]
                    : Colors.grey[400],
          ),
        ),
      ),
    );
  }

  Widget _buildEntryCard(DentalDictionaryEntry entry) {
    final color = _catColor(entry.category);
    final icon = _catIcon(entry.category);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DentalDictionaryDetailScreen(entry: entry),
          ),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    entry.title.isNotEmpty ? entry.title[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: color,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withAlpha(20),
                        borderRadius: BorderRadius.circular(20),
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
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      entry.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                          height: 1.4),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
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
            Icon(Icons.menu_book, size: 72, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(msg,
                style: TextStyle(color: Colors.grey[500], fontSize: 15),
                textAlign: TextAlign.center),
          ],
        ),
      );

  Widget _buildErrorState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 72, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Error desconocido',
              style: TextStyle(color: Colors.grey[600], fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3D3D8F),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Diccionario Dental'),
        backgroundColor: const Color(0xFF3D3D8F),
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
          if (!_isLoading && _errorMessage == null)
            _buildAlphabetIndex(),

          // Contador
          if (!_isLoading && _errorMessage == null && filtered.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(
                children: [
                  Icon(Icons.menu_book, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Text(
                    '${filtered.length} término${filtered.length != 1 ? 's' : ''}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                ],
              ),
            ),

          // Contenido
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.teal),
                  )
                : _errorMessage != null
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
                            color: Color(0xFF2A2A6E),
                            onRefresh: _loadData,
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(12, 4, 12, 16),
                              itemCount: filtered.length,
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