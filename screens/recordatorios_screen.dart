// lib/screens/recordatorios_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/recordatorio.dart';
import '../services/recordatorios_service.dart';
import '../services/notification_service.dart';

const Color _kPrimary     = Color(0xFF3D3D8F);
const Color _kPrimaryDark = Color(0xFF2A2A6E);
const Color _kAccent      = Color(0xFF8888C8);
const Color _kSurface     = Color(0xFFF0F0FA);
const Color _kLightFill   = Color(0xFFD0D0F0);

/// Convierte la fecha del recordatorio en un id de notificación estable
/// y compatible con int de 32 bits (lo que exige el plugin nativo).
int _idNotificacionDesdeFecha(DateTime fecha) {
  return fecha.millisecondsSinceEpoch ~/ 1000 % 2147483647;
}

/// Pantalla del usuario final: crea y ve sus propios recordatorios/citas
/// personales, desde hoy hasta el 31 de diciembre del año actual.
class RecordatoriosScreen extends StatefulWidget {
  const RecordatoriosScreen({super.key});

  @override
  State<RecordatoriosScreen> createState() => _RecordatoriosScreenState();
}

class _RecordatoriosScreenState extends State<RecordatoriosScreen> {
  final _service = RecordatoriosService();
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Future<void> _cambiarEstado(
      Recordatorio r, EstadoRecordatorio nuevoEstado) async {
    if (_uid == null) return;
    try {
      await _service.actualizarEstado(_uid!, r.id, nuevoEstado);
      if (nuevoEstado == EstadoRecordatorio.completado ||
          nuevoEstado == EstadoRecordatorio.cancelado) {
        await NotificationService()
            .cancelarRecordatorio(_idNotificacionDesdeFecha(r.fecha));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _eliminar(Recordatorio r) async {
    if (_uid == null) return;
    try {
      await _service.eliminarRecordatorio(_uid!, r.id);
      await NotificationService()
          .cancelarRecordatorio(_idNotificacionDesdeFecha(r.fecha));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _abrirNuevoRecordatorio() async {
    if (_uid == null) return;
    final creado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NuevoRecordatorioSheet(uid: _uid!),
    );
    if (creado == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recordatorio creado')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null) {
      return const Scaffold(
        body: Center(child: Text('Debes iniciar sesión')),
      );
    }

    return Scaffold(
      backgroundColor: _kSurface,
      appBar: AppBar(
        title: const Text('Mis Recordatorios',
            style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: _kPrimaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirNuevoRecordatorio,
        backgroundColor: _kPrimary,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo recordatorio'),
      ),
      body: StreamBuilder<List<Recordatorio>>(
        stream: _service.streamRecordatorios(_uid!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _kPrimary),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error al cargar recordatorios: ${snapshot.error}'),
            );
          }
          final recordatorios = snapshot.data ?? [];
          if (recordatorios.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_available_rounded,
                        size: 56, color: _kLightFill),
                    SizedBox(height: 12),
                    Text(
                      'No tienes recordatorios próximos',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
            itemCount: recordatorios.length,
            itemBuilder: (context, i) => _RecordatorioCard(
              recordatorio: recordatorios[i],
              onCambiarEstado: _cambiarEstado,
              onEliminar: _eliminar,
            ),
          );
        },
      ),
    );
  }
}

class _RecordatorioCard extends StatelessWidget {
  final Recordatorio recordatorio;
  final Future<void> Function(Recordatorio, EstadoRecordatorio) onCambiarEstado;
  final Future<void> Function(Recordatorio) onEliminar;

  const _RecordatorioCard({
    required this.recordatorio,
    required this.onCambiarEstado,
    required this.onEliminar,
  });

  Color _colorEstado(EstadoRecordatorio estado) {
    switch (estado) {
      case EstadoRecordatorio.pendiente:
        return const Color(0xFFF39C12);
      case EstadoRecordatorio.completado:
        return const Color(0xFF27AE60);
      case EstadoRecordatorio.cancelado:
        return const Color(0xFFE74C3C);
    }
  }

  String _fechaHora(DateTime d) {
    const dias = [
      'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'
    ];
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${dias[d.weekday - 1]} ${d.day}/${d.month} · $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorEstado(recordatorio.estado);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kLightFill),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withAlpha(15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _kPrimaryDark,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _fechaHora(recordatorio.fecha),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  recordatorio.titulo,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: _kPrimaryDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  recordatorio.estado.etiqueta,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          if (recordatorio.notas.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              recordatorio.notas,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Text('Tipo: ${recordatorio.tipo}',
                  style: const TextStyle(fontSize: 11, color: _kAccent)),
              const Spacer(),
              if (recordatorio.estado == EstadoRecordatorio.pendiente)
                TextButton(
                  onPressed: () => onCambiarEstado(
                      recordatorio, EstadoRecordatorio.completado),
                  child: const Text('Completar'),
                ),
              if (recordatorio.estado == EstadoRecordatorio.pendiente)
                TextButton(
                  onPressed: () => onCambiarEstado(
                      recordatorio, EstadoRecordatorio.cancelado),
                  style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFE74C3C)),
                  child: const Text('Cancelar'),
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                color: Colors.grey,
                onPressed: () => onEliminar(recordatorio),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Formulario para que el propio usuario cree su recordatorio.
/// La fecha está restringida entre hoy y el 31 de diciembre del año actual.
class _NuevoRecordatorioSheet extends StatefulWidget {
  final String uid;
  const _NuevoRecordatorioSheet({required this.uid});

  @override
  State<_NuevoRecordatorioSheet> createState() =>
      _NuevoRecordatorioSheetState();
}

class _NuevoRecordatorioSheetState extends State<_NuevoRecordatorioSheet> {
  final _service = RecordatoriosService();
  final _tituloController = TextEditingController();
  final _notasController = TextEditingController();

  late DateTime _fecha;
  TimeOfDay _hora = const TimeOfDay(hour: 9, minute: 0);
  String _tipo = 'revision';
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _fecha = _service.inicioHoy;
  }

  Future<void> _elegirFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: _service.inicioHoy,
      lastDate: _service.finDeAnio,
    );
    if (fecha != null) setState(() => _fecha = fecha);
  }

  Future<void> _elegirHora() async {
    final hora = await showTimePicker(context: context, initialTime: _hora);
    if (hora != null) setState(() => _hora = hora);
  }

  Future<void> _guardar() async {
    if (_tituloController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ponle un título al recordatorio')),
      );
      return;
    }

    setState(() => _guardando = true);
    try {
      final fechaCompleta = DateTime(
        _fecha.year,
        _fecha.month,
        _fecha.day,
        _hora.hour,
        _hora.minute,
      );

      await _service.crearRecordatorio(
        uid: widget.uid,
        titulo: _tituloController.text.trim(),
        fecha: fechaCompleta,
        tipo: _tipo,
        notas: _notasController.text.trim(),
      );

      // Programa la notificación local para que suene a la hora elegida
      await NotificationService().programarRecordatorio(
        id: _idNotificacionDesdeFecha(fechaCompleta),
        titulo: _tituloController.text.trim(),
        cuerpo: 'Tienes un recordatorio dental hoy',
        fecha: fechaCompleta,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _guardando = false);
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nuevo recordatorio',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _tituloController,
                  decoration: const InputDecoration(
                    labelText: 'Título (ej. Limpieza dental)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _elegirFecha,
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          '${_fecha.day}/${_fecha.month}/${_fecha.year}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _elegirHora,
                        icon: const Icon(Icons.access_time, size: 16),
                        label: Text(_hora.format(context)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _tipo,
                  decoration: const InputDecoration(
                    labelText: 'Tipo',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'revision', child: Text('Revisión')),
                    DropdownMenuItem(value: 'limpieza', child: Text('Limpieza')),
                    DropdownMenuItem(value: 'urgencia', child: Text('Urgencia')),
                  ],
                  onChanged: (v) => setState(() => _tipo = v ?? 'revision'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _notasController,
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _guardando ? null : _guardar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _guardando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Crear recordatorio'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}