-- ===================== 商户别名种子数据 =====================
-- family_id = NULL 表示系统级，所有家庭共享

INSERT INTO merchant_aliases (family_id, original_name, alias_name, platform_id, category_id) VALUES
-- 平台别名 → 规范名称
(NULL, '淘宝闪购', '淘宝', 1, NULL),
(NULL, '天猫', '淘宝', 1, NULL),
(NULL, '淘宝商城', '淘宝', 1, NULL),
(NULL, '京东到家', '京东', 2, NULL),
(NULL, '京东商城', '京东', 2, NULL),
(NULL, '美团外卖', '美团', 4, NULL),
(NULL, '大众点评', '美团', 4, NULL),
(NULL, '饿了么星选', '饿了么', 5, NULL),
(NULL, '抖音商城', '抖音', 6, NULL),

-- 平台 → 默认分类（当关键词规则未匹配时的兜底）
(NULL, '美团', '美团', 4, 1),
(NULL, '饿了么', '饿了么', 5, 1),
(NULL, '大众点评', '大众点评', 4, 1),
(NULL, '淘宝', '淘宝', 1, NULL),
(NULL, '天猫', '天猫', 1, NULL),
(NULL, '京东', '京东', 2, NULL),
(NULL, '拼多多', '拼多多', 3, NULL),
(NULL, '抖音', '抖音', 6, NULL),
(NULL, '闲鱼', '闲鱼', 10, NULL),
(NULL, '小红书', '小红书', 7, NULL),
(NULL, '唯品会', '唯品会', 9, NULL),
(NULL, '得物', '得物', 8, NULL),
(NULL, '携程', '携程', NULL, 13),
(NULL, '去哪儿', '去哪儿', NULL, 13),
(NULL, '飞猪', '飞猪', NULL, 13),
(NULL, '滴滴', '滴滴', NULL, NULL)
ON CONFLICT DO NOTHING;


-- ===================== 自动化规则种子数据 =====================
-- conditions.keywords: 匹配关键词列表
-- actions.category_name: 匹配后的分类名
-- actions.tags: 匹配后的标签
-- stage: classify（分类阶段）
-- priority: 数字越大优先级越高

-- 收入类规则（高优先级）
INSERT INTO automation_rules (family_id, name, conditions, actions, stage, priority) VALUES
(NULL, '工资薪酬', '{"keywords": ["工资", "薪资", "薪酬", "月薪", "绩效", "加班费", "补贴", "津贴"]}', '{"category_name": "工资薪酬", "tags": ["工资"]}', 'classify', 100),
(NULL, '奖金中奖', '{"keywords": ["奖金", "年终奖", "中奖", "绩效奖"]}', '{"category_name": "奖金中奖", "tags": ["奖金"]}', 'classify', 100),
(NULL, '利息收入', '{"keywords": ["利息", "利息收入", "活期利息", "定期利息"]}', '{"category_name": "其他收入", "tags": ["利息"]}', 'classify', 100),
(NULL, '公积金', '{"keywords": ["公积金", "住房公积金"]}', '{"category_name": "其他收入", "tags": ["公积金"]}', 'classify', 100),
(NULL, '租金收入', '{"keywords": ["租金", "房租收入", "租金收入"]}', '{"category_name": "租金收入", "tags": ["租金"]}', 'classify', 100),
(NULL, '退款收入', '{"keywords": ["退款", "退保", "退货", "退款收入"]}', '{"category_name": "退款收入", "tags": ["退款"]}', 'classify', 100),
(NULL, '投资收益', '{"keywords": ["理财收益", "基金收益", "股票收益", "投资收益", "分红"]}', '{"category_name": "投资收益", "tags": ["投资"]}', 'classify', 100),
(NULL, '转账收入', '{"keywords": ["他行汇入", "转入", "汇入"]}', '{"category_name": "转账收入", "tags": ["转账"]}', 'classify', 100),

-- 内部转账（高优先级，避免误分类为支出）
(NULL, '内部转账', '{"keywords": ["小荷包", "零钱通", "余额宝", "自动攒", "自动转入", "转出到", "转入到"]}', '{"category_name": "转账", "tags": []}', 'classify', 95),
(NULL, '红包', '{"keywords": ["红包", "微信红包", "支付宝红包"]}', '{"category_name": "红包", "tags": ["红包"]}', 'classify', 95),

-- 保险（高优先级）
(NULL, '保险', '{"keywords": ["保费", "保险", "社保", "车险", "人寿", "财产险"]}', '{"category_name": "保险", "tags": ["保险"]}', 'classify', 90),

-- 餐饮类
(NULL, '餐饮-外卖', '{"keywords": ["外卖", "美团外卖", "饿了么"]}', '{"category_name": "餐饮", "tags": ["外卖"]}', 'classify', 80),
(NULL, '餐饮-连锁', '{"keywords": ["麦当劳", "肯德基", "KFC", "星巴克", "瑞幸", "喜茶", "奈雪", "蜜雪冰城", "必胜客", "汉堡王", "海底捞", "西贝", "呷哺呷哺", "真功夫", "永和大王", "吉野家"]}', '{"category_name": "餐饮", "tags": ["餐饮"]}', 'classify', 80),
(NULL, '餐饮-通用', '{"keywords": ["餐厅", "饭店", "食堂", "小吃", "烧烤", "火锅", "面馆", "咖啡", "奶茶", "蛋糕", "面包", "米粉", "麻辣烫", "饺子", "包子", "快餐", "便当", "寿司", "披萨"]}', '{"category_name": "餐饮", "tags": ["餐饮"]}', 'classify', 75),

-- 食材采购
(NULL, '食材采购', '{"keywords": ["超市", "便利店", "菜市场", "盒马", "永辉", "大润发", "沃尔玛", "家乐福", "山姆", "七鲜", "物美", "华润万家", "联华"]}', '{"category_name": "食材采购", "tags": ["超市"]}', 'classify', 75),

-- 交通出行
(NULL, '打车', '{"keywords": ["滴滴", "打车", "出租车", "曹操出行", "T3出行", "高德打车", "花小猪", "首汽约车"]}', '{"category_name": "打车", "tags": ["打车"]}', 'classify', 70),
(NULL, '停车费', '{"keywords": ["停车", "停车费", "停车缴费", "停车场", "停车服务"]}', '{"category_name": "停车费", "tags": ["停车"]}', 'classify', 70),
(NULL, '自驾加油', '{"keywords": ["加油", "充电桩", "中石油", "中石化", "壳牌", "加油站"]}', '{"category_name": "自驾加油", "tags": ["加油"]}', 'classify', 70),
(NULL, '过路费', '{"keywords": ["ETC", "过路费", "高速费", "通行费"]}', '{"category_name": "过路费", "tags": ["高速"]}', 'classify', 70),
(NULL, '公共交通', '{"keywords": ["地铁", "公交", "一卡通", "交通卡", "公共交通", "轨道交通"]}', '{"category_name": "公共交通", "tags": ["交通"]}', 'classify', 70),

-- 差旅
(NULL, '火车高铁', '{"keywords": ["火车", "高铁", "12306", "动车", "城际"]}', '{"category_name": "火车高铁", "tags": ["出差"]}', 'classify', 65),
(NULL, '飞机', '{"keywords": ["机票", "飞机", "携程", "去哪儿", "飞猪", "同程", "航班", "航空"]}', '{"category_name": "飞机", "tags": ["出差"]}', 'classify', 65),
(NULL, '住宿', '{"keywords": ["酒店", "民宿", "Airbnb", "宾馆", "旅馆", "住宿"]}', '{"category_name": "住宿", "tags": ["出差"]}', 'classify', 65),

-- 购物
(NULL, '网购', '{"keywords": ["淘宝", "天猫", "京东", "拼多多", "抖音商城", "唯品会", "得物", "闲鱼", "小红书", "苏宁", "国美", "当当"]}', '{"category_name": "日用品", "tags": ["网购"]}', 'classify', 60),

-- 娱乐
(NULL, '影视', '{"keywords": ["电影", "影院", "猫眼", "淘票票", "万达影城", "横店影城"]}', '{"category_name": "影视", "tags": ["娱乐"]}', 'classify', 55),
(NULL, '订阅服务', '{"keywords": ["爱奇艺", "优酷", "腾讯视频", "B站", "bilibili", "Netflix", "Spotify", "Apple Music", "芒果TV", "搜狐视频", "乐视"]}', '{"category_name": "影视", "tags": ["订阅"]}', 'classify', 55),
(NULL, '游戏', '{"keywords": ["游戏", "Steam", "腾讯游戏", "网易游戏", "手游", "网游", "PlayStation", "Xbox", "Nintendo"]}', '{"category_name": "游戏", "tags": ["游戏"]}', 'classify', 55),
(NULL, '休闲活动', '{"keywords": ["KTV", "酒吧", "网吧", "剧本杀", "密室", "桌游", "棋牌"]}', '{"category_name": "休闲活动", "tags": ["娱乐"]}', 'classify', 55),

-- 住房
(NULL, '房租房贷', '{"keywords": ["房租", "房贷", "按揭", "租金", "月供"]}', '{"category_name": "房租/房贷", "tags": ["居住"]}', 'classify', 50),
(NULL, '水电燃气', '{"keywords": ["电费", "水费", "燃气", "暖气", "水电费", "燃气费"]}', '{"category_name": "水电燃气", "tags": ["居住"]}', 'classify', 50),
(NULL, '物业费', '{"keywords": ["物业", "物业费", "物业管理费"]}', '{"category_name": "物业费", "tags": ["居住"]}', 'classify', 50),
(NULL, '装修', '{"keywords": ["装修", "家具", "宜家", "家居", "家电", "建材"]}', '{"category_name": "装修", "tags": ["家居"]}', 'classify', 50),

-- 通讯
(NULL, '通讯网络', '{"keywords": ["话费", "流量", "中国移动", "中国联通", "中国电信", "充值", "手机充值", "流量包"]}', '{"category_name": "通讯网络", "tags": ["通讯"]}', 'classify', 45),

-- 医疗
(NULL, '就医', '{"keywords": ["医院", "诊所", "就医", "挂号", "门诊", "住院", "手术"]}', '{"category_name": "就医", "tags": ["医疗"]}', 'classify', 40),
(NULL, '药品', '{"keywords": ["药店", "药房", "大参林", "老百姓大药房", "海王星辰", "同仁堂"]}', '{"category_name": "药品", "tags": ["医疗"]}', 'classify', 40),
(NULL, '疫苗体检', '{"keywords": ["体检", "疫苗", "体检中心", "防疫"]}', '{"category_name": "疫苗体检", "tags": ["医疗"]}', 'classify', 40),
(NULL, '口腔', '{"keywords": ["口腔", "牙科", "牙医", "口腔医院"]}', '{"category_name": "口腔", "tags": ["医疗"]}', 'classify', 40),

-- 教育
(NULL, '辅导培训', '{"keywords": ["学费", "培训", "课程", "网课", "辅导", "补习", "补习班"]}', '{"category_name": "辅导培训", "tags": ["教育"]}', 'classify', 35),
(NULL, '教材教辅', '{"keywords": ["书店", "图书", "当当", "教材", "教辅", "文具", "文具店"]}', '{"category_name": "教材教辅", "tags": ["教育"]}', 'classify', 35),

-- 服饰美妆
(NULL, '美容美发', '{"keywords": ["理发", "美甲", "美发", "发型", "造型"]}', '{"category_name": "美容美发", "tags": ["美容"]}', 'classify', 30),
(NULL, '美妆护肤', '{"keywords": ["化妆品", "护肤", "美妆", "口红", "面膜", "护肤品"]}', '{"category_name": "美妆护肤", "tags": ["美容"]}', 'classify', 30),
(NULL, '服饰品牌', '{"keywords": ["ZARA", "H&M", "优衣库", "耐克", "阿迪", "Nike", "Adidas", "李宁", "安踏", "特步"]}', '{"category_name": "服饰美妆", "tags": ["购物"]}', 'classify', 30),

-- 其他
(NULL, '母婴亲子', '{"keywords": ["奶粉", "纸尿裤", "婴儿", "母婴", "儿童", "玩具", "童装"]}', '{"category_name": "母婴亲子", "tags": ["母婴"]}', 'classify', 25),
(NULL, '宠物', '{"keywords": ["宠物", "猫粮", "狗粮", "宠物医院", "宠物店"]}', '{"category_name": "宠物", "tags": ["宠物"]}', 'classify', 25),
(NULL, '银行费用', '{"keywords": ["手续费", "银行费用", "年费", "账户管理费"]}', '{"category_name": "银行费用", "tags": ["手续费"]}', 'classify', 20),
(NULL, '汇率换汇', '{"keywords": ["购汇", "换汇", "外汇", "汇率"]}', '{"category_name": "汇率换汇", "tags": ["换汇"]}', 'classify', 20),
(NULL, '还款', '{"keywords": ["贷款", "还款", "还贷", "还信用卡"]}', '{"category_name": "转账", "tags": ["还款"]}', 'classify', 20),
(NULL, '办公用品', '{"keywords": ["办公用品", "文具", "打印", "复印", "快递", "顺丰", "圆通", "中通", "韵达"]}', '{"category_name": "办公用品", "tags": ["办公"]}', 'classify', 15),
(NULL, '数码科技', '{"keywords": ["手机", "电脑", "笔记本", "平板", "耳机", "充电器", "数据线"]}', '{"category_name": "数码科技", "tags": ["数码"]}', 'classify', 15),
(NULL, '慈善捐赠', '{"keywords": ["捐款", "慈善", "公益", "捐赠"]}', '{"category_name": "慈善捐赠", "tags": ["公益"]}', 'classify', 10),
(NULL, '罚款', '{"keywords": ["罚款", "罚单", "违章"]}', '{"category_name": "罚款", "tags": ["罚款"]}', 'classify', 10)
ON CONFLICT DO NOTHING;
