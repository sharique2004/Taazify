import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from langchain_ollama import OllamaLLM
from langchain_core.prompts import ChatPromptTemplate
import json

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── LangChain + Ollama Setup ──
MODEL_NAME = "llama3.1:8b"
print(f"Initializing LangChain with Ollama model: {MODEL_NAME}")

llm = OllamaLLM(model=MODEL_NAME, temperature=0.7)

RECIPE_PROMPT = ChatPromptTemplate.from_messages([
    ("system", """You are a creative home cook AI. The user will give you a list of ingredients they have in their pantry. Some items are expiring soon and should be prioritized.

Generate exactly 3 quick, practical recipes using ONLY the provided ingredients (plus common pantry staples like salt, pepper, oil, garlic, onion).

You MUST respond with ONLY a valid JSON object in this exact format, no other text:
{{
  "recipes": [
    {{
      "name": "Recipe Name",
      "emoji": "🍳",
      "cookTime": "15 min",
      "difficulty": "Easy",
      "ingredients": ["ingredient 1", "ingredient 2"],
      "steps": ["Step 1 description", "Step 2 description", "Step 3 description"]
    }}
  ]
}}

Rules:
- Keep recipes simple and quick (under 30 minutes)
- Use 2-5 of the provided ingredients per recipe
- Prioritize ingredients marked as expiring soon
- Give each recipe a fun, appetizing name
- Include a relevant food emoji
- Keep steps concise (1 sentence each, max 6 steps)
- Difficulty is one of: Easy, Medium, Hard
- Return ONLY the JSON, no markdown fences, no explanation"""),
    ("human", """Here are my pantry items:

{items}

Items expiring soon (USE THESE FIRST): {urgent_items}

Generate 3 recipes using these ingredients.""")
])

chain = RECIPE_PROMPT | llm


class RecipeRequest(BaseModel):
    items: list[str]
    urgent_items: list[str] = []


@app.post("/recipes")
async def generate_recipes(request: RecipeRequest):
    if not request.items:
        return {"recipes": [], "error": "No items provided"}

    print(f"\n{'='*50}")
    print(f"Generating recipes for {len(request.items)} items")
    print(f"Items: {request.items}")
    print(f"Urgent: {request.urgent_items}")

    try:
        result = chain.invoke({
            "items": ", ".join(request.items),
            "urgent_items": ", ".join(request.urgent_items) if request.urgent_items else "None"
        })

        print(f"Raw LLM output: {result[:300]}...")

        # Parse JSON from response
        parsed = parse_recipe_output(result)
        print(f"Parsed {len(parsed.get('recipes', []))} recipes")
        return parsed

    except Exception as e:
        error_msg = str(e)
        print(f"Error: {error_msg}")

        # Check if Ollama is not running
        if "Connection refused" in error_msg or "connect" in error_msg.lower():
            return {
                "recipes": [],
                "error": "Ollama is not running. Start it with: ollama serve"
            }

        return {"recipes": [], "error": error_msg}


@app.get("/health")
async def health():
    """Health check — also verifies Ollama is reachable."""
    try:
        test = llm.invoke("Say 'ok'")
        return {"status": "ok", "model": MODEL_NAME}
    except Exception as e:
        return {"status": "error", "error": str(e)}


def parse_recipe_output(output_text: str) -> dict:
    """Parse JSON from LLM output, handling common formatting issues."""
    text = output_text.strip()

    # Strip markdown fences
    if "```json" in text:
        text = text.split("```json")[1]
        if "```" in text:
            text = text.split("```")[0]
    elif "```" in text:
        parts = text.split("```")
        if len(parts) >= 2:
            text = parts[1]

    text = text.strip()

    # Find JSON object
    start = text.find("{")
    end = text.rfind("}")
    if start != -1 and end != -1:
        text = text[start:end + 1]

    try:
        result = json.loads(text)
        if "recipes" not in result:
            result = {"recipes": []}
        return result
    except json.JSONDecodeError as e:
        print(f"JSON Parse Error: {e}")
        print(f"Attempted: {text[:200]}...")

        # Fallback: try to extract individual recipe objects
        return {"recipes": [], "error": "Failed to parse recipe JSON", "raw": output_text}


if __name__ == "__main__":
    print(f"Starting AI Recipe Server on http://localhost:8001")
    print(f"Using model: {MODEL_NAME}")
    print(f"Endpoint: POST /recipes")
    uvicorn.run(app, host="0.0.0.0", port=8001)
