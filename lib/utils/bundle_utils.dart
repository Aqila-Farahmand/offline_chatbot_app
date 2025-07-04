import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class BundleUtils {
  /// Get the path to the bundled llama-cli executable
  static Future<String> getLlamaCli() async {
    if (Platform.isMacOS) {
      final appSupport = await getApplicationSupportDirectory();
      final llamaDir = Directory('${appSupport.path}/llama');
      final llamaCliPath = '${llamaDir.path}/llama-cli';

      // Create directory if it doesn't exist
      if (!await llamaDir.exists()) {
        await llamaDir.create(recursive: true);
      }

      // Copy llama-cli from bundle to app support if it doesn't exist
      final llamaCli = File(llamaCliPath);
      if (!await llamaCli.exists()) {
        final bundle = Directory(Platform.resolvedExecutable).parent;
        final bundledLlamaCli = File(
          '${bundle.path}/Resources/llama/llama-cli',
        );

        if (await bundledLlamaCli.exists()) {
          await bundledLlamaCli.copy(llamaCliPath);
          // Make the copied file executable
          await Process.run('chmod', ['+x', llamaCliPath]);
        } else {
          throw Exception(
            'Bundled llama-cli not found at ${bundledLlamaCli.path}',
          );
        }
      }

      return llamaCliPath;
    }

    throw UnsupportedError('Platform not supported');
  }

  /// Get the path to store models
  static Future<String> getModelsDirectory() async {
    final appSupport = await getApplicationSupportDirectory();
    final modelsDir = Directory('${appSupport.path}/models');

    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }

    return modelsDir.path;
  }

  /// Get the path for temporary files
  static Future<String> getTempDirectory() async {
    final appSupport = await getApplicationSupportDirectory();
    final tempDir = Directory('${appSupport.path}/temp');

    if (!await tempDir.exists()) {
      await tempDir.create(recursive: true);
    }

    return tempDir.path;
  }
}
