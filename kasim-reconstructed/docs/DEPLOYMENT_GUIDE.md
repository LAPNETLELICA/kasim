# Deployment and release guide

## API

1. Provision PostgreSQL and durable private storage for submissions/camera data.
2. Set every value described in `backend/.env.example`; use different random
   values for JWT and policy signing.
3. Restrict CORS to the lecturer origin and expose the API only over HTTPS.
4. Install `backend/requirements.txt`, run managed migrations, and launch with a
   production ASGI process manager.
5. Configure backups and retention/deletion jobs for submissions and camera
   frames.

## Lecturer web build

```powershell
cd lecturer
flutter pub get
flutter build web --release `
  --dart-define=GOOGLE_CLIENT_ID=YOUR_CLIENT_ID.apps.googleusercontent.com `
  --dart-define=KASIM_API_URL=https://api.example.edu/api
```

Deploy `lecturer/build/web/` on the institution's HTTPS origin. Register that
origin in the Google OAuth web client and set the same client ID on the API.

## Student Windows build

The Windows camera implementation requires Flutter 3.19/Dart 3.3 or newer.

```powershell
cd student
flutter pub get
flutter build windows --release `
  --dart-define=KASIM_API_URL=https://api.example.edu/api
```

The output is under `student/build/windows/x64/runner/Release/`. Distribute the
entire directory, not just the executable. Compile `student/installer_setup.iss`
with Inno Setup to produce the installer.

Before distribution:

- set `KASIM_API_URL` to the production HTTPS API at build time;
- code-sign the executable and installer;
- verify camera permission and periodic frame upload on the exact Windows image;
- test every lecturer-entered browser executable and its managed-policy adapter;
- install any privileged guard/service through the institution's endpoint
  management platform;
- run a pilot exam covering join, launch, countdown, interruption, upload,
  student finish, lecturer stop, ZIP export, and automatic expiry.

## Portable package

For a portable release, ZIP the complete Windows `Release` directory. Students
extract it and run `kasim_student.exe`. Portable mode is lower assurance because
it cannot reliably install privileged enforcement controls.
