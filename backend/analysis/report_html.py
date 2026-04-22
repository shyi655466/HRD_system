"""
HRD 静态 HTML 报告生成（供 Celery 写入 HRD_result/HRD_report.html）。
与前端报告章节对齐的精简版，所有动态文本经 html.escape 处理。
"""
from __future__ import annotations

import html
import json
from datetime import datetime
from django.conf import settings
from django.utils import timezone

from .models import HRDResult, Sample


def _thr() -> float:
    return float(getattr(settings, "HRD_POSITIVE_SCORE_MIN", 42.0))


def _brca_label_zh(hrd_score: float) -> str:
    thr = _thr()
    if hrd_score >= thr:
        return "阳性"
    return "阴性"


def _fmt_dt(dt) -> str:
    if not dt:
        return "—"
    if isinstance(dt, datetime):
        return timezone.localtime(dt).strftime("%Y-%m-%d %H:%M:%S")
    return html.escape(str(dt).replace("T", " ")[:19])


def build_hrd_report_html(sample: Sample, result: HRDResult) -> str:
    thr = _thr()
    try:
        hrd = float(result.hrd_score)
    except (TypeError, ValueError):
        hrd = float("nan")
    positive = hrd >= thr if hrd == hrd else False
    judge = "HRD 阳性" if positive else "HRD 阴性"
    tag_cls = "tag-pos" if positive else "tag-neg"
    summary = (
        "该样本 HRD 综合评分达到阳性阈值，提示存在同源重组修复缺陷倾向。"
        if positive
        else "该样本 HRD 综合评分未达到阳性阈值，未提示明显 HRD 倾向。"
    )
    brca_zh = _brca_label_zh(hrd) if hrd == hrd else "—"

    sc = html.escape(sample.sample_code or "—")
    pid = html.escape(sample.patient_id or "—")
    dt_label = sample.get_data_type_display() if hasattr(sample, "get_data_type_display") else sample.data_type
    dt_label = html.escape(str(dt_label))
    in_label = result.get_input_type_display() if hasattr(result, "get_input_type_display") else result.input_type
    in_label = html.escape(str(in_label))
    gbuild = html.escape(result.genome_build or "—")
    pver = html.escape(result.pipeline_version or "—")

    loh = html.escape(str(result.loh_score))
    tai = html.escape(str(result.tai_score))
    lst = html.escape(str(result.lst_score))
    hrd_s = html.escape(str(result.hrd_score)) if hrd == hrd else "—"

    qc_block = ""
    if result.qc_metrics and isinstance(result.qc_metrics, dict) and len(result.qc_metrics) > 0:
        qc_json = html.escape(json.dumps(result.qc_metrics, ensure_ascii=False, indent=2))
        qc_block = f"""
        <h2>五、质控信息</h2>
        <pre class="pre">{qc_json}</pre>
        """

    method_num = "六" if qc_block else "五"

    return f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>HRD 评分基因检测报告 - {sc}</title>
  <style>
    body {{ font-family: "Segoe UI", "PingFang SC", "Microsoft YaHei", sans-serif; margin: 24px; color: #303133; line-height: 1.6; }}
    h1 {{ text-align: center; font-size: 22px; color: #1f2a44; }}
    .sub {{ text-align: center; color: #909399; font-size: 13px; margin-bottom: 28px; }}
    h2 {{ font-size: 16px; color: #1f2a44; border-bottom: 1px solid #ebeef5; padding-bottom: 8px; margin-top: 28px; }}
    table {{ border-collapse: collapse; width: 100%; max-width: 720px; margin: 12px 0; font-size: 14px; }}
    th, td {{ border: 1px solid #dcdfe6; padding: 8px 12px; text-align: left; }}
    th {{ background: #f5f7fa; width: 160px; }}
    .pre {{ background: #f5f7fa; padding: 12px; border-radius: 6px; overflow: auto; font-size: 12px; white-space: pre-wrap; word-break: break-word; }}
    .tag-pos {{ color: #f56c6c; font-weight: 600; }}
    .tag-neg {{ color: #67c23a; font-weight: 600; }}
  </style>
</head>
<body>
  <h1>HRD 评分基因检测报告</h1>
  <p class="sub">由 HRD 评分计算系统自动生成（静态文件，与在线报告同源数据）</p>

  <h2>一、样本与检测信息</h2>
  <table>
    <tr><th>样本编号</th><td>{sc}</td></tr>
    <tr><th>患者编号</th><td>{pid}</td></tr>
    <tr><th>数据类型</th><td>{dt_label}</td></tr>
    <tr><th>输入类型</th><td>{in_label}</td></tr>
    <tr><th>参考基因组</th><td>{gbuild}</td></tr>
    <tr><th>分析管道版本</th><td>{pver}</td></tr>
    <tr><th>分析时间</th><td>{_fmt_dt(result.analysis_date)}</td></tr>
  </table>

  <h2>二、HRD 评分结果</h2>
  <p>阳性判定标准：HRD 综合评分 ≥ {thr} 为阳性；&lt; {thr} 为阴性。</p>
  <table>
    <tr><th>LOH</th><td>{loh}</td></tr>
    <tr><th>TAI</th><td>{tai}</td></tr>
    <tr><th>LST</th><td>{lst}</td></tr>
    <tr><th>HRD 综合评分</th><td>{hrd_s}</td></tr>
    <tr><th>HRD 判定</th><td>{html.escape(judge)}</td></tr>
    <tr><th>BRCA 状态（与 HRD 阈值一致）</th><td>{html.escape(brca_zh)}</td></tr>
  </table>

  <h2>三、结果解读与结论</h2>
  <table>
    <tr><th>HRD 总评分</th><td>{hrd_s}</td></tr>
    <tr><th>结果判定</th><td><span class="{tag_cls}">{html.escape(judge)}</span></td></tr>
    <tr><th>结果说明</th><td>{html.escape(summary)}</td></tr>
    <tr><th>临床提示</th><td>建议结合患者临床信息、病理结果及其他分子检测结果进行综合评估。</td></tr>
  </table>
  <p><strong>建议：</strong>建议结合临床表现、病理信息及其他检测结果综合判断。</p>

  <h2>四、指标明细</h2>
  <table>
    <tr><th>项目</th><th>数值</th><th>说明</th></tr>
    <tr><td>LOH</td><td>{loh}</td><td>杂合性缺失评分</td></tr>
    <tr><td>TAI</td><td>{tai}</td><td>端粒等位基因失衡评分</td></tr>
    <tr><td>LST</td><td>{lst}</td><td>大片段状态转移评分</td></tr>
    <tr><td>HRD 综合评分</td><td>{hrd_s}</td><td>{'达到或超过阳性阈值' if positive else '未达阳性阈值'} {thr}</td></tr>
  </table>
  {qc_block}
  <h2>{method_num}、方法学说明</h2>
  <p>HRD 综合评分基于 scarHRD 等方法对 LOH、TAI、LST 等指标整合计算。本报告文件由分析完成后异步任务写入 HRD_result 目录。</p>
</body>
</html>
"""
