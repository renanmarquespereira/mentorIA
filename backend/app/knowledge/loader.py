import json
from functools import lru_cache
from pathlib import Path

@lru_cache(maxsize=1)
def load_methodology():
    path = Path(__file__).with_name("methodology.json")
    return json.loads(path.read_text(encoding="utf-8"))

def compact_methodology():
    data = load_methodology()
    return {
        "principles": data["principles"],
        "pillars": {
            key: {
                "name": value["name"],
                "goal": value["goal"],
                "core_concepts": value["core_concepts"],
                "rules": value["rules"],
            }
            for key, value in data["pillars"].items()
        }
    }
