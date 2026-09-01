import os
import sys
import subprocess
from typing import List, Tuple

def list_running_processes_windows() -> List[str]:
    processes = []
    try:
        output = subprocess.check_output(['tasklist', '/FO', 'CSV', '/NH'], text=True, errors='ignore')
        for line in output.strip().splitlines():
            parts = line.split(',')
            if parts:
                exe = parts[0].strip('"').strip()
                if exe:
                    processes.append(exe.lower())
    except Exception:
        pass
    return processes

def terminate_process(exe_name: str) -> bool:
    try:
        if sys.platform == "win32":
            subprocess.run(['taskkill', '/F', '/IM', exe_name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        else:
            subprocess.run(['pkill', '-f', exe_name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True
    except Exception:
        return False
