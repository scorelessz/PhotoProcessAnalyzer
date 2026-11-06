# 「照片处理工具」逆向分析 · 补充报告

本报告是主报告《照片处理工具_逆向分析报告.md》的补充，聚焦三项：
1. MFC 消息映射表定位与控件 ID ↔ 处理函数对应
2. `FUN_004013a0` 中两个 `_ftol()` 的扩框系数（x87 常量）
3. 提取出的二进制文件清单

目标 SHA-256 不变：`e344fc1b4619d355d88a52bc1eddf216cca60fb55c8e9bab42ac5d4ed04183a9`

---

## 1. MFC 消息映射表与控件/处理函数对应

### 1.1 消息映射表定位（观测）

主对话框类是一个 `CDialog` 派生类。其虚表（vtable）位于 `0x5997c0`（由构造函数 `0x4023df` 的 `mov [ecx], 0x5997c0` 写入）。

| 项 | 地址 | 说明 |
|---|---|---|
| `GetMessageMap()` | `0x4024c0` | `mov eax, 0x599650; ret`，返回 AFX_MSGMAP 指针 |
| AFX_MSGMAP 结构 | `0x599650` | MFC 4.x 布局：`{ pfnGetBaseMap, lpEntries }` |
| 基类 GetMessageMap 回调 | `0x4022f0` | `mov eax, [0x599180]; ret`（指向 CDialog 基类映射，含 IDOK/IDCANCEL 默认处理） |
| 消息映射条目表 | `0x599658` | 24 字节/条，`{ nMessage, nCode, nID, nLastID, nSig, pfn }` |

### 1.2 消息映射条目（0x599658，观测）

| # | nMessage | nID | nSig | 处理函数 | 语义 |
|---|---|---|---|---|---|
| 1 | `0x112` WM_SYSCOMMAND | 0 | 0x12 | `0x402ac0` | OnSysCommand |
| 2 | `0x00F` WM_PAINT | 0 | 0x0C | `0x402b40` | OnPaint |
| 3 | `0x037` WM_QUERYDRAGICON | 0 | 0x23 | `0x402c00` | 返回成员 `+0x224` 的图标句柄 |
| 4 | `0x111` WM_COMMAND | **3** | 0x0C | **`0x403010`** | 「保存照片文件」按钮 |
| 5 | `0x084` WM_NCHITTEST | 0 | 0x22 | `0x4032b0` | OnNcHitTest（无边框拖动） |
| — | 0 | — | 0 | 0 | 条目结束 |

### 1.3 对话框 IDD 102 控件清单（观测，解析 DLGTEMPLATEEX）

| 控件 ID | 类 | 标题/说明 | 坐标(x,y,cx,cy) |
|---|---|---|---|
| **1** | Button（BS_BITMAP） | 无标题（位图按钮）＝**「打开照片文件」** | 249,119,132,43 |
| **3** | Button（BS_BITMAP） | **「保存照片文件」** | 249,187,132,43 |
| **2** | Button（BS_BITMAP） | **「退出操作」** | 250,252,132,43 |
| 1006 | Static（SS_BITMAP） | 背景位图（全屏 467×325） | 0,0,467,325 |
| 1001 | Static | 「检查结果：」 | 235,295,48,13 |
| 1004 | Static | 结果文本 | 80,295,15,14 |
| 1002 | Static | 「标准证件照样式」 | 60,295,15,10 |
| 1000 | Static | 图片 | 5,295,8,10 |
| 1003 | Static | 「系统处理后图片」 | 15,295,15,8 |
| 65535 | Static | 图片 | 360,215,40,55 |

### 1.4 控件 ID ↔ 处理函数（结论）

| 按钮 | 控件 ID | 分发机制 | 处理函数 |
|---|---|---|---|
| **打开照片文件** | **1**（= IDOK） | CDialog 基类消息映射 `ON_COMMAND(IDOK, OnOK)` → 虚调用 | **`OnOK` 重写 = `0x402c10`** |
| **保存照片文件** | **3** | 本类消息映射 `ON_COMMAND(3, …)` | **`0x403010`** |
| **退出操作** | **2**（= IDCANCEL） | CDialog 基类 `ON_COMMAND(IDCANCEL, OnCancel)` → 虚调用 | `CDialog::OnCancel`（未重写，经 `0x4032a0 → jmp 0x4412a6` 转发到 MFC42） |

**关键证据链（观测）：**

- 「打开照片文件」处理器 `0x402c10` 只出现在 vtable 里（`0x5997c0` 第 51 槽 = `0x59988c`），没有任何 `ON_COMMAND` 条目指向它 → 它是**虚函数重写**。
- vtable 第 48 槽 = `0x44128e`，Ghidra 解析出符号 **`MFC42.DLL::CDialog::DoModal`**（`ev_c556a9f7…`），据此校准 CDialog 虚函数区：
  - 槽 49 = `0x402720` = **OnInitDialog**（行为：`WM_SETICON(0x80)` 设置成员 `+0x224` 图标、`CString::LoadString(101)`）
  - 槽 50 = `0x4412b2`（继承，MFC 导入）
  - 槽 51 = `0x402c10` = **OnOK**（打开照片）
  - 槽 52 = `0x4032a0` = `jmp 0x4412a6`（转发到 `CDialog::OnCancel`）
  - 槽 53 = `0x4412a0`（继承）
- ID 1/2 是标准 `IDOK`/`IDCANCEL`，`CDialog` 基类消息映射已包含其 `ON_COMMAND(IDOK/IDCANCEL, OnOK/OnCancel)`，故本类映射表里没有它们的条目——**打开/退出走默认对话框 OK/Cancel 语义，保存是唯一自定义命令按钮**。

> 说明：槽 50 / 53 对应的 MFC42 虚函数（DoDataExchange / OnSetFont 一带）未在 `.exports` 符号里解析出名字，故标为「继承（未重写）」，不再强猜具体名。

---

## 2. `FUN_004013a0` 两个 `_ftol()` 的扩框系数（x87 常量）

反编译器把两次 `ftol()` 的浮点输入吞掉了。读汇编（`ev_adfa0bc1…`，`procedure_assembly 0x4013a0`）后，x87 栈序列如下：

### 2.1 第一次 `_ftol()`（宽度扩框）

```
0x40196e  FILD [esp+0x44]      ; ST0 = 最大人脸宽度 face_w
0x401972  FILD [ecx+0x28]      ; ST0 = 图像宽, ST1 = face_w
0x401975  FDIVR ST0,ST1        ; ST0 = face_w / 图像宽
0x401977  FCOMP [0x599540]     ; 与 0.32 比较 → 不达标返回码 5
0x401988  FMUL  [0x599538]     ; ST0 = face_w × 1.61812...
0x40198e  CALL  _ftol          ; 宽度 = (int)(face_w × 1.61812...)
```

### 2.2 第二次 `_ftol()`（高度计算 + 四舍五入）

```
0x401993  FILD [esp+0x58]      ; dst_height (默认 413)
0x401997  FILD [esp+0x50]      ; dst_width  (默认 295)
0x4019a1  FILD [esp+0x54]      ; 宽度（第一次 ftol 结果）
0x4019a5  FMUL  ST2            ; 宽度 × dst_height
0x4019a7  FDIV  ST0,ST1        ; (宽度 × dst_height) / dst_width
0x4019a9  FADD  [0x599518]     ; + 0.5（四舍五入）
0x4019af  CALL  _ftol          ; 高度 = round(宽度 × dst_height/dst_width)
```

### 2.3 常量值（观测，读 `.rdata` 双精度字面量）

| 地址 | 值 | 作用 |
|---|---|---|
| `0x599540` | **0.32** | 人脸宽/图宽 最低阈值（≥32% 才算合格） |
| `0x599538` | **1.6181229773462784** | 横向扩框系数：裁剪框宽 = 人脸宽 × 该系数 |
| `0x599530` | 0.9 | 宽高比校正下界（`0.9 ≤ r` 分支） |
| `0x599528` | 1.1 | 宽高比校正上界（`1.1 < r` 分支） |
| `0x599518` | **0.5** | 高度四舍五入常数（`(int)(x + 0.5)`） |
| `0x599510` | 2.0 | 采样像素块归一化辅助（见背景检查） |

### 2.4 结论

- **第一个 ftol 的扩框系数 = 1.6181229773462784**（≈ 黄金比 φ=1.6180339887，二者在 1e-4 量级吻合；系硬编码双精度常量，作者很可能本意取「黄金比例」做人脸在照片中的横向占比）。
- **第二个 ftol 没有独立的「扩框系数」**：它是把裁剪框宽度按目标证件照宽高比换算成高度，并 **+0.5 四舍五入**：
  - `裁剪框宽 = trunc(人脸宽 × 1.6181229773462784)`
  - `裁剪框高 = round(裁剪框宽 × dst_height / dst_width)`，默认 `dst_height/dst_width = 413/295 ≈ 1.4`

即「横向按黄金比放大人脸框，纵向按 295:413 目标比例跟随」，再校验人脸在框内的左右/顶部留白 ∈ `ratio_x`/`ratio_y` 区间。

---

## 3. 提取出的二进制文件

原始 exe 已按字节逐位复制，SHA-256 与原文件一致（`e344fc1b…`）。同时从 `.rsrc` 节完整解析并提取全部 21 个资源。

**输出目录：** `extracted/`

| 文件 | 类型 | 大小 | SHA-256（前 16 位） |
|---|---|---|---|
| `照片处理工具.exe` | 原始 PE 副本 | 9,940,992 | `e344fc1b4619d355…` |
| `BITMAP_id129_lang2052.bmp` | 位图 | 366,784 | `e404b6c23371cc39…` |
| `BITMAP_id131_lang2052.bmp` | 位图 | 318,952 | `479814d08bc2eb24…` |
| `BITMAP_id134_lang2052.bmp` | 位图 | 39,640 | `995f1ff3042ebc1d…` |
| `BITMAP_id135_lang2052.bmp` | 位图 | 39,640 | `de5c8fe5963969f0…` |
| `BITMAP_id136_lang2052.bmp` | 位图 | 39,040 | `0786d6405b93721f…` |
| `BITMAP_id137_lang2052.bmp` | 位图 | 14,264 | `5a5dce899e1356ab…` |
| `BITMAP_id138_lang2052.bmp` | 位图 | 1,026,794 | `436969624ab7099f…` |
| `BITMAP_id139_lang2052.bmp` | 位图 | 1,026,794 | `cfeb863a5c3b716d…` |
| `BITMAP_id140_lang2052.bmp` | 位图 | 1,026,794 | `522aa29cc9e75004…` |
| `BITMAP_id141_lang2052.bmp` | 位图 | 1,026,794 | `f87309e9c875b752…` |
| `BITMAP_id142_lang2052.bmp` | 位图 | 1,026,794 | `fcb759bb35e6e70d…` |
| `BITMAP_id143_lang2052.bmp` | 位图 | 1,026,794 | `8abaedc7f0657d07…` |
| `BITMAP_id144_lang2052.bmp` | 位图 | 1,026,794 | `5af1abaaccb60249…` |
| `ICON_id1_lang2052.ico` | 图标 | 744 | `5a72577122d18e73…` |
| `ICON_id2_lang2052.ico` | 图标 | 296 | `ffd9b48eeb36e492…` |
| `ICON_id3_lang2052.ico` | 图标 | 2,216 | `a8ebb889adc80441…` |
| `DIALOG_id100_lang2052.dlg` | 对话框模板 | 238 | `fda87da9368177f7…` |
| `DIALOG_id102_lang2052.dlg` | 对话框模板 | 432 | `32d2537a5d1654b6…` |
| `STRING_id7_lang2052.str` | 字符串表 | 76 | `a9071d8164348ec2…` |
| `GROUP_ICON_id128_lang2052.ico` | 图标组 | 48 | `4fb53300d56e889f…` |
| `VERSION_id1_lang2052.version` | 版本信息 | 860 | `734f729c1f93bd9a…` |

完整清单（含偏移、语言、代码页、SHA-256）见 `extracted/manifest.json`。

**要点：**
- 资源 138（`BITMAP_id138`，1,026,794 字节，1024 宽 8 位）就是程序每次打开照片时**重建 `interface00.bmp`** 的来源；随后把裁剪好的 295×413 照片合成进该底图 ROI(127,182,175,228) 并覆盖写回。
- 其余 6 个 1,026,794 字节的位图（139–144）是界面皮肤/按钮位图序列。
- 13 个位图中，ID 134/135/136 尺寸较小（39 KB），是按钮/小图标位图。

---

## 附：证据索引

| 结论 | 证据 |
|---|---|
| 消息映射表位置与 5 条目 | `.rdata` 直接读取（0x599650/0x599658，24 字节/条） |
| `CDialog::DoModal` 符号校准 | `address_name 0x44128e` → `MFC42.DLL::CDialog::DoModal`（`ev_c556a9f7…`） |
| vtable 归属与槽位 | 构造函数 `0x4023df` 写 `0x5997c0`；`.rdata` 逐槽读取 |
| OnOK=0x402c10 / OnInitDialog=0x402720 行为 | objdump 反汇编（`WM_SETICON 0x80`、`CString::LoadString`、`CFileDialog`） |
| ftol 常量 | `procedure_assembly 0x4013a0`（`ev_adfa0bc1…`）+ `.rdata` 双精度解码 |
| 对话框控件清单 | 解析 `DIALOG_id102` 的 DLGTEMPLATEEX |
| 资源提取 | Python PE 资源目录解析（`extracted/manifest.json`） |
