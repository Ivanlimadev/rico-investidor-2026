# Rico Investidor (Flutter)

## Desenvolvimento

**Recomendado no Mac:** app desktop (`flutter run -d macos`). Suba o backend **antes** de abrir o app.

API local (debug):

- iOS/macOS: `http://127.0.0.1:8000`
- Web (Chrome): `http://127.0.0.1:8000` (exige backend com CORS; reinicie o uvicorn após mudanças)
- Android emulador: `http://10.0.2.2:8000`

```bash
cd mobile
flutter pub get
flutter run -d macos
```

## Build de produção

Release **exige** URL HTTPS da API:

```bash
flutter build apk --dart-define=API_BASE_URL=https://api.seudominio.com
flutter build ios --dart-define=API_BASE_URL=https://api.seudominio.com
```

Sem `API_BASE_URL`, o app falha no startup em modo release (`ApiConfigError`).
