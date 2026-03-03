# analysis/tasks.py
import time
from celery import shared_task
from django.db import transaction
from .models import Sample, AnalysisTask, HRDResult

# @shared_task 装饰器是关键，它告诉 Celery 这是一个可以丢进后台队列的任务
@shared_task
def run_hrd_analysis(db_task_id, sample_id):
    """
    这是真正的后台执行逻辑。
    目前用 time.sleep 模拟耗时的生信计算流程。
    """
    try:
        # 1. 从数据库捞出任务和样本
        task = AnalysisTask.objects.get(id=db_task_id)
        sample = Sample.objects.get(id=sample_id)

        # 2. 状态更新：告诉系统，我开始跑了
        task.status = 'STARTED'
        task.save()
        
        # ====== 这里是未来的核心生信算法调用区域 ======
        # 比如：os.system('sh run_pipeline.sh /data/fastq...')
        print(f"任务 [{task.id}] 开始处理样本: {sample.sample_code}")
        
        # 模拟生信分析极其耗时（让他睡 15 秒）
        time.sleep(15) 
        
        # 模拟计算出的结果数据
        mock_result_data = {
            "hrd_score": 68.5,
            "loh_score": 25,
            "tai_score": 25,
            "lst_score": 18.5,
            "brca_status": "Negative"
        }
        # ===============================================

        # 3. 开启数据库事务，确保数据一致性（要么全成功，要么全失败）
        with transaction.atomic():
            # A. 存入结果表
            HRDResult.objects.update_or_create(
                sample=sample,
                defaults=mock_result_data
            )
            
            # B. 完结状态
            task.status = 'SUCCESS'
            task.log_output = "Analysis completed successfully."
            task.save()
            
            sample.status = 'completed'
            sample.save()
            
        print(f"任务 [{task.id}] 圆满完成！结果已入库。")
        return "SUCCESS"

    except Exception as e:
        # 4. 如果中途报错（比如文件找不到），记录失败日志
        task = AnalysisTask.objects.get(id=db_task_id)
        task.status = 'FAILURE'
        task.log_output = f"Error: {str(e)}"
        task.save()
        
        sample = Sample.objects.get(id=sample_id)
        sample.status = 'failed'
        sample.save()
        
        print(f"任务 [{task.id}] 失败: {str(e)}")
        return "FAILED"