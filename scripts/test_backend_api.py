#!/usr/bin/env python3
"""后端 API 全量测试 — Phase 2/3/4 验证"""
import requests
import json
import sys

BASE = "http://127.0.0.1:8000/api"
TOKEN = None
HEADERS = {}
results = {"pass": 0, "fail": 0, "errors": []}
created_ids = {}


def log(ok, msg):
    tag = "✅" if ok else "❌"
    results["pass" if ok else "fail"] += 1
    if not ok:
        results["errors"].append(msg)
    print(f"  {tag} {msg}")


def get(path, params=None, expect=200):
    r = requests.get(f"{BASE}{path}", headers=HEADERS, params=params)
    ok = r.status_code == expect
    log(ok, f"GET {path} → {r.status_code} (expect {expect})")
    if not ok:
        print(f"     body: {r.text[:300]}")
    return r.json() if r.status_code < 300 else None


def post(path, data, expect=201):
    r = requests.post(f"{BASE}{path}", headers=HEADERS, json=data)
    ok = r.status_code == expect
    log(ok, f"POST {path} → {r.status_code} (expect {expect})")
    if not ok:
        print(f"     body: {r.text[:300]}")
    return r.json() if r.status_code < 300 else None


def put(path, data, expect=200):
    r = requests.put(f"{BASE}{path}", headers=HEADERS, json=data)
    ok = r.status_code == expect
    log(ok, f"PUT {path} → {r.status_code} (expect {expect})")
    if not ok:
        print(f"     body: {r.text[:300]}")
    return r.json() if r.status_code < 300 else None


def patch(path, data, expect=200):
    r = requests.patch(f"{BASE}{path}", headers=HEADERS, json=data)
    ok = r.status_code == expect
    log(ok, f"PATCH {path} → {r.status_code} (expect {expect})")
    if not ok:
        print(f"     body: {r.text[:300]}")
    return r.json() if r.status_code < 300 else None


def delete(path, expect=204):
    r = requests.delete(f"{BASE}{path}", headers=HEADERS)
    ok = r.status_code == expect
    log(ok, f"DELETE {path} → {r.status_code} (expect {expect})")
    if not ok:
        print(f"     body: {r.text[:300]}")
    return r.json() if r.text.strip() else None


# ========== 1.1 认证模块 ==========
def test_auth():
    print("\n=== 1.1 认证模块 (8 cases) ===")
    global TOKEN, HEADERS

    r = requests.post(f"{BASE}/auth/login", json={"phone": "13800138000", "password": "123456"})
    log(r.status_code == 200 and "access_token" in r.json(), "正常登录")
    TOKEN = r.json()["access_token"]
    HEADERS = {"Authorization": f"Bearer {TOKEN}"}

    r = requests.post(f"{BASE}/auth/login", json={"phone": "13800138000", "password": "wrong"})
    log(r.status_code == 401, "密码错误 → 401")

    r = requests.post(f"{BASE}/auth/login", json={"phone": "13800138000", "password": ""})
    log(r.status_code in (400, 401, 422), "空密码 → 4xx")

    r = requests.post(f"{BASE}/auth/register", json={"phone": "13800138000", "password": "123456", "nickname": "test"})
    log(r.status_code == 409, "已注册手机号 → 409")

    r = get("/users/me")
    if r:
        log("phone" in r, "用户信息含 phone 字段")

    r = requests.get(f"{BASE}/users/me")
    log(r.status_code in (401, 403), f"未认证访问 → {r.status_code}")


# ========== 1.2 交易模块 ==========
def test_transactions():
    print("\n=== 1.2 交易模块 (32 cases) ===")

    # 先获取默认 book_id
    r = get("/books")
    book_id = 1
    if r and isinstance(r, list) and len(r) > 0:
        book_id = r[0].get("id", 1)
    elif r and isinstance(r, dict):
        items = r.get("items", r.get("data", []))
        if items:
            book_id = items[0].get("id", 1)

    # 创建交易
    data = {
        "book_id": book_id,
        "amount": 15000,
        "type": "expense",
        "transaction_time": "2026-08-18T10:00:00",
        "merchant_name": "星巴克",
        "description": "下午茶",
        "payment_account_id": 1,
        "category_id": 1,
    }
    r = post("/transactions", data, 201)
    if r:
        created_ids["tx1"] = r.get("id")

    # 创建多条
    for i, (amount, tx_type, cat_id) in enumerate([
        (25000, "expense", 1), (50000, "income", 2),
        (8000, "expense", 1), (120000, "income", 2),
    ]):
        d = {
            "book_id": book_id, "amount": amount, "type": tx_type,
            "transaction_time": f"2026-08-{15+i:02d}T12:00:00",
            "merchant_name": f"测试商户{i+1}",
            "payment_account_id": 1, "category_id": cat_id,
        }
        post("/transactions", d, 201)

    # 列表
    r = get("/transactions")
    if r is not None:
        items = r.get("items", r.get("data", r)) if isinstance(r, dict) else r
        log(isinstance(items, list), "列表返回数组")
        log(len(items) > 0, "列表非空")

    # 分页
    r = get("/transactions", {"page": 1, "page_size": 2})
    if r:
        items = r.get("items", r.get("data", []))
        log(len(items) <= 2, "分页限制数量")

    r = get("/transactions", {"page": 9999})
    if r:
        items = r.get("items", r.get("data", []))
        log(len(items) == 0, "超出页数返回空")

    # 筛选 - 按类型
    r = get("/transactions", {"type": "expense"})
    if r:
        items = r.get("items", r.get("data", []))
        log(all(t.get("type") == "expense" for t in items) if items else True, "类型筛选正确")

    # 筛选 - 按关键词
    r = get("/transactions", {"keyword": "星巴克"})
    if r:
        items = r.get("items", r.get("data", []))
        log(len(items) > 0, "关键词搜索返回结果")

    r = get("/transactions", {"keyword": "不存在的关键词"})
    if r:
        items = r.get("items", r.get("data", []))
        log(len(items) == 0, "不存在关键词返回空")

    # 日期范围
    r = get("/transactions", {"start_date": "2026-08-01", "end_date": "2026-08-31"})
    log(r is not None, "日期范围筛选")

    # 金额范围
    r = get("/transactions", {"min_amount": 10000, "max_amount": 50000})
    log(r is not None, "金额范围筛选")

    # 组合筛选
    r = get("/transactions", {"type": "expense", "start_date": "2026-08-01", "end_date": "2026-08-31"})
    log(r is not None, "组合筛选")

    # 获取单条
    if created_ids.get("tx1"):
        r = get(f"/transactions/{created_ids['tx1']}")
        if r:
            d = r if isinstance(r, dict) else {}
            log(d.get("amount") is not None, "单条含 amount")

    # 不存在的 id
    get("/transactions/999999", expect=404)

    # 更新
    if created_ids.get("tx1"):
        r = put(f"/transactions/{created_ids['tx1']}", {"merchant_name": "新商户"})
        log(r is not None, "更新交易成功")

    # 删除
    if created_ids.get("tx1"):
        delete(f"/transactions/{created_ids['tx1']}", 204)
        get(f"/transactions/{created_ids['tx1']}", expect=404)

    # 批量创建
    batch_data = {
        "items": [
            {"book_id": book_id, "amount": 1000, "type": "expense", "transaction_time": "2026-08-18T10:00:00", "payment_account_id": 1, "category_id": 1},
            {"book_id": book_id, "amount": 2000, "type": "expense", "transaction_time": "2026-08-18T11:00:00", "payment_account_id": 1, "category_id": 1},
        ]
    }
    r = post("/transactions/batch", batch_data, 200)

    # 批量更新
    r = patch("/transactions/batch", {"ids": [1, 2, 3], "updates": {"merchant_name": "批量更新"}}, 200)


# ========== 1.3 账户模块 ==========
def test_accounts():
    print("\n=== 1.3 账户模块 (10 cases) ===")

    r = get("/accounts")
    if r is not None:
        items = r if isinstance(r, list) else r.get("items", r.get("data", []))
        log(isinstance(items, list), "账户列表返回数组")

    r = post("/accounts", {
        "name": "测试账户", "type_code": "cash", "initial_balance": 100000, "currency": "CNY",
    }, 201)
    if r:
        created_ids["acc1"] = r.get("id")

    r = post("/accounts", {
        "name": "测试信用卡", "type_code": "credit_card", "initial_balance": 0,
        "credit_limit": 5000000, "billing_day": 5, "due_day": 25,
    }, 201)

    if created_ids.get("acc1"):
        r = get(f"/accounts/{created_ids['acc1']}")
        if r:
            d = r if isinstance(r, dict) else {}
            log("name" in d, "获取单条含 name")

    get("/accounts/999999", expect=404)

    if created_ids.get("acc1"):
        r = put(f"/accounts/{created_ids['acc1']}", {"name": "测试账户-改名"})
        log(r is not None, "更新账户成功")

    if created_ids.get("acc1"):
        r = get(f"/accounts/{created_ids['acc1']}/balance")
        log(r is not None, "获取余额详情")

    if created_ids.get("acc1"):
        r = requests.delete(f"{BASE}/accounts/{created_ids['acc1']}", headers=HEADERS)
        log(r.status_code in (200, 204), f"删除账户 → {r.status_code}")

    r = get("/accounts")
    log(r is not None, "删除后列表正常")


# ========== 1.4 预算模块 ==========
def test_budgets():
    print("\n=== 1.4 预算模块 (12 cases) ===")

    r = get("/budgets")
    log(r is not None, "预算列表返回200")

    r = get("/budgets", {"year": 2026, "month": 8})
    log(r is not None, "按年月筛选")

    r = post("/budgets", {
        "period": "monthly", "year": 2026, "month": 8, "amount": 500000, "category_id": 1,
    }, 201)
    if r:
        created_ids["budget1"] = r.get("id")

    # 周度 (year required)
    r = post("/budgets", {
        "period": "weekly", "year": 2026, "amount": 100000, "week_start_date": "2026-08-18", "category_id": 1,
    }, 201)

    # 年度
    r = post("/budgets", {
        "period": "yearly", "year": 2026, "amount": 6000000, "category_id": 1,
    }, 201)

    # 月度缺 month → 400
    r = requests.post(f"{BASE}/budgets", headers=HEADERS, json={
        "period": "monthly", "year": 2026, "amount": 500000, "category_id": 1,
    })
    log(r.status_code in (400, 422), f"月度缺 month → {r.status_code}")

    if created_ids.get("budget1"):
        r = get(f"/budgets/{created_ids['budget1']}")
        log(r is not None, "获取单条预算")

        r = get(f"/budgets/{created_ids['budget1']}/usage")
        log(r is not None, "获取预算使用情况")

        r = put(f"/budgets/{created_ids['budget1']}", {"amount": 600000})
        log(r is not None, "更新预算金额")

        delete(f"/budgets/{created_ids['budget1']}", 204)
        get(f"/budgets/{created_ids['budget1']}", expect=404)


# ========== 1.5 分类模块 ==========
def test_categories():
    print("\n=== 1.5 分类模块 (12 cases) ===")

    r = get("/categories")
    log(r is not None, "分类树返回200")

    r = get("/categories", {"type": "expense"})
    log(r is not None, "支出分类筛选")

    r = get("/categories", {"type": "income"})
    log(r is not None, "收入分类筛选")

    r = get("/categories/flat")
    log(r is not None, "平铺列表返回200")

    # 创建
    r = post("/categories", {
        "name": "测试分类A", "type": "expense", "icon": "test", "color": "#FF0000",
    }, 201)
    if r:
        created_ids["cat_parent"] = r.get("id")

    # 创建子分类
    if created_ids.get("cat_parent"):
        r = post("/categories", {
            "name": "测试子分类A1", "type": "expense", "parent_id": created_ids["cat_parent"],
        }, 201)
        if r:
            created_ids["cat_child"] = r.get("id")

    # 更新
    if created_ids.get("cat_parent"):
        r = put(f"/categories/{created_ids['cat_parent']}", {"name": "测试分类A-改名"})
        log(r is not None, "更新分类")

    # 删除有子分类的 → 400
    if created_ids.get("cat_parent"):
        r = requests.delete(f"{BASE}/categories/{created_ids['cat_parent']}", headers=HEADERS)
        log(r.status_code == 400, f"删除有子分类的 → {r.status_code}")

    # 先删子分类
    if created_ids.get("cat_child"):
        delete(f"/categories/{created_ids['cat_child']}", 204)

    # 再删父分类
    if created_ids.get("cat_parent"):
        r = requests.delete(f"{BASE}/categories/{created_ids['cat_parent']}", headers=HEADERS)
        log(r.status_code in (200, 204), f"删除分类 → {r.status_code}")

    # 系统分类不可修改
    r = requests.put(f"{BASE}/categories/1", headers=HEADERS, json={"name": "hack"})
    log(r.status_code == 403, f"修改系统分类 → {r.status_code} (expect 403)")


# ========== 1.6 标签模块 ==========
def test_tags():
    print("\n=== 1.6 标签模块 (7 cases) ===")

    r = get("/tags")
    log(r is not None, "标签列表返回200")

    r = post("/tags", {"name": "测试标签X", "color": "#FF0000"}, 201)
    if r:
        created_ids["tag1"] = r.get("id")

    r = requests.post(f"{BASE}/tags", headers=HEADERS, json={"name": "测试标签X", "color": "#00FF00"})
    log(r.status_code == 409, f"重名标签 → {r.status_code}")

    if created_ids.get("tag1"):
        r = put(f"/tags/{created_ids['tag1']}", {"name": "测试标签X-改名"})
        log(r is not None, "更新标签")

        r = requests.delete(f"{BASE}/tags/{created_ids['tag1']}", headers=HEADERS)
        log(r.status_code in (200, 204), f"删除标签 → {r.status_code}")


# ========== 1.7 统计模块 ==========
def test_stats():
    print("\n=== 1.7 统计模块 (11 cases) ===")

    r = get("/stats/summary")
    log(r is not None, "收支汇总返回200")

    r = get("/stats/summary", {"start": "2026-08-01", "end": "2026-08-31"})
    log(r is not None, "按月汇总")

    r = get("/stats/summary", {"book_id": 1})
    log(r is not None, "按账本汇总")

    r = get("/stats/by-category", {"type": "expense"})
    log(r is not None, "支出分类统计")

    r = get("/stats/by-category", {"type": "income"})
    log(r is not None, "收入分类统计")

    r = get("/stats/by-category", {"type": "expense", "limit": 5})
    log(r is not None, "分类统计限制数量")

    r = get("/stats/by-day", {"start": "2026-08-01", "end": "2026-08-31", "type": "expense"})
    log(r is not None, "日统计")

    r = get("/stats/by-month", {"year": 2026})
    log(r is not None, "月统计")

    r = get("/stats/merchant-ranking", {"limit": 10})
    log(r is not None, "商户排行")

    # compare 需要 "start:end" 格式
    r = get("/stats/compare", {"current": "2026-08-01:2026-08-31", "previous": "2026-07-01:2026-07-31"})
    log(r is not None, "同比环比")

    r = get("/stats/cross", {"dimension1": "category", "dimension2": "month"})
    log(r is not None, "交叉分析")


# ========== 1.8 离线注册同步 ==========
def test_sync():
    print("\n=== 1.8 离线注册同步 (3 cases) ===")

    r = post("/sync/register", {
        "client_id": "test-client-100",
        "phone": "13900139100",
        "password_hash": "hashed_pwd",
        "nickname": "离线用户100",
    }, 201)
    log(r is not None, "离线注册")

    # 幂等性
    r2 = post("/sync/register", {
        "client_id": "test-client-100",
        "phone": "13900139100",
        "password_hash": "hashed_pwd",
        "nickname": "离线用户100",
    }, 201)
    if r and r2:
        sid1 = r.get("server_id")
        sid2 = r2.get("server_id")
        log(sid1 == sid2 if sid1 and sid2 else True, "幂等性验证")

    # 手机号冲突
    r = requests.post(f"{BASE}/sync/register", json={
        "client_id": "test-client-101",
        "phone": "13800138000",
        "password_hash": "hashed",
        "nickname": "冲突",
    })
    log(r.status_code == 409, f"手机号冲突 → {r.status_code}")


# ========== Phase 3: 信用账单 ==========
def test_credit_bills():
    print("\n=== Phase 3: 信用账单模块 ===")
    r = get("/credit-bills")
    log(r is not None, "信用账单列表")
    r = get("/credit-bills/summary")
    log(r is not None, "信用账单汇总")


# ========== Phase 3: 借贷管理 ==========
def test_debts():
    print("\n=== Phase 3: 借贷管理模块 ===")
    r = get("/debts")
    log(r is not None, "借贷列表")

    r = post("/debts", {
        "type": "lend",
        "counterparty": "张三",
        "amount": 100000,
        "debt_date": "2026-08-18",
        "due_date": "2026-09-18",
    }, 201)
    if r:
        created_ids["debt1"] = r.get("id")

    if created_ids.get("debt1"):
        r = get(f"/debts/{created_ids['debt1']}")
        log(r is not None, "借贷详情")

        r = post(f"/debts/{created_ids['debt1']}/repayments", {
            "amount": 50000, "repayment_date": "2026-08-18",
        }, 201)
        log(r is not None, "还款记录")

        delete(f"/debts/{created_ids['debt1']}", 204)


# ========== Phase 3: 储蓄目标 ==========
def test_savings():
    print("\n=== Phase 3: 储蓄目标模块 ===")
    r = get("/savings")
    log(r is not None, "储蓄目标列表")

    r = post("/savings", {
        "name": "旅行基金", "target_amount": 5000000,
        "start_date": "2026-08-01", "target_date": "2026-12-31",
    }, 201)
    if r:
        created_ids["goal1"] = r.get("id")

    if created_ids.get("goal1"):
        r = get(f"/savings/{created_ids['goal1']}")
        log(r is not None, "储蓄目标详情")
        delete(f"/savings/{created_ids['goal1']}", 204)


# ========== Phase 3: 周期交易 ==========
def test_recurring():
    print("\n=== Phase 3: 周期交易模块 ===")
    r = get("/recurring")
    log(r is not None, "周期交易列表")

    r = post("/recurring", {
        "book_id": 1, "type": "expense", "amount": 150000,
        "category_id": 1, "payment_account_id": 1,
        "frequency": "monthly", "day_of_month": 1, "start_date": "2026-08-01",
        "description": "月租金",
    }, 201)
    if r:
        created_ids["rec1"] = r.get("id")

    if created_ids.get("rec1"):
        r = get(f"/recurring/{created_ids['rec1']}")
        log(r is not None, "周期交易详情")
        delete(f"/recurring/{created_ids['rec1']}", 204)


# ========== Phase 3: 报销管理 ==========
def test_reimbursements():
    print("\n=== Phase 3: 报销管理模块 ===")
    r = get("/reimbursements")
    log(r is not None, "报销列表")

    # 先创建一条交易用于报销关联
    r_tx = requests.post(f"{BASE}/transactions", headers=HEADERS, json={
        "book_id": 1, "amount": 200000, "type": "expense",
        "transaction_time": "2026-08-15T10:00:00",
        "payment_account_id": 1, "category_id": 1,
    })
    tx_id = r_tx.json().get("id") if r_tx.status_code == 201 else None

    if tx_id:
        r = post("/reimbursements", {
            "title": "出差报销", "total_amount": 200000,
            "items": [{"transaction_id": tx_id, "amount": 200000, "description": "机票"}],
        }, 201)
        if r:
            created_ids["reimb1"] = r.get("id")

        if created_ids.get("reimb1"):
            r = get(f"/reimbursements/{created_ids['reimb1']}")
            log(r is not None, "报销详情")
            delete(f"/reimbursements/{created_ids['reimb1']}", 204)
    else:
        log(False, "无法创建交易用于报销关联")


# ========== Phase 3: 导入导出 ==========
def test_import_export():
    print("\n=== Phase 3: 导入导出模块 ===")
    r = get("/imports")
    log(r is not None, "导入记录列表")
    r = requests.get(f"{BASE}/export/transactions", headers=HEADERS)
    log(r.status_code == 200, f"导出交易数据 → {r.status_code}")


# ========== Phase 4: AI 助手 ==========
def test_ai():
    print("\n=== Phase 4: AI 助手模块 ===")
    r = get("/ai/settings")
    log(r is not None, "AI 配置获取")
    r = get("/ai/suggestions")
    log(r is not None, "AI 建议列表")
    r = post("/ai/parse", {"text": "今天中午在麦当劳吃了30元午饭"}, 200)
    log(r is not None, "AI 文本解析")


# ========== Phase 4: 家庭协作 ==========
def test_family():
    print("\n=== Phase 4: 家庭协作模块 ===")
    r = get("/families/current")
    log(r is not None, "当前家庭信息")
    r = get("/families/members")
    log(r is not None, "家庭成员列表")


# ========== 主流程 ==========
def main():
    print("=" * 60)
    print("  后端 API 全量测试 — Phase 2/3/4 验证")
    print("=" * 60)

    test_auth()
    test_transactions()
    test_accounts()
    test_budgets()
    test_categories()
    test_tags()
    test_stats()
    test_sync()
    test_credit_bills()
    test_debts()
    test_savings()
    test_recurring()
    test_reimbursements()
    test_import_export()
    test_ai()
    test_family()

    print("\n" + "=" * 60)
    total = results["pass"] + results["fail"]
    print(f"  测试结果: ✅ {results['pass']}/{total} 通过  ❌ {results['fail']} 失败")
    print("=" * 60)

    if results["errors"]:
        print("\n失败项:")
        for e in results["errors"]:
            print(f"  - {e}")

    return 0 if results["fail"] == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
