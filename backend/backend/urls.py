"""
URL configuration for backend project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/5.2/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""
from django.contrib import admin
from django.urls import path, include
from rest_framework_simplejwt.views import (  # 导入 JWT 提供的现成视图
    TokenObtainPairView,
    TokenRefreshView,
)

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/', include('analysis.urls')),
    
    # --- 新增 JWT 登录与刷新接口 ---
    # 这个接口的作用就是：你给它 post 用户名和密码，它还给你一个 Token
    path('api/token/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
    # 这个接口用于刷新 Token
    path('api/token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
]
