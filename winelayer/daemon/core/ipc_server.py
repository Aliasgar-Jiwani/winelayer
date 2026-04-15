"""
WineLayer — JSON-RPC IPC Server (Phase 2)

Provides a JSON-RPC 2.0 server over TCP socket for communication
between the Flutter GUI and the Python daemon.

Phase 2 adds:
  - search_catalog: Search app catalog
  - get_catalog: Get full catalog or filter
  - get_install_plan: Preview install steps for a catalog app
  - install_from_catalog: One-click install from catalog using script
  - list_jobs: List background job statuses
  - get_job_status: Get status of a specific job
"""

import asyncio
import json
import logging
import traceback
from typing import Any, Callable, Optional

from daemon.core.installer import installer
from daemon.core.wine_manager import wine_manager
from daemon.core.catalog_manager import catalog_manager
from daemon.core.script_engine import script_engine
from daemon.core.job_queue import job_queue
from daemon.core.log_analyzer import log_analyzer
from daemon.core.fix_engine import fix_engine
from daemon.core.vm_manager import vm_manager
from daemon.core.system_requirements import system_requirements

logger = logging.getLogger(__name__)


class JsonRpcError(Exception):
    """JSON-RPC error with code and message."""
    def __init__(self, code: int, message: str, data: Any = None):
        super().__init__(message)
        self.code = code
        self.message = message
        self.data = data

    def to_dict(self) -> dict:
        error = {"code": self.code, "message": self.message}
        if self.data is not None:
            error["data"] = self.data
        return error


# Standard JSON-RPC error codes
PARSE_ERROR = -32700
INVALID_REQUEST = -32600
METHOD_NOT_FOUND = -32601
INVALID_PARAMS = -32602
INTERNAL_ERROR = -32603


class IPCServer:
    """
    Async JSON-RPC 2.0 server over TCP.
    Handles method dispatch, error formatting, and client management.
    """

    def __init__(self, host: str = "127.0.0.1", port: int = 9274):
        self.host = host
        self.port = port
        self._server: Optional[asyncio.AbstractServer] = None
        self._clients: set[asyncio.StreamWriter] = set()

        # Method registry — Phase 1 + Phase 2
        self._methods: dict[str, Callable] = {
            # Phase 1
            "list_apps": self._handle_list_apps,
            "get_app": self._handle_get_app,
            "install_app": self._handle_install_app,
            "launch_app": self._handle_launch_app,
            "delete_app": self._handle_delete_app,
            "get_wine_info": self._handle_get_wine_info,
            "get_status": self._handle_get_status,
            # Phase 2
            "search_catalog": self._handle_search_catalog,
            "get_catalog": self._handle_get_catalog,
            "get_install_plan": self._handle_get_install_plan,
            "install_from_catalog": self._handle_install_from_catalog,
            "list_jobs": self._handle_list_jobs,
            "get_job_status": self._handle_get_job_status,
            # Phase 3
            "analyze_logs": self._handle_analyze_logs,
            "apply_fix": self._handle_apply_fix,
            "sync_compat_db": self._handle_sync_compat_db,
            "submit_report": self._handle_submit_report,
            # Phase 4
            "get_vm_status": self._handle_get_vm_status,
            "start_vm": self._handle_start_vm,
            "stop_vm": self._handle_stop_vm,
            "ensure_vm_image": self._handle_ensure_vm_image,
            "update_app": self._handle_update_app,
            # System requirements (Phase 5 / onboarding)
            "get_system_status": self._handle_get_system_status,
            "install_wine": self._handle_install_wine,
        }

    async def start(self) -> None:
        """Start the IPC server."""
        self._server = await asyncio.start_server(
            self._handle_client,
            self.host,
            self.port,
        )
        addrs = ", ".join(str(s.getsockname()) for s in self._server.sockets)
        logger.info(f"IPC server listening on {addrs}")

    async def stop(self) -> None:
        """Stop the IPC server and close all client connections."""
        if self._server:
            self._server.close()
            await self._server.wait_closed()
            logger.info("IPC server stopped")

        for writer in list(self._clients):
            try:
                writer.close()
                await writer.wait_closed()
            except Exception:
                pass
        self._clients.clear()

    async def _handle_client(
        self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter
    ) -> None:
        """Handle a single client connection."""
        peer = writer.get_extra_info("peername")
        logger.info(f"Client connected: {peer}")
        self._clients.add(writer)

        try:
            while True:
                data = await reader.readline()
                if not data:
                    break

                line = data.decode().strip()
                if not line:
                    continue

                response = await self._process_request(line, writer)

                if response is not None:
                    response_json = json.dumps(response) + "\n"
                    writer.write(response_json.encode())
                    await writer.drain()

        except asyncio.CancelledError:
            pass
        except ConnectionResetError:
            logger.info(f"Client disconnected: {peer}")
        except Exception as e:
            logger.error(f"Client handler error: {e}")
        finally:
            self._clients.discard(writer)
            try:
                writer.close()
                await writer.wait_closed()
            except Exception:
                pass
            logger.info(f"Client disconnected: {peer}")

    async def _process_request(self, raw: str, writer: asyncio.StreamWriter) -> Optional[dict]:
        """Parse and dispatch a JSON-RPC request."""
        try:
            request = json.loads(raw)
        except json.JSONDecodeError as e:
            return self._error_response(None, PARSE_ERROR, f"Parse error: {e}")

        if not isinstance(request, dict):
            return self._error_response(None, INVALID_REQUEST, "Request must be an object")

        method = request.get("method")
        params = request.get("params", {})
        req_id = request.get("id")

        if not method or not isinstance(method, str):
            return self._error_response(req_id, INVALID_REQUEST, "Missing 'method' field")

        handler = self._methods.get(method)
        if not handler:
            return self._error_response(
                req_id, METHOD_NOT_FOUND, f"Method '{method}' not found"
            )

        try:
            result = await handler(params, writer)
            return self._success_response(req_id, result)
        except JsonRpcError as e:
            return self._error_response(req_id, e.code, e.message, e.data)
        except Exception as e:
            logger.error(f"Handler error for '{method}': {traceback.format_exc()}")
            return self._error_response(req_id, INTERNAL_ERROR, str(e))

    def _success_response(self, req_id: Any, result: Any) -> dict:
        return {"jsonrpc": "2.0", "result": result, "id": req_id}

    def _error_response(
        self, req_id: Any, code: int, message: str, data: Any = None
    ) -> dict:
        error = {"code": code, "message": message}
        if data is not None:
            error["data"] = data
        return {"jsonrpc": "2.0", "error": error, "id": req_id}

    # ─── Helper: Progress Reporter ───────────────────────────────────

    def _make_reporter(self, writer: asyncio.StreamWriter):
        """Create a progress reporter that sends notifications to a client."""
        async def reporter(stage: str, message: str):
            notification = json.dumps({
                "jsonrpc": "2.0",
                "method": "progress",
                "params": {"stage": stage, "message": message},
            }) + "\n"
            try:
                writer.write(notification.encode())
                await writer.drain()
            except Exception:
                pass
        return reporter

    # ─── Phase 1 Method Handlers ─────────────────────────────────────

    async def _handle_list_apps(self, params: dict, writer) -> list:
        """List all installed apps."""
        return await installer.list_apps()

    async def _handle_get_app(self, params: dict, writer) -> dict:
        """Get details of a specific app."""
        app_id = params.get("app_id")
        if not app_id:
            raise JsonRpcError(INVALID_PARAMS, "Missing required param: 'app_id'")

        app = await installer.get_app(app_id)
        if not app:
            raise JsonRpcError(INVALID_PARAMS, f"App '{app_id}' not found")
        return app

    async def _handle_install_app(self, params: dict, writer) -> dict:
        """Install a new Windows application (generic or auto-script)."""
        display_name = params.get("display_name")
        exe_path = params.get("exe_path")

        if not display_name:
            raise JsonRpcError(INVALID_PARAMS, "Missing required param: 'display_name'")
        if not exe_path:
            raise JsonRpcError(INVALID_PARAMS, "Missing required param: 'exe_path'")

        architecture = params.get("architecture", "win64")
        wine_version = params.get("wine_version", "stable")

        reporter = self._make_reporter(writer)

        try:
            result = await installer.install_app(
                display_name=display_name,
                exe_path=exe_path,
                architecture=architecture,
                wine_version=wine_version,
                reporter=reporter,
                execution_engine=params.get("execution_engine", "wine"),
            )
            return result
        except FileNotFoundError as e:
            raise JsonRpcError(INVALID_PARAMS, str(e))
        except RuntimeError as e:
            raise JsonRpcError(INTERNAL_ERROR, str(e))

    async def _handle_launch_app(self, params: dict, writer) -> dict:
        """Launch an installed app."""
        app_id = params.get("app_id")
        if not app_id:
            raise JsonRpcError(INVALID_PARAMS, "Missing required param: 'app_id'")

        reporter = self._make_reporter(writer)

        try:
            return await installer.launch_app(app_id, reporter=reporter)
        except RuntimeError as e:
            raise JsonRpcError(INVALID_PARAMS, str(e))

    async def _handle_delete_app(self, params: dict, writer) -> dict:
        """Uninstall an app and delete its prefix."""
        app_id = params.get("app_id")
        if not app_id:
            raise JsonRpcError(INVALID_PARAMS, "Missing required param: 'app_id'")

        reporter = self._make_reporter(writer)
        success = await installer.uninstall_app(app_id, reporter=reporter)
        return {"success": success, "app_id": app_id}

    async def _handle_get_wine_info(self, params: dict, writer) -> dict:
        """Get Wine version info."""
        info = wine_manager.get_wine_info()
        if info:
            return info.to_dict()
        return {"version": "not detected", "path": None, "arch": None}

    async def _handle_get_status(self, params: dict, writer) -> dict:
        """Get daemon status."""
        apps = await installer.list_apps()
        wine_info = wine_manager.get_wine_info()
        return {
            "status": "running",
            "app_count": len(apps),
            "wine_detected": wine_info is not None,
            "wine_version": wine_info.version if wine_info else None,
            "catalog_count": catalog_manager.count,
            "active_jobs": job_queue.active_count,
        }

    # ─── Phase 2 Method Handlers ─────────────────────────────────────

    async def _handle_search_catalog(self, params: dict, writer) -> list:
        """Search app catalog by query string."""
        query = params.get("query", "")
        return catalog_manager.search(query)

    async def _handle_get_catalog(self, params: dict, writer) -> dict:
        """Get full catalog or filter by category/status."""
        category = params.get("category")
        status = params.get("status")

        if category:
            entries = catalog_manager.filter_by_category(category)
        elif status:
            entries = catalog_manager.filter_by_status(status)
        else:
            entries = catalog_manager.get_all()

        return {
            "entries": entries,
            "categories": catalog_manager.list_categories(),
            "total": len(entries),
        }

    async def _handle_get_install_plan(self, params: dict, writer) -> dict:
        """Preview what will be installed for a catalog app."""
        app_id = params.get("app_id")
        if not app_id:
            raise JsonRpcError(INVALID_PARAMS, "Missing required param: 'app_id'")

        plan = await installer.get_install_plan(app_id)
        if not plan:
            raise JsonRpcError(
                INVALID_PARAMS,
                f"No install script found for '{app_id}'",
            )
        return plan

    async def _handle_install_from_catalog(self, params: dict, writer) -> dict:
        """Install an app from the catalog using its YAML script."""
        app_id = params.get("app_id")
        exe_path = params.get("exe_path")

        if not app_id:
            raise JsonRpcError(INVALID_PARAMS, "Missing required param: 'app_id'")
        if not exe_path:
            raise JsonRpcError(INVALID_PARAMS, "Missing required param: 'exe_path'")

        reporter = self._make_reporter(writer)

        try:
            result = await installer.install_from_script(
                app_id=app_id,
                exe_path=exe_path,
                reporter=reporter,
            )
            return result
        except FileNotFoundError as e:
            raise JsonRpcError(INVALID_PARAMS, str(e))
        except RuntimeError as e:
            raise JsonRpcError(INTERNAL_ERROR, str(e))

    async def _handle_list_jobs(self, params: dict, writer) -> list:
        """List all background jobs."""
        include_completed = params.get("include_completed", True)
        return job_queue.list_jobs(include_completed=include_completed)

    async def _handle_get_job_status(self, params: dict, writer) -> dict:
        """Get status of a specific background job."""
        job_id = params.get("job_id")
        if not job_id:
            raise JsonRpcError(INVALID_PARAMS, "Missing required param: 'job_id'")

        job = job_queue.get_job(job_id)
        if not job:
            raise JsonRpcError(INVALID_PARAMS, f"Job '{job_id}' not found")
        return job

    # ─── Phase 3 Method Handlers ─────────────────────────────────────

    async def _handle_analyze_logs(self, params: dict, writer) -> list:
        """Analyze logs for an app and return fix suggestions."""
        app_id = params.get("app_id")
        if not app_id:
            raise JsonRpcError(INVALID_PARAMS, "Missing required param: 'app_id'")
        
        return log_analyzer.analyze_log(app_id)

    async def _handle_apply_fix(self, params: dict, writer) -> dict:
        """Apply a suggested fix to an app prefix."""
        app_id = params.get("app_id")
        fix_action = params.get("fix_action")
        
        if not app_id:
            raise JsonRpcError(INVALID_PARAMS, "Missing required param: 'app_id'")
        if not fix_action:
            raise JsonRpcError(INVALID_PARAMS, "Missing required param: 'fix_action'")

        reporter = self._make_reporter(writer)
        
        try:
            success = await fix_engine.apply_fix(app_id, fix_action, reporter)
            return {"success": success}
        except Exception as e:
            raise JsonRpcError(INTERNAL_ERROR, str(e))

    async def _handle_sync_compat_db(self, params: dict, writer) -> dict:
        """Sync compatibility database."""
        success = await catalog_manager.sync_compat_db()
        return {"success": success}

    async def _handle_submit_report(self, params: dict, writer) -> dict:
        """Submit a user report."""
        app_id = params.get("app_id")
        status = params.get("status")
        description = params.get("description", "")
        
        if not app_id or not status:
            raise JsonRpcError(INVALID_PARAMS, "Missing required param: 'app_id' or 'status'")
            
        success = await catalog_manager.submit_report(app_id, status, description)
        return {"success": success}

    # ─── Phase 4 Method Handlers ─────────────────────────────────────

    async def _handle_get_vm_status(self, params: dict, writer) -> dict:
        """Get status of the Micro-VM engine."""
        return vm_manager.get_status()

    async def _handle_start_vm(self, params: dict, writer) -> dict:
        """Manually start the Micro-VM."""
        success = await vm_manager.start_vm()
        return {"success": success}

    async def _handle_stop_vm(self, params: dict, writer) -> dict:
        """Manually suspend/stop the Micro-VM."""
        success = await vm_manager.stop_vm()
        return {"success": success}

    async def _handle_ensure_vm_image(self, params: dict, writer) -> dict:
        """Start background download/verify of the VM base image."""
        reporter = self._make_reporter(writer)
        success = await vm_manager.ensure_vm_image(reporter)
        return {"success": success}

    async def _handle_update_app(self, params: dict, writer) -> dict:
        """Update an existing app's configuration."""
        app_id = params.get("app_id")
        updates = params.get("updates")
        if not app_id or not updates:
            raise JsonRpcError(INVALID_PARAMS, "Missing required param: 'app_id' or 'updates'")

        try:
            return await installer.update_app(app_id, updates)
        except ValueError as e:
            raise JsonRpcError(INVALID_PARAMS, str(e))

    async def _handle_get_system_status(self, params: dict, writer) -> dict:
        """Return system requirements status (Wine, winetricks, distro)."""
        return system_requirements.get_status()

    async def _handle_install_wine(self, params: dict, writer) -> dict:
        """Trigger automatic Wine installation via pkexec."""
        reporter = self._make_reporter(writer)
        success = await system_requirements.install_wine(reporter)
        return {"success": success}
