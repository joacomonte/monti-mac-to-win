#!/bin/bash
# Publica una versión en GitHub Releases con el .app zipeado para descargar.
# Uso: ./release.sh 1.1.0   (antes pusheá los cambios a main)
set -euo pipefail
cd "$(dirname "$0")"
VERSION="${1:?Uso: ./release.sh 1.1.0}"

./build.sh "$VERSION"

ZIP="Monti-Mac2Win-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "Monti Mac2Win.app" "$ZIP"

gh release create "v$VERSION" "$ZIP" --target main --title "v$VERSION" \
  --notes "Descargá **$ZIP**, descomprimilo y mové la app a Aplicaciones. Ver el README para abrirla la primera vez."
rm "$ZIP"
