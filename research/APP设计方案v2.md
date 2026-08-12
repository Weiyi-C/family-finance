# 家庭记账APP设计方案 v2.0

> 版本：v2.0  
> 日期：2026-08-12  
> 技术栈：Flutter 3.x + SQLite + Riverpod  
> 设计风格：治愈系暖调与萌趣风格

---

## 一、设计风格规范

### 1.1 整体风格

**治愈系暖调与萌趣风格**：
- 色彩：暖色调为主（米白、浅粉、淡黄、薄荷绿），搭配柔和的糖果色
- 图标：圆角矩形、软萌卡通手绘风格，所有图形采用SVG矢量格式
- 字体：圆润可爱的字体风格，避免尖锐棱角
- 动画：柔和的过渡动画，带有弹性效果和微交互

### 1.2 色彩系统

```
主色调：
├── 主色：#FFB5C2（樱花粉）
├── 辅助色：#FFD1DC（浅粉）
├── 强调色：#98D8C8（薄荷绿）
└── 警告色：#FFD93D（暖黄）

中性色：
├── 背景色：#FFF8F0（米白）
├── 卡片色：#FFFFFF（纯白）
├── 文字主色：#5D4E37（深棕）
├── 文字次色：#8B7D6B（浅棕）
└── 分割线：#F0E6D8（米色）

功能色：
├── 收入：#98D8C8（薄荷绿）
├── 支出：#FFB5C2（樱花粉）
├── 转账：#87CEEB（天蓝）
└── 预算超支：#FF6B6B（珊瑚红）
```

### 1.3 图标规范

- 风格：卡通手绘风格，线条圆润，带有轻微的阴影效果
- 尺寸：24x24dp（标准），32x32dp（大图标），16x16dp（小图标）
- 格式：SVG矢量格式，支持无损缩放
- 命名：`icon_category_name.svg`（如 `icon_food_lunch.svg`）

**分类图标示例**：
```
餐饮类：
├── icon_food_breakfast.svg（早饭 - 太阳+面包）
├── icon_food_lunch.svg（午饭 - 餐盒）
├── icon_food_dinner.svg（晚饭 - 月亮+餐具）
├── icon_food_snack.svg（下午茶 - 奶茶杯）
└── icon_food_fruit.svg（水果 - 苹果+香蕉）

交通类：
├── icon_transport_taxi.svg（打车 - 小汽车）
├── icon_transport_metro.svg（地铁 - 列车）
├── icon_transport_bus.svg（公交 - 巴士）
└── icon_transport_bike.svg（骑行 - 自行车）

购物类：
├── icon_shopping_clothes.svg（服饰 - 衣架）
├── icon_shopping_daily.svg（日用品 - 购物袋）
├── icon_shopping_tech.svg（数码 - 手机）
└── icon_shopping_food.svg（食材 - 购物车）

娱乐类：
├── icon_entertainment_movie.svg（电影 - 爆米花）
├── icon_entertainment_game.svg（游戏 - 手柄）
├── icon_entertainment_travel.svg（旅行 - 飞机）
└── icon_entertainment_sport.svg（运动 - 跑步小人）
```

---

## 二、技术架构

### 2.1 技术选型

| 组件 | 技术 | 版本 | 说明 |
|------|------|------|------|
| 框架 | Flutter | 3.x | 跨平台，一套代码出 iOS+Android |
| 状态管理 | Riverpod | 2.x | 响应式状态管理，支持离线 |
| 本地数据库 | SQLite (sqflite) | 2.x | 离线存储，支持复杂查询 |
| 网络请求 | Dio | 5.x | 支持拦截器、重试、缓存 |
| 数据序列化 | Freezed + json_serializable | - | 类型安全的JSON处理 |
| 路由 | GoRouter | 10.x | 声明式路由，支持深度链接 |
| UI组件 | 自定义组件库 | - | 治愈系萌趣风格 |
| 图标 | SVG (flutter_svg) | - | 矢量图标，无损缩放 |
| 图表 | fl_chart | 0.66+ | 自定义样式图表 |
| 动画 | Lottie + Rive | - | 卡通动画效果 |

### 2.2 项目结构

```
family_finance_app/
├── lib/
│   ├── main.dart                    # 应用入口
│   ├── app.dart                     # 应用配置
│   │
│   ├── core/                        # 核心模块
│   │   ├── constants/               # 常量定义
│   │   │   ├── app_colors.dart      # 颜色常量
│   │   │   ├── app_text_styles.dart # 文字样式
│   │   │   ├── app_dimensions.dart  # 尺寸常量
│   │   │   └── app_icons.dart       # 图标常量
│   │   ├── theme/                   # 主题配置
│   │   │   ├── app_theme.dart       # 应用主题
│   │   │   └── color_schemes.dart   # 配色方案
│   │   ├── utils/                   # 工具类
│   │   │   ├── date_utils.dart      # 日期工具
│   │   │   ├── money_utils.dart     # 金额工具
│   │   │   ├── format_utils.dart    # 格式化工具
│   │   │   └── validation_utils.dart# 验证工具
│   │   └── extensions/              # 扩展方法
│   │
│   ├── data/                        # 数据层
│   │   ├── models/                  # 数据模型
│   │   │   ├── transaction.dart     # 交易模型
│   │   │   ├── account.dart         # 账户模型
│   │   │   ├── category.dart        # 分类模型
│   │   │   ├── budget.dart          # 预算模型
│   │   │   ├── tag.dart             # 标签模型
│   │   │   ├── recurring.dart       # 周期交易模型
│   │   │   ├── credit_bill.dart     # 信用账单模型
│   │   │   ├── debt.dart            # 借贷模型
│   │   │   ├── savings_goal.dart    # 储蓄目标模型
│   │   │   └── sync_log.dart        # 同步日志模型
│   │   ├── database/                # 本地数据库
│   │   │   ├── app_database.dart    # 数据库定义
│   │   │   ├── tables/              # 表定义
│   │   │   ├── daos/                # 数据访问对象
│   │   │   └── migrations/          # 数据库迁移
│   │   ├── repositories/            # 仓库层
│   │   │   ├── transaction_repo.dart
│   │   │   ├── account_repo.dart
│   │   │   ├── category_repo.dart
│   │   │   ├── budget_repo.dart
│   │   │   └── sync_repo.dart
│   │   └── services/                # 服务层
│   │       ├── api_service.dart     # API服务
│   │       ├── sync_service.dart    # 同步服务
│   │       ├── auth_service.dart    # 认证服务
│   │       └── notification_service.dart # 通知服务
│   │
│   ├── features/                    # 功能模块
│   │   ├── splash/                  # 启动页
│   │   ├── onboarding/             # 引导页
│   │   ├── auth/                    # 认证模块
│   │   │   ├── login/              # 登录
│   │   │   └── register/           # 注册
│   │   ├── home/                    # 首页
│   │   ├── transaction/            # 交易模块
│   │   │   ├── list/               # 交易列表
│   │   │   ├── create/             # 创建交易
│   │   │   ├── detail/             # 交易详情
│   │   │   └── search/             # 搜索
│   │   ├── account/                 # 账户模块
│   │   │   ├── list/               # 账户列表
│   │   │   ├── detail/             # 账户详情
│   │   │   └── create/             # 创建账户
│   │   ├── budget/                  # 预算模块
│   │   ├── statistics/              # 统计模块
│   │   ├── category/                # 分类管理
│   │   ├── tag/                     # 标签管理
│   │   ├── recurring/               # 周期交易
│   │   ├── credit_bill/             # 信用账单
│   │   ├── debt/                    # 借贷管理
│   │   ├── savings/                 # 储蓄目标
│   │   ├── import/                  # 导入功能
│   │   ├── export/                  # 导出功能
│   │   ├── family/                  # 家庭管理
│   │   ├── ai/                      # AI助手
│   │   ├── settings/                # 设置
│   │   │   ├── general/            # 通用设置
│   │   │   ├── server/             # 服务器配置
│   │   │   ├── theme/              # 主题设置
│   │   │   └── about/              # 关于
│   │   └── sync/                    # 同步状态
│   │
│   ├── shared/                      # 共享组件
│   │   ├── widgets/                 # 通用组件
│   │   │   ├── cute_card.dart       # 萌趣卡片
│   │   │   ├── cute_button.dart     # 萌趣按钮
│   │   │   ├── cute_input.dart      # 萌趣输入框
│   │   │   ├── cute_dialog.dart     # 萌趣弹窗
│   │   │   ├── cute_bottom_sheet.dart # 萌趣底部弹窗
│   │   │   ├── category_icon.dart   # 分类图标
│   │   │   ├── amount_display.dart  # 金额显示
│   │   │   ├── date_picker.dart     # 日期选择器
│   │   │   ├── filter_chips.dart    # 筛选标签
│   │   │   └── empty_state.dart     # 空状态
│   │   └── animations/              # 动画组件
│   │       ├── bounce_animation.dart
│   │       ├── fade_animation.dart
│   │       └── slide_animation.dart
│   │
│   └── config/                      # 配置
│       ├── routes.dart              # 路由配置
│       ├── providers.dart           # Provider配置
│       └── dependencies.dart        # 依赖注入
│
├── assets/                          # 资源文件
│   ├── icons/                       # SVG图标
│   │   ├── categories/             # 分类图标
│   │   ├── navigation/             # 导航图标
│   │   ├── actions/                # 操作图标
│   │   └── status/                 # 状态图标
│   ├── images/                      # 图片资源
│   │   ├── onboarding/            # 引导页图片
│   │   ├── empty/                 # 空状态图片
│   │   └── avatars/               # 头像
│   ├── animations/                  # Lottie动画
│   │   ├── loading.json
│   │   ├── success.json
│   │   ├── error.json
│   │   └── empty.json
│   └── fonts/                       # 字体文件
│       ├── Nunito/                 # 圆润英文字体
│       └── 思源黑体/               # 中文字体
│
├── test/                            # 测试
│   ├── unit/                        # 单元测试
│   ├── widget/                      # 组件测试
│   └── integration/                 # 集成测试
│
└── pubspec.yaml                     # 依赖配置
```

---

## 三、页面结构设计

### 3.1 页面层级

```
App
├── 启动页（Splash Screen）
│   └── 治愈系插画 + 应用Logo
│
├── 引导页（Onboarding，首次启动）
│   ├── 欢迎页（萌趣动画）
│   ├── 功能介绍（3-4页）
│   └── 服务器配置（可选）
│
├── 认证页（Auth）
│   ├── 登录页
│   └── 注册页
│
├── 主页（MainLayout，BottomNavigationBar）
│   │
│   ├── 首页（Home）
│   │   ├── 今日收支概览卡片
│   │   ├── 本月预算进度（可爱进度条）
│   │   ├── 最近账单列表（按日分组）
│   │   ├── 快速记账入口（FAB悬浮按钮，带弹性动画）
│   │   └── 下拉刷新同步状态
│   │
│   ├── 账单（Transactions）
│   │   ├── 交易列表（按日分组，支持筛选）
│   │   ├── 筛选面板（时间/分类/账户/渠道/标签）
│   │   ├── 搜索功能
│   │   ├── 批量操作
│   │   └── 交易详情
│   │
│   ├── 统计（Statistics）
│   │   ├── 时间选择器（周/月/年/自定义）
│   │   ├── 收支概览卡片（可爱图表）
│   │   ├── 分类占比饼图
│   │   ├── 趋势折线图
│   │   ├── 支出排行
│   │   └── 报表导出
│   │
│   └── 我的（Profile）
│       ├── 用户信息卡片
│       ├── 资产总览
│       ├── 功能入口网格
│       │   ├── 资金账户
│       │   ├── 信用账单
│       │   ├── 预算管理
│       │   ├── 借贷管理
│       │   ├── 储蓄目标
│       │   ├── 周期交易
│       │   ├── 报销管理
│       │   ├── 规则引擎
│       │   ├── AI助手
│       │   └── 家庭管理
│       └── 设置入口
│
├── 功能页面（二级页面）
│   ├── 记账页（CreateTransaction）
│   │   ├── 快速模式（金额 + 分类）
│   │   ├── 完整模式（所有字段）
│   │   └── AI模式（自然语言输入）
│   │
│   ├── 账户管理（Accounts）
│   │   ├── 账户列表（分组显示）
│   │   ├── 账户详情
│   │   └── 创建/编辑账户
│   │
│   ├── 预算管理（Budgets）
│   │   ├── 预算列表
│   │   ├── 预算进度
│   │   └── 创建/编辑预算
│   │
│   ├── 信用账单（CreditBills）
│   │   ├── 账单列表
│   │   ├── 账单详情
│   │   └── 还款记录
│   │
│   ├── 借贷管理（Debts）
│   │   ├── 借贷列表
│   │   ├── 借贷详情
│   │   └── 还款记录
│   │
│   ├── 储蓄目标（SavingsGoals）
│   │   ├── 目标列表
│   │   ├── 目标详情
│   │   └── 存入记录
│   │
│   ├── 周期交易（Recurring）
│   │   ├── 周期列表
│   │   └── 创建/编辑周期
│   │
│   ├── 报销管理（Reimbursements）
│   │   ├── 报销单列表
│   │   └── 报销详情
│   │
│   ├── 导入功能（Import）
│   │   ├── 选择文件
│   │   ├── 预览结果
│   │   ├── 账户映射
│   │   └── 确认导入
│   │
│   ├── 家庭管理（Family）
│   │   ├── 成员列表
│   │   ├── 邀请成员
│   │   └── 权限设置
│   │
│   └── AI助手（AIAssistant）
│       ├── 对话界面
│       ├── 建议列表
│       └── 设置
│
└── 设置页面（Settings）
    ├── 通用设置
    │   ├── 个人信息
    │   ├── 默认货币
    │   ├── 日期格式
    │   └── 语言设置
    │
    ├── 服务器配置（ServerConfig）
    │   ├── 服务器地址输入
    │   ├── 连接测试
    │   ├── 自动发现（局域网）
    │   └── 多服务器管理
    │
    ├── 主题设置（Theme）
    │   ├── 主题模式（浅色/深色/自动）
    │   ├── 主题色选择
    │   └── 字体大小
    │
    ├── 同步设置（Sync）
    │   ├── 同步状态
    │   ├── 手动同步
    │   ├── 冲突解决
    │   └── 同步历史
    │
    ├── 数据管理（Data）
    │   ├── 导出数据
    │   ├── 备份恢复
    │   └── 清除缓存
    │
    └── 关于（About）
        ├── 版本信息
        ├── 更新日志
        ├── 隐私政策
        └── 联系方式
```

---

## 四、核心功能设计

### 4.1 离线优先架构

**设计原则**：
- 所有数据优先存储在本地SQLite
- 网络请求异步执行，不阻塞用户操作
- 支持完全离线使用，联网后自动同步

**本地数据库表结构**（与服务端保持一致）：
```sql
-- 核心表
transactions          -- 交易记录
categories            -- 分类
payment_accounts      -- 资金账户
tags                  -- 标签
transaction_tags      -- 交易标签关联

-- 业务表
budgets               -- 预算
recurring_transactions -- 周期交易
credit_card_bills     -- 信用账单
debts                 -- 借贷
debt_repayments       -- 还款记录
savings_goals         -- 储蓄目标
reimbursements        -- 报销

-- 配置表
user_settings         -- 用户设置
automation_rules      -- 自动化规则
merchant_aliases      -- 商户别名

-- 同步表
sync_change_log       -- 变更日志
client_sync_state     -- 同步状态
```

### 4.2 同步机制

```
┌─────────────────────────────────────────────────────────────┐
│                    离线同步流程                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  本地操作                                                   │
│     │                                                       │
│     ▼                                                       │
│  写入本地数据库                                               │
│     │                                                       │
│     ▼                                                       │
│  记录变更日志（sync_change_log）                              │
│     │                                                       │
│     ▼                                                       │
│  检查网络状态                                                │
│     │                                                       │
│     ├─ 在线 → 立即同步                                      │
│     │                                                       │
│     └─ 离线 → 等待网络恢复                                   │
│              │                                              │
│              ▼                                              │
│         网络恢复时                                           │
│              │                                              │
│              ▼                                              │
│         批量上传变更                                         │
│              │                                              │
│              ▼                                              │
│         拉取服务器变更                                       │
│              │                                              │
│              ▼                                              │
│         合并冲突（如有）                                      │
│                                                             │
└─────────────────────────────────────────────────────────────┘

同步时机：
├── 应用启动时
├── 网络恢复时
├── 定时同步（每5分钟）
├── 记账后延迟3秒
└── 手动触发

冲突处理：
├── 版本号比对（base_version == DB.version）
├── 时间戳比对（更新时间更新的优先）
├── 字段级合并（不同字段的修改可以合并）
└── 用户手动解决（无法自动合并时）
```

### 4.3 自定义服务器地址

**功能设计**：

```dart
class ServerConfig {
  final String name;           // 服务器名称（如"家庭服务器"）
  final String url;            // 服务器地址（如"http://192.168.1.100:8080"）
  final String? apiKey;        // API密钥（可选）
  final bool isDefault;        // 是否默认服务器
  final DateTime? lastSync;    // 最后同步时间
  final ConnectionStatus status; // 连接状态
}

enum ConnectionStatus {
  connected,    // 已连接
  disconnected, // 未连接
  testing,      // 测试中
  error,        // 连接错误
}
```

**配置页面**：
```
服务器配置
├── 当前服务器
│   ├── 服务器名称：家庭服务器
│   ├── 地址：http://192.168.1.100:8080
│   ├── 状态：✅ 已连接
│   └── 最后同步：2026-08-12 16:30
│
├── 添加服务器
│   ├── 服务器名称（输入框）
│   ├── 服务器地址（输入框）
│   ├── API密钥（可选，输入框）
│   └── 测试连接（按钮）
│
├── 服务器列表
│   ├── 家庭服务器（默认）
│   ├── 办公服务器
│   └── 云服务器
│
└── 自动发现（局域网）
    └── 扫描局域网中的服务器
```

**使用流程**：
1. 首次启动时显示服务器配置引导
2. 用户输入服务器地址（支持IP/域名）
3. 测试连接是否成功
4. 保存配置并开始同步
5. 支持多服务器切换

### 4.4 主题系统设计

**设计原则**：
- 支持多种主题风格切换
- 主题配置持久化存储
- 跟随系统或手动切换
- 支持自定义主题色

**主题模式**：
```dart
enum ThemeMode {
  light,    // 浅色模式（默认）
  dark,     // 深色模式
  auto,     // 跟随系统
}

enum ThemePreset {
  sakura,     // 樱花粉（默认治愈系）
  mint,       // 薄荷绿
  lavender,   // 薰衣草紫
  sunset,     // 日落橙
  ocean,      // 海洋蓝
  forest,     // 森林绿
  custom,     // 自定义
}
```

**主题配置模型**：
```dart
class AppTheme {
  final ThemeMode mode;           // 主题模式
  final ThemePreset preset;       // 预设主题
  final Color? primaryColor;      // 自定义主色
  final Color? accentColor;       // 自定义强调色
  final double fontSize;          // 字体大小（0.8-1.4）
  final bool useRoundedCorners;   // 使用圆角
  final bool useAnimations;       // 使用动画
}

class ThemeColors {
  // 浅色模式
  static const light = {
    'background': Color(0xFFFFF8F0),    // 米白
    'card': Color(0xFFFFFFFF),          // 纯白
    'primary': Color(0xFFFFB5C2),       // 樱花粉
    'secondary': Color(0xFF98D8C8),     // 薄荷绿
    'text': Color(0xFF5D4E37),          // 深棕
    'textSecondary': Color(0xFF8B7D6B), // 浅棕
    'divider': Color(0xFFF0E6D8),       // 米色
    'income': Color(0xFF98D8C8),        // 收入绿
    'expense': Color(0xFFFFB5C2),       // 支出粉
    'transfer': Color(0xFF87CEEB),      // 转账蓝
  };

  // 深色模式
  static const dark = {
    'background': Color(0xFF1A1A1A),    // 深黑
    'card': Color(0xFF2D2D2D),          // 深灰
    'primary': Color(0xFFFFB5C2),       // 樱花粉
    'secondary': Color(0xFF98D8C8),     // 薄荷绿
    'text': Color(0xFFF5F5F5),          // 浅白
    'textSecondary': Color(0xFFB0B0B0), // 灰色
    'divider': Color(0xFF3D3D3D),       // 分割线
    'income': Color(0xFF98D8C8),        // 收入绿
    'expense': Color(0xFFFFB5C2),       // 支出粉
    'transfer': Color(0xFF87CEEB),      // 转账蓝
  };
}
```

**预设主题色彩**：

```
🌸 樱花粉（默认）
├── 主色：#FFB5C2
├── 辅助：#FFD1DC
├── 强调：#98D8C8
└── 风格：温柔治愈，适合日常使用

🌿 薄荷绿
├── 主色：#98D8C8
├── 辅助：#B8E6D0
├── 强调：#FFB5C2
└── 风格：清新自然，护眼舒适

💜 薰衣草紫
├── 主色：#C8A2C8
├── 辅助：#D8BFD8
├── 强调：#FFD700
└── 风格：优雅浪漫，适合女性用户

🌅 日落橙
├── 主色：#FFB347
├── 辅助：#FFCC80
├── 强调：#87CEEB
└── 风格：温暖活力，充满能量

🌊 海洋蓝
├── 主色：#87CEEB
├── 辅助：#B0E0E6
├── 强调：#FFB5C2
└── 风格：清爽宁静，专注高效

🌲 森林绿
├── 主色：#90EE90
├── 辅助：#98FB98
├── 强调：#FFD700
└── 风格：生机勃勃，自然健康
```

**主题切换页面设计**：
```
┌─────────────────────────────────────┐
│  主题设置                           │
│                                     │
│  ───── 主题模式 ─────               │
│  ┌─────┐ ┌─────┐ ┌─────┐          │
│  │ ☀️  │ │ 🌙  │ │ 📱  │          │
│  │浅色 │ │深色 │ │自动 │          │
│  └─────┘ └─────┘ └─────┘          │
│                                     │
│  ───── 预设主题 ─────               │
│  ┌─────┐ ┌─────┐ ┌─────┐          │
│  │ 🌸  │ │ 🌿  │ │ 💜  │          │
│  │樱花 │ │薄荷 │ │薰衣草│          │
│  └─────┘ └─────┘ └─────┘          │
│  ┌─────┐ ┌─────┐ ┌─────┐          │
│  │ 🌅  │ │ 🌊  │ │ 🌲  │          │
│  │日落 │ │海洋 │ │森林 │          │
│  └─────┘ └─────┘ └─────┘          │
│                                     │
│  ───── 自定义颜色 ─────             │
│  主色调  [■] #FFB5C2    [选择]     │
│  强调色  [■] #98D8C8    [选择]     │
│                                     │
│  ───── 显示设置 ─────               │
│  字体大小  ████████░░ 1.0x         │
│  圆角样式  [开关] 已开启            │
│  动画效果  [开关] 已开启            │
│                                     │
│  ───── 预览 ─────                   │
│  ┌─────────────────────────────┐   │
│  │  [预览卡片]                  │   │
│  │  收入 ¥15,000               │   │
│  │  支出 ¥8,500                │   │
│  └─────────────────────────────┘   │
│                                     │
│           [ 保存设置 ]              │
└─────────────────────────────────────┘
```

**主题切换实现**：
```dart
// Riverpod状态管理
final themeProvider = StateNotifierProvider<ThemeNotifier, AppTheme>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<AppTheme> {
  ThemeNotifier() : super(AppTheme.defaultTheme()) {
    _loadFromStorage();
  }

  // 从本地存储加载主题配置
  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('themeMode') ?? 'light';
    final preset = prefs.getString('themePreset') ?? 'sakura';
    // ... 加载其他配置
  }

  // 切换主题模式
  Future<void> setMode(ThemeMode mode) async {
    state = state.copyWith(mode: mode);
    await _saveToStorage();
  }

  // 切换预设主题
  Future<void> setPreset(ThemePreset preset) async {
    state = state.copyWith(preset: preset);
    await _saveToStorage();
  }

  // 自定义颜色
  Future<void> setCustomColors(Color primary, Color accent) async {
    state = state.copyWith(
      preset: ThemePreset.custom,
      primaryColor: primary,
      accentColor: accent,
    );
    await _saveToStorage();
  }

  // 保存到本地存储
  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', state.mode.name);
    await prefs.setString('themePreset', state.preset.name);
    // ... 保存其他配置
  }
}
```

**Flutter主题集成**：
```dart
// MaterialApp配置
MaterialApp(
  theme: AppTheme.lightTheme(),      // 浅色主题
  darkTheme: AppTheme.darkTheme(),   // 深色主题
  themeMode: themeMode,              // 当前模式
  // ...
)

// 主题定义
class AppTheme {
  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: Color(0xFFFFB5C2),
        secondary: Color(0xFF98D8C8),
        // ...
      ),
      // 圆角配置
      cardTheme: CardTheme(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      // 按钮配置
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      // ...
    );
  }
}
```

**主题切换动画**：
```dart
// 平滑过渡动画
AnimatedTheme(
  data: currentTheme,
  duration: Duration(milliseconds: 300),
  curve: Curves.easeInOut,
  child: child,
)

// 颜色过渡
AnimatedContainer(
  duration: Duration(milliseconds: 300),
  color: themeColors.background,
  // ...
)
```

---

## 五、页面详细设计

### 5.1 首页设计

```
┌─────────────────────────────────────┐
│  ☀️ 早上好，小明              [🔔]  │
│  2026年8月12日                      │
│                                     │
│  ┌─────────────────────────────┐   │
│  │  💰 本月收支                 │   │
│  │  ┌────────┐ ┌────────┐     │   │
│  │  │ 收入    │ │ 支出    │     │   │
│  │  │ ¥15,000│ │ ¥8,500 │     │   │
│  │  └────────┘ └────────┘     │   │
│  │  ┌────────────────────┐    │   │
│  │  │ 结余 ¥6,500        │    │   │
│  │  └────────────────────┘    │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │  🎯 本月预算                 │   │
│  │  餐饮 ████████░░ 80%        │   │
│  │  交通 ████░░░░░░ 40%        │   │
│  │  购物 ██████░░░░ 60%        │   │
│  └─────────────────────────────┘   │
│                                     │
│  ───── 最近账单 ─────               │
│  今天                                │
│  🍽️ 午饭    肯德基      -¥35.00    │
│  🚕 打车    滴滴         -¥25.00    │
│  🥤 咖啡    瑞幸         -¥9.90     │
│                                     │
│  昨天                                │
│  🛒 购物    淘宝         -¥299.00   │
│  💰 工资    工商银行     +¥15,000   │
│                                     │
│  ────────────────────────────       │
│                                     │
│  [首页]    [账单]    [+]    [统计]  [我的] │
└─────────────────────────────────────┘
                     ↑
              FAB 悬浮按钮（带弹性动画）
```

### 5.2 记账页设计

```
┌─────────────────────────────────────┐
│  [←]  记一笔           [完整模式]  │
│                                     │
│  ┌───────────────────────────────┐ │
│  │         ¥ 0.00               │ │
│  │  ──────────────────────────── │ │
│  │  📝 "午饭外卖35"  [AI识别]   │ │
│  └───────────────────────────────┘ │
│                                     │
│  支出                               │
│  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ │
│  │ ☀️  │ │ 🌞  │ │ 🌙  │ │ 🫖  │ │
│  │早饭 │ │午饭 │ │晚饭 │ │下午茶│ │
│  └─────┘ └─────┘ └─────┘ └─────┘ │
│  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ │
│  │ 🚕  │ │ 🚇  │ │ 🛒  │ │ 🏠  │ │
│  │打车 │ │地铁 │ │购物 │ │住房 │ │
│  └─────┘ └─────┘ └─────┘ └─────┘ │
│  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ │
│  │ 💊  │ │ 📚  │ │ 🎁  │ │ ... │ │
│  │医疗 │ │教育 │ │礼物 │ │更多 │ │
│  └─────┘ └─────┘ └─────┘ └─────┘ │
│                                     │
│  收入                               │
│  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ │
│  │ 💰  │ │ 💵  │ │ 🎁  │ │ 📈  │ │
│  │工资 │ │副业 │ │红包 │ │投资 │ │
│  └─────┘ └─────┘ └─────┘ └─────┘ │
│                                     │
│  ────── 常用分类 ──────            │
│  ☀️早饭  🌞午饭  🚕打车  🛒购物   │
│                                     │
│           [ 保存 ]                │
└─────────────────────────────────────┘
```

### 5.3 统计页设计

```
┌─────────────────────────────────────┐
│  统计                   [导出]      │
│                                     │
│  [< 2026年8月 >]    [周][月][年]   │
│                                     │
│  ┌─────────┐ ┌─────────┐ ┌───────┐ │
│  │ 收入     │ │ 支出     │ │ 结余  │ │
│  │ ¥15,000 │ │ ¥8,500  │ │¥6,500 │ │
│  └─────────┘ └─────────┘ └───────┘ │
│                                     │
│  ───── 分类占比 ─────               │
│  ┌─────────────────────────────┐   │
│  │        ╭───────╮            │   │
│  │       /  餐饮   \           │   │
│  │      │  38%     │           │   │
│  │       \ 交通 18%/           │   │
│  │        ╰───────╯            │   │
│  │  ● 餐饮  ● 交通  ● 服饰    │   │
│  │  ● 住房  ● 娱乐  ● 其他    │   │
│  └─────────────────────────────┘   │
│                                     │
│  ───── 每日趋势 ─────               │
│  ┌─────────────────────────────┐   │
│  │  ¥500│      ╭╮              │   │
│  │      │   ╭──╯╰──╮    ╭╮    │   │
│  │  ¥250│──╯       ╰──╯ ╰──  │   │
│  │      │                      │   │
│  │  ¥0  └──────────────────   │   │
│  │      1  5  10  15  20  25   │   │
│  └─────────────────────────────┘   │
│                                     │
│  ───── 支出排行 ─────               │
│  1. 餐饮    ¥3,200  ████████░░ 38% │
│  2. 交通    ¥1,500  ████░░░░░░ 18% │
│  3. 服饰    ¥1,200  ███░░░░░░░ 14% │
│  4. 住房    ¥1,000  ██░░░░░░░░ 12% │
│  5. 娱乐    ¥800    ██░░░░░░░░  9% │
│                                     │
│  [首页]    [账单]    [+]    [统计]  [我的] │
└─────────────────────────────────────┘
```

### 5.4 我的页面设计

```
┌─────────────────────────────────────┐
│  我的                               │
│                                     │
│  ┌─────────────────────────────┐   │
│  │  👤 小明                     │   │
│  │  家庭：温馨小家              │   │
│  │  成员：3人                   │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │  💰 资产总览                 │   │
│  │  总资产 ¥125,000            │   │
│  │  ┌────────┐ ┌────────┐     │   │
│  │  │ 现金    │ │ 银行卡  │     │   │
│  │  │ ¥2,000 │ │ ¥85,000│     │   │
│  │  └────────┘ └────────┘     │   │
│  │  ┌────────┐ ┌────────┐     │   │
│  │  │ 支付宝  │ │ 微信    │     │   │
│  │  │ ¥18,000│ │ ¥20,000│     │   │
│  │  └────────┘ └────────┘     │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │  📊 功能入口                 │   │
│  │  ┌─────┐ ┌─────┐ ┌─────┐   │   │
│  │  │ 💳  │ │ 📋  │ │ 🎯  │   │   │
│  │  │账户 │ │账单 │ │预算 │   │   │
│  │  └─────┘ └─────┘ └─────┘   │   │
│  │  ┌─────┐ ┌─────┐ ┌─────┐   │   │
│  │  │ 📅  │ │ 💸  │ │ 🏦  │   │   │
│  │  │周期 │ │借贷 │ │储蓄 │   │   │
│  │  └─────┘ └─────┘ └─────┘   │   │
│  │  ┌─────┐ ┌─────┐ ┌─────┐   │   │
│  │  │ 🤖  │ │ 👨‍👩‍👧  │ │ ⚙️  │   │   │
│  │  │AI   │ │家庭 │ │设置 │   │   │
│  │  └─────┘ └─────┘ └─────┘   │   │
│  └─────────────────────────────┘   │
│                                     │
│  ────────────────────────────       │
│  当前服务器：家庭服务器 ✅          │
│  最后同步：2026-08-12 16:30        │
│                                     │
│  [首页]    [账单]    [+]    [统计]  [我的] │
└─────────────────────────────────────┘
```

---

## 六、API接口设计

### 6.1 认证接口

```
POST   /api/auth/login              登录
POST   /api/auth/register           注册
POST   /api/auth/refresh            刷新token
POST   /api/auth/logout             登出
```

### 6.2 交易接口

```
GET    /api/transactions            获取交易列表（支持筛选分页）
POST   /api/transactions            创建交易
GET    /api/transactions/{id}       获取交易详情
PUT    /api/transactions/{id}       更新交易
DELETE /api/transactions/{id}       删除交易
POST   /api/transactions/batch      批量创建
PATCH  /api/transactions/batch      批量修改
```

### 6.3 账户接口

```
GET    /api/accounts                获取账户列表
POST   /api/accounts                创建账户
GET    /api/accounts/{id}           获取账户详情
PUT    /api/accounts/{id}           更新账户
DELETE /api/accounts/{id}           删除账户
```

### 6.4 分类接口

```
GET    /api/categories              获取分类树
POST   /api/categories              创建分类
PUT    /api/categories/{id}         更新分类
DELETE /api/categories/{id}         删除分类
```

### 6.5 预算接口

```
GET    /api/budgets                 获取预算列表
POST   /api/budgets                 创建预算
PUT    /api/budgets/{id}            更新预算
DELETE /api/budgets/{id}            删除预算
GET    /api/budgets/progress        获取预算进度
```

### 6.6 统计接口

```
GET    /api/stats/summary           收支概览
GET    /api/stats/by-category       分类统计
GET    /api/stats/by-day            每日统计
GET    /api/stats/by-month          月度统计
GET    /api/stats/compare           同比环比
GET    /api/stats/cross             交叉分析
GET    /api/stats/merchant-ranking  商户排行
```

### 6.7 同步接口

```
POST   /api/sync/push               上传变更
POST   /api/sync/pull               拉取变更
GET    /api/sync/status             同步状态
POST   /api/sync/resolve            解决冲突
```

### 6.8 其他接口

```
GET    /api/credit-bills            信用账单
POST   /api/credit-bills/generate   生成账单
GET    /api/debts                   借贷管理
GET    /api/savings                 储蓄目标
GET    /api/recurring               周期交易
GET    /api/reimbursements          报销管理
GET    /api/families                家庭管理
GET    /api/ai/suggestions          AI建议
POST   /api/ai/categorize           AI分类
GET    /api/exchange-rates          汇率查询
```

---

## 七、开发计划

### 7.1 第一阶段：基础框架（2周）

- [ ] Flutter项目初始化
- [ ] 基础UI组件库（萌趣风格）
- [ ] 本地数据库设计
- [ ] 离线存储框架
- [ ] 服务器配置页面
- [ ] 登录/注册页面

### 7.2 第二阶段：核心功能（3周）

- [ ] 首页（收支概览、预算进度、最近账单）
- [ ] 记账功能（快速模式、完整模式）
- [ ] 交易列表（筛选、搜索）
- [ ] 账户管理
- [ ] 分类管理
- [ ] 离线同步机制

### 7.3 第三阶段：扩展功能（3周）

- [ ] 统计分析（图表、报表）
- [ ] 预算管理
- [ ] 信用账单
- [ ] 借贷管理
- [ ] 储蓄目标
- [ ] 周期交易

### 7.4 第四阶段：高级功能（2周）

- [ ] AI助手（自然语言记账、智能分类）
- [ ] 家庭协作
- [ ] 导入导出
- [ ] 推送通知
- [ ] 数据备份恢复

### 7.5 第五阶段：优化完善（2周）

- [ ] 性能优化
- [ ] 动画效果
- [ ] 主题定制
- [ ] 多语言支持
- [ ] 测试覆盖
- [ ] 文档完善

---

## 八、附录

### 8.1 SVG图标资源

**推荐图标库**：
- [Flaticon](https://www.flaticon.com/) - 免费SVG图标
- [Icons8](https://icons8.com/) - 风格统一的图标
- [Undraw](https://undraw.co/) - 插画风格

**自定义图标规范**：
- 尺寸：24x24dp（标准）
- 格式：SVG
- 颜色：使用currentColor，支持主题切换
- 圆角：所有直角改为圆角（rx="4"）
- 线条：2px描边，圆角端点

### 8.2 字体推荐

**英文**：
- Nunito - 圆润可爱
- Quicksand - 现代圆润
- Poppins - 简洁友好

**中文**：
- 思源黑体 - 开源，支持多种字重
- 阿里巴巴普惠体 - 免费商用
- 站酷快乐体 - 卡通风格

### 8.3 动画资源

**Lottie动画**：
- [LottieFiles](https://lottiefiles.com/) - 免费动画资源
- 加载动画、成功动画、空状态动画

**Rive动画**：
- 交互动画、状态机动画
- 可自定义的矢量动画
