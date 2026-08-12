"""账单解析器模块"""

from .base import detect_and_decode
from .alipay import parse_alipay_csv
from .wechat import parse_wechat_csv, parse_excel
from .icbc import parse_icbc_pdf
from .icbc_csv import parse_icbc_csv
from .ccb_credit import parse_ccb_credit_csv
from .ccb_debit import parse_ccb_debit_xls
from .meituan import parse_meituan_csv
from .utils import identify_platform_and_merchant, KNOWN_PLATFORMS

__all__ = [
    "detect_and_decode",
    "parse_alipay_csv",
    "parse_wechat_csv",
    "parse_excel",
    "parse_icbc_pdf",
    "parse_icbc_csv",
    "parse_ccb_credit_csv",
    "parse_ccb_debit_xls",
    "parse_meituan_csv",
    "identify_platform_and_merchant",
    "KNOWN_PLATFORMS",
]
