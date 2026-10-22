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
command -v docker >/dev/null 2>&1 || error "Docker is required: https://docs.docker.com/engine/install/"
docker compose version >/dev/null 2>&1 || error "Docker Compose is required"

if [[ -e "$INSTALL_DIR/docker-compose.yml" ]]; then
    error "Tourbine is already installed at $INSTALL_DIR"
fi

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/tourbine-install.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT

if [[ "$version" == "main" ]]; then
    archive_url="$REPOSITORY/archive/refs/heads/main.tar.gz"
    release_label="main"
else
    archive_url="$REPOSITORY/archive/refs/tags/v${version}.tar.gz"
    release_label="v${version}"
fi

printf "%bDownloading Tourbine %s%b\n" "${MUTED}" "$release_label" "${NC}"
curl -fsSL "$archive_url" -o "$tmp_dir/tourbine.tar.gz"
mkdir -p "$tmp_dir/source"
tar -xzf "$tmp_dir/tourbine.tar.gz" --strip-components=1 -C "$tmp_dir/source"

mkdir -p "$INSTALL_DIR"
cp -R "$tmp_dir/source/." "$INSTALL_DIR/"

printf "%bBuilding and starting Tourbine%b\n" "${MUTED}" "${NC}"
(
    cd "$INSTALL_DIR"
    docker compose up -d --build
)

printf "\n%bTourbine installed successfully.%b\n\n" "${GREEN}" "${NC}"
printf "  %bOpen%b  http://localhost:3000\n" "${MUTED}" "${NC}"
printf "  %bPath%b  %s\n\n" "${MUTED}" "${NC}" "$INSTALL_DIR"
printf "%bCreate your first admin account at /dashboard/setup.%b\n" "${MUTED}" "${NC}"
printf "%bManage Tourbine with: cd %s && docker compose ps%b\n" "${MUTED}" "$INSTALL_DIR" "${NC}"
