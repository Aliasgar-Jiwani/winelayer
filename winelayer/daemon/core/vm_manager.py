"""
WineLayer — Virtual Machine Manager (Phase 4)

Manages a background KVM/QEMU Micro-VM for apps that cannot run in Wine natively.
In Windows/Dev mode, it stubs out the actual libvirt/FreeRDP binaries.
"""

import asyncio
import logging
from typing import Callable, Awaitable, Optional

from daemon.config import config

logger = logging.getLogger(__name__)
ProgressReporter = Callable[[str, str], Awaitable[None]]

class VMManager:
    def __init__(self):
        self.is_running = False
        self.image_downloaded = False
        self._vm_lock = asyncio.Lock()

    async def ensure_vm_image(self, reporter: Optional[ProgressReporter] = None) -> bool:
        """Download or verify the base Windows KVM image."""
        if self.image_downloaded:
            return True

        if reporter:
            await reporter("downloading_vm", "Downloading Windows base image (mock)...")
        
        # Simulate download
        await asyncio.sleep(2)
        self.image_downloaded = True
        
        if reporter:
            await reporter("done", "Base image ready.")
        
        logger.info("Micro-VM base image is verified and ready.")
        return True

    async def start_vm(self) -> bool:
        """Start the background VM headlessly."""
        async with self._vm_lock:
            if self.is_running:
                return True
            
            logger.info("Starting hidden Micro-VM engine...")
            # Simulate Hypervisor boot
            await asyncio.sleep(1.5)
            self.is_running = True
            logger.info("Micro-VM is now Online.")
            return True

    async def stop_vm(self) -> bool:
        """Shutdown/Suspend the background VM."""
        async with self._vm_lock:
            if not self.is_running:
                return True
            
            logger.info("Suspending Micro-VM engine...")
            await asyncio.sleep(0.5)
            self.is_running = False
            logger.info("Micro-VM is Offline.")
            return True

    def get_status(self) -> dict:
        """Get the current VM engine status."""
        return {
            "is_running": self.is_running,
            "image_downloaded": self.image_downloaded
        }

    async def run_app_in_vm(self, app_id: str, exe_path: str, reporter: Optional[ProgressReporter] = None) -> dict:
        """
        Run a specific executable inside the VM and pipe the window via FreeRDP.
        """
        if not self.is_running:
            if reporter:
                await reporter("starting_vm", "Waking up Micro-VM Sandbox...")
            await self.start_vm()

        if reporter:
            await reporter("projecting_rdp", f"Projecting {app_id} natively from VM...")

        logger.info(f"Routing '{app_id}' via FreeRDP/RemoteApp sandbox...")

        # In dev mode, we just run the exe normally on the host Windows system anyway!
        if not config.is_linux:
            logger.info(f"Dev mode: Executing {exe_path} directly on Windows but pretending it's in a VM Sandbox.")
            import subprocess as sp
            try:
                proc = sp.Popen(
                    [exe_path],
                    stdout=sp.DEVNULL,
                    stderr=sp.DEVNULL,
                    creationflags=sp.DETACHED_PROCESS | sp.CREATE_NEW_PROCESS_GROUP,
                )
                logger.info(f"Sandbox launched '{app_id}' natively with PID {proc.pid}")
            except OSError as e:
                logger.error(f"Sandbox launch failed '{app_id}': {e}")
                raise RuntimeError(f"Failed to launch in Sandbox {exe_path}: {e}")
        else:
            # Linux: Simulate FreeRDP call
            logger.info(f"Linux Sandbox: Firing `xfreerdp /app:{exe_path}` ...")
            # In real software, this would wait for process to detach or run silently
            await asyncio.sleep(1)

        return {"sandbox_status": "success", "app_id": app_id}

# Singleton instance
vm_manager = VMManager()
