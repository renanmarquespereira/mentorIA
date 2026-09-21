from fastapi import APIRouter, Depends
from app.api.deps import current_user
from app.models.user import User
from app.knowledge.loader import load_methodology

router = APIRouter(prefix="/knowledge", tags=["knowledge"])

@router.get("/status")
def knowledge_status(user: User = Depends(current_user)):
    data = load_methodology()
    return {
        "loaded": True,
        "version": data["version"],
        "source": data["source"],
        "pillars": [v["name"] for v in data["pillars"].values()],
        "principles_count": len(data["principles"])
    }
