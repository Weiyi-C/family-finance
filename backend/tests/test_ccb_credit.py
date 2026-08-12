"""建行信用卡 CSV 解析器测试"""

import pytest
from app.parsers.ccb_credit import parse_ccb_credit_csv


class TestParseCCBCreditCSV:
    """建行信用卡 CSV 解析测试"""

    def test_parse_basic(self):
        """测试基本解析功能"""
        content = """中国建设银行

中国建设银行信用卡交易明细

客户姓名 :郑维一



交易日, 入账日, 信用卡卡号, 类型, 入账币种, 入账金额, 交易描述
20260731, 20260731, '6227083007400872, 消费, 人民币, 3.25, 支付宝-特约商户

20260731, 20260731, '6227083007400872, 消费, 人民币, 4.25, 支付宝-特约商户

20260730, 20260730, '6227083007400872, 消费, 人民币, 13.86, 20260729高速通行费四川成德南金堂
"""
        items, meta = parse_ccb_credit_csv(content)

        assert len(items) == 3
        assert meta["platform"] == "建设银行"
        assert meta["card_number"] == "0872"
        assert meta["has_payment_method"] is True

    def test_parse_amount(self):
        """测试金额解析（转为分）"""
        content = """中国建设银行

中国建设银行信用卡交易明细

客户姓名 :郑维一



交易日, 入账日, 信用卡卡号, 类型, 入账币种, 入账金额, 交易描述
20260731, 20260731, '6227083007400872, 消费, 人民币, 3.25, 支付宝-特约商户
"""
        items, _ = parse_ccb_credit_csv(content)

        assert len(items) == 1
        assert items[0]["amount"] == 325  # 3.25元 = 325分

    def test_parse_transaction_time(self):
        """测试交易时间格式"""
        content = """中国建设银行

中国建设银行信用卡交易明细

客户姓名 :郑维一



交易日, 入账日, 信用卡卡号, 类型, 入账币种, 入账金额, 交易描述
20260731, 20260731, '6227083007400872, 消费, 人民币, 3.25, 支付宝-特约商户
"""
        items, _ = parse_ccb_credit_csv(content)

        assert items[0]["transaction_time"] == "2026-07-31"

    def test_parse_payment_method(self):
        """测试支付方式提取"""
        content = """中国建设银行

中国建设银行信用卡交易明细

客户姓名 :郑维一



交易日, 入账日, 信用卡卡号, 类型, 入账币种, 入账金额, 交易描述
20260731, 20260731, '6227083007400872, 消费, 人民币, 3.25, 支付宝-特约商户
"""
        items, meta = parse_ccb_credit_csv(content)

        assert items[0]["payment_method"] == "建设银行信用卡(0872)"
        assert "建设银行信用卡(0872)" in meta["detected_methods"]

    def test_parse_transfer_type(self):
        """测试转账类型识别"""
        content = """中国建设银行

中国建设银行信用卡交易明细

客户姓名 :郑维一



交易日, 入账日, 信用卡卡号, 类型, 入账币种, 入账金额, 交易描述
20260731, 20260731, '6227083007400872, 还款, 人民币, 500.00, 还款
"""
        items, _ = parse_ccb_credit_csv(content)

        assert items[0]["type"] == "transfer"

    def test_parse_empty_content(self):
        """测试空内容"""
        content = """中国建设银行

中国建设银行信用卡交易明细

客户姓名 :郑维一



交易日, 入账日, 信用卡卡号, 类型, 入账币种, 入账金额, 交易描述
"""
        items, _ = parse_ccb_credit_csv(content)

        assert len(items) == 0

    def test_parse_platform_detection(self):
        """测试平台识别"""
        content = """中国建设银行

中国建设银行信用卡交易明细

客户姓名 :郑维一



交易日, 入账日, 信用卡卡号, 类型, 入账币种, 入账金额, 交易描述
20260731, 20260731, '6227083007400872, 消费, 人民币, 3.25, 支付宝-特约商户
20260730, 20260730, '6227083007400872, 消费, 人民币, 13.86, 20260729高速通行费四川成德南金堂
"""
        items, _ = parse_ccb_credit_csv(content)

        # 第一条应该识别为支付宝
        assert items[0]["platform"] == "支付宝"
        # 第二条应该识别为线下
        assert items[1]["platform"] == "线下"

    def test_parse_order_no_generation(self):
        """测试交易号生成（唯一性）"""
        content = """中国建设银行

中国建设银行信用卡交易明细

客户姓名 :郑维一



交易日, 入账日, 信用卡卡号, 类型, 入账币种, 入账金额, 交易描述
20260731, 20260731, '6227083007400872, 消费, 人民币, 3.25, 支付宝-特约商户
20260731, 20260731, '6227083007400872, 消费, 人民币, 4.25, 支付宝-特约商户
"""
        items, _ = parse_ccb_credit_csv(content)

        # 两笔交易的 order_no 应该不同
        assert items[0]["order_no"] != items[1]["order_no"]
        # order_no 应该以 CCB_ 开头
        assert items[0]["order_no"].startswith("CCB_")

    def test_parse_invalid_header(self):
        """测试无效表头"""
        content = """这是无效的文件内容
没有正确的表头
"""
        with pytest.raises(ValueError, match="无法识别建设银行信用卡账单格式"):
            parse_ccb_credit_csv(content)
