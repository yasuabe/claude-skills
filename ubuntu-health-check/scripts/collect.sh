#!/usr/bin/env bash
# Ubuntu Health Check - Information Collector
# Read-only script: no modifications, no sudo required
set +e  # continue on errors (many commands may fail due to permissions)

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
echo "OS: $(lsb_release -ds 2>/dev/null || head -2 /etc/os-release 2>/dev/null)"
echo "Kernel: $(uname -r)"
echo "Uptime: $(uptime -p 2>/dev/null || uptime)"
echo "Last boot: $(who -b 2>/dev/null | awk '{print $3, $4}')"

# ----------------------------------------
# OS Support / Ubuntu Pro
# ----------------------------------------
section "Ubuntu Pro / ESM Status"
if command -v pro &>/dev/null; then
  pro status 2>/dev/null || echo "Cannot query pro status"
elif command -v ua &>/dev/null; then
  ua status 2>/dev/null || echo "Cannot query ua status"
else
  echo "ubuntu-advantage-tools not installed"
fi

section "OS EOL Check"
CODENAME=$(lsb_release -cs 2>/dev/null)
echo "Codename: $CODENAME"
if command -v ubuntu-distro-info &>/dev/null; then
  echo "Fullname: $(ubuntu-distro-info --series="$CODENAME" --fullname 2>/dev/null)"
  echo "Days to EOL: $(ubuntu-distro-info --series="$CODENAME" -yeol 2>/dev/null | awk '{print $NF}')"
  echo "In --supported list: $(ubuntu-distro-info --supported 2>/dev/null | grep -q "$CODENAME" && echo "YES" || echo "NO")"
  echo "In --supported-esm list: $(ubuntu-distro-info --supported-esm 2>/dev/null | grep -q "$CODENAME" && echo "YES" || echo "NO")"
  echo "In --unsupported list: $(ubuntu-distro-info --unsupported 2>/dev/null | grep -q "$CODENAME" && echo "YES" || echo "NO")"
else
  grep -E "^(NAME|VERSION|SUPPORT_URL)" /etc/os-release 2>/dev/null || true
fi
echo "Current date: $(date +%Y-%m-%d)"

# ----------------------------------------
# APT Repository Health
# ----------------------------------------
section "APT Repository Errors"
apt-get update --print-uris 2>&1 | grep -iE "NO_PUBKEY|expired|error|warning" || echo "No repository errors detected"

section "APT Key Expiry Check"
if [ -d /etc/apt/trusted.gpg.d ]; then
  for keyfile in /etc/apt/trusted.gpg.d/*.gpg; do
    [ -f "$keyfile" ] || continue
    echo "--- $(basename "$keyfile") ---"
    gpg --no-default-keyring --keyring "$keyfile" --list-keys --with-colons 2>/dev/null \
      | awk -F: '/^pub/{print "Key: "$5" Expires: "($7=="" ? "never" : strftime("%Y-%m-%d",$7))}'
  done
fi

# ----------------------------------------
# Hardware Health
# ----------------------------------------
section "SMART Disk Health"
if command -v smartctl &>/dev/null; then
  for dev in /dev/sd? /dev/nvme?n?; do
    [ -b "$dev" ] || continue
    echo "--- $dev ---"
    smartctl -H "$dev" 2>/dev/null || echo "Cannot read SMART (may need sudo)"
  done
else
  echo "smartmontools not installed (recommend: sudo apt install smartmontools)"
fi

section "NTP Sync"
timedatectl status 2>/dev/null || echo "N/A"

section "CPU Temperature"
for z in /sys/class/thermal/thermal_zone*; do
  [ -d "$z" ] || continue
  type=$(cat "$z/type" 2>/dev/null)
  temp=$(awk '{printf "%.0f", $1/1000}' "$z/temp" 2>/dev/null)
  echo "$type: ${temp}°C"
done

echo ""
echo "========================================"
echo "## Collection Complete"
echo "========================================"
