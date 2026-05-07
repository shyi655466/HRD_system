# 文件路径: middleware/exception_middleware.py
from django.http import JsonResponse
from utils.logger import logger
import traceback

class GlobalExceptionMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        # 请求到达视图（View）之前的操作可以写在这里
        logger.info(f"收到请求: {request.method} {request.path}")
        
        response = self.get_response(request)
        
        # 统一将业务/框架错误响应的 HTTP 状态码改为 200，
        # 错误类型继续由响应体中的 detail/code/status 等业务字段表达。
        if response.status_code >= 400:
            response["X-Original-Status-Code"] = str(response.status_code)
            response.status_code = 200

        return response

    def process_exception(self, request, exception):
        """
        核心方法：当 Django 内部（包括你的 API、Celery 调度代码）发生任何未捕获的异常时，都会触发这里。
        """
        # 1. 把详细的错误堆栈写入我们的 app_error.log 中
        logger.error(f"捕获到全局异常: 接口 [{request.path}]")
        logger.error(f"错误详情: {str(exception)}")
        logger.error(traceback.format_exc()) # 打印完整的追踪信息，方便找Bug

        # 2. 不向客户端泄露异常详情（路径、SQL 等）；详情仅写入日志
        response_data = {
            "code": 5000,
            "status": "error",
            "message": "系统运行异常，请联系管理员或查看服务器日志。",
            "data": None,
        }
        
        return JsonResponse(response_data, status=200, json_dumps_params={'ensure_ascii': False})
