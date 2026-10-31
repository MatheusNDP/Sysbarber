import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:sysbarber/services/lembretes.dart';
import 'package:sysbarber/theme/app_theme.dart';

/// Testes da identidade do app no Android: o ícone, o nome e a tela nativa
/// que aparece antes da abertura. Conferem os recursos em `android/`.
void main() {
  const res = 'android/app/src/main/res';

  String ler(String caminho) => File(caminho).readAsStringSync();

  /// Cor no formato do Android (`#RRGGBB`).
  String hex(Color cor) =>
      '#${(cor.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  /// Valor da cor [nome] em `values/colors.xml`.
  String corDoAndroid(String nome) =>
      RegExp('<color name="$nome">(#[0-9A-Fa-f]{6})</color>')
          .firstMatch(ler('$res/values/colors.xml'))!
          .group(1)!
          .toUpperCase();

  test('as cores do Android são as mesmas do app', () {
    expect(corDoAndroid('grafite'), hex(AppColors.background));
    expect(corDoAndroid('amarelo'), hex(AppColors.amarelo));
  });

  test('a tela nativa da abertura é só o grafite, sem o branco e sem o '
      'ícone', () {
    expect(
      ler('$res/drawable/launch_background.xml'),
      contains('@color/grafite'),
    );
    expect(Directory('$res/drawable-v21').existsSync(), isFalse);
    final estilos = ler('$res/values/styles.xml');
    expect(estilos, isNot(contains('Theme.Light')));
    expect(Directory('$res/values-night').existsSync(), isFalse);

    // Do Android 12 em diante, a tela de abertura do sistema.
    final android12 = ler('$res/values-v31/styles.xml');
    expect(
      android12,
      contains(
        '<item name="android:windowSplashScreenBackground">'
        '@color/grafite</item>',
      ),
    );
    expect(
      android12,
      contains(
        '<item name="android:windowSplashScreenAnimatedIcon">'
        '@android:color/transparent</item>',
      ),
    );
  });

  test('o nome do app no Android é "SysBarber"', () {
    expect(
      ler('android/app/src/main/AndroidManifest.xml'),
      contains('android:label="SysBarber"'),
    );
  });

  test('o ícone do app é o círculo amarelo com a tesoura, sobre o '
      'grafite', () {
    final adaptativo = ler('$res/mipmap-anydpi-v26/ic_launcher.xml');
    expect(
      adaptativo,
      contains('<background android:drawable="@color/grafite"'),
    );
    expect(adaptativo, contains('@drawable/ic_launcher_foreground'));
    expect(adaptativo, contains('@drawable/ic_launcher_monochrome'));
    expect(
      ler('$res/drawable/ic_launcher_foreground.xml'),
      contains('android:fillColor="@color/amarelo"'),
    );
  });

  test('as notificações usam a tesoura como ícone, mantida no APK '
      'release', () {
    const icone = LembretesLocais.icone;
    expect(icone, isNot(contains('ic_launcher')));
    expect(File('$res/drawable/$icone.xml').existsSync(), isTrue);
    // Citado só pelo nome no Dart, o ícone precisa estar no keep.xml.
    expect(ler('$res/raw/keep.xml'), contains('@drawable/$icone'));
    expect(LembretesLocais.cor, AppColors.amarelo);
  });
}
