
from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
import numpy as np
import time
import os
import threading
import traceback
from collections import deque
import math

# Optional OpenCV for head-pose
try:
    import cv2
    OPENCV_AVAILABLE = True
except Exception:
    cv2 = None
    OPENCV_AVAILABLE = False

# MediaPipe face mesh (server-side fallback)
try:
    import mediapipe as mp
    mp_face = mp.solutions.face_mesh.FaceMesh(max_num_faces=1)
    MEDIAPIPE_AVAILABLE = True
except Exception:
    mp_face = None
    MEDIAPIPE_AVAILABLE = False

# MongoDB (replace connection string as needed)
from pymongo import MongoClient
from bson import ObjectId

MONGO_URI = os.environ.get("MONGO_URI", "mongodb+srv://sagaraliyas005:aravind000005@ard.dojeoia.mongodb.net/")
client = MongoClient(MONGO_URI)
db = client.get_database("attention_db")

# Main database collections
users_collection = db["users"]
stimuli_collection = db["stimuli"]
voice_profiles_collection = db["voice_profiles"]
sessions_collection = db["sessions"]
student_auth_collection = db["student_auth"]
stimulus_tracking_collection = db["stimulus_tracking"]

# Analytics collections (stored within attention_db)
detailed_analysis_collection = db["detailed_analysis"]
student_summary_collection = db["student_summary"]
stimulus_summary_collection = db["stimulus_summary"]

# Flask app
app = Flask(__name__)
CORS(app)

# ---------------- CONFIG ----------------
WINDOW_SECONDS = 6
ALERT_ATTENTION_THRESHOLD = 0.35
NO_FACE_THRESHOLD = 4.0
CONSECUTIVE_LOW_FRAMES = 3
GOOD_FRAMES_TO_CLEAR = 2
W_GAZE = 0.65
W_HEAD = 0.35
HEAD_YAW_ALERT_DEG = 25.0
HEAD_PITCH_ALERT_DEG = 18.0
HEAD_POSE_MAX_ABS_DEG = 80.0
GAZE_H_WEIGHT = 2.0
GAZE_V_WEIGHT = 1.4
ALPHA_ATT = 0.45
ALPHA_HEAD = 0.35
INSTANT_CLEAR_ATT = 0.70
MAX_FRAMES_KEEP = 2000

_MODEL_POINTS = np.array([
    (0.0, 0.0, 0.0),
    (0.0, -63.6, -12.5),
    (-43.3, 32.7, -26.0),
    (43.3, 32.7, -26.0),
    (-28.9, -28.9, -24.1),
    (28.9, -28.9, -24.1)
], dtype=np.float64)
HP_IDX = {
    "nose_tip": 1,
    "chin": 152,
    "left_eye_left": 263,
    "right_eye_right": 33,
    "left_mouth": 291,
    "right_mouth": 61
}

# ---------------- In-memory sessions (store runtime state) ----------------
# active_sessions keyed by student_id
active_sessions = {}

# ---------------- Utilities ----------------

def clamp(v, a=0.0, b=1.0):
    return max(a, min(b, v))

# ---------------- Head pose (solvePnP) ----------------

def compute_head_pose_from_landmarks(landmarks, image_w=640, image_h=480):
    if not OPENCV_AVAILABLE:
        return None, None, None
    try:
        def lm(idx):
            p = landmarks[idx]
            return (p['x'] * image_w, p['y'] * image_h)

        image_points = np.array([
            lm(HP_IDX['nose_tip']),
            lm(HP_IDX['chin']),
            lm(HP_IDX['left_eye_left']),
            lm(HP_IDX['right_eye_right']),
            lm(HP_IDX['left_mouth']),
            lm(HP_IDX['right_mouth'])
        ], dtype=np.float64)

        focal_length = image_w
        center = (image_w / 2.0, image_h / 2.0)
        camera_matrix = np.array([[focal_length, 0, center[0]], [0, focal_length, center[1]], [0, 0, 1]], dtype=np.float64)
        dist_coeffs = np.zeros((4, 1))

        success, rotation_vector, _ = cv2.solvePnP(_MODEL_POINTS, image_points, camera_matrix, dist_coeffs, flags=cv2.SOLVEPNP_ITERATIVE)
        if not success:
            return None, None, None

        rmat, _ = cv2.Rodrigues(rotation_vector)
        sy = math.sqrt(rmat[0, 0] * rmat[0, 0] + rmat[1, 0] * rmat[1, 0])
        singular = sy < 1e-6
        if not singular:
            x = math.atan2(rmat[2, 1], rmat[2, 2])
            y = math.atan2(-rmat[2, 0], sy)
            z = math.atan2(rmat[1, 0], rmat[0, 0])
        else:
            x = math.atan2(-rmat[1, 2], rmat[1, 1])
            y = math.atan2(-rmat[2, 0], sy)
            z = 0
        pitch = math.degrees(x)
        yaw = math.degrees(y)
        roll = math.degrees(z)
        return float(yaw), float(pitch), float(roll)
    except Exception:
        traceback.print_exc()
        return None, None, None

# ---------------- Gaze & eye metrics ----------------

def compute_gaze_eye(landmarks):
    try:
        if not landmarks or len(landmarks) < 10:
            return 0.0, False, False, {}

        def pt(i):
            return np.array([landmarks[i]['x'], landmarks[i]['y']])

        left_eye_idx = [33, 160, 158, 133, 153, 144]
        right_eye_idx = [263, 387, 385, 362, 380, 373]

        def ear(indices):
            a = np.linalg.norm(pt(indices[1]) - pt(indices[5]))
            b = np.linalg.norm(pt(indices[2]) - pt(indices[4]))
            c = np.linalg.norm(pt(indices[0]) - pt(indices[3])) + 1e-9
            return (a + b) / (2.0 * c)

        ear_left = ear(left_eye_idx)
        ear_right = ear(right_eye_idx)
        ear_avg = (ear_left + ear_right) / 2.0
        blink = ear_avg < 0.20

        LEFT_IRIS = [474, 475, 476, 477]
        RIGHT_IRIS = [469, 470, 471, 472]
        iris_present = max(LEFT_IRIS + RIGHT_IRIS) < len(landmarks)

        gaze_offset_x = 0.0
        gaze_offset_y = 0.0
        gaze_score = 0.0
        looking_forward = True

        if iris_present:
            left_iris = np.mean([np.array([landmarks[i]['x'], landmarks[i]['y']]) for i in LEFT_IRIS], axis=0)
            right_iris = np.mean([np.array([landmarks[i]['x'], landmarks[i]['y']]) for i in RIGHT_IRIS], axis=0)
            left_inner = np.array([landmarks[362]['x'], landmarks[362]['y']])
            left_outer = np.array([landmarks[263]['x'], landmarks[263]['y']])
            right_inner = np.array([landmarks[33]['x'], landmarks[33]['y']])
            right_outer = np.array([landmarks[133]['x'], landmarks[133]['y']])

            left_center = (left_inner + left_outer) / 2.0
            right_center = (right_inner + right_outer) / 2.0
            left_width = np.linalg.norm(left_inner - left_outer) + 1e-9
            right_width = np.linalg.norm(right_inner - right_outer) + 1e-9
            left_rel = (left_iris - left_center) / left_width
            right_rel = (right_iris - right_center) / right_width
            gaze_offset_x = float((left_rel[0] + right_rel[0]) / 2.0)
            gaze_offset_y = float((left_rel[1] + right_rel[1]) / 2.0)
            combined_offset = abs(gaze_offset_x) * GAZE_H_WEIGHT + abs(gaze_offset_y) * GAZE_V_WEIGHT
            gaze_score = clamp(1.0 - combined_offset, 0.0, 1.0)
            looking_forward = abs(gaze_offset_x) < 0.30 and abs(gaze_offset_y) < 0.40
        else:
            left_center = np.mean([pt(i) for i in left_eye_idx], axis=0)
            right_center = np.mean([pt(i) for i in right_eye_idx], axis=0)
            mid_eye = (left_center + right_center) / 2.0
            nose = pt(1)
            gaze_raw = np.linalg.norm(nose - mid_eye)
            gaze_score = clamp(1.0 - gaze_raw * 1.5, 0.0, 1.0)
            gaze_offset_x = float(nose[0] - mid_eye[0])
            gaze_offset_y = float(nose[1] - mid_eye[1])
            looking_forward = abs(nose[1] - mid_eye[1]) < 0.045

        face_width = np.linalg.norm(pt(33) - pt(263)) + 1e-9
        left_open = np.linalg.norm(pt(386) - pt(374)) if 386 < len(landmarks) else 0.0
        right_open = np.linalg.norm(pt(159) - pt(145)) if 159 < len(landmarks) else 0.0
        eye_open_norm = (left_open + right_open) / (2.0 * face_width + 1e-9)
        eye_open_score = clamp((eye_open_norm - 0.02) / (0.18 - 0.02), 0.0, 1.0)

        gaze_eye_score = float(clamp(0.65 * gaze_score + 0.35 * eye_open_score, 0.0, 1.0))
        subs = {
            "gaze_offset_x": gaze_offset_x,
            "gaze_offset_y": gaze_offset_y,
            "gaze_score": float(gaze_score),
            "eye_open_score": float(eye_open_score),
            "ear": float(ear_avg)
        }
        return gaze_eye_score, bool(looking_forward), bool(blink), subs
    except Exception:
        traceback.print_exc()
        return 0.0, False, False, {}

# ---------------- Calibration helpers ----------------

def fit_affine_from_samples(samples):
    if not samples or len(samples) < 3:
        return None
    A = []
    B = []
    for gx, gy, sx, sy in samples:
        A.append([gx, gy, 1, 0, 0, 0]); B.append(sx)
        A.append([0, 0, 0, gx, gy, 1]); B.append(sy)
    A = np.array(A, dtype=float); B = np.array(B, dtype=float)
    try:
        x, *_ = np.linalg.lstsq(A, B, rcond=None)
        params = {"a1": float(x[0]), "a2": float(x[1]), "b1": float(x[2]), "c1": float(x[3]), "c2": float(x[4]), "b2": float(x[5])}
        return params
    except Exception:
        return None


def apply_affine(params, gx, gy):
    if not params:
        return None, None
    sx = params["a1"] * gx + params["a2"] * gy + params["b1"]
    sy = params["c1"] * gx + params["c2"] * gy + params["b2"]
    return float(sx), float(sy)

# ---------------- Stimulus & voice helpers ----------------

def save_voice_file(student_id, prefix, audio_bytes, ext="wav"):
    os.makedirs("voice_clones", exist_ok=True)
    filename = f"{student_id}_{prefix}.{ext}"
    filepath = os.path.join("voice_clones", filename)
    with open(filepath, "wb") as f:
        f.write(audio_bytes)
    return filename


def get_voice_url(student_id):
    profile = voice_profiles_collection.find_one({"student_id": student_id})
    if not profile or "voice_file_name" not in profile:
        return None
    return f"/voice/{profile['voice_file_name']}"


def should_play_voice_helper(student_id, voice_on_low_attention, voice_threshold):
    """Evaluate if voice should play based on current attention level."""
    sess = active_sessions.get(student_id)
    recent_frames = list(sess["frames"]) if sess and "frames" in sess else []
    recent_vals = [f.get("smoothed_att", f.get("attention_score", 0.0)) for f in recent_frames[-30:]] if recent_frames else []
    recent_avg = float(np.mean(recent_vals)) if recent_vals else 0.8
    
    # Only play voice if voice_on_low_attention=True AND attention is low
    if voice_on_low_attention:
        return recent_avg < voice_threshold
    else:
        # If voice_on_low_attention=False, never auto-play voice
        return False


def get_next_stimulus(student_id, current_index):
    all_stimuli = list(stimuli_collection.find({}, {"_id": 0}))
    if current_index >= len(all_stimuli):
        return None
    return all_stimuli[current_index]

# ---------------- Stimulus timer flow (background chain) ----------------

def start_stimulus_timer(student_id, voice_duration=10, stimulus_duration=30):
    def timer_func():
        print(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] Timer started for {student_id}: voice {voice_duration}s then stimulus {stimulus_duration}s")
        time.sleep(voice_duration)
        session = active_sessions.get(student_id)
        if not session:
            print(f"No session for {student_id} after voice")
            return
        if session.get("terminated"):
            print(f"Session terminated for {student_id} before stimulus")
            return
        # Ensure a current stimulus is set
        if not session.get('current_stimulus'):
            idx = session.get('stimulus_index', 0)
            next_stim = get_next_stimulus(student_id, idx)
            if next_stim:
                session['current_stimulus'] = next_stim
            else:
                print(f"No stimuli available for {student_id} when starting stimulus")
                session['next_instruction'] = {"action": "session_complete"}
                return
        # Start stimulus
        try:
            session['analysis_active'] = True
            session['next_instruction'] = {
                "action": "play_stimulus",
                "stimulus_id": session['current_stimulus']['stimulus_id'],
                "stimulus_name": session['current_stimulus'].get('name'),
                "stimulus_url": f"/stimuli/{os.path.basename(session['current_stimulus']['file_path'])}",
                "voice_url": get_voice_url(student_id) if voice_duration > 0 else None
            }
            print(f"Queued stimulus for {student_id}")
        except Exception as e:
            print("Error queuing stimulus:", e)
            session['next_instruction'] = {"action": "error", "message": str(e)}

        # wait for stimulus duration while collecting frames
        time.sleep(stimulus_duration)
        session = active_sessions.get(student_id)
        if not session or not session.get('current_stimulus'):
            print(f"Session or current_stimulus not found for {student_id}")
            return
        if session.get("terminated"):
            print(f"Session terminated for {student_id} during stimulus")
            return
        
        current_stimulus = session['current_stimulus']
        if not current_stimulus:
            print(f"Invalid stimulus data for {student_id}")
            return
        
        # Use analysis_frames collected during stimulus playback; fallback to full frames deque snapshot
        analysis_frames = session.get('analysis_frames', [])
        if not analysis_frames:
            try:
                analysis_frames = list(session.get('frames', []))
            except Exception:
                analysis_frames = []
        
        # Store detailed frame data in stimulus_tracking collection
        if analysis_frames:
            stimulus_tracking_collection.insert_one({
                "student_id": student_id,
                "stimulus_id": current_stimulus.get('stimulus_id'),
                "stimulus_name": current_stimulus.get('name'),
                "frames_data": [
                    {
                        "timestamp": f['ts'],
                        "attention_score": f.get('attention_score'),
                        "smoothed_att": f.get('smoothed_att'),
                        "face_detected": f.get('face'),
                        "on_screen": f.get('on_screen'),
                        "blink": f.get('blink'),
                        "yaw": f.get('yaw'),
                        "pitch": f.get('pitch')
                    }
                    for f in analysis_frames
                ],
                "timestamp": time.time()
            })
        
        if analysis_frames:
            valid_vals = [f.get('smoothed_att', f.get('attention_score', 0.0)) for f in analysis_frames if f is not None]
            valid_vals = [v for v in valid_vals if isinstance(v, (int, float))]
            avg_attention = float(np.mean(valid_vals)) if valid_vals else 0.0
            max_attention = float(np.max(valid_vals)) if valid_vals else 0.0
            min_attention = float(np.min(valid_vals)) if valid_vals else 0.0
            blink_count = int(sum([1 for f in analysis_frames if f.get('blink')]))
            frames_with_face = int(sum([1 for f in analysis_frames if f.get('face')]))
            frames_on_screen = int(sum([1 for f in analysis_frames if f.get('on_screen')]))
            
            # Calculate attention distribution
            def val(f):
                return f.get('smoothed_att', f.get('attention_score', 0.0))
            high_attention_frames = int(sum([1 for f in analysis_frames if val(f) >= 0.7]))
            medium_attention_frames = int(sum([1 for f in analysis_frames if 0.35 <= val(f) < 0.7]))
            low_attention_frames = int(sum([1 for f in analysis_frames if val(f) < 0.35]))
        else:
            avg_attention = 0.0
            max_attention = 0.0
            min_attention = 0.0
            blink_count = 0
            frames_with_face = 0
            frames_on_screen = 0
            high_attention_frames = 0
            medium_attention_frames = 0
            low_attention_frames = 0
        
        try:
            # Store in sessions collection (simple summary)
            sessions_collection.insert_one({
                "student_id": student_id,
                "stimulus_id": current_stimulus.get('stimulus_id'),
                "stimulus_name": current_stimulus.get('name'),
                "avg_attention": avg_attention,
                "blink_count": blink_count,
                "frames_collected": len(analysis_frames),
                "timestamp": time.time()
            })
            
            # Store in detailed_analysis collection (detailed data)
            # Store detailed analytics
            detailed_analysis_collection.insert_one({
                "student_id": student_id,
                "stimulus_id": current_stimulus.get('stimulus_id'),
                "stimulus_name": current_stimulus.get('name'),
                "avg_attention": avg_attention,
                "max_attention": max_attention,
                "min_attention": min_attention,
                "blink_count": blink_count,
                "frames_collected": len(analysis_frames),
                "frames_with_face": frames_with_face,
                "frames_on_screen": frames_on_screen,
                "high_attention_frames": high_attention_frames,
                "medium_attention_frames": medium_attention_frames,
                "low_attention_frames": low_attention_frames,
                "attention_distribution": {
                    "high": high_attention_frames,
                    "medium": medium_attention_frames,
                    "low": low_attention_frames
                },
                "timestamp": time.time(),
                "duration_seconds": stimulus_duration
            })

            # Upsert per-student summary
            student_summary_collection.update_one(
                {"student_id": student_id},
                {
                    "$set": {"student_id": student_id},
                    "$inc": {
                        "total_sessions": 1,
                        "total_frames": len(analysis_frames),
                        "total_blinks": blink_count,
                        "high_frames": high_attention_frames,
                        "medium_frames": medium_attention_frames,
                        "low_frames": low_attention_frames
                    },
                    "$max": {"best_attention": avg_attention},
                    "$push": {
                        "sessions": {
                            "timestamp": time.time(),
                            "stimulus_id": current_stimulus.get('stimulus_id'),
                            "stimulus_name": current_stimulus.get('name'),
                            "avg_attention": avg_attention,
                            "frames": len(analysis_frames)
                        }
                    }
                },
                upsert=True
            )

            # Upsert per-stimulus summary
            stimulus_summary_collection.update_one(
                {"stimulus_id": current_stimulus.get('stimulus_id')},
                {
                    "$set": {"stimulus_id": current_stimulus.get('stimulus_id'), "stimulus_name": current_stimulus.get('name'), "last_avg_attention": avg_attention},
                    "$inc": {
                        "total_sessions": 1,
                        "total_frames": len(analysis_frames),
                        "total_blinks": blink_count,
                        "high_frames": high_attention_frames,
                        "medium_frames": medium_attention_frames,
                        "low_frames": low_attention_frames
                    }
                },
                upsert=True
            )
            print(f"Stored detailed analysis for {student_id}: avg_attention={avg_attention:.3f}, frames={len(analysis_frames)}")
        except Exception as e:
            print("Error storing session to DB:", e)
            traceback.print_exc()

        # Reset session analysis
        session['analysis_active'] = False
        session['analysis_frames'] = []  # Clear analysis frames
        session['stimulus_index'] = session.get('stimulus_index', 0) + 1
        next_stim = get_next_stimulus(student_id, session['stimulus_index'])
        if next_stim:
            session['current_stimulus'] = next_stim
            # Update per-stimulus duration for next stimulus
            next_duration = int(next_stim.get("duration_seconds", session.get("stimulus_duration", stimulus_duration)))
            session['stimulus_duration'] = next_duration
            
            # Re-evaluate attention before queuing next stimulus
            voice_on_low = session.get('voice_on_low_attention', False)
            voice_thresh = session.get('voice_threshold', 0.4)
            play_voice_next = should_play_voice_helper(student_id, voice_on_low, voice_thresh) if voice_on_low else False
            next_voice_duration = session.get('base_voice_duration', 10) if play_voice_next else 0
            session['voice_duration'] = next_voice_duration
            
            session['next_instruction'] = {"action": "play_voice", "voice_url": get_voice_url(student_id) if next_voice_duration > 0 else None}
            # chain next timer with re-evaluated voice duration and new stimulus duration
            threading.Thread(
                target=start_stimulus_timer,
                args=(student_id, next_voice_duration, next_duration),
                daemon=True
            ).start()
        else:
            session['next_instruction'] = {"action": "session_complete"}
            print(f"Session complete for {student_id}")

    threading.Thread(target=timer_func, daemon=True).start()

# ------------------ Endpoints: Static file serving ------------------

@app.route('/stimuli/<filename>')
def serve_stimulus(filename):
    return send_from_directory('stimuli', filename)

@app.route('/voice/<filename>')
def serve_voice(filename):
    return send_from_directory('voice_clones', filename)

# NOTE: Authentication is handled by the NeuroSense main backend.
# The Flutter app passes the authenticated user_id as student_id
# to all endpoints below. No separate login is needed here.


@app.route("/upload_voice/<student_id>", methods=["POST"])
def upload_voice(student_id):
    if "file" not in request.files:
        return jsonify({"error": "Missing audio file"}), 400
    file = request.files["file"]
    prefix = request.form.get("prefix", "caretaker")
    audio_bytes = file.read()
    filename = save_voice_file(student_id, prefix, audio_bytes)
    voice_profiles_collection.update_one({"student_id": student_id}, {"$set": {"student_id": student_id, "voice_file_name": filename, "uploaded_at": time.time()}}, upsert=True)
    return jsonify({"status": "success", "voice_url": f"/voice/{filename}"})

@app.route("/upload_stimulus", methods=["POST"])
def upload_stimulus():
    if "file" not in request.files or "name" not in request.form:
        return jsonify({"error": "Missing file or name"}), 400
    file = request.files["file"]
    name = request.form["name"]
    total_time = int(request.form.get("total_time", 30))
    os.makedirs("stimuli", exist_ok=True)
    stimulus_id = str(ObjectId())
    filename = f"{stimulus_id}_{file.filename}"
    filepath = os.path.join("stimuli", filename)
    file.save(filepath)
    stimuli_collection.insert_one({
        "stimulus_id": stimulus_id,
        "name": name,
        "file_path": filepath,
        "duration_seconds": total_time,
        "created_at": time.time()
    })
    return jsonify({"stimulus_id": stimulus_id, "stimulus_name": name, "duration_seconds": total_time})

# ------------------ Stimulus session flow endpoints ------------------

@app.route("/start_stimulus", methods=["POST"])
def start_stimulus():
    data = request.get_json(force=True, silent=True) or {}
    student_id = data.get("student_id")
    total_time = data.get("total_time", 30)
    voice_on_low_attention = bool(data.get("voice_on_low_attention", False))
    voice_threshold = float(data.get("voice_threshold", 0.4))
    base_voice_duration = int(data.get("voice_duration", 10))
    if not student_id:
        return jsonify({"error": "Missing student_id"}), 400
    all_stimuli = list(stimuli_collection.find({}, {"_id": 0}))
    if not all_stimuli:
        return jsonify({"error": "No stimuli available"}), 400
    first_stimulus = all_stimuli[0]
    # Helper: decide voice duration based on attention
    def should_play_voice(student_id, voice_on_low_attention, voice_threshold):
        return should_play_voice_helper(student_id, voice_on_low_attention, voice_threshold)
    
    # Decide initial voice duration: only play if attention is low (when voice_on_low_attention enabled)
    play_voice = should_play_voice(student_id, voice_on_low_attention, voice_threshold)
    voice_duration_to_use = base_voice_duration if play_voice else 0

    # Use stimulus-specific duration if available
    stimulus_duration_to_use = int(first_stimulus.get("duration_seconds", total_time))

    active_sessions[student_id] = {
        "current_stimulus": first_stimulus,
        "frames": deque(),
        "analysis_active": False,
        "stimulus_index": 0,
        "next_instruction": {"action": "play_voice", "voice_url": get_voice_url(student_id) if voice_duration_to_use > 0 else None},
        "voice_duration": voice_duration_to_use,
        "stimulus_duration": stimulus_duration_to_use,
        "voice_on_low_attention": voice_on_low_attention,
        "voice_threshold": voice_threshold,
        "base_voice_duration": base_voice_duration,
        "terminated": False
    }
    print(f"Starting session for {student_id} with stimulus_duration={stimulus_duration_to_use}s, voice_duration={voice_duration_to_use}s, voice_on_low={voice_on_low_attention}")
    start_stimulus_timer(student_id, voice_duration=voice_duration_to_use, stimulus_duration=stimulus_duration_to_use)
    return jsonify(active_sessions[student_id]['next_instruction'])

@app.route("/end_stimulus", methods=["POST"])
def end_stimulus():
    data = request.get_json(force=True, silent=True) or {}
    student_id = data.get("student_id")
    if not student_id:
        return jsonify({"error": "Missing student_id"}), 400
    session = active_sessions.get(student_id)
    if not session:
        return jsonify({"error": "No active session"}), 400
    # Mark terminated and inactive, but keep the session so background timers don't crash.
    session["terminated"] = True
    session["active"] = False

    frames = session.get('frames', [])
    avg_attention = float(np.mean([f['attention_score'] for f in frames])) if frames else 0.0
    blink_count = int(sum([1 for f in frames if f.get('blink')]))

    try:
        current_stimulus = session.get('current_stimulus') or {}
        sessions_collection.insert_one({
            "student_id": student_id,
            "stimulus_id": current_stimulus.get('stimulus_id'),
            "stimulus_name": current_stimulus.get('name'),
            "avg_attention": avg_attention,
            "blink_count": blink_count,
            "frames_collected": len(frames),
            "timestamp": time.time()
        })
    except Exception as e:
        print("Error storing forced end session:", e)

    # Signal the client to wrap up gracefully.
    session['next_instruction'] = {"action": "session_complete"}
    return jsonify({"status": "ended", "frames_collected": len(frames)})

@app.route('/next_instruction/<student_id>', methods=['GET'])
def next_instruction(student_id):
    session = active_sessions.get(student_id)
    if not session:
        return jsonify({"status": "no_session"})
    instr = session.get('next_instruction')
    if instr is None:
        return jsonify({"status": "wait"})
    # clear after sending
    session['next_instruction'] = None
    print(f"Sending instruction to {student_id}: {instr}")
    return jsonify(instr)

# ------------------ Sessions DB retrieval ------------------

@app.route('/sessions', methods=['GET'])
def get_sessions():
    all_sessions = list(sessions_collection.find({}, {"_id": 0}))
    return jsonify(all_sessions)

# ------------------ Analytics endpoints ------------------

@app.route('/analytics/summary', methods=['GET'])
def analytics_summary():
    """Get overall summary statistics"""
    try:
        pipeline = [
            {
                "$group": {
                    "_id": None,
                    "total_sessions": {"$sum": 1},
                    "avg_attention": {"$avg": "$avg_attention"},
                    "total_frames": {"$sum": "$frames_collected"},
                    "total_blinks": {"$sum": "$blink_count"}
                }
            }
        ]
        result = list(detailed_analysis_collection.aggregate(pipeline))
        
        # Get student count
        student_count = users_collection.count_documents({})
        
        # Get stimulus count
        stimulus_count = stimuli_collection.count_documents({})
        
        if result:
            summary = result[0]
            return jsonify({
                "total_sessions": summary.get("total_sessions", 0),
                "total_students": student_count,
                "total_stimuli": stimulus_count,
                "avg_attention": round(summary.get("avg_attention", 0), 4),
                "total_frames": summary.get("total_frames", 0),
                "total_blinks": summary.get("total_blinks", 0)
            })
        else:
            return jsonify({
                "total_sessions": 0,
                "total_students": student_count,
                "total_stimuli": stimulus_count,
                "avg_attention": 0,
                "total_frames": 0,
                "total_blinks": 0
            })
    except Exception as e:
        print(f"Error in analytics_summary: {e}")
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

@app.route('/analytics/student/<student_id>', methods=['GET'])
def analytics_by_student(student_id):
    """Get detailed analysis for a specific student"""
    try:
        sessions = list(detailed_analysis_collection.find(
            {"student_id": student_id},
            {"_id": 0}
        ).sort("timestamp", -1))
        
        return jsonify(sessions)
    except Exception as e:
        print(f"Error in analytics_by_student: {e}")
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

@app.route('/analytics/student/<student_id>/stimulus', methods=['GET'])
def analytics_student_stimulus(student_id):
    """Get stimulus-specific analysis for a student"""
    try:
        pipeline = [
            {"$match": {"student_id": student_id}},
            {
                "$group": {
                    "_id": "$stimulus_id",
                    "stimulus_name": {"$first": "$stimulus_name"},
                    "total_sessions": {"$sum": 1},
                    "avg_attention": {"$avg": "$avg_attention"},
                    "max_attention": {"$max": "$max_attention"},
                    "min_attention": {"$min": "$min_attention"},
                    "total_high_frames": {"$sum": "$high_attention_frames"},
                    "total_medium_frames": {"$sum": "$medium_attention_frames"},
                    "total_low_frames": {"$sum": "$low_attention_frames"},
                    "total_frames": {"$sum": "$frames_collected"},
                    "total_blinks": {"$sum": "$blink_count"}
                }
            },
            {"$sort": {"avg_attention": -1}}
        ]
        
        result = list(detailed_analysis_collection.aggregate(pipeline))
        
        # Format response
        stimulus_data = [
            {
                "stimulus_id": item["_id"],
                "stimulus_name": item.get("stimulus_name", "Unknown"),
                "total_sessions": item.get("total_sessions", 0),
                "avg_attention": round(item.get("avg_attention", 0), 4),
                "max_attention": round(item.get("max_attention", 0), 4),
                "min_attention": round(item.get("min_attention", 0), 4),
                "focus_distribution": {
                    "high": item.get("total_high_frames", 0),
                    "medium": item.get("total_medium_frames", 0),
                    "low": item.get("total_low_frames", 0)
                },
                "total_frames": item.get("total_frames", 0),
                "total_blinks": item.get("total_blinks", 0),
                "focus_score": round(
                    (item.get("total_high_frames", 0) / max(item.get("total_frames", 1), 1)) * 100,
                    2
                )
            }
            for item in result
        ]
        
        return jsonify(stimulus_data)
    except Exception as e:
        print(f"Error in analytics_student_stimulus: {e}")
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

@app.route('/analytics/student/<student_id>/best', methods=['GET'])
def analytics_student_best(student_id):
    """Return the student's best session and best stimulus by avg_attention"""
    try:
        sessions = list(detailed_analysis_collection.find({"student_id": student_id}, {"_id": 0}))
        if not sessions:
            return jsonify({"best_session": None, "best_stimulus": None})

        # Best session (single record with max avg_attention)
        best_session = max(sessions, key=lambda s: s.get("avg_attention", 0))

        # Best stimulus (aggregate by stimulus_id)
        agg = {}
        for s in sessions:
            sid = s.get("stimulus_id")
            if sid not in agg:
                agg[sid] = {"stimulus_id": sid, "stimulus_name": s.get("stimulus_name"), "avg_sum": 0.0, "count": 0}
            agg[sid]["avg_sum"] += s.get("avg_attention", 0.0)
            agg[sid]["count"] += 1
        best_stimulus = None
        for v in agg.values():
            v["avg_attention"] = v["avg_sum"] / max(v["count"], 1)
            if best_stimulus is None or v["avg_attention"] > best_stimulus["avg_attention"]:
                best_stimulus = {"stimulus_id": v["stimulus_id"], "stimulus_name": v["stimulus_name"], "avg_attention": round(v["avg_attention"], 4), "sessions": v["count"]}

        return jsonify({
            "best_session": {
                "stimulus_id": best_session.get("stimulus_id"),
                "stimulus_name": best_session.get("stimulus_name"),
                "avg_attention": round(best_session.get("avg_attention", 0), 4),
                "blink_count": best_session.get("blink_count", 0),
                "frames_collected": best_session.get("frames_collected", 0),
                "timestamp": best_session.get("timestamp")
            },
            "best_stimulus": best_stimulus
        })
    except Exception as e:
        print(f"Error in analytics_student_best: {e}")
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

@app.route('/analytics/stimulus/<stimulus_id>/tracking', methods=['GET'])
def analytics_stimulus_tracking(stimulus_id):
    """Get detailed frame-by-frame tracking for a stimulus"""
    try:
        tracking_data = list(stimulus_tracking_collection.find(
            {"stimulus_id": stimulus_id},
            {"_id": 0}
        ).sort("timestamp", -1))
        
        return jsonify(tracking_data)
    except Exception as e:
        print(f"Error in analytics_stimulus_tracking: {e}")
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

@app.route('/analytics/stimulus/<stimulus_id>', methods=['GET'])
def analytics_by_stimulus(stimulus_id):
    """Get detailed analysis for a specific stimulus"""
    try:
        sessions = list(detailed_analysis_collection.find(
            {"stimulus_id": stimulus_id},
            {"_id": 0}
        ).sort("timestamp", -1))
        
        return jsonify(sessions)
    except Exception as e:
        print(f"Error in analytics_by_stimulus: {e}")
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

@app.route('/analytics/detailed', methods=['GET'])
def analytics_detailed():
    """Get all detailed analysis records"""
    try:
        all_analysis = list(detailed_analysis_collection.find({}, {"_id": 0}).sort("timestamp", -1).limit(100))
        return jsonify(all_analysis)
    except Exception as e:
        print(f"Error in analytics_detailed: {e}")
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

# ------------------ Live attention / calibration endpoints ------------------

@app.route("/start_session", methods=["POST"])
def start_session():
    data = request.json or {}
    sid = data.get("student_id", "default")
    active_sessions[sid] = {
        "frames": deque(),
        "active": True,
        "last_face_ts": time.time(),
        "started_at": time.time(),
        "low_frames": 0,
        "good_frames": 0,
        "smoothed_att": None,
        "smoothed_yaw": None,
        "smoothed_pitch": None,
        "alert_active": False
    }
    print(f"start_session sid={sid}")
    return jsonify({"status": "started", "student_id": sid})

@app.route("/stop_session", methods=["POST"])
def stop_session():
    data = request.json or {}
    sid = data.get("student_id", "default")
    sess = active_sessions.get(sid)
    if not sess:
        return jsonify({"status": "no_session"})
    sess["active"] = False
    sess["terminated"] = True
    frames = list(sess["frames"])
    avg = float(np.mean([f["smoothed_att"] for f in frames])) if frames else 0.0
    active_sessions.pop(sid, None)
    print(f"stop_session sid={sid} avg={avg:.3f} frames={len(frames)} (terminated)")
    return jsonify({"status": "stopped", "avg_attention": round(avg, 4)})

@app.route("/calibrate_start", methods=["POST"])
def calibrate_start():
    data = request.get_json(force=True) or {}
    sid = data.get("student_id", "default")
    sess = active_sessions.setdefault(sid, {"frames": deque(), "active": True, "last_face_ts": time.time(), "low_frames": 0, "good_frames": 0, "smoothed_att": None, "smoothed_yaw": None, "smoothed_pitch": None, "alert_active": False})
    sess["calib_samples"] = []
    print(f"calibration started for {sid}")
    return jsonify({"status": "calibration_started"})

@app.route("/calibrate_sample", methods=["POST"])
def calibrate_sample():
    data = request.get_json(force=True) or {}
    sid = data.get("student_id", "default")
    gx = float(data.get("gx", 0.0)); gy = float(data.get("gy", 0.0))
    sx = float(data.get("screen_x", 0.0)); sy = float(data.get("screen_y", 0.0))
    sess = active_sessions.setdefault(sid, {"frames": deque(), "active": True, "last_face_ts": time.time(), "low_frames": 0})
    sess.setdefault("calib_samples", []).append((gx, gy, sx, sy))
    count = len(sess["calib_samples"])
    print(f"calib sample {count} for {sid}")
    return jsonify({"status": "sample_recorded", "samples": count})

@app.route("/calibrate_finish", methods=["POST"])
def calibrate_finish():
    data = request.get_json(force=True) or {}
    sid = data.get("student_id", "default")
    sess = active_sessions.get(sid)
    if not sess or not sess.get("calib_samples"):
        return jsonify({"error": "no_samples"}), 400
    params = fit_affine_from_samples(sess["calib_samples"])
    if not params:
        return jsonify({"error": "fit_failed"}), 500
    sess["affine"] = params
    sess.pop("calib_samples", None)
    print(f"calibration finished for {sid}: {params}")
    return jsonify({"status": "ok", "affine": params})

# ------------------ Frame processing (single / unified) ------------------
@app.route("/frame", methods=["POST"])
def frame():
    data = request.get_json(force=True) or {}
    sid = data.get("student_id", "default")
    image_w = int(data.get("image_w", 640))
    image_h = int(data.get("image_h", 480))
    sess = active_sessions.get(sid)
    if not sess:
        active_sessions[sid] = {
            "frames": deque(), 
            "active": True, 
            "last_face_ts": time.time(), 
            "started_at": time.time(), 
            "low_frames": 0, 
            "good_frames": 0, 
            "smoothed_att": None, 
            "smoothed_yaw": None, 
            "smoothed_pitch": None, 
            "alert_active": False,
            "analysis_active": False,
            "analysis_frames": [],
            "current_stimulus": None,
            "stimulus_index": 0
        }
        sess = active_sessions[sid]
        print(f"auto-created session sid={sid}")

    if not sess.get("active", True):
        return jsonify({"status": "ignored", "active": False})

    landmarks = data.get("landmarks")
    face_present = bool(landmarks)

    if face_present:
        sess["last_face_ts"] = time.time()

    # compute gaze & eye
    gaze_eye_score, looking_forward_gaze, blink, subs_gaze = compute_gaze_eye(landmarks) if face_present else (0.0, False, False, {})

    # head-pose
    yaw = pitch = roll = None
    head_pose_valid = False
    head_pose_score = 1.0
    if OPENCV_AVAILABLE and face_present and len(landmarks) > max(HP_IDX.values()):
        yaw, pitch, roll = compute_head_pose_from_landmarks(landmarks, image_w=image_w, image_h=image_h)
        if yaw is not None and pitch is not None:
            if abs(yaw) <= HEAD_POSE_MAX_ABS_DEG and abs(pitch) <= HEAD_POSE_MAX_ABS_DEG:
                head_pose_valid = True
                head_pose_score = clamp(1.0 - (abs(yaw) - 5.0) / (60.0 - 5.0), 0.0, 1.0)
            else:
                head_pose_valid = False
                head_pose_score = 1.0

    combined_att_raw = float(clamp(W_GAZE * gaze_eye_score + W_HEAD * head_pose_score, 0.0, 1.0))

    # smoothing
    if sess.get("smoothed_att") is None:
        sess["smoothed_att"] = combined_att_raw
    else:
        sess["smoothed_att"] = ALPHA_ATT * combined_att_raw + (1 - ALPHA_ATT) * sess["smoothed_att"]

    yaw_to_use = None if (yaw is None or abs(yaw) > HEAD_POSE_MAX_ABS_DEG) else yaw
    pitch_to_use = None if (pitch is None or abs(pitch) > HEAD_POSE_MAX_ABS_DEG) else pitch
    if yaw_to_use is not None:
        if sess.get("smoothed_yaw") is None:
            sess["smoothed_yaw"] = yaw_to_use
        else:
            sess["smoothed_yaw"] = ALPHA_HEAD * yaw_to_use + (1 - ALPHA_HEAD) * sess["smoothed_yaw"]
    if pitch_to_use is not None:
        if sess.get("smoothed_pitch") is None:
            sess["smoothed_pitch"] = pitch_to_use
        else:
            sess["smoothed_pitch"] = ALPHA_HEAD * pitch_to_use + (1 - ALPHA_HEAD) * sess["smoothed_pitch"]

    sm_att = sess.get("smoothed_att", combined_att_raw)
    sm_yaw = sess.get("smoothed_yaw", None)
    sm_pitch = sess.get("smoothed_pitch", None)

    # affine mapping
    affine = sess.get("affine")
    screen_x = screen_y = None
    on_screen = True
    if affine and subs_gaze:
        gx = subs_gaze.get("gaze_offset_x", 0.0)
        gy = subs_gaze.get("gaze_offset_y", 0.0)
        sx, sy = apply_affine(affine, gx, gy)
        screen_x, screen_y = sx, sy
        margin = 80
        on_screen = (-margin <= sx <= image_w + margin) and (-margin <= sy <= image_h + margin)
    else:
        on_screen = face_present

    # store frame
    now = time.time()
    frame_data = {
        "ts": now,
        "attention_score": combined_att_raw,
        "smoothed_att": sm_att,
        "face": face_present,
        "on_screen": on_screen,
        "blink": blink,
        "yaw": sm_yaw,
        "pitch": sm_pitch,
        "head_pose_valid": head_pose_valid
    }
    sess["frames"].append(frame_data)
    
    # If analysis is active (during stimulus playback), also store to analysis_frames
    if sess.get("analysis_active", False):
        if "analysis_frames" not in sess:
            sess["analysis_frames"] = []
        sess["analysis_frames"].append(frame_data)
    
    while len(sess["frames"]) > MAX_FRAMES_KEEP:
        sess["frames"].popleft()
    while sess["frames"] and now - sess["frames"][0]["ts"] > WINDOW_SECONDS:
        sess["frames"].popleft()

    frames_list = list(sess["frames"])
    avg_attention = float(np.mean([f["smoothed_att"] for f in frames_list])) if frames_list else sm_att

    # alert logic
    alert = False; alert_type = None; alert_msg = None
    time_since_face = now - sess.get("last_face_ts", now)
    if time_since_face > NO_FACE_THRESHOLD:
        alert = True; alert_type = "no_face"; alert_msg = "No face detected — please look at the camera."
        sess["low_frames"] = 0
        sess["good_frames"] = 0
        sess["alert_active"] = True
    else:
        head_turn_alert = False
        if head_pose_valid:
            if sm_yaw is not None and abs(sm_yaw) >= HEAD_YAW_ALERT_DEG:
                head_turn_alert = True
            if sm_pitch is not None and abs(sm_pitch) >= HEAD_PITCH_ALERT_DEG:
                head_turn_alert = True
        current_good = (on_screen and (sm_att >= ALERT_ATTENTION_THRESHOLD) and (not head_turn_alert))
        if current_good and (sm_att >= INSTANT_CLEAR_ATT):
            sess["low_frames"] = 0
            sess["good_frames"] = max(sess.get("good_frames", 0), GOOD_FRAMES_TO_CLEAR)
            sess["alert_active"] = False
            alert = False
        else:
            if not current_good:
                sess["good_frames"] = 0
                sess["low_frames"] = sess.get("low_frames", 0) + 1
            else:
                sess["low_frames"] = 0
                sess["good_frames"] = sess.get("good_frames", 0) + 1

            if sess.get("low_frames", 0) >= CONSECUTIVE_LOW_FRAMES:
                alert = True; alert_type = "low_attention"; alert_msg = "Look here — concentrate!"
                sess["alert_active"] = True
            elif sess.get("good_frames", 0) >= GOOD_FRAMES_TO_CLEAR:
                alert = False; alert_type = None; alert_msg = None
                sess["alert_active"] = False
            else:
                alert = bool(sess.get("alert_active", False))

    print(f"[{time.strftime('%H:%M:%S')}] sid={sid} face={face_present} on_screen={on_screen} sm_att={sm_att:.3f} sm_yaw={sm_yaw} sm_pitch={sm_pitch} head_pose_valid={head_pose_valid} low={sess.get('low_frames')} good={sess.get('good_frames')} alert={alert_type}")

    return jsonify({
        "status": "ok",
        "face": face_present,
        "on_screen": on_screen,
        "attention_score": round(combined_att_raw, 4),
        "smoothed_attention": round(sm_att, 4),
        "avg_attention": round(avg_attention, 4),
        "alert": bool(alert),
        "alert_type": alert_type,
        "alert_msg": alert_msg,
        "low_frames": sess.get("low_frames"),
        "good_frames": sess.get("good_frames"),
        "head_pose_valid": head_pose_valid,
        "subscores": {**(subs_gaze or {}), "head_pose": {"yaw": sm_yaw, "pitch": sm_pitch, "roll": roll if 'roll' in locals() else None, "head_pose_score": round(head_pose_score, 4) if 'head_pose_score' in locals() else None}},
        "screen_xy": {"x": screen_x, "y": screen_y}
    })

@app.route('/', methods=['GET'])
def status():
    return jsonify({
        "status": "API WORKING"
    })

# ------------------ Admin sessions listing ------------------
@app.route('/runtime_sessions', methods=['GET'])
def runtime_sessions():
    out = {}
    for sid, s in active_sessions.items():
        out[sid] = {"active": s.get("active", False), "started_at": s.get("started_at"), "last_face_ts": s.get("last_face_ts"), "frames_total": len(s.get("frames", [])), "low_frames": s.get("low_frames",0), "good_frames": s.get("good_frames",0), "affine": s.get("affine")}
    return jsonify(out)

# ------------------ Main ------------------
if __name__ == "__main__":
    os.makedirs("stimuli", exist_ok=True)
    os.makedirs("voice_clones", exist_ok=True)
    print("Attention Server running on port 5000")
    if not OPENCV_AVAILABLE:
        print("WARNING: OpenCV not available — head-pose disabled. Install opencv-python for best results.")
    if not MEDIAPIPE_AVAILABLE:
        print("INFO: MediaPipe not available on server — server-side fallback processing disabled.")
    app.run(host="0.0.0.0", port=5000, debug=True)
