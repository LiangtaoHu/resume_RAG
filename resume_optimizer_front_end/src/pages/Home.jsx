import '../css/Home.css'
import {Link} from "react-router-dom"

function Home() {
    const cognito_url = import.meta.env.VITE_COGNITO_URL
    return <div className="home-content">
        <h2>A web service where you can upload and customize your resumes to specific job listings. </h2>
        <h3> Backed with a serverless cloud architecture. </h3>
        <Link className="register_button" href={cognito_url}>Sign up/Log in</Link>
    </div>
}

export default Home