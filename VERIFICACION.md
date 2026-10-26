# Verificación de la copia

Fecha: 26 de octubre de 2026.

Traslado a `D:\onate\audiomack`: se volvieron a ejecutar correctamente
`preparar.ps1`, `flutter analyze --no-pub` y `flutter test --no-pub` desde esta
carpeta. Se verificó por SHA-256 que código, dependencias, imágenes y configuración
Firebase coinciden con la copia ya probada. Los binarios y capturas de las pruebas
previas se copiaron completos; las compilaciones de la tabla se realizaron antes
del traslado, en la carpeta de trabajo `sofia`.

## Origen y conexiones

- Original: `D:\onate\s_onate`, sin cambios al terminar.
- Copia: `D:\onate\audiomack`.
- Commit de origen: `e08a7e8`.
- Se copió el contenido de `s_onate`; no se copiaron los proyectos vecinos de `D:\onate`.
- Se conservó el historial de Git. Rama local: `main`.
- Remoto: `git@github.com:sofiwi003/onate.git`; `git fetch origin main` funcionó por SSH.
- Firebase existente: `audiomack26pm`, proyecto activo accesible con la sesión local.
- Los identificadores y la configuración original de Firebase se conservaron.
- Hay 69 paquetes resueltos y `pubspec.lock` coincide con el original.
- Los cachés y archivos de compilación se regeneraron para la nueva ubicación.
- Las correcciones quedan locales, sin commit ni publicación en GitHub.

## Resultados

| Comprobación | Resultado |
| --- | --- |
| `flutter pub get` | Correcto |
| `preparar.ps1` y análisis de sintaxis de ambos scripts | Correcto |
| `flutter analyze` | Sin incidencias |
| `flutter test` | 2 pruebas aprobadas, tamaños teléfono y escritorio |
| `flutter build web` | Correcto |
| Navegador, versión web compilada | Inicio, imágenes, pantalla Listas y validación de formulario correctos |
| Lectura de `canciones` en Firestore | Correcta en web y Windows; colección vacía |
| `flutter build windows --no-pub` | Correcto |
| Ejecución de Windows en modo release | Inicio y consulta de Firestore correctos |
| `flutter build apk --debug --no-pub` | Correcto |
| Instalación y ejecución del APK en `SOFIAONATE` | Inicio y pantalla con imágenes correctos |
| `git diff --check` | Correcto |

## Archivos generados

- Web: `build/web/`.
- Windows: `build/windows/x64/runner/Release/`, con ejecutable, DLL y datos.
- Android: `build/app/outputs/flutter-apk/app-debug.apk`.
- Capturas locales: `.dart_tool/verificacion-web.png` y `.dart_tool/verificacion-android.png`.

## Ajustes y alcance

Se corrigieron las rutas y la declaración de imágenes, el permiso de Internet de
Android y la configuración de depuración de VS Code. Las imágenes `kaleko.jpeg`
y `logo.svg` no estaban en el original; se usa su `logo.png` existente.

Se añadió `.firebaserc` apuntando al proyecto existente. Los plugins de escritorio
se prepararon con uniones de directorio, porque Windows no permite crear enlaces
simbólicos en esta sesión. `preparar.ps1` resuelve ese caso sin cambiar ajustes de Windows.

La primera compilación Android instaló las plataformas SDK 34, 35 y 36 y CMake
3.22.1 usando las licencias ya disponibles. El emulador inicialmente quedó negro;
el arranque en frío con SwiftShader permitió la prueba. No se borraron sus datos
ni se modificó su configuración permanente.

No se crearon, editaron ni eliminaron documentos de Firebase durante las pruebas.
No se verificó el ciclo de escritura de Firestore ni un teléfono físico.
iOS/macOS no se compilaron desde Windows; Linux no está configurado para Firebase
en el proyecto original. Los resultados anteriores verifican este equipo y estas
versiones, y no constituyen una garantía para cualquier dispositivo o plataforma.
