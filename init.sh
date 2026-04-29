#!/usr/bin/env bash
# Ubuntu Server initialization script (compatible with 22.04 / 24.04)
#
# Run without cloning:
#   sudo bash <(curl -fsSL https://raw.githubusercontent.com/recluse90s/ubuntu-init-script/master/init.sh)
#
# Run locally:
#   sudo bash init.sh

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; exit 1; }
section() { echo -e "\n${BOLD}══════════════════════════════════════${RESET}";
            echo -e "${BOLD} $* ${RESET}";
            echo -e "${BOLD}══════════════════════════════════════${RESET}"; }

# Press Enter to accept the default (Y)
confirm() {
    read -rp "$(echo -e "${YELLOW}${1:-Continue?} [Y/n] ${RESET}")" ans
    [[ "${ans:-Y}" =~ ^[Yy]$ ]]
}

[[ $EUID -ne 0 ]] && error "Please run as root or with sudo"

# ============================================================
# 1. apt update
# ============================================================
section "1/6  Update package index"
apt update
success "Package index updated"

# ============================================================
# 2. apt upgrade
# ============================================================
section "2/6  Upgrade system packages"
info "Interactive prompts may appear for config files or service restarts."
if confirm "Run system upgrade?"; then
    apt upgrade -y
    success "System upgrade complete"
else
    warn "Skipped system upgrade"
fi

# ============================================================
# 3. Chinese locale
# ============================================================
section "3/7  Chinese locale"
if confirm "Install Chinese language pack and set locale to zh_CN.UTF-8?"; then
    apt install -y language-pack-zh-hans
    update-locale LANG=zh_CN.UTF-8
    export LANG=zh_CN.UTF-8
    success "Locale:   $(locale | grep '^LANG=')"
else
    warn "Skipped locale setup"
fi

# ============================================================
# 4. Timezone
# ============================================================
section "4/7  Set timezone to Asia/Shanghai"
if confirm "Set timezone to Asia/Shanghai?"; then
    timedatectl set-timezone Asia/Shanghai
    success "Timezone: $(timedatectl | grep 'Time zone')"
else
    warn "Skipped timezone setup"
fi

# ============================================================
# 5. BBR
# ============================================================
section "5/7  TCP BBR congestion control"
CURRENT_CC=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "unknown")
info "Current congestion control algorithm: ${CURRENT_CC}"

if [[ "$CURRENT_CC" == "bbr" ]]; then
    success "BBR is already enabled, nothing to do"
elif confirm "Enable BBR congestion control?"; then
    # If bbr isn't in tcp_available_congestion_control, the module isn't loaded yet
    if ! sysctl net.ipv4.tcp_available_congestion_control | grep -qw bbr; then
        modprobe tcp_bbr || error "Failed to load tcp_bbr — kernel may not support BBR"
    fi
    echo "tcp_bbr" > /etc/modules-load.d/tcp-bbr.conf
    # Prefix 90- loads after distro defaults (10-) but before 99-sysctl.conf,
    # keeping it clearly in the "local admin" range without name-order tricks
    cat > /etc/sysctl.d/90-bbr.conf <<'EOF'
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF
    sysctl --system > /dev/null
    NEW_CC=$(sysctl -n net.ipv4.tcp_congestion_control)
    if [[ "$NEW_CC" == "bbr" ]]; then
        success "BBR enabled (algorithm: ${NEW_CC})"
    else
        warn "BBR may take effect after reboot (current: ${NEW_CC})"
    fi
else
    warn "Skipped BBR setup"
fi

# ============================================================
# 6. Docker
# ============================================================
section "6/7  Install Docker CE"

if command -v docker &>/dev/null; then
    success "Docker is already installed, skipping"
    docker version
elif confirm "Install Docker CE following the official Docker documentation?"; then

    # Remove conflicting packages (only those actually installed)
    # shellcheck disable=SC2046
    apt remove -y $(dpkg --get-selections \
        docker.io docker-compose docker-compose-v2 \
        docker-doc podman-docker containerd runc \
        2>/dev/null | cut -f1) 2>/dev/null || true

    apt install -y ca-certificates curl

    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    # DEB822 format — current official standard
    tee /etc/apt/sources.list.d/docker.sources > /dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

    apt update
    apt install -y docker-ce docker-ce-cli containerd.io \
                   docker-buildx-plugin docker-compose-plugin

    # deb postinst usually handles this, but explicit is safer
    systemctl enable --now docker

    # docker group = passwordless docker = effective root; confirm before adding
    REAL_USER="${SUDO_USER:-}"
    if [[ -n "$REAL_USER" && "$REAL_USER" != "root" ]]; then
        warn "docker group membership = root equivalent (host fs can be mounted via socket)."
        if confirm "Add '${REAL_USER}' to the docker group?"; then
            usermod -aG docker "$REAL_USER"
            warn "Done — re-login to apply"
        else
            info "Skipped. To add manually: sudo usermod -aG docker ${REAL_USER}"
        fi
    fi

    if docker version &>/dev/null; then
        success "Docker installation verified"
        docker version
    else
        warn "Docker verification failed — check: systemctl status docker"
    fi

else
    warn "Skipped Docker installation"
fi

# ============================================================
# 7. apt autoremove
# ============================================================
section "7/7  Clean up unused packages"
apt autoremove -y
success "Cleanup complete"

echo -e "\n${GREEN}${BOLD}✔  Initialization complete!${RESET}"
echo -e "${YELLOW}A reboot is recommended to apply all changes:${RESET}"
echo -e "    ${CYAN}sudo reboot${RESET}\n"
