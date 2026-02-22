import { useState, useEffect } from 'react';

const AdminDashboard = () => {
    const [users, setUsers] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);

    useEffect(() => {
        const fetchUsers = async () => {
            try {
                const response = await fetch('http://localhost:3000/admin/users');
                const data = await response.json();
                if (data.success) {
                    setUsers(data.users);
                } else {
                    setError(data.message);
                }
            } catch (err) {
                setError(err.message);
            } finally {
                setLoading(false);
            }
        };

        fetchUsers();

        // Poll every 5 seconds for live updates
        const interval = setInterval(fetchUsers, 5000);
        return () => clearInterval(interval);
    }, []);

    const getRiskColor = (riskLevel) => {
        switch (riskLevel?.toLowerCase()) {
            case 'low': return '#10b981'; // green
            case 'medium': return '#f59e0b'; // orange
            case 'high': return '#ef4444'; // red
            default: return '#6b7280'; // gray
        }
    };

    if (loading) return <div className="loading">Loading Admin Dashboard...</div>;
    if (error) return <div className="error">Error: {error}</div>;

    return (
        <div className="admin-container">
            <header className="admin-header">
                <h1>AtlasWatch Admin Dashboard</h1>
                <p>Live User Locations and Active Journeys</p>
            </header>

            <div className="users-grid">
                {users.length === 0 ? (
                    <p className="no-users">No users found.</p>
                ) : (
                    users.map((user) => (
                        <div className="user-card" key={user.email}>
                            <div className="user-card-header">
                                <h2>{user.email}</h2>
                                {user.profileComplete && <span className="badge profile-badge">Profile Completed</span>}
                            </div>

                            <div className="user-details">
                                {/* Location Section */}
                                <div className="section">
                                    <h3>📍 Latest Location</h3>
                                    {user.lastLocation ? (
                                        <>
                                            <div className="location-info">
                                                <p><strong>Lat/Lng:</strong> {user.lastLocation.lat.toFixed(4)}, {user.lastLocation.lng.toFixed(4)}</p>
                                                <p><strong>Time:</strong> {new Date(user.lastLocation.timestamp).toLocaleString()}</p>
                                            </div>
                                            <div className="risk-indicator" style={{ backgroundColor: getRiskColor(user.lastLocation.riskLevel) }}>
                                                Risk: {user.lastLocation.riskLevel?.toUpperCase() || 'UNKNOWN'}
                                            </div>
                                        </>
                                    ) : (
                                        <p className="not-available">Location not available</p>
                                    )}
                                </div>

                                {/* Journey Section */}
                                {user.activeJourney && (
                                    <div className="section journey-section">
                                        <h3>🚀 Active Journey</h3>
                                        <p><strong>From:</strong> {user.activeJourney.startLocation}</p>
                                        <p><strong>To:</strong> {user.activeJourney.endLocation}</p>
                                        <p><strong>Mode:</strong> {user.activeJourney.mode} {user.activeJourney.reference ? `(${user.activeJourney.reference})` : ''}</p>
                                        <p><strong>Started:</strong> {new Date(user.activeJourney.startTime).toLocaleString()}</p>
                                        <div className="risk-indicator" style={{ backgroundColor: getRiskColor(user.activeJourney.riskLevel) }}>
                                            Journey Risk: {user.activeJourney.riskLevel?.toUpperCase() || 'UNKNOWN'}
                                        </div>
                                    </div>
                                )}

                                {/* Profile Information Section */}
                                {user.profile && (
                                    <div className="section">
                                        <h3>👤 Passport & Info</h3>
                                        <p><strong>Passport:</strong> {user.profile.passport || 'N/A'}</p>
                                        <p><strong>Nationality:</strong> {user.profile.nationality || 'N/A'}</p>
                                        <p><strong>Doc Type:</strong> {user.profile.documentType || 'N/A'}</p>
                                    </div>
                                )}
                            </div>
                        </div>
                    ))
                )}
            </div>
        </div>
    );
};

export default AdminDashboard;
