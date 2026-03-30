from django.urls import path
from .views import (
    SampleListCreateView, 
    SampleDetailView, 
    StartAnalysisView, 
    SubmitResultView,
    ServerPathValidateView,
    ServerFileBrowseView,
    ImportSampleFromServerView,
)

urlpatterns = [
    # 样本基础接口
    # 对应 /api/samples/ -> 列出所有 或 新建
    path('samples/', SampleListCreateView.as_view(), name='sample-list-create'),
    
    # 对应 /api/samples/uuid-xxx/ -> 查看详情
    path('samples/<uuid:pk>/', SampleDetailView.as_view(), name='sample-detail'),

    # 对 id 为 pk 的样本，执行 run 动作
    path('samples/<uuid:pk>/run/', StartAnalysisView.as_view(), name='sample-run'),

    # 对 id 为 pk 的样本，执行 result 回传
    path('samples/<uuid:pk>/result/', SubmitResultView.as_view(), name='sample-result'),

    # 对 id 为 pk 的样本，执行 start-analysis 动作
    path('samples/<uuid:pk>/start-analysis/', StartAnalysisView.as_view(), name='start-analysis'),


    # 服务器路径导入接口
    path("server-files/validate-paths/", ServerPathValidateView.as_view(), name="validate_server_paths"),

    path("server-files/browse/", ServerFileBrowseView.as_view(), name="browse_server_files"),

    path("samples/import-from-server/", ImportSampleFromServerView.as_view(), name="import_sample_from_server"),
]