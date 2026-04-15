"""
WineLayer — Background Job Queue

Manages concurrent installation tasks with an asyncio-based worker pool.
Jobs are queued, processed sequentially (to avoid Wine conflicts), and
their progress is tracked for GUI display.
"""

import asyncio
import logging
import uuid
from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import Any, Callable, Awaitable, Optional

logger = logging.getLogger(__name__)


class JobStatus(str, Enum):
    QUEUED = "queued"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"


@dataclass
class Job:
    """Represents a background installation job."""
    id: str
    app_id: str
    action: str  # "install", "install_from_script", "uninstall"
    params: dict = field(default_factory=dict)
    status: JobStatus = JobStatus.QUEUED
    progress_stage: str = ""
    progress_message: str = ""
    result: Any = None
    error: Optional[str] = None
    created_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "app_id": self.app_id,
            "action": self.action,
            "status": self.status.value,
            "progress_stage": self.progress_stage,
            "progress_message": self.progress_message,
            "error": self.error,
            "created_at": self.created_at.isoformat(),
            "started_at": self.started_at.isoformat() if self.started_at else None,
            "completed_at": self.completed_at.isoformat() if self.completed_at else None,
        }


class JobQueue:
    """
    Async job queue for background installation tasks.
    Processes jobs sequentially to avoid Wine prefix conflicts.
    """

    def __init__(self, max_concurrent: int = 1):
        self._queue: asyncio.Queue[Job] = asyncio.Queue()
        self._jobs: dict[str, Job] = {}
        self._max_concurrent = max_concurrent
        self._workers: list[asyncio.Task] = []
        self._handlers: dict[str, Callable] = {}
        self._progress_callbacks: list[Callable] = []
        self._running = False

    def register_handler(self, action: str, handler: Callable) -> None:
        """Register a handler function for a job action."""
        self._handlers[action] = handler

    def on_progress(self, callback: Callable) -> None:
        """Register a callback for job progress updates."""
        self._progress_callbacks.append(callback)

    async def start(self) -> None:
        """Start the worker pool."""
        self._running = True
        for i in range(self._max_concurrent):
            worker = asyncio.create_task(self._worker(f"worker-{i}"))
            self._workers.append(worker)
        logger.info(f"Job queue started with {self._max_concurrent} worker(s)")

    async def stop(self) -> None:
        """Stop all workers gracefully."""
        self._running = False
        for worker in self._workers:
            worker.cancel()
        self._workers.clear()
        logger.info("Job queue stopped")

    def submit(self, app_id: str, action: str, params: dict = None) -> str:
        """
        Submit a new job to the queue.
        Returns the job ID.
        """
        job_id = str(uuid.uuid4())[:8]
        job = Job(
            id=job_id,
            app_id=app_id,
            action=action,
            params=params or {},
        )
        self._jobs[job_id] = job
        self._queue.put_nowait(job)
        logger.info(f"Job {job_id} submitted: {action} for '{app_id}'")
        return job_id

    def get_job(self, job_id: str) -> Optional[dict]:
        """Get the status of a specific job."""
        job = self._jobs.get(job_id)
        return job.to_dict() if job else None

    def list_jobs(self, include_completed: bool = True) -> list[dict]:
        """List all jobs, optionally filtering out completed ones."""
        jobs = self._jobs.values()
        if not include_completed:
            jobs = [
                j for j in jobs
                if j.status in (JobStatus.QUEUED, JobStatus.RUNNING)
            ]
        # Sort: running first, then queued, then completed
        priority = {
            JobStatus.RUNNING: 0,
            JobStatus.QUEUED: 1,
            JobStatus.COMPLETED: 2,
            JobStatus.FAILED: 3,
            JobStatus.CANCELLED: 4,
        }
        sorted_jobs = sorted(jobs, key=lambda j: priority.get(j.status, 5))
        return [j.to_dict() for j in sorted_jobs]

    def cancel_job(self, job_id: str) -> bool:
        """Cancel a queued job. Running jobs cannot be cancelled."""
        job = self._jobs.get(job_id)
        if not job:
            return False
        if job.status != JobStatus.QUEUED:
            return False

        job.status = JobStatus.CANCELLED
        job.completed_at = datetime.now(timezone.utc)
        logger.info(f"Job {job_id} cancelled")
        return True

    @property
    def active_count(self) -> int:
        return sum(
            1 for j in self._jobs.values()
            if j.status in (JobStatus.QUEUED, JobStatus.RUNNING)
        )

    @property
    def queue_size(self) -> int:
        return self._queue.qsize()

    async def _worker(self, worker_name: str) -> None:
        """Worker coroutine that processes jobs from the queue."""
        logger.info(f"{worker_name}: Started")

        while self._running:
            try:
                # Wait for a job with timeout (so we can check _running flag)
                try:
                    job = await asyncio.wait_for(
                        self._queue.get(), timeout=1.0
                    )
                except asyncio.TimeoutError:
                    continue

                # Skip cancelled jobs
                if job.status == JobStatus.CANCELLED:
                    self._queue.task_done()
                    continue

                # Execute the job
                await self._execute_job(job, worker_name)
                self._queue.task_done()

            except asyncio.CancelledError:
                break
            except Exception as e:
                logger.error(f"{worker_name}: Unexpected error: {e}")

        logger.info(f"{worker_name}: Stopped")

    async def _execute_job(self, job: Job, worker_name: str) -> None:
        """Execute a single job."""
        handler = self._handlers.get(job.action)
        if not handler:
            job.status = JobStatus.FAILED
            job.error = f"No handler registered for action: {job.action}"
            job.completed_at = datetime.now(timezone.utc)
            logger.error(f"Job {job.id}: {job.error}")
            return

        job.status = JobStatus.RUNNING
        job.started_at = datetime.now(timezone.utc)
        logger.info(f"{worker_name}: Starting job {job.id} ({job.action} for '{job.app_id}')")

        # Create a reporter that updates the job and notifies callbacks
        async def reporter(stage: str, message: str):
            job.progress_stage = stage
            job.progress_message = message
            for callback in self._progress_callbacks:
                try:
                    await callback(job.id, stage, message)
                except Exception:
                    pass

        try:
            result = await handler(job.app_id, job.params, reporter)
            job.status = JobStatus.COMPLETED
            job.result = result
            logger.info(f"{worker_name}: Job {job.id} completed successfully")
        except Exception as e:
            job.status = JobStatus.FAILED
            job.error = str(e)
            logger.error(f"{worker_name}: Job {job.id} failed: {e}")
        finally:
            job.completed_at = datetime.now(timezone.utc)


# Singleton instance
job_queue = JobQueue()
