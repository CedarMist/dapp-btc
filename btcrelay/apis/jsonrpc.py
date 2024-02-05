# SPDX-License-Identifier: Apache-2.0

import json
import urllib.request
from threading import Lock
from typing import TypedDict, Optional, Any

from ..constants import LOGGER

URLOPEN_DEBUGLEVEL=1

JSONRPC_REQUEST_ID: int = 1
JSONRPC_REQUEST_LOCK = Lock()

URL_AUTH_T = tuple[str,str]
URL_T = str | tuple[str,URL_AUTH_T]


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


def jsonrpc(url:URL_T, method:str, params:Optional[list[Any]]=None) -> Any:
    request = {
        "jsonrpc": "2.0",
        "method": method,
        "params": params or [],
        "id": _next_request_id()
    }
    input = json.dumps(request).encode()

    # Don't reveal JSON-RPC auth in debug messages
    friendly_url = url[0] if isinstance(url, (list,tuple)) else url

    LOGGER.debug(f"JSON-RPC {friendly_url} id={request['id']} {method} params:{params}")

    handlers = []
    if isinstance(url, (list,tuple)):
        url, (auth_user, auth_passwd) = url
        passman = urllib.request.HTTPPasswordMgrWithDefaultRealm()
        passman.add_password(None, url, auth_user, auth_passwd)
        handlers.append(urllib.request.HTTPBasicAuthHandler(passman))

    handlers.append(urllib.request.HTTPSHandler(debuglevel=URLOPEN_DEBUGLEVEL))
    opener = urllib.request.build_opener(*handlers)
    opener.addheaders = [('Content-Type', 'application/json')]

    # Return BTC RPC errors verbatim
    error = None
    try:
        with opener.open(url, data=input) as handle:
            output: jsonrpc_Response = json.load(handle)
    except urllib.error.HTTPError as ex:
        error = json.loads(ex.read())

    if error is not None:
        raise jsonrpc_Error(error)

    if output.get('error', None) is not None:
        raise jsonrpc_Error(output)

    assert 'result' in output
    return output['result']
