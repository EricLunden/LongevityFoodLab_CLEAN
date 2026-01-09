import json
import requests
from recipe_scrapers import scrape_url, scrape_html
import logging
import os
import time
from urllib.parse import urlparse

# ---- SAFE TIER LOGGING (timing + env flag) ----
TIER_LOGGING_ENABLED = os.environ.get("TIER_LOGGING", "1") == "1"
if "_log_tier" not in globals():
    def _log_tier(tier: str, url: str, missing_fields=None, quality=None, duration_ms=None):
        if not TIER_LOGGING_ENABLED:
            return
        try:
            domain = urlparse(url).netloc.lower() if url else ""
        except Exception:
            domain = ""
        rec = {
            "TIER_USED": tier,
            "site": domain,
            "url": (url or "")[:300],
            "missing": missing_fields or [],
            "quality": quality,
            "ms": duration_ms,
        }
        try:
            print(json.dumps(rec, separators=(",", ":")))
        except Exception:
            pass
        try:
            miss = ",".join(rec["missing"]) if rec["missing"] else ""
            print(f"TIER_USED={tier} site={domain} url={rec['url']} missing={miss} quality={quality} ms={duration_ms}")
        except Exception:
            pass
# ---- END SAFE TIER LOGGING ----

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Force BeautifulSoup to use html.parser (AWS Pandas layer includes lxml)
os.environ['BS4_PARSER'] = 'html.parser'

# ============================================================================
# MINIMAL SAFETY ADDITIONS (Dec 23 baseline + essential safety)
# ============================================================================

MIN_HTML_BYTES = 20000

def needs_full_fetch(html):
    """Check if HTML snippet needs full page fetch."""
    if not html:
        return True
    if len(html) < MIN_HTML_BYTES:
        return True
    html_lower = html.lower() if html else ""
    if "<html" not in html_lower or "<script" not in html_lower:
        return True
    return False

def fetch_full_html(url):
    """Fetch full HTML from URL."""
    try:
        headers = {
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
        }
        response = requests.get(url, headers=headers, timeout=15, allow_redirects=True)
        if response.status_code == 200:
            return response.text
        return None
    except Exception as e:
        logger.error(f"Fetch error: {e}")
        return None

def has_meaningful_instructions(instructions):
    """Check if instructions list has meaningful content."""
    if not instructions or not isinstance(instructions, list):
        return False
    meaningful = [inst.strip() for inst in instructions if isinstance(inst, str) and inst.strip() and len(inst.strip()) > 20]
    return len(meaningful) >= 3

def call_ai_fallback_simple(url, html):
    """Minimal AI fallback - only extracts verbatim, never generates."""
    try:
        api_key = os.environ.get('OPENAI_API_KEY')
        if not api_key:
            return None
        
        # AI kill switch
        if os.environ.get("DISABLE_AI") == "1":
            logger.info("LAMBDA/AI_DISABLED")
            return None
        
        # Truncate HTML
        html_truncated = html[:8000] if html and len(html) > 8000 else (html or "")
        
        prompt = f"""Extract recipe data from this HTML. Return ONLY a JSON object.

CRITICAL: Extract instructions VERBATIM from the page text.
DO NOT generate, summarize, infer, or rewrite instructions.
If instructions are not explicitly present, return empty array [] for instructions.

{{
  "title": "string",
  "ingredients": ["array of strings"],
  "instructions": ["array of strings - VERBATIM ONLY"],
  "servings": "string",
  "image": "string URL"
}}

HTML excerpt: {html_truncated[:2000]}

Return only valid JSON, no markdown, no backticks."""

        headers = {
            'Authorization': f'Bearer {api_key}',
            'Content-Type': 'application/json'
        }
        
        payload = {
            'model': 'gpt-4o-mini',
            'max_tokens': 800,
            'temperature': 0,
            'messages': [{'role': 'user', 'content': prompt}],
            'response_format': {'type': 'json_object'}
        }
        
        response = requests.post(
            'https://api.openai.com/v1/chat/completions',
            headers=headers,
            json=payload,
            timeout=10
        )
        
        if response.status_code == 200:
            result = response.json()
            content = result.get('choices', [{}])[0].get('message', {}).get('content', '').strip()
            if content:
                # Clean markdown if present
                if content.startswith('```json'):
                    content = content[7:]
                if content.startswith('```'):
                    content = content[3:]
                if content.endswith('```'):
                    content = content[:-3]
                content = content.strip()
                return json.loads(content)
        return None
    except Exception as e:
        logger.error(f"AI fallback error: {e}")
        return None

def lambda_handler(event, context):
    """
    AWS Lambda function for recipe parsing using recipe-scrapers.
    Dec 23 baseline with minimal AI safety additions.
    
    Execution order:
    1. recipe-scrapers runs FIRST (Tier-0)
    2. If instructions exist → IMMEDIATE RETURN
    3. If HTML snippet provided → fetch full page, retry recipe-scrapers
    4. AI only if instructions still empty after full fetch
    """
    try:
        start_time = time.time()
        
        # Parse event (handle both direct URL and API Gateway body formats)
        url = None
        html = None
        
        if 'url' in event:
            url = event['url']
        elif 'body' in event:
            try:
                body = json.loads(event['body']) if isinstance(event['body'], str) else event['body']
                url = body.get('url')
                html = body.get('html')  # Handle HTML snippets
            except json.JSONDecodeError:
                url = event['body']  # Direct URL in body
        
        if not url:
            logger.error("No URL provided in request.")
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                    'Access-Control-Allow-Methods': 'POST,OPTIONS'
                },
                'body': json.dumps({'error': 'No URL provided'})
            }
        
        logger.info(f"LAMBDA/TIER0: recipe-scrapers start url={url}")
        
        # ========================================================================
        # STEP 1: TIER-0 RECIPE-SCRAPERS (Dec 23 baseline - runs FIRST)
        # ========================================================================
        try:
            result = scrape_url(url)
            
            # Extract instructions
            instructions = result.instructions()
            # Convert to list if string
            if isinstance(instructions, str):
                instructions = [s.strip() for s in instructions.split('\n') if s.strip()]
            elif not isinstance(instructions, list):
                instructions = []
            
            # Check if instructions exist
            if has_meaningful_instructions(instructions):
                # IMMEDIATE RETURN - instructions found
                logger.info("LAMBDA/TIER0: success — FAST EXIT (instructions found)")
                
                response_data = {
                    'title': result.title() or 'Untitled Recipe',
                    'total_time': result.total_time() or None,
                    'cook_time': result.cook_time() or None,
                    'prep_time': result.prep_time() or None,
                    'yields': result.yields() or None,
                    'ingredients': result.ingredients() or [],
                    'instructions': instructions,
                    'image': result.image() or '',
                    'host': result.host() or '',
                    'author': result.author() or '',
                    'nutrition': result.nutrition() or {},
                    'source': 'recipe-scrapers-tier0',
                    'metadata': {'tier_used': 'tier0', 'ai_ran': 0}
                }
                
                try:
                    _dur = int((time.time() - start_time) * 1000)
                    _log_tier("tier0", url, missing_fields=None, quality=None, duration_ms=_dur)
                except Exception:
                    pass
                
                return {
                    'statusCode': 200,
                    'headers': {
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*',
                        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                        'Access-Control-Allow-Methods': 'POST,OPTIONS'
                    },
                    'body': json.dumps(response_data)
                }
            else:
                logger.info("LAMBDA/TIER0: no instructions found — checking HTML snippet")
        except Exception as e:
            logger.warning(f"LAMBDA/TIER0: recipe-scrapers failed: {e}")
        
        # ========================================================================
        # STEP 2: FULL FETCH GUARD (if HTML snippet provided)
        # ========================================================================
        if html and needs_full_fetch(html):
            logger.info(f"LAMBDA/FETCH: inbound html insufficient len={len(html)} — fetching full page")
            fetched_html = fetch_full_html(url)
            if fetched_html:
                html = fetched_html
                logger.info(f"LAMBDA/FETCH: fetched_html_len={len(html)}")
                
                # Retry recipe-scrapers with full HTML context
                try:
                    result = scrape_url(url)  # recipe-scrapers fetches its own HTML
                    instructions = result.instructions()
                    if isinstance(instructions, str):
                        instructions = [s.strip() for s in instructions.split('\n') if s.strip()]
                    elif not isinstance(instructions, list):
                        instructions = []
                    
                    if has_meaningful_instructions(instructions):
                        logger.info("LAMBDA/TIER0: success after full fetch — FAST EXIT")
                        
                        response_data = {
                            'title': result.title() or 'Untitled Recipe',
                            'total_time': result.total_time() or None,
                            'cook_time': result.cook_time() or None,
                            'prep_time': result.prep_time() or None,
                            'yields': result.yields() or None,
                            'ingredients': result.ingredients() or [],
                            'instructions': instructions,
                            'image': result.image() or '',
                            'host': result.host() or '',
                            'author': result.author() or '',
                            'nutrition': result.nutrition() or {},
                            'source': 'recipe-scrapers-tier0-full-fetch',
                            'metadata': {'tier_used': 'tier0', 'ai_ran': 0}
                        }
                        
                        try:
                            _dur = int((time.time() - start_time) * 1000)
                            _log_tier("tier0", url, missing_fields=None, quality=None, duration_ms=_dur)
                        except Exception:
                            pass
                        
                        return {
                            'statusCode': 200,
                            'headers': {
                                'Content-Type': 'application/json',
                                'Access-Control-Allow-Origin': '*',
                                'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                                'Access-Control-Allow-Methods': 'POST,OPTIONS'
                            },
                            'body': json.dumps(response_data)
                        }
                except Exception as e:
                    logger.warning(f"LAMBDA/TIER0: retry after fetch failed: {e}")
        
        # ========================================================================
        # STEP 3: AI FALLBACK (ONLY if instructions still empty)
        # ========================================================================
        # AI may run ONLY if instructions list is empty after full fetch
        # This is the last resort
        
        # Ensure we have HTML for AI
        if not html:
            html = fetch_full_html(url)
        
        if html:
            logger.info("LAMBDA/AI: attempting fallback (instructions empty after Tier-0)")
            ai_result = call_ai_fallback_simple(url, html)
            
            if ai_result and ai_result.get('instructions'):
                ai_instructions = ai_result.get('instructions', [])
                if isinstance(ai_instructions, str):
                    ai_instructions = [s.strip() for s in ai_instructions.split('\n') if s.strip()]
                elif not isinstance(ai_instructions, list):
                    ai_instructions = []
                
                # Only use AI result if it has instructions
                if has_meaningful_instructions(ai_instructions):
                    logger.info("LAMBDA/AI: fallback success")
                    
                    response_data = {
                        'title': ai_result.get('title') or 'Untitled Recipe',
                        'ingredients': ai_result.get('ingredients', []),
                        'instructions': ai_instructions,
                        'servings': ai_result.get('servings'),
                        'image': ai_result.get('image', ''),
                        'source': 'ai-fallback',
                        'metadata': {'tier_used': 'ai', 'ai_ran': 1}
                    }
                    
                    try:
                        _dur = int((time.time() - start_time) * 1000)
                        _log_tier("ai", url, missing_fields=None, quality=None, duration_ms=_dur)
                    except Exception:
                        pass
                    
                    return {
                        'statusCode': 200,
                        'headers': {
                            'Content-Type': 'application/json',
                            'Access-Control-Allow-Origin': '*',
                            'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                            'Access-Control-Allow-Methods': 'POST,OPTIONS'
                        },
                        'body': json.dumps(response_data)
                    }
        
        # All methods failed
        logger.error("LAMBDA/ERROR: All extraction methods failed")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                'Access-Control-Allow-Methods': 'POST,OPTIONS'
            },
            'body': json.dumps({'error': 'Recipe extraction failed - no instructions found'})
        }
        
    except Exception as e:
        logger.error(f"Parsing failed: {e}", exc_info=True)
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                'Access-Control-Allow-Methods': 'POST,OPTIONS'
            },
            'body': json.dumps({'error': f'Parsing failed: {str(e)}'})
        }



