import '../css/Dashboard.css'
import { useAuthContext } from '../contexts/AuthContext'
import {Link} from "react-router-dom"

function Dashboard() {
    const {userIdentity} = useAuthContext();
    return <div className="dashboard-content">
        <h1 className="greeting"> Hello <span className="user-tag">User#{userIdentity}</span>! </h1>
        <ul class="user_actions">
            <li> <Link href="/chats"> {">>"}View Conversations </Link> </li>
            <li> <Link href="/resumes"> {">>"}View Resumes </Link> </li>
            <li> <Link href="/listings"> {">>"}View Listings </Link> </li>
        </ul>
    </div>
}

export default Dashboard