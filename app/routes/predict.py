from flask import Blueprint, request, send_file, jsonify, current_app
import os
import uuid
import joblib
import pandas as pd
from ..utils.feature_extraction import extract_features

bp = Blueprint("prediction", __name__)

# Global variables for models
model = None
mlb = None
UPLOAD_DIR = os.path.abspath("temp")

def init_models():
    """Lazily initialize models."""
    global model, mlb
    
    if model is not None and mlb is not None:
        return

    base_dir = os.getcwd()
    models_dir = os.path.join(base_dir, "models")
    
    model_path = os.path.join(models_dir, "multi_rf_model.pkl")
    mlb_path = os.path.join(models_dir, "env_label_encoder.pkl")
    
    if not os.path.exists(models_dir):
        os.makedirs(models_dir, exist_ok=True)

    if not os.path.exists(model_path) or not os.path.exists(mlb_path):
        # We won't raise error here to allow app start, but will fail on predict
        print(f"WARNING: Models not found in {models_dir}")
        return

    print(f"Loading models from {models_dir}...")
    try:
        model = joblib.load(model_path)
        mlb = joblib.load(mlb_path)
        print("Models loaded successfully.")
    except Exception as e:
        print(f"Error loading models: {e}")

@bp.route("/predict", methods=["POST"])
def predict():
    # Ensure models are loaded
    init_models()
    
    if model is None or mlb is None:
        return jsonify({"error": "Models not loaded. Please ensure 'multi_rf_model.pkl' and 'env_label_encoder.pkl' are in the 'models/' directory."}), 500

    print("Received prediction request")
    
    if "file" not in request.files:
        return jsonify({"error": "No CSV file provided"}), 400

    file = request.files["file"]
    uid = str(uuid.uuid4())

    # Ensure upload dir exists
    if not os.path.exists(UPLOAD_DIR):
        os.makedirs(UPLOAD_DIR, exist_ok=True)

    csv_path = os.path.join(UPLOAD_DIR, f"{uid}.csv")
    file.save(csv_path)

    try:
        df = pd.read_csv(csv_path)

        window = 60
        stride = 30

        features = []

        for start in range(0, len(df) - window, stride):
            win = df.iloc[start:start + window]
            feat = extract_features(win)
            if feat is None:
                continue
            features.append({
                "start_frame": start,
                "end_frame": start + window,
                **feat
            })
        
        if not features:
             return jsonify({"error": "No valid features extracted from data"}), 400

        feat_df = pd.DataFrame(features).fillna(0.0)

        frame_cols = feat_df[["start_frame", "end_frame"]].copy()
        X = feat_df.drop(columns=["start_frame", "end_frame"])

        y_pred = model.predict(X)

        label_pred = y_pred[:, 0]
        env_pred = y_pred[:, 1:]

        env_labels = mlb.classes_
        decoded_env = [
            [env_labels[i] for i, v in enumerate(row) if v == 1]
            for row in env_pred
        ]

        out_df = pd.DataFrame({
            "start_frame": frame_cols["start_frame"],
            "end_frame": frame_cols["end_frame"],
            "label_pred": ["trigger" if x == 1 else "normal" for x in label_pred],
            "env_factors_pred": [str(e) for e in decoded_env]
        })

        out_path = os.path.join(UPLOAD_DIR, f"{uid}_predictions.csv")
        out_df.to_csv(out_path, index=False)

        return send_file(out_path, as_attachment=True)
    
    except Exception as e:
        print(f"Prediction error: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        # Cleanup input file if desired
        if os.path.exists(csv_path):
            os.remove(csv_path)
