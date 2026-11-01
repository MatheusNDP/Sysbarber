import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// De onde vem a foto de perfil do barbeiro (regra de negócio 22).
enum OrigemDaFoto { camera, galeria }

/// Abre a câmera ou a galeria e devolve a foto escolhida, ou `null` se a
/// pessoa desistiu.
typedef EscolherFoto = Future<Uint8List?> Function(OrigemDaFoto origem);

/// Abre a câmera do aparelho (a frontal, quando o app de câmera aceita a
/// preferência) ou o seletor de fotos do sistema, que no Android 13 ou mais
/// novo não pede permissão de acesso às fotos.
///
/// A foto volta reduzida a no máximo 512 × 512 pixels e comprimida em JPEG
/// (PNG, se tiver transparência), bem abaixo do limite que o banco aceita.
/// A tela a centraliza no círculo, sem recorte.
Future<Uint8List?> escolherFotoDoAparelho(OrigemDaFoto origem) async {
  final arquivo = await ImagePicker().pickImage(
    source: origem == OrigemDaFoto.camera
        ? ImageSource.camera
        : ImageSource.gallery,
    maxWidth: 512,
    maxHeight: 512,
    imageQuality: 85,
    preferredCameraDevice: CameraDevice.front,
    requestFullMetadata: false,
  );
  return arquivo?.readAsBytes();
}
