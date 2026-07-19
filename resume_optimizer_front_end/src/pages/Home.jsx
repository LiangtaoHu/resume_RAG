import '../css/Home.css'

function Home() {
    const cognito_url = import.meta.env.VITE_COGNITO_URL
    return <div className="home-content">
        <h2>A web service where you can upload and customize your resumes to specific job listings. </h2>
        <h3> Backed with a serverless cloud architecture. </h3>
        <a className="register_button" href={cognito_url}>Sign up/Log in</a>
    </div>
}

export default Home