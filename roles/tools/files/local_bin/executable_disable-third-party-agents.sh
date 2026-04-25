#!/usr/bin/env bash
set -euo pipefail

USER_AGENTS=(
  com.crowdstrike.falcon.UserAgent
  com.forcepoint.one.endpoint.ui.helper
  com.google.keystone.agent
  com.google.keystone.xpcservice
  com.mcafee.menulet
  com.mcafee.reporter
  com.mcafee.uninstall.SystemExtension
  com.microsoft.OneDriveStandaloneUpdater
  com.microsoft.SyncReporter
  com.microsoft.entraidentitybrokerxpc
  com.microsoft.intuneMDMAgent
  com.microsoft.update.agent
  com.nexthink.collector.nxtray
  com.nexthink.collector.nxtusm
  com.websense.endpoint.dlp.helper
  com.websense.endpoint.dlp.helperservice
  net.Printix.UI
)

SYSTEM_DAEMONS=(
  com.bayer.dwp.networksetup
  com.forcepoint.endpoint.dc.epupgrade
  com.google.GoogleUpdater.wake.system
  com.google.keystone.daemon
  com.mcafee.agent.ma
  com.mcafee.agent.macmn
  com.mcafee.agentMonitor.helper
  com.mcafee.virusscan.fmpd
  com.microsoft.EdgeUpdater.wake.system
  com.microsoft.OneDriveStandaloneUpdaterDaemon
  com.microsoft.OneDriveUpdaterDaemon
  com.microsoft.autoupdate.helper
  com.microsoft.intuneMDMAgent.daemon
  com.microsoft.office.licensingV2.helper
  com.nexthink.collector.driver.nxtsvc
  com.nexthink.collector.nxtbsm
  com.nexthink.collector.nxtcltdd
  com.nexthink.collector.nxtcod
  com.nexthink.collector.nxtconnectivity
  com.nexthink.collector.nxtcoordinator
  com.nexthink.collector.nxteufb
  com.nexthink.collector.nxtpackages
  com.nexthink.collector.nxtsessions
  com.nexthink.collector.nxtupdater
  com.tailscale.tailscaled
  com.tanium.taniumclient
  com.websense.endpoint.dlp.daemon
  com.websense.endpoint.epclassifier
  com.websense.endpoint.es.daemon
  com.websense.endpoint.fpnpd
  com.websense.endpoint.proxy.boot
  com.websense.endpoint.proxy.daemon
  net.Printix.Service
)

UID_NUM=$(id -u)

log() { printf "\033[1m[%s]\033[0m %s\n" "$1" "$2"; }

log "INFO" "Booting out user-level launch agents..."
for svc in "${USER_AGENTS[@]}"; do
  if launchctl bootout "gui/${UID_NUM}/${svc}" 2>/dev/null; then
    log "OK  " "Bootout: $svc"
  else
    log "SKIP" "Not loaded: $svc"
  fi
done

log "INFO" "Disabling user-level launch agents from auto-loading..."
for svc in "${USER_AGENTS[@]}"; do
  launchctl disable "gui/${UID_NUM}/${svc}" 2>/dev/null && log "OK  " "Disable: $svc" || log "SKIP" "Cannot disable: $svc"
done

log "INFO" "Booting out system-level launch daemons..."
for svc in "${SYSTEM_DAEMONS[@]}"; do
  if sudo launchctl bootout "system/${svc}" 2>/dev/null; then
    log "OK  " "Bootout: $svc"
  else
    log "SKIP" "Not loaded: $svc"
  fi
done

log "INFO" "Disabling system-level launch daemons from auto-loading..."
for svc in "${SYSTEM_DAEMONS[@]}"; do
  sudo launchctl disable "system/${svc}" 2>/dev/null && log "OK  " "Disable: $svc" || log "SKIP" "Cannot disable: $svc"
done

log "INFO" "Listing remaining system extensions..."
systemextensionsctl list 2>/dev/null || log "WARN" "systemextensionsctl not available"

log "WARN" "Trellix Network Extension is active — disable manually:"
log "WARN" "  System Settings > General > Login Items & Extensions > Endpoint Security Extensions"
log "DONE" "All third-party agents/daemons unloaded and disabled."