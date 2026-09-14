#!/bin/bash
#
# ondrya-banner.sh
# Prints an "Ondrya" ASCII banner followed by the hostname and current IP.
# Intended to run on login (e.g. via /etc/profile.d/) or as an MOTD script
# baked into the Debian gold image.

set -euo pipefail

generate_banner() {
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

# Center a block of text (read from stdin) horizontally based on the
# current terminal width. Falls back to 80 cols when not attached to
# a tty (e.g. run non-interactively) or when tput is unavailable.
center_text() {
    local term_width
    term_width=$(tput cols 2>/dev/null) || term_width=80
    [[ "$term_width" =~ ^[0-9]+$ ]] || term_width=80

    local lines=()
    local line
    local maxlen=0
    while IFS= read -r line; do
        lines+=("$line")
        (( ${#line} > maxlen )) && maxlen=${#line}
    done

    local pad=$(( (term_width - maxlen) / 2 ))
    (( pad < 0 )) && pad=0

    for line in "${lines[@]}"; do
        printf '%*s%s\n' "$pad" "" "$line"
    done
}

print_banner() {
    generate_banner | center_text
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

# Filesystem types to exclude from disk report - pseudo/virtual mounts
# that don't represent real disk usage (tmpfs, proc/sys, overlay layers
# used by Docker/containerd, squashfs snap mounts, etc).
EXCLUDE_FSTYPE_REGEX='^(tmpfs|devtmpfs|overlay|squashfs|proc|sysfs|cgroup2?|devpts|mqueue|fuse.*|rpc_pipefs|tracefs|debugfs|configfs|autofs|nsfs|binfmt_misc)$'

print_disks() {
    local fs type size used avail pcent mount
    # -T = include filesystem type column
    while read -r fs type size used avail pcent mount; do
        [[ "$fs" == "Filesystem" ]] && continue          # header row
        [[ "$type" =~ $EXCLUDE_FSTYPE_REGEX ]] && continue
        # skip Docker's internal overlay mounts by path too, in case
        # they report as a real fstype (e.g. ext4 on a loop device)
        [[ "$mount" == /var/lib/docker* ]] && continue
        printf '  %-20s %-6s %6s used of %-6s (%s) -> %s\n' \
            "$fs" "$type" "$used" "$size" "$pcent" "$mount"
    done < <(df -hT --output=source,fstype,size,used,avail,pcent,target 2>/dev/null \
              || df -hT)
}

print_memory() {
    # `free -h` line 2 = Mem: total used free shared buff/cache available
    local total used free_ shared cache avail
    read -r _ total used free_ shared cache avail < <(free -h | awk '/^Mem:/{print}')
    printf '  Total: %-8s Used: %-8s Available: %-8s (free: %s)\n' \
        "$total" "$used" "$avail" "$free_"
}

main() {
    print_banner
    echo
    echo "Hostname: $(hostname)"
    echo "Interfaces:"
    print_interfaces
    echo
    echo "Disks:"
    print_disks
    echo
    echo "Memory:"
    print_memory
    echo
}

main
