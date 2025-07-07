import 'dart:io';
import 'package:path_provider/path_provider.dart';

class BundleUtils {
  /// Get the path to the bundled llama-cli executable
  static Future<String> getLlamaCli() async {
    if (Platform.isMacOS) {
      final appSupport = await getApplicationSupportDirectory();
      final llamaDir = Directory('${appSupport.path}/llama');
      final llamaCliPath = '${llamaDir.path}/llama-cli';

      print('Checking llama-cli at: $llamaCliPath');

      // Create directory if it doesn't exist
      if (!await llamaDir.exists()) {
        print('Creating llama directory: ${llamaDir.path}');
        await llamaDir.create(recursive: true);
      }

      // First preference: use the executable inside the app bundle (already
      // signed correctly). This avoids Gatekeeper rejecting a copy in the
      // sandbox.
      final bundleRoot = Directory(Platform.resolvedExecutable).parent.parent;
      final bundledLlamaCliPath =
          '${bundleRoot.path}/Resources/llama/llama-cli';
      if (await File(bundledLlamaCliPath).exists()) {
        print('Using bundled llama-cli at: $bundledLlamaCliPath');
        return bundledLlamaCliPath;
      }

      // Fallback: copy into Application Support if the bundle copy was not
      // found (e.g. during development hot-reload on macOS Catalyst).

      // Copy llama-cli from bundle to app support if it doesn't exist
      final llamaCli = File(llamaCliPath);
      if (!await llamaCli.exists()) {
        print('llama-cli not found in app support, copying from bundle...');
        final bundle = Directory(Platform.resolvedExecutable).parent.parent;
        final bundledLlamaCli = File(
          '${bundle.path}/Resources/llama/llama-cli',
        );

        print('Looking for bundled llama-cli at: ${bundledLlamaCli.path}');
        if (await bundledLlamaCli.exists()) {
          print('Found bundled llama-cli, copying to app support...');
          await bundledLlamaCli.copy(llamaCliPath);

          // Remove quarantine and ad-hoc sign
          await _postCopyFixes(llamaCliPath);

          // Always ensure required dynamic libraries exist in Application Support
          const requiredLibs = [
            'libllama.dylib',
            'libggml.dylib',
            'libggml-cpu.dylib',
            'libggml-blas.dylib',
            'libggml-metal.dylib',
            'libggml-base.dylib',
          ];

          final libDir = Directory('${appSupport.path}/lib');
          if (!await libDir.exists()) {
            await libDir.create(recursive: true);
          }

          for (final libName in requiredLibs) {
            final appLibPath = '${libDir.path}/$libName';
            final appLibFile = File(appLibPath);
            if (!await appLibFile.exists()) {
              final bundleLibPath =
                  '${Directory(Platform.resolvedExecutable).parent.parent.path}/Resources/lib/$libName';
              final bundleLibFile = File(bundleLibPath);
              if (await bundleLibFile.exists()) {
                print('Copying $libName from bundle to app support...');
                await bundleLibFile.copy(appLibPath);
                await _postCopyFixes(appLibPath);
              } else {
                print('Warning: bundled $libName not found at $bundleLibPath');
              }
            }
          }

          // Make the copied file executable
          final result = await Process.run('chmod', ['+x', llamaCliPath]);
          if (result.exitCode != 0) {
            throw Exception(
              'Failed to make llama-cli executable: ${result.stderr}',
            );
          }
          print('Successfully copied and made executable: $llamaCliPath');
        } else {
          throw Exception(
            'Bundled llama-cli not found at ${bundledLlamaCli.path}. '
            'Please ensure the llama-cli is properly bundled with the application.',
          );
        }
      } else {
        print('Found existing llama-cli at: $llamaCliPath');
      }

      // Ensure libllama.dylib exists (in case llama-cli already existed earlier)
      const requiredLibsPost = [
        'libllama.dylib',
        'libggml.dylib',
        'libggml-cpu.dylib',
        'libggml-blas.dylib',
        'libggml-metal.dylib',
        'libggml-base.dylib',
      ];

      final libDir2 = Directory('${appSupport.path}/lib');
      if (!await libDir2.exists()) {
        await libDir2.create(recursive: true);
      }

      for (final libName in requiredLibsPost) {
        final appLibPath = '${libDir2.path}/$libName';
        final appLibFile = File(appLibPath);
        if (!await appLibFile.exists()) {
          final bundleLibPath =
              '${Directory(Platform.resolvedExecutable).parent.parent.path}/Resources/lib/$libName';
          final bundleLibFile = File(bundleLibPath);
          if (await bundleLibFile.exists()) {
            print('$libName missing (post-check), copying from bundle...');
            await bundleLibFile.copy(appLibPath);
            await _postCopyFixes(appLibPath);
          } else {
            print('Warning: bundled $libName not found at $bundleLibPath');
          }
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

  /// After copying a binary/dylib, remove quarantine attribute and ad-hoc sign it.
  static Future<void> _postCopyFixes(String path) async {
    try {
      await Process.run('xattr', ['-d', 'com.apple.quarantine', path]);
    } catch (_) {
      // Ignore if attribute not present
    }

    // Do NOT ad-hoc sign here; the dylibs/executable were already signed in the
    // Xcode build phase. Re-signing at runtime would replace a valid signature
    // with an ad-hoc one and cause the Hardened Runtime to reject the library.
  }
}
