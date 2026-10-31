# VS Code Server 离线构建

用 GitHub Actions 构建 VS Code Server + 扩展的离线包，支持 `linux-x64` 和 `linux-arm64`，产物直接上传到 GitHub Release。

## 产物

每个架构一个包：

```
vscode-server-x64-<version>-full.tar.gz
vscode-server-arm64-<version>-full.tar.gz
```

包内结构：

```text
.vscode-server/bin/<commit>/                          # 旧版布局
.vscode-server/cli/servers/Stable-<commit>/server/    # 新版 exec server 布局
.vscode-server/code-<commit>                          # CLI
.vscode-server/extensions/                            # 扩展
```

## 目录

```text
.
├── .github/workflows/build.yml
├── extensions.txt                 # 扩展清单，每行一个 ID
└── scripts/
    ├── build.sh                   # 下载 server、装扩展、打包
    └── install-extensions.sh      # 逐个安装扩展
```

## 使用

### 1. 推到 GitHub

```bash
git init
git add .
git commit -m "init vscode offline builder"
git remote add origin git@github.com:<user>/<repo>.git
git push -u origin main
```

### 2. 触发构建

仓库页面 → Actions → `Build VS Code Server Offline Bundle` → `Run workflow`。

参数：

| 参数 | 说明 |
| --- | --- |
| `version` | VS Code 版本，例如 `1.144.0` |
| `commit` | 对应 commit，必须与客户端一致 |
| `create_release` | 是否上传到 Release，默认是 |
| `upload_artifact` | 是否同时上传 Actions Artifact；私有库注意存储配额 |

### 3. 下载

在 Releases 里下载对应架构的包，或：

```bash
gh release download vscode-server-1.144.0 -p 'vscode-server-*'
```

## 部署到 Linux 目标机

```bash
tar xzf vscode-server-x64-1.144.0-full.tar.gz -C "$HOME" --no-same-owner
chown -R "$(id -u):$(id -g)" "$HOME/.vscode-server"
chmod -R u+rwX "$HOME/.vscode-server"
```

验证：

```bash
COMMIT=2c33b50b16c472efe58357d1d2a8a5414bc23fbf
~/.vscode-server/bin/$COMMIT/bin/code-server --version
~/.vscode-server/code-$COMMIT --version
```

## 客户端设置

```json
{
  "remote.SSH.useExecServer": true,
  "remote.SSH.localServerDownload": "off",
  "remote.SSH.remotePlatform": {
    "你的主机别名": "linux"
  },
  "update.mode": "none",
  "extensions.autoUpdate": false,
  "extensions.autoCheckUpdates": false
}
```

## 更新扩展清单

编辑 `extensions.txt`，每行一个扩展 ID：

```text
ms-python.python
ms-vscode.cpptools
```

提交后重新触发 workflow，构建时会逐个安装并跳过已安装项。

## 本地调试

需要 Linux 环境（x64 或 arm64 原生）：

```bash
export VSCODE_VERSION=1.144.0
./scripts/build.sh x64 server-linux-x64 cli-alpine-x64 2c33b50b16c472efe58357d1d2a8a5414bc23fbf
```

产物在 `dist/`。

## 注意

1. **commit 必须与客户端一致**，否则连接时仍会要求下载服务器。
2. **Runner 架构**：`ubuntu-22.04` 是 x64，`ubuntu-22.04-arm` 是 arm64；私有库 arm64 runner 2026-01 起已支持。
3. **Artifact 存储**：私有库 Free 500 MB、Pro 1 GB，包约 1.3 GB，建议用 Release 附件而不是 Actions Artifact。
4. **glibc**：22.04 构建的包适用于 glibc ≥ 2.35 的目标；更老系统需换构建镜像。
5. **UI 扩展**：主题、语言包、快捷键应装本地客户端，不必进服务器包。
6. **运行期依赖**：C/C++、Python、Java、Jupyter 等扩展首次运行可能联网下载组件，纯离线环境需额外准备。
7. **.NET**：包内不含 dotnet，当前扩展清单也没有强制依赖；如后续加入 C# 扩展，需另备 .NET SDK。
