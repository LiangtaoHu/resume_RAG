import { useState, useEffect } from 'react'
import { useAuthContext } from '../contexts/AuthContext'

function Callback() {
    const {login} = useAuthContext();
    const [text, setText] = useState('Please Wait.')
    const [status, setStatus] = useState("")

    useEffect(() => {
        async function fetchData() {
            try {
                const queryParams = new URLSearchParams(window.location.search)
                const state = queryParams.get('state')
                const auth_code = queryParams.get('auth_code')

                payload = {
                    "grant_type": "authorization_code",
                    "client_id": import.meta.env.CLIENT_ID,
                    "code": auth_code,
                    "redirect_uri": `https://${import.meta.env.COGNITO_DOMAIN_URL}/callback`
                }
                const encodedData = new URLSearchParams(payload)

                const response = fetch(`https://${import.meta.env.COGNITO_DOMAIN_URL}/oauth2/token`, {
                    method: "POST",
                    headers: {
                        "Content-Type": "application/x-www-form-urlencoded"
                    },
                    body: encodedData
                })

                if (!response.ok) {
                    throw new Error(`HTTP error! status: ${response.status}`);
                }
                const response_json = (await response).json()

                const accessToken = response_json["access_token"]
                login(accessToken)

            } catch (err) {
                setStatus(err)
            } finally {
                setText("Properly Validated. You may now go to the dashboard.")
            }
        }
        fetchData();
    }, [])
    return <div className="callback-content">{text}</div>
}

export default Callback