#!/bin/bash
#
# System Optimization Script for M5 Max (macOS 26.4)
# Run with: sudo bash ~/.local/bin/optimize-system.sh [options]
#
# Options:
#   --disable-spotlight   Disable Spotlight indexing (reclaims disk I/O + CPU)
#   --enable-spotlight    Re-enable Spotlight indexing
#   --persist             Write sysctl changes to /etc/sysctl.conf (survives reboot)
#   --dry-run             Show what would be applied without making changes
#   --help                Show this help
#
# Optimizes: DNS, TCP/UDP stack, ephemeral ports, file descriptors,
#            vnode cache, Spotlight control, developer UX tweaks
#

set -uo pipefail

# --- Argument Parsing ---
DISABLE_SPOTLIGHT=false
ENABLE_SPOTLIGHT=false
PERSIST=false
DRY_RUN=false

for arg in "$@"; do
  case "$arg" in
    --disable-spotlight) DISABLE_SPOTLIGHT=true ;;
    --enable-spotlight)  ENABLE_SPOTLIGHT=true ;;
    --persist)           PERSIST=true ;;
    --dry-run)           DRY_RUN=true ;;
    --help)
      awk 'NR>=2 && NR<=15 {sub(/^# ?/,""); print}' "$0"
      exit 0
      ;;
    *) echo "Unknown option: $arg. Use --help."; exit 1 ;;
  esac
done

# --- Helpers ---
SYSCTL_PERSIST_FILE="/etc/sysctl.conf"
APPLIED_SYSCTLS=()

require_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    echo "Error: This script must be run with sudo."
    echo "  Usage: sudo bash $0 $*"
    exit 1
  fi
}

apply_sysctl() {
  local key="$1" val="$2"
  if ! sysctl "$key" >/dev/null 2>&1; then
    printf "  %-8s %s\n" "[skip]" "$key (not supported on this OS)"
    return
  fi
  local current
  current=$(sysctl -n "$key" 2>/dev/null)
  if [[ "$current" == "$val" ]]; then
    printf "  %-8s %s\n" "[ok]" "$key = $val"
    return
  fi
  if $DRY_RUN; then
    printf "  %-8s %s: %s -> %s\n" "[dry]" "$key" "$current" "$val"
  else
    if sysctl -w "$key=$val" >/dev/null 2>&1; then
      printf "  %-8s %s = %s\n" "[set]" "$key" "$val"
    else
      printf "  %-8s %s\n" "[fail]" "$key"
      return
    fi
  fi
  APPLIED_SYSCTLS+=("$key=$val")
}

run_cmd() {
  local desc="$1"; shift
  if $DRY_RUN; then
    printf "  %-8s %s\n" "[dry]" "$desc"
  else
    if "$@" 2>/dev/null; then
      printf "  %-8s %s\n" "[ok]" "$desc"
    else
      printf "  %-8s %s\n" "[fail]" "$desc"
    fi
  fi
}

set_default() {
  local domain="$1" key="$2" type="$3" val="$4"
  if $DRY_RUN; then
    printf "  %-8s defaults write %s %s %s %s\n" "[dry]" "$domain" "$key" "$type" "$val"
  else
    defaults write "$domain" "$key" "$type" "$val" 2>/dev/null \
      && printf "  %-8s %s %s = %s\n" "[set]" "$domain" "$key" "$val" \
      || printf "  %-8s %s %s\n" "[fail]" "$domain" "$key"
  fi
}

if ! $DRY_RUN; then
  require_root
fi

$DRY_RUN && echo "=== DRY RUN — No changes will be applied ===" && echo ""

echo "=== System Optimization: M5 Max / macOS 26.4 ==="
echo "    $(date)"
echo ""

# =============================================================================
# [1/9] DNS
# =============================================================================
echo "[1/9] DNS: Flush cache + configure fast resolvers..."
run_cmd "Flush DNS cache"           dscacheutil -flushcache
run_cmd "Reload mDNSResponder"      killall -HUP mDNSResponder

if ! $DRY_RUN; then
  # Auto-detect active interface
  ACTIVE_IF=$(route get default 2>/dev/null | awk '/interface:/ {print $2}')
  NIC_SERVICE=$(networksetup -listallhardwareports 2>/dev/null | awk \
    -v iface="$ACTIVE_IF" '
      /Hardware Port:/ { port=$0 }
      /Device: / && $2==iface { sub(/.*Hardware Port: /,"",port); print port; exit }
    ')
  TARGET_NIC="${NIC_SERVICE:-Wi-Fi}"
  networksetup -setdnsservers "$TARGET_NIC" \
    1.1.1.1 1.0.0.1 \
    8.8.8.8 8.8.4.4 \
    2606:4700:4700::1111 2606:4700:4700::1001 \
    2001:4860:4860::8888 2001:4860:4860::8844 \
    2>/dev/null \
    && printf "  %-8s Cloudflare + Google DNS (IPv4+IPv6) on %s\n" "[set]" "$TARGET_NIC"
else
  printf "  %-8s %s\n" "[dry]" "Would set Cloudflare + Google DNS on active interface"
fi

# =============================================================================
# [2/9] TCP Stack
# =============================================================================
echo ""
echo "[2/9] TCP network stack..."

# Receive/send buffers: 4MB default, 32MB ceiling for auto-tuning
apply_sysctl net.inet.tcp.sendspace          4194304
apply_sysctl net.inet.tcp.recvspace          4194304
apply_sysctl kern.ipc.maxsockbuf             33554432
apply_sysctl net.inet.tcp.autorcvbufmax      33554432
apply_sysctl net.inet.tcp.autosndbufmax      33554432

# RFC 1323: window scaling + timestamps (required for > 64KB windows)
apply_sysctl net.inet.tcp.rfc1323            1

# Disable delayed ACK — reduces latency for interactive tools (LSP, debuggers)
apply_sysctl net.inet.tcp.delayed_ack        0

# ECN: signal congestion without dropping packets (better on modern networks)
apply_sysctl net.inet.tcp.ecn_initiate_out   1
apply_sysctl net.inet.tcp.ecn_negotiate_in   1

# TCP Fast Open: skip handshake round-trip for repeat connections
apply_sysctl net.inet.tcp.fastopen           3

# Keep-alive: detect dead connections within ~2 min (60s idle + 8x10s probes)
apply_sysctl net.inet.tcp.keepidle           60000
apply_sysctl net.inet.tcp.keepintvl          10000
apply_sysctl net.inet.tcp.keepcnt            8

# Reclaim sockets faster after close
apply_sysctl net.inet.tcp.fast_finwait2_recycle 1
apply_sysctl net.inet.tcp.msl                3000

# Listener backlog (high for local dev servers)
apply_sysctl kern.ipc.somaxconn              4096

# MSS defaults
apply_sysctl net.inet.tcp.mssdflt            1460
apply_sysctl net.inet.tcp.slowlink_wsize     65535

# =============================================================================
# [3/9] UDP Stack  (QUIC / HTTP3 / DNS-over-UDP)
# =============================================================================
echo ""
echo "[3/9] UDP network stack (QUIC, DNS, streaming)..."
apply_sysctl net.inet.udp.recvspace          2097152
apply_sysctl net.inet.udp.maxdgram           65535

# =============================================================================
# [4/9] Ephemeral Port Range
# =============================================================================
echo ""
echo "[4/9] Ephemeral port range (more ports for dev servers + connections)..."
# macOS default is ~49152-65535 — widening gives >39K outbound ports
apply_sysctl net.inet.ip.portrange.first     10000
apply_sysctl net.inet.ip.portrange.last      65535
apply_sysctl net.inet.ip.portrange.hifirst   49152
apply_sysctl net.inet.ip.portrange.hilast    65535

# =============================================================================
# [5/9] File Descriptors
# =============================================================================
echo ""
echo "[5/9] File descriptor limits..."
apply_sysctl kern.maxfiles                   524288
apply_sysctl kern.maxfilesperproc            262144
if ! $DRY_RUN; then
  ulimit -n 262144 2>/dev/null \
    && printf "  %-8s %s\n" "[set]" "ulimit -n = 262144 (shell-scoped)" \
    || printf "  %-8s %s\n" "[skip]" "ulimit (already at limit or shell restriction)"
fi

# =============================================================================
# [6/9] Virtual Memory & Filesystem Cache
# =============================================================================
echo ""
echo "[6/9] Virtual memory & filesystem cache..."

# Vnode cache: how many file metadata entries macOS caches in RAM
# Default ~263K; 750K handles large monorepos without eviction thrashing
apply_sysctl kern.maxvnodes                  750000

# Max processes — only increase if current value is below our target
# (macOS 26 ships with higher defaults than earlier versions)
CURRENT_MAXPROC=$(sysctl -n kern.maxproc 2>/dev/null || echo 0)
[[ "$CURRENT_MAXPROC" -lt 4096 ]] && apply_sysctl kern.maxproc 4096 \
  || printf "  %-8s %s\n" "[ok]" "kern.maxproc = $CURRENT_MAXPROC (already adequate)"
CURRENT_MAXPROCPERUID=$(sysctl -n kern.maxprocperuid 2>/dev/null || echo 0)
[[ "$CURRENT_MAXPROCPERUID" -lt 2048 ]] && apply_sysctl kern.maxprocperuid 2048 \
  || printf "  %-8s %s\n" "[ok]" "kern.maxprocperuid = $CURRENT_MAXPROCPERUID (already adequate)"

# =============================================================================
# [7/9] Spotlight
# =============================================================================
echo ""
echo "[7/9] Spotlight..."
if $DISABLE_SPOTLIGHT; then
  if ! $DRY_RUN; then
    mdutil -a -i off 2>/dev/null \
      && printf "  %-8s %s\n" "[set]" "Spotlight indexing DISABLED on all volumes"
    # Optionally nuke the existing index to reclaim disk space
    mdutil -X / 2>/dev/null \
      && printf "  %-8s %s\n" "[set]" "Spotlight index removed from /" || true
  else
    printf "  %-8s %s\n" "[dry]" "Would run: mdutil -a -i off && mdutil -X /"
  fi
elif $ENABLE_SPOTLIGHT; then
  if ! $DRY_RUN; then
    mdutil -a -i on 2>/dev/null \
      && printf "  %-8s %s\n" "[set]" "Spotlight indexing ENABLED on all volumes"
  else
    printf "  %-8s %s\n" "[dry]" "Would run: mdutil -a -i on"
  fi
else
  SPOT_STATUS=$(mdutil -s / 2>/dev/null | grep -c "enabled" || echo "0")
  if [[ "$SPOT_STATUS" -gt 0 ]]; then
    printf "  %-8s %s\n" "[info]" "Spotlight is currently ENABLED"
    printf "  %-8s %s\n" "[tip]" "Re-run with --disable-spotlight to free CPU/disk I/O"
  else
    printf "  %-8s %s\n" "[info]" "Spotlight is currently DISABLED"
    printf "  %-8s %s\n" "[tip]" "Re-run with --enable-spotlight to restore"
  fi
fi

# =============================================================================
# [8/9] Developer macOS Tweaks
# =============================================================================
echo ""
echo "[8/9] Developer macOS tweaks..."

# Prevent background CPU throttling of foreground-spawned processes (App Nap)
set_default NSGlobalDomain NSAppSleepDisabled              -bool  true

# Disable automatic app termination under memory pressure
set_default NSGlobalDomain NSDisableAutomaticTermination   -bool  true

# Fast key repeat (value 2 = ~30ms repeat, 15 = ~225ms initial delay)
set_default NSGlobalDomain KeyRepeat                       -int   2
set_default NSGlobalDomain InitialKeyRepeat                -int   15

# No .DS_Store pollution on network or USB volumes
set_default com.apple.desktopservices DSDontWriteNetworkStores -bool true
set_default com.apple.desktopservices DSDontWriteUSBStores     -bool true

# Instant window resize animations
set_default NSGlobalDomain NSWindowResizeTime              -float 0.001

# Skip "are you sure you want to open?" dialog for downloaded apps
set_default com.apple.LaunchServices LSQuarantine          -bool  false

# Crash reporter: log silently, no popup dialog blocking your screen
set_default com.apple.CrashReporter DialogType            -string none

# Disable automatic diagnostics upload to Apple
set_default com.apple.SubmitDiagInfo AutoSubmit            -bool  false

# Disable Time Machine local snapshots (significant disk I/O reduction)
run_cmd "Time Machine local snapshots disabled" \
  tmutil disablelocalsnapshots

# Dock: instant autohide (no animation delay)
set_default com.apple.dock autohide-time-modifier          -float 0.15
set_default com.apple.dock autohide-delay                  -float 0.0

# Disable autocorrect / smart punctuation (breaks code in non-IDE text fields)
set_default NSGlobalDomain NSAutomaticSpellingCorrectionEnabled  -bool false
set_default NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled   -bool false
set_default NSGlobalDomain NSAutomaticDashSubstitutionEnabled    -bool false

# =============================================================================
# [9/9] Persist to /etc/sysctl.conf
# =============================================================================
if $PERSIST && [[ ${#APPLIED_SYSCTLS[@]} -gt 0 ]]; then
  echo ""
  echo "[9/9] Persisting ${#APPLIED_SYSCTLS[@]} sysctl entries to $SYSCTL_PERSIST_FILE..."
  if ! $DRY_RUN; then
    [[ -f "$SYSCTL_PERSIST_FILE" ]] \
      && cp "$SYSCTL_PERSIST_FILE" "${SYSCTL_PERSIST_FILE}.bak.$(date +%s)" \
      && echo "  Backed up existing $SYSCTL_PERSIST_FILE"

    for entry in "${APPLIED_SYSCTLS[@]}"; do
      key="${entry%%=*}"
      [[ -f "$SYSCTL_PERSIST_FILE" ]] && sed -i '' "/^${key}=/d" "$SYSCTL_PERSIST_FILE"
    done

    {
      echo ""
      echo "# optimize-system.sh — $(date)"
      for entry in "${APPLIED_SYSCTLS[@]}"; do
        echo "$entry"
      done
    } >> "$SYSCTL_PERSIST_FILE"
    printf "  %-8s Wrote %d entries to %s\n" "[ok]" "${#APPLIED_SYSCTLS[@]}" "$SYSCTL_PERSIST_FILE"
  else
    printf "  %-8s Would write %d entries to %s:\n" "[dry]" "${#APPLIED_SYSCTLS[@]}" "$SYSCTL_PERSIST_FILE"
    for entry in "${APPLIED_SYSCTLS[@]}"; do
      echo "           $entry"
    done
  fi
elif $PERSIST && [[ ${#APPLIED_SYSCTLS[@]} -eq 0 ]]; then
  echo ""
  echo "[9/9] Nothing new to persist (all values already current)."
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "==================================================="
echo " Optimization complete"
echo "==================================================="
echo ""
echo " Network:"
echo "   DNS:   Cloudflare (1.1.1.1) + Google (8.8.8.8) with IPv6"
echo "   TCP:   4MB buffers | 32MB ceiling | ECN on | delayed ACK off"
echo "   UDP:   2MB recv buffer"
echo "   Ports: 10000–65535 ephemeral range"
echo ""
echo " System:"
echo "   Files: 524K max descriptors | 750K vnodes | 4K max procs"
$DISABLE_SPOTLIGHT && echo "   Spotlight: DISABLED (--enable-spotlight to restore)" || true
echo ""
echo " Verify:"
echo "   scutil --dns"
echo "   sysctl net.inet.tcp.sendspace kern.maxvnodes"
echo "   mdutil -s /"
$PERSIST && echo "   cat /etc/sysctl.conf" || true
echo ""
if ! $PERSIST && ! $DRY_RUN; then
  echo " NOTE: sysctl changes reset on reboot."
  echo "       Re-run with --persist to write to /etc/sysctl.conf"
fi
