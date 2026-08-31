#!/usr/bin/env bash
#
# sweep.sh — Parallel credentialed service sweep using NetExec (nxc)
#
# Probes each host/service port pair, skips closed ports, and only runs
# nxc against services that are actually open — with throttled concurrency
# so it scales safely to large host lists.
#
# Usage:
#   ./sweep.sh [-j max_jobs] [-d launch_delay] <user> <pass> <host1> [host2] [host3] ...
#
# Options:
#   -j N   Max number of concurrent probe/nxc jobs (default: 10)
#   -d N   Seconds to sleep between launching each job (default: 0.3)
#
# Examples:
#   ./sweep.sh shannon 'GoldSeagull123' 192.168.118.129 192.168.118.130 192.168.118.131
#   ./sweep.sh -j 20 -d 0.1 shannon 'GoldSeagull123' 192.168.118.129 192.168.118.130

set -u

usage() {
    echo "Usage: $0 [-j max_jobs] [-d launch_delay] <user> <pass> <host1> [host2] [host3] ..." >&2
    exit 1
}

# Defaults — overridable via -j / -d
max_jobs=10
launch_delay=0.3

while getopts ":j:d:" opt; do
    case "$opt" in
        j) max_jobs="$OPTARG" ;;
        d) launch_delay="$OPTARG" ;;
        *) usage ;;
    esac
done
shift $((OPTIND - 1))

if [ "$#" -lt 3 ]; then
    usage
fi

user1="$1"
pass1="$2"
shift 2
hosts="$*"

declare -A ports=(
    [nfs]=2049
    [winrm]=5985
    [ftp]=21
    [ssh]=22
    [smb]=445
    [rdp]=3389
    [ldap]=389
    [mssql]=1433
    [vnc]=5900
    [wmi]=135
)

for h in $hosts; do
    for s in "${!ports[@]}"; do
        while [ "$(jobs -rp | wc -l)" -ge "$max_jobs" ]; do
            wait -n
        done
        (
            timeout 15 bash -c "echo >/dev/tcp/$h/${ports[$s]}" 2>/dev/null \
                && timeout 15 nxc "$s" "$h" -u "$user1" -p "$pass1" --timeout 15 2>/dev/null
        ) &
        sleep "$launch_delay"
    done
done

wait
