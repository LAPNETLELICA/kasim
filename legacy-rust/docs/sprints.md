# Sprint Planning

## Sprint 1
- **Goal**: Basic agent functionality on Linux VM
- **Tasks**:
  - Implement Rust agent with nftables rules
  - Test agent on exam-linux VM only (Ubuntu 22.04 LTS)
  - NEVER test on host Kali machine
  - Basic LOCK/UNLOCK via RTDB
  - Verify firewall rules application/removal

## Sprint 2
- **Goal**: Lecturer Console with service selector
- **Tasks**:
  - Flutter Console runs on host Kali machine
  - Implement ServiceSelectorWidget with Africa-focused search engines
  - Integrate selectedServicesProvider with SessionController
  - Push allowedHosts[] to RTDB and Firestore
  - Test end-to-end: Console on host → Agent on VM