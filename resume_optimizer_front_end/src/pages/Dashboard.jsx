import '../css/Dashboard.css'
import { useAuthContext } from '../contexts/AuthContext'

function Dashboard() {
    const {userIdentity} = useAuthContext();
    return <div className="dashboard-content">
        <h1 className="greeting"> Hello <span className="user-tag">User#{userIdentity}</span>! </h1>
        <ul class="user_actions">
            <li> <a href="./chats"> {">>"}View Conversations </a> </li>
            <li> <a href="./resumes"> {">>"}View Resumes </a> </li>
            <li> <a href="./listings"> {">>"}View Listings </a> </li>
        </ul>
    </div>
}

export default Dashboard