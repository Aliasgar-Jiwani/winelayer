"""
WineLayer Daemon — Main Entrypoint

Starts the daemon process:
1. Initializes configuration and logging
2. Sets up the SQLite database
3. Detects Wine installation
4. Starts the JSON-RPC IPC server
5. Runs until interrupted
"""

import asyncio
import logging
import signal
import sys
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from daemon.config import config
from daemon.db.database import init_db, close_db
from daemon.core.ipc_server import IPCServer
from daemon.core.wine_manager import wine_manager
from daemon.core.catalog_manager import catalog_manager
from daemon.core.job_queue import job_queue


def setup_logging() -> None:
    """Configure logging for the daemon."""
    log_format = "%(asctime)s [%(levelname)s] %(name)s: %(message)s"
    logging.basicConfig(
        level=getattr(logging, config.log_level),
        format=log_format,
        handlers=[
            logging.StreamHandler(sys.stdout),
        ],
    )


async def main() -> None:
    """Main daemon entry point."""
    setup_logging()
    logger = logging.getLogger("winelayer")

    logger.info("=" * 60)
    logger.info("  WineLayer Daemon v0.2.0")
    logger.info(f"  Platform: {config.platform_name}")
    logger.info(f"  Data dir: {config.data_dir}")
    logger.info(f"  IPC: {config.ipc_host}:{config.ipc_port}")
    logger.info("=" * 60)

    # Step 1: Ensure directories exist
    config.ensure_directories()
    logger.info("Directory structure ready")

    # Step 2: Initialize database
    await init_db()
    logger.info("Database initialized")

    # Step 3: Detect Wine
    wine_info = await wine_manager.detect_wine()
    if wine_info:
        logger.info(f"Wine detected: {wine_info.version}")
    else:
        logger.warning("Wine not detected — running in limited mode")

    # Step 4: Load app catalog
    catalog_count = catalog_manager.load_catalog()
    logger.info(f"Catalog loaded: {catalog_count} apps")

    # Step 5: Start job queue
    await job_queue.start()
    logger.info("Job queue started")

    # Step 6: Start IPC server
    server = IPCServer(host=config.ipc_host, port=config.ipc_port)
    await server.start()

    # Step 7: Wait for shutdown signal
    logger.info("Daemon is ready. Waiting for connections...")

    stop_event = asyncio.Event()

    def _signal_handler():
        logger.info("Shutdown signal received")
        stop_event.set()

    # Register signal handlers
    loop = asyncio.get_running_loop()
    try:
        for sig in (signal.SIGINT, signal.SIGTERM):
            loop.add_signal_handler(sig, _signal_handler)
    except NotImplementedError:
        # Windows doesn't support add_signal_handler
        pass

    try:
        if sys.platform == "win32":
            # On Windows, use a keyboard interrupt approach
            while not stop_event.is_set():
                try:
                    await asyncio.wait_for(stop_event.wait(), timeout=1.0)
                except asyncio.TimeoutError:
                    continue
        else:
            await stop_event.wait()
    except KeyboardInterrupt:
        logger.info("Keyboard interrupt received")

    # Shutdown
    logger.info("Shutting down...")
    await job_queue.stop()
    await server.stop()
    await close_db()
    logger.info("Daemon stopped. Goodbye!")


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
