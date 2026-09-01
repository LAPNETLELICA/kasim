import time
import json
import urllib.request
import sys
from policy_cache import load_cached_policy
from process_monitor import list_running_processes_windows, terminate_process

def evaluate_process(policy: dict, exe_name: str) -> tuple:
    exe_lower = exe_name.lower()
    
    # 1. Desktop AI Applications
    for ai in policy.get("registered_ai", []):
        for d_exe in ai.get("desktop_executables", []):
            if d_exe.lower() == exe_lower:
                if d_exe in policy.get("allowed_desktop_apps", []):
                    return ("ALLOW", ai["name"])
                return ("DENY_DESKTOP_AI", f"{ai['name']} Desktop ({d_exe})")
                
    # 2. Browsers
    matched_browser = None
    for b in policy.get("registered_browsers", []):
        for b_exe in b.get("executables", []):
            if b_exe.lower() == exe_lower:
                matched_browser = b
                break
        if matched_browser:
            break
            
    if matched_browser:
        b_id = matched_browser["id"]
        if policy.get("browser_mode") == "ALLOW_ANY" or b_id in policy.get("allowed_browsers", []):
            return ("ALLOW", matched_browser["name"])
        return ("DENY_UNAUTHORIZED_BROWSER", matched_browser["name"])
        
    return ("ALLOW", exe_name)

def report_violation(server_url: str, session_id: str, student_name: str, v_type: str, resource_name: str, details: str):
    try:
        url = f"{server_url}/api/audit/violations"
        payload = json.dumps({
            "student_session_id": session_id,
            "student_name": student_name,
            "device_id": "Windows Native Guard Service",
            "violation_type": v_type,
            "resource_name": resource_name,
            "action_taken": "TERMINATED",
            "details": details
        }).encode('utf-8')
        req = urllib.request.Request(url, data=payload, headers={"Content-Type": "application/json"})
        urllib.request.urlopen(req, timeout=3)
    except Exception:
        pass

def run_supervisor_loop(server_url: str = "http://localhost:8000"):
    print("[Agent Guard] Background Security Supervisor active. Enforcing Default-Deny engine...")
    while True:
        policy = load_cached_policy()
        if policy and sys.platform == "win32":
            running = list_running_processes_windows()
            for proc in running:
                action, res_name = evaluate_process(policy, proc)
                if action.startswith("DENY"):
                    print(f"[Agent Guard] Default-Deny Triggered! Terminating unauthorized process '{proc}' ({res_name})")
                    terminate_process(proc)
                    report_violation(
                        server_url,
                        session_id="local_active",
                        student_name="Student Client",
                        v_type=action,
                        resource_name=res_name,
                        details=f"Process '{proc}' terminated by background security guard."
                    )
        time.sleep(1.5)

if __name__ == "__main__":
    run_supervisor_loop()
