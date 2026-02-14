#!/usr/bin/env bash
# Ubuntu Health Check - Information Collector
# Read-only script: no modifications, no sudo required
set -euo pipefail

section() {
  echo ""
  echo "========================================"
  echo "## $1"
  echo "========================================"
}

# ----------------------------------------
# Disk
# ----------------------------------------
section "Disk Usage (df)"
df -h --output=source,fstype,size,used,avail,pcent,target -x tmpfs -x devtmpfs -x squashfs 2>/dev/null || df -h

section "Large Directories under HOME"
du -h --max-depth=1 "$HOME" 2>/dev/null | sort -rh | head -20

section "Cache Directory Breakdown"
if [ -d "$HOME/.cache" ]; then
  du -h --max-depth=1 "$HOME/.cache" 2>/dev/null | sort -rh | head -15
fi

section "Large Files (>100MB under HOME)"
find "$HOME" -xdev -type f -size +100M -printf '%s %p\n' 2>/dev/null | sort -rn | head -20 | awk '{printf "%.1fM %s\n", $1/1048576, $2}'

section "Inode Usage"
df -i --output=source,itotal,iused,iavail,ipcent,target -x tmpfs -x devtmpfs -x squashfs 2>/dev/null || df -i

# ----------------------------------------
# Packages
# ----------------------------------------
section "Upgradable Packages"
apt list --upgradable 2>/dev/null | tail -n +2 | head -30
echo "--- Total: $(apt list --upgradable 2>/dev/null | tail -n +2 | wc -l) packages"

section "Auto-removable Packages"
apt list --installed 2>/dev/null | grep -c 'automatic' || echo "0"
apt-get --dry-run autoremove 2>/dev/null | grep '^Remv' | head -20
echo "--- Total: $(apt-get --dry-run autoremove 2>/dev/null | grep -c '^Remv' || echo 0) packages"

section "Packages in rc (removed but config remains)"
dpkg -l | awk '/^rc/ {print $2}' | head -20
echo "--- Total: $(dpkg -l | awk '/^rc/ {print $2}' | wc -l)"

section "APT Cache Size"
du -sh /var/cache/apt/archives 2>/dev/null || echo "N/A"

section "Old Kernels"
dpkg -l 'linux-image-*' 2>/dev/null | awk '/^ii/ {print $2, $3}' || echo "N/A"
echo "--- Running: $(uname -r)"

# ----------------------------------------
# Memory & Processes
# ----------------------------------------
section "Memory Usage"
free -h

section "Top Memory Consumers"
ps aux --sort=-%mem | head -11

section "Top CPU Consumers"
ps aux --sort=-%cpu | head -11

# ----------------------------------------
# Services
# ----------------------------------------
section "Running Services"
systemctl list-units --type=service --state=running --no-pager --no-legend 2>/dev/null | head -40

section "Failed Services"
systemctl list-units --type=service --state=failed --no-pager 2>/dev/null || echo "N/A"

section "Slowest Services (boot)"
systemctl blame --no-pager 2>/dev/null | head -15

# ----------------------------------------
# Network
# ----------------------------------------
section "Listening Ports"
ss -tlnp 2>/dev/null || echo "N/A"

section "UFW Status"
ufw status 2>/dev/null || echo "UFW not available or not permitted"

section "Postfix Configuration (if present)"
if command -v postconf &>/dev/null; then
  postconf inet_interfaces mynetworks 2>/dev/null || echo "Cannot read postfix config"
else
  echo "Postfix not installed"
fi

# ----------------------------------------
# Docker
# ----------------------------------------
section "Docker Disk Usage"
if command -v docker &>/dev/null; then
  docker system df 2>/dev/null || echo "Cannot access Docker"
else
  echo "Docker not installed"
fi

section "Docker Containers (all)"
if command -v docker &>/dev/null; then
  docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Size}}' 2>/dev/null || echo "Cannot access Docker"
else
  echo "Docker not installed"
fi

section "Docker Dangling Images"
if command -v docker &>/dev/null; then
  docker images -f dangling=true 2>/dev/null || echo "Cannot access Docker"
else
  echo "Docker not installed"
fi

# ----------------------------------------
# Snap
# ----------------------------------------
section "Snap List"
if command -v snap &>/dev/null; then
  snap list 2>/dev/null || echo "Cannot list snaps"
else
  echo "Snap not installed"
fi

section "Snap Disabled (old revisions)"
if command -v snap &>/dev/null; then
  snap list --all 2>/dev/null | awk '/disabled/ {print $1, $2, $3}' | head -20
  echo "--- Total disabled: $(snap list --all 2>/dev/null | grep -c disabled || echo 0)"
else
  echo "Snap not installed"
fi

# ----------------------------------------
# Logs
# ----------------------------------------
section "Journal Disk Usage"
journalctl --disk-usage 2>/dev/null || echo "N/A"

section "Recent Critical/Error Logs (last 24h)"
journalctl --priority=0..3 --since "24 hours ago" --no-pager 2>/dev/null | tail -30 || echo "N/A"

# ----------------------------------------
# Misc
# ----------------------------------------
section "Reboot Required"
if [ -f /var/run/reboot-required ]; then
  echo "YES - Reboot is required"
  cat /var/run/reboot-required.pkgs 2>/dev/null || true
else
  echo "No reboot required"
fi

section "System Info"
echo "Hostname: $(hostname)"
echo "OS: $(lsb_release -ds 2>/dev/null || cat /etc/os-release 2>/dev/null | head -2)"
echo "Kernel: $(uname -r)"
echo "Uptime: $(uptime -p 2>/dev/null || uptime)"
echo "Last boot: $(who -b 2>/dev/null | awk '{print $3, $4}')"

echo ""
echo "========================================"
echo "## Collection Complete"
echo "========================================"
