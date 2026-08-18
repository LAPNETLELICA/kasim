# Kasim Exam Platform - Deployment & Student App Packaging Guide

This guide details the procedure for compiling and deploying the **Kasim Student Desktop Client** for exam day distribution.

---

## 1. Directory Layout & Frontend Structure

The frontend application code is organized under `frontend/`:
```
kasim/
├── backend/
│   ├── run.bat                          # Automated backend startup script
│   └── ...
├── frontend/
│   ├── lecturer/                        # Flutter Web App for Teachers
│   │   ├── run.bat                      # Web app launch script (Chrome)
│   │   └── ...
│   └── student/                         # Flutter Windows Desktop Client
│       ├── run.bat                      # Windows dev mode launch script
│       ├── build_release.bat            # Release build automation script
│       ├── installer_setup.iss          # Inno Setup installer script
│       └── ...
└── docs/
    ├── ARCHITECTURE.md                  # System architecture manual
    └── DEPLOYMENT_GUIDE.md              # Build & release documentation
```

---

## 2. Compiling Production Release Build

To build the release-ready Windows executable:

```powershell
cd frontend/student
flutter build windows --release
```
*Alternatively, double-click `frontend/student/build_release.bat`.*

### Release Output Directory
The compiled binary and required Windows DLLs are located at:
```
frontend/student/build/windows/x64/runner/Release/
```

Files generated in the `Release/` directory:
- `kasim_student.exe` (Main application executable)
- `flutter_windows.dll` (Flutter engine dynamic link library)
- `data/` (Application assets, font dependencies, and ICUs)

---

## 3. Exam Day Student Laptop Deployment Strategies

Choose one of the two deployment strategies below for distributing the client to student laptops:

### Strategy A: Portable ZIP Package (No Installation Required)

Suitable for USB drive distribution or direct link download where administrative installation rights are restricted.

1. **Build the release executable:**
   ```powershell
   cd frontend/student
   flutter build windows --release
   ```
2. **Compress the output directory:**
   - Zip the entire contents of `build/windows/x64/runner/Release/` into `ExamGuard_Student_Portable.zip`.
3. **Student Execution:**
   - Students extract `ExamGuard_Student_Portable.zip` on their laptops and double-click `kasim_student.exe`.

---

### Strategy B: Installer Package (`ExamGuard_Student_Setup.exe`)

Provides a single executable setup wizard with desktop shortcuts and automatic installation into `Program Files`.

1. **Install Inno Setup 6+** on the build workstation: [Inno Setup Download](https://jrsoftware.org/isdl.php).
2. **Build release binary:**
   ```powershell
   cd frontend/student
   flutter build windows --release
   ```
3. **Compile Installer:**
   - Open `frontend/student/installer_setup.iss` in Inno Setup Compiler and click **Compile** (or run `ISCC installer_setup.iss` from terminal).
4. **Output Installer:**
   - The compiled installer `ExamGuard_Student_Setup.exe` is generated inside `frontend/student/Output/`.
5. **Student Installation:**
   - Distribute `ExamGuard_Student_Setup.exe`. Students run the setup wizard to install the application.
