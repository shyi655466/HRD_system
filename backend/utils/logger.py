# 文件路径: utils/logger.py
import os
from loguru import logger
import sys

# 确保 logs 文件夹存在
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOG_DIR = os.path.join(BASE_DIR, 'logs')
if not os.path.exists(LOG_DIR):
    os.makedirs(LOG_DIR)

def setup_logger():
    # 移除默认配置
    logger.remove()
    
    # 控制台输出（带颜色，方便你在本地开发时查看）
    logger.add(sys.stdout, colorize=True, format="<green>{time:YYYY-MM-DD HH:mm:ss}</green> | <level>{level: <8}</level> | <cyan>{name}</cyan>:<cyan>{function}</cyan>:<cyan>{line}</cyan> - <level>{message}</level>")
    
    # 信息日志文件（按天切割，保留30天）
    logger.add(os.path.join(LOG_DIR, "app_info.log"), level="INFO", rotation="00:00", retention="30 days", encoding="utf-8")
    
    # 错误日志文件（捕获你的 R脚本崩溃、数据库报错等）
    logger.add(os.path.join(LOG_DIR, "app_error.log"), level="ERROR", rotation="00:00", retention="30 days", encoding="utf-8", backtrace=True, diagnose=True)

# 执行初始化
setup_logger()