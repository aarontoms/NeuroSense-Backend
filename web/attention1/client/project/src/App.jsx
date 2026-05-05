import { useState } from 'react';
import { Eye, BarChart3, Shield, Menu, X, LogOut, User, Settings } from 'lucide-react';
import Login from './components/Login';
import SessionManager from './components/SessionManager';
import AnalyticsDashboard from './components/AnalyticsDashboard';
import AdminPanel from './components/AdminPanel';

function App() {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [userRole, setUserRole] = useState(''); // 'student' or 'admin'
  const [currentStudentId, setCurrentStudentId] = useState('');
  const [currentStudentName, setCurrentStudentName] = useState('');
  const [activeTab, setActiveTab] = useState('session');
  const [refreshAnalytics, setRefreshAnalytics] = useState(0);
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [adminMenuOpen, setAdminMenuOpen] = useState(false);

  const handleStudentLogin = (studentId, studentName) => {
    setCurrentStudentId(studentId);
    setCurrentStudentName(studentName);
    setUserRole('student');
    setIsAuthenticated(true);
    setActiveTab('session');
  };

  const handleAdminLogin = () => {
    setUserRole('admin');
    setIsAuthenticated(true);
    setActiveTab('admin');
  };

  const handleLogout = () => {
    setIsAuthenticated(false);
    setUserRole('');
    setCurrentStudentId('');
    setCurrentStudentName('');
    setActiveTab('session');
    setSidebarOpen(false);
    setAdminMenuOpen(false);
  };

  const handleSessionComplete = () => {
    setRefreshAnalytics(prev => prev + 1);
    setTimeout(() => {
      setActiveTab('analytics');
    }, 1000);
  };

  if (!isAuthenticated) {
    return <Login onStudentLogin={handleStudentLogin} onAdminLogin={handleAdminLogin} />;
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-50 via-blue-50 to-indigo-50 flex">
      {/* Sidebar - Desktop */}
      <aside className="hidden md:flex md:flex-col w-64 bg-white border-r border-gray-200 shadow-lg">
        <div className="p-6 border-b border-gray-200">
          <div className="flex items-center gap-3">
            <div className="bg-gradient-to-br from-blue-600 to-indigo-600 rounded-xl p-2.5 shadow-lg">
              <Eye className="text-white" size={28} />
            </div>
            <div>
              <h1 className="text-lg font-bold text-gray-900">Attention</h1>
              <p className="text-xs text-gray-500">Monitor System</p>
            </div>
          </div>
        </div>

        {/* User Info */}
        <div className="p-4 bg-gradient-to-br from-blue-50 to-indigo-50 border-b border-gray-200">
          {userRole === 'student' ? (
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 bg-blue-600 rounded-full flex items-center justify-center">
                <User className="text-white" size={20} />
              </div>
              <div className="flex-1 min-w-0">
                <p className="text-sm font-semibold text-gray-900 truncate">{currentStudentName}</p>
                <p className="text-xs text-gray-500 truncate">Student</p>
              </div>
            </div>
          ) : (
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 bg-purple-600 rounded-full flex items-center justify-center">
                <Shield className="text-white" size={20} />
              </div>
              <div className="flex-1">
                <p className="text-sm font-semibold text-gray-900">Administrator</p>
                <p className="text-xs text-gray-500">Full Access</p>
              </div>
            </div>
          )}
        </div>

        {/* Navigation */}
        <nav className="flex-1 p-4 space-y-2">
          {userRole === 'student' && (
            <>
              <button
                onClick={() => setActiveTab('session')}
                className={`w-full flex items-center gap-3 px-4 py-3 rounded-lg font-medium transition-all ${
                  activeTab === 'session'
                    ? 'bg-blue-600 text-white shadow-lg'
                    : 'text-gray-700 hover:bg-gray-100'
                }`}
              >
                <Eye size={20} />
                <span>Session</span>
              </button>
              <button
                onClick={() => setActiveTab('analytics')}
                className={`w-full flex items-center gap-3 px-4 py-3 rounded-lg font-medium transition-all ${
                  activeTab === 'analytics'
                    ? 'bg-blue-600 text-white shadow-lg'
                    : 'text-gray-700 hover:bg-gray-100'
                }`}
              >
                <BarChart3 size={20} />
                <span>Analytics</span>
              </button>
            </>
          )}
          {userRole === 'admin' && (
            <button
              onClick={() => setActiveTab('admin')}
              className={`w-full flex items-center gap-3 px-4 py-3 rounded-lg font-medium transition-all ${
                activeTab === 'admin'
                  ? 'bg-purple-600 text-white shadow-lg'
                  : 'text-gray-700 hover:bg-gray-100'
              }`}
            >
              <Shield size={20} />
              <span>Admin Panel</span>
            </button>
          )}
        </nav>

        {/* Logout */}
        <div className="p-4 border-t border-gray-200">
          <button
            onClick={handleLogout}
            className="w-full flex items-center justify-center gap-3 px-4 py-3 bg-red-50 text-red-600 hover:bg-red-100 rounded-lg font-semibold transition-all shadow-sm hover:shadow-md"
          >
            <LogOut size={20} />
            <span>Logout</span>
          </button>
        </div>
      </aside>

      {/* Main Content Area */}
      <div className="flex-1 flex flex-col min-w-0">
        {/* Mobile Header */}
        <header className="md:hidden bg-white border-b border-gray-200 shadow-sm sticky top-0 z-40">
          <div className="flex items-center justify-between p-4">
            <button
              onClick={() => setSidebarOpen(!sidebarOpen)}
              className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
            >
              {sidebarOpen ? <X size={24} /> : <Menu size={24} />}
            </button>
            
            <div className="flex items-center gap-2">
              <div className="bg-gradient-to-br from-blue-600 to-indigo-600 rounded-lg p-1.5">
                <Eye className="text-white" size={20} />
              </div>
              <h1 className="text-lg font-bold text-gray-900">Attention Monitor</h1>
            </div>

            <button
              onClick={handleLogout}
              className="p-2 hover:bg-red-50 rounded-lg transition-colors text-red-600"
              title="Logout"
            >
              <LogOut size={24} />
            </button>
          </div>

          {/* Mobile User Info */}
          {userRole === 'student' && (
            <div className="px-4 pb-3 bg-blue-50">
              <p className="text-xs text-gray-500">Logged in as</p>
              <p className="text-sm font-semibold text-gray-900 truncate">{currentStudentName}</p>
            </div>
          )}
        </header>

        {/* Mobile Sidebar Overlay */}
        {sidebarOpen && (
          <div className="md:hidden fixed inset-0 z-50 bg-black bg-opacity-50" onClick={() => setSidebarOpen(false)}>
            <div className="w-64 h-full bg-white shadow-xl" onClick={(e) => e.stopPropagation()}>
              <div className="p-6 border-b border-gray-200">
                <div className="flex items-center gap-3 mb-4">
                  <div className="bg-gradient-to-br from-blue-600 to-indigo-600 rounded-xl p-2.5">
                    <Eye className="text-white" size={24} />
                  </div>
                  <div>
                    <h1 className="text-lg font-bold text-gray-900">Attention</h1>
                    <p className="text-xs text-gray-500">Monitor System</p>
                  </div>
                </div>
                <button
                  onClick={() => setSidebarOpen(false)}
                  className="absolute top-4 right-4 p-2 hover:bg-gray-100 rounded-lg"
                >
                  <X size={20} />
                </button>
              </div>

              <div className="p-4 bg-gradient-to-br from-blue-50 to-indigo-50 border-b border-gray-200">
                {userRole === 'student' ? (
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 bg-blue-600 rounded-full flex items-center justify-center">
                      <User className="text-white" size={20} />
                    </div>
                    <div className="flex-1">
                      <p className="text-sm font-semibold text-gray-900">{currentStudentName}</p>
                      <p className="text-xs text-gray-500">Student</p>
                    </div>
                  </div>
                ) : (
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 bg-purple-600 rounded-full flex items-center justify-center">
                      <Shield className="text-white" size={20} />
                    </div>
                    <div className="flex-1">
                      <p className="text-sm font-semibold text-gray-900">Administrator</p>
                      <p className="text-xs text-gray-500">Full Access</p>
                    </div>
                  </div>
                )}
              </div>

              <nav className="p-4 space-y-2">
                {userRole === 'student' && (
                  <>
                    <button
                      onClick={() => { setActiveTab('session'); setSidebarOpen(false); }}
                      className={`w-full flex items-center gap-3 px-4 py-3 rounded-lg font-medium transition-all ${
                        activeTab === 'session'
                          ? 'bg-blue-600 text-white'
                          : 'text-gray-700 hover:bg-gray-100'
                      }`}
                    >
                      <Eye size={20} />
                      <span>Session</span>
                    </button>
                    <button
                      onClick={() => { setActiveTab('analytics'); setSidebarOpen(false); }}
                      className={`w-full flex items-center gap-3 px-4 py-3 rounded-lg font-medium transition-all ${
                        activeTab === 'analytics'
                          ? 'bg-blue-600 text-white'
                          : 'text-gray-700 hover:bg-gray-100'
                      }`}
                    >
                      <BarChart3 size={20} />
                      <span>Analytics</span>
                    </button>
                  </>
                )}
                {userRole === 'admin' && (
                  <button
                    onClick={() => { setActiveTab('admin'); setSidebarOpen(false); }}
                    className={`w-full flex items-center gap-3 px-4 py-3 rounded-lg font-medium transition-all ${
                      activeTab === 'admin'
                        ? 'bg-purple-600 text-white'
                        : 'text-gray-700 hover:bg-gray-100'
                    }`}
                  >
                    <Shield size={20} />
                    <span>Admin Panel</span>
                  </button>
                )}
              </nav>

              <div className="absolute bottom-0 left-0 right-0 p-4 border-t border-gray-200 bg-white">
                <button
                  onClick={handleLogout}
                  className="w-full flex items-center gap-3 px-4 py-3 text-red-600 hover:bg-red-50 rounded-lg font-medium transition-all"
                >
                  <LogOut size={20} />
                  <span>Logout</span>
                </button>
              </div>
            </div>
          </div>
        )}

        {/* Main Content */}
        <main className="flex-1 overflow-auto p-4 md:p-6 lg:p-8">
          {userRole === 'student' && activeTab === 'session' && (
            <SessionManager
              studentId={currentStudentId}
              onSessionComplete={handleSessionComplete}
            />
          )}

          {userRole === 'student' && activeTab === 'analytics' && (
            <AnalyticsDashboard
              studentId={currentStudentId}
              refresh={refreshAnalytics}
            />
          )}

          {userRole === 'admin' && activeTab === 'admin' && (
            <AdminPanel />
          )}
        </main>
      </div>
    </div>
  );
}

export default App;
