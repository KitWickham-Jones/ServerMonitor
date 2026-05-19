#!/usr/bin/env bash
set -euo pipefail

INSTALL_USER="node_exporter"
BIN_PATH="/usr/local/bin/node_exporter"
SERVICE_PATH="/etc/systemd/system/node_exporter.service"

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root (sudo ./install.sh)" >&2
  exit 1
fi

# Detect arch
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)  ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
  armv7l)  ARCH="armv7" ;;
  *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;;
esac

# Get latest version from GitHub
VERSION=$(curl -fsSL https://api.github.com/repos/prometheus/node_exporter/releases/latest \
  | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')

echo "Installing node_exporter v${VERSION} (${ARCH})..."

TARBALL="node_exporter-${VERSION}.linux-${ARCH}.tar.gz"
URL="https://github.com/prometheus/node_exporter/releases/download/v${VERSION}/${TARBALL}"

curl -fsSL "$URL" -o "/tmp/${TARBALL}"
tar -xzf "/tmp/${TARBALL}" -C /tmp
mv "/tmp/node_exporter-${VERSION}.linux-${ARCH}/node_exporter" "$BIN_PATH"
chmod +x "$BIN_PATH"
rm -rf "/tmp/${TARBALL}" "/tmp/node_exporter-${VERSION}.linux-${ARCH}"

# Create system user if it doesn't exist
id "$INSTALL_USER" &>/dev/null || useradd -rs /bin/false "$INSTALL_USER"

cat > "$SERVICE_PATH" <<EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=${INSTALL_USER}
ExecStart=${BIN_PATH}
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now node_exporter

echo "node_exporter is running on port 9100"
echo "Verify: curl http://localhost:9100/metrics"
