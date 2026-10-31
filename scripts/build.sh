#!/usr/bin/env bash
# 构建指定架构的 VS Code Server + 扩展离线包
# 用法: build.sh <arch> <server-artifact> <cli-artifact> <commit>
# 环境变量: VSCODE_VERSION
set -euo pipefail

ARCH="${1:?arch: x64|arm64}"
SERVER_ARTIFACT="${2:?server artifact, e.g. server-linux-x64}"
CLI_ARTIFACT="${3:?cli artifact, e.g. cli-alpine-x64}"
COMMIT="${4:?vscode commit}"
VERSION="${VSCODE_VERSION:?VSCODE_VERSION is required}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SERVER_DIR="$HOME/.vscode-server/bin/$COMMIT"
CLI_SERVER_DIR="$HOME/.vscode-server/cli/servers/Stable-$COMMIT/server"
CLI_BIN="$HOME/.vscode-server/code-$COMMIT"
EXT_DIR="$HOME/.vscode-server/extensions"
DIST="$ROOT/dist"
OUT="$DIST/vscode-server-${ARCH}-${VERSION}-full.tar.gz"

echo "==> arch=$ARCH version=$VERSION commit=$COMMIT"
mkdir -p "$SERVER_DIR" "$DIST"

echo "==> download VS Code Server: $SERVER_ARTIFACT"
curl -fL --retry 5 --retry-delay 5 --connect-timeout 20 \
  "https://update.code.visualstudio.com/commit:${COMMIT}/${SERVER_ARTIFACT}/stable" \
  -o /tmp/server.tar.gz
tar -xzf /tmp/server.tar.gz -C "$SERVER_DIR" --strip-components=1
rm -f /tmp/server.tar.gz
touch "$SERVER_DIR/0"

echo "==> prepare exec-server layout"
mkdir -p "$(dirname "$CLI_SERVER_DIR")"
rm -rf "$CLI_SERVER_DIR"
cp -a "$SERVER_DIR" "$CLI_SERVER_DIR"

echo "==> download VS Code CLI: $CLI_ARTIFACT"
curl -fL --retry 5 --retry-delay 5 --connect-timeout 20 \
  "https://update.code.visualstudio.com/commit:${COMMIT}/${CLI_ARTIFACT}/stable" \
  -o /tmp/cli.tar.gz
rm -rf /tmp/cli && mkdir -p /tmp/cli
tar -xzf /tmp/cli.tar.gz -C /tmp/cli
cp -f /tmp/cli/code "$CLI_BIN"
chmod +x "$CLI_BIN"
rm -rf /tmp/cli /tmp/cli.tar.gz

echo "==> verify server"
"$SERVER_DIR/bin/code-server" --version
"$CLI_BIN" --version

echo "==> install extensions"
"$ROOT/scripts/install-extensions.sh" "$ROOT/extensions.txt"

echo "==> clean runtime data"
rm -rf "$HOME/.vscode-server/data/logs" \
       "$HOME/.vscode-server/data/User/globalStorage" \
       "$HOME/.vscode-server/data/User/workspaceStorage" \
       "$HOME/.vscode-server/data/User/History" \
       "$HOME/.vscode-server/data/CachedExtensionVSIXs"
rm -f "$EXT_DIR/.obsolete" "$EXT_DIR/.init-default-profile-extensions"

echo "==> package"
cd "$HOME"
tar czf "$OUT" \
  ".vscode-server/bin/$COMMIT" \
  ".vscode-server/cli/servers/Stable-$COMMIT" \
  ".vscode-server/code-$COMMIT" \
  ".vscode-server/extensions"

gzip -t "$OUT"
(cd "$DIST" && sha256sum "$(basename "$OUT")" > "$(basename "$OUT").sha256")

echo "==> done"
ls -lh "$OUT"
cat "$OUT.sha256"
