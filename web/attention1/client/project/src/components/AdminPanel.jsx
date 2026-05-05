import { useState } from 'react';
import { Upload, Mic, Video, Shield, CheckCircle, AlertCircle } from 'lucide-react';
import { uploadVoice, uploadStimulus } from '../api';

export default function AdminPanel() {
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState({ text: '', type: '' });

  // Voice upload state
  const [studentIdForVoice, setStudentIdForVoice] = useState('');
  const [voiceFile, setVoiceFile] = useState(null);
  const [voicePrefix, setVoicePrefix] = useState('caretaker');

  // Stimulus upload state
  const [stimulusFile, setStimulusFile] = useState(null);
  const [stimulusName, setStimulusName] = useState('');
  const [stimulusDuration, setStimulusDuration] = useState(30);

  const showMessage = (text, type = 'info') => {
    setMessage({ text, type });
    setTimeout(() => setMessage({ text: '', type: '' }), 5000);
  };

  const handleUploadVoice = async (e) => {
    e.preventDefault();
    
    if (!studentIdForVoice.trim()) {
      showMessage('Please enter a student ID', 'error');
      return;
    }
    if (!voiceFile) {
      showMessage('Please select a voice file', 'error');
      return;
    }

    setLoading(true);

    try {
      const formData = new FormData();
      formData.append('file', voiceFile);
      formData.append('prefix', voicePrefix);

      const result = await uploadVoice(studentIdForVoice, formData);
      showMessage(`Voice uploaded successfully! URL: ${result.voice_url}`, 'success');
      
      // Reset form
      setVoiceFile(null);
      setStudentIdForVoice('');
      // Reset file input
      const fileInput = document.getElementById('voice-file-input');
      if (fileInput) fileInput.value = '';
    } catch (err) {
      showMessage(`Error: ${err.response?.data?.error || err.message}`, 'error');
    } finally {
      setLoading(false);
    }
  };

  const handleUploadStimulus = async (e) => {
    e.preventDefault();
    
    if (!stimulusFile) {
      showMessage('Please select a stimulus file (video/audio)', 'error');
      return;
    }
    if (!stimulusName.trim()) {
      showMessage('Please enter a stimulus name', 'error');
      return;
    }

    setLoading(true);

    try {
      const formData = new FormData();
      formData.append('file', stimulusFile);
      formData.append('name', stimulusName);
      formData.append('total_time', stimulusDuration || 30);

      const result = await uploadStimulus(formData);
      showMessage(`Stimulus uploaded successfully! ID: ${result.stimulus_id}`, 'success');
      
      // Reset form
      setStimulusFile(null);
      setStimulusName('');
      setStimulusDuration(30);
      // Reset file input
      const fileInput = document.getElementById('stimulus-file-input');
      if (fileInput) fileInput.value = '';
    } catch (err) {
      showMessage(`Error: ${err.response?.data?.error || err.message}`, 'error');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="bg-gradient-to-r from-purple-600 to-blue-600 rounded-lg shadow-lg p-6 text-white">
        <div className="flex items-center gap-3 mb-2">
          <Shield size={32} />
          <h1 className="text-3xl font-bold">Admin Panel</h1>
        </div>
        <p className="text-purple-100">
          Manage voice profiles and stimulus content for the attention monitoring system
        </p>
      </div>

      {/* Message Display */}
      {message.text && (
        <div className={`rounded-lg p-4 flex items-center gap-3 ${
          message.type === 'success' ? 'bg-green-100 text-green-800 border border-green-300' :
          message.type === 'error' ? 'bg-red-100 text-red-800 border border-red-300' :
          'bg-blue-100 text-blue-800 border border-blue-300'
        }`}>
          {message.type === 'success' ? <CheckCircle size={20} /> : <AlertCircle size={20} />}
          <span className="font-medium">{message.text}</span>
        </div>
      )}

      {/* Upload Voice Section */}
      <div className="bg-white rounded-lg shadow-md p-6">
        <div className="flex items-center gap-2 mb-4">
          <Mic className="text-green-600" size={28} />
          <h2 className="text-2xl font-bold text-gray-800">Upload Voice Profile</h2>
        </div>
        
        <p className="text-gray-600 mb-4">
          Upload a personalized voice file for a student. This will be used during attention monitoring sessions.
        </p>

        <form onSubmit={handleUploadVoice} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Student ID
            </label>
            <input
              type="text"
              value={studentIdForVoice}
              onChange={(e) => setStudentIdForVoice(e.target.value)}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-transparent"
              placeholder="Enter student ID (e.g., 6785a1c2f3e4d5a6b7c8d9e0)"
              required
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Voice Prefix
            </label>
            <select
              value={voicePrefix}
              onChange={(e) => setVoicePrefix(e.target.value)}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-transparent"
            >
              <option value="caretaker">Caretaker</option>
              <option value="teacher">Teacher</option>
              <option value="parent">Parent</option>
              <option value="friend">Friend</option>
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Voice File (WAV/MP3)
            </label>
            <input
              id="voice-file-input"
              type="file"
              accept="audio/*"
              onChange={(e) => setVoiceFile(e.target.files[0])}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-transparent file:mr-4 file:py-2 file:px-4 file:rounded-md file:border-0 file:text-sm file:font-semibold file:bg-green-50 file:text-green-700 hover:file:bg-green-100"
              required
            />
            {voiceFile && (
              <p className="mt-2 text-sm text-gray-500">
                Selected: {voiceFile.name} ({(voiceFile.size / 1024).toFixed(2)} KB)
              </p>
            )}
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full px-6 py-3 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:bg-gray-400 disabled:cursor-not-allowed transition-colors font-semibold flex items-center justify-center gap-2"
          >
            {loading ? (
              <>
                <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-white"></div>
                Uploading...
              </>
            ) : (
              <>
                <Upload size={20} />
                Upload Voice
              </>
            )}
          </button>
        </form>
      </div>

      {/* Upload Stimulus Section */}
      <div className="bg-white rounded-lg shadow-md p-6">
        <div className="flex items-center gap-2 mb-4">
          <Video className="text-purple-600" size={28} />
          <h2 className="text-2xl font-bold text-gray-800">Upload Stimulus Content</h2>
        </div>
        
        <p className="text-gray-600 mb-4">
          Upload video or audio stimulus content that will be presented to students during attention monitoring.
        </p>

        <form onSubmit={handleUploadStimulus} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Stimulus Name
            </label>
            <input
              type="text"
              value={stimulusName}
              onChange={(e) => setStimulusName(e.target.value)}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent"
              placeholder="e.g., Color Card 1, Math Video, Story Audio"
              required
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Stimulus File (Video/Audio)
            </label>
            <input
              id="stimulus-file-input"
              type="file"
              accept="video/*,audio/*"
              onChange={(e) => setStimulusFile(e.target.files[0])}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent file:mr-4 file:py-2 file:px-4 file:rounded-md file:border-0 file:text-sm file:font-semibold file:bg-purple-50 file:text-purple-700 hover:file:bg-purple-100"
              required
            />
            {stimulusFile && (
              <p className="mt-2 text-sm text-gray-500">
                Selected: {stimulusFile.name} ({(stimulusFile.size / 1024 / 1024).toFixed(2)} MB)
              </p>
            )}
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Play Duration (seconds)
            </label>
            <input
              type="number"
              min={5}
              value={stimulusDuration}
              onChange={(e) => setStimulusDuration(Number(e.target.value))}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent"
              placeholder="e.g., 30"
            />
            <p className="text-xs text-gray-500 mt-1">Video/audio will be limited to this duration in sessions.</p>
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full px-6 py-3 bg-purple-600 text-white rounded-lg hover:bg-purple-700 disabled:bg-gray-400 disabled:cursor-not-allowed transition-colors font-semibold flex items-center justify-center gap-2"
          >
            {loading ? (
              <>
                <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-white"></div>
                Uploading...
              </>
            ) : (
              <>
                <Upload size={20} />
                Upload Stimulus
              </>
            )}
          </button>
        </form>
      </div>

      {/* Info Section */}
      <div className="bg-blue-50 border border-blue-200 rounded-lg p-6">
        <h3 className="text-lg font-semibold text-blue-900 mb-3">📋 Instructions</h3>
        <ul className="space-y-2 text-blue-800">
          <li className="flex items-start gap-2">
            <span className="text-blue-600 font-bold">•</span>
            <span><strong>Voice uploads:</strong> Associate voice prompts with registered students using their ID</span>
          </li>
          <li className="flex items-start gap-2">
            <span className="text-blue-600 font-bold">•</span>
            <span><strong>Stimulus uploads:</strong> Add educational content (videos/audio) for attention sessions</span>
          </li>
          <li className="flex items-start gap-2">
            <span className="text-blue-600 font-bold">•</span>
            <span><strong>Supported formats:</strong> Audio (MP3, WAV), Video (MP4, WebM)</span>
          </li>
          <li className="flex items-start gap-2">
            <span className="text-blue-600 font-bold">•</span>
            <span><strong>File size:</strong> Keep files under 50MB for optimal performance</span>
          </li>
        </ul>
      </div>
    </div>
  );
}
