import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/vocabulary_repository.dart' show packsDirectoryName;

/// URL raw de GitHub donde viven los packs de vocabulario publicados.
/// Al hacer commit de un nuevo pack en `content/packs/` de este repo,
/// queda disponible aquí sin necesidad de un backend.
const _indexUrl =
    'https://raw.githubusercontent.com/Fvargas17/Widget-VocIng/main/widget_vocing/content/packs/index.json';

const _downloadedPacksPrefsKey = 'downloaded_pack_versions';
const _fetchTimeout = Duration(seconds: 5);

/// Permite a los tests de widgets desactivar por completo las llamadas de
/// red reales: los tests no deben depender de la disponibilidad o latencia
/// de una red real (ver `test/widget_test.dart`).
@visibleForTesting
bool debugDisableNetworkChecks = false;

/// `Future.timeout()` no cancela la conexión TCP subyacente: sin esto, una
/// red inalcanzable deja el socket intentando conectar en segundo plano.
/// `HttpClient.connectionTimeout` sí aborta el socket a nivel de sistema.
http.Client _createClient() {
  final httpClient = HttpClient()..connectionTimeout = _fetchTimeout;
  return IOClient(httpClient);
}

class PackMetadata {
  const PackMetadata({
    required this.id,
    required this.name,
    required this.version,
    required this.wordCount,
    required this.file,
  });

  final String id;
  final String name;
  final int version;
  final int wordCount;
  final String file;

  factory PackMetadata.fromJson(Map<String, dynamic> json) {
    return PackMetadata(
      id: json['id'] as String,
      name: json['name'] as String,
      version: json['version'] as int,
      wordCount: json['wordCount'] as int,
      file: json['file'] as String,
    );
  }
}

/// Consulta el índice remoto de packs disponibles.
/// Retorna `null` si no hay conexión o la consulta falla, sin lanzar errores.
Future<List<PackMetadata>?> fetchRemoteIndex() async {
  if (debugDisableNetworkChecks) return null;

  final client = _createClient();
  try {
    final response =
        await client.get(Uri.parse(_indexUrl)).timeout(_fetchTimeout);
    if (response.statusCode != 200) return null;
    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded
        .map((item) => PackMetadata.fromJson(item as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return null;
  } finally {
    client.close();
  }
}

Future<Map<String, int>> _getDownloadedPackVersions() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_downloadedPacksPrefsKey);
  if (raw == null) return {};
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  return decoded.map((key, value) => MapEntry(key, value as int));
}

Future<void> _markPackDownloaded(String packId, int version) async {
  final prefs = await SharedPreferences.getInstance();
  final current = await _getDownloadedPackVersions();
  current[packId] = version;
  await prefs.setString(_downloadedPacksPrefsKey, jsonEncode(current));
}

/// Compara el índice remoto contra los packs ya descargados y retorna
/// los packs nuevos o con una versión más reciente que la local.
Future<List<PackMetadata>> checkForNewPacks() async {
  final remoteIndex = await fetchRemoteIndex();
  if (remoteIndex == null) return const [];

  final downloadedVersions = await _getDownloadedPackVersions();
  return remoteIndex.where((pack) {
    final downloadedVersion = downloadedVersions[pack.id];
    return downloadedVersion == null || downloadedVersion < pack.version;
  }).toList();
}

/// Descarga el archivo de un pack y lo guarda en el directorio de documentos
/// de la app, luego registra la versión descargada.
Future<void> downloadPack(PackMetadata pack) async {
  final baseUrl = _indexUrl.substring(0, _indexUrl.lastIndexOf('/') + 1);
  final client = _createClient();
  final http.Response response;
  try {
    response = await client
        .get(Uri.parse('$baseUrl${pack.file}'))
        .timeout(_fetchTimeout);
  } finally {
    client.close();
  }
  if (response.statusCode != 200) {
    throw HttpException('No se pudo descargar el pack ${pack.id}');
  }

  final documentsDir = await getApplicationDocumentsDirectory();
  final packsDir = Directory('${documentsDir.path}/$packsDirectoryName');
  if (!await packsDir.exists()) {
    await packsDir.create(recursive: true);
  }

  final file = File('${packsDir.path}/${pack.file}');
  await file.writeAsString(response.body);

  await _markPackDownloaded(pack.id, pack.version);
}
