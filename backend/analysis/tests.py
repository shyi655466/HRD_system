from pathlib import Path
from tempfile import TemporaryDirectory

from django.contrib.auth import get_user_model
from django.test import SimpleTestCase, TestCase, override_settings
from rest_framework.test import APIClient, APIRequestFactory, force_authenticate

from .hrd_pipeline import parse_final_hrd_tsv
from .models import Sample, SampleFile
from .views import StartAnalysisView


class AnalysisApiTests(TestCase):
    def setUp(self):
        self.user = get_user_model().objects.create_user(
            username="api-tester",
            password="StrongPass123",
        )
        self.client = APIClient()

    def authenticate(self):
        response = self.client.post(
            "/api/token/",
            {"username": "api-tester", "password": "StrongPass123"},
            format="json",
        )
        self.assertEqual(response.status_code, 200)
        token = response.data["access"]
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")
        return token

    def write_fastq(self, root: Path, relative_path: str) -> str:
        path = root / relative_path
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("@read1\nACGT\n+\n!!!!\n", encoding="utf-8")
        return str(path)

    def make_import_payload(self, root: Path, sample_code: str = "S-IMPORT-001"):
        return {
            "patient_id": "P-IMPORT-001",
            "sample_code": sample_code,
            "data_type": "WGS",
            "description": "server import test",
            "files": [
                {
                    "file_role": "TUMOR_R1",
                    "path": self.write_fastq(root, "tumor_R1.fastq"),
                },
                {
                    "file_role": "TUMOR_R2",
                    "path": self.write_fastq(root, "tumor_R2.fastq"),
                },
                {
                    "file_role": "NORMAL_R1",
                    "path": self.write_fastq(root, "normal_R1.fastq"),
                },
                {
                    "file_role": "NORMAL_R2",
                    "path": self.write_fastq(root, "normal_R2.fastq"),
                },
            ],
        }

    def test_login_returns_access_token(self):
        response = self.client.post(
            "/api/token/",
            {"username": "api-tester", "password": "StrongPass123"},
            format="json",
        )

        self.assertEqual(response.status_code, 200)
        self.assertIn("access", response.data)
        self.assertIn("refresh", response.data)

    def test_create_sample_api(self):
        self.authenticate()

        response = self.client.post(
            "/api/samples/",
            {
                "patient_id": "P-CREATE-001",
                "sample_code": "S-CREATE-001",
                "data_type": "WGS",
                "description": "create sample test",
            },
            format="json",
        )

        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.data["sample_code"], "S-CREATE-001")
        sample = Sample.objects.get(sample_code="S-CREATE-001")
        self.assertEqual(sample.owner, self.user)
        self.assertEqual(sample.upload_status, Sample.UploadStatus.DRAFT)

    def test_import_sample_from_server_api(self):
        self.authenticate()

        with TemporaryDirectory() as allowed_dir:
            payload = self.make_import_payload(Path(allowed_dir))
            with override_settings(HRD_ALLOWED_IMPORT_ROOTS=[allowed_dir]):
                response = self.client.post(
                    "/api/samples/import-from-server/",
                    payload,
                    format="json",
                )

        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.data["sample"]["sample_code"], "S-IMPORT-001")
        sample = Sample.objects.get(sample_code="S-IMPORT-001")
        self.assertEqual(sample.upload_status, Sample.UploadStatus.UPLOADED)
        self.assertEqual(sample.analysis_status, Sample.AnalysisStatus.NOT_STARTED)
        self.assertEqual(sample.files.count(), 4)
        self.assertTrue(
            sample.files.filter(
                file_role=SampleFile.FileRole.TUMOR_R1,
                upload_status=SampleFile.UploadStatus.UPLOADED,
                merge_status=SampleFile.MergeStatus.MERGED,
                is_verified=True,
            ).exists()
        )

    def test_validate_paths_rejects_path_outside_allowed_roots(self):
        self.authenticate()

        with TemporaryDirectory() as allowed_dir, TemporaryDirectory() as other_dir:
            outside_path = self.write_fastq(Path(other_dir), "outside.fastq")
            with override_settings(HRD_ALLOWED_IMPORT_ROOTS=[allowed_dir]):
                response = self.client.post(
                    "/api/server-files/validate-paths/",
                    {
                        "files": [
                            {
                                "file_role": "TUMOR_R1",
                                "path": outside_path,
                            }
                        ]
                    },
                    format="json",
                )

        self.assertEqual(response.status_code, 200)
        self.assertFalse(response.data["all_valid"])
        self.assertFalse(response.data["results"][0]["is_valid"])
        self.assertEqual(response.data["results"][0]["message"], "路径不在允许导入的目录范围内")

    def test_import_sample_from_server_rejects_path_outside_allowed_roots(self):
        self.authenticate()

        with TemporaryDirectory() as allowed_dir, TemporaryDirectory() as other_dir:
            payload = self.make_import_payload(Path(allowed_dir), "S-IMPORT-BAD-PATH")
            outside_path = self.write_fastq(Path(other_dir), "outside.fastq")
            payload["files"][0]["path"] = outside_path

            with override_settings(HRD_ALLOWED_IMPORT_ROOTS=[allowed_dir]):
                response = self.client.post(
                    "/api/samples/import-from-server/",
                    payload,
                    format="json",
                )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.headers["X-Original-Status-Code"], "400")
        self.assertIn("路径校验失败", response.data["detail"])
        self.assertFalse(Sample.objects.filter(sample_code="S-IMPORT-BAD-PATH").exists())

    def test_snp_panel_start_analysis_is_rejected(self):
        sample = Sample.objects.create(
            owner=self.user,
            patient_id="P-PANEL-001",
            sample_code="S-PANEL-001",
            data_type=Sample.DataType.SNP_PANEL,
            upload_status=Sample.UploadStatus.UPLOADED,
            analysis_status=Sample.AnalysisStatus.NOT_STARTED,
        )
        request = APIRequestFactory().post(f"/api/samples/{sample.id}/start-analysis/")
        force_authenticate(request, user=self.user)

        response = StartAnalysisView.as_view()(request, pk=sample.id)

        self.assertEqual(response.status_code, 400)
        self.assertIn("仅支持 WGS / WES 分析", response.data["detail"])
        self.assertFalse(sample.analysis_tasks.exists())


class HRDPipelineParsingTests(SimpleTestCase):
    def test_parse_final_hrd_tsv(self):
        with TemporaryDirectory() as tmp_dir:
            tsv_path = Path(tmp_dir) / "sample_final_hrd_score.tsv"
            tsv_path.write_text(
                "SampleID\tLOH\tTAI\tLST\tHRD_Score\n"
                "S-001\t12\t8\t22\t42\n",
                encoding="utf-8",
            )

            result = parse_final_hrd_tsv(tsv_path)

        self.assertEqual(
            result,
            {
                "hrd_score": 42.0,
                "loh_score": 12,
                "tai_score": 8,
                "lst_score": 22,
            },
        )
