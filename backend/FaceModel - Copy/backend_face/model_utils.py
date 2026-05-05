import joblib
import numpy as np

# Path to trained model
MODEL_FILE = "rf_basic.joblib"

# Load model metadata
model_meta = joblib.load(MODEL_FILE)

# Environment mappings
TRIGGER_ENVIRONMENTS = [
    'youtube video',
    'fan',
    'laptop',
    'teacher',
    'high pitch sound',
    'high contrast color'
]

NON_TRIGGER_ENVIRONMENTS = [
    'home',
    'Liked places'
]


def predict_from_vector(vec):
    """
    Predict mood/trigger status and possible environments from feature vector

    Args:
        vec: numpy array of extracted features (1D)

    Returns:
        dict with trigger_status, mood, confidence, and possible_environments
    """

    model = model_meta["model"]
    le = model_meta["label_encoder"]

    # Optional components (robust if missing)
    scaler = model_meta.get("scaler", None)
    best_threshold = model_meta.get("best_threshold", 0.5)

    x = vec.reshape(1, -1)

    # Scale only if scaler exists
    if scaler is not None:
        x = scaler.transform(x)

    # Predict probabilities
    probs = model.predict_proba(x)[0]

    # Binary classifier → class 1 assumed as Trigger
    trigger_prob = float(probs[1]) if len(probs) > 1 else float(probs[0])

    is_trigger = trigger_prob >= best_threshold

    pred_idx = 1 if is_trigger else 0
    mood = le.inverse_transform([pred_idx])[0]

    trigger_status = "trigger" if is_trigger else "no_trigger"
    possible_environments = (
        TRIGGER_ENVIRONMENTS if is_trigger else NON_TRIGGER_ENVIRONMENTS
    )

    return {
        "trigger_status": trigger_status,
        "mood": str(mood),
        "confidence": trigger_prob,
        "possible_environments": possible_environments
    }
