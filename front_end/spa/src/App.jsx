import { Routes, Route } from 'react-router-dom'
import Layout from './components/Layout.jsx'
import ProtectedRoute from './components/ProtectedRoute.jsx'
import Home from './pages/Home.jsx'
import Dashboard from './pages/Dashboard.jsx'
import Resumes from './pages/Resumes.jsx'
import Listings from './pages/Listings.jsx'
import Chats from './pages/Chats.jsx'
import ErrorPage from './pages/Error.jsx'

/**
 * Route map for the SPA. Each authenticated route is wrapped in
 * <ProtectedRoute> which redirects unauthenticated visitors to "/".
 *
 * The Auth0-style "/callback" path is reserved for the Cognito code
 * exchange (handled by the parse_auth Lambda@Edge) — it returns 403 from
 * S3 directly without ever reaching React. Do not add a route here.
 */
export default function App() {
    return (
        <Routes>
            <Route element={<Layout />}>
                <Route path="/" element={<Home />} />
                <Route path="/error" element={<ErrorPage />} />
                <Route path="/dashboard" element={
                    <ProtectedRoute><Dashboard /></ProtectedRoute>
                } />
                <Route path="/resumes" element={
                    <ProtectedRoute><Resumes /></ProtectedRoute>
                } />
                <Route path="/listings" element={
                    <ProtectedRoute><Listings /></ProtectedRoute>
                } />
                <Route path="/chats" element={
                    <ProtectedRoute><Chats /></ProtectedRoute>
                } />
                <Route path="*" element={<ErrorPage code={404} />} />
            </Route>
        </Routes>
    )
}
