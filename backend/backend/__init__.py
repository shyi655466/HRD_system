import pymysql
from .celery import app as celery_app
from utils.logger import logger

__all__ = ('celery_app',)
pymysql.install_as_MySQLdb()