import base64
import json
import urllib.request
import urllib.parse
import config
from jwt.exceptions import InvalidSignatureError, ExpiredSignatureError

def unpack_state(state):
    # TODO: Should add error checking if somebody wants to manually add in a state for whatever reason
    # State should be already a base64 string. 
    # We just need to encode it into utf8, reconvert it with base64, then decode with utf8, then load it with json.
    decoded_state_string = base64.urlsafe_b64decode(state.encode("utf-8")).decode("utf-8")
    return json.loads(decoded_state_string)

def auth_code_exchange(auth_code, domain_name):
    token_url = f"{config.COGNITO_DOMAIN}/oauth2/token"
    payload = {
        "grant_type": "authorization_code",
        "client_id": config.CLIENT_ID,
        "code": auth_code,
        "redirect_uri": f"https://{domain_name}/callback"
    }
    encoded_data = urllib.parse.urlencode(payload).encode("utf-8")
    headers = {
        # No authorization header?
        "Content-Type": "application/x-www-form-urlencoded"
    }
    req = urllib.request.Request(token_url, data=encoded_data, headers=headers, method="POST")
    # TODO: Should add try, except block in order to catch potential timeouts? or wrong authcode
    with urllib.request.urlopen(req) as response:
        tokens = json.loads(response.read().decode('utf-8'))
        return tokens["id_token"], tokens["expires_in"], tokens["refresh_token"]

def lambda_handler(event, context):
    # Auth code in query string
    # State paramters and nonce in query string
    # Nonce in cookies as well
    request = event['Records'][0]['cf']['request']
    headers = request.get("headers", {})
    domain_name = headers["host"][0]["value"]
    cookies = {}
    if "cookie" in headers:
        # Loop through all the cookies
        for cookie in headers["cookie"]:
            # We are mainly interested in the value as the key for each is just "cookie"
            # The value can be multi-cookie per actual cookie, with a separator of ";"
            cookie_string = cookie.get("value", "")
            for cookie_instance in cookie_string.split(";"):
                # We split again on the equals sign
                key, value = cookie_instance.split("=", 1)
                cookies[key.strip()] = value.strip()
    cookie_nonce = cookies.get("spa-auth-edge-nonce")

    auth_code = ""
    state = {}
    original_uri = ""
    query_string = request.get("querystring", "")
    try:
        # Check if nonces match
        for parameter_pair in query_string.split("&"):
            key, value = parameter_pair.split("=", 1)
            if key == "state":
                state = unpack_state(value)
                nonce = state.get("spa-auth-edge-nonce")
                original_uri = state.get("requestedUri", "/")
                if cookie_nonce != nonce:
                    raise InvalidSignatureError("Mismatching Nonce")
            if key == "code":
                auth_code = value
        # Check if we do have an accessToken
        if not auth_code:
            raise ExpiredSignatureError("No access token given.")
        idToken, expires_in, refreshToken = auth_code_exchange(auth_code)

        return_pathway = f"https://{domain_name}/dashboard"
        # # If we are in any pathway that the actual browser should call which is /api/v1/*, we should return to their respective landing pages
        # if "/api/v1" in original_uri:
        #     original_uri = original_uri.split("/api/v1", 1)[1]
        #     return_pathway = return_pathway + original_uri

        return {
            "status": "302",
            "statusDescription": "found",
            "headers": {
                "location": [{
                    "key": "Location",
                    "value": return_pathway
                }],
                "set-cookie": [
                    {
                        "key": "Set-Cookie",
                        "value": f"idToken={idToken}; Max-Age={expires_in} Secure; HttpOnly; SameSite=Lax; Path=/"
                    },
                    {
                        "key": "Set-Cookie",
                        "value": f"refreshToken={refreshToken}; Max-Age={config.REFRESH_EXPIRES_IN} Secure; HttpOnly; SameSite=Lax; Path=/"
                    },
                    # Clear out the tracking nonce cookie since its mission is complete
                    {
                        "key": "Set-Cookie",
                        "value": "spa-auth-edge-nonce=deleted; Max-Age=0; Secure; HttpOnly; SameSite=Lax; Path=/"
                    }]
            }
        }
    except Exception as e:
            error_reason = "internal_error"
            if isinstance(e, InvalidSignatureError):
                error_reason = "tampered_nonce"
            elif isinstance(e, ExpiredSignatureError):
                error_reason = "missing_access_code"
            
            return {
                "status": "302",
                "statusDescription": "Found",
                "headers": {
                    "location": [{
                        "key": "Location",
                        "value": f"/index.html?error=auth_failed&reason={error_reason}"
                    }]
                }
            }