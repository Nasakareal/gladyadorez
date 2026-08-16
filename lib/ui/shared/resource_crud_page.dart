import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/brand_theme.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';

enum ResourceFieldType {
  text,
  number,
  email,
  multiline,
  select,
  dateTime,
  toggle,
}

class ResourceField {
  const ResourceField({
    required this.keyName,
    required this.label,
    this.type = ResourceFieldType.text,
    this.required = false,
    this.options = const {},
    this.showInDetail = true,
    this.createOnly = false,
    this.requiredOnCreate = false,
  });

  final String keyName;
  final String label;
  final ResourceFieldType type;
  final bool required;
  final Map<String, String> options;
  final bool showInDetail;
  final bool createOnly;
  final bool requiredOnCreate;
}

class ResourceDefinition {
  const ResourceDefinition({
    required this.title,
    required this.singular,
    required this.endpoint,
    required this.permissionPrefix,
    required this.fields,
    required this.titleBuilder,
    required this.subtitleBuilder,
    this.searchHint = 'Buscar',
    this.searchParameter = 'q',
  });

  final String title;
  final String singular;
  final String endpoint;
  final String permissionPrefix;
  final List<ResourceField> fields;
  final String Function(Map<String, dynamic>) titleBuilder;
  final String Function(Map<String, dynamic>) subtitleBuilder;
  final String searchHint;
  final String searchParameter;
}

class ResourceCrudPage extends StatefulWidget {
  const ResourceCrudPage({super.key, required this.definition});
  final ResourceDefinition definition;

  @override
  State<ResourceCrudPage> createState() => _ResourceCrudPageState();
}

class _ResourceCrudPageState extends State<ResourceCrudPage> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  String? _error;
  int _page = 1;
  int _lastPage = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({int page = 1}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await context.read<ApiClient>().dio.get(
        widget.definition.endpoint,
        queryParameters: {
          'page': page,
          'per_page': 25,
          if (_search.text.trim().isNotEmpty)
            widget.definition.searchParameter: _search.text.trim(),
        },
      );
      final raw = response.data;
      final list = raw is List
          ? raw
          : raw is Map && raw['data'] is List
          ? raw['data'] as List
          : raw is Map && raw['items'] is List
          ? raw['items'] as List
          : const [];
      final meta = raw is Map && raw['meta'] is Map ? raw['meta'] as Map : raw;
      if (!mounted) return;
      setState(() {
        _items = list
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        _page =
            int.tryParse('${meta is Map ? meta['current_page'] : page}') ??
            page;
        _lastPage = int.tryParse('${meta is Map ? meta['last_page'] : 1}') ?? 1;
      });
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final definition = widget.definition;
    final auth = context.watch<AuthService>();
    return Scaffold(
      appBar: AppBar(title: Text(definition.title)),
      body: GladyzBackdrop(
        child: RefreshIndicator(
          onRefresh: () => _load(page: _page),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: GlassPanel(
                  margin: const EdgeInsets.fromLTRB(12, 14, 12, 10),
                  padding: const EdgeInsets.all(10),
                  child: TextField(
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _load(),
                    decoration: InputDecoration(
                      hintText: definition.searchHint,
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: IconButton(
                        onPressed: _loading ? null : _load,
                        icon: const Icon(Icons.arrow_forward_rounded),
                      ),
                    ),
                  ),
                ),
              ),
              if (_loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _MessageState(
                    icon: Icons.cloud_off_rounded,
                    message: _error!,
                    action: () => _load(page: _page),
                  ),
                )
              else if (_items.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _MessageState(
                    icon: Icons.inbox_outlined,
                    message: 'No hay registros con estos filtros.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  sliver: SliverList.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 9),
                    itemBuilder: (_, index) {
                      final item = _items[index];
                      return GlassPanel(
                        padding: EdgeInsets.zero,
                        onTap: () => _showItem(item),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: GladyzColors.granate.withValues(
                              alpha: .1,
                            ),
                            foregroundColor: GladyzColors.granate,
                            child: Text(
                              definition
                                      .titleBuilder(item)
                                      .characters
                                      .firstOrNull ??
                                  '•',
                            ),
                          ),
                          title: Text(
                            definition.titleBuilder(item),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(definition.subtitleBuilder(item)),
                          trailing: const Icon(Icons.chevron_right_rounded),
                        ),
                      );
                    },
                  ),
                ),
              if (!_loading && _lastPage > 1)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 26),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton.filledTonal(
                          onPressed: _page > 1
                              ? () => _load(page: _page - 1)
                              : null,
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text('$_page / $_lastPage'),
                        ),
                        IconButton.filledTonal(
                          onPressed: _page < _lastPage
                              ? () => _load(page: _page + 1)
                              : null,
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: auth.can('${definition.permissionPrefix}.crear')
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add_rounded),
              label: Text('Nuevo ${definition.singular.toLowerCase()}'),
            )
          : null,
    );
  }

  Future<void> _showItem(Map<String, dynamic> item) async {
    final definition = widget.definition;
    final auth = context.read<AuthService>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: .68,
        maxChildSize: .94,
        minChildSize: .4,
        expand: false,
        builder: (_, controller) => GlassPanel(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          opacity: .9,
          child: ListView(
            controller: controller,
            children: [
              Text(
                definition.titleBuilder(item),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              for (final field in definition.fields.where(
                (field) => field.showInDetail && !field.createOnly,
              ))
                if ('${item[field.keyName] ?? ''}'.isNotEmpty)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(field.label),
                    subtitle: Text(_displayValue(field, item[field.keyName])),
                  ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (auth.can('${definition.permissionPrefix}.editar'))
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _openForm(item: item);
                        },
                        icon: const Icon(Icons.edit_rounded),
                        label: const Text('Editar'),
                      ),
                    ),
                  if (auth.can('${definition.permissionPrefix}.editar') &&
                      auth.can('${definition.permissionPrefix}.borrar'))
                    const SizedBox(width: 10),
                  if (auth.can('${definition.permissionPrefix}.borrar'))
                    IconButton.filledTonal(
                      tooltip: 'Eliminar',
                      onPressed: () async {
                        Navigator.pop(sheetContext);
                        await _delete(item);
                      },
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openForm({Map<String, dynamic>? item}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ResourceForm(definition: widget.definition, item: item),
    );
    if (saved == true) await _load(page: item == null ? 1 : _page);
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminar ${widget.definition.singular.toLowerCase()}'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    try {
      await context.read<ApiClient>().dio.delete(
        '${widget.definition.endpoint}/${item['id']}',
      );
      await _load(page: _page);
    } catch (error) {
      if (mounted) _showError(_friendlyError(error));
    }
  }

  String _displayValue(ResourceField field, Object? value) {
    if (field.type == ResourceFieldType.toggle) {
      return value == true || value == 1 ? 'Sí' : 'No';
    }
    return field.options['$value'] ?? '$value';
  }

  void _showError(String message) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}

class _ResourceForm extends StatefulWidget {
  const _ResourceForm({required this.definition, this.item});
  final ResourceDefinition definition;
  final Map<String, dynamic>? item;

  @override
  State<_ResourceForm> createState() => _ResourceFormState();
}

class _ResourceFormState extends State<_ResourceForm> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, dynamic> _values = {};
  bool _saving = false;
  String? _error;

  bool get _editing => widget.item != null;

  @override
  void initState() {
    super.initState();
    for (final field in widget.definition.fields) {
      if (field.createOnly && _editing) continue;
      final value = widget.item?[field.keyName];
      _values[field.keyName] = value;
      _controllers[field.keyName] = TextEditingController(
        text: value?.toString() ?? '',
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() {
      _saving = true;
      _error = null;
    });
    final data = <String, dynamic>{};
    for (final field in widget.definition.fields) {
      if (field.createOnly && _editing) continue;
      dynamic value = _values[field.keyName];
      if (field.type == ResourceFieldType.number && '$value'.isNotEmpty) {
        value = num.tryParse('$value');
      }
      if (value == '') value = null;
      data[field.keyName] = value;
    }
    if (data.containsKey('password') && data['password'] != null) {
      data['password_confirmation'] = data['password'];
    }
    try {
      final api = context.read<ApiClient>().dio;
      if (_editing) {
        await api.put(
          '${widget.definition.endpoint}/${widget.item!['id']}',
          data: data,
        );
      } else {
        await api.post(widget.definition.endpoint, data: data);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: GlassPanel(
        opacity: .94,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${_editing ? 'Editar' : 'Nuevo'} ${widget.definition.singular.toLowerCase()}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 18),
                  for (final field in widget.definition.fields)
                    if (!field.createOnly || !_editing) ...[
                      _field(field),
                      const SizedBox(height: 12),
                    ],
                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 12),
                  ],
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(_saving ? 'Guardando…' : 'Guardar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(ResourceField field) {
    if (field.type == ResourceFieldType.select) {
      final current = '${_values[field.keyName] ?? ''}';
      return DropdownButtonFormField<String>(
        value: field.options.containsKey(current) ? current : null,
        decoration: InputDecoration(labelText: field.label),
        items: field.options.entries
            .map(
              (entry) =>
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            )
            .toList(),
        validator: (value) =>
            (field.required || (field.requiredOnCreate && !_editing)) &&
                (value == null || value.isEmpty)
            ? 'Campo requerido'
            : null,
        onChanged: (value) => _values[field.keyName] = value,
      );
    }
    if (field.type == ResourceFieldType.toggle) {
      return SwitchListTile.adaptive(
        value: _values[field.keyName] == true || _values[field.keyName] == 1,
        title: Text(field.label),
        onChanged: (value) => setState(() => _values[field.keyName] = value),
      );
    }
    return TextFormField(
      controller: _controllers[field.keyName],
      decoration: InputDecoration(labelText: field.label),
      keyboardType: switch (field.type) {
        ResourceFieldType.number => TextInputType.number,
        ResourceFieldType.email => TextInputType.emailAddress,
        ResourceFieldType.multiline => TextInputType.multiline,
        _ => TextInputType.text,
      },
      minLines: field.type == ResourceFieldType.multiline ? 3 : 1,
      maxLines: field.type == ResourceFieldType.multiline ? 6 : 1,
      validator: (value) =>
          (field.required || (field.requiredOnCreate && !_editing)) &&
              (value == null || value.trim().isEmpty)
          ? 'Campo requerido'
          : null,
      onSaved: (value) => _values[field.keyName] = value?.trim(),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.icon, required this.message, this.action});
  final IconData icon;
  final String message;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 52,
            color: GladyzColors.granate.withValues(alpha: .45),
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: action,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ],
      ),
    ),
  );
}

String _friendlyError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['errors'] is Map) {
      final errors = data['errors'] as Map;
      return errors.values
          .whereType<List>()
          .expand((messages) => messages)
          .join('\n');
    }
    if (data is Map && data['message'] != null) return '${data['message']}';
    if (error.response?.statusCode == 403) {
      return 'Esta opción no está disponible para tu usuario.';
    }
  }
  return 'No se pudo completar la operación. Revisa tu conexión.';
}
