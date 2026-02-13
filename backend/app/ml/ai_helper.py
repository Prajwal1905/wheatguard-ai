import os
from datetime import datetime
from typing import Optional

from dotenv import load_dotenv
from openai import OpenAI

load_dotenv()

client = OpenAI(
    base_url="https://openrouter.ai/api/v1",
    api_key=os.getenv("OPENROUTER_API_KEY"),
)

LANG_MAP = {
    "en": "English",
    "hi": "Hindi",
    "mr": "Marathi",
}

DISEASE_TRANSLATIONS = {
    "Healthy": {
        "en": "Healthy crop",
        "hi": "फसल स्वस्थ है",
        "mr": "पिक निरोगी आहे",
    },

    "Aphid": {
        "en": "Aphid (insect)",
        "hi": "एफिड / माहू कीट",
        "mr": "मावा किडा",
    },

    "Black Rust": {
        "en": "Black Rust",
        "hi": "काला रतुवा",
        "mr": "काळा गंज",
    },

    "Blast": {
        "en": "Blast disease",
        "hi": "ब्लास्ट रोग",
        "mr": "ब्लास्ट रोग",
    },

    "Brown Rust": {
        "en": "Brown Rust",
        "hi": "भूरा रतुवा",
        "mr": "तपकिरी गंज",
    },

    "Common Root Rot": {
        "en": "Common Root Rot",
        "hi": "जड़ सड़न",
        "mr": "मूळ कुज",
    },

    "Fusarium Head Blight": {
        "en": "Fusarium Head Blight",
        "hi": "फ्यूजेरियम हेड ब्लाइट",
        "mr": "फ्युजेरियम हेड ब्लाइट",
    },

    "Leaf Blight": {
        "en": "Leaf Blight",
        "hi": "पत्ती झुलसा",
        "mr": "पान झुलसा",
    },

    "Mildew": {
        "en": "Mildew",
        "hi": "फफूंदी",
        "mr": "बुरशी",
    },

    "Mite": {
        "en": "Mite",
        "hi": "माइट कीट",
        "mr": "माईट किडा",
    },

    "Septoria": {
        "en": "Septoria",
        "hi": "सेप्टोरिया रोग",
        "mr": "सेप्टोरिया रोग",
    },

    "Smut": {
        "en": "Smut",
        "hi": "स्मट रोग",
        "mr": "स्मट रोग",
    },

    "Stem fly": {
        "en": "Stem fly",
        "hi": "तना मक्खी",
        "mr": "खोड माशी",
    },

    "Tan spot": {
        "en": "Tan spot",
        "hi": "टैन स्पॉट",
        "mr": "टॅन स्पॉट",
    },

    "Yellow Rust": {
        "en": "Yellow Rust",
        "hi": "पीला रतुवा",
        "mr": "पिवळा गंज",
    },

    "BYDV": {
        "en": "Barley Yellow Dwarf Virus",
        "hi": "बार्ली येलो ड्वार्फ वायरस",
        "mr": "बार्ली यलो ड्वार्फ व्हायरस",
    },

    "Black_Chaff": {
        "en": "Black Chaff (bacterial)",
        "hi": "ब्लैक चाफ (बैक्टीरियल)",
        "mr": "ब्लॅक चाफ (बॅक्टेरियल)",
    },

    "Karnal_Bunt": {
        "en": "Karnal Bunt",
        "hi": "कर्नाल बंट",
        "mr": "कर्नाल बंट",
    },

    "Powdery_Mildew": {
        "en": "Powdery Mildew",
        "hi": "पाउडरी फफूंदी",
        "mr": "पावडरी बुरशी",
    }
}


SAFE_FUNGICIDES = [
    "Mancozeb",
    "Propiconazole",
    "Tebuconazole",
    "Azoxystrobin",
    "Difenoconazole",
    "Hexaconazole",
    "Zineb",
    "Captan",
]

SAFE_INSECTICIDES = [
    
    "Neem based (Azadirachtin)",
    "Flonicamid",
    "Thiamethoxam",
    "Lambda-cyhalothrin",
]

SAFE_BIO_SOLUTIONS = [
    "Neem oil spray",
    "Trichoderma",
    "Beauveria",
    "Cow dung / buttermilk based local extracts (as advised by local experts)",
]

def _current_season_india() -> str:
    month = datetime.utcnow().month
    # Rabi approx: Nov–Mar
    if month in (11, 12, 1, 2, 3):
        return "Rabi (winter) season"
    return "off-season"


def _get_display_disease_name(raw_name: str, language: str) -> str:
    """
    Map raw class name -> farmer-friendly name in selected language.
    Works for the 15 exact disease names.
    """
    if not raw_name:
        return "wheat crop problem"

    key = raw_name.strip()
    mapping = DISEASE_TRANSLATIONS.get(key)
    if not mapping:
        
        return key.replace("_", " ").title()

    if language == "hi":
        return mapping.get("hi", mapping["en"])
    if language == "mr":
        return mapping.get("mr", mapping["en"])
    return mapping["en"]


def get_short_remedy(disease_name: str, language: str = "en") -> str:
    lang_full = LANG_MAP.get(language, "English")
    season = _current_season_india()

    display_name = _get_display_disease_name(disease_name, language)

    prompt = f"""
You are a Krishi Vaidya (agri doctor) helping Indian wheat farmers.

Write 3–4 VERY SIMPLE bullet points to control this wheat problem.

Disease (farmer name): **{display_name}**
Season now: {season}

RULES (VERY IMPORTANT):
- Write in very simple {lang_full}, like talking to a small farmer.
- Use ONLY short, clear bullet points.
- DO NOT mention dose, ml/litre, grams, or exact spray schedule.
- DO NOT mention any pesticide other than the list given below.
- Prefer non-chemical and organic steps if attack is mild.

If you need to suggest FUNGICIDES for wheat, you may ONLY use names from this list:
- Mancozeb
- Propiconazole
- Tebuconazole
- Azoxystrobin
- Difenoconazole
- Hexaconazole
- Zineb
- Captan

If you need to suggest INSECTICIDES (for Aphid / Mite / Stem fly), you may ONLY use:
- Neem based (Azadirachtin)
- Flonicamid
- Thiamethoxam
- Lambda-cyhalothrin

If you want to suggest BIO / ORGANIC options, you may use:
- Neem oil spray
- Trichoderma
- Beauveria
- Cow dung / buttermilk based local extracts (without recipe details)

ALSO INCLUDE non-chemical steps, for example:
- remove badly infected leaves or tillers
- avoid water logging
- keep enough spacing / avoid overcrowding
- use clean seed and crop rotation

You MUST clearly tell:
- if this problem is mild or serious in this season,
- what farmer should NOT do (no overdose, no random mixing, no repeated spraying).

FORMAT:
- ONLY bullet points (• or -).
- No headings, no long paragraphs.

Language: {lang_full}
"""

    try:
        resp = client.chat.completions.create(
            model="x-ai/grok-4-fast",
            messages=[{"role": "user", "content": prompt}],
            max_tokens=700,
        )
        return resp.choices[0].message.content.strip()
    except Exception as e:
        print(f" short_remedy error: {e}")
        return f"Remedy not available right now for {display_name}."


def get_remedy_explanation(disease_name: str, language: str = "en") -> str:
    lang_full = LANG_MAP.get(language, "English")
    season = _current_season_india()

    display_name = _get_display_disease_name(disease_name, language)

    prompt = f"""
Explain this wheat problem for an Indian farmer.

Disease (farmer name): **{display_name}**
Season now: {season}

Write answer ONLY in very simple {lang_full}.  
Do NOT mix English with local language except medicine names.
Do NOT mention dose, ml/litre, grams or exact spray schedule.

You MUST follow this structure:

### What is this disease?
- 2–3 very simple lines.
- No scientific language.

### Why does it happen? (Season: {season})
- 2–3 simple points.
- Mention weather/season and management mistakes only if relevant.

### Early symptoms farmers can notice
- 3–5 bullet points.
- Describe what they SEE on leaf, stem or grain.

### Is it dangerous right now?
- 2–3 lines:
  - clearly say if it is serious or mild in current season,
  - no panic, but honest warning if it spreads fast.

### What farmers should do now?
- 3–6 clear steps.
- Include a mix of:
  - cultural practices (removing diseased parts, proper spacing, irrigation, clean field),
  - safe fungicides / insecticides from the lists below,
  - bio / organic options.

Allowed FUNGICIDES (you may use only these names, if needed):
- Mancozeb
- Propiconazole
- Tebuconazole
- Azoxystrobin
- Difenoconazole
- Hexaconazole
- Zineb
- Captan

Allowed INSECTICIDES (for Aphid / Mite / Stem fly, only if really needed):
- Neem based (Azadirachtin)
- Flonicamid
- Thiamethoxam
- Lambda-cyhalothrin

Allowed BIO / ORGANIC options:
- Neem oil spray
- Trichoderma
- Beauveria
- Cow dung / buttermilk based local extracts (as per local advice)

You MUST warn:
- no overdose,
- no random mixing of many chemicals,
- follow local agriculture officer / label instructions.

### How to prevent it next time?
- 3–5 bullets.
- Mention seed treatment (without exact dose), crop rotation, proper irrigation, sowing time, resistant varieties (if relevant).

Tone:
- Calm, friendly, like a village Krishi Sevak.
- Very easy for rural farmers.
- No banned chemicals.
- No heavy technical words.

Language: {lang_full}
"""

    try:
        resp = client.chat.completions.create(
            model="x-ai/grok-4-fast",
            messages=[{"role": "user", "content": prompt}],
            max_tokens=1400,
        )
        return resp.choices[0].message.content.strip()
    except Exception as e:
        print(f" detailed_explanation error: {e}")
        return f"Explanation not available right now for {display_name}."


def get_farmer_chat_reply(
    question: str,
    disease_name: Optional[str] = None,
    language: str = "en",
) -> str:
    """
    Chatbot used on ResultPage.
    Farmer can ask doubt in EN/HI/MR. Answer in same language.
    """
    lang_full = LANG_MAP.get(language, "English")
    season = _current_season_india()

    if disease_name:
        display_name = _get_display_disease_name(disease_name, language)
        disease_text = f"{display_name}"
    else:
        disease_text = "wheat crop problem"

    prompt = f"""
You are an AI Krishi Sevak helping Indian wheat farmers.

Farmer question (in {lang_full}):
\"\"\"{question}\"\"\" 

Context:
- Detected problem: {disease_text}
- Season now: {season}

Answer requirements:
- Reply in very simple {lang_full}, like talking to a small / marginal farmer.
- Format: 4–6 short bullet points OR 2–3 very short paragraphs.
- DO NOT mention dose, ml/litre, grams, or exact spray schedule.
- DO NOT suggest any pesticides other than the allowed list below.

Allowed FUNGICIDES:
- Mancozeb
- Propiconazole
- Tebuconazole
- Azoxystrobin
- Difenoconazole
- Hexaconazole
- Zineb
- Captan

Allowed INSECTICIDES (Aphid / Mite / Stem fly):
- Neem based (Azadirachtin)
- Flonicamid
- Thiamethoxam
- Lambda-cyhalothrin

Allowed BIO / ORGANIC options:
- Neem oil spray
- Trichoderma
- Beauveria
- Cow dung / buttermilk based local extracts (without recipe).

If farmer asks about:
- medicine → suggest only from above list, and remind to follow label / local officer.
- danger → clearly say if crop is at high risk or not, without creating panic.
- cost → give rough idea only (e.g. "कम खर्च", "ज्यादा खर्च"), no exact rupee values.

ALWAYS:
- Be calm and encouraging.
- Remind: no overdose, no random mixing, and follow local Krishi Sevak / agriculture officer.

Language: {lang_full}
"""

    try:
        resp = client.chat.completions.create(
            model="x-ai/grok-4-fast",
            messages=[{"role": "user", "content": prompt}],
            max_tokens=900,
        )
        return resp.choices[0].message.content.strip()
    except Exception as e:
        print(f" farmer_chat error: {e}")
        return "Right now I am not able to answer. Please contact your local Krishi Sevak."
