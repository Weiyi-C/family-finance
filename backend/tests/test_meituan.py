"""美团账单 CSV 解析器测试"""

import pytest
from app.parsers.meituan import parse_meituan_csv


class TestParseMeituanCSV:
    """美团账单 CSV 解析测试"""

    def _make_content(self, rows: list[str]) -> str:
        """构建美团账单 CSV 内容"""
        header = """美团账单

统计信息

交易创建时间, 交易成功时间, 交易类型, 订单标题, 收/支, 支付方式, 订单金额, 实付金额, 交易单号, 商家单号, 备注
"""
        return header + "\n".join(rows) + "\n"

    def test_parse_basic(self):
        """测试基本解析功能"""
        content = self._make_content([
            '2026-07-27 19:40:04, 2026-07-27 19:40:13, 支付, 姜胖胖韩式自助烤肉, 支出, 美团月付, ¥139.80, ¥139.80, 2026072719400412345, 20260727194004, ',
            '2026-07-02 11:25:22, 2026-07-02 11:25:27, 还款, 【美团月付】主动还款2026年7月账单, 支出, 中国工商银行储蓄卡(0726), ¥301.88, ¥301.88, 2026070211252212345, 20260702112522, ',
        ])
        items, meta = parse_meituan_csv(content)

        assert len(items) == 2
        assert meta["platform"] == "美团"
        assert meta["has_payment_method"] is True

    def test_parse_amount(self):
        """测试金额解析（去掉¥前缀，转为分）"""
        content = self._make_content([
            '2026-07-27 19:40:04, 2026-07-27 19:40:13, 支付, 姜胖胖韩式自助烤肉, 支出, 美团月付, ¥139.80, ¥139.80, 2026072719400412345, 20260727194004, ',
        ])
        items, _ = parse_meituan_csv(content)

        assert items[0]["amount"] == 13980  # ¥139.80 = 13980分

    def test_parse_transaction_time(self):
        """测试交易时间（使用交易成功时间）"""
        content = self._make_content([
            '2026-07-27 19:40:04, 2026-07-27 19:40:13, 支付, 姜胖胖韩式自助烤肉, 支出, 美团月付, ¥139.80, ¥139.80, 2026072719400412345, 20260727194004, ',
        ])
        items, _ = parse_meituan_csv(content)

        assert items[0]["transaction_time"] == "2026-07-27 19:40:13"

    def test_parse_expense_type(self):
        """测试支出类型识别"""
        content = self._make_content([
            '2026-07-27 19:40:04, 2026-07-27 19:40:13, 支付, 姜胖胖韩式自助烤肉, 支出, 美团月付, ¥139.80, ¥139.80, 2026072719400412345, 20260727194004, ',
        ])
        items, _ = parse_meituan_csv(content)

        assert items[0]["type"] == "expense"

    def test_parse_transfer_type(self):
        """测试转账类型识别（还款）"""
        content = self._make_content([
            '2026-07-02 11:25:22, 2026-07-02 11:25:27, 还款, 【美团月付】主动还款2026年7月账单, 支出, 中国工商银行储蓄卡(0726), ¥301.88, ¥301.88, 2026070211252212345, 20260702112522, ',
        ])
        items, _ = parse_meituan_csv(content)

        assert items[0]["type"] == "transfer"

    def test_parse_payment_method(self):
        """测试支付方式提取"""
        content = self._make_content([
            '2026-07-27 19:40:04, 2026-07-27 19:40:13, 支付, 姜胖胖韩式自助烤肉, 支出, 美团月付, ¥139.80, ¥139.80, 2026072719400412345, 20260727194004, ',
        ])
        items, meta = parse_meituan_csv(content)

        assert items[0]["payment_method"] == "美团月付"
        assert "美团月付" in meta["detected_methods"]

    def test_parse_order_no(self):
        """测试交易单号提取"""
        content = self._make_content([
            '2026-07-27 19:40:04, 2026-07-27 19:40:13, 支付, 姜胖胖韩式自助烤肉, 支出, 美团月付, ¥139.80, ¥139.80, 2026072719400412345, 20260727194004, ',
        ])
        items, _ = parse_meituan_csv(content)

        assert items[0]["order_no"] == "2026072719400412345"

    def test_parse_merchant_name(self):
        """测试商户名提取（去掉【】前缀）"""
        content = self._make_content([
            '2026-07-02 11:25:22, 2026-07-02 11:25:27, 还款, 【美团月付】主动还款2026年7月账单, 支出, 中国工商银行储蓄卡(0726), ¥301.88, ¥301.88, 2026070211252212345, 20260702112522, ',
        ])
        items, _ = parse_meituan_csv(content)

        # 应该去掉【美团月付】前缀
        assert "美团月付" not in items[0]["merchant"] or items[0]["merchant"].startswith("主动还款")

    def test_parse_empty_content(self):
        """测试空内容"""
        content = self._make_content([])
        items, _ = parse_meituan_csv(content)

        assert len(items) == 0

    def test_parse_invalid_header(self):
        """测试无效表头"""
        content = """这是无效的文件内容
没有正确的表头
"""
        with pytest.raises(ValueError, match="无法识别美团账单格式"):
            parse_meituan_csv(content)

    def test_parse_detected_methods(self):
        """测试支付方式收集"""
        content = self._make_content([
            '2026-07-27 19:40:04, 2026-07-27 19:40:13, 支付, 餐厅A, 支出, 美团月付, ¥100.00, ¥100.00, 1, 1, ',
            '2026-07-28 19:40:04, 2026-07-28 19:40:13, 支付, 餐厅B, 支出, 工商银行(0726), ¥50.00, ¥50.00, 2, 2, ',
        ])
        _, meta = parse_meituan_csv(content)

        assert "美团月付" in meta["detected_methods"]
        assert "工商银行(0726)" in meta["detected_methods"]
