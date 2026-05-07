# ExamGuard v2

## CRITICAL: Agent Testing — Always Use a VM

⚠ **NEVER** run `cargo run` or install the examguard-agent binary directly on the host Kali machine. Doing so will apply nftables/WFP DROP rules to the host's own network interfaces and will cut off internet access on your development machine. Always use a VM.

### Testing Environment Setup

The ExamGuard Agent must be tested exclusively inside Virtual Machines (NEVER on the host Kali machine). The Flutter Lecturer Console runs directly on the host Kali machine.

#### Network Architecture for Local Testing

```
Host Kali (192.168.56.1)    ←→    Firebase Emulator (localhost:9000)
       ↑                                    ↑
       |  Host-Only Network                 | NAT (internet)
       ↓                                    ↓
exam-linux VM (192.168.56.101)    exam-win VM (192.168.56.102)
```

Each VM's agent config.toml must point to:
- `database_url = "http://192.168.56.1:9000"` (Firebase RTDB emulator on host)
- `functions_url = "http://192.168.56.1:5001"` (Functions emulator on host)

#### VMs Setup
- **exam-linux**: Ubuntu 22.04 LTS VM — tests nftables Linux agent
- **exam-win**: Windows 11 VM — tests WFP Windows agent
- Both VMs use VirtualBox with:
  - Adapter 1: NAT (outbound internet via host)
  - Adapter 2: Host-Only (192.168.56.x — host-VM communication)

#### Step-by-Step Local E2E Test Procedure

1. **On host Kali**:
   ```bash
   cd ~/examguard
   firebase emulators:start --host 0.0.0.0
   # Emulator UI: http://localhost:4000
   ```

2. **On host Kali (new terminal)**:
   ```bash
   cd ~/examguard/console
   flutter run -d chrome --dart-define=USE_EMULATOR=true
   # Console opens at http://localhost:5000
   ```

3. **On exam-linux VM**:
   ```bash
   sudo systemctl start examguard-agent
   sudo systemctl status examguard-agent
   # Should show: active (running), connected to emulator
   ```

4. **On host Kali Console (browser)**:
   - Log in → Create session → Select allowed services
   - Click LOCK

5. **On exam-linux VM, verify**:
   ```bash
   curl -I https://www.google.com --max-time 5
   # Expected: timeout (BLOCKED)
   curl -I https://gemini.google.com --max-time 10
   # Expected: HTTP/2 200 (ALLOWED — if Gemini was selected)
   sudo nft list table ip examguard
   # Expected: shows examguard table with DROP policy + ACCEPT rules
   ```

6. **On host Kali Console**:
   - Click UNLOCK

7. **On exam-linux VM, verify**:
   ```bash
   curl -I https://www.google.com --max-time 5
   # Expected: HTTP/2 200 (internet restored)
   sudo nft list tables
   # Expected: examguard table is GONE
   ```

### Safety Rules
- HOST MACHINE (Kali Linux): Retain full internet access at ALL times. Do NOT install agent.
- VIRTUAL MACHINES: Agent installed INSIDE VMs only.
- LOCK/UNLOCK commands originate from Console on HOST and reach VMs via Firebase Emulator over NAT adapter.

## Project Structure and File Contents

This section explains the contents and purpose of each file in the ExamGuard v2 project.

### Flutter Console (lib/)

#### lib/models/allowed_service.dart
- Defines the `AllowedService` data model using Freezed
- Represents a service that can be allowed during exams (e.g., Google Search, ChatGPT)
- Fields: id, name, category, hosts (list of domains), iconAsset, isSelected
- Includes JSON serialization methods for Firestore persistence

#### lib/repositories/allowed_services_repository.dart
- Static repository containing the curated list of all allowed services
- Organized by categories: Search Engines, AI Tools, Reference & Academic, Educational Platforms, Cloud Storage, Communication
- Each service includes all necessary domains/sub-domains for proper functionality
- Returns `List<AllowedService>` with all predefined services

#### lib/providers/selected_services_provider.dart
- Riverpod StateNotifierProvider for managing service selection state
- `SelectedServicesNotifier` class handles:
  - Toggling individual services on/off
  - Selecting/deselecting all services in a category
  - Adding custom domains manually
  - Computing the flat list of allowed hosts (selected + always-allowed Firebase endpoints)
- Always-allowed hosts: accounts.google.com, firebaseio.com, googleapis.com

#### lib/widgets/service_selector_widget.dart
- Main UI widget for the service selector interface
- Two-panel layout: service list on left, selected summary on right
- Features:
  - Search/filter bar for finding services
  - Category grouping with "Select All" toggles
  - Checkboxes for individual service selection
  - Custom domain input field
  - Chips display showing all allowed domains
- Uses Riverpod to consume and update selection state

#### lib/controllers/session_controller.dart
- Business logic controller for exam session management
- `activateLock()`: Reads selected services, builds allowedHosts array, updates Firestore and RTDB
- `deactivateLock()`: Sends UNLOCK command to agents
- Integrates with Firebase Firestore and Realtime Database

### Agent Configuration (agent/)

#### agent/config-linux.toml
- Configuration file for the Rust agent running on Ubuntu VM
- Points to Firebase emulator on host machine (192.168.56.1)
- Unique agent_id: exam-linux-001
- Development environment (disables SSL for local testing)

#### agent/config-win.toml
- Configuration file for the Rust agent running on Windows VM
- Points to Firebase emulator on host machine (192.168.56.1)
- Unique agent_id: exam-win-001
- Development environment (disables SSL for local testing)

### Documentation (docs/)

#### docs/sprints.md
- Sprint planning documentation
- Sprint 1: Agent development and testing on Linux VM only
- Sprint 2: Console development with service selector UI

#### docs/threat_model.md
- Security threat analysis
- Mitigation strategies for exam integrity threats
- Focus on preventing unauthorized internet access during lockdown