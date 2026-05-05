import { useState } from 'react';
import { UserPlus, LogIn, Key } from 'lucide-react';
import { registerStudent, loginStudent } from '../api';

export default function Controls({ onStudentRegistered }) {
  const [mode, setMode] = useState('register'); // 'register' or 'login'
  const [studentName, setStudentName] = useState('');
  const [preferredCall, setPreferredCall] = useState('');
  const [language, setLanguage] = useState('en');
  const [accessKey, setAccessKey] = useState('');
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState('');
  const [registeredAccessKey, setRegisteredAccessKey] = useState('');

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
      setMessage(`Student registered successfully! Student ID: ${result.student_id}`);

      if (onStudentRegistered) {
        onStudentRegistered(result.student_id, studentName);
      }
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

      if (onStudentRegistered) {
        onStudentRegistered(result.student_id, result.student_name);
      }
    } catch (err) {
      setMessage(`Error: ${err.response?.data?.error || err.message}`);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="space-y-4 md:space-y-6">
      {/* Mode Toggle */}
      <div className="bg-white rounded-lg shadow-md p-4 md:p-6">
        <div className="flex gap-2 mb-4">
          <button
            onClick={() => setMode('register')}
            className={`flex-1 flex items-center justify-center gap-1 md:gap-2 px-3 md:px-6 py-2 md:py-3 rounded-lg font-medium text-sm md:text-base transition-colors ${
              mode === 'register'
                ? 'bg-blue-600 text-white'
                : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
            }`}
          >
            <UserPlus size={18} className="md:w-5 md:h-5" />
            <span className="hidden sm:inline">New Student</span>
            <span className="sm:hidden">New</span>
          </button>
          <button
            onClick={() => setMode('login')}
            className={`flex-1 flex items-center justify-center gap-1 md:gap-2 px-3 md:px-6 py-2 md:py-3 rounded-lg font-medium text-sm md:text-base transition-colors ${
              mode === 'login'
                ? 'bg-green-600 text-white'
                : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
            }`}
          >
            <LogIn size={18} className="md:w-5 md:h-5" />
            <span className="hidden sm:inline">Returning</span>
            <span className="sm:hidden">Login</span>
          </button>
        </div>
      </div>

      {/* Register Form */}
      {mode === 'register' && (
        <div className="bg-white rounded-lg shadow-md p-4 md:p-6">
          <div className="flex items-center gap-2 mb-4">
            <UserPlus className="text-blue-600 flex-shrink-0" size={20} />
            <h2 className="text-lg md:text-2xl font-bold text-gray-800">Register New Student</h2>
          </div>

          <p className="text-gray-600 mb-4 text-sm md:text-base">
            Create a new student account. You'll receive a unique access key to login later.
          </p>

          <form onSubmit={handleRegisterStudent} className="space-y-3 md:space-y-4">
            <div>
              <label className="block text-xs md:text-sm font-medium text-gray-700 mb-1">
                Student Name *
              </label>
              <input
                type="text"
                value={studentName}
                onChange={(e) => setStudentName(e.target.value)}
                className="w-full px-3 md:px-4 py-2 text-sm border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                placeholder="Enter student name"
                required
              />
            </div>

            <div>
              <label className="block text-xs md:text-sm font-medium text-gray-700 mb-1">
                Preferred Call Name
              </label>
              <input
                type="text"
                value={preferredCall}
                onChange={(e) => setPreferredCall(e.target.value)}
                className="w-full px-3 md:px-4 py-2 text-sm border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                placeholder="Optional nickname"
              />
            </div>

            <div>
              <label className="block text-xs md:text-sm font-medium text-gray-700 mb-1">
                Language
              </label>
              <select
                value={language}
                onChange={(e) => setLanguage(e.target.value)}
                className="w-full px-3 md:px-4 py-2 text-sm border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              >
                <option value="en">English</option>
                <option value="es">Spanish</option>
                <option value="fr">French</option>
              </select>
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full px-4 md:px-6 py-2 md:py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:bg-gray-300 disabled:cursor-not-allowed transition-colors font-medium text-sm md:text-base"
            >
              {loading ? 'Registering...' : 'Register Student'}
            </button>
          </form>

          {registeredAccessKey && (
            <div className="mt-4 md:mt-6 p-4 md:p-6 bg-green-50 border-2 border-green-500 rounded-lg">
              <div className="flex items-center gap-2 mb-3">
                <Key className="text-green-600 flex-shrink-0" size={20} />
                <h3 className="text-base md:text-lg font-bold text-green-800">Registration Successful!</h3>
              </div>
              <p className="text-sm md:text-base text-green-700 mb-3 font-semibold">
                Your unique access key is:
              </p>
              <div className="bg-white p-3 md:p-4 rounded-lg border-2 border-green-300 mb-3 overflow-auto">
                <p className="text-2xl md:text-3xl font-mono font-bold text-center text-green-700 tracking-widest break-all">
                  {registeredAccessKey}
                </p>
              </div>
              <p className="text-xs md:text-sm text-green-600 font-medium">
                ⚠️ IMPORTANT: Save this key! You'll need it to login next time.
              </p>
            </div>
          )}

          {message && !registeredAccessKey && (
            <div className={`mt-4 p-3 md:p-4 rounded-lg text-sm md:text-base ${
              message.includes('Error') ? 'bg-red-100 text-red-700' : 'bg-green-100 text-green-700'
            }`}>
              {message}
            </div>
          )}
        </div>
      )}

      {/* Login Form */}
      {mode === 'login' && (
        <div className="bg-white rounded-lg shadow-md p-4 md:p-6">
          <div className="flex items-center gap-2 mb-4">
            <LogIn className="text-green-600 flex-shrink-0" size={20} />
            <h2 className="text-lg md:text-2xl font-bold text-gray-800">Student Login</h2>
          </div>

          <p className="text-gray-600 mb-4 text-sm md:text-base">
            Enter your unique access key to continue your sessions.
          </p>

          <form onSubmit={handleLoginStudent} className="space-y-3 md:space-y-4">
            <div>
              <label className="block text-xs md:text-sm font-medium text-gray-700 mb-1">
                Access Key *
              </label>
              <input
                type="text"
                value={accessKey}
                onChange={(e) => setAccessKey(e.target.value.toUpperCase())}
                className="w-full px-3 md:px-4 py-3 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-green-500 font-mono text-lg md:text-xl text-center tracking-widest"
                placeholder="XXXXXXXX"
                maxLength={8}
                required
              />
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full px-4 md:px-6 py-2 md:py-3 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:bg-gray-300 disabled:cursor-not-allowed transition-colors font-medium text-sm md:text-base"
            >
              {loading ? 'Logging in...' : 'Login'}
            </button>
          </form>

          {message && (
            <div className={`mt-4 p-3 md:p-4 rounded-lg text-sm md:text-base ${
              message.includes('Error') || message.includes('Invalid') 
                ? 'bg-red-100 text-red-700' 
                : 'bg-green-100 text-green-700'
            }`}>
              {message}
            </div>
          )}
        </div>
      )}

      <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 md:p-6">
        <h3 className="text-base md:text-lg font-semibold text-blue-900 mb-2 md:mb-3">📝 Next Steps</h3>
        <ol className="space-y-1 md:space-y-2 text-blue-800 text-xs md:text-sm list-decimal list-inside">
          <li>After {mode === 'register' ? 'registration' : 'login'}, go to the <strong>Session</strong> tab to start monitoring</li>
          <li>Admin can upload voice profiles and stimulus content in the <strong>Admin</strong> tab</li>
          <li>View your progress and analytics in the <strong>Analytics</strong> tab</li>
        </ol>
      </div>
    </div>
  );
}
