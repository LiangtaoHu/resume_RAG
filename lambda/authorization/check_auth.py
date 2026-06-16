import jwt
import secrets
import json
import base64
import urllib
import config
from jwt.exceptions import ExpiredSignatureError
'''
This describes a Lambda@Edge function that checks the users request before allowing them to access Lambda origins.
How this works is the user will have cookies which will have information that describe if they're logged in or not.
If they're properly logged in, we will let through the request. If they aren't we redirect them to the Cognito Hosted UI.
'''
def validate_id_token(idToken):


def refresh_tokens(refresh_token, domain_name):
    token_url = f"{config.COGNITO_DOMAIN}/oauth2/token"
    payload = {
        "grant_type": "authorization_code",
        "client_id": config.CLIENT_ID,
        "refresh_token": refresh_token,
    }
    encoded_data = urllib.parse.urlencode(payload).encode("utf-8")
    headers = {
        # No authorization header?
        "Content-Type": "application/x-www-form-urlencoded"
    }
    req = urllib.request.Request(token_url, data=encoded_data, headers=headers, method="POST")
    # TODO: Should add try, except block in order to catch potential timeouts? or wrong refreshToken
    with urllib.request.urlopen(req) as response:
        tokens = json.loads(response.read().decode('utf-8'))
        idToken = tokens["id_token"]
        expires_in = tokens["expires_in"]
        refreshToken = tokens["refresh_token"] # TODO: Turn on refresh token rotation
        return_pathway = f"https://{domain_name}"
        # If we are in any pathway that the actual browser should call which is /api/v1/*, we should return to their respective landing pages
        if "/api/v1" in original_uri:
            original_uri = original_uri.split("/api/v1", 1)[1]
            return_pathway = return_pathway + original_uri

        return {
            "status": "307",
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

def build_cognito_url(requested_uri, domain_name):
    # Create the state via requested_uri and nonce, one of which is also the cookie?
    # Send to the cognito hosted UI url
    # Return nonce (Cookie), redirect_url (includes query?)
    nonce = secrets.token_urlsafe(16)
    state = {
        "spa-auth-edge-nonce": nonce,
        "requested_uri": requested_uri
    }
    url_state = base64.urlsafe_b64encode(json.dumps(state).encode('utf-8')).decode('utf-8')
    query_parameters = {
        "response_type": "code",
        "client_id": config.CLIENT_ID,
        "redirect_uri": f"https://{domain_name}/callback",
        "state": url_state,
        "scope": "openid email"
    }
    encoded_params = urllib.parse.urlencode(query_parameters)
    cognito_hosted_url = f"{config.COGNITO_DOMAIN}/login?{encoded_params}"
    return nonce, cognito_hosted_url


def lambda_handler(event, context):
    '''
    So this would be a viewer request that we're sniping.
    If the user isn't logged in, we redirect them to Cognito for authentication. Cloudfront sets a state and nonce
    After they authenticate themselves, Cognito sends them to /callback with a auth code query string and state parameter.
        - The second lambda function parse_auth works there. It gets the auth code and state parameter and compares the nonce in the state parameter with the one in the cookies to see if they're equal
        - Use the Cognito token API to trade auth code for JWTs, set into cookies
        - Using the state parameter redirect to the URL we were trying to access
    
    After authentication,
        - User goes to page, check_auth looks at cookies and JWT within them. 
        - Check_auth will use the JWKs in the user pool to validate the JWTs
    '''
    # First, we need to check the cookies
    request = event['Records'][0]['cf']['request']
    headers = request.get("headers", {})
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
    # Now we retrieve the idToken and the refreshToken
    idToken = cookies.get("idToken")
    refreshToken = cookies.get("refreshToken")

    # Create the request url and save in state parameter
    domain_name = headers["host"][0]["value"]
    requested_uri = request.get("uri", "/")
    query_string = request.get("querystring", "")
    if query_string:
        requested_uri += f"?{query_string}"

    try:
        if not idToken:
            raise ExpiredSignatureError("No ID token prescribed")
        validate_id_token(idToken)
        return request
    except Exception as e:
        redirect_url = ""
        if isinstance(e, ExpiredSignatureError) and refreshToken:
            refresh_tokens(refreshToken)
        else:
            # Either tampered with or there is just no information, redirect to Hosted UI to sign in or create an account
            redirect_url, nonce = build_cognito_url(requested_uri, domain_name)
        return {
            "status": 307,
            "statusDescription": "found",
            "headers": {
                "location": [{
                    "key": "Location",
                    "value": redirect_url
                }],
                "set-cookie": [{
                    "key": "Set-Cookie",
                    "value": f"spa-auth-edge-nonce={nonce}; Secure; HttpOnly"
                }]
            }
        }
