import json
from threading import Lock
from urllib.request import urlopen
from typing import TypedDict, Optional, Any

JSONRPC_REQUEST_ID = 1
JSONRPC_REQUEST_LOCK = Lock()

def _next_request_id():
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


def jsonrpc(url:str, method:str, params:Optional[list[Any]]=None):
    input = json.dumps({
        "jsonrpc": "2.0",
        "method": method,
        "params": params or [],
        "id": _next_request_id()
    }).encode()
    with urlopen(url, data=input) as handle:
        output: jsonrpc_Response = json.load(handle)
    if output.get('error', None) is not None:
        raise jsonrpc_Error(output['error'])
    assert 'result' in output
    return output['result']
