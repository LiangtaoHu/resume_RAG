import './css/App.css'
import Home from './pages/Home'
import Chats from './pages/Chats'
import Dashboard from './pages/Dashboard'
import Error from './pages/Error'
import Listings from './pages/Listings'
import Resumes from './pages/Resumes'
import Navbar from './components/Navbar'
import GitFooter from './components/GitFooter'

function App() {
  return (
    <>
      <Navbar/>
      <main className="main-content">
        <Routes>
          <Route path="/" element={<Home/>}/>
          <Route path="/chats" element={<Chats/>}/>
          <Route path="/dashboard" element={<Dashboard/>}/>
          <Route path="/error" element={<Error/>}/>
          <Route path="/listings" element={<Listings/>}/>
          <Route path="/resumes" element={<Resumes/>}/>
        </Routes>
      </main>
      <GitFooter/>
    </>
  )
}

export default App
