import numpy as np
import pandas as pd
import io

# Landmark indices for facial features
IDX = {
    "mouth_left": 61, 
    "mouth_right": 291, 
    "upper_lip": 13, 
    "lower_lip": 14,
    "left_eye_upper": 159, 
    "left_eye_lower": 145,
    "right_eye_upper": 386, 
    "right_eye_lower": 374,
    "left_eye_outer": 33, 
    "left_eye_inner": 133,
    "right_eye_outer": 362, 
    "right_eye_inner": 263,
    "left_brow": 105, 
    "right_brow": 334,
    "left_inner_brow": 70, 
    "right_inner_brow": 300,
    "nose_tip": 1, 
    "nose_bridge": 168,
    "chin": 152,
}


def safe_dist(a, b):
    """Calculate Euclidean distance with small epsilon to avoid division by zero"""
    return np.linalg.norm(a - b) + 1e-9


def build_feature_vector_from_csv(csv_bytes, model_meta):
    
    # Parse CSV
    df = pd.read_csv(io.StringIO(csv_bytes.decode()))
    pts = df[['x', 'y', 'z']].values
    
    # Helper function to get point by index
    def P(i): 
        return pts[i]
    
    # Calculate inter-eye distance for normalization
    left_eye_center = np.mean([P(33), P(133), P(160), P(158)], axis=0)
    right_eye_center = np.mean([P(362), P(263), P(387), P(385)], axis=0)
    inter = safe_dist(left_eye_center, right_eye_center)
    
    # Extract normalized features
    features = {
        "mouth_width": safe_dist(P(IDX["mouth_left"]), P(IDX["mouth_right"])) / inter,
        "mouth_open": safe_dist(P(IDX["upper_lip"]), P(IDX["lower_lip"])) / inter,
        "left_eye_openness": safe_dist(P(IDX["left_eye_upper"]), P(IDX["left_eye_lower"])) / inter,
        "right_eye_openness": safe_dist(P(IDX["right_eye_upper"]), P(IDX["right_eye_lower"])) / inter,
        "nose_length": safe_dist(P(IDX["nose_bridge"]), P(IDX["nose_tip"])) / inter,
        "chin_tension": safe_dist(P(IDX["chin"]), 0.5 * (P(IDX["mouth_left"]) + P(IDX["mouth_right"]))) / inter
    }
    
    # Build feature vector in the correct order
    vec = []
    for name in model_meta["feature_names"]:
        vec.append(float(features.get(name, 0.0)))
    
    return np.array(vec, dtype=float)