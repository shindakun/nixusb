#!/usr/bin/env bash
# wifi-connect: get the MacBook Air's BCM4360 online from a clean device state.
#
# Ported from the NixOS ISO helper. Same hard-won sequence: NetworkManager, iwd
# and `wpa_supplicant -Dwext` all fail on this card when the `wl` driver has
# broken cfg80211, but plain wpa_supplicant + dhcpcd works IF nothing else is
# holding the interface.
#
# On a linux-lts kernel where broadcom-wl's cfg80211 is intact you should just
# use nmcli/nmtui instead; this is the fallback for when it is not.
#
# Usage: ./wifi-connect.sh "SSID" "PASSWORD" [interface]
set -euo pipefail

ssid="${1:-}"; pass="${2:-}"; iface="${3:-wlp3s0}"
if [ -z "$ssid" ] || [ -z "$pass" ]; then
  echo 'usage: wifi-connect.sh "SSID" "PASSWORD" [interface]' >&2
  echo "(interface defaults to wlp3s0; check with: ip link)" >&2
  exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
  echo "must run as root (try: sudo $0 ...)" >&2
  exit 1
fi

echo "==> clearing anything holding $iface"
pkill wpa_supplicant 2>/dev/null || true
systemctl stop NetworkManager 2>/dev/null || true
systemctl stop iwd 2>/dev/null || true

echo "==> resetting $iface"
rfkill unblock all || true
ip link set "$iface" down || true
ip link set "$iface" up

echo "==> associating with $ssid"
# Deliberately BARE wpa_passphrase output. Do not add key_mgmt/proto/ieee80211w:
# forcing those options broke association on this card.
wpa_passphrase "$ssid" "$pass" > /tmp/wpa.conf
wpa_supplicant -B -i "$iface" -c /tmp/wpa.conf
sleep 6

if ! iw dev "$iface" link | grep -qi connected; then
  echo "!! not associated. Check the password, or run foreground to see why:" >&2
  echo "   sudo wpa_supplicant -i $iface -c /tmp/wpa.conf" >&2
  exit 1
fi

echo "==> associated; requesting DHCP lease"
dhcpcd "$iface" || true
sleep 3
if ip -4 addr show "$iface" | grep -q 'inet '; then
  echo "==> online. test: ping archlinux.org"
else
  echo "!! no IP via DHCP. Set one manually, e.g.:"
  echo "   ip addr add 10.0.0.200/24 dev $iface"
  echo "   ip route add default via 10.0.0.1"
  echo "   printf 'nameserver 1.1.1.1\\n' > /etc/resolv.conf"
fi
