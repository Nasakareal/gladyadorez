import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/brand_theme.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../shared/resource_crud_page.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final items =
        <
              ({
                String title,
                String subtitle,
                IconData icon,
                String permission,
                String route,
              })
            >[
              (
                title: 'Usuarios',
                subtitle: 'Cuentas y roles asignados',
                icon: Icons.group_rounded,
                permission: 'usuarios.ver',
                route: '/admin/usuarios',
              ),
              (
                title: 'Roles',
                subtitle: 'Roles disponibles',
                icon: Icons.badge_rounded,
                permission: 'roles.ver',
                route: '/admin/roles',
              ),
              (
                title: 'Permisos',
                subtitle: 'Funciones visibles por rol',
                icon: Icons.admin_panel_settings_rounded,
                permission: 'permisos.ver',
                route: '/admin/permisos',
              ),
              (
                title: 'Comunicados',
                subtitle: 'Publicar y administrar avisos',
                icon: Icons.campaign_rounded,
                permission: 'comunicados.ver',
                route: '/admin/comunicados',
              ),
              (
                title: 'Configuración',
                subtitle: 'Control global de captura',
                icon: Icons.tune_rounded,
                permission: 'settings.ver',
                route: '/admin/configuracion',
              ),
            ]
            .where((item) => auth.can(item.permission))
            .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Administración')),
      body: GladyzBackdrop(
        child: ListView.separated(
          padding: const EdgeInsets.all(14),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, index) {
            final item = items[index];
            return GlassPanel(
              padding: EdgeInsets.zero,
              onTap: () => Navigator.pushNamed(context, item.route),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                leading: Icon(item.icon, color: GladyzColors.granate),
                title: Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(item.subtitle),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
            );
          },
        ),
      ),
    );
  }
}

class UsuariosPage extends StatelessWidget {
  const UsuariosPage({super.key});

  static const _definition = ResourceDefinition(
    title: 'Usuarios',
    singular: 'Usuario',
    endpoint: '/v1/admin/usuarios',
    permissionPrefix: 'usuarios',
    searchHint: 'Nombre o correo',
    fields: [
      ResourceField(keyName: 'name', label: 'Nombre', required: true),
      ResourceField(
        keyName: 'email',
        label: 'Correo',
        type: ResourceFieldType.email,
        required: true,
      ),
      ResourceField(
        keyName: 'role',
        label: 'Rol (nombre exacto)',
        required: true,
      ),
      ResourceField(
        keyName: 'password',
        label: 'Contraseña (mínimo 8 caracteres)',
        showInDetail: false,
        requiredOnCreate: true,
      ),
    ],
    titleBuilder: _title,
    subtitleBuilder: _subtitle,
  );

  static String _title(Map<String, dynamic> item) =>
      '${item['name'] ?? 'Sin nombre'}';
  static String _subtitle(Map<String, dynamic> item) =>
      '${item['email'] ?? ''} · ${item['role'] ?? 'Sin rol'}';

  @override
  Widget build(BuildContext context) =>
      const ResourceCrudPage(definition: _definition);
}

class RolesPage extends StatelessWidget {
  const RolesPage({super.key});

  static const _definition = ResourceDefinition(
    title: 'Roles',
    singular: 'Rol',
    endpoint: '/v1/admin/roles',
    permissionPrefix: 'roles',
    fields: [ResourceField(keyName: 'name', label: 'Nombre', required: true)],
    titleBuilder: _title,
    subtitleBuilder: _subtitle,
  );

  static String _title(Map<String, dynamic> item) =>
      '${item['name'] ?? 'Sin nombre'}';
  static String _subtitle(Map<String, dynamic> item) =>
      '${item['users_count'] ?? 0} usuarios · ${item['permissions_count'] ?? 0} permisos';

  @override
  Widget build(BuildContext context) =>
      const ResourceCrudPage(definition: _definition);
}

class ComunicadosAdminPage extends StatelessWidget {
  const ComunicadosAdminPage({super.key});

  static const _definition = ResourceDefinition(
    title: 'Comunicados',
    singular: 'Comunicado',
    endpoint: '/v1/admin/comunicados',
    permissionPrefix: 'comunicados',
    fields: [
      ResourceField(keyName: 'titulo', label: 'Título', required: true),
      ResourceField(
        keyName: 'contenido',
        label: 'Contenido',
        type: ResourceFieldType.multiline,
        required: true,
      ),
      ResourceField(
        keyName: 'visible_desde',
        label: 'Visible desde (AAAA-MM-DD HH:mm)',
      ),
      ResourceField(
        keyName: 'visible_hasta',
        label: 'Visible hasta (AAAA-MM-DD HH:mm)',
      ),
      ResourceField(
        keyName: 'estado',
        label: 'Estado',
        type: ResourceFieldType.select,
        required: true,
        options: {
          'borrador': 'Borrador',
          'publicado': 'Publicado',
          'archivado': 'Archivado',
        },
      ),
    ],
    titleBuilder: _title,
    subtitleBuilder: _subtitle,
  );

  static String _title(Map<String, dynamic> item) =>
      '${item['titulo'] ?? 'Sin título'}';
  static String _subtitle(Map<String, dynamic> item) =>
      '${item['estado'] ?? 'borrador'}';

  @override
  Widget build(BuildContext context) =>
      const ResourceCrudPage(definition: _definition);
}

class RolePermissionsPage extends StatefulWidget {
  const RolePermissionsPage({super.key});

  @override
  State<RolePermissionsPage> createState() => _RolePermissionsPageState();
}

class _RolePermissionsPageState extends State<RolePermissionsPage> {
  List<Map<String, dynamic>> _roles = const [];
  Map<String, List<String>> _groups = const {};
  Set<String> _selected = {};
  int? _roleId;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    try {
      final response = await context.read<ApiClient>().dio.get(
        '/v1/admin/roles',
      );
      final list = response.data is Map ? response.data['data'] as List? : null;
      _roles = (list ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (_roles.isNotEmpty) {
        await _loadPermissions(int.parse('${_roles.first['id']}'));
      }
    } catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadPermissions(int roleId) async {
    setState(() {
      _roleId = roleId;
      _loading = true;
      _error = null;
    });
    try {
      final response = await context.read<ApiClient>().dio.get(
        '/v1/admin/roles/$roleId/permisos',
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      final all = ((data['permissions'] as List?) ?? const [])
          .map((item) => '$item')
          .toList();
      final groups = <String, List<String>>{};
      for (final permission in all) {
        final module = permission.split('.').first;
        (groups[module] ??= []).add(permission);
      }
      if (mounted) {
        setState(() {
          _groups = groups;
          _selected = ((data['selected'] as List?) ?? const [])
              .map((item) => '$item')
              .toSet();
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final roleId = _roleId;
    if (roleId == null) return;
    setState(() => _saving = true);
    try {
      await context.read<ApiClient>().dio.put(
        '/v1/admin/roles/$roleId/permisos',
        data: {'permissions': _selected.toList()},
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Permisos actualizados.')));
      }
    } catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = context.watch<AuthService>().can('permisos.editar');
    return Scaffold(
      appBar: AppBar(title: const Text('Permisos por rol')),
      body: GladyzBackdrop(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: DropdownButtonFormField<int>(
                value: _roleId,
                decoration: const InputDecoration(labelText: 'Rol'),
                items: _roles
                    .map(
                      (role) => DropdownMenuItem(
                        value: int.parse('${role['id']}'),
                        child: Text('${role['name']}'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) _loadPermissions(value);
                },
              ),
            ),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 100),
                children: [
                  for (final group in _groups.entries)
                    GlassPanel(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.key.toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: GladyzColors.granate,
                            ),
                          ),
                          for (final permission in group.value)
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _selected.contains(permission),
                              title: Text(permission.split('.').last),
                              onChanged: canEdit
                                  ? (value) => setState(
                                      () => value == true
                                          ? _selected.add(permission)
                                          : _selected.remove(permission),
                                    )
                                  : null,
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_rounded),
              label: Text(_saving ? 'Guardando…' : 'Guardar'),
            )
          : null,
    );
  }
}

class AppSettingsPage extends StatefulWidget {
  const AppSettingsPage({super.key});

  @override
  State<AppSettingsPage> createState() => _AppSettingsPageState();
}

class _AppSettingsPageState extends State<AppSettingsPage> {
  final _reason = TextEditingController();
  bool _captureEnabled = true;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final response = await context.read<ApiClient>().dio.get('/v1/admin/app');
      final data = Map<String, dynamic>.from(response.data as Map);
      _captureEnabled =
          data['captura_habilitada'] == true || data['captura_habilitada'] == 1;
      _reason.text = '${data['motivo_bloqueo'] ?? ''}';
    } catch (error) {
      _error = _errorMessage(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.read<ApiClient>().dio.put(
        '/v1/admin/app',
        data: {
          'captura_habilitada': _captureEnabled,
          'motivo_bloqueo': _reason.text.trim().isEmpty
              ? null
              : _reason.text.trim(),
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuración guardada.')),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = context.watch<AuthService>().can('settings.editar');
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración de la app')),
      body: GladyzBackdrop(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  GlassPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Captura habilitada',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: const Text(
                            'Controla el registro global de afiliados.',
                          ),
                          value: _captureEnabled,
                          onChanged: canEdit
                              ? (value) =>
                                    setState(() => _captureEnabled = value)
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _reason,
                          enabled: canEdit,
                          minLines: 3,
                          maxLines: 6,
                          decoration: const InputDecoration(
                            labelText: 'Motivo del bloqueo',
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                        if (canEdit) ...[
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: const Icon(Icons.save_rounded),
                            label: Text(_saving ? 'Guardando…' : 'Guardar'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

String _errorMessage(Object error) {
  if (error is DioException && error.response?.data is Map) {
    return '${(error.response!.data as Map)['message'] ?? 'No se pudo completar la operación.'}';
  }
  return 'No se pudo completar la operación.';
}
