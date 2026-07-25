import React, { createContext, useContext, useState, useEffect } from 'react';
import { jwtDecode } from 'jwt-decode';

export const AuthContext = createContext()

export const useAuthContext = () => {
    return useContext(AuthContext)
}

export const AuthProvider = ({ children }) => {
  const [token, setToken] = useState(null)
  const [userIdentity, setUserIdentity] = useState(null)

  const logout = () => {
    localStorage.removeItem('auth_token')
    localStorage.removeItem('userIdentity')
    setToken(null)
    setUserIdentity(null)
  }

  const login = (newToken) => {
    try {
        const decoded = jwtDecode(newToken)
        const currentTime = Math.floor(Date.now()/1000)
        if (decoded.exp < currentTime) {
            logout()
        } else {
            setToken(newToken)
            setUserIdentity(decoded.sub)
            localStorage.setItem('auth_token', newToken)
            localStorage.setItem('userIdentity', decoded.sub)
        }
    } catch {
        logout()
    }
  }

  const validateToken = () => {
    if (!token) {
        return false
    }
    try {
        const decoded = jwtDecode(token)
        const currentTime = Math.floor(Date.now()/1000)
        if (decoded.exp < currentTime) {
            logout()
            return false
        } else {
            return true
        }
    } catch {
        logout()
        return false
    }
  }

  return (
    <AuthContext.Provider value={{login, logout, userIdentity, token, validateToken}}>
        {children}
    </AuthContext.Provider>
  )
};
