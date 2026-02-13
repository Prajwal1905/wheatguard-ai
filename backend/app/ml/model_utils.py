import os
from io import BytesIO
from PIL import Image
import numpy as np

from app.ml.ai_helper import (
    get_short_remedy,
    get_remedy_explanation
)

try:
    import onnxruntime as ort
except:
    ort = None

DISEASE_CLASSES = [
    "Aphid",
    "Black Rust",
    "Blast",
    "Brown Rust",
    "Common Root Rot",
    "Fusarium Head Blight",
    "Leaf Blight",
    "Mildew",
    "Mite",
    "Septoria",
    "Smut",
    "Stem fly",
    "Tan spot",
    "Yellow Rust",
    "BYDV",
    "Black_Chaff",
    "Karnal_Bunt",
    "Powdery_Mildew",
    "Healthy"
]

IMAGE_SIZE = 380   
ONNX_PATH = os.path.join(os.path.dirname(__file__), "wheat_disease_b3.onnx")

onnx_session = None

def load_onnx():
    global onnx_session

    if ort is None:
        print(" onnxruntime NOT installed")
        return

    if not os.path.exists(ONNX_PATH):
        print(f" ONNX not found: {ONNX_PATH}")
        return

    try:
        onnx_session = ort.InferenceSession(
            ONNX_PATH,
            providers=["CPUExecutionProvider"]
        )
        print(" 19-class EfficientNet-B3 ONNX loaded.")
    except Exception as e:
        print(" Failed to load ONNX:", e)
        onnx_session = None


def load_model():
    load_onnx()
    if onnx_session:
        print(" Model ready.")
    else:
        print(" ERROR: model NOT loaded")


def preprocess_image(image_bytes: bytes):
    img = Image.open(BytesIO(image_bytes)).convert("RGB")
    img = img.resize((IMAGE_SIZE, IMAGE_SIZE))

    arr = np.array(img).astype("float32") / 255.0

    mean = np.array([0.485, 0.456, 0.406], dtype="float32")
    std = np.array([0.229, 0.224, 0.225], dtype="float32")

    arr = (arr - mean) / std
    arr = arr.transpose(2, 0, 1)
    arr = np.expand_dims(arr, 0)
    return arr


def softmax(x):
    e = np.exp(x - np.max(x))
    return e / e.sum()


def predict_image(image_bytes: bytes, language="en"):
    global onnx_session

    if onnx_session is None:
        load_onnx()

    if onnx_session is None:
        return {"error": "ONNX model not loaded"}

    x = preprocess_image(image_bytes)
    inp_name = onnx_session.get_inputs()[0].name

    logits = onnx_session.run(None, {inp_name: x})[0][0]
    probs = softmax(logits)

    idx = int(np.argmax(probs))
    predicted = DISEASE_CLASSES[idx]
    conf = float(probs[idx] * 100)

    remedy = get_short_remedy(predicted, language)
    explanation = get_remedy_explanation(predicted, language)

    return {
        "exact_disease": predicted,
        "confidence": conf,
        "remedy": remedy,
        "ai_explanation": explanation,
        "backend": "19-class-efficientnet-b3-onnx"
    }
