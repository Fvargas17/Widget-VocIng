import 'package:flutter/material.dart';

import '../services/pack_service.dart';
import '../widgets/app_drawer.dart';

class PackManagementScreen extends StatefulWidget {
  const PackManagementScreen({super.key});

  @override
  State<PackManagementScreen> createState() => _PackManagementScreenState();
}

class _PackManagementScreenState extends State<PackManagementScreen> {
  List<PackMetadata>? _packs;
  Map<String, int> _downloadedVersions = {};
  final Set<String> _busyPackIds = {};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _errorMessage = null;
    });

    final remoteIndex = await fetchRemoteIndex();
    if (!mounted) return;

    if (remoteIndex == null) {
      setState(() {
        _errorMessage = 'No se pudo conectar. Intenta de nuevo.';
      });
      return;
    }

    final downloadedVersions = await getDownloadedPackVersions();
    if (!mounted) return;
    setState(() {
      _packs = remoteIndex;
      _downloadedVersions = downloadedVersions;
    });
  }

  Future<void> _download(PackMetadata pack) async {
    setState(() => _busyPackIds.add(pack.id));
    try {
      await downloadPack(pack);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo descargar ${pack.name}')),
        );
      }
    }
    await _refreshDownloadedState(pack.id);
  }

  Future<void> _confirmDelete(PackMetadata pack) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminar ${pack.name}'),
        content: const Text(
          'Se borrará el pack descargado. Podrás volver a descargarlo cuando quieras.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _delete(pack);
  }

  Future<void> _delete(PackMetadata pack) async {
    setState(() => _busyPackIds.add(pack.id));
    await deletePack(pack);
    await _refreshDownloadedState(pack.id);
  }

  Future<void> _refreshDownloadedState(String packId) async {
    final downloadedVersions = await getDownloadedPackVersions();
    if (!mounted) return;
    setState(() {
      _downloadedVersions = downloadedVersions;
      _busyPackIds.remove(packId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrar packs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      drawer: const AppDrawer(currentScreen: AppScreen.packs),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage!),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    final packs = _packs;
    if (packs == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (packs.isEmpty) {
      return const Center(child: Text('No hay packs disponibles por ahora.'));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: packs.length,
        itemBuilder: (context, index) => _buildPackTile(packs[index]),
      ),
    );
  }

  Widget _buildPackTile(PackMetadata pack) {
    final downloadedVersion = _downloadedVersions[pack.id];
    final isDownloaded = downloadedVersion != null;
    final hasUpdate = isDownloaded && downloadedVersion < pack.version;
    final isBusy = _busyPackIds.contains(pack.id);

    String subtitle = '${pack.wordCount} palabras';
    if (hasUpdate) {
      subtitle += ' · Actualización disponible';
    } else if (isDownloaded) {
      subtitle += ' · Descargado';
    }

    Widget trailing;
    if (isBusy) {
      trailing = const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (!isDownloaded || hasUpdate) {
      trailing = IconButton(
        icon: const Icon(Icons.download),
        tooltip: 'Descargar',
        onPressed: () => _download(pack),
      );
    } else {
      trailing = IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Eliminar',
        onPressed: () => _confirmDelete(pack),
      );
    }

    return Card(
      child: ListTile(
        title: Text(pack.name),
        subtitle: Text(subtitle),
        trailing: trailing,
      ),
    );
  }
}
