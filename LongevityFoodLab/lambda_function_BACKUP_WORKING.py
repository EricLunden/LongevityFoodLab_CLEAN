import json
from recipe_scrapers import scrape_html
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

# Force BeautifulSoup to use html.parser and disable lxml
os.environ['BS4_PARSER'] = 'html.parser'
os.environ['BEAUTIFULSOUP_PARSER'] = 'html.parser'

def lambda_handler(event, context):
    """
    AWS Lambda function for recipe parsing using recipe-scrapers.
    This version parses HTML content sent by the iOS app.
    
    Expected event format:
    {
        "url": "https://example.com/recipe",
        "html": "<html>...</html>"
    }
    """
    try:
        start_time = time.time()
        # Parse event - get URL and HTML from iOS app
        url = event.get('url')
        html = event.get('html')
        
        if not url or not html:
            logger.error("Missing url or html parameters.")
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                    'Access-Control-Allow-Methods': 'POST,OPTIONS'
                },
                'body': json.dumps({'error': 'Missing url or html parameters'})
            }
        
        logger.info(f"Parsing HTML for URL: {url}")
        
        # Parse the HTML content using recipe-scrapers
        result = scrape_html(html=html, org_url=url)
        
        # Return structured recipe data
        response_data = {
            'title': result.title() or 'N/A',
            'total_time': result.total_time() or 'N/A',
            'cook_time': result.cook_time() or 'N/A',
            'prep_time': result.prep_time() or 'N/A',
            'yields': result.yields() or 'N/A',
            'ingredients': result.ingredients() or [],
            'instructions': result.instructions() or 'N/A',
            'image': result.image() or 'N/A',
            'host': result.host() or 'N/A',
            'author': result.author() or 'N/A',
            'nutrition': result.nutrition() or {},
            'source': 'recipe-scrapers-html-parser' # Indicate successful parsing
        }
        
        logger.info("Recipe parsed successfully with recipe-scrapers.")
        try:
            _dur = int((time.time() - start_time) * 1000)
            _log_tier("html", url, missing_fields=None, quality=None, duration_ms=_dur)
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
