#!/usr/bin/env python3

from __future__ import annotations

import json
import socket
import subprocess
import sys
import urllib.request


MONITOR_PATH = r"""<< monitor_path >>"""
WARNING_PERCENT = int(r"""<< warning_percent >>""")

DISCORD_WEBHOOK_URL = r"""<< discord_webhook_url >>"""
DISCORD_USERNAME = r"""<< discord_username >>"""


def fetch_disk_usage() -> dict[str, str | int]:
    path = MONITOR_PATH.strip() or "/"

    if not 1 <= WARNING_PERCENT <= 100:
        raise SystemExit("warning_percent must be between 1 and 100.")

    result = subprocess.run(
        ["df", "-P", path],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip() or "unknown local error"
        raise RuntimeError(f"Local df command failed with exit code {result.returncode}: {detail}")

    lines = [line.strip() for line in result.stdout.splitlines() if line.strip()]
    if len(lines) < 2:
        raise RuntimeError(f"Unexpected df output: {result.stdout!r}")

    parts = lines[-1].split(maxsplit=5)
    if len(parts) != 6:
        raise RuntimeError(f"Unable to parse df output line: {lines[-1]!r}")

    usage_raw = parts[4]
    if not usage_raw.endswith("%"):
        raise RuntimeError(f"Unable to parse disk usage percentage: {usage_raw!r}")

    return {
        "filesystem": parts[0],
        "blocks_kb": parts[1],
        "used_kb": parts[2],
        "available_kb": parts[3],
        "usage_percent": int(usage_raw[:-1]),
        "mounted_on": parts[5],
        "path": path,
        "host": socket.gethostname(),
    }


def send_discord_warning(result: dict[str, str | int]) -> bool:
    webhook_url = DISCORD_WEBHOOK_URL.strip()
    if not webhook_url:
        return False

    content = "\n".join(
        [
            "Disk usage warning",
            f"Host: {result['host']}",
            f"Path: {result['path']}",
            f"Mounted on: {result['mounted_on']}",
            f"Filesystem: {result['filesystem']}",
            f"Usage: {result['usage_percent']}% (threshold {WARNING_PERCENT}%)",
            f"Available: {result['available_kb']} KB",
        ]
    )
    payload = json.dumps(
        {
            "username": DISCORD_USERNAME.strip() or "Disk Monitor",
            "content": content[:1900],
        }
    ).encode("utf-8")
    request = urllib.request.Request(
        webhook_url,
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=10) as response:  # noqa: S310
        if response.status >= 400:
            raise RuntimeError(f"Discord webhook returned HTTP {response.status}")
    return True


def main() -> int:
    result = fetch_disk_usage()
    usage_percent = int(result["usage_percent"])
    status = "warn" if usage_percent >= WARNING_PERCENT else "pass"
    alert_sent = False

    if status == "warn":
        alert_sent = send_discord_warning(result)

    print(f"Server Disk Usage Monitor: {status.upper()}")
    print(f"Host: {result['host']}")
    print(f"Path: {result['path']}")
    print(f"Mounted on: {result['mounted_on']}")
    print(f"Filesystem: {result['filesystem']}")
    print(f"Usage: {usage_percent}%")
    print(f"Threshold: {WARNING_PERCENT}%")
    print(f"Available: {result['available_kb']} KB")
    print(f"Discord alert sent: {'yes' if alert_sent else 'no'}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
