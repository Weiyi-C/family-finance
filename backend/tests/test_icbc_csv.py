"""工行 CSV 解析器测试（含信用卡14列格式）"""

import pytest
from app.parsers.icbc_csv import parse_icbc_csv, _parse_icbc_fields, _parse_icbc_credit_fields


class TestParseICBCCSV:
    """工行 CSV 解析测试"""

    def test_parse_basic_15col(self):
        """测试15列储蓄卡格式"""
        content = """明细查询文件下载
卡号:1234****5678

交易日期, 摘要, 交易详情, 交易场所, 交易国家或地区简称, 钞/汇, 交易金额(收入), 交易金额(支出), 交易币种, 记账金额(收入), 记账金额(支出), 记账币种, 余额, 对方户名, 对方账户
2026-07-30, 消费, , 支付宝-特约商户, CHN, 钞, -, -, -, , 3.25, 人民币, 1000.00, 支付宝支付科技有限公司, 2088****1911
2026-07-29, 工资, , , CHN, 钞, -, -, -, 3629.54, , 人民币, 1003.25, 成都地铁运营有限公司, 4402****7387
"""
        items, meta = parse_icbc_csv(content)

        assert len(items) == 2
        assert meta["platform"] == "工商银行"
        assert meta["card_number"] == "5678"

    def test_parse_basic_14col(self):
        """测试14列信用卡格式"""
        content = """明细查询文件下载
卡号:1234****5678

交易日期, 记账日期, 摘要, 交易场所, 交易国家或地区简称, 交易金额(收入), 交易金额(支出), 交易币种, 记账金额(收入), 记账金额(支出), 记账币种, 余额, 对方户名, 对方账户
2026-07-26, 2026-07-26, 消费, 财付通-沃尔玛到家, CHN, , 229.71, 人民币, , 229.71, 人民币, -389.99, , 
2026-07-15, 2026-07-15, 消费, 支付宝-北京小米移动软件有限公司, CHN, , 9.87, 人民币, , 9.87, 人民币, -160.28, , 
"""
        items, meta = parse_icbc_csv(content)

        assert len(items) == 2
        assert meta["platform"] == "工商银行"
        # 信用卡格式应该识别出 payment_method 包含"信用卡"
        assert "信用卡" in items[0]["payment_method"] or "信用卡" in meta["detected_methods"][0]

    def test_parse_amount_15col(self):
        """测试15列格式金额解析"""
        content = """明细查询文件下载
卡号:1234****5678

交易日期, 摘要, 交易详情, 交易场所, 交易国家或地区简称, 钞/汇, 交易金额(收入), 交易金额(支出), 交易币种, 记账金额(收入), 记账金额(支出), 记账币种, 余额, 对方户名, 对方账户
2026-07-30, 消费, , 支付宝-特约商户, CHN, 钞, -, -, -, , 3.25, 人民币, 1000.00, 支付宝支付科技有限公司, 2088****1911
"""
        items, _ = parse_icbc_csv(content)

        assert items[0]["amount"] == 325  # 3.25元 = 325分
        assert items[0]["type"] == "expense"

    def test_parse_amount_14col(self):
        """测试14列格式金额解析"""
        content = """明细查询文件下载
卡号:1234****5678

交易日期, 记账日期, 摘要, 交易场所, 交易国家或地区简称, 交易金额(收入), 交易金额(支出), 交易币种, 记账金额(收入), 记账金额(支出), 记账币种, 余额, 对方户名, 对方账户
2026-07-26, 2026-07-26, 消费, 财付通-沃尔玛到家, CHN, , 229.71, 人民币, , 229.71, 人民币, -389.99, , 
"""
        items, _ = parse_icbc_csv(content)

        assert items[0]["amount"] == 22971  # 229.71元 = 22971分
        assert items[0]["type"] == "expense"

    def test_parse_income_15col(self):
        """测试15列格式收入"""
        content = """明细查询文件下载
卡号:1234****5678

交易日期, 摘要, 交易详情, 交易场所, 交易国家或地区简称, 钞/汇, 交易金额(收入), 交易金额(支出), 交易币种, 记账金额(收入), 记账金额(支出), 记账币种, 余额, 对方户名, 对方账户
2026-07-30, 工资, , , CHN, 钞, -, -, -, 3629.54, , 人民币, 1003.25, 成都地铁运营有限公司, 4402****7387
"""
        items, _ = parse_icbc_csv(content)

        assert items[0]["amount"] == 362954  # 3629.54元 = 362954分
        assert items[0]["type"] == "income"

    def test_parse_transfer_venue(self):
        """测试转账类型识别（交易场所）"""
        content = """明细查询文件下载
卡号:1234****5678

交易日期, 摘要, 交易详情, 交易场所, 交易国家或地区简称, 钞/汇, 交易金额(收入), 交易金额(支出), 交易币种, 记账金额(收入), 记账金额(支出), 记账币种, 余额, 对方户名, 对方账户
2026-07-30, 消费, , 支付宝-支付宝小荷包-自动攒, CHN, 钞, -, -, -, , 13.14, 人民币, 1000.00, 支付宝支付科技有限公司, 2088****1911
"""
        items, _ = parse_icbc_csv(content)

        assert items[0]["type"] == "transfer"

    def test_parse_balance(self):
        """测试余额解析"""
        content = """明细查询文件下载
卡号:1234****5678

交易日期, 摘要, 交易详情, 交易场所, 交易国家或地区简称, 钞/汇, 交易金额(收入), 交易金额(支出), 交易币种, 记账金额(收入), 记账金额(支出), 记账币种, 余额, 对方户名, 对方账户
2026-07-30, 消费, , 支付宝-特约商户, CHN, 钞, -, -, -, , 3.25, 人民币, 1000.00, 支付宝支付科技有限公司, 2088****1911
"""
        items, _ = parse_icbc_csv(content)

        assert items[0]["balance"] == 100000  # 1000.00元 = 100000分

    def test_parse_empty_content(self):
        """测试空内容"""
        content = """明细查询文件下载
卡号:1234****5678

交易日期, 摘要, 交易详情, 交易场所, 交易国家或地区简称, 钞/汇, 交易金额(收入), 交易金额(支出), 交易币种, 记账金额(收入), 记账金额(支出), 记账币种, 余额, 对方户名, 对方账户
"""
        items, _ = parse_icbc_csv(content)

        assert len(items) == 0

    def test_parse_invalid_header(self):
        """测试无效表头"""
        content = """这是无效的文件内容
没有正确的表头
"""
        with pytest.raises(ValueError, match="无法识别工商银行明细格式"):
            parse_icbc_csv(content)


class TestParseICBCCreditFields:
    """工行信用卡14列字段解析测试"""

    def test_parse_basic(self):
        """测试基本14列解析"""
        fields = [
            "2026-07-26", "2026-07-26", "消费", "财付通-沃尔玛到家", "CHN",
            "", "229.71", "人民币", "", "229.71", "人民币", "-389.99", "", ""
        ]
        result = _parse_icbc_credit_fields(fields, "1234****5678")

        assert result is not None
        assert result["amount"] == 22971
        assert result["type"] == "expense"
        assert result["transaction_time"] == "2026-07-26"

    def test_parse_income(self):
        """测试收入解析"""
        fields = [
            "2026-07-26", "2026-07-26", "消费返利", "ICBC Visa", "SGP",
            "0.11", "", "美元", "0.11", "", "美元", "-10.38", "", ""
        ]
        result = _parse_icbc_credit_fields(fields, "1234****5678")

        assert result is not None
        assert result["amount"] == 11  # 0.11元 = 11分
        assert result["type"] == "income"

    def test_parse_invalid_date(self):
        """测试无效日期"""
        fields = [
            "invalid-date", "2026-07-26", "消费", "财付通", "CHN",
            "", "229.71", "人民币", "", "229.71", "人民币", "-389.99", "", ""
        ]
        result = _parse_icbc_credit_fields(fields, "1234****5678")

        assert result is None

    def test_parse_zero_amount(self):
        """测试零金额"""
        fields = [
            "2026-07-26", "2026-07-26", "消费", "财付通", "CHN",
            "", "0.00", "人民币", "", "0.00", "人民币", "0.00", "", ""
        ]
        result = _parse_icbc_credit_fields(fields, "1234****5678")

        assert result is None


class TestParseICBCFields:
    """工行15列字段解析测试"""

    def test_parse_basic(self):
        """测试基本15列解析"""
        fields = [
            "2026-07-30", "消费", "", "支付宝-特约商户", "CHN", "钞",
            "-", "-", "-", "", "3.25", "人民币", "1000.00",
            "支付宝支付科技有限公司", "2088****1911"
        ]
        result = _parse_icbc_fields(fields, "1234****5678")

        assert result is not None
        assert result["amount"] == 325
        assert result["type"] == "expense"

    def test_parse_too_few_fields(self):
        """测试字段数不足"""
        fields = ["2026-07-30", "消费", "", "支付宝"]
        result = _parse_icbc_fields(fields, "1234****5678")

        assert result is None

    def test_parse_14col_auto_detect(self):
        """测试14列格式自动检测"""
        fields = [
            "2026-07-26", "2026-07-26", "消费", "财付通-沃尔玛到家", "CHN",
            "", "229.71", "人民币", "", "229.71", "人民币", "-389.99", "", ""
        ]
        result = _parse_icbc_fields(fields, "1234****5678")

        # 应该自动调用 _parse_icbc_credit_fields
        assert result is not None
        assert result["amount"] == 22971
