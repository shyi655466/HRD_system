from django.urls import path
from .views import SampleListCreateView, SampleDetailView, StartAnalysisView, SubmitResultView

urlpatterns = [
    # 对应 /api/samples/ -> 列出所有 或 新建
    path('samples/', SampleListCreateView.as_view(), name='sample-list-create'),
    
    # 对应 /api/samples/uuid-xxx/ -> 查看详情
    path('samples/<uuid:pk>/', SampleDetailView.as_view(), name='sample-detail'),

    # 对 id 为 pk 的样本，执行 run 动作
    path('samples/<uuid:pk>/run/', StartAnalysisView.as_view(), name='sample-run'),

    # 语义：对 id 为 pk 的样本，执行 result 回传
    path('samples/<uuid:pk>/result/', SubmitResultView.as_view(), name='sample-result'),
]