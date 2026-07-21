import "../css/Navbar.css"
import {Link} from "react-router-dom"

function Navbar() {
    return <nav className="navbar">
        <div className="navbar-brand">
            <Link to="/">Resume Optimizer</Link>
        </div>
        <ul>
            <li><Link to="/dashboard">Dashboard</Link></li>
            <li><Link href="/">Sign Out</Link></li>
        </ul>
    </nav>
}

export default Navbar