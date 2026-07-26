import 'package:flutter/material.dart';

import 'lona_list_page.dart';
import 'lona_map_page.dart';

class LonasPage extends StatefulWidget {
  const LonasPage({super.key});

  @override
  State<LonasPage> createState() => _LonasPageState();
}

class _LonasPageState extends State<LonasPage> {
  int _revision = 0;

  Future<void> _capture() async {
    final saved = await Navigator.of(context).pushNamed('/lonas/nueva');
    if (saved == true && mounted) {
      setState(() => _revision++);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Lonas'),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.view_list_rounded), text: 'Listado'),
              Tab(icon: Icon(Icons.map_rounded), text: 'Mapa'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            LonaListPage(key: ValueKey('list-$_revision')),
            LonaMapPage(key: ValueKey('map-$_revision')),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _capture,
          icon: const Icon(Icons.add_a_photo_rounded),
          label: const Text('Capturar'),
        ),
      ),
    );
  }
}
