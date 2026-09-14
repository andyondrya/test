#!/bin/bash
#
# ondrya-banner.sh
# Prints an "Ondrya" ASCII banner followed by the hostname and current IP.
# Intended to run on login (e.g. via /etc/profile.d/) or as an MOTD script
# baked into the Debian gold image.

set -euo pipefail

print_banner() {
    if command -v figlet >/dev/null 2>&1; then
        figlet "Ondrya"
        return
    fi

    # Fallback hardcoded ASCII art (no external dependency required)
    cat <<'EOF'
  ___             _
 / _ \  _ __   __| | _ __  _   _   __ _
| | | || '_ \ / _` || '__|| | | | / _` |
| |_| || | | | (_| || |   | |_| || (_| |
 \___/ |_| |_|\__,_||_|    \__, | \__,_|
                            |___/
EOF
}

# Interfaces to exclude: loopback plus anything Docker creates
# (docker0, br-<network-id> bridges, veth* pairs). Add more patterns
# here if you run other container/virt stacks you want hidden too
# (e.g. virbr* for libvirt, cni0/flannel* for k8s).
EXCLUDE_IFACE_REGEX='^(lo|docker[0-9]*|br-[0-9a-f]+|veth.*)$'

print_interfaces() {
    local iface family addr
    local -A addrs=()      # iface -> comma-separated addr list
    local -a order=()      # iface names in first-seen order

    # -o = one line per address, gives us "IFACE inet/inet6 ADDR/PREFIX ..."
    while read -r _ iface family addr _; do
        [[ "$family" == "inet" || "$family" == "inet6" ]] || continue
        [[ "$iface" =~ $EXCLUDE_IFACE_REGEX ]] && continue
        # skip link-local v6 (fe80::...) - rarely useful for identification
        [[ "$family" == "inet6" && "$addr" == fe80:* ]] && continue

        addr="${addr%%/*}"
        if [[ -z "${addrs[$iface]:-}" ]]; then
            order+=("$iface")
            addrs[$iface]="$addr"
        else
            addrs[$iface]+=", $addr"
        fi
    done < <(ip -o addr show)

    for iface in "${order[@]}"; do
        printf '  %-12s %s\n' "$iface" "${addrs[$iface]}"
    done
}

main() {
    print_banner
    echo
    echo "Hostname: $(hostname)"
    echo "Interfaces:"
    print_interfaces
    echo
}

main
