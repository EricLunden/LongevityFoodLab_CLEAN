import json
import re
import os
import time
import requests
from urllib.parse import quote_plus
from bs4 import BeautifulSoup

# --- SSL sanity: ensure Requests uses its own CA bundle ---
# Some environments set these and break TLS. Clear them at runtime.
for _v in ("REQUESTS_CA_BUNDLE", "CURL_CA_BUNDLE", "SSL_CERT_FILE"):
    if os.environ.get(_v):
        try:
            print(f"LAMBDA/SSL: clearing {_v}={os.environ.get(_v)}")
            os.environ.pop(_v)
        except Exception:
            pass

# Force requests to use system CA bundle, not certifi
os.environ['REQUESTS_CA_BUNDLE'] = ''
os.environ['CURL_CA_BUNDLE'] = ''
os.environ['SSL_CERT_FILE'] = ''

print("LAMBDA/SSL: forced requests to use system CA bundle")
# Requests verifies SSL by default when no env overrides exist.
# We do not pass a custom `verify=` path anywhere.

BUILD_ID = os.getenv("BUILD_ID", "dev-local")

def lambda_handler(event, context):
    """Lambda handler with Tier-4 AI fallback for recipe extraction"""
    print(f"LAMBDA/BOOT: build={BUILD_ID}")
    
    try:
        # Health check endpoint
        if event.get('queryStringParameters', {}).get('health') == '1':
            return {
                'statusCode': 200,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'ok': True,
                    'build': BUILD_ID,
                    'function': os.getenv('AWS_LAMBDA_FUNCTION_NAME', 'unknown'),
                    'version': os.getenv('AWS_LAMBDA_FUNCTION_VERSION', 'unknown')
                })
            }
        
        # Parse request
        if 'body' in event and isinstance(event['body'], str):
            body = json.loads(event['body'])
        else:
            body = event
        
        url = body.get('url', '')
        html = body.get('html', '')
        
        # Log request type
        if html:
            print(f"LAMBDA/REQ: url+html")
        else:
            print(f"LAMBDA/REQ: url-only")
        
        # ---- early Spoonacular try when no HTML ----
        ai_enabled = os.environ.get('AI_TIER_ENABLED', 'false').lower() == 'true'
        min_trigger_score = float(os.environ.get('AI_MIN_TRIGGER_SCORE', '0.60'))
        spoon_enabled = os.environ.get('SPOON_TIER_ENABLED', 'true').lower() == 'true'
        spoon_timeout_ms = int(os.environ.get('SPOON_TIMEOUT_MS', '5000'))
        if not html and spoon_enabled:
            print(f"LAMBDA/PARSE: gates ai={ai_enabled} min={min_trigger_score:.2f} spoon={spoon_enabled} stimeout={spoon_timeout_ms}")
            print("LAMBDA/PARSE: tier=spoonacular (early, no HTML)")
            spn = try_spoonacular(url)
            if spn:
                # Mark metadata and return immediately (no need to fetch HTML)
                if 'metadata' not in spn:
                    spn['metadata'] = {}
                spn['metadata']['tier_used'] = 'spoonacular'
                spn['build'] = BUILD_ID
                print(f"LAMBDA/OUT: tier_used=spoonacular score={calculate_quality_score(spn):.2f}")
                return {
                    'statusCode': 200,
                    'headers': {
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*',
                        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                        'Access-Control-Allow-Methods': 'POST,OPTIONS'
                    },
                    'body': json.dumps(spn)
                }
        
        # Fetch HTML if not provided
        if not html:
            try:
                response = requests.get(
                    url,
                    timeout=10,
                    headers={'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'}
                )
                html = response.text
                print(f"LAMBDA/HTML: fetched ok bytes={len(html)}")
            except Exception as e:
                print(f"LAMBDA/HTML: fetch error={str(e)}")
                
                # If fetch failed, try Spoonacular once before failing
                if spoon_enabled:
                    print("LAMBDA/PARSE: fetch failed → trying spoonacular")
                    spn = try_spoonacular(url)
                    if spn:
                        if 'metadata' not in spn:
                            spn['metadata'] = {}
                        spn['metadata']['tier_used'] = 'spoonacular'
                        spn['build'] = BUILD_ID
                        print(f"LAMBDA/OUT: tier_used=spoonacular score={calculate_quality_score(spn):.2f}")
                        return {
                            'statusCode': 200,
                            'headers': {
                                'Content-Type': 'application/json',
                                'Access-Control-Allow-Origin': '*',
                                'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                                'Access-Control-Allow-Methods': 'POST,OPTIONS'
                            },
                            'body': json.dumps(spn)
                        }

                # If Spoonacular not enabled or failed, keep the current 400 response:
                return {
                    'statusCode': 400,
                    'headers': {
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*',
                        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                        'Access-Control-Allow-Methods': 'POST,OPTIONS'
                    },
                    'body': json.dumps({'error': 'Failed to fetch HTML content'})
                }
        
        # Parse with BeautifulSoup (deterministic tier)
        soup = BeautifulSoup(html, 'html.parser')
        recipe_data = extract_recipe_data(soup, url)
        
        # Calculate quality score and completeness
        quality_score = calculate_quality_score(recipe_data)
        ingredients_full = len(recipe_data.get('ingredients', [])) >= 3
        instructions_full = len(recipe_data.get('instructions', [])) >= 3
        full_recipe = ingredients_full and instructions_full
        
        print(f"LAMBDA/PARSE: tier=deterministic score={quality_score:.2f}")
        
        # Try Spoonacular API first (Tier 2) if enabled and quality is low
        if spoon_enabled and (quality_score < min_trigger_score or not full_recipe):
            print("LAMBDA/PARSE: tier=spoonacular")
            spoonacular_result = try_spoonacular(url)
            if spoonacular_result:
                # Merge Spoonacular results with deterministic results
                recipe_data = merge_spoonacular_results(recipe_data, spoonacular_result)
                print(f"LAMBDA/PARSE: spoonacular success ing={len(recipe_data.get('ingredients', []))} steps={len(recipe_data.get('instructions', []))}")
                
                # Recalculate quality after merge
                quality_score = calculate_quality_score(recipe_data)
                ingredients_full = len(recipe_data.get('ingredients', [])) >= 3
                instructions_full = len(recipe_data.get('instructions', [])) >= 3
                full_recipe = ingredients_full and instructions_full
                
                # Update metadata
                if 'metadata' not in recipe_data:
                    recipe_data['metadata'] = {}
                recipe_data['metadata']['tier_used'] = 'spoonacular'
            else:
                print("LAMBDA/PARSE: spoonacular error=no_result")
        
        # Check if AI fallback should be triggered (only if Spoonacular didn't improve quality enough)
        if ai_enabled and (quality_score < min_trigger_score or not full_recipe):
            print("LAMBDA/PARSE: ai-fallback start")
            
            try:
                ai_result = call_ai_fallback(url, html)
                if ai_result:
                    # Merge AI results with deterministic results
                    recipe_data = merge_ai_results(recipe_data, ai_result)
                    print(f"LAMBDA/PARSE: ai-fallback success ing={len(recipe_data.get('ingredients', []))} steps={len(recipe_data.get('instructions', []))}")
                    
                    # Update metadata
                    if 'metadata' not in recipe_data:
                        recipe_data['metadata'] = {}
                    recipe_data['metadata']['tier_used'] = 'ai_fallback'
                else:
                    print("LAMBDA/PARSE: ai-fallback error=no_result")
                    if 'metadata' not in recipe_data:
                        recipe_data['metadata'] = {}
                    recipe_data['metadata']['tier_used'] = 'deterministic'
                    recipe_data['metadata']['ai_error'] = 'no_result'
            except Exception as e:
                print(f"LAMBDA/PARSE: ai-fallback error={str(e)}")
                if 'metadata' not in recipe_data:
                    recipe_data['metadata'] = {}
                recipe_data['metadata']['tier_used'] = 'deterministic'
                recipe_data['metadata']['ai_error'] = str(e)
        else:
            if 'metadata' not in recipe_data:
                recipe_data['metadata'] = {}
            recipe_data['metadata']['tier_used'] = 'deterministic'
        
        # Final logging
        final_ingredients = len(recipe_data.get('ingredients', []))
        final_instructions = len(recipe_data.get('instructions', []))
        final_full_recipe = final_ingredients >= 3 and final_instructions >= 3
        
        print(f"LAMBDA/COMPLETE: full_recipe={final_full_recipe} ing={final_ingredients} steps={final_instructions}")
        print(f"LAMBDA/OUT: tier_used={recipe_data.get('metadata', {}).get('tier_used', 'deterministic')} score={quality_score:.2f}")
        
        # Add build marker to response
        recipe_data['build'] = BUILD_ID
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                'Access-Control-Allow-Methods': 'POST,OPTIONS'
            },
            'body': json.dumps(recipe_data)
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                'Access-Control-Allow-Methods': 'POST,OPTIONS'
            },
            'body': json.dumps({'error': str(e)})
        }

def extract_recipe_data(soup, url):
    """Extract recipe data using BeautifulSoup patterns"""
    
    # Extract title
    title = extract_title(soup)
    
    # Extract ingredients
    ingredients = extract_ingredients(soup)
    
    # Extract instructions
    instructions = extract_instructions(soup)
    
    # Extract servings
    servings = extract_servings(soup)
    
    # Extract prep time
    prep_time = extract_prep_time(soup)
    
    # Extract image
    image = extract_image(soup, url)
    
    return {
        'title': title,
        'ingredients': ingredients,
        'instructions': instructions,
        'servings': servings,
        'prep_time': prep_time,
        'cook_time': '',
        'total_time': '',
        'image': image,
        'site_link': url,
        'source_url': url,
        'site_name': extract_site_name(url),
        'quality_score': 0.0,
        'metadata': {
            'full_recipe': len(ingredients) >= 3 and len(instructions) >= 3
        }
    }

def extract_title(soup):
    """Extract recipe title"""
    # Try multiple selectors for title
    selectors = [
        'h1[class*="recipe"]',
        'h1[class*="title"]',
        'h1[class*="heading"]',
        '.recipe-title',
        '.recipe-name',
        'h1',
        'title'
    ]
    
    for selector in selectors:
        element = soup.select_one(selector)
        if element and element.get_text().strip():
            return element.get_text().strip()
    
    return "Untitled Recipe"

def extract_ingredients(soup):
    """Extract ingredients list with better filtering and deduplication"""
    ingredients = []
    seen_ingredients = set()  # Track seen ingredients to avoid duplicates
    
    # Try multiple selectors for ingredients
    selectors = [
        '[class*="ingredient"] li',
        '[class*="ingredient"] p',
        '[class*="ingredient"] span',
        '.ingredients li',
        '.ingredients p',
        '.recipe-ingredients li',
        '.recipe-ingredients p',
        '[itemprop="ingredients"]',
        'li[class*="ingredient"]',
        'p[class*="ingredient"]'
    ]
    
    # Skip words that indicate categories, not ingredients
    skip_words = [
        'ingredients', 'directions', 'instructions', 'method', 'breakfast', 
        'dinner', 'lunch', 'healthy', 'appetizers', 'side dishes', 'main dishes',
        'see all', 'chicken', 'turkey', 'beef', 'pork', 'seafood', 'vegetarian',
        'vegan', 'gluten-free', 'dairy-free', 'low-carb', 'keto', 'paleo',
        'categories', 'tags', 'cuisine', 'difficulty', 'cook time', 'prep time',
        'total time', 'servings', 'yield', 'nutrition', 'calories', 'fat',
        'protein', 'carbs', 'fiber', 'sugar', 'sodium', 'cholesterol',
        'linda c', 'by linda', 'submitted by', 'recipe by', 'author'
    ]
    
    for selector in selectors:
        elements = soup.select(selector)
        for element in elements:
            text = element.get_text().strip()
            if text and len(text) > 3 and len(text) < 200:
                # Check if this looks like an actual ingredient
                text_lower = text.lower()
                if not any(skip in text_lower for skip in skip_words):
                    # Additional checks for ingredient-like text
                    if any(indicator in text_lower for indicator in ['cup', 'tablespoon', 'teaspoon', 'pound', 'ounce', 'gram', 'ml', 'tbsp', 'tsp', 'lb', 'oz']):
                        if text not in seen_ingredients:
                            ingredients.append(text)
                            seen_ingredients.add(text)
                    elif any(ingredient_word in text_lower for ingredient_word in ['flour', 'sugar', 'salt', 'pepper', 'oil', 'butter', 'milk', 'egg', 'cheese', 'meat', 'chicken', 'beef', 'fish', 'vegetable', 'herb', 'spice']):
                        if text not in seen_ingredients:
                            ingredients.append(text)
                            seen_ingredients.add(text)
                    elif len(text.split()) <= 8:  # Short phrases are more likely to be ingredients
                        if text not in seen_ingredients:
                            ingredients.append(text)
                            seen_ingredients.add(text)
        
        if ingredients:
            break
    
    # If no ingredients found, try to find any list items but filter more strictly
    if not ingredients:
        for li in soup.find_all('li'):
            text = li.get_text().strip()
            if text and len(text) > 5 and len(text) < 200:
                text_lower = text.lower()
                if not any(skip in text_lower for skip in skip_words):
                    if text not in seen_ingredients:
                        ingredients.append(text)
                        seen_ingredients.add(text)
    
    return ingredients[:20]  # Limit to 20 ingredients

def extract_instructions(soup):
    """Extract cooking instructions with better filtering and deduplication"""
    instructions = []
    seen_instructions = set()  # Track seen instructions to avoid duplicates
    
    # Skip words that indicate non-instruction content
    skip_words = [
        'ingredients', 'ingredient', 'linda c', 'by linda', 'submitted by', 
        'recipe by', 'author', 'review', 'rating', 'stars', 'votes',
        'nutrition', 'calories', 'fat', 'protein', 'carbs', 'fiber',
        'sugar', 'sodium', 'cholesterol', 'serves', 'yield', 'prep time',
        'cook time', 'total time', 'difficulty', 'skill level'
    ]
    
    # Try multiple selectors for instructions
    selectors = [
        '[class*="instruction"] li',
        '[class*="instruction"] p',
        '[class*="direction"] li',
        '[class*="direction"] p',
        '.instructions li',
        '.instructions p',
        '.recipe-instructions li',
        '.recipe-instructions p',
        '[itemprop="recipeInstructions"] li',
        '[itemprop="recipeInstructions"] p',
        'ol[class*="instruction"] li',
        'ol[class*="direction"] li'
    ]
    
    for selector in selectors:
        elements = soup.select(selector)
        for element in elements:
            text = element.get_text().strip()
            if text and len(text) > 10:
                text_lower = text.lower()
                if not any(skip in text_lower for skip in skip_words):
                    # Check if this looks like an instruction (starts with action words)
                    if any(action in text_lower for action in ['heat', 'add', 'mix', 'stir', 'cook', 'bake', 'fry', 'boil', 'simmer', 'preheat', 'place', 'put', 'combine', 'blend', 'whisk', 'beat', 'fold', 'pour', 'drain', 'remove', 'serve']):
                        if text not in seen_instructions:
                            instructions.append(text)
                            seen_instructions.add(text)
                    elif text[0].isdigit() or text.startswith(('1.', '2.', '3.', '4.', '5.', '6.', '7.', '8.', '9.')):
                        if text not in seen_instructions:
                            instructions.append(text)
                            seen_instructions.add(text)
                    elif len(text.split()) > 5:  # Longer text is likely an instruction
                        if text not in seen_instructions:
                            instructions.append(text)
                            seen_instructions.add(text)
        
        # Don't break early - collect all instructions from all selectors
        if len(instructions) >= 5:  # Only break if we have a reasonable number
            break
    
    # If no instructions found, try to find ordered list
    if not instructions:
        for ol in soup.find_all('ol'):
            for li in ol.find_all('li'):
                text = li.get_text().strip()
                if text and len(text) > 10:
                    text_lower = text.lower()
                    if not any(skip in text_lower for skip in skip_words):
                        if text not in seen_instructions:
                            instructions.append(text)
                            seen_instructions.add(text)
    
    # Also try to find any numbered steps in paragraphs
    if not instructions:
        for p in soup.find_all('p'):
            text = p.get_text().strip()
            if text and len(text) > 20:
                text_lower = text.lower()
                if not any(skip in text_lower for skip in skip_words):
                    # Look for numbered steps or action words
                    if (text[0].isdigit() and '.' in text[:5]) or any(action in text_lower for action in ['heat', 'add', 'mix', 'stir', 'cook', 'bake', 'fry', 'boil', 'simmer', 'preheat', 'place', 'put', 'combine', 'blend', 'whisk', 'beat', 'fold', 'pour', 'drain', 'remove', 'serve']):
                        if text not in seen_instructions:
                            instructions.append(text)
                            seen_instructions.add(text)
    
    return instructions[:15]  # Limit to 15 steps

def extract_servings(soup):
    """Extract number of servings"""
    # Look for serving information
    serving_patterns = [
        r'(\d+)\s*(?:servings?|people|portions?)',
        r'serves?\s*(\d+)',
        r'yields?\s*(\d+)',
        r'makes?\s*(\d+)'
    ]
    
    text = soup.get_text().lower()
    for pattern in serving_patterns:
        match = re.search(pattern, text)
        if match:
            return int(match.group(1))
    
    return None

def extract_prep_time(soup):
    """Extract prep/cook time with better parsing"""
    # Look for time information in various formats
    time_patterns = [
        r'prep[:\s]*(\d+)\s*(?:min|minutes?|hr|hours?|h)',
        r'cook[:\s]*(\d+)\s*(?:min|minutes?|hr|hours?|h)',
        r'total[:\s]*(\d+)\s*(?:min|minutes?|hr|hours?|h)',
        r'(\d+)\s*(?:min|minutes?|hr|hours?|h)\s*(?:prep|cook|total)',
        r'(\d+)\s*(?:min|minutes?|hr|hours?|h)'
    ]
    
    text = soup.get_text().lower()
    
    for pattern in time_patterns:
        match = re.search(pattern, text)
        if match:
            time_val = int(match.group(1))
            # Convert hours to minutes - check the actual matched text, not the pattern
            matched_text = match.group(0).lower()
            if any(unit in matched_text for unit in ['hr', 'hour', 'h']):
                return time_val * 60
            return time_val
    
    # Look for time in specific elements
    time_elements = soup.find_all(['time', 'span', 'div'])
    for element in time_elements:
        text = element.get_text().strip().lower()
        if re.search(r'\d+\s*(?:min|minutes?|hr|hours?|h)', text):
            match = re.search(r'(\d+)\s*(?:min|minutes?|hr|hours?|h)', text)
            if match:
                time_val = int(match.group(1))
                if any(unit in text for unit in ['hr', 'hour', 'h']):
                    return time_val * 60
                return time_val
    
    return None

def extract_image(soup, url=''):
    """Extract recipe image URL with comprehensive selectors"""
    # Extract domain for relative URL construction
    domain = ''
    if url:
        try:
            from urllib.parse import urlparse
            parsed = urlparse(url)
            domain = f"{parsed.scheme}://{parsed.netloc}"
        except:
            pass
    
    # Comprehensive image selectors
    img_selectors = [
        # Recipe-specific selectors
        'img[class*="recipe"]',
        'img[class*="hero"]',
        'img[class*="main"]',
        'img[class*="featured"]',
        'img[class*="primary"]',
        'img[class*="lead"]',
        'img[class*="banner"]',
        'img[class*="cover"]',
        'img[class*="thumbnail"]',
        'img[class*="preview"]',
        
        # Container-based selectors
        '.recipe-image img',
        '.hero-image img',
        '.main-image img',
        '.featured-image img',
        '.primary-image img',
        '.lead-image img',
        '.banner-image img',
        '.cover-image img',
        '.thumbnail img',
        '.preview img',
        
        # Schema.org and microdata
        'img[itemprop="image"]',
        'img[itemprop="photo"]',
        'img[itemprop="thumbnail"]',
        
        # Common recipe site patterns
        '.recipe-card img',
        '.recipe-header img',
        '.recipe-content img',
        '.recipe-summary img',
        '.recipe-intro img',
        '.recipe-meta img',
        
        # Generic high-priority selectors
        'article img',
        'main img',
        '.content img',
        '.post img',
        '.entry img',
        
        # Fallback to any img with src
        'img[src]'
    ]
    
    for selector in img_selectors:
        imgs = soup.select(selector)
        for img in imgs:
            src = img.get('src') or img.get('data-src') or img.get('data-lazy-src')
            if not src:
                continue
                
            # Clean up the URL
            src = src.strip()
            
            # Skip placeholder/icon/promotional images
            if any(skip in src.lower() for skip in [
                'placeholder', 'icon', 'logo', 'avatar', 'profile', 'spacer', 'pixel',
                'worstcooks', 'promo', 'advertisement', 'banner', 'header', 'nav',
                'social', 'facebook', 'twitter', 'instagram', 'pinterest', 'youtube',
                'subscribe', 'newsletter', 'signup', 'login', 'register', 'account',
                'menu', 'hamburger', 'search', 'cart', 'shopping', 'buy', 'shop'
            ]):
                continue
                
            # Skip very small images (likely icons)
            width = img.get('width', '')
            height = img.get('height', '')
            if width and height:
                try:
                    w, h = int(width), int(height)
                    if w < 100 or h < 100:
                        continue
                except:
                    pass
            
            # Convert relative URLs to absolute
            if src.startswith('http'):
                return src
            elif src.startswith('//'):
                return 'https:' + src
            elif src.startswith('/'):
                if domain:
                    return domain + src
                # Try common domains
                for common_domain in ['https://www.allrecipes.com', 'https://www.foodnetwork.com', 'https://www.epicurious.com']:
                    if common_domain in url:
                        return common_domain + src
            elif src.startswith('./'):
                if domain:
                    return domain + '/' + src[2:]
            elif not src.startswith('data:'):
                # Relative path without leading slash
                if domain:
                    return domain + '/' + src
    
    return None

def extract_site_name(url):
    """Extract site name from URL"""
    try:
        from urllib.parse import urlparse
        parsed = urlparse(url)
        domain = parsed.netloc
        if domain.startswith('www.'):
            domain = domain[4:]
        return domain
    except:
        return "Unknown Site"

def calculate_quality_score(recipe_data):
    """Calculate quality score based on recipe completeness"""
    score = 0.0
    
    # Title (20%)
    if recipe_data.get('title') and recipe_data['title'] != "Untitled Recipe":
        score += 0.2
    
    # Ingredients (30%)
    ingredients = recipe_data.get('ingredients', [])
    if len(ingredients) >= 3:
        score += 0.3
    elif len(ingredients) >= 1:
        score += 0.15
    
    # Instructions (30%)
    instructions = recipe_data.get('instructions', [])
    if len(instructions) >= 3:
        score += 0.3
    elif len(instructions) >= 1:
        score += 0.15
    
    # Image (10%)
    if recipe_data.get('image'):
        score += 0.1
    
    # Servings (5%)
    if recipe_data.get('servings'):
        score += 0.05
    
    # Prep time (5%)
    if recipe_data.get('prep_time'):
        score += 0.05
    
    return min(score, 1.0)

def try_spoonacular(url):
    """Try Spoonacular API for recipe extraction (Tier 2)"""
    try:
        api_key = os.environ.get('SPOONACULAR_API_KEY')
        if not api_key:
            print("LAMBDA/PARSE: spoonacular error=no_api_key")
            return None
        
        print("LAMBDA/PARSE: tier=spoonacular")
        
        # URL encode the URL parameter
        encoded_url = quote_plus(url)
        
        # Call Spoonacular API
        api_url = f"https://api.spoonacular.com/recipes/extract?url={encoded_url}&apiKey={api_key}"
        
        # Get timeout from environment variable
        timeout_seconds = int(os.environ.get('SPOON_TIMEOUT_MS', '5000')) / 1000.0
        
        response = requests.get(
            api_url,
            timeout=timeout_seconds
        )
        
        if response.status_code == 200:
            data = response.json()
            
            # Normalize Spoonacular response to our schema
            normalized = {
                'title': data.get('title', ''),
                'ingredients': [ing.get('original', '') for ing in data.get('extendedIngredients', []) if ing.get('original')],
                'instructions': [step.get('step', '') for step in data.get('analyzedInstructions', [{}])[0].get('steps', []) if step.get('step')],
                'servings': data.get('servings'),
                'prep_time': data.get('prepMinutes'),
                'cook_time': data.get('cookMinutes'),
                'total_time': data.get('readyInMinutes'),
                'image': data.get('image'),
                'site_link': url,
                'source_url': url,
                'site_name': extract_site_name(url),
                'quality_score': 0.0  # Will be recalculated
            }
            
            # Calculate quality score for Spoonacular result
            normalized['quality_score'] = calculate_quality_score(normalized)
            
            return normalized
        else:
            print(f"LAMBDA/PARSE: spoonacular error=api_error_{response.status_code}")
            return None
            
    except requests.exceptions.Timeout:
        print("LAMBDA/PARSE: spoonacular error=timeout")
        return None
    except Exception as e:
        print(f"LAMBDA/PARSE: spoonacular error={str(e)}")
        return None

def merge_spoonacular_results(deterministic_result, spoonacular_result):
    """Merge Spoonacular results with deterministic results"""
    merged = deterministic_result.copy()
    
    # Merge ingredients (prefer Spoonacular if deterministic is short)
    det_ingredients = deterministic_result.get('ingredients', [])
    spoon_ingredients = spoonacular_result.get('ingredients', [])
    
    if len(spoon_ingredients) > len(det_ingredients):
        merged['ingredients'] = spoon_ingredients
    
    # Merge instructions (prefer Spoonacular if deterministic is short)
    det_instructions = deterministic_result.get('instructions', [])
    spoon_instructions = spoonacular_result.get('instructions', [])
    
    if len(spoon_instructions) > len(det_instructions):
        merged['instructions'] = spoon_instructions
    
    # Fill missing basic fields with Spoonacular data
    if not merged.get('title') or merged['title'] == "Untitled Recipe":
        if spoonacular_result.get('title'):
            merged['title'] = spoonacular_result['title']
    
    if not merged.get('image') and spoonacular_result.get('image'):
        merged['image'] = spoonacular_result['image']
    
    if not merged.get('servings') and spoonacular_result.get('servings'):
        merged['servings'] = spoonacular_result['servings']
    
    if not merged.get('prep_time') and spoonacular_result.get('prep_time'):
        merged['prep_time'] = spoonacular_result['prep_time']
    
    if not merged.get('cook_time') and spoonacular_result.get('cook_time'):
        merged['cook_time'] = spoonacular_result['cook_time']
    
    if not merged.get('total_time') and spoonacular_result.get('total_time'):
        merged['total_time'] = spoonacular_result['total_time']
    
    # Update metadata
    if 'metadata' not in merged:
        merged['metadata'] = {}
    
    merged['metadata']['full_recipe'] = len(merged.get('ingredients', [])) >= 3 and len(merged.get('instructions', [])) >= 3
    
    return merged

def call_ai_fallback(url, html):
    """Call Claude AI for recipe extraction fallback"""
    try:
        api_key = os.environ.get('ANTHROPIC_API_KEY')
        if not api_key:
            raise Exception("ANTHROPIC_API_KEY not set")
        
        model = os.environ.get('AI_MODEL', 'claude-3-haiku-202410')
        timeout_ms = int(os.environ.get('AI_TIMEOUT_MS', '4000'))
        
        # Truncate HTML if too long (keep first 8000 chars)
        html_truncated = html[:8000] if len(html) > 8000 else html
        
        prompt = f"""Extract recipe information from this HTML content and return ONLY a JSON object with these exact keys:

{{
  "title": "string or null",
  "image": "string URL or null", 
  "prep_time": "string or null",
  "cook_time": "string or null",
  "total_time": "string or null",
  "servings": "string or null",
  "site_link": "string or null",
  "site_name": "string or null",
  "ingredients": ["array of strings"],
  "instructions": ["array of strings"]
}}

URL: {url}

HTML Content:
{html_truncated}

Return only valid JSON, no markdown, no backticks, no commentary."""

        headers = {
            'x-api-key': api_key,
            'Content-Type': 'application/json',
            'anthropic-version': '2023-06-01'
        }
        
        payload = {
            'model': model,
            'max_tokens': 1200,
            'temperature': 0,
            'messages': [
                {
                    'role': 'user',
                    'content': prompt
                }
            ]
        }
        
        response = requests.post(
            'https://api.anthropic.com/v1/messages',
            headers=headers,
            json=payload,
            timeout=timeout_ms / 1000.0
        )
        
        if response.status_code == 200:
            result = response.json()
            content = result.get('content', [])
            if content and len(content) > 0:
                text = content[0].get('text', '')
                # Clean up the response
                text = text.strip()
                if text.startswith('```json'):
                    text = text[7:]
                if text.endswith('```'):
                    text = text[:-3]
                text = text.strip()
                
                # Parse JSON
                ai_data = json.loads(text)
                return ai_data
        else:
            raise Exception(f"API error: {response.status_code}")
            
    except Exception as e:
        print(f"AI fallback error: {str(e)}")
        return None

def merge_ai_results(deterministic_result, ai_result):
    """Merge AI results with deterministic results, preferring non-empty values"""
    merged = deterministic_result.copy()
    
    # Merge ingredients (prefer AI if deterministic is short)
    det_ingredients = deterministic_result.get('ingredients', [])
    ai_ingredients = ai_result.get('ingredients', [])
    
    if len(ai_ingredients) > len(det_ingredients):
        merged['ingredients'] = ai_ingredients
    
    # Merge instructions (prefer AI if deterministic is short)
    det_instructions = deterministic_result.get('instructions', [])
    ai_instructions = ai_result.get('instructions', [])
    
    if len(ai_instructions) > len(det_instructions):
        merged['instructions'] = ai_instructions
    
    # Fill missing basic fields with AI data
    if not merged.get('title') or merged['title'] == "Untitled Recipe":
        if ai_result.get('title'):
            merged['title'] = ai_result['title']
    
    if not merged.get('image') and ai_result.get('image'):
        merged['image'] = ai_result['image']
    
    if not merged.get('servings') and ai_result.get('servings'):
        merged['servings'] = ai_result['servings']
    
    if not merged.get('prep_time') and ai_result.get('prep_time'):
        merged['prep_time'] = ai_result['prep_time']
    
    if not merged.get('cook_time') and ai_result.get('cook_time'):
        merged['cook_time'] = ai_result['cook_time']
    
    if not merged.get('total_time') and ai_result.get('total_time'):
        merged['total_time'] = ai_result['total_time']
    
    # Update metadata
    if 'metadata' not in merged:
        merged['metadata'] = {}
    
    merged['metadata']['full_recipe'] = len(merged.get('ingredients', [])) >= 3 and len(merged.get('instructions', [])) >= 3
    
    return merged
