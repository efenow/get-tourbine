#!/usr/bin/env bash
set -euo pipefail

REPOSITORY="https://github.com/efenow/tourbine"
INSTALL_DIR="${TOURBINE_DIR:-$HOME/.tourbine}"

MUTED='\033[0;2m'
RED='\033[0;31m'
ORANGE='\033[38;5;214m'
GREEN='\033[0;32m'
BLUE='\033[38;2;0;82;184m'
SLATE='\033[38;2;55;65;81m'
WHITE='\033[38;2;255;255;255m'
NC='\033[0m'

usage() {
    cat <<EOF
Tourbine Installer

Usage: install.sh [options]

Options:
    -h, --help              Display this help message
    -v, --version <version> Install a specific GitHub release or tag
    -d, --dir <path>        Install into a specific directory

Examples:
    curl -fsSL https://get.tourbine.example/install.sh | bash
    curl -fsSL https://get.tourbine.example/install.sh | bash -s -- --version v1.0.0
    curl -fsSL https://get.tourbine.example/install.sh | bash -s -- --dir "\$HOME/apps/tourbine"
EOF
}

print_logo() {
    printf "%b" "${BLUE}"
    printf '     ######\n'
    printf '     ########'
    printf "%b" "${WHITE}"
    printf '                                       #\n'
    printf "%b      #######" "${BLUE}"
    printf "%b            ##                         ##       ##\n" "${WHITE}"
    printf "%b       ######" "${BLUE}"
    printf "%b           #####  #####  ##   ## ##### ######   ## ######   #####\n" "${WHITE}"
    printf "%b   #####**##             " "${SLATE}"
    printf "%b##   ##   ## ##   ## ###   ##   ### ## ##   ## ##   ##\n" "${WHITE}"
    printf "%b ##################      " "${SLATE}"
    printf "%b##   ##   ## ##   ## ##    ##   %%## ## ##   ## ##\n" "${WHITE}"
    printf "%b#######  ##########      " "${SLATE}"
    printf "%b####  #####   ###### ##    #######  ## ##   ##  #####\n" "${WHITE}"
    printf "%b #####    ########\n" "${SLATE}"
    printf "%b  ###        #%%\n" "${SLATE}"
    printf "%b" "${NC}"
}

error() {
    printf "%b\n" "${RED}Error: $1${NC}" >&2
    exit 1
}

version="main"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -v|--version)
            [[ -n "${2:-}" ]] || error "--version requires a version argument"
            version="${2#v}"
            shift 2
            ;;
        -d|--dir)
            [[ -n "${2:-}" ]] || error "--dir requires a path argument"
            INSTALL_DIR="$2"
            shift 2
            ;;
        *)
            error "Unknown option '$1'"
            ;;
    esac
done

print_logo
printf "\n%bTourbine installer%b\n\n" "${ORANGE}" "${NC}"

command -v curl >/dev/null 2>&1 || error "'curl' is required but not installed"
command -v tar >/dev/null 2>&1 || error "'tar' is required but not installed"

ask() {
    local answer

    if [[ ! -r /dev/tty ]]; then
        error "Interactive confirmation is required. Install Docker first: https://docs.docker.com/engine/install/"
    fi

    read -r -p "$1 [y/N] " answer < /dev/tty
    [[ "$answer" =~ ^[Yy]$ ]]
}

DOCKER=(docker)
DISTRO_ID="unknown"
DISTRO_NAME="unknown Linux"

if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    DISTRO_ID="${ID:-unknown}"
    DISTRO_NAME="${PRETTY_NAME:-$DISTRO_ID}"
fi

install_docker() {
    command -v sudo >/dev/null 2>&1 || error "'sudo' is required to install Docker"
    printf "%bDetected: %s%b\n" "${MUTED}" "$DISTRO_NAME" "${NC}"

    case "$DISTRO_ID" in
        debian|ubuntu|linuxmint)
            sudo apt-get update
            sudo apt-get install -y docker.io docker-compose-plugin \
                || sudo apt-get install -y docker.io docker-compose
            ;;
        fedora|rhel|centos|rocky|almalinux)
            printf "%bInstalling Docker from Docker's official installer%b\n" "${MUTED}" "${NC}"
            docker_install_script="$(mktemp)"
            curl -fsSL https://get.docker.com -o "$docker_install_script"
            sudo sh "$docker_install_script"
            rm -f "$docker_install_script"
            ;;
        arch|manjaro)
            sudo pacman -Sy --needed --noconfirm docker docker-compose
            ;;
        opensuse*|sles)
            sudo zypper --non-interactive install docker docker-compose
            ;;
        gentoo)
            sudo emerge --ask=n app-containers/docker app-containers/docker-compose
            ;;
        slackware)
            error "Slackware requires a manual Docker installation: https://docs.docker.com/engine/install/binaries/"
            ;;
        *)
            error "Unsupported Linux distribution: $DISTRO_NAME. Install Docker manually: https://docs.docker.com/engine/install/"
            ;;
    esac
}

if ! command -v docker >/dev/null 2>&1; then
    [[ "$(uname -s)" == "Linux" ]] || error "Docker is not installed. Install Docker Desktop: https://docs.docker.com/get-docker/"
    ask "Docker is not installed. Install it now?" || error "Docker is required"
    install_docker
fi

command -v docker >/dev/null 2>&1 || error "Docker installation failed"

if ! docker compose version >/dev/null 2>&1 && ! docker-compose version >/dev/null 2>&1; then
    ask "Docker Compose is missing. Install it now?" || error "Docker Compose is required"

    case "$DISTRO_ID" in
        debian|ubuntu|linuxmint)
            sudo apt-get update
            sudo apt-get install -y docker-compose-plugin \
                || sudo apt-get install -y docker-compose
            ;;
        fedora|rhel|centos|rocky|almalinux)
            sudo dnf install -y docker-compose-plugin \
                || sudo dnf install -y docker-compose
            ;;
        arch|manjaro)
            sudo pacman -Sy --needed --noconfirm docker-compose
            ;;
        opensuse*|sles)
            sudo zypper --non-interactive install docker-compose
            ;;
        gentoo)
            sudo emerge --ask=n app-containers/docker-compose
            ;;
        *)
            error "Cannot install Docker Compose automatically on $DISTRO_NAME: https://docs.docker.com/compose/install/"
            ;;
    esac
fi

COMPOSE_MODE="plugin"
if ! docker compose version >/dev/null 2>&1; then
    docker-compose version >/dev/null 2>&1 || error "Docker Compose is required: https://docs.docker.com/compose/install/"
    COMPOSE_MODE="legacy"
fi

if ! docker info >/dev/null 2>&1; then
    if command -v sudo >/dev/null 2>&1 && sudo docker info >/dev/null 2>&1; then
        DOCKER=(sudo docker)
    else
        if command -v systemctl >/dev/null 2>&1 && command -v sudo >/dev/null 2>&1; then
            if ask "Docker daemon is not running. Start it now?"; then
                sudo systemctl start docker
            fi
        elif command -v rc-service >/dev/null 2>&1 && command -v sudo >/dev/null 2>&1; then
            if ask "Docker daemon is not running. Start it now?"; then
                sudo rc-service docker start
            fi
        elif command -v service >/dev/null 2>&1 && command -v sudo >/dev/null 2>&1; then
            if ask "Docker daemon is not running. Start it now?"; then
                sudo service docker start
            fi
        fi

        if docker info >/dev/null 2>&1; then
            DOCKER=(docker)
        elif command -v sudo >/dev/null 2>&1 && sudo docker info >/dev/null 2>&1; then
            DOCKER=(sudo docker)
        else
            error "Cannot access Docker. Start Docker and grant your user access to /var/run/docker.sock"
        fi
    fi
fi

run_compose() {
    if [[ "$COMPOSE_MODE" == "plugin" ]]; then
        "${DOCKER[@]}" compose "$@"
    elif [[ "${DOCKER[0]}" == "sudo" ]]; then
        sudo docker-compose "$@"
    else
        docker-compose "$@"
    fi
}

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/tourbine-install.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT

if [[ "$version" == "main" ]]; then
    archive_url="$REPOSITORY/archive/refs/heads/main.tar.gz"
    release_label="main"
else
    archive_url="$REPOSITORY/archive/refs/tags/v${version}.tar.gz"
    release_label="v${version}"
fi

download_source() {
    printf "%bDownloading Tourbine %s%b\n" "${MUTED}" "$release_label" "${NC}"
    curl -fsSL "$archive_url" -o "$tmp_dir/tourbine.tar.gz"
    rm -rf "$tmp_dir/source"
    mkdir -p "$tmp_dir/source"
    tar -xzf "$tmp_dir/tourbine.tar.gz" --strip-components=1 -C "$tmp_dir/source"

    mkdir -p "$INSTALL_DIR"
    cp -R "$tmp_dir/source/." "$INSTALL_DIR/"
}

if [[ -e "$INSTALL_DIR/docker-compose.yml" ]]; then
    printf "%bUsing existing Tourbine installation at %s%b\n" "${MUTED}" "$INSTALL_DIR" "${NC}"
else
    download_source
fi

printf "%bBuilding and starting Tourbine%b\n" "${MUTED}" "${NC}"
if ! (
    cd "$INSTALL_DIR"
    run_compose up -d --build
); then
    printf "%bBuild failed. This may be a dependency conflict.%b\n" "${RED}" "${NC}" >&2
    if ask "Download the selected Tourbine source again and retry without Docker cache?"; then
        download_source
        (
            cd "$INSTALL_DIR"
            run_compose build --no-cache
            run_compose up -d
        )
    else
        error "Tourbine build failed"
    fi
fi

printf "\n%bTourbine installed successfully.%b\n\n" "${GREEN}" "${NC}"
printf "  %bOpen%b  http://localhost:3000\n" "${MUTED}" "${NC}"
printf "  %bPath%b  %s\n\n" "${MUTED}" "${NC}" "$INSTALL_DIR"
printf "%bCreate your first admin account at /dashboard/setup.%b\n" "${MUTED}" "${NC}"
printf "%bManage Tourbine with: cd %s && docker compose ps%b\n" "${MUTED}" "$INSTALL_DIR" "${NC}"
