"""编码检测和文件解析基础工具"""


def detect_and_decode(content_bytes: bytes) -> str:
    """自动检测文件编码并解码为字符串"""
    for encoding in ["utf-8-sig", "utf-8", "gbk", "gb18030", "gb2312"]:
        try:
            return content_bytes.decode(encoding)
        except (UnicodeDecodeError, LookupError):
            continue
    return content_bytes.decode("utf-8", errors="ignore")
