// lib/admin/screens/admin_dashboard_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const Color _kPrimary      = Color(0xFF3D3D8F);
const Color _kPrimaryDark  = Color(0xFF2A2A6E);
const Color _kPrimaryLight = Color(0xFF5C5CAF);
const Color _kAccent       = Color(0xFF8888C8);
const Color _kSurface      = Color(0xFFF0F0FA);
const Color _kLightFill    = Color(0xFFD0D0F0);

class _DashboardData {
  final int totalUsuarios;
  final int usuariosAdmin;
  final int usuariosRegulares;
  final int ingresosHoy;
  final int ingresosSemana;
  final int ingresosMes;
  final int minutosUsoTotal;
  final Map<String, int> loginMethods;
  final List<_UsuarioReciente> recientes;
  final Map<String, int> registrosPorDia;
  final int usuariosActivos30dias;

  const _DashboardData({
    required this.totalUsuarios,
    required this.usuariosAdmin,
    required this.usuariosRegulares,
    required this.ingresosHoy,
    required this.ingresosSemana,
    required this.ingresosMes,
    required this.minutosUsoTotal,
    required this.loginMethods,
    required this.recientes,
    required this.registrosPorDia,
    required this.usuariosActivos30dias,
  });
}

class _UsuarioReciente {
  final String nombre;
  final String email;
  final String role;
  final String metodo;
  final DateTime ultimoIngreso;
  final int totalIngresos;

  const _UsuarioReciente({
    required this.nombre,
    required this.email,
    required this.role,
    required this.metodo,
    required this.ultimoIngreso,
    required this.totalIngresos,
  });
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  _DashboardData? _data;
  bool _loading = true;
  String? _error;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);

    _loadData();

    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _loadData(silente: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool silente = false}) async {
    if (!silente) {
      setState(() {
        _loading = true;
        _error   = null;
      });
    }

    try {
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('usuarios')
            .get(const GetOptions(source: Source.server)),
        FirebaseFirestore.instance
            .collection('estadisticas')
            .doc('global')
            .get(),
      ]);

      final snap      = results[0] as QuerySnapshot;
      final globalDoc = results[1] as DocumentSnapshot;
      final docs      = snap.docs;

      final minutosUsoTotal =
          ((globalDoc.data() as Map<String, dynamic>?)?['minutosUsoTotal']
                  as num? ??
              0)
              .toInt();

      final ahora        = DateTime.now();
      final hoyInicio    = DateTime(ahora.year, ahora.month, ahora.day);
      final semanaInicio = hoyInicio.subtract(const Duration(days: 7));
      final mesInicio    = hoyInicio.subtract(const Duration(days: 30));

      int totalAdmin  = 0;
      int ingresosHoy = 0;
      int ingresosSem = 0;
      int ingresosMes = 0;
      int activos30   = 0;
      final loginMethods = <String, int>{};
      final recientes    = <_UsuarioReciente>[];

      final registrosDia = <String, int>{};
      for (int i = 6; i >= 0; i--) {
        final d   = hoyInicio.subtract(Duration(days: i));
        final key = '${_dayName(d.weekday)}\n${d.day}/${d.month}';
        registrosDia[key] = 0;
      }

      for (final doc in docs) {
        final data = doc.data() as Map<String, dynamic>;

        final role = (data['role'] as String?) ?? 'user';
        if (role == 'admin') totalAdmin++;

        final metodo = (data['metodoLogin'] as String?) ?? 'password';
        loginMethods[metodo] = (loginMethods[metodo] ?? 0) + 1;

        final totalIng = ((data['totalIngresos'] as num?) ?? 1).toInt();

        DateTime? ultimo;
        if (data['ultimoIngreso'] is Timestamp) {
          ultimo = (data['ultimoIngreso'] as Timestamp).toDate();
        }

        if (ultimo != null) {
          if (ultimo.isAfter(hoyInicio))    ingresosHoy++;
          if (ultimo.isAfter(semanaInicio)) ingresosSem++;
          if (ultimo.isAfter(mesInicio)) {
            ingresosMes++;
            activos30++;
          }
        }

        DateTime? primero;
        if (data['primerIngreso'] is Timestamp) {
          primero = (data['primerIngreso'] as Timestamp).toDate();
        }
        if (primero != null && primero.isAfter(semanaInicio)) {
          final key =
              '${_dayName(primero.weekday)}\n${primero.day}/${primero.month}';
          if (registrosDia.containsKey(key)) {
            registrosDia[key] = registrosDia[key]! + 1;
          }
        }

        recientes.add(_UsuarioReciente(
          nombre:        (data['nombre'] as String?) ?? 'Sin nombre',
          email:         (data['email']  as String?) ?? '',
          role:          role,
          metodo:        metodo,
          ultimoIngreso: ultimo ?? DateTime(2000),
          totalIngresos: totalIng,
        ));
      }

      recientes.sort((a, b) => b.ultimoIngreso.compareTo(a.ultimoIngreso));

      final dashData = _DashboardData(
        totalUsuarios:         docs.length,
        usuariosAdmin:         totalAdmin,
        usuariosRegulares:     docs.length - totalAdmin,
        ingresosHoy:           ingresosHoy,
        ingresosSemana:        ingresosSem,
        ingresosMes:           ingresosMes,
        minutosUsoTotal:       minutosUsoTotal,
        loginMethods:          loginMethods,
        recientes:             recientes.take(20).toList(),
        registrosPorDia:       registrosDia,
        usuariosActivos30dias: activos30,
      );

      if (!mounted) return;
      setState(() {
        _data    = dashData;
        _loading = false;
      });

      if (!silente) {
        _animController
          ..reset()
          ..forward();
      }
    } catch (e) {
      if (!mounted) return;
      if (!silente) {
        setState(() {
          _error   = 'Error al cargar estadísticas:\n$e';
          _loading = false;
        });
      }
    }
  }

  String _dayName(int weekday) {
    const names = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return names[(weekday - 1).clamp(0, 6)];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      appBar: AppBar(
        title: const Text(
          'Panel de Estadísticas',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: _kPrimaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? _buildLoader()
          : _error != null
              ? _buildError()
              : FadeTransition(opacity: _fadeAnim, child: _buildContent()),
    );
  }

  Widget _buildLoader() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: _kPrimary, strokeWidth: 3),
          SizedBox(height: 16),
          Text(
            'Cargando estadísticas…',
            style: TextStyle(color: _kPrimaryLight, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 72, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _loadData(),
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final d = _data!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
      children: [
        _buildHeader(d),
        const SizedBox(height: 20),
        _buildSectionTitle('Usuarios registrados'),
        const SizedBox(height: 10),
        _buildKpiRow(d),
        const SizedBox(height: 20),
        _buildSectionTitle('Actividad de accesos'),
        const SizedBox(height: 10),
        _buildActivityRow(d),
        const SizedBox(height: 20),
        _buildSectionTitle('Nuevos registros (últimos 7 días)'),
        const SizedBox(height: 10),
        _buildBarChart(d),
        const SizedBox(height: 20),
        _buildSectionTitle('Métodos de inicio de sesión'),
        const SizedBox(height: 10),
        _buildLoginMethodsCard(d),
        const SizedBox(height: 20),
        _buildSectionTitle('Últimos accesos'),
        const SizedBox(height: 10),
        _buildUsersTable(d),
      ],
    );
  }

  Widget _buildHeader(_DashboardData d) {
    final horas   = d.minutosUsoTotal ~/ 60;
    final minutos = d.minutosUsoTotal % 60;
    final usoStr  = horas > 0
        ? '$horas h $minutos min de uso total'
        : '${d.minutosUsoTotal} min de uso total';

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kPrimaryDark, _kPrimary, _kPrimaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _kPrimaryDark.withAlpha(100),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SALUD DENTAL AI',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Panel de Estadísticas',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  usoStr,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.analytics_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: _kPrimary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _kPrimaryDark,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildKpiRow(_DashboardData d) {
    final horas  = d.minutosUsoTotal ~/ 60;
    final minStr = horas > 0
        ? '${horas}h ${d.minutosUsoTotal % 60}m'
        : '${d.minutosUsoTotal}m';

    return Row(
      children: [
        Expanded(
          child: _KpiCard(
            label: 'Total',
            value: '${d.totalUsuarios}',
            icon: Icons.people_rounded,
            color: _kPrimary,
            subtitle: 'registrados',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _KpiCard(
            label: 'Admin',
            value: '${d.usuariosAdmin}',
            icon: Icons.admin_panel_settings_rounded,
            color: _kPrimaryDark,
            subtitle: 'administradores',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _KpiCard(
            label: 'Usuarios',
            value: '${d.usuariosRegulares}',
            icon: Icons.person_rounded,
            color: _kPrimaryLight,
            subtitle: 'regulares',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _KpiCard(
            label: 'Uso',
            value: minStr,
            icon: Icons.timer_rounded,
            color: _kAccent,
            subtitle: 'tiempo total',
          ),
        ),
      ],
    );
  }

  Widget _buildActivityRow(_DashboardData d) {
    return Row(
      children: [
        Expanded(
          child: _ActivityCard(
            label: 'Hoy',
            value: '${d.ingresosHoy}',
            icon: Icons.today_rounded,
            color: const Color(0xFF27AE60),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActivityCard(
            label: 'Esta semana',
            value: '${d.ingresosSemana}',
            icon: Icons.date_range_rounded,
            color: const Color(0xFFF39C12),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActivityCard(
            label: 'Este mes',
            value: '${d.ingresosMes}',
            icon: Icons.calendar_month_rounded,
            color: _kPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildBarChart(_DashboardData d) {
    final entries = d.registrosPorDia.entries.toList();
    final maxVal  = entries
        .map((e) => e.value)
        .fold(0, (prev, v) => v > prev ? v : prev);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: maxVal == 0
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(Icons.bar_chart_rounded, size: 48, color: _kLightFill),
                  SizedBox(height: 8),
                  Text(
                    'Sin nuevos registros en los últimos 7 días',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : SizedBox(
              height: 150,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: entries.map((entry) {
                  final ratio = maxVal > 0 ? entry.value / maxVal : 0.0;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (entry.value > 0)
                            Text(
                              '${entry.value}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _kPrimary,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Container(
                            height: (ratio * 100).clamp(4.0, 100.0),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: entry.value > 0
                                    ? [_kPrimaryLight, _kPrimaryDark]
                                    : [_kLightFill, _kLightFill],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            entry.key,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
    );
  }

  Widget _buildLoginMethodsCard(_DashboardData d) {
    final total   = d.totalUsuarios == 0 ? 1 : d.totalUsuarios;
    final methods = d.loginMethods;

    if (methods.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: _cardDecoration(),
        child: const Center(
          child: Text(
            'Sin datos de métodos de login',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        children: methods.entries.map((e) {
          final pct   = e.value / total * 100;
          final label = e.key == 'google.com'
              ? 'Google'
              : e.key == 'password'
                  ? 'Email / Contraseña'
                  : e.key;
          final color = e.key == 'google.com'
              ? const Color(0xFFE74C3C)
              : _kPrimary;
          final icon  = e.key == 'google.com'
              ? Icons.g_mobiledata_rounded
              : Icons.email_rounded;

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: _kPrimaryDark,
                        ),
                      ),
                    ),
                    Text(
                      '${e.value} (${pct.toStringAsFixed(1)}%)',
                      style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    minHeight: 8,
                    backgroundColor: _kLightFill,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildUsersTable(_DashboardData d) {
    return Container(
      decoration: _cardDecoration(),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: _kPrimaryDark,
            child: const Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Usuario',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Último acceso',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Ingresos',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Rol',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          if (d.recientes.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Sin datos de usuarios',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ...d.recientes.asMap().entries.map((e) {
              return _buildUserRow(e.value, e.key.isOdd);
            }),
        ],
      ),
    );
  }

  Widget _buildUserRow(_UsuarioReciente u, bool alternate) {
    final isAdmin  = u.role == 'admin';
    final isGoogle = u.metodo == 'google.com';

    final diff = DateTime.now().difference(u.ultimoIngreso);
    final String tiempo;
    if (u.ultimoIngreso.year == 2000) {
      tiempo = 'Sin registro';
    } else if (diff.inMinutes < 60) {
      tiempo = 'Hace ${diff.inMinutes} min';
    } else if (diff.inHours < 24) {
      tiempo = 'Hace ${diff.inHours} h';
    } else if (diff.inDays < 7) {
      tiempo = 'Hace ${diff.inDays}d';
    } else {
      tiempo =
          '${u.ultimoIngreso.day}/${u.ultimoIngreso.month}/${u.ultimoIngreso.year}';
    }

    return Container(
      color: alternate ? _kSurface : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor:
                      isAdmin ? _kPrimaryDark : _kAccent.withAlpha(80),
                  child: Text(
                    u.nombre.isNotEmpty ? u.nombre[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: isAdmin ? Colors.white : _kPrimaryDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        u.nombre,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _kPrimaryDark,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          Icon(
                            isGoogle
                                ? Icons.g_mobiledata_rounded
                                : Icons.email_rounded,
                            size: 10,
                            color: isGoogle
                                ? const Color(0xFFE74C3C)
                                : _kAccent,
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              u.email,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              tiempo,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _kPrimary.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${u.totalIngresos}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _kPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: isAdmin ? _kPrimaryDark : _kLightFill,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isAdmin ? 'Admin' : 'User',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isAdmin ? Colors.white : _kPrimaryDark,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kLightFill),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withAlpha(15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kLightFill),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(20),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _ActivityCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color.withAlpha(200),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}