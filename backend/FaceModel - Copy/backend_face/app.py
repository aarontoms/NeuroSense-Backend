from flask import Flask, request, jsonify
from flask_cors import CORS
from feature_utils import build_feature_vector_from_csv
from model_utils import predict_from_vector, model_meta
import csv
import io
import os
import sys
from datetime import datetime
import tempfile

app = Flask(__name__)
CORS(app, resources={r"/api/*": {"origins": ["http://localhost:3000", "http://127.0.0.1:3000", "*"]}})

# Create upload directory if it doesn't exist
UPLOAD_FOLDER = 'uploads'
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# Import MediaPipe and OpenCV with better error handling
MEDIAPIPE_AVAILABLE = False
mp_face_mesh = None
mp = None

try:
    import cv2
    print("✓ OpenCV imported successfully")
    
    # Try different import methods for MediaPipe
    try:
        import mediapipe as mp
        mp_face_mesh = mp.solutions.face_mesh
        MEDIAPIPE_AVAILABLE = True
        print("✓ MediaPipe loaded successfully")
    except ImportError as e:
        print(f"⚠ MediaPipe import failed (method 1): {e}")
        try:
            # Alternative import
            from mediapipe.python.solutions import face_mesh as mp_face_mesh_module
            mp_face_mesh = mp_face_mesh_module
            MEDIAPIPE_AVAILABLE = True
            print("✓ MediaPipe loaded successfully (alternative method)")
        except ImportError as e2:
            print(f"⚠ MediaPipe import failed (method 2): {e2}")
            MEDIAPIPE_AVAILABLE = False
    
except ImportError as e:
    print(f"⚠ Failed to import required libraries: {e}")
    MEDIAPIPE_AVAILABLE = False

if not MEDIAPIPE_AVAILABLE:
    print("\n" + "="*60)
    print("⚠️  WARNING: MediaPipe not available!")
    print("Video processing will not work.")
    print("\nTroubleshooting steps:")
    print("1. Check Python version: python --version")
    print("2. Reinstall MediaPipe: pip uninstall mediapipe && pip install mediapipe==0.10.9")
    print("3. Test import: python -c 'import mediapipe; print(mediapipe.__version__)'")
    print("4. Check for conflicts: pip list | grep mediapipe")
    print("="*60 + "\n")


def extract_landmarks_from_frame(frame, face_mesh):
    """Extract 468 facial landmarks from a single frame"""
    try:
        # Convert BGR to RGB
        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        
        # Process the frame
        results = face_mesh.process(rgb_frame)
        
        if not results.multi_face_landmarks:
            return None
        
        # Get first face landmarks
        landmarks = results.multi_face_landmarks[0].landmark
        
        # Convert to list of dicts with x, y, z
        landmark_list = []
        for lm in landmarks[:468]:  # Ensure we only take first 468
            landmark_list.append({
                'x': lm.x,
                'y': lm.y,
                'z': lm.z
            })
        
        return landmark_list
    
    except Exception as e:
        print(f"Error extracting landmarks: {e}")
        return None


def process_video_to_segments(video_path, segment_duration=2.0):
    """
    Process video file and extract landmarks for each segment
    
    Args:
        video_path: Path to video file
        segment_duration: Duration of each segment in seconds (default 2.0)
    
    Returns:
        List of segments with landmarks and timing info
    """
    if not MEDIAPIPE_AVAILABLE:
        raise Exception("MediaPipe is not installed. Install with: pip install mediapipe opencv-python")
    
    segments = []
    
    # Open video
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        raise Exception("Failed to open video file")
    
    # Get video properties
    fps = cap.get(cv2.CAP_PROP_FPS)
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    duration = total_frames / fps if fps > 0 else 0
    
    print(f"Video info: {fps} fps, {total_frames} frames, {duration:.2f} seconds")
    
    # Calculate frames per segment
    frames_per_segment = int(fps * segment_duration)
    
    # Initialize MediaPipe Face Mesh
    with mp_face_mesh.FaceMesh(
        max_num_faces=1,
        refine_landmarks=True,
        min_detection_confidence=0.5,
        min_tracking_confidence=0.5
    ) as face_mesh:
        
        segment_num = 0
        frame_count = 0
        segment_frames = []
        
        while True:
            ret, frame = cap.read()
            if not ret:
                break
            
            segment_frames.append(frame)
            frame_count += 1
            
            # Process segment when we have enough frames
            if len(segment_frames) >= frames_per_segment or frame_count >= total_frames:
                # Use middle frame of segment for landmark extraction
                middle_frame_idx = len(segment_frames) // 2
                middle_frame = segment_frames[middle_frame_idx]
                
                # Extract landmarks
                landmarks = extract_landmarks_from_frame(middle_frame, face_mesh)
                
                start_time = segment_num * segment_duration
                end_time = min((segment_num + 1) * segment_duration, duration)
                
                segment_info = {
                    'segment_number': segment_num + 1,
                    'start_time': start_time,
                    'end_time': end_time,
                    'segment_label': f"{start_time:.1f}-{end_time:.1f} sec",
                    'landmarks': landmarks,
                    'frames_processed': len(segment_frames)
                }
                
                segments.append(segment_info)
                
                # Reset for next segment
                segment_frames = []
                segment_num += 1
    
    cap.release()
    
    return segments


def landmarks_to_csv_string(landmarks):
    """Convert landmarks list to CSV string"""
    output = io.StringIO()
    writer = csv.DictWriter(output, fieldnames=["x", "y", "z"])
    writer.writeheader()
    
    for lm in landmarks:
        writer.writerow(lm)
    
    return output.getvalue()


# ==================== PREDICTION ENDPOINTS ====================

@app.route("/api/predict/realtime", methods=["POST"])
def realtime_predict():
    """Real-time prediction from MediaPipe landmark data"""
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({
                "success": False,
                "error": "No data provided"
            }), 400
        
        if "landmarks" not in data:
            return jsonify({
                "success": False,
                "error": "No landmarks provided. Expected 'landmarks' array."
            }), 400
        
        landmarks = data["landmarks"]
        
        # Validate landmarks
        if not isinstance(landmarks, list):
            return jsonify({
                "success": False,
                "error": "Landmarks must be an array"
            }), 400
        
        if len(landmarks) != 468:
            return jsonify({
                "success": False,
                "error": f"Expected 468 landmarks, got {len(landmarks)}"
            }), 400
        
        # Convert landmarks to CSV in-memory
        output = io.StringIO()
        writer = csv.DictWriter(output, fieldnames=["x", "y", "z"])
        writer.writeheader()
        
        for lm in landmarks:
            if not all(k in lm for k in ["x", "y", "z"]):
                return jsonify({
                    "success": False,
                    "error": "Each landmark must have x, y, z coordinates"
                }), 400
            writer.writerow(lm)
        
        output.seek(0)
        
        # Extract features and predict
        vec = build_feature_vector_from_csv(output.getvalue().encode(), model_meta)
        result = predict_from_vector(vec)
        
        return jsonify({
            "success": True,
            **result
        })
    
    except Exception as e:
        return jsonify({
            "success": False,
            "error": "Prediction failed",
            "details": str(e)
        }), 500


@app.route("/api/predict/video-process", methods=["POST"])
def video_process():
    """
    Complete video processing endpoint:
    1. Receives video file
    2. Extracts landmarks using MediaPipe for each 2-second segment
    3. Runs predictions on all segments
    4. Returns comprehensive analysis
    """
    try:
        if not MEDIAPIPE_AVAILABLE:
            return jsonify({
                "success": False,
                "error": "MediaPipe is not available on the server",
                "details": "Server configuration issue. MediaPipe could not be imported.",
                "troubleshooting": {
                    "check_install": "Run: pip list | grep mediapipe",
                    "reinstall": "Run: pip uninstall mediapipe && pip install mediapipe==0.10.9",
                    "test_import": "Run: python -c 'import mediapipe; print(mediapipe.__version__)'"
                }
            }), 500
        
        if 'video' not in request.files:
            return jsonify({
                "success": False,
                "error": "No video file provided. Upload with key 'video'"
            }), 400
        
        video_file = request.files['video']
        
        if video_file.filename == '':
            return jsonify({
                "success": False,
                "error": "No file selected"
            }), 400
        
        # Save video temporarily
        with tempfile.NamedTemporaryFile(delete=False, suffix='.mp4') as temp_video:
            video_file.save(temp_video.name)
            temp_video_path = temp_video.name
        
        try:
            # Process video into segments with landmarks
            print(f"Processing video: {video_file.filename}")
            segments_data = process_video_to_segments(temp_video_path, segment_duration=2.0)
            
            # Get video info
            cap = cv2.VideoCapture(temp_video_path)
            fps = cap.get(cv2.CAP_PROP_FPS)
            total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
            duration = total_frames / fps if fps > 0 else 0
            cap.release()
            
            # Process predictions for each segment
            results = []
            
            for seg_data in segments_data:
                if seg_data['landmarks'] is None:
                    # No face detected in this segment
                    results.append({
                        'segment': seg_data['segment_label'],
                        'segment_number': seg_data['segment_number'],
                        'error': 'No face detected in this segment',
                        'frames_processed': seg_data['frames_processed']
                    })
                else:
                    try:
                        # Convert landmarks to CSV and predict
                        csv_string = landmarks_to_csv_string(seg_data['landmarks'])
                        vec = build_feature_vector_from_csv(csv_string.encode(), model_meta)
                        prediction = predict_from_vector(vec)
                        
                        results.append({
                            'segment': seg_data['segment_label'],
                            'segment_number': seg_data['segment_number'],
                            'trigger_status': prediction['trigger_status'],
                            'confidence': prediction['confidence'],
                            'mood': prediction['mood'],
                            'possible_environments': prediction['possible_environments'],
                            'frames_processed': seg_data['frames_processed']
                        })
                    except Exception as pred_error:
                        results.append({
                            'segment': seg_data['segment_label'],
                            'segment_number': seg_data['segment_number'],
                            'error': f'Prediction failed: {str(pred_error)}',
                            'frames_processed': seg_data['frames_processed']
                        })
            
            # Calculate summary statistics
            valid_segments = [s for s in results if 'error' not in s]
            total_segments = len(results)
            trigger_count = sum(1 for r in valid_segments if r.get('trigger_status') == 'trigger')
            trigger_percentage = (trigger_count / len(valid_segments) * 100) if valid_segments else 0
            
            # Find top trigger moments
            trigger_segments = [s for s in valid_segments if s.get('trigger_status') == 'trigger']
            trigger_segments.sort(key=lambda x: x.get('confidence', 0), reverse=True)
            
            response = {
                'success': True,
                'segments': results,
                'summary': {
                    'total_segments': total_segments,
                    'valid_segments': len(valid_segments),
                    'failed_segments': total_segments - len(valid_segments),
                    'trigger_segments': trigger_count,
                    'non_trigger_segments': len(valid_segments) - trigger_count,
                    'trigger_percentage': round(trigger_percentage, 2),
                    'top_trigger_moments': [
                        {
                            'segment': s['segment'],
                            'confidence': round(s['confidence'] * 100, 1)
                        }
                        for s in trigger_segments[:3]
                    ]
                },
                'video_info': {
                    'filename': video_file.filename,
                    'duration': round(duration, 2),
                    'fps': round(fps, 2),
                    'total_frames': total_frames,
                    'segment_duration': 2.0
                }
            }
            
            return jsonify(response)
        
        finally:
            # Clean up temporary file
            if os.path.exists(temp_video_path):
                os.unlink(temp_video_path)
    
    except Exception as e:
        import traceback
        print(f"Error processing video: {e}")
        print(traceback.format_exc())
        return jsonify({
            "success": False,
            "error": "Video processing failed",
            "details": str(e)
        }), 500


@app.route("/api/predict/csv", methods=["POST"])
def csv_predict():
    """Predict from uploaded CSV file"""
    try:
        if 'csv' not in request.files:
            return jsonify({
                "success": False,
                "error": "No CSV file provided. Upload with key 'csv'"
            }), 400
        
        csv_file = request.files['csv']
        
        if csv_file.filename == '':
            return jsonify({
                "success": False,
                "error": "No file selected"
            }), 400
        
        # Read and validate CSV
        csv_content = csv_file.read()
        
        # Extract features and predict
        vec = build_feature_vector_from_csv(csv_content, model_meta)
        result = predict_from_vector(vec)
        
        return jsonify({
            "success": True,
            **result
        })
    
    except Exception as e:
        return jsonify({
            "success": False,
            "error": "CSV prediction failed",
            "details": str(e)
        }), 500


# ==================== UTILITY ENDPOINTS ====================

@app.route('/', methods=['GET'])
@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        "status": "online",
        "service": "Face Model API",
        "version": "3.0",
        "model_loaded": model_meta is not None,
        "mediapipe_available": MEDIAPIPE_AVAILABLE,
        "endpoints": {
            "realtime": "/api/predict/realtime",
            "csv": "/api/predict/csv",
            "video_process": "/api/predict/video-process",
            "model_info": "/api/model/info"
        }
    })


@app.route('/api/model/info', methods=['GET'])
def model_info():
    """Get information about the loaded model"""
    try:
        classes_list = []
        if hasattr(model_meta.get("classes", []), 'tolist'):
            classes_list = model_meta["classes"].tolist()
        else:
            classes_list = list(model_meta.get("classes", []))
        
        return jsonify({
            "success": True,
            "model_type": "Random Forest Classifier",
            "features": model_meta.get("feature_names", []),
            "num_features": len(model_meta.get("feature_names", [])),
            "classes": classes_list,
            "threshold": float(model_meta.get("best_threshold", 0.5)),
            "expected_landmarks": 468,
            "mediapipe_available": MEDIAPIPE_AVAILABLE,
            "environment_mappings": {
                "trigger": [
                    "youtube video",
                    "fan",
                    "laptop",
                    "teacher",
                    "high pitch sound",
                    "high contrast color"
                ],
                "no_trigger": [
                    "home",
                    "Liked places"
                ]
            }
        })
    except Exception as e:
        return jsonify({
            "success": False,
            "error": "Failed to get model info",
            "details": str(e)
        }), 500


@app.route('/api/test-mediapipe', methods=['GET'])
def test_mediapipe():
    """Test MediaPipe availability and configuration"""
    import sys
    
    test_results = {
        "python_version": sys.version,
        "python_executable": sys.executable,
        "mediapipe_available": MEDIAPIPE_AVAILABLE,
    }
    
    if MEDIAPIPE_AVAILABLE:
        try:
            test_results["mediapipe_version"] = mp.__version__
            test_results["mediapipe_path"] = mp.__file__
            test_results["face_mesh_available"] = mp_face_mesh is not None
        except:
            test_results["mediapipe_details"] = "Could not get MediaPipe details"
    
    # Try to import and get more info
    try:
        import mediapipe
        test_results["direct_import_success"] = True
        test_results["direct_import_version"] = mediapipe.__version__
    except Exception as e:
        test_results["direct_import_success"] = False
        test_results["direct_import_error"] = str(e)
    
    return jsonify(test_results)


# ==================== ERROR HANDLERS ====================

@app.errorhandler(404)
def not_found(error):
    return jsonify({
        "success": False,
        "error": "Endpoint not found",
        "available_endpoints": [
            "/api/predict/realtime",
            "/api/predict/csv",
            "/api/predict/video-process",
            "/api/model/info",
            "/api/test-mediapipe",
            "/health"
        ]
    }), 404


@app.errorhandler(500)
def internal_error(error):
    return jsonify({
        "success": False,
        "error": "Internal server error",
        "details": str(error)
    }), 500


if __name__ == "__main__":
    print("=" * 60)
    print(" Face Model API Server v3.0")
    print("=" * 60)
    print(f"✓ Model loaded: {model_meta is not None}")
    if model_meta:
        print(f"✓ Features: {len(model_meta.get('feature_names', []))}")
        print(f"✓ Threshold: {model_meta.get('best_threshold', 'N/A')}")
    print(f"✓ MediaPipe available: {MEDIAPIPE_AVAILABLE}")
    print(f"✓ Upload folder: {UPLOAD_FOLDER}")
    print("=" * 60)
    print("🌐 Server running on http://0.0.0.0:3000")
    print("=" * 60)
    print("\nAvailable endpoints:")
    print("  POST /api/predict/realtime      - Real-time camera feed")
    print("  POST /api/predict/csv           - CSV file upload")
    print("  POST /api/predict/video-process - Complete video processing")
    print("  GET  /api/model/info            - Model information")
    print("  GET  /api/test-mediapipe        - Test MediaPipe setup")
    print("  GET  /health                    - Health check")
    print("=" * 60)
    
    if not MEDIAPIPE_AVAILABLE:
        print("\n  WARNING: MediaPipe not available!")
        print("   Video processing will NOT work.")
        print("   Test endpoint: http://localhost:3000/api/test-mediapipe")
        print("=" * 60)
    
    app.run(host="0.0.0.0", port=3000, debug=True)