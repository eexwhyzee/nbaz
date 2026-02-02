#!/usr/bin/env bash
set -euo pipefail

platform=$(uname -ms)

# Reset
Color_Off=''
Red=''
Green=''
Dim=''
Bold_White=''

if [[ -t 1 ]]; then
  Color_Off='\033[0m'
  Red='\033[0;31m'
  Green='\033[0;32m'
  Dim='\033[0;2m'
  Bold_White='\033[1m'
fi

error() {
  echo -e "${Red}error${Color_Off}:" "$@" >&2
  exit 1
}

info() {
  echo -e "${Dim}$@${Color_Off}"
}

info_bold() {
  echo -e "${Bold_White}$@${Color_Off}"
}

success() {
  echo -e "${Green}$@${Color_Off}"
}

usage() {
  cat <<'EOF'
Install nbaz to a local bin directory.

Usage:
  ./install.sh [--prefix DIR] [--bindir DIR] [--optimize MODE] [--no-build]

Options:
  --prefix DIR     Install prefix (default: $HOME/.local)
  --bindir DIR     Bin directory (default: <prefix>/bin)
  --optimize MODE  Zig optimize mode (default: ReleaseSafe)
  --no-build       Skip zig build step
  -h, --help       Show this help
EOF
}

prefix="${PREFIX:-$HOME/.local}"
bindir="${BINDIR:-}"
optimize="${OPTIMIZE:-ReleaseSafe}"
do_build=1

if [[ ${OS:-} = Windows_NT ]]; then
  error "Windows is not supported by this installer. Use WSL or build manually."
fi

case "$platform" in
  'Darwin x86_64'|'Darwin arm64')
    os=darwin
    ;;
  'Linux x86_64'|'Linux aarch64'|'Linux arm64')
    os=linux
    ;;
  *)
    error "Unsupported platform: $platform"
    ;;
esac

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix)
      prefix="${2:-}"
      shift 2
      ;;
    --bindir)
      bindir="${2:-}"
      shift 2
      ;;
    --optimize)
      optimize="${2:-}"
      shift 2
      ;;
    --no-build)
      do_build=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "${bindir}" ]]; then
  bindir="${prefix}/bin"
fi

if ! command -v zig >/dev/null 2>&1; then
  error "zig is required to build nbaz. Install Zig 0.15.x and retry."
fi

if [[ "${do_build}" -eq 1 ]]; then
  info "Building nbaz (${os})..."
  zig build -Doptimize="${optimize}"
fi

if [[ ! -f "zig-out/bin/nbaz" ]]; then
  echo "Binary not found at zig-out/bin/nbaz. Run 'zig build' first." >&2
  exit 1
fi

mkdir -p "${bindir}"
if command -v install >/dev/null 2>&1; then
  install -m 0755 zig-out/bin/nbaz "${bindir}/nbaz"
else
  cp zig-out/bin/nbaz "${bindir}/nbaz"
  chmod 0755 "${bindir}/nbaz"
fi

success "Installed nbaz to ${bindir}/nbaz"
case ":${PATH}:" in
  *":${bindir}:"*) ;;
  *)
    info_bold "Note: ${bindir} is not on your PATH."
    ;;
esac
