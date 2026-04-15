"""
Unit tests for the IPC Server module.
"""

import asyncio
import json
from pathlib import Path
from unittest.mock import patch, AsyncMock, MagicMock

import pytest

import sys
sys.path.insert(0, str(Path(__file__).parent.parent))


class TestJsonRpc:
    """Tests for JSON-RPC protocol handling."""

    def test_success_response_format(self):
        """Success responses should follow JSON-RPC 2.0 spec."""
        from daemon.core.ipc_server import IPCServer

        server = IPCServer()
        response = server._success_response(1, {"status": "ok"})

        assert response["jsonrpc"] == "2.0"
        assert response["id"] == 1
        assert response["result"] == {"status": "ok"}
        assert "error" not in response

    def test_error_response_format(self):
        """Error responses should follow JSON-RPC 2.0 spec."""
        from daemon.core.ipc_server import IPCServer

        server = IPCServer()
        response = server._error_response(2, -32600, "Invalid Request")

        assert response["jsonrpc"] == "2.0"
        assert response["id"] == 2
        assert response["error"]["code"] == -32600
        assert response["error"]["message"] == "Invalid Request"
        assert "result" not in response

    def test_method_registry(self):
        """Server should register all expected methods."""
        from daemon.core.ipc_server import IPCServer

        server = IPCServer()
        expected_methods = [
            "list_apps",
            "get_app",
            "install_app",
            "launch_app",
            "delete_app",
            "get_wine_info",
            "get_status",
        ]

        for method in expected_methods:
            assert method in server._methods, f"Method '{method}' not registered"

    def test_json_rpc_error_codes(self):
        """Standard JSON-RPC error codes should be defined."""
        from daemon.core.ipc_server import (
            PARSE_ERROR,
            INVALID_REQUEST,
            METHOD_NOT_FOUND,
            INVALID_PARAMS,
            INTERNAL_ERROR,
        )

        assert PARSE_ERROR == -32700
        assert INVALID_REQUEST == -32600
        assert METHOD_NOT_FOUND == -32601
        assert INVALID_PARAMS == -32602
        assert INTERNAL_ERROR == -32603


class TestJsonRpcError:
    """Tests for the JsonRpcError exception class."""

    def test_error_creation(self):
        """JsonRpcError should store code, message, and optional data."""
        from daemon.core.ipc_server import JsonRpcError

        error = JsonRpcError(-32600, "Invalid Request", {"field": "method"})
        assert error.code == -32600
        assert error.message == "Invalid Request"
        assert error.data == {"field": "method"}

    def test_error_to_dict(self):
        """to_dict should produce a proper JSON-RPC error object."""
        from daemon.core.ipc_server import JsonRpcError

        error = JsonRpcError(-32601, "Method not found")
        error_dict = error.to_dict()

        assert error_dict["code"] == -32601
        assert error_dict["message"] == "Method not found"
        assert "data" not in error_dict
