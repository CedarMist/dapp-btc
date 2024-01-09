# SPDX-License-Identifier: Apache-2.0

import json
from threading import Lock
from urllib.request import urlopen
from typing import TypedDict, Optional, Any

from ..constants import LOGGER

JSONRPC_REQUEST_ID: int = 1
JSONRPC_REQUEST_LOCK = Lock()

def _next_request_id() -> int:
    global JSONRPC_REQUEST_ID
    with JSONRPC_REQUEST_LOCK:
        rid = JSONRPC_REQUEST_ID
        JSONRPC_REQUEST_ID += 1
        return rid


class jsonrpc_Error(RuntimeError):
    pass


class jsonrpc_Response(TypedDict):
    result: Optional[Any]
    error: Optional[Any]
    id: int


def jsonrpc(url:str, method:str, params:Optional[list[Any]]=None) -> Any:
    request = {
        "jsonrpc": "2.0",
        "method": method,
        "params": params or [],
        "id": _next_request_id()
    }
    input = json.dumps(request).encode()
    LOGGER.debug(f"JSON-RPC {url} id={request['id']} {method} params:{params}")
    with urlopen(url, data=input) as handle:
        output: jsonrpc_Response = json.load(handle)
    if output.get('error', None) is not None:
        raise jsonrpc_Error(output['error'])
    assert 'result' in output
    return output['result']
