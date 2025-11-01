#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# bb-tools-inst.sh - argument-driven installer
# Usage:
#   ./bb-tools-inst.sh -m    # print manual-only tools and exit
#   ./bb-tools-inst.sh -i    # perform automated installs
#   ./bb-tools-inst.sh -h    # show help
#
# Running without args prints this help and exits.

INSTALL=0
MANUAL=0

usage() {
    cat <<EOF

Usage: $0 [option]

Options:
  -i    Install tools (run the automated installation steps)
  -m    Print tools / commands that need manual installation and exit
  -h    Show this help and exit

Notes:
  - -i and -m are mutually exclusive.
  - Running the script without arguments prints this help.

EOF
}

manual_notes() {
    cat <<'MAN'

1) impacket:
   python3 -m pipx install impacket

2) enum4linux:
   git clone https://github.com/CiscoCXSecurity/enum4linux.git
   cd enum4linux
   # run with: ./enum4linux.pl <target>

3) SecLists:
   git clone --depth 1 https://github.com/danielmiessler/SecLists.git

MAN
}

while getopts ":imh" opt; do
  case "${opt}" in
    i) INSTALL=1 ;;
    m) MANUAL=1 ;;
    h) usage; exit 0 ;;
    \?) echo "Invalid option: -$OPTARG" >&2; usage; exit 2 ;;
  esac
done

# Print help if no args provided
if [[ $INSTALL -eq 0 && $MANUAL -eq 0 ]]; then
    usage
    exit 0
fi

if [[ $INSTALL -eq 1 && $MANUAL -eq 1 ]]; then
    echo "Error: -i and -m cannot be used together." >&2
    usage
    exit 2
fi

if [[ $MANUAL -eq 1 ]]; then
    manual_notes
    exit 0
fi

# If we reached here, INSTALL==1
echo
echo "Starting automated installation (this performs actions on your system)."
echo

# ---- preflight / helper ----
sudo apt update

echo "Installing essentials: python3-pip, pipx, git ..."
sudo apt install -y python3-pip pipx git || {
    echo "Failed to install essentials via apt. Aborting." >&2
    exit 1
}

# ensure pipx path is available
pipx ensurepath || true

# Python tools (pipx)
python_tools=(
    "git+https://github.com/xnl-h4ck3r/waymore.git"
    "bbot"
    "git+https://github.com/Pennyw0rth/NetExec"
)

echo
echo "Installing Python (pipx) tools..."
for python_tool in "${python_tools[@]}"; do
    echo "-> $python_tool"
    if pipx list 2>/dev/null | grep -q "$(basename "$python_tool" | sed 's/\.git$//')" ; then
        echo "   already installed; skipping"
        continue
    fi
    pipx install "$python_tool" || echo "   pipx install failed for $python_tool"
done

# apt-installable tools
apt_tools=(
    "ffuf"
    "nmap"
    "gobuster"
    "cewl"
)

echo
echo "Installing apt-available tools..."
for t in "${apt_tools[@]}"; do
    echo "-> $t"
    sudo apt install -y "$t" || echo "   apt install failed for $t"
done

# dependencies
dependencies=(
    "chromium"
    "libpcap-dev"
)

echo
echo "Installing dependencies..."
for dep in "${dependencies[@]}"; do
    echo "-> $dep"
    sudo apt install -y "$dep" || echo "   apt install failed for $dep"
done

# Go tools
go_tools=(
    "github.com/tomnomnom/anew@latest"
    "github.com/tomnomnom/unfurl@latest"
    "github.com/projectdiscovery/asnmap/cmd/asnmap@latest"
    "github.com/sensepost/gowitness@latest"
    "github.com/projectdiscovery/httpx/cmd/httpx@latest"
    "github.com/projectdiscovery/naabu/v2/cmd/naabu@latest"
    "github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
    "github.com/tomnomnom/waybackurls@latest"
    "github.com/lc/gau/v2/cmd/gau@latest"
)

echo
echo "Installing Go tools..."
if ! command -v go >/dev/null 2>&1; then
    echo "ERROR: Go not found in PATH. Install Go and re-run the script." >&2
    exit 1
fi

for g in "${go_tools[@]}"; do
    echo "-> $g"
    GO111MODULE=on go install -v "$g" || echo "   go install failed for $g"
done

# CGo-based go tools
cgo_go_tools=(
    "github.com/projectdiscovery/katana/cmd/katana@latest"
)

echo
echo "Installing CGo-based Go tools..."
for cg in "${cgo_go_tools[@]}"; do
    echo "-> $cg"
    CGO_ENABLED=1 go install -v "$cg" || echo "   go install failed for $cg"
done

echo
cat <<'FIN'
Manual follow-up (copy & paste if needed):

python3 -m pipx install impacket
git clone https://github.com/CiscoCXSecurity/enum4linux.git
git clone --depth 1 https://github.com/danielmiessler/SecLists.git
FIN

echo
echo "Automated installation finished. Inspect output for any failures."
echo

