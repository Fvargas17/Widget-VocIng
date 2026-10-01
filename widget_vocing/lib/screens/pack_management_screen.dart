import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/language_course_service.dart';
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

  /// Se guarda el *hecho* de que falló la consulta, no el texto del error: el
  /// mensaje se resuelve en `build` para que siga el idioma activo.
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loadFailed = false;
    });

    final remoteIndex = await fetchRemoteIndex();
    final course = await getLanguageCourse();
    if (!mounted) return;

    if (remoteIndex == null) {
      setState(() {
        _loadFailed = true;
      });
      return;
    }

    final downloadedVersions = await getDownloadedPackVersions();
    if (!mounted) return;
    setState(() {
      // Solo los packs del curso activo: descargar vocabulario de otro idioma
      // no cambiaría nada de lo que el usuario ve hoy.
      _packs = remoteIndex.where((pack) => pack.course == course).toList();
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
          SnackBar(
            content: Text(AppStrings.of(context).downloadFailed(pack.name)),
          ),
        );
      }
    }
    await _refreshDownloadedState(pack.id);
  }

  Future<void> _confirmDelete(PackMetadata pack) async {
    final strings = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.deletePackTitle(pack.name)),
        content: Text(strings.deletePackBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.delete),
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
    final strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.managePacks),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: strings.refresh,
          ),
        ],
      ),
      drawer: const AppDrawer(currentScreen: AppScreen.packs),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final strings = AppStrings.of(context);
    if (_loadFailed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(strings.connectionError),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: Text(strings.retry)),
          ],
        ),
      );
    }

    final packs = _packs;
    if (packs == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (packs.isEmpty) {
      return Center(child: Text(strings.noPacksAvailable));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: packs.length,
        itemBuilder: (context, index) => _buildPackTile(context, packs[index]),
      ),
    );
  }

  Widget _buildPackTile(BuildContext context, PackMetadata pack) {
    final strings = AppStrings.of(context);
    final downloadedVersion = _downloadedVersions[pack.id];
    final isDownloaded = downloadedVersion != null;
    final hasUpdate = isDownloaded && downloadedVersion < pack.version;
    final isBusy = _busyPackIds.contains(pack.id);

    String subtitle = strings.wordCount(pack.wordCount);
    if (hasUpdate) {
      subtitle += ' · ${strings.updateAvailable}';
    } else if (isDownloaded) {
      subtitle += ' · ${strings.downloaded}';
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
        tooltip: strings.download,
        onPressed: () => _download(pack),
      );
    } else {
      trailing = IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: strings.delete,
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
