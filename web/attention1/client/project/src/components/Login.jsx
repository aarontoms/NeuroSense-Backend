import { useState } from 'react';
import { UserPlus, LogIn, Shield, Key, Lock, Copy, Check } from 'lucide-react';
import { registerStudent, loginStudent, loginAdmin } from '../api';

export default function Login({ onStudentLogin, onAdminLogin }) {
  const [mode, setMode] = useState('student'); // 'student' or 'admin'
  const [studentMode, setStudentMode] = useState('login'); // 'register' or 'login'
  //
  // Student fields
  const [studentName, setStudentName] = useState('');
  const [preferredCall, setPreferredCall] = useState('');
  const [language, setLanguage] = useState('en');
  const [accessKey, setAccessKey] = useState('');
  const [registeredAccessKey, setRegisteredAccessKey] = useState('');
  
  // Admin fields
  const [adminUsername, setAdminUsername] = useState('');
  const [adminPassword, setAdminPassword] = useState('');
  
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState('');
  const [copied, setCopied] = useState(false);

  const handleCopyAccessKey = () => {
    navigator.clipboard.writeText(registeredAccessKey);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleRegisterStudent = async (e) => {
    e.preventDefault();
    if (!studentName.trim()) {
      setMessage('Please enter a student name');
      return;
    }

    setLoading(true);
    setMessage('');

    try {
      const result = await registerStudent({
        student_name: studentName,
        preferred_call: preferredCall || studentName,
        language
      });

      setRegisteredAccessKey(result.access_key);
      setMessage(`Student registered successfully!`);
    } catch (err) {
      setMessage(`Error: ${err.response?.data?.error || err.message}`);
    } finally {
      setLoading(false);
    }
  };

  const handleLoginStudent = async (e) => {
    e.preventDefault();
    if (!accessKey.trim()) {
      setMessage('Please enter your access key');
      return;
    }

    setLoading(true);
    setMessage('');

    try {
      const result = await loginStudent({
        access_key: accessKey
      });

      setMessage(`Welcome back, ${result.student_name}!`);
      
      if (onStudentLogin) {
        onStudentLogin(result.student_id, result.student_name);
      }
    } catch (err) {
      setMessage(`Error: ${err.response?.data?.error || err.message}`);
    } finally {
      setLoading(false);
    }
  };

  const handleLoginAdmin = async (e) => {
    e.preventDefault();
    if (!adminUsername.trim() || !adminPassword.trim()) {
      setMessage('Please enter username and password');
      return;
    }

    setLoading(true);
    setMessage('');

    try {
      const result = await loginAdmin({
        username: adminUsername,
        password: adminPassword
      });

      setMessage('Admin login successful!');
      
      if (onAdminLogin) {
        onAdminLogin();
      }
    } catch (err) {
      setMessage(`Error: ${err.response?.data?.error || err.message}`);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 via-indigo-50 to-purple-50 flex items-center justify-center p-4">
      <div className="w-full max-w-md">
        {/* Logo/Brand */}
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-20 h-20 bg-gradient-to-br from-blue-600 to-indigo-600 rounded-2xl shadow-lg mb-4">
            <Shield className="text-white" size={40} />
          </div>
          <h1 className="text-3xl font-bold text-gray-900 mb-2">Attention Monitor</h1>
          <p className="text-gray-600">Privacy-first attention tracking system</p>
        </div>

        {/* Mode Toggle */}
        <div className="bg-white rounded-2xl shadow-xl overflow-hidden">
          <div className="flex border-b border-gray-200">
            <button
              onClick={() => setMode('student')}
              className={`flex-1 flex items-center justify-center gap-2 px-6 py-4 font-semibold transition-all ${
                mode === 'student'
                  ? 'bg-blue-600 text-white'
                  : 'bg-gray-50 text-gray-600 hover:bg-gray-100'
              }`}
            >
              <UserPlus size={20} />
              Student
            </button>
            <button
              onClick={() => setMode('admin')}
              className={`flex-1 flex items-center justify-center gap-2 px-6 py-4 font-semibold transition-all ${
                mode === 'admin'
                  ? 'bg-purple-600 text-white'
                  : 'bg-gray-50 text-gray-600 hover:bg-gray-100'
              }`}
            >
              <Shield size={20} />
              Admin
            </button>
          </div>

          <div className="p-6 md:p-8">
            {mode === 'student' ? (
              <>
                {/* Student Sub-Mode Toggle */}
                <div className="flex gap-2 mb-6">
                  <button
                    onClick={() => setStudentMode('login')}
                    className={`flex-1 px-4 py-2 rounded-lg font-medium transition-colors ${
                      studentMode === 'login'
                        ? 'bg-blue-100 text-blue-700 border-2 border-blue-600'
                        : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                    }`}
                  >
                    <LogIn className="inline mr-2" size={16} />
                    Login
                  </button>
                  <button
                    onClick={() => setStudentMode('register')}
                    className={`flex-1 px-4 py-2 rounded-lg font-medium transition-colors ${
                      studentMode === 'register'
                        ? 'bg-blue-100 text-blue-700 border-2 border-blue-600'
                        : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                    }`}
                  >
                    <UserPlus className="inline mr-2" size={16} />
                    Register
                  </button>
                </div>

                {studentMode === 'register' ? (
                  <form onSubmit={handleRegisterStudent} className="space-y-4">
                    <div>
                      <label className="block text-sm font-semibold text-gray-700 mb-2">
                        Student Name *
                      </label>
                      <input
                        type="text"
                        value={studentName}
                        onChange={(e) => setStudentName(e.target.value)}
                        className="w-full px-4 py-3 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-all"
                        placeholder="Enter your full name"
                        required
                      />
                    </div>

                    <div>
                      <label className="block text-sm font-semibold text-gray-700 mb-2">
                        Preferred Name (Optional)
                      </label>
                      <input
                        type="text"
                        value={preferredCall}
                        onChange={(e) => setPreferredCall(e.target.value)}
                        className="w-full px-4 py-3 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-all"
                        placeholder="Nickname or preferred name"
                      />
                    </div>

                    <div>
                      <label className="block text-sm font-semibold text-gray-700 mb-2">
                        Language
                      </label>
                      <select
                        value={language}
                        onChange={(e) => setLanguage(e.target.value)}
                        className="w-full px-4 py-3 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-all"
                      >
                        <option value="en">English</option>
                        <option value="es">Spanish</option>
                        <option value="fr">French</option>
                      </select>
                    </div>

                    <button
                      type="submit"
                      disabled={loading}
                      className="w-full px-6 py-3 bg-gradient-to-r from-blue-600 to-indigo-600 text-white rounded-lg hover:from-blue-700 hover:to-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed transition-all font-semibold shadow-lg hover:shadow-xl"
                    >
                      {loading ? 'Registering...' : 'Register Student'}
                    </button>

                    {registeredAccessKey && (
                      <div className="mt-4 p-6 bg-gradient-to-br from-green-50 to-emerald-50 border-2 border-green-500 rounded-xl shadow-lg">
                        <div className="flex items-center gap-2 mb-4">
                          <div className="w-10 h-10 bg-green-600 rounded-full flex items-center justify-center">
                            <Key className="text-white" size={20} />
                          </div>
                          <div>
                            <h3 className="text-lg font-bold text-green-800">Registration Successful!</h3>
                            <p className="text-xs text-green-600">Your account has been created</p>
                          </div>
                        </div>
                        
                        <div className="bg-white p-4 rounded-lg border-2 border-green-400 shadow-inner mb-3">
                          <p className="text-xs font-semibold text-gray-600 mb-2 text-center uppercase tracking-wide">
                            Your Access Key
                          </p>
                          <p className="text-3xl font-mono font-bold text-center text-green-700 tracking-widest mb-3">
                            {registeredAccessKey}
                          </p>
                          <button
                            onClick={handleCopyAccessKey}
                            className="w-full flex items-center justify-center gap-2 px-4 py-2 bg-green-600 hover:bg-green-700 text-white rounded-lg font-medium transition-all"
                          >
                            {copied ? (
                              <>
                                <Check size={18} />
                                <span>Copied!</span>
                              </>
                            ) : (
                              <>
                                <Copy size={18} />
                                <span>Copy Access Key</span>
                              </>
                            )}
                          </button>
                        </div>
                        
                        <div className="bg-amber-50 border border-amber-300 rounded-lg p-3">
                          <p className="text-xs text-amber-800 font-bold mb-1">⚠️ IMPORTANT - Save This Key!</p>
                          <ul className="text-xs text-amber-700 space-y-1 ml-4 list-disc">
                            <li>Copy and save this key in a safe place</li>
                            <li>You'll need it to login next time</li>
                            <li>This key will not be shown again</li>
                          </ul>
                        </div>

                        <button
                          onClick={() => {
                            setStudentMode('login');
                            setAccessKey(registeredAccessKey);
                            setRegisteredAccessKey('');
                            setStudentName('');
                            setPreferredCall('');
                          }}
                          className="w-full mt-3 px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg font-medium transition-all"
                        >
                          Continue to Login
                        </button>
                      </div>
                    )}
                  </form>
                ) : (
                  <form onSubmit={handleLoginStudent} className="space-y-4">
                    <div>
                      <label className="block text-sm font-semibold text-gray-700 mb-2">
                        Access Key *
                      </label>
                      <input
                        type="text"
                        value={accessKey}
                        onChange={(e) => setAccessKey(e.target.value.toUpperCase())}
                        className="w-full px-4 py-4 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 font-mono text-xl text-center tracking-widest transition-all"
                        placeholder="XXXXXXXX"
                        maxLength={8}
                        required
                      />
                    </div>

                    <button
                      type="submit"
                      disabled={loading}
                      className="w-full px-6 py-3 bg-gradient-to-r from-blue-600 to-indigo-600 text-white rounded-lg hover:from-blue-700 hover:to-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed transition-all font-semibold shadow-lg hover:shadow-xl"
                    >
                      {loading ? 'Logging in...' : 'Login'}
                    </button>
                  </form>
                )}
              </>
            ) : (
              <form onSubmit={handleLoginAdmin} className="space-y-4">
                <div className="text-center mb-6">
                  <div className="inline-flex items-center justify-center w-16 h-16 bg-purple-100 rounded-full mb-3">
                    <Lock className="text-purple-600" size={32} />
                  </div>
                  <h3 className="text-xl font-bold text-gray-900">Admin Login</h3>
                  <p className="text-sm text-gray-600 mt-1">Secure access for administrators</p>
                </div>

                <div>
                  <label className="block text-sm font-semibold text-gray-700 mb-2">
                    Username
                  </label>
                  <input
                    type="text"
                    value={adminUsername}
                    onChange={(e) => setAdminUsername(e.target.value)}
                    className="w-full px-4 py-3 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500 transition-all"
                    placeholder="admin"
                    required
                  />
                </div>

                <div>
                  <label className="block text-sm font-semibold text-gray-700 mb-2">
                    Password
                  </label>
                  <input
                    type="password"
                    value={adminPassword}
                    onChange={(e) => setAdminPassword(e.target.value)}
                    className="w-full px-4 py-3 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500 transition-all"
                    placeholder="Enter admin password"
                    required
                  />
                </div>

                <button
                  type="submit"
                  disabled={loading}
                  className="w-full px-6 py-3 bg-gradient-to-r from-purple-600 to-indigo-600 text-white rounded-lg hover:from-purple-700 hover:to-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed transition-all font-semibold shadow-lg hover:shadow-xl"
                >
                  {loading ? 'Logging in...' : 'Admin Login'}
                </button>
              </form>
            )}

            {message && (
              <div className={`mt-4 p-3 rounded-lg text-sm font-medium ${
                message.includes('Error') || message.includes('Invalid')
                  ? 'bg-red-100 text-red-700 border border-red-300'
                  : 'bg-green-100 text-green-700 border border-green-300'
              }`}>
                {message}
              </div>
            )}
          </div>
        </div>

        <p className="text-center text-sm text-gray-600 mt-6">
          🔒 Your privacy is protected. Camera feed never leaves your device.
        </p>
      </div>
    </div>
  );
}
