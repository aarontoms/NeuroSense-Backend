import React, { useRef, useState, useEffect } from "react";
import {
  Camera,
  Video,
  Upload,
  AlertCircle,
  Activity,
  Loader,
  CheckCircle,
  Circle,
  EyeOff,
} from "lucide-react";

/* ✅ CORRECT PORT */
const API_BASE_URL = "https://mv1z79jg-3000.inc1.devtunnels.ms/";

export default function FaceModelApp() {
  const [mode, setMode] = useState("realtime");
  const [cameraActive, setCameraActive] = useState(false);
  const [isProcessing, setIsProcessing] = useState(false);
  const [result, setResult] = useState(null);
  const [error, setError] = useState(null);
  const [videoResults, setVideoResults] = useState(null);
  const [faceDetected, setFaceDetected] = useState(false);
  const [processingStatus, setProcessingStatus] = useState("");

  const videoRef = useRef(null);
  const faceMeshRef = useRef(null);
  const cameraRef = useRef(null);
  const videoFileRef = useRef(null);
  const latestLandmarksRef = useRef(null);
  const apiIntervalRef = useRef(null);
  const lastFaceDetectTime = useRef(0);

  /* ---------------- INIT FACEMESH ---------------- */
  useEffect(() => {
    if (!window.FaceMesh || !window.Camera) return;

    const faceMesh = new window.FaceMesh({
      locateFile: (file) =>
        `https://cdn.jsdelivr.net/npm/@mediapipe/face_mesh/${file}`,
    });

    faceMesh.setOptions({
      maxNumFaces: 1,
      refineLandmarks: true,
      minDetectionConfidence: 0.5,
      minTrackingConfidence: 0.5,
    });

    faceMesh.onResults(onFaceMeshResults);
    faceMeshRef.current = faceMesh;

    return stopCamera;
  }, []);

  /* ---------------- FACEMESH CALLBACK ---------------- */
  const onFaceMeshResults = (results) => {
    const now = Date.now();
    if (!results.multiFaceLandmarks?.length) {
      if (now - lastFaceDetectTime.current > 1200) {
        setFaceDetected(false);
      }
      return;
    }

    lastFaceDetectTime.current = now;
    setFaceDetected(true);

    let lm = results.multiFaceLandmarks[0];
    if (lm.length === 478) lm = lm.slice(0, 468);
    if (lm.length !== 468) return;

    latestLandmarksRef.current = lm.map(({ x, y, z }) => ({ x, y, z }));
  };

  /* ---------------- CAMERA CONTROL ---------------- */
  const startCamera = async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: { width: 640, height: 480, facingMode: "user" },
      });
      videoRef.current.srcObject = stream;

      const camera = new window.Camera(videoRef.current, {
        onFrame: async () => {
          await faceMeshRef.current.send({ image: videoRef.current });
        },
        width: 640,
        height: 480,
      });

      cameraRef.current = camera;
      await camera.start();
      setCameraActive(true);
      setError(null);
      setResult(null);
      setFaceDetected(false);

      apiIntervalRef.current = setInterval(() => {
        if (latestLandmarksRef.current) {
          sendRealtimePrediction(latestLandmarksRef.current);
        }
      }, 2000);
    } catch {
      setError("Camera permission denied or unavailable");
    }
  };

  const stopCamera = () => {
    if (apiIntervalRef.current) clearInterval(apiIntervalRef.current);
    cameraRef.current?.stop();
    videoRef.current?.srcObject?.getTracks().forEach((t) => t.stop());
    setCameraActive(false);
    setFaceDetected(false);
    latestLandmarksRef.current = null;
    setResult(null);
  };

  /* ---------------- REALTIME API ---------------- */
  const sendRealtimePrediction = async (landmarks) => {
    try {
      const res = await fetch(`${API_BASE_URL}/api/predict/realtime`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ landmarks }),
      });
      const data = await res.json();
      if (data.success) setResult(data);
    } catch {
      // Silently fail for realtime (too noisy)
    }
  };

  /* ---------------- VIDEO PROCESSING (BACKEND HANDLES EVERYTHING) ---------------- */
  const processVideoFile = async (file) => {
    setIsProcessing(true);
    setError(null);
    setVideoResults(null);
    setProcessingStatus("Uploading video to server...");

    try {
      // Send video to backend for complete processing
      const formData = new FormData();
      formData.append("video", file);

      console.log("Uploading video for backend processing:", file.name);
      setProcessingStatus("Processing video on server (this may take a minute)...");

      const res = await fetch(`${API_BASE_URL}/api/predict/video-process`, {
        method: "POST",
        body: formData,
      });

      if (!res.ok) {
        const errorData = await res.json().catch(() => ({ error: "Unknown error" }));
        throw new Error(errorData.error || errorData.details || `Server error: ${res.status}`);
      }

      const data = await res.json();
      console.log("Backend processing response:", data);

      if (!data.success) {
        throw new Error(data.error || "Video processing failed");
      }

      setVideoResults(data);
      setProcessingStatus("Analysis complete!");
    } catch (err) {
      console.error("Video processing error:", err);
      setError(err.message);
      setProcessingStatus("");
    } finally {
      setIsProcessing(false);
    }
  };

  const handleVideoUpload = (e) => {
    const file = e.target.files?.[0];
    if (file) {
      console.log("Video file selected:", file.name, file.type, file.size);
      
      // Validate file type
      const validTypes = ['video/mp4', 'video/quicktime', 'video/x-msvideo', 'video/webm'];
      if (!validTypes.includes(file.type) && !file.name.match(/\.(mp4|mov|avi|webm)$/i)) {
        setError("Unsupported video format. Please use MP4, MOV, AVI, or WebM.");
        return;
      }
      
      // Validate file size (max 100MB)
      if (file.size > 100 * 1024 * 1024) {
        setError("Video file too large. Maximum size is 100MB.");
        return;
      }
      
      processVideoFile(file);
    }
  };

  /* ---------------- UI ---------------- */
  return (
    <div style={styles.page}>
      <video
        ref={videoRef}
        autoPlay
        playsInline
        muted
        style={{ display: "none", position: "absolute", top: -9999, left: -9999, width: 1, height: 1 }}
      />

      <div style={styles.container}>
        <header style={styles.header}>
          <h1 style={styles.title}>Face Trigger Detection</h1>
          <p style={styles.subtitle}>AI-powered attention monitoring system</p>
        </header>

        <div style={styles.modeSwitch}>
          <button
            onClick={() => {
              setMode("realtime");
              setVideoResults(null);
              setResult(null);
              setError(null);
              setProcessingStatus("");
            }}
            style={styles.modeBtn(mode === "realtime")}
          >
            <Camera size={20} /> Real-time Camera
          </button>
          <button
            onClick={() => {
              setMode("video");
              stopCamera();
              setResult(null);
              setError(null);
              setProcessingStatus("");
            }}
            style={styles.modeBtn(mode === "video")}
          >
            <Video size={20} /> Upload Video
          </button>
        </div>

        <main style={styles.main}>
          {mode === "realtime" && (
            <div style={styles.contentArea}>
              {/* Status bar */}
              <div style={styles.statusCard}>
                <div style={styles.statusHeader}>
                  <Circle
                    size={12}
                    fill={faceDetected ? "#10b981" : cameraActive ? "#ef4444" : "#6b7280"}
                    color={faceDetected ? "#10b981" : cameraActive ? "#ef4444" : "#6b7280"}
                  />
                  <span style={styles.statusText}>
                    {cameraActive
                      ? faceDetected
                        ? "Face Detected – Analyzing"
                        : "No Face Detected"
                      : "Camera Inactive"}
                  </span>
                </div>

                <button
                  onClick={cameraActive ? stopCamera : startCamera}
                  disabled={isProcessing && !cameraActive}
                  style={styles.cameraBtn(cameraActive)}
                >
                  {cameraActive ? (
                    <>
                      <Activity size={20} /> Stop Camera
                    </>
                  ) : (
                    <>
                      <Camera size={20} /> Start Camera
                    </>
                  )}
                </button>
              </div>

              {/* Main result area */}
              <div style={{ width: "100%", maxWidth: "800px", minHeight: "300px" }}>
                {cameraActive && !faceDetected && (
                  <div style={styles.noFaceResultArea}>
                    <EyeOff size={64} color="#9ca3af" strokeWidth={1.5} />
                    <h2 style={{ margin: "16px 0 8px", color: "#4b5563" }}>No Face Detected</h2>
                    <p style={{ color: "#6b7280", maxWidth: "420px", textAlign: "center" }}>
                      Please position your face clearly in front of the camera.<br />
                      Ensure good lighting and that your face is not too close or too far.
                    </p>
                  </div>
                )}

                {cameraActive && faceDetected && result && <ResultCard result={result} />}

                {!cameraActive && (
                  <div style={styles.instructionsCard}>
                    <h3 style={styles.instructionsTitle}>How it works</h3>
                    <ul style={styles.instructionsList}>
                      <li>Click "Start Camera" to begin real-time analysis</li>
                      <li>Your face must be clearly visible</li>
                      <li>Predictions appear every ~2 seconds</li>
                      <li>Privacy: No video is shown or stored</li>
                    </ul>
                  </div>
                )}
              </div>
            </div>
          )}

          {mode === "video" && (
            <div style={styles.contentArea}>
              <div style={styles.uploadCard}>
                <input
                  ref={videoFileRef}
                  type="file"
                  accept="video/*"
                  onChange={handleVideoUpload}
                  style={{ display: "none" }}
                />
                <button
                  onClick={() => videoFileRef.current?.click()}
                  disabled={isProcessing}
                  style={styles.uploadBtn(isProcessing)}
                >
                  {isProcessing ? (
                    <>
                      <Loader size={24} className="animate-spin" /> Processing Video...
                    </>
                  ) : (
                    <>
                      <Upload size={24} /> Upload Video
                    </>
                  )}
                </button>
                <p style={styles.uploadHint}>
                  Upload a video to analyze attention triggers over time
                </p>
                {processingStatus && (
                  <div style={styles.processingStatus}>
                    <Loader size={18} className="animate-spin" />
                    <span>{processingStatus}</span>
                  </div>
                )}
              </div>

              {videoResults && <VideoResultsCard results={videoResults} />}

              {!videoResults && !isProcessing && (
                <div style={styles.instructionsCard}>
                  <h3 style={styles.instructionsTitle}>Video Analysis</h3>
                  <ul style={styles.instructionsList}>
                    <li>Supports MP4, MOV, AVI and similar formats</li>
                    <li>Video is processed entirely on the server</li>
                    <li>Face detection + prediction per 2-second segment</li>
                    <li>Shows summary statistics and timeline</li>
                    <li>Max file size: 100MB</li>
                  </ul>
                </div>
              )}
            </div>
          )}

          {error && (
            <div style={styles.errorCard}>
              <AlertCircle size={24} color="#ef4444" />
              <div>
                <strong>Error:</strong> {error}
              </div>
            </div>
          )}
        </main>

        <footer style={styles.footer}>
          <p>
            🔒 Privacy-focused: Camera feed is never displayed or stored.  
            Real-time processing happens locally in your browser using MediaPipe.
            Video processing happens securely on the server.
          </p>
        </footer>
      </div>
    </div>
  );
}

/* ---------------- RESULT CARD ---------------- */
function ResultCard({ result }) {
  const isTrigger = result?.trigger_status === "trigger";

  return (
    <div style={styles.resultCard(isTrigger)}>
      <div style={styles.resultHeader}>
        {isTrigger ? (
          <AlertCircle size={40} color="#ef4444" />
        ) : (
          <CheckCircle size={40} color="#10b981" />
        )}
        <div>
          <h2 style={styles.resultTitle(isTrigger)}>
            {isTrigger ? "⚠️ Trigger Detected" : "✓ No Trigger"}
          </h2>
          <p style={styles.resultSubtitle}>
            Confidence: {(result?.confidence * 100 || 0).toFixed(1)}%
          </p>
        </div>
      </div>

      <div style={styles.resultDivider} />

      <div style={styles.resultBody}>
        <div style={styles.resultSection}>
          <strong style={styles.resultLabel}>Mood Status:</strong>
          <span style={styles.resultValue}>{result?.mood || "—"}</span>
        </div>

        <div style={styles.resultSection}>
          <strong style={styles.resultLabel}>Possible Environments:</strong>
          <div style={styles.envTags}>
            {(result?.possible_environments || []).map((env, idx) => (
              <span key={idx} style={styles.envTag(isTrigger)}>
                {env}
              </span>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

/* ---------------- VIDEO RESULTS ---------------- */
function VideoResultsCard({ results }) {
  const { segments = [], summary = {}, video_info = {} } = results || {};

  return (
    <div style={styles.videoResultsContainer}>
      <div style={styles.summaryCard}>
        <h3 style={styles.summaryTitle}>📊 Video Analysis Summary</h3>
        
        {video_info.filename && (
          <div style={styles.videoInfo}>
            <p><strong>File:</strong> {video_info.filename}</p>
            <p><strong>Duration:</strong> {video_info.duration}s @ {video_info.fps} fps</p>
            <p><strong>Frames:</strong> {video_info.total_frames} total</p>
          </div>
        )}
        
        <div style={styles.statsGrid}>
          <div style={styles.statBox}>
            <div style={styles.statValue}>{summary.total_segments || 0}</div>
            <div style={styles.statLabel}>Total Segments</div>
          </div>
          <div style={styles.statBox}>
            <div style={{ ...styles.statValue, color: "#ef4444" }}>
              {summary.trigger_segments || 0}
            </div>
            <div style={styles.statLabel}>Triggers Found</div>
          </div>
          <div style={styles.statBox}>
            <div style={{ ...styles.statValue, color: "#10b981" }}>
              {summary.non_trigger_segments || 0}
            </div>
            <div style={styles.statLabel}>Normal Segments</div>
          </div>
          <div style={styles.statBox}>
            <div style={styles.statValue}>{summary.trigger_percentage || 0}%</div>
            <div style={styles.statLabel}>Trigger Rate</div>
          </div>
        </div>
        
        {summary.top_trigger_moments && summary.top_trigger_moments.length > 0 && (
          <div style={styles.topMoments}>
            <h4 style={styles.topMomentsTitle}>🔥 Top Trigger Moments</h4>
            {summary.top_trigger_moments.map((moment, idx) => (
              <div key={idx} style={styles.topMoment}>
                <span>{moment.segment}</span>
                <span style={styles.topMomentConfidence}>{moment.confidence}%</span>
              </div>
            ))}
          </div>
        )}
      </div>

      <div style={styles.segmentsContainer}>
        <h3 style={styles.segmentsTitle}>Timeline Analysis</h3>
        <div style={styles.segmentsList}>
          {segments.map((seg, idx) => (
            <SegmentCard key={idx} segment={seg} />
          ))}
        </div>
      </div>
    </div>
  );
}

function SegmentCard({ segment }) {
  if (segment?.error) {
    return (
      <div style={styles.segmentError}>
        <strong>{segment?.segment || "—"}:</strong>{" "}
        {segment?.error || "No face detected in this segment"}
      </div>
    );
  }

  const isTrigger = segment.trigger_status === "trigger";

  return (
    <div style={styles.segmentCard(isTrigger)}>
      <div style={styles.segmentHeader}>
        <div style={styles.segmentTime}>
          {isTrigger ? (
            <AlertCircle size={18} color="#ef4444" />
          ) : (
            <CheckCircle size={18} color="#10b981" />
          )}
          <strong>{segment.segment}</strong>
        </div>
        <span style={styles.segmentConfidence(isTrigger)}>
          {(segment.confidence * 100).toFixed(1)}%
        </span>
      </div>
      <div style={styles.segmentEnvs}>
        {segment.possible_environments?.slice(0, 3).map((env, i) => (
          <span key={i} style={styles.segmentEnvTag}>
            {env}
          </span>
        ))}
      </div>
    </div>
  );
}

/* ---------------- STYLES ---------------- */
const styles = {
  page: {
    minHeight: "100vh",
    background: "linear-gradient(135deg, #667eea 0%, #764ba2 100%)",
    padding: "20px",
    fontFamily: "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif",
  },
  container: {
    maxWidth: "1400px",
    margin: "0 auto",
    width: "100%",
  },
  header: {
    textAlign: "center",
    marginBottom: "40px",
    color: "#fff",
  },
  title: {
    fontSize: "clamp(2rem, 5vw, 3.5rem)",
    fontWeight: "800",
    marginBottom: "10px",
    textShadow: "0 4px 6px rgba(0,0,0,0.1)",
  },
  subtitle: {
    fontSize: "clamp(1rem, 2vw, 1.3rem)",
    opacity: 0.9,
    margin: 0,
  },
  modeSwitch: {
    display: "flex",
    justifyContent: "center",
    gap: "20px",
    marginBottom: "30px",
    flexWrap: "wrap",
  },
  modeBtn: (active) => ({
    padding: "16px 32px",
    fontSize: "clamp(0.9rem, 1.5vw, 1.1rem)",
    fontWeight: "600",
    border: "none",
    borderRadius: "12px",
    cursor: "pointer",
    display: "flex",
    alignItems: "center",
    gap: "10px",
    background: active ? "#fff" : "rgba(255,255,255,0.2)",
    color: active ? "#667eea" : "#fff",
    transition: "all 0.3s",
    boxShadow: active ? "0 8px 16px rgba(0,0,0,0.2)" : "none",
  }),
  main: {
    background: "#fff",
    borderRadius: "24px",
    padding: "clamp(20px, 4vw, 50px)",
    minHeight: "60vh",
  },
  contentArea: {
    display: "flex",
    flexDirection: "column",
    gap: "30px",
    alignItems: "center",
    width: "100%",
  },
  statusCard: {
    width: "100%",
    maxWidth: "600px",
    padding: "24px",
    background: "#f9fafb",
    borderRadius: "16px",
    display: "flex",
    flexDirection: "column",
    gap: "16px",
  },
  statusHeader: {
    display: "flex",
    alignItems: "center",
    gap: "10px",
    justifyContent: "center",
  },
  statusText: {
    fontSize: "clamp(0.9rem, 1.5vw, 1rem)",
    color: "#374151",
    fontWeight: "500",
  },
  cameraBtn: (active) => ({
    padding: "16px 32px",
    fontSize: "clamp(1rem, 1.5vw, 1.1rem)",
    fontWeight: "600",
    borderRadius: "12px",
    border: active ? "2px solid #ef4444" : "none",
    background: active ? "#fff" : "linear-gradient(135deg, #667eea 0%, #764ba2 100%)",
    color: active ? "#ef4444" : "#fff",
    cursor: "pointer",
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    gap: "10px",
    transition: "all 0.3s",
    width: "100%",
    maxWidth: "300px",
    margin: "0 auto",
  }),
  noFaceResultArea: {
    display: "flex",
    flexDirection: "column",
    alignItems: "center",
    justifyContent: "center",
    padding: "60px 20px",
    background: "#f9fafb",
    borderRadius: "20px",
    border: "2px dashed #d1d5db",
  },
  processingStatus: {
    display: "flex",
    alignItems: "center",
    gap: "12px",
    padding: "12px 20px",
    background: "#eff6ff",
    borderRadius: "8px",
    color: "#1e40af",
    fontSize: "clamp(0.85rem, 1.2vw, 0.95rem)",
    fontWeight: "500",
  },
  resultCard: (isTrigger) => ({
    width: "100%",
    maxWidth: "800px",
    padding: "clamp(20px, 4vw, 40px)",
    background: isTrigger ? "#fef2f2" : "#f0fdf4",
    border: `3px solid ${isTrigger ? "#ef4444" : "#10b981"}`,
    borderRadius: "20px",
    boxShadow: "0 10px 25px rgba(0,0,0,0.1)",
  }),
  resultHeader: {
    display: "flex",
    alignItems: "center",
    gap: "20px",
    marginBottom: "20px",
    flexWrap: "wrap",
  },
  resultTitle: (isTrigger) => ({
    fontSize: "clamp(1.3rem, 3vw, 2rem)",
    fontWeight: "700",
    color: isTrigger ? "#ef4444" : "#10b981",
    margin: 0,
  }),
  resultSubtitle: {
    fontSize: "clamp(0.9rem, 1.5vw, 1.1rem)",
    color: "#6b7280",
    margin: "5px 0 0",
  },
  resultDivider: {
    height: "2px",
    background: "#e5e7eb",
    margin: "20px 0",
  },
  resultBody: {
    display: "flex",
    flexDirection: "column",
    gap: "20px",
  },
  resultSection: {
    display: "flex",
    flexDirection: "column",
    gap: "10px",
  },
  resultLabel: {
    fontSize: "clamp(1rem, 1.5vw, 1.1rem)",
    color: "#374151",
  },
  resultValue: {
    fontSize: "clamp(1.1rem, 2vw, 1.3rem)",
    color: "#1f2937",
  },
  envTags: {
    display: "flex",
    flexWrap: "wrap",
    gap: "10px",
  },
  envTag: (isTrigger) => ({
    padding: "8px 16px",
    background: isTrigger ? "#fee2e2" : "#dcfce7",
    border: `1px solid ${isTrigger ? "#fecaca" : "#bbf7d0"}`,
    borderRadius: "20px",
    fontSize: "clamp(0.85rem, 1.2vw, 0.95rem)",
    fontWeight: "500",
    color: isTrigger ? "#991b1b" : "#166534",
  }),
  uploadCard: {
    width: "100%",
    maxWidth: "600px",
    padding: "40px",
    background: "#f9fafb",
    borderRadius: "16px",
    display: "flex",
    flexDirection: "column",
    alignItems: "center",
    gap: "20px",
    textAlign: "center",
  },
  uploadBtn: (disabled) => ({
    padding: "16px 32px",
    fontSize: "clamp(1rem, 1.5vw, 1.1rem)",
    fontWeight: "600",
    border: "none",
    borderRadius: "12px",
    cursor: disabled ? "not-allowed" : "pointer",
    background: disabled ? "#9ca3af" : "linear-gradient(135deg, #667eea 0%, #764ba2 100%)",
    color: "#fff",
    display: "flex",
    alignItems: "center",
    gap: "10px",
    opacity: disabled ? 0.6 : 1,
  }),
  uploadHint: {
    fontSize: "clamp(0.85rem, 1.2vw, 0.95rem)",
    color: "#6b7280",
    margin: 0,
  },
  instructionsCard: {
    width: "100%",
    maxWidth: "700px",
    padding: "30px",
    background: "#f0f9ff",
    borderRadius: "16px",
    border: "2px solid #bfdbfe",
  },
  instructionsTitle: {
    fontSize: "clamp(1.1rem, 2vw, 1.3rem)",
    color: "#1e40af",
    marginBottom: "15px",
  },
  instructionsList: {
    fontSize: "clamp(0.9rem, 1.3vw, 1rem)",
    color: "#374151",
    lineHeight: "1.8",
    paddingLeft: "20px",
    margin: 0,
  },
  errorCard: {
    padding: "20px",
    background: "#fee",
    border: "2px solid #ef4444",
    borderRadius: "12px",
    color: "#ef4444",
    display: "flex",
    alignItems: "center",
    gap: "10px",
    width: "100%",
    maxWidth: "700px",
    fontSize: "clamp(0.9rem, 1.3vw, 1rem)",
  },
  videoResultsContainer: {
    width: "100%",
    display: "flex",
    flexDirection: "column",
    gap: "30px",
  },
  summaryCard: {
    padding: "30px",
    background: "linear-gradient(135deg, #667eea 0%, #764ba2 100%)",
    borderRadius: "20px",
    color: "#fff",
  },
  summaryTitle: {
    fontSize: "clamp(1.3rem, 2.5vw, 1.8rem)",
    fontWeight: "700",
    marginBottom: "20px",
  },
  videoInfo: {
    fontSize: "clamp(0.85rem, 1.2vw, 0.95rem)",
    marginBottom: "20px",
    opacity: 0.95,
    lineHeight: 1.6,
  },
  statsGrid: {
    display: "grid",
    gridTemplateColumns: "repeat(auto-fit, minmax(150px, 1fr))",
    gap: "20px",
    marginBottom: "20px",
  },
  statBox: {
    textAlign: "center",
  },
  statValue: {
    fontSize: "clamp(2rem, 4vw, 3rem)",
    fontWeight: "700",
  },
  statLabel: {
    fontSize: "clamp(0.85rem, 1.2vw, 1rem)",
    opacity: 0.9,
    marginTop: "5px",
  },
  topMoments: {
    marginTop: "20px",
    padding: "20px",
    background: "rgba(255,255,255,0.1)",
    borderRadius: "12px",
    backdropFilter: "blur(10px)",
  },
  topMomentsTitle: {
    fontSize: "clamp(1rem, 1.5vw, 1.2rem)",
    marginBottom: "12px",
  },
  topMoment: {
    display: "flex",
    justifyContent: "space-between",
    alignItems: "center",
    padding: "8px 0",
    fontSize: "clamp(0.85rem, 1.2vw, 0.95rem)",
  },
  topMomentConfidence: {
    fontWeight: "700",
    fontSize: "clamp(1rem, 1.5vw, 1.1rem)",
  },
  segmentsContainer: {
    width: "100%",
  },
  segmentsTitle: {
    fontSize: "clamp(1.2rem, 2vw, 1.5rem)",
    fontWeight: "600",
    marginBottom: "20px",
    color: "#1f2937",
  },
  segmentsList: {
    display: "grid",
    gridTemplateColumns: "repeat(auto-fill, minmax(280px, 1fr))",
    gap: "15px",
  },
  segmentCard: (isTrigger) => ({
    padding: "16px",
    background: "#fff",
    border: `2px solid ${isTrigger ? "#ef4444" : "#e5e7eb"}`,
    borderRadius: "12px",
    transition: "all 0.3s",
  }),
  segmentHeader: {
    display: "flex",
    justifyContent: "space-between",
    alignItems: "center",
    marginBottom: "10px",
  },
  segmentTime: {
    display: "flex",
    alignItems: "center",
    gap: "8px",
    fontSize: "clamp(0.9rem, 1.3vw, 1rem)",
  },
  segmentConfidence: (isTrigger) => ({
    padding: "4px 12px",
    background: isTrigger ? "#fee2e2" : "#dcfce7",
    color: isTrigger ? "#991b1b" : "#166534",
    borderRadius: "12px",
    fontSize: "clamp(0.8rem, 1.1vw, 0.9rem)",
    fontWeight: "600",
  }),
  segmentEnvs: {
    display: "flex",
    flexWrap: "wrap",
    gap: "6px",
  },
  segmentEnvTag: {
    padding: "4px 10px",
    background: "#f3f4f6",
    borderRadius: "12px",
    fontSize: "clamp(0.75rem, 1vw, 0.85rem)",
    color: "#6b7280",
  },
  segmentError: {
    padding: "16px",
    background: "#fee",
    border: "1px solid #fcc",
    borderRadius: "12px",
    color: "#c44",
    fontSize: "clamp(0.85rem, 1.2vw, 0.9rem)",
  },
  footer: {
    marginTop: "40px",
    padding: "20px",
    textAlign: "center",
    color: "#fff",
    opacity: 0.9,
    fontSize: "clamp(0.85rem, 1.2vw, 0.95rem)",
    background: "rgba(255,255,255,0.1)",
    borderRadius: "12px",
    backdropFilter: "blur(10px)",
  },
};