# BenefiSocial — Flutter UI (Part 1)

This is a runnable MVP shell:
- Supabase OAuth (GitHub/Google)
- RFH list/create/detail (+match)
- Profile view/update
- GoRouter auth guard
- API client calls your FastAPI backend

## First run
```bash
bash create_flutter_app.sh   # runs `flutter create .` if needed
flutter pub get
# Edit lib/config.dart (SUPABASE + BACKEND_BASE_URL)
flutter run -d chrome
```
Login with GitHub/Google, then try creating an RFH and viewing matches.
