import '../css/Listings.css'
import { useState, useEffect } from 'react'
import Table from './components/Table'
import { useAuthContext } from '../contexts/AuthContext'

function Listings() {
    const {userIdentity} = useAuthContext();
    const [listings, setListings] = useState([])
    const [activeListing, setActiveListing] = useState(null)
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        async function fetchListings() {
            if (!userIdentity) return; 
            //TODO
        }
        fetchListings()
    }, [userIdentity])

    if (loading) {
        return <div className="listing-loading">Loading Your Listings</div>
    }

    return <div className="listing-content">
        <h2>Your Listings</h2>
        <Table content={listings} setListings={setListings}/>
    </div>
}

export default Listings