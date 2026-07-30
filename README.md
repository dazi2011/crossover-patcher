# CrossOver Patcher

[简体中文](README.md) · [English](README_EN.md)

CrossOver Patcher 是一个实验性兼容工具，目标是改善 CrossOver 对使用反作弊系统的 Windows 游戏的兼容性。

当前已适配的游戏：

- 《鸣潮》 / Wuthering Waves

## 支持范围

安装器只接受以下官方、未经修改的 CrossOver：

| CrossOver | 精确版本 | 验证状态 |
| --- | --- | --- |
| CrossOver Preview | `20260717 / 27.0.0.40734` | 安装、回滚、登录和实际游戏验证 |
| CrossOver | `26.3 / 26.3.0.39832` | 安装、回滚和隔离运行时加载验证；尚未完成真实游戏长时间验证 |

其他版本、已被修改的 App、混合版本运行时和不完整安装会被拒绝。没有强制跳过检查的选项。

## 下载与校验

下载 [CrossOver-Patcher-0.2.0-macOS.zip](CrossOver-Patcher-0.2.0-macOS.zip)。

SHA-256：

```text
80811f090321fd9e882d17e484ccf4a0d22b24c4083b8d363ad55294b0df6185
```

终端校验：

```sh
shasum -a 256 CrossOver-Patcher-0.2.0-macOS.zip
```

要求：

- Apple Silicon Mac
- macOS 14 或更高版本
- 用户自己合法取得的受支持 CrossOver

本项目不提供或二次分发 CrossOver、完整 Wine 运行时、Game Porting Toolkit、D3DMetal、游戏或反作弊程序。

## 从仓库构建完整 App

仓库包含 MIT 许可的 SwiftUI App 外壳源码、测试、构建脚本、两个受支持版本的 profile，以及已经编译好的专有 PatchCore。PatchCore 源码不在仓库中。

构建要求：

- Apple Silicon Mac
- macOS 14 或更高版本
- Xcode Command Line Tools（`xcode-select -p` 可正常返回）

```sh
git clone https://github.com/dazi2011/crossover-patcher.git
cd crossover-patcher
./build.sh
```

脚本会先验证 PatchCore 和全部 profile 的 SHA-256，编译 App 外壳，组装完整 App，进行 ad-hoc 签名并运行完整性检查。输出为：

```text
$TMPDIR/crossover-patcher-dist/CrossOver Patcher.app
dist/CrossOver-Patcher-0.2.0-macOS.zip
dist/SHA256SUMS.txt
```

执行全部单元测试、核心/profile 校验和完整 App 组装测试：

```sh
./script/test_private.sh
```

这里的 `private` 是早期内部构建脚本保留的文件名，不代表必须访问私有仓库；公开仓库的干净克隆包含完成构建所需的文件。

## 图形界面使用方法

1. 解压 ZIP。
2. 打开 `CrossOver Patcher.app`。
3. 将官方 CrossOver App 拖入窗口，或点击“选择”指定路径。
4. 选择输出位置。安装器会创建新的 CrossOver App 副本，不覆盖输入 App。
5. 完成后使用新生成的 CrossOver App。现有容器和游戏文件不会被修改。

安装器会在输出 App 内为三个目标运行时模块建立相邻的 `.cxorig` 备份，并对输出 App 进行本地 ad-hoc 签名。该签名只证明修改后的本地文件保持一致，不代表 CodeWeavers 或 Apple 的官方签名。

## 终端使用方法

图形界面和终端使用同一个闭源核心：

```sh
CORE="$PWD/CrossOver Patcher.app/Contents/Helpers/PatchCore"

"$CORE" list-profiles
"$CORE" inspect "/Applications/CrossOver.app"
"$CORE" patch "/Applications/CrossOver.app" "$HOME/Applications/CrossOver Patched.app"
"$CORE" rollback "$HOME/Applications/CrossOver Patched.app"
```

Preview 用户应将路径改为自己的官方 `CrossOver Preview.app`。已经修补过的 App 会被拒绝。

## 宏观实现方式

安装器会：

- 识别精确 CrossOver、Wine 和图形运行时组合；
- 验证官方签名、版本、关键文件哈希以及 PE/Mach-O 结构；
- 在事务副本中应用与该精确版本绑定的窄范围二进制变换；
- 验证目标模块、备份和 App 签名后再提交输出；
- 支持通过已认证备份回滚。

它不会修改游戏文件、反作弊文件或 CrossOver 容器。未来版本必须单独分析、构建 profile 并验证，安装器不会猜测未知二进制。

## 为什么闭源

PatchCore 和版本 profile 暂时保持闭源。公开完整实现细节可能使兼容方法过早失效，也会增加未经验证的变体和不安全修改。SwiftUI App 外壳、协议、测试和构建脚本已经开源；仓库通过编译好的 PatchCore 提供完整可构建版本，但不提供 PatchCore 源码。

二进制闭源不影响 Wine 等第三方组件原有的许可证权利。对于本项目发布中受 LGPL 覆盖的修改，自每个公开版本发布之日起至少三年内，可通过本仓库 Issues 请求对应的机器可读源代码和构建材料；该书面提供不包含专有 PatchCore 源码。

各部分的许可范围以根目录 `LICENSE`、`PrivateComponents/LICENSE.txt` 和 `Resources/THIRD_PARTY_NOTICES.txt` 为准。

## macOS 拦截或显示“已损坏”

本项目目前没有 Apple Developer ID，因此 App 使用 ad-hoc 签名且未公证。

按以下顺序处理：

1. 在 Finder 中按住 Control 点击 App，选择“打开”，再确认。
2. 如果仍被拦截，前往“系统设置 → 隐私与安全性”，使用仅针对这个 App 的“仍要打开”。
3. 重新下载并确认 ZIP 的 SHA-256 与上文一致。
4. 只有在校验正确、且系统没有提供“仍要打开”时，才对这个 App 清除隔离属性：

   ```sh
   xattr -dr com.apple.quarantine "CrossOver Patcher.app"
   ```

不要全局关闭 SIP、Gatekeeper、XProtect 或隔离机制。如果 macOS 明确报告恶意软件或“将损坏电脑”，请停止使用。

## 账号风险

这是非官方兼容修改，存在非零账号处罚风险。游戏或反作弊更新可能导致限制、暂停甚至永久封禁。没有人能保证风险“很轻”或保证账号安全。请自行评估，重要账号慎用。

## 隐私

Patcher 本地运行，不上传游戏日志、账号信息或设备标识。发布包不包含遥测。

## 独立项目声明

本项目与库洛游戏、腾讯、CodeWeavers、Apple 及任何反作弊供应商均无关联，也未获得其认可、赞助或支持。CrossOver、Wine、Wuthering Waves、鸣潮、D3DMetal 及其他名称和商标归各自权利人所有。
