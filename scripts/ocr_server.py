import uvicorn
from fastapi import FastAPI, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from transformers import Qwen2VLForConditionalGeneration, AutoTokenizer, AutoProcessor
from qwen_vl_utils import process_vision_info
import torch
import io
from PIL import Image
import json

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Load Model: Qwen2-VL-2B-Instruct (SOTA Small VLM for OCR)
MODEL_PATH = "Qwen/Qwen2-VL-2B-Instruct"

print(f"Loading {MODEL_PATH}... (This will download ~3GB)")

try:
    # Auto-detect device
    device = "cpu"
    if torch.cuda.is_available():
        device = "cuda"
    elif torch.backends.mps.is_available():
        device = "mps"
        
    print(f"Running on device: {device}")
    
    # ── DTYPE SELECTION ──
    # MPS does NOT reliably support bfloat16 — it causes "probability tensor 
    # contains inf, nan or element < 0" errors during generation.
    # Use float32 for MPS (stable but slower) and bfloat16 for CUDA.
    if device == "cuda":
        dtype = torch.bfloat16
    else:
        dtype = torch.float32
    
    print(f"Using dtype: {dtype}")
    
    # Load model
    model = Qwen2VLForConditionalGeneration.from_pretrained(
        MODEL_PATH,
        torch_dtype=dtype,
        device_map="auto" if device == "cuda" else None
    )
    if device == "mps":
        model = model.to("mps")
    elif device == "cpu":
        pass  # already on CPU
        
    # Load processor
    processor = AutoProcessor.from_pretrained(MODEL_PATH)
    
    print("Model loaded successfully!")
except Exception as e:
    print(f"CRITICAL ERROR LOADING MODEL: {e}")
    model = None
    processor = None

# ── Receipt analysis prompt ──
RECEIPT_PROMPT = """You are analyzing a grocery store receipt image. Extract ALL line items that represent purchased products.

IMPORTANT CONTEXT: Receipt text uses POS-abbreviated names. Examples:
- "GV LG WHT EGGS 12" = Great Value Large White Eggs 12ct
- "BNNA YLW LB" = Yellow Bananas per lb
- "MLK 2% GAL" = 2% Milk Gallon
- "BNLS SKNLS CKN BRST" = Boneless Skinless Chicken Breast
- "DUNKINDONUTS FN" = Dunkin Donuts (Food/Nontaxable)
- "MP 2 PC MILK FN" = Market Pantry 2 Pack Milk
- "DNZN CARGO S" = Danskin Cargo Shorts (clothing)
- "NUTELLA 725G" = Nutella 725g jar
- "CHK BST BNLS" = Chicken Breast Boneless
- "GV MIX VEG" = Great Value Mixed Vegetables
- "GV WHITE 675" = Great Value White product 675g
- Trailing letters like J, D, FN, FC, T, N are tax codes, not part of the name.
- Numbers like 003077206122 are UPC barcodes, ignore them.

Return a JSON object: {"items": [{"name": "<raw receipt text>", "category": "<best guess: GROCERY, CLOTHING, HEALTH, HOME, etc.>", "price": <number>, "quantity": <number>, "shelfDays": <integer, estimated shelf life in days>}]}

Rules:
- Use the EXACT text from the receipt as the "name" field. Do not expand abbreviations.
- Skip subtotal, total, tax, payment, and other non-item lines.
- Include ALL items, even non-food. We filter on the client side.
- For "shelfDays", estimate the typical shelf life in days (e.g., milk=7, eggs=21, bananas=5, canned goods=365). For non-perishable or non-food items, use 0.
- Do not invent items. Only extract what you can read.
- Return ONLY valid JSON, no markdown fences."""

@app.post("/analyze")
async def analyze_receipt(file: UploadFile = File(...)):
    if model is None:
        return {"error": "Model not loaded. Check server logs."}

    print(f"\n{'='*50}")
    print(f"Processing image: {file.filename}")
    
    try:
        # 1. Read Image
        contents = await file.read()
        image = Image.open(io.BytesIO(contents)).convert("RGB")
        print(f"Original image size: {image.size}")
        
        # 2. Resize — keep max dimension ≤ 768px for MPS stability
        #    Larger images create more visual tokens, increasing chance of NaN
        max_dimension = 768 if device == "mps" else 1024
        if max(image.size) > max_dimension:
            scale = max_dimension / max(image.size)
            new_size = (int(image.width * scale), int(image.height * scale))
            print(f"Resizing to {new_size} for {device} stability...")
            image = image.resize(new_size, Image.Resampling.LANCZOS)
        else:
            print(f"Image size OK: {image.size}")
        
        # 3. Prepare Conversation
        messages = [
            {
                "role": "user",
                "content": [
                    {"type": "image", "image": image},
                    {"type": "text", "text": RECEIPT_PROMPT},
                ],
            }
        ]
        
        # 4. Process Inputs
        text = processor.apply_chat_template(
            messages, tokenize=False, add_generation_prompt=True
        )
        image_inputs, video_inputs = process_vision_info(messages)
        inputs = processor(
            text=[text],
            images=image_inputs,
            videos=video_inputs,
            padding=True,
            return_tensors="pt",
        )
        inputs = inputs.to(model.device)
        
        # 5. Generate with torch.no_grad() for stability
        print("Starting model generation...")
        with torch.no_grad():
            generated_ids = model.generate(
                **inputs, 
                max_new_tokens=2048,
                do_sample=False,  # Greedy decoding — most stable
            )
        print("Model generation complete.")
        
        generated_ids_trimmed = [
            out_ids[len(in_ids):] for in_ids, out_ids in zip(inputs.input_ids, generated_ids)
        ]
        output_text = processor.batch_decode(
            generated_ids_trimmed, skip_special_tokens=True, clean_up_tokenization_spaces=False
        )[0]
        
        print(f"Raw Output: {output_text[:500]}...")
        
        # 6. Parse JSON — handle both {...} and [...]
        result = parse_model_output(output_text)
        print(f"Parsed {len(result.get('items', []))} items")
        return result

    except Exception as e:
        error_msg = str(e)
        print(f"Inference Error: {error_msg}")
        
        # Specific fix for MPS tensor issues
        if "probability tensor" in error_msg or "inf" in error_msg or "nan" in error_msg:
            return {
                "items": [], 
                "error": "Image too complex for GPU. Try a clearer/smaller photo.",
                "raw": error_msg
            }
        return {"items": [], "error": error_msg, "raw": error_msg}


def parse_model_output(output_text):
    """Robustly parse JSON from model output, handling markdown fences and arrays."""
    json_str = output_text.strip()
    
    # Strip markdown fences
    if "```json" in json_str:
        json_str = json_str.split("```json")[1]
        if "```" in json_str:
            json_str = json_str.split("```")[0]
    elif "```" in json_str:
        parts = json_str.split("```")
        if len(parts) >= 2:
            json_str = parts[1]
    
    json_str = json_str.strip()
    
    # Find the outermost JSON structure — could be {...} or [...]
    start_obj = json_str.find("{")
    start_arr = json_str.find("[")
    end_obj = json_str.rfind("}")
    end_arr = json_str.rfind("]")
    
    # Pick whichever structure starts first
    if start_arr != -1 and (start_obj == -1 or start_arr < start_obj):
        json_str = json_str[start_arr : end_arr + 1]
    elif start_obj != -1 and end_obj != -1:
        json_str = json_str[start_obj : end_obj + 1]
    
    try:
        result = json.loads(json_str)
        if isinstance(result, list):
            result = {"items": result}
        if "items" not in result:
            result = {"items": []}
        return result
    except json.JSONDecodeError as e:
        print(f"JSON Parse Error: {e}")
        print(f"Attempted to parse: {json_str[:200]}...")
        return {"items": [], "error": "Failed to parse JSON", "raw": output_text}


if __name__ == "__main__":
    print("Starting Qwen2-VL-2B OCR Server on http://localhost:8000")
    uvicorn.run(app, host="0.0.0.0", port=8000)
