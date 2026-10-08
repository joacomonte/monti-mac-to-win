# Monti Mac2Win

Pasá archivos y textos de tu **Mac** a tu **Windows** (o cualquier compu) por la red de tu casa. Sin cables, sin pendrive, sin subir nada a internet.

## ¿Cómo funciona?

1. En la Mac, arrastrás archivos (o escribís un texto) en el ícono ⇅ de la barra de arriba.
2. En la Windows, abrís el navegador y entrás a la dirección que te muestra la app (ej: `http://192.168.0.105:8000`).
3. Ahí ves todo y lo descargás o copiás.

> Las dos compus tienen que estar en el **mismo Wi-Fi**.

## Instalar

1. Bajá el `.zip` de la última versión en [**Releases**](https://github.com/joacomonte/monti-mac-to-win/releases) (a la derecha de esta página).
2. Descomprimilo y mové **Monti Mac2Win** a la carpeta **Aplicaciones**.
3. La primera vez, macOS la bloquea porque no viene de la App Store. Abrí la Terminal y pegá:

   ```bash
   xattr -dr com.apple.quarantine "/Applications/Monti Mac2Win.app"
   ```

4. Abrila. Si pregunta si puede aceptar conexiones, poné **Permitir**.

Necesita macOS 14 o más nuevo.

## Para desarrolladores

```bash
./build.sh            # compila y arma "Monti Mac2Win.app"
./release.sh 1.1.0    # publica una versión nueva en Releases
```
