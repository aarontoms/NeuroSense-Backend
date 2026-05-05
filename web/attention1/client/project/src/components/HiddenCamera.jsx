import { useEffect, useRef, useState } from 'react';

export default function HiddenCamera({ onLandmarks, isActive, studentId }) {
  const videoRef = useRef(null);
  const faceMeshRef = useRef(null);
  const cameraRef = useRef(null);
  const lastSentRef = useRef(0);
  const [error, setError] = useState(null);

  const SEND_INTERVAL = 120;

  useEffect(() => {
    if (!isActive || !studentId) return;

    const videoElement = videoRef.current;
    if (!videoElement) return;

    let stopped = false;

    (async () => {
      try {
        // Try ESM imports first; fall back to loading via CDN script tags
        let FaceMeshCtor, CameraCtor;
        try {
          const fm = await import('@mediapipe/face_mesh');
          const cu = await import('@mediapipe/camera_utils');
          FaceMeshCtor = fm.FaceMesh || fm.default?.FaceMesh;
          CameraCtor = cu.Camera || cu.default?.Camera;
        } catch (_) {
          FaceMeshCtor = undefined;
          CameraCtor = undefined;
        }

        if (!FaceMeshCtor || !CameraCtor) {
          // Dynamically load UMD scripts from CDN to get window.FaceMesh and window.Camera
          const loadScript = (src) => new Promise((resolve, reject) => {
            const s = document.createElement('script');
            s.src = src; s.async = true; s.onload = resolve; s.onerror = reject; document.head.appendChild(s);
          });
          await loadScript('https://cdn.jsdelivr.net/npm/@mediapipe/face_mesh/face_mesh.js');
          await loadScript('https://cdn.jsdelivr.net/npm/@mediapipe/camera_utils/camera_utils.js');
          FaceMeshCtor = window.FaceMesh;
          CameraCtor = window.Camera;
        }

        const faceMesh = new FaceMeshCtor({
          locateFile: (file) => `https://cdn.jsdelivr.net/npm/@mediapipe/face_mesh/${file}`
        });

        faceMesh.setOptions({
          maxNumFaces: 1,
          refineLandmarks: true,
          minDetectionConfidence: 0.5,
          minTrackingConfidence: 0.5
        });

        faceMesh.onResults((results) => {
          if (stopped) return;
          const faces = results.multiFaceLandmarks || [];
          if (faces.length === 0) return;

          const now = performance.now();
          if (now - lastSentRef.current < SEND_INTERVAL) return;
          lastSentRef.current = now;

          const landmarks = faces[0].map(lm => ({ x: lm.x, y: lm.y, z: lm.z }));

          const imageW = results.image?.width || 640;
          const imageH = results.image?.height || 480;

          const payload = {
            student_id: studentId,
            ts: Date.now() / 1000,
            image_w: imageW,
            image_h: imageH,
            landmarks
          };

          onLandmarks?.(payload);
        });

        faceMeshRef.current = faceMesh;

        // Prefer native getUserMedia to ensure permission prompt on HTTPS
        const constraints = { video: { width: 640, height: 480 }, audio: false };
        try {
          const stream = await navigator.mediaDevices.getUserMedia(constraints);
          videoElement.srcObject = stream;
          await videoElement.play().catch(() => {});
        } catch (permErr) {
          console.error('getUserMedia error:', permErr);
          setError('Camera permission denied. Please allow camera access.');
          return;
        }

        const camera = new CameraCtor(videoElement, {
          onFrame: async () => {
            if (!stopped && faceMeshRef.current && videoElement.readyState === 4) {
              await faceMeshRef.current.send({ image: videoElement });
            }
          },
          width: 640,
          height: 480
        });

        camera.start().catch((err) => {
          console.error('Camera start error:', err);
          setError('Failed to access camera. Please grant camera permissions.');
        });

        cameraRef.current = camera;
      } catch (e) {
        console.error('FaceMesh init error:', e);
        setError('Failed to initialize face tracking.');
      }
    })();

    return () => {
      stopped = true;
      if (cameraRef.current) {
        try { cameraRef.current.stop(); } catch {}
      }
      const stream = videoElement?.srcObject;
      if (stream && typeof stream.getTracks === 'function') {
        stream.getTracks().forEach(t => t.stop());
      }
    };
  }, [isActive, studentId, onLandmarks]);

  return (
    <div>
      <video
        ref={videoRef}
        style={{ display: 'none' }}
        playsInline
      />
      {error && (
        <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded">
          {error}
        </div>
      )}
    </div>
  );
}
