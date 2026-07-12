import { Outlet } from 'react-router-dom'
import Header from './Header'
import Footer from './Footer'

/**
 * Top-level page chrome: header + outlet + footer. Mirrors the HTML shell
 * pattern that existed across all of the old static pages.
 */
export default function Layout() {
    return (
        <>
            <Header />
            <Outlet />
            <Footer />
        </>
    )
}
