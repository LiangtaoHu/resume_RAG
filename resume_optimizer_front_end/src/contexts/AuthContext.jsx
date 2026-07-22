import {createContext, useState, useContext } from 'react'
import { jwtDecode } from 'jwt-decode';

const AuthContext = createContext()

export function useAuthContext() {
    return useContext(AuthContext)
} 

export function AuthProvider({children}) {

    function initAuth() {
        const token = localStorage.getItem("cognito_id_token")
        const storedIdentity = localStorage.getItem("userIdentity")

        if (!token || !storedIdentity) {
            localStorage.removeItem("cognito_id_token")
            localStorage.removeItem("userIdentity")
            return {token: null, userIdentity: null}
        }
    }


    return <AuthContext.Provider value={userIdentity}>
        {children}
    </AuthContext.Provider>
}