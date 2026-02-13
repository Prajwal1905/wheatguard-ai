# app/routes/ai_explain.py

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional  

from app.ml.ai_helper import (
    get_short_remedy,
    get_remedy_explanation,
    get_farmer_chat_reply
)

router = APIRouter(prefix="/ai", tags=["AI Assistant"])


class DiseaseRequest(BaseModel):
    disease: str
    language: str = "en"


class ChatRequest(BaseModel):
    question: str
    disease: Optional[str] = None     
    language: str = "en"


@router.post("/remedy")
def ai_short_remedy(req: DiseaseRequest):
    try:
        result = get_short_remedy(req.disease, req.language)
        return {"remedy": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/explain")
def ai_explanation(req: DiseaseRequest):
    try:
        result = get_remedy_explanation(req.disease, req.language)
        return {"explanation": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/chat")
def ai_chat(req: ChatRequest):
    try:
        reply = get_farmer_chat_reply(
            question=req.question,
            disease_name=req.disease,
            language=req.language
        )
        return {"reply": reply}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
