# Parallel Credentialed Service Sweep

```bash
bash -c 'hosts="192.168.118.129 192.168.118.130 192.168.118.131"; declare -A ports=([nfs]=2049 [winrm]=5985 [ftp]=21 [ssh]=22 [smb]=445 [rdp]=3389 [ldap]=389 [mssql]=1433 [vnc]=5900 [wmi]=135); for h in $hosts; do for s in "${!ports[@]}"; do (timeout 2 bash -c "echo >/dev/tcp/$h/${ports[$s]}" 2>/dev/null && timeout 15 nxc $s $h -u $user1 -p $pass1 --timeout 15 2>/dev/null) & done; done; wait'
```

A single-line Bash utility for quickly validating a set of credentials against multiple hosts across common Windows/network services — skipping any service whose port isn't open, throttling concurrency so it scales safely to large host lists, and running checks in the background for speed.

## What it does

Given a list of target hosts, a set of services with well-known ports, and a username/password pair, the script:

1. **Probes each host:port pair** using Bash's built-in `/dev/tcp` pseudo-device to confirm the port is open before doing anything else.
2. **Skips closed/filtered ports** — if the TCP connect fails or times out, `nxc` (NetExec) is never invoked for that host/service combination.
3. **Throttles concurrency** with a hard cap on simultaneously running jobs plus a small stagger between launches, so large host lists don't overwhelm targets or trigger connection resets.
4. **Authenticates via NetExec (`nxc`)** against every open, reachable service using the supplied credentials.

This avoids the noise and wasted time of blindly firing `nxc` at every service on every host regardless of whether the port is even listening, and avoids overloading targets when scanning many hosts at once.

## Services covered

| Service | Port |
|---------|------|
| FTP     | 21   |
| SSH     | 22   |
| LDAP    | 389  |
| SMB     | 445  |
| WMI     | 135  |
| MSSQL   | 1433 |
| RDP     | 3389 |
| NFS     | 2049 |
| VNC     | 5900 |
| WinRM   | 5985 |

## Usage

Set your credentials as environment variables, then run the sweep:

```bash
bash -c 'hosts="192.168.118.129 192.168.118.130 192.168.118.131"; declare -A ports=([nfs]=2049 [winrm]=5985 [ftp]=21 [ssh]=22 [smb]=445 [rdp]=3389 [ldap]=389 [mssql]=1433 [vnc]=5900 [wmi]=135); for h in $hosts; do for s in "${!ports[@]}"; do (timeout 2 bash -c "echo >/dev/tcp/$h/${ports[$s]}" 2>/dev/null && timeout 15 nxc $s $h -u $user1 -p $pass1 --timeout 15 2>/dev/null) & done; done; wait'
```

### Customizing targets

Edit the `hosts` variable to a space-separated list of IPs or hostnames:

```bash
hosts="10.10.10.1 10.10.10.2 10.10.10.3"
```

### Adjusting timeouts

- `timeout 2` on the `/dev/tcp` probe — how long to wait for a TCP connect before declaring the port closed. Increase on slow or high-latency networks to avoid false negatives.
- `timeout 15` on the `nxc` call — how long to allow each authentication attempt to run before killing it.

## Requirements

- Bash (uses `/dev/tcp`, associative arrays, and process substitution — not POSIX `sh` compatible)
- [NetExec](https://github.com/Pennyw0rth/NetExec) (`nxc`) installed and available on `$PATH`
- Network reachability to all target hosts

## Design notes

- **Why `bash -c '...'` instead of running inline?** Wrapping the whole routine in a non-interactive subshell suppresses Bash job-control notifications (`[1] 12345`, `Done`, etc.) that would otherwise clutter the output when backgrounding dozens of jobs. `export`-ing the credentials beforehand makes them available to the subshell's environment without needing to pass them as positional arguments.
- **Why `/dev/tcp` instead of `nmap`?** It keeps the tool self-contained with zero external dependencies beyond Bash and `nxc`. For larger host lists, a single batched `nmap` scan feeding into `nxc` is faster and less "noisy" on the wire (one SYN scan vs. N individual full TCP connects) — worth switching to at scale.
- **Concurrency model:** every host/service pair gets its own subshell and background job, so runtime is bounded by the slowest individual check (≤ 17s: 2s probe + 15s auth) rather than the sum of all checks.

## Disclaimer

Intended for use in authorized lab and assessment environments only (e.g. HTB, OSCP-style labs, or engagements with explicit permission). Running credential checks against systems you don't own or have authorization to test is illegal.
