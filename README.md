# family-finance

家庭记账系统 — 快速记账 + 完整资金追踪 + 家庭协作 + 灵活分析

## 技术栈

| 层级 | 技术 |
|------|------|
| 后端 | Python FastAPI + SQLAlchemy 2.0 (async) + PostgreSQL 15 |
| 前端 | Vue 3 + TypeScript + Vite + Element Plus + ECharts |
| 部署 | Docker Compose (db + api + web + nginx) |

## 快速开始

```bash
# 1. 复制环境变量
cp .env.example .env
vim .env  # 修改密码等配置

# 2. 启动
docker compose up -d

# 3. 检查
docker compose ps
curl http://localhost/health
```

## 项目结构

```
├── docker-compose.yml
├── .env.example
├── db/init/          # 数据库初始化 SQL（建表 + 种子数据）
├── backend/          # FastAPI 后端
├── frontend/         # Vue3 前端
├── nginx/            # Nginx 反向代理配置
└── research/         # 设计文档
```

## 设计文档

- [完整设计文档](research/完整设计文档.md)
- [数据库设计方案](research/数据库设计方案v2.md)
- [分类体系设计](research/分类体系设计.md)
- [项目总结文档](research/项目总结文档.md)
