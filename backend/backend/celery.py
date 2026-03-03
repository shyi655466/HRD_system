import os
from celery import Celery

# 1. 设置 Django 的默认 settings 模块
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')

# 2. 实例化 Celery，名字就叫 'backend'
app = Celery('backend')

# 3. 告诉 Celery 去 settings.py 里找配置（以 CELERY_ 开头的变量）
app.config_from_object('django.conf:settings', namespace='CELERY')

# 4. 自动去所有已注册的 app (比如我们的 analysis) 里寻找 tasks.py
app.autodiscover_tasks()