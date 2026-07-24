import React from 'react';
import { Navigate, Outlet } from 'react-router-dom'
import { useAuthContext } from '../context/AuthContext.jsx'

const ProtectedRoute = () => {
  const cognito_url = import.meta.env.VITE_COGNITO_URL
  const { validateToken } = useAuthContext()
  const isAuthenticated = validateToken()
  return isAuthenticated ? <Outlet /> : <Navigate to={cognito_url} replace />
};

export default ProtectedRoute