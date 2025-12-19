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

def lambda_handler(event, context):
    """
    AWS Lambda function for recipe parsing using recipe-scrapers.
    This version uses the AWS Pandas layer which includes lxml support.
    
    Expected event format:
    {
        "url": "https://example.com/recipe"
    }
    or
    {
        "body": "{\"url\": \"https://example.com/recipe\"}"
    }
    """
    try:
        start_time = time.time()
        # Parse event (handle both direct URL and API Gateway body formats)
        url = None
        if 'url' in event:
            url = event['url']
        elif 'body' in event:
            try:
                body = json.loads(event['body'])
                url = body.get('url')
            except json.JSONDecodeError:
                url = event['body'] # Direct URL in body
        
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
        
        logger.info(f"Attempting to scrape URL: {url}")

        # Verify URL accessibility
        try:
            response = requests.head(url, timeout=5, allow_redirects=True)
            if response.status_code == 404:
                logger.error(f"URL not found: {url}")
                return {
                    'statusCode': 400,
                    'headers': {
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*',
                        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                        'Access-Control-Allow-Methods': 'POST,OPTIONS'
                    },
                    'body': json.dumps({'error': f'URL not found: {url}'})
                }
        except requests.RequestException as e:
            logger.error(f"Invalid URL or network error: {e}")
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                    'Access-Control-Allow-Methods': 'POST,OPTIONS'
                },
                'body': json.dumps({'error': f'Invalid URL or network error: {str(e)}'})
            }
        
        # Scrape the recipe using recipe-scrapers
        # With AWS Pandas layer, lxml should be available
        result = scrape_url(url)
        
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
            'source': 'recipe-scrapers-aws-pandas-layer' # Indicate successful use with AWS layer
        }
        
        logger.info("Recipe scraped successfully with recipe-scrapers using AWS Pandas layer.")
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
