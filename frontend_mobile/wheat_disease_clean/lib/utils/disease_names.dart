class DiseaseNames {
  static const Map<String, Map<String, String>> names = {
    

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
    },

    "Healthy": {
      "en": "Healthy crop",
      "hi": "स्वस्थ फसल",
      "mr": "निरोगी पीक",
    },
  };

  static String get(String disease, String lang) {
    if (names.containsKey(disease)) {
      return names[disease]?[lang] ?? disease;
    }
    return disease;
  }
}
