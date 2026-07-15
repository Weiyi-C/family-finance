-- ============================================================
-- Family Finance - Seed Data
-- ============================================================

-- ===================== 分类体系 =====================

-- 一级分类（支出）
INSERT INTO categories (id, family_id, parent_id, level, name, icon, color, type, sort_order) VALUES
(1,  NULL, NULL, 1, '餐饮',     '🍽️', '#FF6B6B', 'expense', 1),
(2,  NULL, NULL, 1, '交通出行', '🚗', '#4ECDC4', 'expense', 2),
(3,  NULL, NULL, 1, '服饰美妆', '👗', '#FF69B4', 'expense', 3),
(4,  NULL, NULL, 1, '住房',     '🏠', '#45B7D1', 'expense', 4),
(5,  NULL, NULL, 1, '休闲娱乐', '🎮', '#96CEB4', 'expense', 5),
(6,  NULL, NULL, 1, '医疗健康', '💊', '#FF8A80', 'expense', 6),
(7,  NULL, NULL, 1, '教育学习', '📚', '#7C4DFF', 'expense', 7),
(8,  NULL, NULL, 1, '人情往来', '🤝', '#EC407A', 'expense', 8),
(9,  NULL, NULL, 1, '母婴亲子', '👶', '#AB47BC', 'expense', 9),
(10, NULL, NULL, 1, '宠物',     '🐾', '#8D6E63', 'expense', 10),
(11, NULL, NULL, 1, '数码科技', '📱', '#29B6F6', 'expense', 11),
(12, NULL, NULL, 1, '金融理财', '💰', '#FFD700', 'expense', 12),
(13, NULL, NULL, 1, '差旅',     '🧳', '#26A69A', 'expense', 13),
(14, NULL, NULL, 1, '工作办公', '💼', '#78909C', 'expense', 14),
(15, NULL, NULL, 1, '其他',     '❓', '#BDBDBD', 'expense', 99);

-- 餐饮 二级
INSERT INTO categories (family_id, parent_id, level, name, icon, type, sort_order) VALUES
(NULL, 1, 2, '早饭',     '☀️', 'expense', 1),
(NULL, 1, 2, '午饭',     '🌞', 'expense', 2),
(NULL, 1, 2, '晚饭',     '🌙', 'expense', 3),
(NULL, 1, 2, '下午茶',   '🫖', 'expense', 4),
(NULL, 1, 2, '夜宵',     '🌃', 'expense', 5),
(NULL, 1, 2, '饮品',     '🥤', 'expense', 6),
(NULL, 1, 2, '甜点零食', '🍰', 'expense', 7),
(NULL, 1, 2, '水果',     '🍎', 'expense', 8),
(NULL, 1, 2, '食材采购', '🛒', 'expense', 9);

-- 餐饮-早饭 三级
INSERT INTO categories (family_id, parent_id, level, name, icon, type, sort_order) VALUES
(NULL, (SELECT id FROM categories WHERE name='早饭' AND level=2), 3, '食堂',   '🏫', 'expense', 1),
(NULL, (SELECT id FROM categories WHERE name='早饭' AND level=2), 3, '外卖',   '🛵', 'expense', 2),
(NULL, (SELECT id FROM categories WHERE name='早饭' AND level=2), 3, '自己做', '🍳', 'expense', 3),
(NULL, (SELECT id FROM categories WHERE name='早饭' AND level=2), 3, '便利店', '🏪', 'expense', 4),
(NULL, (SELECT id FROM categories WHERE name='早饭' AND level=2), 3, '路边摊', '🛖', 'expense', 5);

-- 餐饮-午饭 三级
INSERT INTO categories (family_id, parent_id, level, name, icon, type, sort_order) VALUES
(NULL, (SELECT id FROM categories WHERE name='午饭' AND level=2), 3, '食堂',   '🏫', 'expense', 1),
(NULL, (SELECT id FROM categories WHERE name='午饭' AND level=2), 3, '外卖',   '🛵', 'expense', 2),
(NULL, (SELECT id FROM categories WHERE name='午饭' AND level=2), 3, '自己做', '🍳', 'expense', 3),
(NULL, (SELECT id FROM categories WHERE name='午饭' AND level=2), 3, '堂食',   '🍽️', 'expense', 4),
(NULL, (SELECT id FROM categories WHERE name='午饭' AND level=2), 3, '便利店', '🏪', 'expense', 5),
(NULL, (SELECT id FROM categories WHERE name='午饭' AND level=2), 3, '快餐',   '🍔', 'expense', 6);

-- 餐饮-晚饭 三级
INSERT INTO categories (family_id, parent_id, level, name, icon, type, sort_order) VALUES
(NULL, (SELECT id FROM categories WHERE name='晚饭' AND level=2), 3, '食堂',   '🏫', 'expense', 1),
(NULL, (SELECT id FROM categories WHERE name='晚饭' AND level=2), 3, '外卖',   '🛵', 'expense', 2),
(NULL, (SELECT id FROM categories WHERE name='晚饭' AND level=2), 3, '自己做', '🍳', 'expense', 3),
(NULL, (SELECT id FROM categories WHERE name='晚饭' AND level=2), 3, '堂食',   '🍽️', 'expense', 4),
(NULL, (SELECT id FROM categories WHERE name='晚饭' AND level=2), 3, '快餐',   '🍔', 'expense', 5);

-- 餐饮-夜宵 三级
INSERT INTO categories (family_id, parent_id, level, name, icon, type, sort_order) VALUES
(NULL, (SELECT id FROM categories WHERE name='夜宵' AND level=2), 3, '烧烤',   '🍖', 'expense', 1),
(NULL, (SELECT id FROM categories WHERE name='夜宵' AND level=2), 3, '外卖',   '🛵', 'expense', 2),
(NULL, (SELECT id FROM categories WHERE name='夜宵' AND level=2), 3, '泡面',   '🍜', 'expense', 3),
(NULL, (SELECT id FROM categories WHERE name='夜宵' AND level=2), 3, '便利店', '🏪', 'expense', 4);

-- 餐饮-下午茶 三级
INSERT INTO categories (family_id, parent_id, level, name, icon, type, sort_order) VALUES
(NULL, (SELECT id FROM categories WHERE name='下午茶' AND level=2), 3, '奶茶', '🧋', 'expense', 1),
(NULL, (SELECT id FROM categories WHERE name='下午茶' AND level=2), 3, '咖啡', '☕', 'expense', 2),
(NULL, (SELECT id FROM categories WHERE name='下午茶' AND level=2), 3, '甜点', '🧁', 'expense', 3),
(NULL, (SELECT id FROM categories WHERE name='下午茶' AND level=2), 3, '果汁', '🧃', 'expense', 4),
(NULL, (SELECT id FROM categories WHERE name='下午茶' AND level=2), 3, '茶饮', '🍵', 'expense', 5);

-- 餐饮-饮品 三级
INSERT INTO categories (family_id, parent_id, level, name, icon, type, sort_order) VALUES
(NULL, (SELECT id FROM categories WHERE name='饮品' AND level=2), 3, '奶茶',     '🧋', 'expense', 1),
(NULL, (SELECT id FROM categories WHERE name='饮品' AND level=2), 3, '咖啡',     '☕', 'expense', 2),
(NULL, (SELECT id FROM categories WHERE name='饮品' AND level=2), 3, '果汁',     '🧃', 'expense', 3),
(NULL, (SELECT id FROM categories WHERE name='饮品' AND level=2), 3, '矿泉水',   '💧', 'expense', 4),
(NULL, (SELECT id FROM categories WHERE name='饮品' AND level=2), 3, '碳酸饮料', '🥤', 'expense', 5),
(NULL, (SELECT id FROM categories WHERE name='饮品' AND level=2), 3, '茶',       '🍵', 'expense', 6);

-- 餐饮-甜点零食 三级
INSERT INTO categories (family_id, parent_id, level, name, icon, type, sort_order) VALUES
(NULL, (SELECT id FROM categories WHERE name='甜点零食' AND level=2), 3, '蛋糕',   '🎂', 'expense', 1),
(NULL, (SELECT id FROM categories WHERE name='甜点零食' AND level=2), 3, '面包',   '🍞', 'expense', 2),
(NULL, (SELECT id FROM categories WHERE name='甜点零食' AND level=2), 3, '饼干',   '🍪', 'expense', 3),
(NULL, (SELECT id FROM categories WHERE name='甜点零食' AND level=2), 3, '糖果',   '🍬', 'expense', 4),
(NULL, (SELECT id FROM categories WHERE name='甜点零食' AND level=2), 3, '坚果',   '🥜', 'expense', 5),
(NULL, (SELECT id FROM categories WHERE name='甜点零食' AND level=2), 3, '薯片',   '🥔', 'expense', 6),
(NULL, (SELECT id FROM categories WHERE name='甜点零食' AND level=2), 3, '巧克力', '🍫', 'expense', 7);

-- 餐饮-水果 三级
INSERT INTO categories (family_id, parent_id, level, name, icon, type, sort_order) VALUES
(NULL, (SELECT id FROM categories WHERE name='水果' AND level=2), 3, '苹果',     '🍎', 'expense', 1),
(NULL, (SELECT id FROM categories WHERE name='水果' AND level=2), 3, '香蕉',     '🍌', 'expense', 2),
(NULL, (SELECT id FROM categories WHERE name='水果' AND level=2), 3, '葡萄',     '🍇', 'expense', 3),
(NULL, (SELECT id FROM categories WHERE name='水果' AND level=2), 3, '西瓜',     '🍉', 'expense', 4),
(NULL, (SELECT id FROM categories WHERE name='水果' AND level=2), 3, '车厘子',   '🍒', 'expense', 5),
(NULL, (SELECT id FROM categories WHERE name='水果' AND level=2), 3, '其他水果', '🥝', 'expense', 6);

-- 餐饮-食材采购 三级
INSERT INTO categories (family_id, parent_id, level, name, icon, type, sort_order) VALUES
(NULL, (SELECT id FROM categories WHERE name='食材采购' AND level=2), 3, '蔬菜',   '🥬', 'expense', 1),
(NULL, (SELECT id FROM categories WHERE name='食材采购' AND level=2), 3, '肉类',   '🥩', 'expense', 2),
(NULL, (SELECT id FROM categories WHERE name='食材采购' AND level=2), 3, '海鲜',   '🦐', 'expense', 3),
(NULL, (SELECT id FROM categories WHERE name='食材采购' AND level=2), 3, '蛋奶',   '🥚', 'expense', 4),
(NULL, (SELECT id FROM categories WHERE name='食材采购' AND level=2), 3, '粮油',   '🌾', 'expense', 5),
(NULL, (SELECT id FROM categories WHERE name='食材采购' AND level=2), 3, '调味品', '🧂', 'expense', 6),
(NULL, (SELECT id FROM categories WHERE name='食材采购' AND level=2), 3, '半成品', '🥟', 'expense', 7);

-- 交通出行 二级
INSERT INTO categories (family_id, parent_id, level, name, icon, type, sort_order) VALUES
(NULL, 2, 2, '打车',         '🚕', 'expense', 1),
(NULL, 2, 2, '公共交通',     '🚇', 'expense', 2),
(NULL, 2, 2, '火车高铁',     '🚄', 'expense', 3),
(NULL, 2, 2, '飞机',         '✈️', 'expense', 4),
(NULL, 2, 2, '长途汽车',     '🚌', 'expense', 5),
(NULL, 2, 2, '自驾加油',     '⛽', 'expense', 6),
(NULL, 2, 2, '停车费',       '🅿️', 'expense', 7),
(NULL, 2, 2, '共享单车',     '🛵', 'expense', 8),
(NULL, 2, 2, '车辆保养维修', '🔧', 'expense', 9),
(NULL, 2, 2, '车险',         '🛡️', 'expense', 10),
(NULL, 2, 2, '洗车美容',     '🚿', 'expense', 11),
(NULL, 2, 2, '过路费',       '🛣️', 'expense', 12),
(NULL, 2, 2, '车辆行政',     '📋', 'expense', 13),
(NULL, 2, 2, '出行服务',     '🛤️', 'expense', 14);

-- 交通-打车 三级
INSERT INTO categories (family_id, parent_id, level, name, icon, type, sort_order) VALUES
(NULL, (SELECT id FROM categories WHERE name='打车' AND level=2), 3, '滴滴',     '🚗', 'expense', 1),
(NULL, (SELECT id FROM categories WHERE name='打车' AND level=2), 3, '高德打车', '🗺️', 'expense', 2),
(NULL, (SELECT id FROM categories WHERE name='打车' AND level=2), 3, '曹操出行', '🟢', 'expense', 3),
(NULL, (SELECT id FROM categories WHERE name='打车' AND level=2), 3, 'T3出行',   '🔵', 'expense', 4),
(NULL, (SELECT id FROM categories WHERE name='打车' AND level=2), 3, '出租车',   '🚕', 'expense', 5);

-- 交通-公共交通 三级
INSERT INTO categories (family_id, parent_id, level, name, icon, type, sort_order) VALUES
(NULL, (SELECT id FROM categories WHERE name='公共交通' AND level=2), 3, '地铁',       '🚇', 'expense', 1),
(NULL, (SELECT id FROM categories WHERE name='公共交通' AND level=2), 3, '公交',       '🚌', 'expense', 2),
(NULL, (SELECT id FROM categories WHERE name='公共交通' AND level=2), 3, '轮渡',       '⛴️', 'expense', 3),
(NULL, (SELECT id FROM categories WHERE name='公共交通' AND level=2), 3, '城际铁路',   '🚆', 'expense', 4);

-- 交通-火车高铁 三级
INSERT INTO categories (family_id, parent_id, level, name, icon, type, sort_order) VALUES
(NULL, (SELECT id FROM categories WHERE name='火车高铁' AND level=2), 3, '高铁',       '🚄', 'expense', 1),
(NULL, (SELECT id FROM categories WHERE name='火车高铁' AND level=2), 3, '动车',       '🚅', 'expense', 2),
(NULL, (SELECT id FROM categories WHERE name='火车高铁' AND level=2), 3, '普通火车',   '🚂', 'expense', 3),
(NULL, (SELECT id FROM categories WHERE name='火车高铁' AND level=2), 3, '城际',       '🚆', 'expense', 4);

-- 服饰美妆 二级
INSERT INTO categories (family_id, parent_id, level, name, icon, type, sort_order) VALUES
(NULL, 3, 2, '男装',     '👔', 'expense', 1),
(NULL, 3, 2, '女装',     '👗', 'expense', 2),
(NULL, 3, 2, '鞋子',     '👟', 'expense', 3),
(NULL, 3, 2, '包包',     '👜', 'expense', 4),
(NULL, 3, 2, '饰品',     '💍', 'expense', 5),
(NULL, 3, 2, '美妆护肤', '💄', 'expense', 6),
(NULL, 3, 2, '美容美发', '💇', 'expense', 7),
(NULL, 3, 2, '日用品',   '🧴', 'expense', 8);

-- 住房 二级
INSERT INTO categories (family_id, parent_id, level, name, icon, type, sort_order) VALUES
(NULL, 4, 2, '房租/房贷', '🏷️', 'expense', 1),
(NULL, 4, 2, '水电燃气',   '💡', 'expense', 2),
(NULL, 4, 2, '通讯网络',   '📶', 'expense', 3),
(NULL, 4, 2, '物业费',     '🏠', 'expense', 4),
(NULL, 4, 2, '维修维护',   '🔧', 'expense', 5),
(NULL, 4, 2, '家居用品',   '🛋️', 'expense', 6),
(NULL, 4, 2, '家政服务',   '🧹', 'expense', 7),
(NULL, 4, 2, '装修',       '🏗️', 'expense', 8);

-- 休闲娱乐 二级
INSERT INTO categories (family_id, parent_id, level, name, icon, type, sort_order) VALUES
(NULL, 5, 2, '影视',     '🎬', 'expense', 1),
(NULL, 5, 2, '音乐',     '🎵', 'expense', 2),
(NULL, 5, 2, '阅读',     '📚', 'expense', 3),
(NULL, 5, 2, '游戏',     '🎮', 'expense', 4),
(NULL, 5, 2, '运动健身', '🏃', 'expense', 5),
(NULL, 5, 2, '休闲活动', '🎳', 'expense', 6),
(NULL, 5, 2, '旅游景点', '🎪', 'expense', 7),
(NULL, 5, 2, '摄影',     '📷', 'expense', 8),
(NULL, 5, 2, '兴趣爱好', '🎨', 'expense', 9);

-- 医疗健康 二级
INSERT INTO categories (family_id, parent_id, level, name, icon, type, sort_order) VALUES
(NULL, 6, 2, '就医',     '🏥', 'expense', 1),
(NULL, 6, 2, '药品',     '💊', 'expense', 2),
(NULL, 6, 2, '口腔',     '🦷', 'expense', 3),
(NULL, 6, 2, '眼科',     '👁️', 'expense', 4),
(NULL, 6, 2, '疫苗体检', '💉', 'expense', 5),
(NULL, 6, 2, '保健调理', '🧘', 'expense', 6),
(NULL, 6, 2, '健身器材', '🏋️', 'expense', 7);

-- 教育学习 二级
INSERT INTO categories (family_id, parent_id, level, name, icon, type, sort_order) VALUES
(NULL, 7, 2, '学费',     '📖', 'expense', 1),
(NULL, 7, 2, '考试考证', '📝', 'expense', 2),
(NULL, 7, 2, '文具用品', '📓', 'expense', 3),
(NULL, 7, 2, '在线课程', '💻', 'expense', 4),
(NULL, 7, 2, '辅导培训', '🎓', 'expense', 5),
(NULL, 7, 2, '教材教辅', '📖', 'expense', 6);

-- 人情往来 二级
INSERT INTO categories (family_id, parent_id, level, name, icon, type, sort_order) VALUES
(NULL, 8, 2, '礼物', '🎁', 'expense', 1),
(NULL, 8, 2, '红包', '💰', 'expense', 2),
(NULL, 8, 2, '婚礼', '🎊', 'expense', 3),
(NULL, 8, 2, '生日', '🎂', 'expense', 4),
(NULL, 8, 2, '节日', '🏮', 'expense', 5),
(NULL, 8, 2, '请客', '🤝', 'expense', 6),
(NULL, 8, 2, '探望', '💐', 'expense', 7);

-- 母婴亲子 二级
INSERT INTO categories (family_id, parent_id, level, name, icon, type, sort_order) VALUES
(NULL, 9, 2, '奶粉辅食', '🍼', 'expense', 1),
(NULL, 9, 2, '玩具',     '🧸', 'expense', 2),
(NULL, 9, 2, '婴儿用品', '👶', 'expense', 3),
(NULL, 9, 2, '童装',     '👗', 'expense', 4),
(NULL, 9, 2, '早教',     '📚', 'expense', 5),
(NULL, 9, 2, '亲子活动', '🎠', 'expense', 6);

-- 宠物 二级
INSERT INTO categories (family_id, parent_id, level, name, icon, type, sort_order) VALUES
(NULL, 10, 2, '宠物食品', '🍖', 'expense', 1),
(NULL, 10, 2, '宠物医疗', '🏥', 'expense', 2),
(NULL, 10, 2, '宠物用品', '🧴', 'expense', 3),
(NULL, 10, 2, '宠物服务', '✂️', 'expense', 4),
(NULL, 10, 2, '宠物其他', '🐕', 'expense', 5);

-- 数码科技 二级
INSERT INTO categories (family_id, parent_id, level, name, icon, type, sort_order) VALUES
(NULL, 11, 2, '手机',     '📱', 'expense', 1),
(NULL, 11, 2, '电脑',     '💻', 'expense', 2),
(NULL, 11, 2, '数码配件', '🎧', 'expense', 3),
(NULL, 11, 2, '办公设备', '🖨️', 'expense', 4),
(NULL, 11, 2, '家电',     '📺', 'expense', 5),
(NULL, 11, 2, '游戏设备', '🎮', 'expense', 6);

-- 金融理财 二级
INSERT INTO categories (family_id, parent_id, level, name, icon, type, sort_order) VALUES
(NULL, 12, 2, '银行费用', '💳', 'expense', 1),
(NULL, 12, 2, '投资',     '📈', 'expense', 2),
(NULL, 12, 2, '贷款利息', '🏦', 'expense', 3),
(NULL, 12, 2, '汇率换汇', '💱', 'expense', 4),
(NULL, 12, 2, '保险',     '📊', 'expense', 5),
(NULL, 12, 2, '税费',     '💸', 'expense', 6);

-- 差旅 二级
INSERT INTO categories (family_id, parent_id, level, name, icon, type, sort_order) VALUES
(NULL, 13, 2, '住宿',     '🏨', 'expense', 1),
(NULL, 13, 2, '差旅餐饮', '🍽️', 'expense', 2),
(NULL, 13, 2, '差旅交通', '🚕', 'expense', 3),
(NULL, 13, 2, '差旅其他', '📋', 'expense', 4);

-- 工作办公 二级
INSERT INTO categories (family_id, parent_id, level, name, icon, type, sort_order) VALUES
(NULL, 14, 2, '办公用品', '🖊️', 'expense', 1),
(NULL, 14, 2, '工作出行', '🚕', 'expense', 2),
(NULL, 14, 2, '通讯办公', '📱', 'expense', 3),
(NULL, 14, 2, '职业发展', '🎓', 'expense', 4);

-- 其他 二级
INSERT INTO categories (family_id, parent_id, level, name, icon, type, sort_order) VALUES
(NULL, 15, 2, '未分类',   '❓', 'expense', 1),
(NULL, 15, 2, '转账',     '🔄', 'expense', 2),
(NULL, 15, 2, '手续费',   '💸', 'expense', 3),
(NULL, 15, 2, '彩票',     '🎰', 'expense', 4),
(NULL, 15, 2, '慈善捐赠', '🙏', 'expense', 5),
(NULL, 15, 2, '罚款',     '⚖️', 'expense', 6),
(NULL, 15, 2, '快递物流', '📦', 'expense', 7);

-- 一级分类（收入）
INSERT INTO categories (id, family_id, parent_id, level, name, icon, color, type, sort_order) VALUES
(100, NULL, NULL, 1, '工资薪酬', '💰', '#4CAF50', 'income', 1),
(101, NULL, NULL, 1, '副业收入', '💵', '#66BB6A', 'income', 2),
(102, NULL, NULL, 1, '红包收入', '🎁', '#FF7043', 'income', 3),
(103, NULL, NULL, 1, '转账收入', '💸', '#42A5F5', 'income', 4),
(104, NULL, NULL, 1, '投资收益', '📈', '#FFD700', 'income', 5),
(105, NULL, NULL, 1, '租金收入', '🏠', '#78909C', 'income', 6),
(106, NULL, NULL, 1, '退款收入', '💝', '#AB47BC', 'income', 7),
(107, NULL, NULL, 1, '奖金中奖', '🎊', '#FF6B6B', 'income', 8),
(108, NULL, NULL, 1, '其他收入', '🔄', '#BDBDBD', 'income', 99);

-- 收入二级
INSERT INTO categories (family_id, parent_id, level, name, icon, type, sort_order) VALUES
(NULL, 100, 2, '月薪',      '💵', 'income', 1),
(NULL, 100, 2, '年终奖',    '🎊', 'income', 2),
(NULL, 100, 2, '绩效奖金',  '🏆', 'income', 3),
(NULL, 100, 2, '加班费',    '⏰', 'income', 4),
(NULL, 100, 2, '补贴津贴',  '📋', 'income', 5),
(NULL, 101, 2, '兼职',      '💼', 'income', 1),
(NULL, 101, 2, 'freelance', '💻', 'income', 2),
(NULL, 101, 2, '稿费',      '📝', 'income', 3),
(NULL, 101, 2, '咨询费',    '🗣️', 'income', 4);

-- Reset sequence to avoid conflicts with explicit IDs
SELECT setval('categories_id_seq', GREATEST(
    (SELECT MAX(id) FROM categories),
    200
));

-- ===================== 支付渠道 =====================

INSERT INTO payment_channels (family_id, name, icon, sort_order) VALUES
(NULL, '支付宝',   '📱', 1),
(NULL, '微信支付', '💬', 2),
(NULL, '云闪付',   '💳', 3),
(NULL, '美团支付', '🛵', 4),
(NULL, 'Apple Pay','🍎', 5),
(NULL, '现金',     '💵', 6),
(NULL, '银行转账', '🏦', 7),
(NULL, 'POS刷卡',  '💳', 8),
(NULL, '其他',     '❓', 99);

-- ===================== 交易平台 =====================

INSERT INTO platforms (family_id, name, type, icon, sort_order) VALUES
(NULL, '淘宝',   'online',  '🛒', 1),
(NULL, '京东',   'online',  '🐕', 2),
(NULL, '拼多多', 'online',  '🍊', 3),
(NULL, '美团',   'online',  '🛵', 4),
(NULL, '饿了么', 'online',  '🔵', 5),
(NULL, '抖音',   'online',  '🎵', 6),
(NULL, '小红书', 'online',  '📕', 7),
(NULL, '得物',   'online',  '🏷️', 8),
(NULL, '唯品会', 'online',  '🛍️', 9),
(NULL, '闲鱼',   'online',  '🐟', 10),
(NULL, '亚马逊', 'online',  '📦', 11),
(NULL, '超市',   'offline', '🏪', 20),
(NULL, '餐厅',   'offline', '🍽️', 21),
(NULL, '便利店', 'offline', '🏪', 22),
(NULL, '菜市场', 'offline', '🥬', 23),
(NULL, '商场',   'offline', '🏬', 24),
(NULL, '加油站', 'offline', '⛽', 25),
(NULL, '医院',   'offline', '🏥', 26),
(NULL, '其他',   'offline', '❓', 99);

-- ===================== 银行 =====================

INSERT INTO banks (name, code, short_name, color, sort_order) VALUES
('招商银行', 'cmb',   '招行', '#CC0000', 1),
('工商银行', 'icbc',  '工行', '#C41230', 2),
('建设银行', 'ccb',   '建行', '#003DA5', 3),
('农业银行', 'abc',   '农行', '#009944', 4),
('中国银行', 'boc',   '中行', '#C41230', 5),
('交通银行', 'bocom', '交行', '#003DA5', 6),
('浦发银行', 'spdb',  '浦发', '#003DA5', 7),
('民生银行', 'cmbc',  '民生', '#003DA5', 8),
('兴业银行', 'cib',   '兴业', '#003DA5', 9),
('中信银行', 'citic', '中信', '#C41230', 10),
('光大银行', 'ceb',   '光大', '#6B2C91', 11),
('平安银行', 'pab',   '平安', '#FF6600', 12),
('邮储银行', 'psbc',  '邮储', '#006B3F', 13),
('广发银行', 'cgb',   '广发', '#C41230', 14),
('华夏银行', 'hxb',   '华夏', '#C41230', 15);

-- ===================== 账户类型模板 =====================

INSERT INTO account_type_templates
    (type_code, name, icon, group_name, is_credit, has_credit_limit, has_billing_day, has_due_day, sort_order)
VALUES
    ('cash',            '现金',          '💵', '资金',   FALSE, FALSE, FALSE, FALSE, 1),
    ('bank_savings',    '银行储蓄卡',    '🏦', '资金',   FALSE, FALSE, FALSE, FALSE, 2),
    ('alipay_balance',  '支付宝余额',    '📱', '资金',   FALSE, FALSE, FALSE, FALSE, 3),
    ('alipay_yuebao',   '余额宝',        '📱', '资金',   FALSE, FALSE, FALSE, FALSE, 4),
    ('wechat_balance',  '微信零钱',      '💬', '资金',   FALSE, FALSE, FALSE, FALSE, 5),
    ('wechat_lingqian', '零钱通',        '💬', '资金',   FALSE, FALSE, FALSE, FALSE, 6),
    ('meituan_pay',     '美团支付',      '🛵', '资金',   FALSE, FALSE, FALSE, FALSE, 7),
    ('bank_credit',     '银行信用卡',    '💳', '信用卡', TRUE,  TRUE,  TRUE,  TRUE,  1),
    ('alipay_huabei',   '花呗',          '🌸', '信用卡', TRUE,  TRUE,  TRUE,  TRUE,  2),
    ('alipay_jiebei',   '借呗',          '🔶', '信用卡', TRUE,  TRUE,  FALSE, FALSE, 3),
    ('jd_baitiao',      '京东白条',      '🏷️', '信用卡', TRUE,  TRUE,  TRUE,  TRUE,  4),
    ('bus_card',        '公交卡',        '🚌', '充值',   FALSE, FALSE, FALSE, FALSE, 1),
    ('meal_card',       '饭卡',          '🍱', '充值',   FALSE, FALSE, FALSE, FALSE, 2),
    ('membership_card', '会员卡',        '🎫', '充值',   FALSE, FALSE, FALSE, FALSE, 3),
    ('stock_account',   '股票账户',      '📈', '投资',   FALSE, FALSE, FALSE, FALSE, 1),
    ('fund_account',    '基金账户',      '📊', '投资',   FALSE, FALSE, FALSE, FALSE, 2);

-- ===================== 币种 =====================

INSERT INTO currencies (code, name, symbol, decimal_places) VALUES
('CNY', '人民币',           '¥',   2),
('USD', '美元',             '$',   2),
('EUR', '欧元',             '€',   2),
('JPY', '日元',             '¥',   0),
('KRW', '韩元',             '₩',   0),
('HKD', '港币',             'HK$', 2),
('TWD', '新台币',           'NT$', 2),
('GBP', '英镑',             '£',   2),
('THB', '泰铢',             '฿',   2),
('SGD', '新加坡元',         'S$',  2),
('AUD', '澳元',             'A$',  2),
('CAD', '加元',             'C$',  2),
('MYR', '马来西亚林吉特',   'RM',  2),
('VND', '越南盾',           '₫',   0),
('PHP', '菲律宾比索',       '₱',   2),
('IDR', '印尼盾',           'Rp',  0);
