
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
A Bash script for quickly validating a set of credentials against multiple hosts across common Windows/network services — skipping any service whose port isn't open, throttling concurrency so it scales safely to large host lists, and running checks in the background for speed.

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

The sweep is packaged as `credwalk.sh`, taking the username, password, and target hosts as command-line arguments, with optional flags for concurrency and timeout tuning:

```bash
chmod +x credwalk.sh
./credwalk.sh [-j max_jobs] [-d launch_delay] [-t probe_timeout] [-n nxc_timeout] <user> <pass> <host1> [host2] [host3] ...
```

Example (defaults):

```bash
./credwalk.sh bob 'b0bsp4ss1sth3b3st' 192.168.118.129 192.168.118.130 192.168.118.131
```

Example (custom concurrency and timeouts — higher job cap, shorter delay, faster port probe, longer nxc window):

```bash
./credwalk.sh -j 20 -d 0.1 -t 5 -n 20 bob 'b0bsp4ss1sth3b3st' 192.168.118.129 192.168.118.130 192.168.118.131
```

Any number of hosts can be passed — the script loops over every host/service pair automatically.

> **Note:** Quote the password if it contains special characters (`!`, `$`, spaces, etc.) to prevent the shell from interpreting them.

### Adjusting concurrency and timeouts

- `-j N` — maximum number of concurrent probe/`nxc` jobs (default `10`). Lower this for smaller or more sensitive environments; raise it on stable networks for more throughput.
- `-d N` — seconds to sleep between launching each job (default `0.3`), smoothing bursts within the concurrency cap. Accepts fractional values (e.g. `0.1`).
- `-t N` — seconds to wait on the `/dev/tcp` port probe before declaring it closed (default `15`). Lower this on fast, low-latency networks to skip closed ports quicker; raise it on slow or high-latency links to avoid false negatives.
- `-n N` — seconds to allow each `nxc` authentication attempt to run before it's killed (default `15`). Raise this for slower or heavily loaded services (SMB, WinRM in particular can be sluggish); lower it to fail fast and speed up the overall sweep.

These defaults are tuned to scale safely to larger host lists without overwhelming targets or triggering connection resets — see [Design notes](#design-notes) below.

## Requirements

- Bash (uses `/dev/tcp`, associative arrays, and process substitution — not POSIX `sh` compatible)
- [NetExec](https://github.com/Pennyw0rth/NetExec) (`nxc`) installed and available on `$PATH`
- Network reachability to all target hosts

## Design notes

- **Why a standalone script instead of a one-liner?** Taking `user`, `pass`, and `hosts` as arguments avoids hardcoding credentials or targets into the file, and running as a real script (rather than pasting into `bash -c '...'`) means it can be dropped into a `$PATH` directory, version-controlled, and reused without re-typing a long inline command each time.
- **Why flags instead of editing the script?** `-j`/`-d`/`-t`/`-n` let you tune concurrency and timeouts per-run (e.g. more aggressive on a stable internal lab, more conservative against a fragile or monitored target) without modifying the script itself — keeping it safe to reuse as-is across engagements.
- **Why `/dev/tcp` instead of `nmap`?** It keeps the tool self-contained with zero external dependencies beyond Bash and `nxc`. For very large host lists, a single batched `nmap` scan feeding into `nxc` is faster and less "noisy" on the wire (one SYN scan vs. many individual full TCP connects) — worth switching to at scale.
- **Concurrency model:** every host/service pair gets its own subshell and background job, but a `jobs -rp | wc -l` check before each launch caps how many run simultaneously (`max_jobs`), with `wait -n` used to free a slot as soon as any job finishes. A small `sleep` between launches further smooths bursts. This keeps runtime scaling roughly linearly with total host/service pairs instead of firing everything at once, which is what caused connection resets (`Connection reset by peer`) against some services (SMB and WinRM in particular) when scanning many targets in parallel with no cap.

## Disclaimer

Intended for use in authorized lab and assessment environments only (e.g. HTB, OSCP-style labs, or engagements with explicit permission). Running credential checks against systems you don't own or have authorization to test is illegal.
