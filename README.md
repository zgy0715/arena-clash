<div align="center">
  <h1>⚔️ Arena Clash · 竞技场对决</h1>
  <p><strong>多人在线竞技游戏数据管理平台 · 数据库综合实验</strong></p>
  <br>
  <p>
    <img src="https://img.shields.io/badge/PostgreSQL-16-336791?style=flat&logo=postgresql&logoColor=white">
    <img src="https://img.shields.io/badge/Redis-7-DC382D?style=flat&logo=redis&logoColor=white">
    <img src="https://img.shields.io/badge/Python-3.13-3776AB?style=flat&logo=python&logoColor=white">
    <img src="https://img.shields.io/badge/FastAPI-0.115-009688?style=flat&logo=fastapi&logoColor=white">
    <img src="https://img.shields.io/badge/Vue-3.5-4FC08D?style=flat&logo=vue.js&logoColor=white">
    <img src="https://img.shields.io/badge/ECharts-5.6-AA344D?style=flat">
    <img src="https://img.shields.io/badge/Docker-Compose-2496ED?style=flat&logo=docker&logoColor=white">
  </p>
</div>

---

## 📋 项目简介

**Arena Clash** 是一个多人在线竞技游戏（MOBA）数据管理平台，模拟了完整的游戏数据后端。以 **PostgreSQL** 为核心持久化数据库、**Redis** 为实时数据引擎，覆盖了数据库课程的**全部高级特性**。

### 🎯 为什么是游戏场景？

传统实验选题（学生选课、图书管理、库存系统）只能用到数据库基础的 CRUD。而游戏对战场景天然需要：

| 需求 | 数据库特性 |
|------|-----------|
| 对战结算（10人并发） | **存储过程** + **行级锁** |
| 实时排行榜 | **Redis Sorted Set** |
| 段位分布统计 | **NTILE 窗口函数** |
| 战绩走势 | **滑动窗口** (ROWS BETWEEN) |
| 扩展数据存储 | **JSONB** + **GIN 索引** |
| 胜率自动计算 | **生成列** (GENERATED ALWAYS AS) |
| 赛季重置批量操作 | **CTE** (WITH 子句) |
| 赛季统计预计算 | **物化视图** |
| 数据完整性 | **CHECK 约束** |
| 状态自动同步 | **触发器** |

---

## 🏗️ 系统架构

```
┌───────────────────────────────────────────────────────────┐
│                     前端 (Frontend)                         │
│      Vue 3 + Vite + Element Plus + ECharts + Vue Router    │
├───────────────────────────────────────────────────────────┤
│                    后端 (Backend API)                       │
│   Python 3.13 + FastAPI + SQLAlchemy 2.0 + SlowAPI 限流    │
│   JWT 认证 · Pydantic v2 校验 · structlog 结构化日志        │
├───────────────────────────────────────────────────────────┤
│                  数据层 (Data Layer)                        │
│  ┌─────────────────┐    ┌────────────────────┐            │
│  │  PostgreSQL 16   │    │    Redis 7          │            │
│  │  持久化主库      │    │  实时排行榜         │            │
│  │  存储过程/触发器  │    │  匹配队列           │            │
│  │  复杂查询/统计   │    │  会话管理(TTL)      │            │
│  │  事务保证        │    │  AOF+密码认证       │            │
│  └─────────────────┘    └────────────────────┘            │
├───────────────────────────────────────────────────────────┤
│              部署 (Deployment)                              │
│           Docker Compose · Nginx 反向代理                   │
└───────────────────────────────────────────────────────────┘
```

---

## ✨ 功能模块

```
Arena Clash 竞技场对决
├── 👤 玩家管理        注册/登录（JWT） · 资料 CRUD · 战绩查询 · 段位信息
├── ⚔️ 匹配系统        ELO 评分匹配 · Redis Stream 队列 · 匹配倒计时
├── 🏟️ 对战系统        创建房间 · 状态同步（触发器） · 结算（存储过程） · MVP 评选
├── 🏆 排行榜          Redis 实时排行（< 5ms） · PG 赛季排行 · NTILE 段位分布
├── 🛒 虚拟商城        商品列表 · 购买（行级锁 + 存储过程） · 限流防刷
├── 📊 数据大屏        ECharts 可视化 · 对战趋势 · 英雄统计 · 段位分布
├── 🔄 赛季系统        赛季重置（存储过程 + CTE） · 段位衰减 · 历史归档
└── 🏗️ 系统功能        限流 · 结构化日志 · 审计日志 · 健康检查
```

---

## 🖥️ 前端可视化

5 个页面，**8 张 ECharts 动态图表**：

| 页面 | 图表 | 数据来源 |
|------|------|---------|
| 📊 **数据大屏** | 段位分布饼图 · 英雄出场率饼图 · 英雄胜率柱状图 · 对战趋势折线图 | API + NTILE + 物化视图 |
| 🏆 **排行榜** | ELO 排行榜柱状图 · 段位分布饼图 | Redis Sorted Set |
| 👤 **玩家查询** | KDA 走势折线图（含5场滑动窗口） · 累计ELO面积图 | 窗口函数 ROWS BETWEEN |

---

## 📚 数据库特性全覆盖

| 特性 | 数量 | 说明 |
|------|------|------|
| 🗃️ **表** | 11 张 | season / rank_tier / player / hero / match_record / match_detail / player_season_rank / shop_item / purchase_record / audit_log |
| 📌 **存储过程** | 4 个 | `fn_settle_match` 对战结算 · `fn_purchase_item` 商品购买 · `fn_reset_season` 赛季重置 · `fn_generate_match_code` 编号生成 |
| ⚡ **触发器** | 4 个 | updated_at 自动更新 · 对战状态同步 · 编号自动填充 |
| 📊 **窗口函数** | 5 种 | RANK / LAG / LEAD / NTILE / 滑动窗口 (ROWS BETWEEN) |
| 🔗 **CTE** | ✅ | 赛季重置批量段位衰减 (WITH 子句) |
| 📦 **JSONB + GIN** | ✅ | match_detail.extra_data 扩展字段存储 |
| 🔒 **行级锁** | ✅ | `SELECT ... FOR UPDATE` 并发防超卖 |
| 🏗️ **物化视图** | ✅ | `mv_season_statistics` 赛季英雄统计预计算 |
| 🔢 **生成列** | ✅ | kda (STORED) · win_rate (STORED) |
| ✅ **CHECK 约束** | 12 个 | 状态枚举 · 值范围 · 时间合法性 · 库存校验 |
| 📎 **索引** | 16 个 | 普通索引 · 复合索引 · 条件索引 · GIN 索引 |

---

## 🔌 API 接口一览

| 方法 | 路径 | 限流 | 说明 |
|------|------|------|------|
| POST | /api/auth/register | 5/分 | 注册 |
| POST | /api/auth/login | 10/分 | 登录 |
| GET | /api/players/{id} | 60/分 | 玩家信息 |
| GET | /api/players/{id}/stats | 30/分 | 战绩统计（窗口函数演示） |
| POST | /api/matchmaking/join | 5/分 | 加入匹配（Redis Sorted Set） |
| POST | /api/matches/create | 10/分 | 创建对战（触发器生成编号） |
| POST | /api/matches/{id}/settle | 10/分 | 结算（存储过程 + 行级锁） |
| GET | /api/leaderboard/global | 30/分 | 全服排行（Redis < 5ms） |
| GET | /api/leaderboard/season/{id} | 30/分 | 赛季排行（RANK + LAG + LEAD） |
| POST | /api/leaderboard/sync | 1/分 | PG → Redis 全量同步 |
| POST | /api/shop/purchase | 10/分 | 购买（行级锁 + 限流） |
| GET | /api/stats/tier-distribution | 30/分 | 段位分布（NTILE 分桶） |
| GET | /api/stats/hero-stats | 30/分 | 英雄出场率/胜率统计 |
| GET | /api/stats/mv-season | 30/分 | 物化视图查询 |
| WS | /ws/game?token=jwt | - | 实时通信 |

---

## 🚀 快速启动

### 方式一：本地开发（推荐）

```bash
# 1. 克隆项目
git clone https://github.com/zgy0715/arena-clash.git
cd arena-clash

# 2. 配置数据库连接
# 编辑 backend/.env，修改为你本地的 PostgreSQL 和 Redis 连接信息

# 3. 导入数据库
psql -U postgres -d postgres -c "CREATE DATABASE arena_clash;"
psql -U postgres -d arena_clash < sql/init.sql
psql -U postgres -d arena_clash < sql/procedures.sql
psql -U postgres -d arena_clash < sql/triggers.sql
psql -U postgres -d arena_clash < sql/sample_data.sql

# 4. 启动后端
cd backend
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8001 --reload

# 5. 启动前端（新终端）
cd frontend
npm install
npm run dev
```

### 方式二：Docker 一键部署

```bash
cp .env.example .env    # 修改密码
docker-compose up -d     # 一键启动所有服务
```

---

## 📂 项目结构

```
arena-clash/
├── docker-compose.yml           # 容器编排
├── .env.example                 # 环境变量模板
├── .gitignore
├── README.md
├── 实验报告.md                    # 完整实验报告（实验四）
├── backend/                     # Python FastAPI 后端
│   ├── main.py                  # 入口 + 限流 + 结构化日志
│   ├── config.py                # pydantic-settings 配置
│   ├── database.py              # SQLAlchemy 异步连接池
│   ├── redis_client.py          # Redis 连接
│   ├── dependencies.py          # JWT 认证
│   ├── routers/                 # 8 个路由模块
│   │   ├── auth.py              # 注册/登录
│   │   ├── players.py           # 玩家信息/战绩
│   │   ├── matchmaking.py       # 匹配队列
│   │   ├── matches.py           # 对战管理系统
│   │   ├── leaderboard.py       # 排行榜
│   │   ├── shop.py              # 商城（限流）
│   │   ├── stats.py             # 数据统计
│   │   └── websocket.py         # 实时通信
│   ├── services/                # 业务服务
│   │   └── leaderboard_service.py
│   ├── requirements.txt
│   └── Dockerfile
├── frontend/                    # Vue 3 + Vite 前端
│   ├── index.html
│   ├── vite.config.js
│   ├── package.json
│   ├── src/
│   │   ├── main.js              # 入口
│   │   ├── App.vue              # 布局 + 导航
│   │   ├── api/index.js         # Axios API 封装
│   │   ├── router/index.js      # 路由
│   │   ├── styles/main.css      # 暗黑主题样式
│   │   └── views/
│   │       ├── Dashboard.vue    # 数据大屏（4张图）
│   │       ├── Leaderboard.vue  # 排行榜（2张图）
│   │       ├── Players.vue      # 玩家查询（2张图）
│   │       ├── Matches.vue      # 对战列表
│   │       └── Shop.vue         # 虚拟商城
│   ├── nginx.conf
│   └── Dockerfile
├── sql/                         # 数据库脚本
│   ├── init.sql                 # DDL + 索引 + 物化视图
│   ├── procedures.sql           # 4 个存储过程
│   ├── triggers.sql             # 触发器
│   └── sample_data.sql          # 测试数据（25玩家 + 100对战）
├── scripts/
│   ├── generate_data.py         # 大规模数据生成器（可配500用户）
│   └── demo_queries.sql         # 实验验收 SQL 演示脚本
└── redis/
    └── redis.conf               # AOF + RDB 持久化
```

---

## 🧪 实验验收演示

```bash
# 运行完整的 SQL 演示（12个验收点）
psql -U postgres -d arena_clash < scripts/demo_queries.sql
```

演示内容包含：

| # | 演示 | SQL 特性 | 验证方式 |
|---|------|---------|---------|
| 1 | 对战详情 | **4表 JOIN** + CASE | 玩家 ↔ 英雄 ↔ 对战 ↔ 详情 |
| 2 | 排行榜 | **RANK + LAG + LEAD** | 排名无跳号、分差正确 |
| 3 | 段位分布 | **NTILE(4)** | 四档人数之和 = 总玩家 |
| 4 | 晋升路线 | **LAG + LEAD** | 上下段位 + 晋级分差 |
| 5 | 扩展数据 | **JSONB + ? + ->>** | 守卫数、视野分提取 |
| 6 | 战绩走势 | **ROWS 滑动窗口** | 近5场 KDA 移动平均 |
| 7 | 对战结算 | **存储过程 fn_settle_match** | KDA 评选 MVP + 段位更新 |
| 8 | 商品购买 | **存储过程 fn_purchase_item** | 扣金币 + 减库存 |
| 9 | 赛季统计 | **物化视图** | 预计算 vs 实时查询一致 |
| 10 | updated_at | **触发器 fn_update_timestamp** | UPDATE 后自动更新时间 |
| 11 | CHECK 约束 | 状态枚举 + 值范围 | 非法数据被拒绝 |
| 12 | 全局统计 | 聚合函数 | 玩家/对战/商品汇总 |

---

## 🛠️ 技术栈

| 分类 | 技术 | 版本 |
|------|------|------|
| **关系数据库** | PostgreSQL | 16 |
| **内存数据库** | Redis | 7 |
| **后端框架** | FastAPI + SQLAlchemy 2.0 | Python 3.13 |
| **前端** | Vue 3 + Vite + Element Plus | Node 20 |
| **可视化** | ECharts | 5 |
| **安全认证** | JWT + bcrypt + SlowAPI | - |
| **数据校验** | Pydantic v2 + CHECK 约束 | 双重校验 |
| **日志** | structlog | 结构化 JSON |
| **部署** | Docker Compose + Nginx | 容器化 |

---

## 📄 许可证

本项目为 **数据库原理综合实验** 课程设计，仅用于教学目的。
