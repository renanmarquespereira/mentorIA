#!/usr/bin/env bash
set -euo pipefail

API_URL="${MENTORIA_API_URL:-https://mentoria-adeh.onrender.com/api/v1}"
FLUTTER_DIR="${HOME}/flutter"

echo "== Mentoria AI - Cloudflare Web Build =="
echo "API: ${API_URL}"

if [ ! -x "${FLUTTER_DIR}/bin/flutter" ]; then
  echo "Instalando Flutter stable no ambiente de build..."
  git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "${FLUTTER_DIR}"
fi

export PATH="${FLUTTER_DIR}/bin:${PATH}"
flutter --version
flutter config --enable-web

# O app teve uma versao com URL LAN fixa. A substituicao abaixo ocorre somente
# no checkout temporario do Cloudflare e garante que o Web use a API publica.
while IFS= read -r -d '' file; do
  sed -i "s#http://192\.168\.18\.161:8001/api/v1#${API_URL}#g" "$file"
done < <(find mobile/lib -type f -name '*.dart' -print0)

cd mobile
flutter pub get
flutter build web --release --dart-define="MENTORIA_API_URL=${API_URL}"

test -f build/web/index.html
test -f build/web/main.dart.js

echo "Build Web concluido: mobile/build/web"
