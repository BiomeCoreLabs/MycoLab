import os
import json
import time
import threading
import shutil
from datetime import datetime
from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.responses import FileResponse
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
import tinytuya

app = FastAPI(title="MycoLab 24/7 Pi Lab Hub Bridge", version="3.1.0")

DIR = os.path.dirname(os.path.abspath(__file__))
USB_PATH = "/mnt/pi-storage"

# Determine storage location (prefer USB stick if mounted to preserve SD card)
if os.path.exists(USB_PATH) and os.path.ismount(USB_PATH):
    STORAGE_DIR = os.path.join(USB_PATH, "mycolab-data")
    TIMELAPSE_DIR = os.path.join(USB_PATH, "timelapse")
    os.makedirs(STORAGE_DIR, exist_ok=True)
    os.makedirs(TIMELAPSE_DIR, exist_ok=True)
    os.makedirs(os.path.join(USB_PATH, "backups"), exist_ok=True)
else:
    STORAGE_DIR = DIR
    TIMELAPSE_DIR = os.path.join(DIR, "timelapse")
    os.makedirs(TIMELAPSE_DIR, exist_ok=True)

SCHEDULES_FILE = os.path.join(STORAGE_DIR, "schedules.json")
LOG_FILE = os.path.join(STORAGE_DIR, "hub_log.json")
DATABASE_FILE = os.path.join(STORAGE_DIR, "database.json")
BACKUPS_DIR = os.path.join(USB_PATH, "backups") if (os.path.exists(USB_PATH) and os.path.ismount(USB_PATH)) else os.path.join(STORAGE_DIR, "backups")
os.makedirs(BACKUPS_DIR, exist_ok=True)

def get_hub_ip() -> str:
    import socket
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
        s.close()
        return local_ip
    except Exception:
        return "127.0.0.1"

def load_devices() -> Dict[str, Dict[str, Any]]:
    """Loads Tuya devices dynamically from devices.json or falls back to devices.example.json."""
    custom_path = os.path.join(DIR, "devices.json")
    example_path = os.path.join(DIR, "devices.example.json")
    for p in [custom_path, example_path]:
        if os.path.exists(p):
            try:
                with open(p, "r", encoding="utf-8") as f:
                    return json.load(f)
            except Exception as e:
                print(f"Warning: could not read {p}: {e}")
    return {}

# Tuya plugs loaded dynamically from local config
DEVICES: Dict[str, Dict[str, Any]] = load_devices()

# --- Intelligent Climate Safety & Interlock State ---
CLIMATE_STATE = {
    "exhaust_lockout_until": 0.0,       # Timestamp until when exhaust fan cannot start (dwell period)
    "last_fan_off_timestamp": 0.0,      # Timestamp when fan turned OFF (fresh air baseline)
    "last_mist_off_timestamp": 0.0,     # Timestamp when humidifier turned OFF
    "latest_reading": None              # Latest sensor reading from optical meter or local sensor
}

lock = threading.RLock()  # Reentrant lock to prevent deadlocks when save_database calls add_log
hardware_lock = threading.Lock()  # Hardware socket lock to prevent socket collisions between status polls and switch commands

def load_logs() -> List[Dict[str, Any]]:
    if os.path.exists(LOG_FILE):
        try:
            with open(LOG_FILE, "r") as f:
                return json.load(f)
        except Exception:
            return []
    return []

def add_log(device_name: str, state: bool, trigger: str, method: str):
    entry = {
        "id": f"{int(time.time() * 1000)}",
        "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "device": device_name,
        "state": state,
        "trigger": trigger,
        "method": method
    }
    with lock:
        logs = load_logs()
        logs.insert(0, entry)
        logs = logs[:150]
        try:
            with open(LOG_FILE, "w") as f:
                json.dump(logs, f, indent=2)
        except Exception as e:
            print(f"Failed to write log: {e}")

def load_schedules() -> Dict[str, Any]:
    if os.path.exists(SCHEDULES_FILE):
        try:
            with open(SCHEDULES_FILE, "r") as f:
                return json.load(f)
        except Exception:
            pass
    default_scheds = []
    for d in DEVICES.values():
        dev_id = d.get("id", "")
        dev_type = d.get("type", "")
        dev_name = d.get("name", "")
        if dev_type == "Light":
            default_scheds.append({
                "device_id": dev_id,
                "name": dev_name,
                "type": "Light",
                "light_on_hour": 8,
                "light_off_hour": 20
            })
        elif dev_type in ["ExhaustFan", "Fan"]:
            default_scheds.append({
                "device_id": dev_id,
                "name": dev_name,
                "type": "ExhaustFan",
                "interval_minutes": 180,
                "duration_minutes": 5,
                "cycle_start_time": time.time()
            })
        elif dev_type == "Humidifier":
            default_scheds.append({
                "device_id": dev_id,
                "name": dev_name,
                "type": "Humidifier",
                "interval_minutes": 60,
                "duration_minutes": 3,
                "cycle_start_time": time.time()
            })

    return {
        "autopilot_enabled": True,
        "last_sync": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "schedules": default_scheds
    }

def save_schedules(sched: Dict[str, Any]):
    with lock:
        try:
            with open(SCHEDULES_FILE, "w") as f:
                json.dump(sched, f, indent=2)
        except Exception as e:
            print(f"Error saving schedules: {e}")

# MARK: - Central MycoLab Database Management (Pi as Single Source of Truth)
def load_database() -> Optional[Dict[str, Any]]:
    if os.path.exists(DATABASE_FILE):
        try:
            with open(DATABASE_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception as e:
            print(f"⚠️ [Pi DB] Fout bij openen database.json: {e}")
    return None

def rotate_backups(keep_count: int = 25):
    try:
        files = []
        for fname in os.listdir(BACKUPS_DIR):
            if fname.startswith("mycolab_db_") and fname.endswith(".json"):
                fpath = os.path.join(BACKUPS_DIR, fname)
                files.append((os.path.getmtime(fpath), fpath))
        files.sort(key=lambda x: x[0], reverse=True)
        for _, old_path in files[keep_count:]:
            try:
                os.remove(old_path)
            except Exception:
                pass
    except Exception as e:
        print(f"⚠️ [Pi DB] Fout bij opschonen backups: {e}")

def save_database(data: Dict[str, Any], client_name: str = "Client") -> Dict[str, Any]:
    with lock:
        tmp_file = DATABASE_FILE + ".tmp"
        try:
            with open(tmp_file, "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            os.replace(tmp_file, DATABASE_FILE)
            
            # Timestamped backup to USB backups directory
            ts_str = datetime.now().strftime("%Y%m%d_%H%M%S")
            backup_file = os.path.join(BACKUPS_DIR, f"mycolab_db_{ts_str}.json")
            try:
                shutil.copy2(DATABASE_FILE, backup_file)
                rotate_backups(25)
            except Exception as e:
                print(f"⚠️ [Pi DB] Backup maken mislukt: {e}")
                
            # Automatically synchronize smart devices and environment autopilot config if present
            if "smartDevices" in data or "environmentConfig" in data:
                try:
                    sync_schedules_from_db(data)
                except Exception as e:
                    print(f"⚠️ [Pi DB] Automatisch syncen van schema's uit database mislukt: {e}")
                    
            file_size = os.path.getsize(DATABASE_FILE)
            add_log("Centrale Database", True, f"Sync ontvangen van {client_name}", "REST-API")
            print(f"💾 [Pi DB] Centrale database succesvol opgeslagen ({round(file_size/1024, 1)} KB) van {client_name}")
            return {
                "success": True,
                "saved_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                "timestamp": time.time(),
                "size_bytes": file_size,
                "backup": os.path.basename(backup_file)
            }
        except Exception as e:
            if os.path.exists(tmp_file):
                try: os.remove(tmp_file)
                except Exception: pass
            print(f"❌ [Pi DB] Opslaan database mislukt: {e}")
            raise HTTPException(status_code=500, detail=f"Opslaan mislukt: {str(e)}")

def sync_schedules_from_db(db_data: Dict[str, Any]):
    current_sched = load_schedules()
    existing_starts = {}
    for s in current_sched.get("schedules", []):
        if "device_id" in s and s.get("cycle_start_time"):
            existing_starts[str(s["device_id"]).lower()] = s["cycle_start_time"]
        if "name" in s and s.get("cycle_start_time"):
            existing_starts[str(s["name"]).lower()] = s["cycle_start_time"]

    env = db_data.get("environmentConfig", {})
    autopilot_on = env.get("isAutopilotEnabled", True) if isinstance(env, dict) else True
    
    devices_list = db_data.get("smartDevices", [])
    if not isinstance(devices_list, list):
        return
        
    schedules = []
    for dev in devices_list:
        if not isinstance(dev, dict): continue
        d_type = dev.get("deviceType", "")
        if d_type == "Sensor": continue
        
        name = dev.get("name", "")
        dev_id = dev.get("tuyaDeviceID") or name
        is_light = d_type == "Light" or any(k in name.lower() for k in ["lamp", "licht", "growlight"])
        
        item = {
            "device_id": dev_id,
            "name": name,
            "type": "Light" if is_light else d_type,
            "mode": "cycle" if is_light else "interval",
            "manual_override": dev.get("isManualOverrideActive", False),
            "manual_override_state": dev.get("isOn", False)
        }
        if is_light:
            item["light_on_hour"] = dev.get("lightOnHour", 8)
            item["light_off_hour"] = dev.get("lightOffHour", 20)
        else:
            total_m = (int(dev.get("customIntervalHours") or 0) * 60) + int(dev.get("customIntervalMinutes") or 0)
            if total_m <= 0:
                total_m = int(dev.get("totalIntervalMinutes") or 180)
            item["interval_minutes"] = max(1, total_m)
            item["duration_minutes"] = max(1, int(dev.get("customDurationMinutes") or 5))
            
            # Preserve existing cycle_start_time so timers are NEVER reset when database is saved
            raw_ts = dev.get("cycle_start_time")
            if not raw_ts and str(dev_id).lower() in existing_starts:
                raw_ts = existing_starts[str(dev_id).lower()]
            elif not raw_ts and str(name).lower() in existing_starts:
                raw_ts = existing_starts[str(name).lower()]
            elif not raw_ts:
                raw_ts = dev.get("lastCustomExecutionTime")
            
            if raw_ts and float(raw_ts) > 0:
                ts_val = float(raw_ts)
                if ts_val < 1000000000.0:
                    ts_val += 978307200.0
                item["cycle_start_time"] = ts_val
            elif str(dev_id).lower() in existing_starts:
                item["cycle_start_time"] = existing_starts[str(dev_id).lower()]
            elif str(name).lower() in existing_starts:
                item["cycle_start_time"] = existing_starts[str(name).lower()]
            
        schedules.append(item)
        
    sched_data = {
        "autopilot_enabled": autopilot_on,
        "last_sync": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "schedules": schedules
    }
    save_schedules(sched_data)
    threading.Thread(target=run_autopilot_tick, daemon=True).start()

def resolve_device(identifier: str, dev_type: Optional[str] = None) -> Optional[Dict[str, Any]]:
    clean_id = (identifier or "").strip().lower()
    clean_type = (dev_type or "").strip().lower()

    # 1. Exact ID match
    for d in DEVICES.values():
        if d["id"].lower() == clean_id:
            return d

    # 2. Aliases or Name match
    for d in DEVICES.values():
        if clean_id in [a.lower() for a in d.get("aliases", [])]:
            return d
        if d["name"].lower() == clean_id:
            return d
        if clean_id and clean_id in d["name"].lower():
            return d

    # 3. Type match
    for d in DEVICES.values():
        if clean_type and (d["type"].lower() == clean_type or clean_type in d.get("aliases", [])):
            return d
        if clean_id and d["type"].lower() == clean_id:
            return d

    # 4. Partial substring in aliases
    for d in DEVICES.values():
        for a in d.get("aliases", []):
            if a in clean_id or clean_id in a:
                return d

    return None

def auto_discover_tuya_ip(target_id: str) -> Optional[str]:
    """Scant het lokale netwerk via UDP discovery als een stekker van IP is veranderd door DHCP."""
    try:
        print(f"🔍 [Pi Tuya Scan] Zoeken naar nieuw IP voor apparaat {target_id}...")
        scan_results = tinytuya.deviceScan(verbose=False, maxretry=1)
        if isinstance(scan_results, dict):
            for ip, info in scan_results.items():
                gw_id = info.get("gwId") or info.get("id") or (info.get("device") if isinstance(info.get("device"), dict) else None)
                if gw_id == target_id:
                    print(f"🎯 [Pi Tuya Scan] Apparaat {target_id} herontdekt op nieuw IP: {ip}!")
                    return ip
    except Exception as e:
        print(f"⚠️ [Pi Tuya Scan] Fout tijdens UDP scan: {e}")
    return None

def _execute_tuya_switch(dev: Dict[str, Any], on: bool, trigger: str) -> Dict[str, Any]:
    ip = dev.get("ip")
    if not ip or not dev.get("key"):
        return {"success": False, "error": f"Geen lokaal IP/key voor {dev['name']}"}

    pref_ver = dev.get("version", 3.3)
    versions_to_try = [pref_ver]
    for alt in [3.3, 3.4, 3.1]:
        if alt not in versions_to_try:
            versions_to_try.append(alt)

    last_error = ""
    with hardware_lock:
        for ver in versions_to_try:
            try:
                d = tinytuya.OutletDevice(dev["id"], ip, dev["key"])
                d.set_version(ver)
                d.set_socketPersistent(False)
                res = d.turn_on() if on else d.turn_off()
                if "dps" in res or res.get("success") == True or not res.get("Error"):
                    dev["is_on"] = on
                    dev["version"] = ver
                    add_log(dev["name"], on, trigger, "local_lan")
                    print(f"⚡ [Pi Hub] {dev['name']} -> {'AAN' if on else 'UIT'} via LAN (v{ver}) [Trigger: {trigger}]")
                    return {"success": True, "method": "local_lan", "device": dev["name"], "on": on, "version": ver}
                else:
                    last_error = str(res)
            except Exception as e:
                last_error = str(e)
            time.sleep(0.2)

    # Als het mislukt is: mogelijks is het IP gewijzigd via router DHCP. Probeer automatisch te herontdekken!
    new_ip = auto_discover_tuya_ip(dev["id"])
    if new_ip and new_ip != ip:
        print(f"🔄 [Pi Hub] Nieuw IP {new_ip} gevonden voor {dev['name']} (was {ip}). Opnieuw proberen...")
        dev["ip"] = new_ip
        try:
            d = tinytuya.OutletDevice(dev["id"], new_ip, dev["key"])
            d.set_version(pref_ver)
            d.set_socketPersistent(False)
            res = d.turn_on() if on else d.turn_off()
            if "dps" in res or res.get("success") == True or not res.get("Error"):
                dev["is_on"] = on
                add_log(dev["name"], on, f"{trigger} (Auto-DHCP Reconnect)", "local_lan")
                print(f"⚡ [Pi Hub] {dev['name']} -> {'AAN' if on else 'UIT'} na IP-herstel ({new_ip})")
                return {"success": True, "method": "local_lan", "device": dev["name"], "on": on, "version": pref_ver, "recovered_ip": new_ip}
        except Exception as e2:
            last_error = f"{last_error} | Retry met nieuw IP mislukt: {e2}"

    return {"success": False, "error": f"Kon '{dev['name']}' niet lokaal bereiken op {ip}: {last_error}"}

def switch_internal(device_id: str, on: bool, trigger: str = "Handmatig", dev_type: Optional[str] = None) -> Dict[str, Any]:
    dev = resolve_device(device_id, dev_type)
    if not dev:
        return {"success": False, "error": f"Apparaat '{device_id}' niet herkend door lokale Pi Hub"}

    d_type = dev.get("type", "")
    now_ts = time.time()
    is_manual = any(k in trigger.lower() for k in ["handmatig", "iphone", "manual", "gebruiker", "override"])

    # --- CLIMATE SAFETY INTERLOCK RULES ---

    # Rule 1: Turning Humidifier ON
    if d_type == "Humidifier" and on:
        # Find any running exhaust fans and turn them OFF immediately
        for other_id, other_dev in list(DEVICES.items()):
            if other_dev.get("type") in ["ExhaustFan", "Fan"] and other_dev.get("is_on"):
                print("🔒 [Pi Interlock] Ventilatie direct UIT geschakeld wegens start bevochtiging")
                _execute_tuya_switch(other_dev, False, trigger="Interlock: Bevochtiging Actief")
                CLIMATE_STATE["last_fan_off_timestamp"] = now_ts
        # Lock exhaust fan for mist settling (2 minutes = 120s)
        CLIMATE_STATE["exhaust_lockout_until"] = now_ts + 120
        print(f"🔒 [Pi Interlock] Ventilatie vergrendeld voor 2 minuten (nevel neerslagperiode tot {datetime.fromtimestamp(now_ts + 120).strftime('%H:%M:%S')})")

    # Rule 2: Turning Humidifier OFF
    if d_type == "Humidifier" and not on:
        CLIMATE_STATE["last_mist_off_timestamp"] = now_ts
        # Ensure 2 minutes settling lockout post-mist
        CLIMATE_STATE["exhaust_lockout_until"] = max(CLIMATE_STATE["exhaust_lockout_until"], now_ts + 120)

    # Rule 3: Turning Exhaust Fan ON
    if d_type in ["ExhaustFan", "Fan"] and on:
        # Check if fan is currently locked out by active or recent misting
        if now_ts < CLIMATE_STATE["exhaust_lockout_until"] and not is_manual:
            remaining = int(CLIMATE_STATE["exhaust_lockout_until"] - now_ts)
            print(f"⏳ [Pi Interlock] Ventilatie uitgesteld: nevel slaat nog neer (nog {remaining}s)")
            return {
                "success": False,
                "error": f"Ventilatie tijdelijk vergrendeld: nevel slaat nog neer (nog {remaining}s)",
                "locked": True,
                "lock_remaining_seconds": remaining
            }

        # If manual override or lock expired: Turn OFF any running humidifier
        for other_id, other_dev in list(DEVICES.items()):
            if other_dev.get("type") == "Humidifier" and other_dev.get("is_on"):
                print("🔒 [Pi Interlock] Bevochtiger direct UIT geschakeld wegens start ventilatie (FAE)")
                _execute_tuya_switch(other_dev, False, trigger="Interlock: Ventilatie Actief")

    # Rule 4: Turning Exhaust Fan OFF
    if d_type in ["ExhaustFan", "Fan"] and not on:
        if dev.get("is_on"):
            CLIMATE_STATE["last_fan_off_timestamp"] = now_ts
            print(f"🍃 [Pi Interlock] FAE Ventilatie beëindigd op {datetime.now().strftime('%H:%M:%S')}. Optimale optische scan-window actief!")

    # Physical Execution
    return _execute_tuya_switch(dev, on, trigger)

def run_autopilot_tick():
    sched_data = load_schedules()
    if not sched_data.get("autopilot_enabled", True):
        return

    now = datetime.now()
    now_ts = time.time()
    schedules = sched_data.get("schedules", [])
    updated = False

    for item in schedules:
        dev_id = item.get("device_id")
        dev = resolve_device(dev_id, item.get("type"))
        if not dev:
            continue

        dev_type = item.get("type", dev.get("type"))
        current_state = dev.get("is_on", False)

        # Check manual override
        override_until = float(item.get("manual_override_until") or 0)
        if 0 < override_until < 1000000000.0:
            override_until += 978307200.0
        is_override = item.get("manual_override", False)
        if override_until > 0 and now_ts >= override_until:
            is_override = False
            item["manual_override"] = False
            item["manual_override_until"] = 0
            updated = True
        
        if is_override:
            desired_state = item.get("manual_override_state", current_state)
            if desired_state != current_state:
                switch_internal(dev["id"], desired_state, trigger="Handmatige Overschrijving Actief")
            continue

        if dev_type in ["Light", "GrowLight"]:
            on_h = int(item.get("light_on_hour", 8))
            off_h = int(item.get("light_off_hour", 20))
            if on_h <= off_h:
                should_be_on = (on_h <= now.hour < off_h)
            else:
                should_be_on = (now.hour >= on_h or now.hour < off_h)

            if should_be_on != current_state:
                switch_internal(dev["id"], should_be_on, trigger=f"Pi Autopilot: Lichtschema ({'AAN' if should_be_on else 'UIT'})")

        elif dev_type in ["ExhaustFan", "Fan", "Humidifier"]:
            interval_min = max(1, int(item.get("interval_minutes", 180)))
            duration_min = max(1, int(item.get("duration_minutes", 5)))
            period_sec = interval_min * 60
            duration_sec = duration_min * 60

            start_ts = item.get("cycle_start_time")
            if not start_ts:
                item["cycle_start_time"] = now_ts - duration_sec
                start_ts = item["cycle_start_time"]
                updated = True
            elif float(start_ts) < 1000000000.0:
                item["cycle_start_time"] = float(start_ts) + 978307200.0
                start_ts = item["cycle_start_time"]
                updated = True

            elapsed = now_ts - start_ts
            if elapsed < 0:
                item["cycle_start_time"] = now_ts
                start_ts = now_ts
                elapsed = 0
                updated = True

            if elapsed >= period_sec:
                cycles_passed = int(elapsed // period_sec)
                item["cycle_start_time"] = start_ts + (cycles_passed * period_sec)
                start_ts = item["cycle_start_time"]
                elapsed = now_ts - start_ts
                updated = True

            if elapsed < duration_sec:
                should_be_on = True
            else:
                should_be_on = False

            # Interlock Safety for Autopilot Intervals:
            if should_be_on and dev_type in ["ExhaustFan", "Fan"]:
                if now_ts < CLIMATE_STATE["exhaust_lockout_until"]:
                    # Post-mist dwell period in effect! Do not turn on fan to avoid blowing away mist
                    should_be_on = False

            if should_be_on and dev_type == "Humidifier":
                # Check if fan is currently running
                fan_dev = resolve_device(None, "ExhaustFan") or resolve_device(None, "Fan")
                if fan_dev and fan_dev.get("is_on"):
                    should_be_on = False

            if should_be_on != current_state:
                switch_internal(dev["id"], should_be_on, trigger=f"Pi Autopilot: Interval ({dev['name']} {'AAN' if should_be_on else 'UIT'})")

    if updated:
        save_schedules(sched_data)

def poll_physical_hardware_status():
    """Polls each physical plug on the local LAN using tinytuya status() to continuously detect physical button presses."""
    for dev in DEVICES.values():
        ip = dev.get("ip")
        key = dev.get("key")
        dev_id = dev.get("id")
        if not ip or not key or not dev_id:
            continue
        try:
            with hardware_lock:
                pref_ver = dev.get("version", 3.3)
                d = tinytuya.OutletDevice(dev_id, ip, key)
                d.set_version(pref_ver)
                d.set_socketPersistent(False)
                st = d.status()
            if isinstance(st, dict) and "dps" in st and "1" in st["dps"]:
                physical_on = bool(st["dps"]["1"])
                old_state = dev.get("is_on", False)
                if physical_on != old_state:
                    print(f"🔌 [Pi Hub] Fysieke knop / statuswijziging gedetecteerd op {dev['name']}: {'AAN' if physical_on else 'UIT'}")
                    dev["is_on"] = physical_on
                    add_log(dev["name"], physical_on, "Fysieke Knop", "hardware_switch")
                    try:
                        sched_data = load_schedules()
                        sched_updated = False
                        n_ts = time.time()
                        for s in sched_data.get("schedules", []):
                            if (s.get("device_id") and s["device_id"].lower() == dev_id.lower()) or (s.get("name") and s["name"].lower() == dev["name"].lower()):
                                s_type = s.get("type", dev.get("type"))
                                if s_type in ["Light", "GrowLight"]:
                                    s["manual_override"] = True
                                    s["manual_override_state"] = physical_on
                                    s["manual_override_until"] = n_ts + (4 * 3600)
                                    sched_updated = True
                                elif s_type in ["ExhaustFan", "Fan", "Humidifier"]:
                                    dur_sec = max(1, int(s.get("duration_minutes", 5))) * 60
                                    s["cycle_start_time"] = n_ts if physical_on else (n_ts - dur_sec)
                                    s["manual_override"] = False
                                    sched_updated = True
                        if sched_updated:
                            save_schedules(sched_data)
                    except Exception as e:
                        print(f"⚠️ [Pi Hub] Fout bij verwerken fysieke knop in schema: {e}")
        except Exception:
            pass
        time.sleep(0.25)

def initial_hardware_sync():
    time.sleep(2)
    print("🔍 [Pi Hub] Initiële status poll van fysieke stekkers op LAN...")
    poll_physical_hardware_status()

threading.Thread(target=initial_hardware_sync, daemon=True).start()

def autopilot_loop():
    print("🚀 [Pi Lab Hub] Autopilot Loop gestart (incl. continue fysieke knop detectie)!")
    time.sleep(5)  # Grace period
    while True:
        try:
            poll_physical_hardware_status()
            run_autopilot_tick()
        except Exception as e:
            print(f"Error in autopilot tick / poll: {e}")
        time.sleep(10)  # Poll physical buttons and tick schedules every 10 seconds

threading.Thread(target=autopilot_loop, daemon=True).start()

class SwitchReq(BaseModel):
    device_id: str
    on: bool
    trigger: Optional[str] = "iPhone"
    device_type: Optional[str] = None
    name: Optional[str] = None

class SchedulesPayload(BaseModel):
    autopilot_enabled: bool = True
    schedules: List[Dict[str, Any]]

class ClimateReadingPayload(BaseModel):
    humidity: float
    temperature: Optional[float] = None
    target_humidity: Optional[float] = 90.0
    source: Optional[str] = "OpticalHygrometer"

@app.post("/devices/scan")
def trigger_network_scan():
    """Scant het netwerk en werkt de IP-adressen van alle geconfigureerde Tuya stekkers bij."""
    try:
        scan_results = tinytuya.deviceScan(verbose=False, maxretry=1)
        updated = []
        if isinstance(scan_results, dict):
            for ip, info in scan_results.items():
                gw_id = info.get("gwId") or info.get("id")
                if gw_id and gw_id in DEVICES:
                    old_ip = DEVICES[gw_id].get("ip")
                    if old_ip != ip:
                        DEVICES[gw_id]["ip"] = ip
                        updated.append({"device": DEVICES[gw_id]["name"], "id": gw_id, "old_ip": old_ip, "new_ip": ip})
        return {
            "success": True,
            "scan_count": len(scan_results) if isinstance(scan_results, dict) else 0,
            "updated_devices": updated,
            "devices": list(DEVICES.values())
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Fout tijdens scan: {str(e)}")

@app.get("/status")
def get_hub_status():
    sched = load_schedules()
    now_ts = time.time()
    
    # USB Storage stats
    storage_info = {"mounted": False}
    if os.path.exists(USB_PATH) and os.path.ismount(USB_PATH):
        try:
            total, used, free = shutil.disk_usage(USB_PATH)
            storage_info = {
                "mounted": True,
                "mount_point": USB_PATH,
                "label": "Pi-Storage (USB Stick)",
                "total_gb": round(total / (1024**3), 2),
                "free_gb": round(free / (1024**3), 2),
                "used_percent": round((used / total) * 100, 1)
            }
        except Exception:
            pass

    # Climate safety & interlock stats
    last_fan_off = CLIMATE_STATE["last_fan_off_timestamp"]
    sec_since_fan = round(now_ts - last_fan_off, 1) if last_fan_off > 0 else None
    is_scan_window = (sec_since_fan is not None and 30.0 <= sec_since_fan <= 600.0)

    climate_safety = {
        "exhaust_locked": bool(now_ts < CLIMATE_STATE["exhaust_lockout_until"]),
        "exhaust_lock_remaining_seconds": max(0, int(CLIMATE_STATE["exhaust_lockout_until"] - now_ts)),
        "seconds_since_fan_off": sec_since_fan,
        "is_optimal_scan_window": is_scan_window,
        "humidifier_on": any(d.get("is_on") for d in DEVICES.values() if d.get("type") == "Humidifier"),
        "fan_on": any(d.get("is_on") for d in DEVICES.values() if d.get("type") in ["ExhaustFan", "Fan"]),
        "latest_reading": CLIMATE_STATE["latest_reading"]
    }

    return {
        "status": "online",
        "hub": "Raspberry Pi 3B (Pi-Lab)",
        "ip": get_hub_ip(),
        "time": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "autopilot_active": sched.get("autopilot_enabled", True),
        "storage": storage_info,
        "climate_safety": climate_safety,
        "devices": [
            {
                "id": d["id"],
                "name": d["name"],
                "type": d["type"],
                "ip": d.get("ip"),
                "is_on": d.get("is_on", False),
                "version": d.get("version"),
                "local_lan_ready": bool(d.get("ip") and d.get("key"))
            } for d in DEVICES.values()
        ],
        "schedules": sched.get("schedules", [])
    }

@app.get("/devices")
def get_devices():
    return {"devices": DEVICES}

@app.post("/switch")
def switch_device(req: SwitchReq):
    res = switch_internal(req.device_id, req.on, trigger=req.trigger, dev_type=req.device_type)
    if not res.get("success") and req.name:
        res = switch_internal(req.name, req.on, trigger=req.trigger, dev_type=req.device_type)
    if not res.get("success"):
        raise HTTPException(status_code=500, detail=res.get("error", "Switch mislukt"))
    
    try:
        sched_data = load_schedules()
        sched_updated = False
        n_ts = time.time()
        for s in sched_data.get("schedules", []):
            if (s.get("device_id") and s["device_id"].lower() == req.device_id.lower()) or (req.name and s.get("name") and s["name"].lower() == req.name.lower()):
                s_type = s.get("type", req.device_type or "")
                if s_type in ["Light", "GrowLight"]:
                    s["manual_override"] = True
                    s["manual_override_state"] = req.on
                    s["manual_override_until"] = n_ts + (4 * 3600)
                    sched_updated = True
                elif s_type in ["ExhaustFan", "Fan", "Humidifier"]:
                    dur_sec = max(1, int(s.get("duration_minutes", 5))) * 60
                    s["cycle_start_time"] = n_ts if req.on else (n_ts - dur_sec)
                    s["manual_override"] = False
                    sched_updated = True
        if sched_updated:
            save_schedules(sched_data)
    except Exception as e:
        print(f"⚠️ [Pi Hub] Fout bij updaten schema na switch: {e}")

    return res

@app.post("/climate/reading")
def record_climate_reading(reading: ClimateReadingPayload):
    CLIMATE_STATE["latest_reading"] = {
        "humidity": reading.humidity,
        "temperature": reading.temperature,
        "target_humidity": reading.target_humidity,
        "timestamp": time.time(),
        "time_str": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "source": reading.source
    }
    print(f"📊 [Pi Hub] Nieuwe klimaatmeting ontvangen ({reading.source}): {reading.humidity}% RV, {reading.temperature}°C")
    return {"success": True, "reading": CLIMATE_STATE["latest_reading"]}

@app.get("/schedules")
def get_schedules():
    return load_schedules()

@app.post("/schedules")
def set_schedules(payload: SchedulesPayload):
    current_sched = load_schedules()
    existing_starts = {}
    for s in current_sched.get("schedules", []):
        if "device_id" in s and s.get("cycle_start_time"):
            existing_starts[str(s["device_id"]).lower()] = s["cycle_start_time"]
        if "name" in s and s.get("cycle_start_time"):
            existing_starts[str(s["name"]).lower()] = s["cycle_start_time"]

    incoming = []
    for s in payload.schedules:
        item = dict(s)
        dev_id = item.get("device_id")
        name = item.get("name")
        raw_ts = item.get("cycle_start_time")
        if not raw_ts or float(raw_ts) <= 0:
            if dev_id and str(dev_id).lower() in existing_starts:
                item["cycle_start_time"] = existing_starts[str(dev_id).lower()]
            elif name and str(name).lower() in existing_starts:
                item["cycle_start_time"] = existing_starts[str(name).lower()]
        else:
            ts_val = float(raw_ts)
            if ts_val < 1000000000.0:
                ts_val += 978307200.0
            item["cycle_start_time"] = ts_val
        incoming.append(item)

    sched_data = {
        "autopilot_enabled": payload.autopilot_enabled,
        "last_sync": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "schedules": incoming
    }
    save_schedules(sched_data)
    threading.Thread(target=run_autopilot_tick, daemon=True).start()
    return {"success": True, "message": "Schema's opgeslagen!", "schedules": sched_data}

@app.get("/logs")
def get_logs():
    return {"logs": load_logs()}

@app.post("/shutdown")
def safe_shutdown():
    def do_shutdown():
        time.sleep(1.5)
        os.system("sync && sudo shutdown -h now")
    threading.Thread(target=do_shutdown, daemon=True).start()
    return {"success": True, "message": "Pi Hub sluit veilig af over 2 seconden..."}

@app.post("/reboot")
def safe_reboot():
    def do_reboot():
        time.sleep(1.5)
        os.system("sync && sudo reboot")
    threading.Thread(target=do_reboot, daemon=True).start()
    return {"success": True, "message": "Pi Hub herstart..."}

# MARK: - Central Database REST Endpoints (Pi as Single Source of Truth)

@app.get("/database")
def get_central_database():
    """Haalt de volledige centrale MycoLab database op van de USB-opslag op de Pi."""
    db = load_database()
    if db is None:
        raise HTTPException(status_code=404, detail="Centrale database is nog niet geïnitialiseerd op de Pi Hub")
    
    st = os.stat(DATABASE_FILE)
    return {
        "success": True,
        "database": db,
        "last_modified": st.st_mtime,
        "last_modified_str": datetime.fromtimestamp(st.st_mtime).strftime("%Y-%m-%d %H:%M:%S"),
        "size_bytes": st.st_size
    }

@app.get("/database/status")
def get_database_status():
    """Snelle, compacte statuscontrole om te zien of de client up-to-date is zonder megabytes te downloaden."""
    if not os.path.exists(DATABASE_FILE):
        return {
            "exists": False,
            "message": "Nog geen database aanwezig op de Pi Hub"
        }
    st = os.stat(DATABASE_FILE)
    db = load_database() or {}
    return {
        "exists": True,
        "last_modified": st.st_mtime,
        "last_modified_str": datetime.fromtimestamp(st.st_mtime).strftime("%Y-%m-%d %H:%M:%S"),
        "size_bytes": st.st_size,
        "counts": {
            "strains": len(db.get("strains", [])),
            "cultures": len(db.get("cultures", [])),
            "projects": len(db.get("projects", [])),
            "harvests": len(db.get("harvests", [])),
            "stash": len(db.get("stash", [])),
            "supplies": len(db.get("supplies", [])),
            "smart_devices": len(db.get("smartDevices", []))
        }
    }

@app.post("/database")
def update_central_database(payload: Dict[str, Any]):
    """Ontvangt database updates van MycoLab (iPhone/Mac/iPad) of MycoCam en bewaart deze 24/7 op USB."""
    db_data = payload.get("database") if "database" in payload and isinstance(payload.get("database"), dict) else payload
    client_name = payload.get("senderDeviceName") or payload.get("client_name") or "MycoLab App"
    
    if not isinstance(db_data, dict):
        raise HTTPException(status_code=400, detail="Ongeldig database JSON formaat")
        
    res = save_database(db_data, client_name=str(client_name))
    return res

@app.get("/database/download")
def download_database_file():
    """Direct bestand downloaden voor backupdoeleinden."""
    if not os.path.exists(DATABASE_FILE):
        raise HTTPException(status_code=404, detail="Database bestand bestaat niet")
    return FileResponse(
        path=DATABASE_FILE,
        media_type="application/json",
        filename="MycoLab_Central_Database.json"
    )

@app.get("/database/backups")
def list_database_backups():
    """Toont alle gearchiveerde backups op de USB-stick."""
    backups = []
    if os.path.exists(BACKUPS_DIR):
        for fname in sorted(os.listdir(BACKUPS_DIR), reverse=True):
            if fname.startswith("mycolab_db_") and fname.endswith(".json"):
                fpath = os.path.join(BACKUPS_DIR, fname)
                try:
                    st = os.stat(fpath)
                    backups.append({
                        "filename": fname,
                        "size_bytes": st.st_size,
                        "created_at": datetime.fromtimestamp(st.st_mtime).strftime("%Y-%m-%d %H:%M:%S"),
                        "timestamp": st.st_mtime
                    })
                except Exception:
                    pass
    return {"backups": backups, "count": len(backups), "backup_dir": BACKUPS_DIR}

@app.post("/database/restore/{filename}")
def restore_database_backup(filename: str):
    """Zet een eerdere backup terug naar de actieve database."""
    safe_name = os.path.basename(filename)
    fpath = os.path.join(BACKUPS_DIR, safe_name)
    if not os.path.exists(fpath):
        raise HTTPException(status_code=404, detail="Backup bestand niet gevonden")
    try:
        shutil.copy2(fpath, DATABASE_FILE)
        add_log("Centrale Database", True, f"Backup hersteld ({safe_name})", "REST-API")
        return {"success": True, "message": f"Backup '{safe_name}' succesvol hersteld!"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Herstellen mislukt: {str(e)}")

# MARK: - Finished Timelapse MP4 Storage & Video Serving (No loose photo syncing)
@app.post("/timelapse/upload")
async def upload_timelapse_video(file: UploadFile = File(...)):
    """Receives completed MP4 timelapse video rendered on the camera phone and stores it permanently on Pi USB."""
    try:
        raw_name = os.path.basename(file.filename) if file.filename else f"MycoLab_Timelapse_{int(time.time())}.mp4"
        safe_filename = "".join(c for c in raw_name if c.isalnum() or c in "._- ")
        if not safe_filename.endswith(".mp4"):
            safe_filename += ".mp4"
        
        target_path = os.path.join(TIMELAPSE_DIR, safe_filename)
        
        with open(target_path, "wb") as f_out:
            while chunk := await file.read(1024 * 1024):
                f_out.write(chunk)
                
        file_size = os.path.getsize(target_path)
        print(f"🎬 [Pi Hub] Nieuwe timelapse video opgeslagen op Pi: {safe_filename} ({round(file_size / (1024*1024), 2)} MB)")
        
        return {
            "success": True,
            "filename": safe_filename,
            "size_bytes": file_size,
            "size_mb": round(file_size / (1024 * 1024), 2),
            "download_url": f"/timelapse/download/{safe_filename}",
            "created_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        }
    except Exception as e:
        print(f"⚠️ [Pi Hub] Fout bij uploaden timelapse: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/timelapse/list")
def list_timelapses():
    """Lists all finished MP4 timelapse videos stored on the Pi Hub."""
    items = []
    if os.path.exists(TIMELAPSE_DIR):
        for fname in sorted(os.listdir(TIMELAPSE_DIR), reverse=True):
            if fname.lower().endswith(".mp4"):
                fpath = os.path.join(TIMELAPSE_DIR, fname)
                try:
                    st = os.stat(fpath)
                    created_dt = datetime.fromtimestamp(st.st_mtime)
                    items.append({
                        "filename": fname,
                        "size_bytes": st.st_size,
                        "size_mb": round(st.st_size / (1024 * 1024), 2),
                        "created_at": created_dt.strftime("%Y-%m-%d %H:%M:%S"),
                        "timestamp": st.st_mtime,
                        "download_url": f"/timelapse/download/{fname}"
                    })
                except Exception:
                    pass
    return {"timelapses": items, "count": len(items), "storage_dir": TIMELAPSE_DIR}

@app.get("/timelapse/download/{filename}")
def download_timelapse(filename: str):
    """Streams or downloads a stored MP4 timelapse video directly to the iOS app."""
    safe_filename = os.path.basename(filename)
    fpath = os.path.join(TIMELAPSE_DIR, safe_filename)
    if not os.path.exists(fpath):
        raise HTTPException(status_code=404, detail="Timelapse video niet gevonden")
    return FileResponse(
        path=fpath,
        media_type="video/mp4",
        filename=safe_filename
    )

@app.delete("/timelapse/{filename}")
def delete_timelapse(filename: str):
    safe_filename = os.path.basename(filename)
    fpath = os.path.join(TIMELAPSE_DIR, safe_filename)
    if os.path.exists(fpath):
        os.remove(fpath)
        print(f"🗑️ [Pi Hub] Timelapse verwijderd: {safe_filename}")
        return {"success": True, "message": f"{safe_filename} verwijderd"}
    raise HTTPException(status_code=404, detail="Bestand niet gevonden")
