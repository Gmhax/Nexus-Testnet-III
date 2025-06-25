#!/bin/bash

# === Colors ===
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RED='\033[1;31m'
NC='\033[0m'

# === Root check ===
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[!] Please run this script as root (sudo)${NC}"
  exit 1
fi

# === Banner ===
clear
echo -e "${YELLOW}==================================================${NC}"
echo -e "${GREEN}=       🚀 Nexus Multi-Node Setup              =${NC}"
echo -e "${YELLOW}=  Telegram: https://t.me/KatayanAirdropGnC  =${NC}"
echo -e "${GREEN}=        by: _Jheff | PNGO Boiz!!             =${NC}"
echo -e "${YELLOW}==================================================${NC}\n"

# === Disk space check ===
REQUIRED_KB=5000000  # 5 GB
FREE_KB=$(df --output=avail / | tail -n1)
if [ "$FREE_KB" -lt "$REQUIRED_KB" ]; then
  echo -e "${RED}[!] Not enough disk space (min 5 GB required). Aborting.${NC}"
  exit 1
fi

# === Directories ===
WORKDIR="/root/nexus-prover"
LOGDIR="/mnt/storage/nexus-logs"
mkdir -p "$WORKDIR" "$LOGDIR"
cd "$WORKDIR" || exit 1

# === Dependencies ===
apt update && apt upgrade -y
apt install -y screen curl wget build-essential pkg-config libssl-dev git-all protobuf-compiler ca-certificates

# === Install Rust ===
if ! command -v rustup &>/dev/null; then
  echo -e "${GREEN}[*] Installing Rust...${NC}"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi
source "$HOME/.cargo/env"
echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> "$HOME/.bashrc"
source "$HOME/.bashrc"
rustup target add riscv32i-unknown-none-elf

# === Install Nexus CLI ===
echo -e "${GREEN}[*] Downloading Nexus CLI...${NC}"
yes | curl -s https://cli.nexus.xyz/ | bash

# === Find nexus-network ===
echo -e "${GREEN}[*] Searching for nexus-network binary...${NC}"
NEXUS_BIN=$(find / -type f -name "nexus-network" -perm /u+x 2>/dev/null | head -n 1)

if [ -x "$NEXUS_BIN" ]; then
  echo -e "${GREEN}[✓] Found at: $NEXUS_BIN${NC}"
  cp "$NEXUS_BIN" /usr/local/bin/
  chmod +x /usr/local/bin/nexus-network
else
  echo -e "${RED}[!] nexus-network not found. Aborting.${NC}"
  exit 1
fi

# === How many nodes ===
echo -e "${YELLOW}[?] How many node IDs to run? (1–10)${NC}"
read -rp "> " NODE_COUNT
if ! [[ "$NODE_COUNT" =~ ^[1-9]$|^10$ ]]; then
  echo -e "${RED}[!] Invalid input. Must be 1–10.${NC}"
  exit 1
fi

# === Input node IDs ===
NODE_IDS=()
for ((i=1;i<=NODE_COUNT;i++)); do
  echo -e "${YELLOW}Enter node-id #$i:${NC}"
  read -rp "> " NODE_ID
  if [ -z "$NODE_ID" ]; then
    echo -e "${RED}[!] Empty input. Aborting.${NC}"
    exit 1
  fi
  NODE_IDS+=("$NODE_ID")
done

# === Launch nodes with autorestart ===
for ((i=0;i<NODE_COUNT;i++)); do
  SESSION="nexus$((i+1))"
  NODE_ID="${NODE_IDS[$i]}"
  LOGFILE="$LOGDIR/log_$SESSION.txt"

  # Kill any old screen
  screen -S "$SESSION" -X quit >/dev/null 2>&1 || true

  echo -e "${GREEN}[*] Launching node-id $NODE_ID in screen '$SESSION'...${NC}"

  # Launch screen with infinite restart loop
  screen -dmS "$SESSION" bash -c "cd $WORKDIR && while true; do \
    echo \"[\$(date)] Starting node-id $NODE_ID\" >> \"$LOGFILE\"; \
    nexus-network start --node-id $NODE_ID 2>&1 | tee -a \"$LOGFILE\"; \
    echo \"[\$(date)] node-id $NODE_ID crashed. Restarting in 10s...\" >> \"$LOGFILE\"; \
    sleep 10; \
  done"

  sleep 2

  if screen -list | grep -q "$SESSION"; then
    echo -e "${GREEN}[✓] '$SESSION' started successfully for node-id $NODE_ID.${NC}"
  else
    echo -e "${RED}[✗] Failed to start screen session '$SESSION'.${NC}"
  fi
done

# === Final instructions ===
echo -e "${YELLOW}\n[i] To detach: CTRL+A then D"
echo -e "[i] To reattach: screen -r nexus1 (or nexus2...)"
echo -e "[i] To stop: screen -XS nexusX quit"
echo -e "[i] Logs saved at: $LOGDIR"
echo -e "[i] To delete everything: rm -rf $WORKDIR${NC}"
