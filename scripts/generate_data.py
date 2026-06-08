"""
Arena Clash 测试数据生成器
生成规模：500玩家 + 10英雄 + 2000场对战 + 4商品
所有测试账号密码统一为 test1234（bcrypt 哈希）

依赖安装: pip install psycopg2-binary passlib[bcrypt]

用法:
    python scripts/generate_data.py
    # 或指定连接参数:
    python scripts/generate_data.py --host localhost --port 5432 --dbname arena_clash --user arena_admin --password arena_2026_secure_pass
"""
import random
import argparse
from datetime import datetime, timedelta
import psycopg2
from passlib.hash import bcrypt

# ============================================
# 配置
# ============================================
TEST_PASSWORD = "test1234"
TEST_PASSWORD_HASH = bcrypt.hash(TEST_PASSWORD)

HEROES = [
    ("暗影刺客", "暗夜猎手", "assassin", 4500, 8),
    ("炎爆法师", "烈焰之主", "mage", 4800, 7),
    ("钢铁卫士", "不灭守护", "tank", 3150, 3),
    ("疾风剑豪", "风暴之刃", "fighter", 6300, 9),
    ("星辰射手", "破晓之光", "marksman", 4800, 6),
    ("圣光使者", "黎明祝福", "support", 1350, 2),
    ("月影追踪", "暗夜猎手", "assassin", 4800, 8),
    ("寒冰女巫", "霜之哀伤", "mage", 6300, 7),
    ("狂暴战士", "血之怒吼", "fighter", 3150, 4),
    ("幽灵守卫", "迷雾之盾", "support", 4500, 3),
]

RANK_TIERS = [
    ("青铜 I", 1, 0),
    ("青铜 II", 2, 100),
    ("青铜 III", 3, 200),
    ("白银 I", 4, 400),
    ("白银 II", 5, 600),
    ("白银 III", 6, 800),
    ("黄金 I", 7, 1100),
    ("黄金 II", 8, 1400),
    ("黄金 III", 9, 1700),
]

SHOP_ITEMS = [
    ("暴风大剑", "hero", None, 4500, -1, False),
    ("暗影皮肤", "skin", 1, 9900, 100, True),
    ("庆祝表情", "emote", None, 500, -1, False),
    ("金色边框", "frame", None, 3000, 50, True),
]


def generate(conn, num_players=500, num_matches=2000):
    """生成测试数据"""
    cur = conn.cursor()
    start_time = datetime.now()

    # ---------- 段位 ----------
    print("📊 插入段位数据...")
    for name, level, min_pts in RANK_TIERS:
        cur.execute(
            "INSERT INTO rank_tier(name, tier_level, min_points) VALUES(%s,%s,%s)",
            (name, level, min_pts),
        )

    # ---------- 英雄 ----------
    print("⚔️  插入英雄数据...")
    for name, title, role, price, diff in HEROES:
        cur.execute(
            "INSERT INTO hero(name, title, role, price_gold, difficulty) VALUES(%s,%s,%s,%s,%s)",
            (name, title, role, price, diff),
        )

    # ---------- 赛季 ----------
    print("📅 创建赛季...")
    cur.execute(
        "INSERT INTO season(name, start_date, status) VALUES('S1 青铜时代','2026-01-01','active')"
    )

    # ---------- 玩家 ----------
    print(f"👤 生成 {num_players} 名玩家...")
    for i in range(1, num_players + 1):
        elo = random.randint(800, 2200)
        cur.execute(
            """INSERT INTO player(username, password_hash, nickname, elo_rating, level, experience, gold, total_matches)
               VALUES(%s,%s,%s,%s,%s,%s,%s,%s)""",
            (
                f"player{i}",
                TEST_PASSWORD_HASH,
                f"玩家{i}",
                elo,
                random.randint(1, 30),
                random.randint(0, 50000),
                random.randint(500, 10000),
                random.randint(0, 200),
            ),
        )

    # ---------- 赛季段位 ----------
    print("🏆 生成赛季段位记录...")
    cur.execute("SELECT id, elo_rating FROM player")
    players = cur.fetchall()
    for pid, elo in players:
        tier_id = min(9, max(1, (elo - 800) // 200 + 1))
        pts = max(0, elo - 1500 + random.randint(-100, 100))
        w = random.randint(0, 100)
        total = w + random.randint(0, 100)
        cur.execute(
            """INSERT INTO player_season_rank(player_id, season_id, rank_tier_id, rank_points, peak_points, matches_played, wins, losses)
               VALUES(%s,1,%s,%s,%s,%s,%s,%s)""",
            (pid, tier_id, pts, pts + 200, total, w, total - w),
        )

    # ---------- 对战 ----------
    print(f"⚔️  生成 {num_matches} 场对战...")
    player_ids = [p[0] for p in players]
    for m in range(1, num_matches + 1):
        d = datetime(2026, 1, 1) + timedelta(days=random.randint(0, 150))
        code = f"M-{d.strftime('%Y%m%d')}-{random.randint(0, 65535):04X}"
        dur = random.randint(600, 2700)
        winner = random.choice([1, 2])

        cur.execute(
            """INSERT INTO match_record(match_code, season_id, duration_sec, winner_side, status, started_at, ended_at)
               VALUES(%s,1,%s,%s,'completed',%s,%s)""",
            (code, dur, winner, d, d + timedelta(seconds=dur)),
        )
        mid = cur.lastrowid

        # 随机选10个玩家
        match_players = random.sample(player_ids, 10)
        for idx, pid in enumerate(match_players):
            side = 1 if idx < 5 else 2
            k = random.randint(0, 20)
            d2 = random.randint(0, 15)
            a = random.randint(0, 25)
            cur.execute(
                """INSERT INTO match_detail(match_id, player_id, hero_id, team_side,
                   kills, deaths, assists, damage_dealt, damage_taken, gold_earned, exp_earned, elo_change, extra_data)
                   VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)""",
                (
                    mid, pid, random.randint(1, 10), side,
                    k, d2, a,
                    random.randint(5000, 50000),
                    random.randint(5000, 40000),
                    random.randint(100, 500),
                    random.randint(50, 300),
                    random.randint(-30, 30),
                    f'{{"wards_placed":{random.randint(0,20)},"vision_score":{random.randint(0,50)}}}',
                ),
            )

        if m % 500 == 0:
            print(f"   进度: {m}/{num_matches}")

    # ---------- 商品 ----------
    print("🛒 生成商城商品...")
    for name, itype, hid, price, stock, limited in SHOP_ITEMS:
        cur.execute(
            """INSERT INTO shop_item(name, item_type, hero_id, price_gold, stock, is_limited)
               VALUES(%s,%s,%s,%s,%s,%s)""",
            (name, itype, hid, price, stock, limited),
        )

    conn.commit()
    elapsed = (datetime.now() - start_time).total_seconds()

    # ---------- 统计 ----------
    cur.execute("SELECT COUNT(*) FROM player")
    pc = cur.fetchone()[0]
    cur.execute("SELECT COUNT(*) FROM match_record")
    mc = cur.fetchone()[0]
    cur.execute("SELECT COUNT(*) FROM match_detail")
    dc = cur.fetchone()[0]

    print(f"\n✅ 数据生成完成！耗时 {elapsed:.1f}s")
    print(f"   └── 玩家: {pc} | 英雄: {len(HEROES)} | 对战: {mc} | 详情: {dc} | 商品: {len(SHOP_ITEMS)}")
    print(f"   └── 测试账号: player1 ~ player{num_players}")
    print(f"   └── 统一密码: {TEST_PASSWORD}")

    cur.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Arena Clash 测试数据生成器")
    parser.add_argument("--host", default="localhost", help="PostgreSQL 主机")
    parser.add_argument("--port", default=5432, type=int, help="PostgreSQL 端口")
    parser.add_argument("--dbname", default="arena_clash", help="数据库名")
    parser.add_argument("--user", default="arena_admin", help="用户名")
    parser.add_argument("--password", default="arena_2026_secure_pass", help="密码")
    parser.add_argument("--players", default=500, type=int, help="玩家数量")
    parser.add_argument("--matches", default=2000, type=int, help="对战数量")

    args = parser.parse_args()

    print("=" * 60)
    print("  Arena Clash 测试数据生成器")
    print("=" * 60)

    conn = psycopg2.connect(
        host=args.host,
        port=args.port,
        dbname=args.dbname,
        user=args.user,
        password=args.password,
    )

    try:
        generate(conn, args.players, args.matches)
    finally:
        conn.close()
