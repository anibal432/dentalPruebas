// lib/widgets/radius_selector.dart
import 'package:flutter/material.dart';

class RadiusSelector extends StatefulWidget {
  final double initialRadius;
  final Function(double) onRadiusChanged;

  const RadiusSelector({
    super.key,
    required this.initialRadius,
    required this.onRadiusChanged,
  });

  @override
  State<RadiusSelector> createState() => _RadiusSelectorState();
}

class _RadiusSelectorState extends State<RadiusSelector> {
  late double _currentRadius;

  @override
  void initState() {
    super.initState();
    _currentRadius = widget.initialRadius;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Radio de Búsqueda',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_searching, color: Colors.teal.shade700),
              const SizedBox(width: 12),
              Text(
                '${_currentRadius.toInt()} km',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Slider(
            value: _currentRadius,
            min: 5,
            max: 100,
            divisions: 19,
            label: '${_currentRadius.toInt()} km',
            activeColor: Colors.teal,
            onChanged: (value) {
              setState(() {
                _currentRadius = value;
              });
            },
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('5 km', style: TextStyle(color: Colors.grey.shade600)),
              Text('100 km', style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    widget.onRadiusChanged(_currentRadius);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Aplicar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}