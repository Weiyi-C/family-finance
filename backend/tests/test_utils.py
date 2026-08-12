"""通用工具函数测试"""

import pytest
from app.parsers.base import detect_and_decode
from app.parsers.utils import identify_platform_and_merchant, KNOWN_PLATFORMS


class TestDetectAndDecode:
    """编码检测测试"""

    def test_utf8(self):
        """测试 UTF-8 编码"""
        content = "这是中文内容".encode("utf-8")
        result = detect_and_decode(content)
        assert result == "这是中文内容"

    def test_utf8_bom(self):
        """测试 UTF-8 BOM 编码"""
        content = "这是中文内容".encode("utf-8-sig")
        result = detect_and_decode(content)
        assert result == "这是中文内容"

    def test_gbk(self):
        """测试 GBK 编码"""
        content = "这是中文内容".encode("gbk")
        result = detect_and_decode(content)
        assert result == "这是中文内容"

    def test_empty_content(self):
        """测试空内容"""
        content = b""
        result = detect_and_decode(content)
        assert result == ""


class TestIdentifyPlatformAndMerchant:
    """平台和商户识别测试"""

    def test_alipay_taobao(self):
        """测试淘宝平台识别"""
        platform, merchant = identify_platform_and_merchant(
            "淘宝-某店铺", "商品描述", "alipay"
        )
        assert platform == "淘宝"

    def test_alipay_meituan(self):
        """测试美团平台识别"""
        platform, merchant = identify_platform_and_merchant(
            "美团-某餐厅", "外卖订单", "alipay"
        )
        assert platform == "美团"

    def test_wechat_platform(self):
        """测试微信平台识别"""
        platform, merchant = identify_platform_and_merchant(
            "某商户", "商品描述", "wechat"
        )
        assert platform == "微信"

    def test_unknown_platform(self):
        """测试未知平台"""
        platform, merchant = identify_platform_and_merchant(
            "普通商户", "商品描述", "unknown"
        )
        assert platform == "线下"

    def test_known_platforms_set(self):
        """测试已知平台集合"""
        assert "淘宝" in KNOWN_PLATFORMS
        assert "京东" in KNOWN_PLATFORMS
        assert "美团" in KNOWN_PLATFORMS
        assert "拼多多" in KNOWN_PLATFORMS
