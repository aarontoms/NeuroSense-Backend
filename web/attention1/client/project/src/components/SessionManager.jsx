import { useState, useRef, useCallback, useEffect } from 'react';
import { Play, Square, Activity, Maximize } from 'lucide-react';
import HiddenCamera from './HiddenCamera';
import API, { startStimulus, nextInstruction, sendFrame, endStimulus } from '../api';
import useInterval from '../hooks/useInterval';

export default function SessionManager({ studentId, onSessionComplete }) {
  const [sessionActive, setSessionActive] = useState(false);
  const [currentAction, setCurrentAction] = useState('');
  const [statusMessage, setStatusMessage] = useState('');
  const [liveAttention, setLiveAttention] = useState(null);
  const [currentStimulus, setCurrentStimulus] = useState(null);
  const [stimulusSeconds, setStimulusSeconds] = useState(30);
  const [voiceOnLow, setVoiceOnLow] = useState(true);
  const [voiceThreshold, setVoiceThreshold] = useState(0.4);

  const audioRef = useRef(null);
  const videoRef = useRef(null);
  const pollTimerRef = useRef(null);
  const videoContainerRef = useRef(null);

  const handleFullscreen = async () => {
    // Prefer the video element; fall back to its container if needed.
    const videoEl = videoRef.current;
    const containerEl = videoContainerRef.current;
    const target = videoEl || containerEl;
    if (!target) return;

    const requestFullscreen = async (el) => {
      if (el.requestFullscreen) return el.requestFullscreen();
      if (el.webkitRequestFullscreen) return el.webkitRequestFullscreen();
      if (el.msRequestFullscreen) return el.msRequestFullscreen();
      if (el.webkitEnterFullscreen) return el.webkitEnterFullscreen();
      return Promise.reject(new Error('No fullscreen API available'));
    };

    try {
      await requestFullscreen(target);
    } catch (err) {
      console.log('Primary fullscreen failed, retrying on container:', err);
      if (containerEl && containerEl !== target) {
        try {
          await requestFullscreen(containerEl);
        } catch (fallbackErr) {
          console.log('Container fullscreen failed:', fallbackErr);
        }
      }
    }
  };

  const handleLandmarks = useCallback(async (payload) => {
    if (!sessionActive) return;

    try {
      const res = await sendFrame(payload);

      if (res.smoothed_attention !== undefined) {
        setLiveAttention(res.smoothed_attention);
      }

      if (res.alert && res.alert_msg) {
        console.log('Alert:', res.alert_msg);
      }
    } catch (err) {
      console.error('Frame send error:', err);
    }
  }, [sessionActive]);

  const playAudio = useCallback((url) => {
    if (!url) return; // Guard: backend may send null voice_url
    const fullUrl = `${API.defaults.baseURL}${url}`;
    if (audioRef.current) {
      audioRef.current.pause();
    }
    audioRef.current = new Audio(fullUrl);
    audioRef.current.play().catch(err => {
      console.error('Audio play error:', err);
    });

    audioRef.current.onended = () => {
      setStatusMessage('Voice finished, waiting for stimulus...');
    };
  }, []);

  const playVideo = useCallback((url, name) => {
    const fullUrl = `${API.defaults.baseURL}${url}`;
    setCurrentStimulus({ url: fullUrl, name });
    setStatusMessage(`Playing stimulus: ${name}`);

    if (videoRef.current) {
      videoRef.current.load();
      videoRef.current.play().catch(err => {
        console.error('Video play error:', err);
        setStatusMessage(`Error playing video: ${err.message}`);
      });

      // Auto-fullscreen when video starts playing
      videoRef.current.addEventListener('playing', () => {
        if (videoContainerRef.current && document.fullscreenEnabled) {
          setTimeout(() => {
            handleFullscreen();
          }, 500);
        }
      }, { once: true });
    }
  }, []);

  const pollNextInstruction = useCallback(async () => {
    if (!studentId || !sessionActive) return;

    try {
      const res = await nextInstruction(studentId);

      if (res.status === 'wait') {
        return;
      }

      if (res.status === 'no_session') {
        setStatusMessage('No active session');
        return;
      }

      if (res.action === 'play_voice') {
        setCurrentAction('Playing voice');
        setStatusMessage('Playing voice prompt...');
        if (res.voice_url) {
          playAudio(res.voice_url);
        }
      } else if (res.action === 'play_stimulus') {
        setCurrentAction('Playing stimulus');
        playVideo(res.stimulus_url, res.stimulus_name);

        if (res.voice_url) {
          setTimeout(() => {
            playAudio(res.voice_url);
          }, 500);
        }
      } else if (res.action === 'session_complete') {
        setCurrentAction('Session complete');
        setStatusMessage('Session completed!');
        // Backend already finalized all stimuli; avoid clearing its state mid-save.
        handleStopSession({ notifyServer: false });

        if (onSessionComplete) {
          onSessionComplete();
        }
      }
    } catch (err) {
      console.error('Poll error:', err);
    }
  }, [studentId, sessionActive, playAudio, playVideo, onSessionComplete]);

  useInterval(pollNextInstruction, sessionActive ? 700 : null);

  const handleStartSession = async () => {
    if (!studentId) {
      alert('Please select or register a student first');
      return;
    }

    try {
      const res = await startStimulus({
        student_id: studentId,
        total_time: Number(stimulusSeconds) || 30,
        voice_on_low_attention: voiceOnLow,
        voice_threshold: Number(voiceThreshold) || 0.4
      });
      setSessionActive(true);
      setStatusMessage('Session started');
      setLiveAttention(null);

      // Attempt fullscreen immediately off the user gesture (Start click).
      handleFullscreen();

      if (res.action === 'play_voice') {
        setCurrentAction('Playing voice');
        if (res.voice_url) {
          playAudio(res.voice_url);
        }
      }
    } catch (err) {
      console.error('Start session error:', err);
      alert('Failed to start session: ' + err.message);
    }
  };

  const handleStopSession = async ({ notifyServer = true } = {}) => {
    if (notifyServer && studentId) {
      try {
        await endStimulus({ student_id: studentId });
      } catch (err) {
        console.error('End stimulus error:', err);
      }
    }

    setSessionActive(false);
    setCurrentAction('');
    setStatusMessage('');
    setCurrentStimulus(null);

    if (audioRef.current) {
      audioRef.current.pause();
      audioRef.current = null;
    }

    if (videoRef.current) {
      videoRef.current.pause();
    }
  };

  useEffect(() => {
    return () => {
      if (audioRef.current) {
        audioRef.current.pause();
      }
    };
  }, []);

  return (
    <div className="space-y-4 md:space-y-6">
      <div className="bg-white rounded-lg shadow-md p-4 md:p-6">
        <h2 className="text-xl md:text-2xl font-bold mb-4 text-gray-800">Session Control</h2>

        <div className="flex gap-2 md:gap-4 mb-4 flex-wrap">
          {!sessionActive ? (
            <button
              onClick={handleStartSession}
              disabled={!studentId}
              className="flex items-center gap-2 px-4 md:px-6 py-2 md:py-3 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:bg-gray-300 disabled:cursor-not-allowed transition-colors text-sm md:text-base"
            >
              <Play size={18} className="md:w-5 md:h-5" />
              Start Session
            </button>
          ) : (
            <button
              onClick={handleStopSession}
              className="flex items-center gap-2 px-4 md:px-6 py-2 md:py-3 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors text-sm md:text-base"
            >
              <Square size={18} className="md:w-5 md:h-5" />
              Stop Session
            </button>
          )}
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3 md:gap-4 mb-4">
          <div>
            <label className="block text-xs md:text-sm font-medium text-gray-700 mb-1">Stimulus Duration (s)</label>
            <input
              type="number"
              min={5}
              value={stimulusSeconds}
              onChange={(e) => setStimulusSeconds(e.target.value)}
              className="w-full px-3 py-2 text-sm border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            />
          </div>
          <div>
            <label className="block text-xs md:text-sm font-medium text-gray-700 mb-1">Voice on Low</label>
            <select
              value={voiceOnLow ? 'yes' : 'no'}
              onChange={(e) => setVoiceOnLow(e.target.value === 'yes')}
              className="w-full px-3 py-2 text-sm border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            >
              <option value="yes">Yes</option>
              <option value="no">No</option>
            </select>
          </div>
          <div>
            <label className="block text-xs md:text-sm font-medium text-gray-700 mb-1">Threshold</label>
            <input
              type="number"
              step="0.05"
              min={0}
              max={1}
              value={voiceThreshold}
              onChange={(e) => setVoiceThreshold(e.target.value)}
              className="w-full px-3 py-2 text-sm border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            />
          </div>
        </div>

        {sessionActive && (
          <div className="space-y-2 md:space-y-3">
            <div className="flex items-center gap-2 text-gray-700 text-sm md:text-base flex-wrap">
              <Activity size={16} className="md:w-5 md:h-5 text-green-600 flex-shrink-0" />
              <span className="font-semibold">Status:</span>
              <span className="break-words">{statusMessage}</span>
            </div>

            {currentAction && (
              <div className="text-gray-700 text-sm md:text-base">
                <span className="font-semibold">Current:</span> {currentAction}
              </div>
            )}

            {liveAttention !== null && (
              <div className="bg-blue-50 p-3 md:p-4 rounded-lg">
                <div className="text-xs md:text-sm font-semibold text-gray-600 mb-2">
                  Live Attention Score
                </div>
                <div className="flex items-center gap-3">
                  <div className="flex-1 bg-gray-200 rounded-full h-3 md:h-4">
                    <div
                      className="bg-blue-600 h-3 md:h-4 rounded-full transition-all duration-300"
                      style={{ width: `${(liveAttention * 100).toFixed(0)}%` }}
                    />
                  </div>
                  <span className="text-lg md:text-xl font-bold text-blue-600 whitespace-nowrap">
                    {(liveAttention * 100).toFixed(1)}%
                  </span>
                </div>
              </div>
            )}
          </div>
        )}
      </div>

      {sessionActive && (
        <div className="bg-white rounded-lg shadow-md p-4 md:p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-lg md:text-xl font-bold text-gray-800 truncate">
              Stimulus: {currentStimulus ? currentStimulus.name : 'Waiting for stimulus...'}
            </h3>
            <button
              onClick={handleFullscreen}
              className="flex items-center gap-2 px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg font-medium transition-all shadow-md hover:shadow-lg"
              title="Fullscreen"
            >
              <Maximize size={18} />
              <span className="hidden sm:inline">Fullscreen</span>
            </button>
          </div>
          <div
            ref={videoContainerRef}
            className="relative w-full aspect-video bg-black rounded-lg shadow-lg overflow-hidden"
          >
            <video
              ref={videoRef}
              src={currentStimulus ? currentStimulus.url : ''}
              className="w-full h-full"
              controls={!!currentStimulus}
              autoPlay={!!currentStimulus}
              onError={(e) => {
                console.error('Video error:', e);
                setStatusMessage('Error loading video. Please check the file format.');
              }}
              onLoadedMetadata={() => {
                console.log('Video loaded successfully');
              }}
            >
              Your browser does not support the video tag.
            </video>
          </div>
        </div>
      )}

      <HiddenCamera
        isActive={sessionActive}
        studentId={studentId}
        onLandmarks={handleLandmarks}
      />
    </div>
  );
}
