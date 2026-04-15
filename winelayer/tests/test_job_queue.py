"""
Unit tests for the Job Queue module.
"""

import asyncio
from pathlib import Path
import pytest
import sys

sys.path.insert(0, str(Path(__file__).parent.parent))


class TestJobQueue:
    """Tests for the JobQueue."""

    def test_job_creation(self):
        from daemon.core.job_queue import Job, JobStatus

        job = Job(
            id="test-1",
            app_id="test_app",
            action="install",
        )
        assert job.id == "test-1"
        assert job.status == JobStatus.QUEUED
        assert job.error is None

    def test_job_to_dict(self):
        from daemon.core.job_queue import Job

        job = Job(id="test-2", app_id="app", action="install")
        d = job.to_dict()
        assert d["id"] == "test-2"
        assert d["status"] == "queued"
        assert "created_at" in d

    def test_job_status_enum(self):
        from daemon.core.job_queue import JobStatus

        assert JobStatus.QUEUED == "queued"
        assert JobStatus.RUNNING == "running"
        assert JobStatus.COMPLETED == "completed"
        assert JobStatus.FAILED == "failed"
        assert JobStatus.CANCELLED == "cancelled"

    def test_submit_job(self):
        from daemon.core.job_queue import JobQueue

        q = JobQueue()
        job_id = q.submit("test_app", "install", {"exe_path": "/test.exe"})
        assert isinstance(job_id, str)
        assert len(job_id) > 0

    def test_get_job(self):
        from daemon.core.job_queue import JobQueue

        q = JobQueue()
        job_id = q.submit("test_app", "install")
        job = q.get_job(job_id)
        assert job is not None
        assert job["app_id"] == "test_app"
        assert job["status"] == "queued"

    def test_get_nonexistent_job(self):
        from daemon.core.job_queue import JobQueue

        q = JobQueue()
        result = q.get_job("nonexistent-id")
        assert result is None

    def test_list_jobs(self):
        from daemon.core.job_queue import JobQueue

        q = JobQueue()
        q.submit("app1", "install")
        q.submit("app2", "install")
        jobs = q.list_jobs()
        assert len(jobs) == 2

    def test_cancel_queued_job(self):
        from daemon.core.job_queue import JobQueue

        q = JobQueue()
        job_id = q.submit("app", "install")
        assert q.cancel_job(job_id) is True
        job = q.get_job(job_id)
        assert job["status"] == "cancelled"

    def test_cancel_nonexistent_fails(self):
        from daemon.core.job_queue import JobQueue

        q = JobQueue()
        assert q.cancel_job("nope") is False

    def test_active_count(self):
        from daemon.core.job_queue import JobQueue

        q = JobQueue()
        q.submit("app1", "install")
        q.submit("app2", "install")
        assert q.active_count == 2

    def test_queue_size(self):
        from daemon.core.job_queue import JobQueue

        q = JobQueue()
        q.submit("app1", "install")
        assert q.queue_size == 1
