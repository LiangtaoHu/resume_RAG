import { createContext, useContext, useState, useEffect } from 'react'

const AuthContext = createContext(null)

const TOKEN_KEY = 'idToken'

/**
 * Holds the Cognito idToken in React state, mirroring it to sessionStorage so
 * hard refreshes keep the user signed in (within the tab session) and so page
 * navigation between /chats /resumes /listings preserves the token.
 */
export function AuthProvider({ children }) {
    const [idToken, setIdTokenState] = useState(() => sessionStorage.getItem(TOKEN_KEY) || null)

    const setIdToken = (token) => {
        if (token) {
            sessionStorage.setItem(TOKEN_KEY, token)
        } else {
            sessionStorage.removeItem(TOKEN_KEY)
        }
        setIdTokenState(token)
    }

    const clearIdToken = () => setIdToken(null)

    return (
        <AuthContext.Provider value={{ idToken, setIdToken, clearIdToken }}>
            {children}
        </AuthContext.Provider>
    )
}

export function useAuth() {
    const ctx = useContext(AuthContext)
    if (!ctx) throw new Error('useAuth must be used inside <AuthProvider>')
    return ctx
}
