import json
import re
import os
import time
from urllib.parse import quote_plus

# ---- SAFE TIER LOGGING (timing + env flag) ----
import os as _os_for_tier
import json as _json_for_tier
import time as _time_for_tier
from urllib.parse import urlparse as _urlparse_for_tier

# Env gate (default ON)
TIER_LOGGING_ENABLED = _os_for_tier.environ.get("TIER_LOGGING", "1") == "1"

if "_log_tier" not in globals():
    def _log_tier(tier: str, url: str, missing_fields=None, quality=None, duration_ms=None):
        """Lightweight, gated tier log. No side effects."""
        if not TIER_LOGGING_ENABLED:
            return
        try:
            domain = _urlparse_for_tier(url).netloc.lower() if url else ""
        except Exception:
            domain = ""
        record = {
            "TIER_USED": tier,
            "site": domain,
            "url": (url or "")[:300],
            "missing": missing_fields or [],
            "quality": quality,
            "ms": duration_ms,
        }
        try:
            print(_json_for_tier.dumps(record, separators=(",", ":")))
        except Exception:
            pass
        try:
            miss = ",".join(record["missing"]) if record["missing"] else ""
            print(f"TIER_USED={tier} site={domain} url={record['url']} missing={miss} quality={quality} ms={duration_ms}")
        except Exception:
            pass
# ---- END SAFE TIER LOGGING ----
from bs4 import BeautifulSoup
from typing import List, Dict, Any, Tuple

# ---- Force Requests to use the system CA bundle BEFORE importing requests ----
# Prefer Amazon Linux system bundle paths
_SYSTEM_CA_CANDIDATES = [
    "/etc/ssl/certs/ca-bundle.crt",        # common on AL2023
    "/etc/pki/tls/certs/ca-bundle.crt"     # alternate path
]
_CHOSEN_CA = None
for _p in _SYSTEM_CA_CANDIDATES:
    if os.path.exists(_p):
        _CHOSEN_CA = _p
        break

# Clear any broken bundle hints from our package/archive
for _var in ("SSL_CERT_FILE", "REQUESTS_CA_BUNDLE", "CURL_CA_BUNDLE"):
    if os.environ.get(_var, "").startswith("/var/task/certifi"):
        os.environ.pop(_var, None)

# If we found a system CA, force Requests to use it before import
if _CHOSEN_CA:
    os.environ["REQUESTS_CA_BUNDLE"] = _CHOSEN_CA
    print(f"LAMBDA/SSL: using system CA at={_CHOSEN_CA}")
else:
    print("LAMBDA/SSL: system CA not found; relying on Requests default")

import requests
# ------------------------------------------------------------------------------

BUILD_ID = os.getenv("BUILD_ID", "dev-local")

# ============================================================================
# YOUTUBE RECIPE EXTRACTION (3-Tier System)
# ============================================================================

def is_youtube_url(url: str) -> bool:
    """Check if URL is a YouTube video URL"""
    if not url:
        return False
    youtube_domains = ['youtube.com', 'youtu.be', 'm.youtube.com']
    return any(domain in url.lower() for domain in youtube_domains)

def extract_youtube_video_id(url: str) -> str:
    """Extract video ID from various YouTube URL formats"""
    patterns = [
        r'youtube\.com/watch\?v=([a-zA-Z0-9_-]{11})',
        r'youtu\.be/([a-zA-Z0-9_-]{11})',
        r'youtube\.com/shorts/([a-zA-Z0-9_-]{11})',
        r'youtube\.com/embed/([a-zA-Z0-9_-]{11})'
    ]
    
    for pattern in patterns:
        match = re.search(pattern, url)
        if match:
            return match.group(1)
    return None

# ============================================================================
# TIKTOK HELPER FUNCTIONS
# ============================================================================

def is_tiktok_url(url: str) -> bool:
    """Check if URL is a TikTok video URL"""
    if not url:
        return False
    tiktok_domains = ['tiktok.com', 'vm.tiktok.com', 't.tiktok.com']
    return any(domain in url.lower() for domain in tiktok_domains)

def extract_tiktok_video_id(url: str) -> str:
    """Extract video ID from various TikTok URL formats"""
    patterns = [
        r'tiktok\.com/@[\w.-]+/video/(\d+)',  # https://www.tiktok.com/@username/video/1234567890
        r'tiktok\.com/v/(\d+)',                # https://www.tiktok.com/v/1234567890
        r'vm\.tiktok\.com/(\w+)',              # https://vm.tiktok.com/ABC123
        r't\.tiktok\.com/(\w+)',               # https://t.tiktok.com/ABC123
        r'tiktok\.com/t/([A-Za-z0-9]+)',       # https://www.tiktok.com/t/ZTrCEF2KC/ (shortened, may have trailing slash)
    ]
    
    for pattern in patterns:
        match = re.search(pattern, url)
        if match:
            return match.group(1)
    
    return None

def fetch_tiktok_metadata(video_id: str, url: str) -> Dict[str, Any]:
    """Fetch TikTok video metadata using Apify"""
    apify_token = os.environ.get('APIFY_TOKEN')
    # Actor ID from console: GdWCkxBtKWOsKjdch (from https://console.apify.com/actors/GdWCkxBtKWOsKjdch/input)
    # This is the unique actor ID - more reliable than friendly name format
    apify_actor_id = os.environ.get('APIFY_ACTOR_ID', 'GdWCkxBtKWOsKjdch')
    
    if not apify_token:
        print("LAMBDA/TIKTOK: APIFY_TOKEN not set, cannot fetch metadata")
        raise Exception("APIFY_TOKEN not set")
    
    try:
        print(f"LAMBDA/TIKTOK: Fetching metadata for url={url} via Apify (video_id={video_id})")
        
        # Start Apify actor run
        # Apify accepts full TikTok URLs (including shortened ones like tiktok.com/t/...)
        # Use actor ID directly (GdWCkxBtKWOsKjdch) - this is the unique identifier
        actor_url = f"https://api.apify.com/v2/acts/{apify_actor_id}/runs"
        
        headers = {
            'Authorization': f'Bearer {apify_token}',
            'Content-Type': 'application/json'
        }
        
        # Log token info (first/last 4 chars only for security)
        token_preview = f"{apify_token[:4]}...{apify_token[-4:]}" if len(apify_token) > 8 else "***"
        print(f"LAMBDA/TIKTOK: Token preview: {token_preview} (length: {len(apify_token)})")
        
        # Try different input parameter formats - different actors use different names
        # Common parameter names: postURLs (capital URL), postUrls, startUrls, urls, inputUrls
        payload_options = [
            {'postURLs': [url]},  # Actor expects capital URL (per error message)
            {'postUrls': [url]},  # Lowercase variant
            {'startUrls': [url]},  # Alternative format
            {'urls': [url]},  # Another alternative
            {'inputUrls': [url]},  # Another alternative
        ]
        
        # Start the actor run - try different payload parameter names
        print(f"LAMBDA/TIKTOK: Calling Apify API: {actor_url}")
        print(f"LAMBDA/TIKTOK: Using actor_id: {apify_actor_id}")
        
        response = None
        last_error = None
        
        # Try each payload option until one works
        for i, payload in enumerate(payload_options):
            param_name = list(payload.keys())[0]
            print(f"LAMBDA/TIKTOK: Trying payload option {i+1}: {param_name}")
            response = requests.post(actor_url, json=payload, headers=headers, timeout=10)
            
            if response.status_code == 201:
                print(f"LAMBDA/TIKTOK: ✅ SUCCESS! Payload parameter: {param_name}")
                break
            elif response.status_code != 404:
                # If not 404, it's a different error (auth, bad input, etc) - save for detailed logging
                last_error = response
                print(f"LAMBDA/TIKTOK: Returned {response.status_code} with {param_name}: {response.text[:200]}")
        
        # Use last_error if we got a non-404 error and no success
        if response and response.status_code != 201 and last_error and last_error.status_code != 404:
            response = last_error
        
        if response.status_code != 201:
            error_text = response.text[:2000] if response.text else "No error detail"
            print(f"LAMBDA/TIKTOK: Apify actor start failed: {response.status_code}")
            print(f"LAMBDA/TIKTOK: Full error response: {error_text}")
            print(f"LAMBDA/TIKTOK: Request URL: {actor_url}")
            print(f"LAMBDA/TIKTOK: Actor ID used: {apify_actor_id}")
            print(f"LAMBDA/TIKTOK: Tried all payload options: {[list(p.keys())[0] for p in payload_options]}")
            
            # Try to parse error JSON for more details
            try:
                error_json = response.json()
                print(f"LAMBDA/TIKTOK: Error JSON: {error_json}")
                if 'error' in error_json:
                    error_obj = error_json.get('error', {})
                    print(f"LAMBDA/TIKTOK: Apify error message: {error_obj.get('message', 'N/A')}")
                    print(f"LAMBDA/TIKTOK: Apify error type: {error_obj.get('type', 'N/A')}")
            except Exception as e:
                print(f"LAMBDA/TIKTOK: Could not parse error JSON: {e}")
            
            # If 404, provide helpful message
            if response.status_code == 404:
                print(f"LAMBDA/TIKTOK: ⚠️ 404 Error - Actor '{apify_actor_id}' not found.")
                print(f"LAMBDA/TIKTOK: Please verify the actor exists at: https://apify.com/{apify_actor_id}")
                print(f"LAMBDA/TIKTOK: Or check your Apify console for the correct actor ID")
            
            raise Exception(f"Apify actor start failed: {response.status_code} - {error_text[:300]}")
        
        run_data = response.json()
        run_id = run_data['data']['id']
        dataset_id = run_data['data']['defaultDatasetId']
        
        print(f"LAMBDA/TIKTOK: Apify run started: {run_id}, dataset: {dataset_id}")
        
        # Poll for results (max 60 seconds, check every 2 seconds)
        # Also check run status to see if it's still running
        dataset_url = f"https://api.apify.com/v2/datasets/{dataset_id}/items"
        run_status_url = f"https://api.apify.com/v2/actor-runs/{run_id}"
        max_attempts = 30  # 30 attempts * 2 seconds = 60 seconds max
        
        for attempt in range(max_attempts):
            time.sleep(2)  # Check every 2 seconds instead of 1
            
            # Check run status first
            status_response = requests.get(run_status_url, headers=headers, timeout=10)
            if status_response.status_code == 200:
                status_data = status_response.json()
                run_status = status_data.get('data', {}).get('status', 'UNKNOWN')
                print(f"LAMBDA/TIKTOK: Run status: {run_status} (attempt {attempt + 1}/{max_attempts})")
                
                # If run failed, raise error
                if run_status == 'FAILED':
                    error_msg = status_data.get('data', {}).get('statusMessage', 'Unknown error')
                    raise Exception(f"Apify run failed: {error_msg}")
            
            # Try to get results
            result_response = requests.get(dataset_url, headers=headers, timeout=10)
            if result_response.status_code == 200:
                results = result_response.json()
                if results and len(results) > 0:
                    tiktok_data = results[0]
                    
                    # Extract relevant fields (Apify response structure may vary)
                    title = tiktok_data.get('text', '') or tiktok_data.get('caption', '') or tiktok_data.get('description', '')
                    description = tiktok_data.get('text', '') or tiktok_data.get('caption', '') or ''
                    author = tiktok_data.get('authorName', '') or tiktok_data.get('author', {}).get('name', 'Unknown')
                    
                    # Build author URL from username (extract from authorMeta if available)
                    author_url = ''
                    if 'authorMeta' in tiktok_data and isinstance(tiktok_data['authorMeta'], dict):
                        author_meta = tiktok_data['authorMeta']
                        username = author_meta.get('name', '') or author_meta.get('uniqueId', '')
                        if username:
                            author_url = f"https://www.tiktok.com/@{username}"
                    elif author and author != 'Unknown':
                        # Try to extract username from author name
                        author_url = f"https://www.tiktok.com/@{author.replace(' ', '').lower()}"
                    
                    # Get thumbnail (try multiple possible fields)
                    thumbnail = ''
                    # Log available keys for debugging
                    available_keys = list(tiktok_data.keys())
                    print(f"LAMBDA/TIKTOK: Available keys in Apify response: {available_keys[:30]}")  # First 30 keys
                    
                    # Try various thumbnail/image fields (check nested structures too)
                    # Apify TikTok scraper may return images in different formats
                    if 'covers' in tiktok_data:
                        if isinstance(tiktok_data['covers'], dict):
                            thumbnail = tiktok_data['covers'].get('default', '') or tiktok_data['covers'].get('origin', '') or tiktok_data['covers'].get('dynamic', '')
                        elif isinstance(tiktok_data['covers'], str):
                            thumbnail = tiktok_data['covers']
                    elif 'cover' in tiktok_data:
                        thumbnail = tiktok_data['cover'] if isinstance(tiktok_data['cover'], str) else ''
                    elif 'imageUrl' in tiktok_data:
                        thumbnail = tiktok_data['imageUrl']
                    # SKIP authorMeta.avatar - that's a profile picture (face), NOT food!
                    # Try videoMeta first (actual video thumbnail)
                    elif 'videoMeta' in tiktok_data and isinstance(tiktok_data['videoMeta'], dict):
                        video_meta = tiktok_data['videoMeta']
                        # Check for coverUrl/originalCoverUrl in videoMeta (actual video thumbnail)
                        if 'coverUrl' in video_meta:
                            cover_val = video_meta['coverUrl']
                            if isinstance(cover_val, str) and 'avatar' not in cover_val.lower():
                                thumbnail = cover_val
                                print(f"LAMBDA/TIKTOK: Found thumbnail in videoMeta.coverUrl: {cover_val[:100]}")
                        elif 'originalCoverUrl' in video_meta:
                            cover_val = video_meta['originalCoverUrl']
                            if isinstance(cover_val, str) and 'avatar' not in cover_val.lower():
                                thumbnail = cover_val
                                print(f"LAMBDA/TIKTOK: Found thumbnail in videoMeta.originalCoverUrl: {cover_val[:100]}")
                        # Fallback to 'cover' or 'thumbnail' if coverUrl/originalCoverUrl not found
                        elif 'cover' in video_meta:
                            cover_val = video_meta['cover']
                            if isinstance(cover_val, str) and 'avatar' not in cover_val.lower():
                                thumbnail = cover_val
                                print(f"LAMBDA/TIKTOK: Found thumbnail in videoMeta.cover: {cover_val[:100]}")
                        elif 'thumbnail' in video_meta:
                            thumb_val = video_meta['thumbnail']
                            if isinstance(thumb_val, str) and 'avatar' not in thumb_val.lower():
                                thumbnail = thumb_val
                                print(f"LAMBDA/TIKTOK: Found thumbnail in videoMeta.thumbnail: {thumb_val[:100]}")
                    elif 'mediaUrls' in tiktok_data:
                        # Check mediaUrls array for image (NOT author avatar - that's a face!)
                        if isinstance(tiktok_data['mediaUrls'], list) and len(tiktok_data['mediaUrls']) > 0:
                            # Look for image URLs in mediaUrls (skip avatar/profile images)
                            for media_url in tiktok_data['mediaUrls']:
                                if isinstance(media_url, str):
                                    # Skip avatar/profile images (they contain 'avatar' or are from CDN paths with user IDs)
                                    if 'avatar' in media_url.lower() or 'profile' in media_url.lower():
                                        print(f"LAMBDA/TIKTOK: Skipping avatar URL: {media_url[:100]}")
                                        continue
                                    # Check if it's an image URL (not video)
                                    if any(ext in media_url.lower() for ext in ['.jpg', '.jpeg', '.png', '.webp', 'image']):
                                        thumbnail = media_url
                                        print(f"LAMBDA/TIKTOK: Found image in mediaUrls: {media_url[:100]}")
                                        break
                                    # Also check if it contains 'cover' or 'thumbnail' (but not avatar)
                                    if ('cover' in media_url.lower() or 'thumbnail' in media_url.lower()) and 'avatar' not in media_url.lower():
                                        thumbnail = media_url
                                        print(f"LAMBDA/TIKTOK: Found cover/thumbnail in mediaUrls: {media_url[:100]}")
                                        break
                    
                    # Try top-level 'cover' field (video cover, not author avatar)
                    if not thumbnail and 'cover' in tiktok_data:
                        cover_value = tiktok_data['cover']
                        if isinstance(cover_value, str) and 'avatar' not in cover_value.lower():
                            thumbnail = cover_value
                            print(f"LAMBDA/TIKTOK: Found thumbnail in top-level cover: {cover_value[:100]}")
                    
                    # Don't use webVideoUrl as thumbnail - it's a video, not an image
                    # Don't use authorMeta.avatar - that's a profile picture (face), NOT food!
                    # If no thumbnail found, leave empty (iOS will handle missing image)
                    
                    # Log what we found
                    if not thumbnail:
                        print(f"LAMBDA/TIKTOK: No thumbnail found in Apify response. Checked keys: covers, cover, imageUrl, videoMeta, mediaUrls (skipped authorMeta.avatar)")
                        # Log mediaUrls structure if available
                        if 'mediaUrls' in tiktok_data:
                            print(f"LAMBDA/TIKTOK: mediaUrls content: {tiktok_data['mediaUrls']}")
                        # Log videoMeta if available
                        if 'videoMeta' in tiktok_data:
                            print(f"LAMBDA/TIKTOK: videoMeta keys: {list(tiktok_data['videoMeta'].keys()) if isinstance(tiktok_data['videoMeta'], dict) else 'not a dict'}")
                    
                    print(f"LAMBDA/TIKTOK: Metadata fetched - title length: {len(title)}, description length: {len(description)}, thumbnail: {thumbnail[:100] if thumbnail else 'NONE'}")
                    
                    # Extract actual video ID from Apify response if available
                    actual_video_id = video_id
                    if 'id' in tiktok_data:
                        actual_video_id = str(tiktok_data['id'])
                    elif 'webVideoUrl' in tiktok_data:
                        # Try to extract from webVideoUrl if available
                        web_url = tiktok_data['webVideoUrl']
                        extracted_id = extract_tiktok_video_id(web_url)
                        if extracted_id:
                            actual_video_id = extracted_id
                    
                    return {
                        'title': title,
                        'description': description,
                        'thumbnail_url': thumbnail,
                        'author': author,
                        'author_url': author_url,
                        'video_id': actual_video_id
                    }
            
            # Log progress every 5 attempts (every 10 seconds with 2s sleep)
            if attempt % 5 == 0:
                print(f"LAMBDA/TIKTOK: Waiting for Apify results... ({attempt + 1}/{max_attempts})")
        
        # Final check - get run status to see what happened
        try:
            status_response = requests.get(run_status_url, headers=headers, timeout=10)
            if status_response.status_code == 200:
                status_data = status_response.json()
                run_status = status_data.get('data', {}).get('status', 'UNKNOWN')
                raise Exception(f"Apify timeout - run status: {run_status} (no results after 60 seconds)")
        except Exception as status_error:
            raise Exception(f"Apify timeout - no results after 60 seconds. Status check error: {str(status_error)}")
        
    except requests.exceptions.Timeout:
        print("LAMBDA/TIKTOK: Apify request timeout")
        raise Exception("Apify request timeout")
    except requests.exceptions.RequestException as e:
        print(f"LAMBDA/TIKTOK: Apify request error: {str(e)}")
        raise Exception(f"Apify request error: {str(e)}")
    except Exception as e:
        print(f"LAMBDA/TIKTOK: Apify extraction error: {str(e)}")
        import traceback
        print(f"LAMBDA/TIKTOK: Traceback: {traceback.format_exc()}")
        raise

# ============================================================================
# YOUTUBE RECIPE EXTRACTION (3-Tier System)
# ============================================================================

def fetch_youtube_metadata(video_id: str) -> Dict[str, Any]:
    """Fetch video metadata from YouTube Data API v3"""
    api_key = os.environ.get('YOUTUBE_API_KEY')
    if not api_key:
        raise Exception("YOUTUBE_API_KEY not set")
    
    url = f"https://www.googleapis.com/youtube/v3/videos?id={video_id}&part=snippet&key={api_key}"
    
    try:
        response = requests.get(url, timeout=10)
        if response.status_code == 403:
            raise Exception("YouTube API quota exceeded or invalid key")
        if response.status_code != 200:
            raise Exception(f"YouTube API error: {response.status_code}")
        
        data = response.json()
        items = data.get('items', [])
        if not items:
            raise Exception("Video not found")
        
        snippet = items[0]['snippet']
        title = snippet.get('title', 'Untitled')
        description = snippet.get('description', '')
        channel_title = snippet.get('channelTitle', '')
        channel_id = snippet.get('channelId', '')
        
        # Get highest quality thumbnail
        thumbnails = snippet.get('thumbnails', {})
        thumbnail_url = None
        for quality in ['maxres', 'high', 'medium', 'default']:
            if quality in thumbnails:
                thumbnail_url = thumbnails[quality].get('url')
                break
        
        # Build channel URL
        author_url = f"https://www.youtube.com/channel/{channel_id}" if channel_id else ''
        
        return {
            'title': title,
            'description': description,
            'thumbnail_url': thumbnail_url or '',
            'channel_title': channel_title,
            'channel_id': channel_id,
            'author': channel_title,  # Use channel_title as author name
            'author_url': author_url
        }
    except Exception as e:
        print(f"LAMBDA/YOUTUBE: metadata error={str(e)}")
        raise

def get_youtube_service_with_oauth():
    """Get YouTube API service using OAuth 2.0 credentials"""
    try:
        from google.oauth2.credentials import Credentials
        from google.auth.transport.requests import Request
        import googleapiclient.discovery
        
        # Option 1: Use OAuth 2.0 with refresh token (stored in env vars)
        client_id = os.environ.get('YOUTUBE_CLIENT_ID')
        client_secret = os.environ.get('YOUTUBE_CLIENT_SECRET')
        refresh_token = os.environ.get('YOUTUBE_REFRESH_TOKEN')
        
        if all([client_id, client_secret, refresh_token]):
            print("LAMBDA/YOUTUBE: Using OAuth 2.0 with refresh token")
            credentials = Credentials(
                token=None,
                refresh_token=refresh_token,
                token_uri='https://oauth2.googleapis.com/token',
                client_id=client_id,
                client_secret=client_secret,
                scopes=['https://www.googleapis.com/auth/youtube.force-ssl']
            )
            
            # Refresh the token if needed
            if not credentials.valid:
                credentials.refresh(Request())
            
            return googleapiclient.discovery.build('youtube', 'v3', credentials=credentials)
        
        # Option 2: Use Service Account JSON (stored as env var or in Secrets Manager)
        service_account_json = os.environ.get('GOOGLE_SERVICE_ACCOUNT_JSON')
        if service_account_json:
            print("LAMBDA/YOUTUBE: Using Service Account JSON")
            from google.oauth2 import service_account
            import json
            
            # Parse JSON string if it's a string, otherwise assume it's already a dict
            if isinstance(service_account_json, str):
                try:
                    sa_data = json.loads(service_account_json)
                except json.JSONDecodeError:
                    # Maybe it's a file path? Try reading it
                    if os.path.exists(service_account_json):
                        with open(service_account_json, 'r') as f:
                            sa_data = json.load(f)
                    else:
                        raise Exception("Invalid service account JSON")
            else:
                sa_data = service_account_json
            
            credentials = service_account.Credentials.from_service_account_info(
                sa_data,
                scopes=['https://www.googleapis.com/auth/youtube.force-ssl']
            )
            
            return googleapiclient.discovery.build('youtube', 'v3', credentials=credentials)
        
        # Option 3: Try AWS Secrets Manager for service account
        try:
            import boto3
            secrets_client = boto3.client('secretsmanager')
            secret_name = os.environ.get('GOOGLE_SA_SECRET_NAME', 'youtube-service-account')
            
            try:
                response = secrets_client.get_secret_value(SecretId=secret_name)
                sa_data = json.loads(response['SecretString'])
                
                print("LAMBDA/YOUTUBE: Using Service Account from Secrets Manager")
                from google.oauth2 import service_account
                
                credentials = service_account.Credentials.from_service_account_info(
                    sa_data,
                    scopes=['https://www.googleapis.com/auth/youtube.force-ssl']
                )
                
                return googleapiclient.discovery.build('youtube', 'v3', credentials=credentials)
            except Exception as e:
                print(f"LAMBDA/YOUTUBE: Secrets Manager error: {str(e)}")
        except ImportError:
            pass  # boto3 not available
        
        return None
        
    except ImportError as e:
        print(f"LAMBDA/YOUTUBE: Google API libraries not installed: {str(e)}")
        return None
    except Exception as e:
        print(f"LAMBDA/YOUTUBE: OAuth setup error: {str(e)}")
        return None

def fetch_youtube_transcript(video_id: str) -> str:
    """Fetch YouTube transcript using YouTube Data API v3 captions endpoint with OAuth 2.0"""
    api_key = os.environ.get('YOUTUBE_API_KEY')
    
    # Try OAuth first if available
    youtube_service = get_youtube_service_with_oauth()
    
    if youtube_service:
        try:
            print("LAMBDA/YOUTUBE: Attempting transcript fetch with OAuth 2.0")
            
            # List caption tracks using OAuth
            caption_list = youtube_service.captions().list(
                part='snippet',
                videoId=video_id
            ).execute()
            
            items = caption_list.get('items', [])
            if not items:
                print(f"LAMBDA/YOUTUBE: No caption tracks found for video {video_id}")
                return ""
            
            # Find best caption track (same priority logic)
            caption_id = None
            caption_language = None
            
            # Priority: English auto-generated > English manual > Any auto-generated > Any manual
            for item in items:
                snippet = item.get('snippet', {})
                if snippet.get('language', '').startswith('en') and snippet.get('trackKind') == 'ASR':
                    caption_id = item.get('id')
                    caption_language = snippet.get('language', 'en')
                    break
            
            if not caption_id:
                for item in items:
                    snippet = item.get('snippet', {})
                    if snippet.get('language', '').startswith('en') and snippet.get('trackKind') != 'ASR':
                        caption_id = item.get('id')
                        caption_language = snippet.get('language', 'en')
                        break
            
            if not caption_id:
                for item in items:
                    snippet = item.get('snippet', {})
                    if snippet.get('trackKind') == 'ASR':
                        caption_id = item.get('id')
                        caption_language = snippet.get('language', 'en')
                        break
            
            if not caption_id and items:
                caption_id = items[0].get('id')
                caption_language = items[0].get('snippet', {}).get('language', 'en')
            
            if not caption_id:
                print(f"LAMBDA/YOUTUBE: Could not find valid caption track")
                return ""
            
            print(f"LAMBDA/YOUTUBE: Found caption track {caption_id} (language: {caption_language})")
            
            # Download caption with OAuth
            caption_download = youtube_service.captions().download(
                id=caption_id,
                tfmt='ttml'
            ).execute()
            
            # Parse TTML content
            if isinstance(caption_download, bytes):
                ttml_content = caption_download.decode('utf-8')
            else:
                ttml_content = str(caption_download)
            
            # Extract text from TTML
            text_parts = re.findall(r'<p[^>]*>([^<]+)</p>', ttml_content)
            
            if not text_parts:
                text_parts = re.findall(r'>([^<]+)<', ttml_content)
            
            if not text_parts:
                print(f"LAMBDA/YOUTUBE: Could not parse TTML caption content")
                return ""
            
            transcript = ' '.join(text_parts)
            transcript = ' '.join(transcript.split())
            
            if transcript and len(transcript.strip()) > 100:
                print(f"LAMBDA/YOUTUBE: transcript fetched successfully via OAuth ({len(transcript)} chars, lang: {caption_language})")
                return transcript
            else:
                print(f"LAMBDA/YOUTUBE: transcript too short ({len(transcript) if transcript else 0} chars)")
                return ""
                
        except Exception as e:
            print(f"LAMBDA/YOUTUBE: OAuth transcript error: {str(e)}")
            import traceback
            print(f"LAMBDA/YOUTUBE: OAuth traceback: {traceback.format_exc()}")
            # Fall through to API key method or HTML fallback
    
    # Fallback to API key method (for listing captions) + HTML parsing (for downloading)
    if not api_key:
        print("LAMBDA/YOUTUBE: YOUTUBE_API_KEY not set, skipping transcript")
        return ""
    
    try:
        # Step 1: List available caption tracks
        list_url = f"https://www.googleapis.com/youtube/v3/captions?videoId={video_id}&part=snippet&key={api_key}"
        response = requests.get(list_url, timeout=10)
        
        if response.status_code == 403:
            print(f"LAMBDA/YOUTUBE: YouTube API quota exceeded or invalid key for captions")
            return ""
        if response.status_code != 200:
            print(f"LAMBDA/YOUTUBE: YouTube captions.list API error: {response.status_code}")
            return ""
        
        data = response.json()
        items = data.get('items', [])
        
        if not items:
            print(f"LAMBDA/YOUTUBE: No caption tracks found for video {video_id}")
            return ""
        
        # Step 2: Find best caption track (prefer English, auto-generated, then manual)
        caption_id = None
        caption_language = None
        
        # Priority: English auto-generated > English manual > Any auto-generated > Any manual
        # Try English auto-generated first (ASR = Automatic Speech Recognition)
        for item in items:
            snippet = item.get('snippet', {})
            if snippet.get('language', '').startswith('en') and snippet.get('trackKind') == 'ASR':
                caption_id = item.get('id')
                caption_language = snippet.get('language', 'en')
                break
        
        # Try English manual
        if not caption_id:
            for item in items:
                snippet = item.get('snippet', {})
                if snippet.get('language', '').startswith('en') and snippet.get('trackKind') != 'ASR':
                    caption_id = item.get('id')
                    caption_language = snippet.get('language', 'en')
                    break
        
        # Try any auto-generated
        if not caption_id:
            for item in items:
                snippet = item.get('snippet', {})
                if snippet.get('trackKind') == 'ASR':
                    caption_id = item.get('id')
                    caption_language = snippet.get('language', 'en')
                    break
        
        # Try any manual
        if not caption_id:
            item = items[0]
            caption_id = item.get('id')
            caption_language = item.get('snippet', {}).get('language', 'en')
        
        if not caption_id:
            print(f"LAMBDA/YOUTUBE: Could not find valid caption track for video {video_id}")
            return ""
        
        print(f"LAMBDA/YOUTUBE: Found caption track {caption_id} (language: {caption_language})")
        
        # Step 3: Download caption content (use ttml format for easier parsing)
        download_url = f"https://www.googleapis.com/youtube/v3/captions/{caption_id}?key={api_key}&tfmt=ttml"
        download_response = requests.get(download_url, timeout=15)
        
        if download_response.status_code != 200:
            error_detail = download_response.text[:500] if download_response.text else "No error detail"
            print(f"LAMBDA/YOUTUBE: Caption download failed: {download_response.status_code}, error: {error_detail}")
            # YouTube Data API v3 captions.download requires OAuth 2.0, not just API key
            # Fall back to parsing watch page HTML for public captions
            print(f"LAMBDA/YOUTUBE: Falling back to watch page HTML parsing")
            return fetch_youtube_transcript_from_html(video_id)
        
        # Step 4: Parse TTML format and extract text
        ttml_content = download_response.text
        
        # Simple TTML parsing - extract text from <p> tags
        # Remove XML tags and extract text content
        # TTML format: <p begin="..." end="...">text content</p>
        text_parts = re.findall(r'<p[^>]*>([^<]+)</p>', ttml_content)
        
        if not text_parts:
            # Fallback: try to extract any text between tags
            text_parts = re.findall(r'>([^<]+)<', ttml_content)
        
        if not text_parts:
            print(f"LAMBDA/YOUTUBE: Could not parse TTML caption content")
            return ""
        
        # Join all text parts and clean up
        transcript = ' '.join(text_parts)
        # Remove extra whitespace
        transcript = ' '.join(transcript.split())
        
        if transcript and len(transcript.strip()) > 100:
            print(f"LAMBDA/YOUTUBE: transcript fetched successfully via API v3 ({len(transcript)} chars, lang: {caption_language})")
            return transcript
        else:
            print(f"LAMBDA/YOUTUBE: transcript too short ({len(transcript) if transcript else 0} chars)")
            return ""
            
    except Exception as e:
        print(f"LAMBDA/YOUTUBE: transcript error={str(e)}")
        import traceback
        print(f"LAMBDA/YOUTUBE: transcript traceback: {traceback.format_exc()}")
        return ""

def fetch_youtube_transcript_from_html(video_id: str) -> str:
    """Fallback: Extract transcript from YouTube watch page HTML (similar to youtube-transcript-api)"""
    try:
        # Fetch the watch page HTML
        watch_url = f"https://www.youtube.com/watch?v={video_id}"
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        }
        response = requests.get(watch_url, headers=headers, timeout=15)
        
        if response.status_code != 200:
            print(f"LAMBDA/YOUTUBE: Failed to fetch watch page: {response.status_code}")
            return ""
        
        html = response.text
        
        # Extract caption tracks from embedded JSON data
        # YouTube embeds caption track URLs in the page's JSON data
        # Look for "captionTracks" in the ytInitialPlayerResponse JSON
        
        # Try to find ytInitialPlayerResponse JSON
        match = re.search(r'var ytInitialPlayerResponse = ({.+?});', html, re.DOTALL)
        if not match:
            # Try alternative pattern
            match = re.search(r'"captionTracks":\s*(\[.+?\])', html, re.DOTALL)
        
        if not match:
            print(f"LAMBDA/YOUTUBE: Could not find caption tracks in watch page HTML")
            return ""
        
        try:
            # Try to parse the JSON
            json_str = match.group(1)
            # Clean up the JSON string
            json_str = json_str.strip()
            if json_str.startswith('{'):
                player_response = json.loads(json_str)
                caption_tracks = player_response.get('captions', {}).get('playerCaptionsTracklistRenderer', {}).get('captionTracks', [])
            else:
                caption_tracks = json.loads(json_str)
        except:
            # If direct parsing fails, try to extract captionTracks from the full JSON
            try:
                # Find the full ytInitialPlayerResponse
                full_match = re.search(r'var ytInitialPlayerResponse = ({.+?});', html, re.DOTALL)
                if full_match:
                    player_response = json.loads(full_match.group(1))
                    caption_tracks = player_response.get('captions', {}).get('playerCaptionsTracklistRenderer', {}).get('captionTracks', [])
                else:
                    print(f"LAMBDA/YOUTUBE: Could not parse caption tracks JSON")
                    return ""
            except Exception as e:
                print(f"LAMBDA/YOUTUBE: JSON parsing error: {str(e)}")
                return ""
        
        if not caption_tracks:
            print(f"LAMBDA/YOUTUBE: No caption tracks found in watch page")
            return ""
        
        # Find best caption track (prefer English, auto-generated)
        caption_url = None
        for track in caption_tracks:
            lang = track.get('languageCode', '')
            is_auto = track.get('kind') == 'asr'  # Auto-generated
            
            if lang.startswith('en') and is_auto:
                caption_url = track.get('baseUrl')
                break
        
        # Try English manual
        if not caption_url:
            for track in caption_tracks:
                lang = track.get('languageCode', '')
                if lang.startswith('en'):
                    caption_url = track.get('baseUrl')
                    break
        
        # Try any auto-generated
        if not caption_url:
            for track in caption_tracks:
                if track.get('kind') == 'asr':
                    caption_url = track.get('baseUrl')
                    break
        
        # Try any
        if not caption_url and caption_tracks:
            caption_url = caption_tracks[0].get('baseUrl')
        
        if not caption_url:
            print(f"LAMBDA/YOUTUBE: No valid caption URL found")
            return ""
        
        print(f"LAMBDA/YOUTUBE: Found caption URL from watch page HTML")
        
        # Fetch the caption XML
        caption_response = requests.get(caption_url, headers=headers, timeout=15)
        if caption_response.status_code != 200:
            print(f"LAMBDA/YOUTUBE: Failed to fetch caption XML: {caption_response.status_code}")
            return ""
        
        # Parse XML/TTML format
        caption_xml = caption_response.text
        
        # Extract text from <text> tags (YouTube's caption format)
        text_parts = re.findall(r'<text[^>]*>([^<]+)</text>', caption_xml)
        
        if not text_parts:
            # Try TTML format (<p> tags)
            text_parts = re.findall(r'<p[^>]*>([^<]+)</p>', caption_xml)
        
        if not text_parts:
            print(f"LAMBDA/YOUTUBE: Could not parse caption XML")
            return ""
        
        # Join and clean up
        transcript = ' '.join(text_parts)
        transcript = ' '.join(transcript.split())  # Remove extra whitespace
        
        if transcript and len(transcript.strip()) > 100:
            print(f"LAMBDA/YOUTUBE: transcript fetched successfully from HTML ({len(transcript)} chars)")
            return transcript
        else:
            print(f"LAMBDA/YOUTUBE: transcript too short ({len(transcript) if transcript else 0} chars)")
            return ""
            
    except Exception as e:
        print(f"LAMBDA/YOUTUBE: HTML fallback error={str(e)}")
        import traceback
        print(f"LAMBDA/YOUTUBE: HTML fallback traceback: {traceback.format_exc()}")
        return ""

def parse_youtube_recipe_deterministic(title: str, description: str) -> Dict[str, Any]:
    """Tier 1: Fast deterministic parsing of YouTube recipe from description"""
    ingredients = []
    instructions = []
    servings = 4  # Default
    
    # Find ingredients section
    ingredient_keywords = [
        'INGREDIENTS:', 'Ingredients:', 'INGREDIENTS', 'Ingredients',
        'INGREDIENTS -', 'Ingredients -', 'INGREDIENT LIST:', 'Ingredient List:',
        'WHAT YOU NEED:', 'What You Need:'
    ]
    
    ingredients_text = ""
    ingredients_start = None
    for keyword in ingredient_keywords:
        idx = description.find(keyword)
        if idx != -1:
            ingredients_start = idx + len(keyword)
            break
    
    if ingredients_start:
        # Find where ingredients section ends (at Method/Instructions)
        stop_keywords = ['METHOD:', 'Method:', 'INSTRUCTIONS:', 'Instructions:', 'DIRECTIONS:', 'Directions:', 'STEPS:', 'Steps:']
        ingredients_end = len(description)
        for keyword in stop_keywords:
            idx = description.find(keyword, ingredients_start)
            if idx != -1 and idx < ingredients_end:
                ingredients_end = idx
        
        ingredients_text = description[ingredients_start:ingredients_end]
        
        # Parse ingredients (lines starting with numbers, bullets, or dashes)
        for line in ingredients_text.split('\n'):
            line = line.strip()
            if not line:
                continue
            # Check if it's a list item (starts with number, bullet, or dash)
            if re.match(r'^(\d+[\.\)]\s+|\d+\s+[-•]\s+|[-•]\s+)', line):
                # Remove leading number/bullet
                ingredient = re.sub(r'^(\d+[\.\)]\s+|\d+\s+[-•]\s+|[-•]\s+)', '', line).strip()
                if ingredient and len(ingredient) > 3:
                    ingredients.append(ingredient)
    
    # Find instructions section (after ingredients)
    instruction_keywords = [
        'METHOD:', 'Method:', 'INSTRUCTIONS:', 'Instructions:',
        'DIRECTIONS:', 'Directions:', 'STEPS:', 'Steps:',
        'HOW TO:', 'How to:', 'PREPARATION:', 'Preparation:',
        'COOKING:', 'Cooking:', 'PROCEDURE:', 'Procedure:'
    ]
    
    instructions_start = None
    if ingredients_start:
        # Start searching after ingredients section
        search_start = ingredients_start + len(ingredients_text)
    else:
        search_start = 0
    
    for keyword in instruction_keywords:
        idx = description.find(keyword, search_start)
        if idx != -1:
            instructions_start = idx + len(keyword)
            break
    
    if instructions_start:
        instructions_text = description[instructions_start:]
        
        # Parse instructions (numbered steps, bullet points, or action paragraphs)
        for line in instructions_text.split('\n'):
            line = line.strip()
            if not line:
                continue
            
            # Skip common non-instruction lines
            skip_patterns = [
                r'^(subscribe|like|share|follow|click|watch|video|channel)',
                r'^(ingredients|ingredient|you will need|you need)',
                r'^(for more|check out|visit|link|website)',
                r'^(music|song|track|audio)',
                r'^(sponsor|advertisement|ad|promo)',
                r'^\d+:\d+',  # Timestamps
            ]
            if any(re.match(pattern, line, re.IGNORECASE) for pattern in skip_patterns):
                continue
            
            # Check if it's a numbered step or instruction
            if re.match(r'^(\d+[\.\)]\s+|\d+\s+[-•]\s+|[-•]\s+)', line):
                instruction = re.sub(r'^(\d+[\.\)]\s+|\d+\s+[-•]\s+|[-•]\s+)', '', line).strip()
                if instruction and len(instruction) > 10:  # Minimum length for instruction
                    instructions.append(instruction)
            # Also check for action verbs that indicate instructions
            elif re.search(r'\b(heat|add|mix|stir|cook|bake|fry|boil|simmer|roast|grill|season|dice|chop|slice|mince|pour|whisk|beat|fold|knead|roll|cut|peel|grate|sauté|brown|caramelize|reduce|thicken|garnish|serve|plate|preheat|combine|blend|marinate|rest|resting)\b', line, re.IGNORECASE):
                # This looks like an instruction even without numbering
                if len(line) > 15 and len(line) < 300:  # Reasonable length
                    instructions.append(line)
    
    # Look for servings
    servings_match = re.search(r'(serves|servings|makes|yield)[:\s]*(\d+)', description, re.IGNORECASE)
    if servings_match:
        try:
            servings = int(servings_match.group(2))
        except:
            pass
    
    # Clean title (remove YouTube suffixes)
    cleaned_title = re.sub(r'\s*-\s*YouTube$', '', title, flags=re.IGNORECASE)
    cleaned_title = re.sub(r'\s*\|.*$', '', cleaned_title)
    
    return {
        'title': cleaned_title.strip(),
        'ingredients': ingredients,
        'instructions': instructions,
        'servings': str(servings) if servings else None
    }

def parse_youtube_recipe_ai_description(title: str, description: str, thumbnail_url: str) -> Dict[str, Any]:
    """Tier 2: Use OpenAI GPT-4 to extract recipe from description"""
    api_key = os.environ.get('OPENAI_API_KEY')
    if not api_key:
        raise Exception("OPENAI_API_KEY not set")
    
    prompt = f"""Extract recipe information from this YouTube video description. Return ONLY valid JSON, no markdown, no backticks, no commentary.

Video Title: {title}

Description:
{description[:4000]}  # Limit to avoid token limits

Return a JSON object with these exact fields:
{{
  "title": "cleaned recipe title (remove YouTube suffixes, emojis)",
  "ingredients": ["ingredient 1", "ingredient 2", ...],
  "instructions": ["step 1", "step 2", ...],
  "servings": "number as string or null"
}}

Rules:
- Extract ALL ingredients mentioned, even if buried in text or conversational ("you'll need some flour...")
- Extract ALL cooking steps/instructions - look for:
  * Numbered steps (1., 2., 3. or Step 1, Step 2)
  * Bulleted lists with cooking actions
  * Paragraphs describing cooking methods ("First, heat oil...", "Then add...", "Cook until...")
  * Action verbs (heat, add, cook, bake, mix, stir, etc.)
- Instructions can be in various formats:
  * Explicit "Instructions:" or "Method:" sections
  * Embedded in paragraphs describing the cooking process
  * Listed as numbered or bulleted steps
- Ignore timestamps, sponsor sections, social media links, subscribe prompts
- Instructions should be clear, actionable steps (not just ingredient mentions)
- If servings mentioned, extract it; otherwise null
- Title should be clean recipe name only
- If no instructions found in description, return empty array [] (instructions are likely in video)"""
    
    try:
        headers = {
            'Authorization': f'Bearer {api_key}',
            'Content-Type': 'application/json'
        }
        
        payload = {
            'model': 'gpt-4o-mini',  # Using GPT-4o-mini for cost efficiency
            'max_tokens': 2000,
            'temperature': 0,
            'messages': [{'role': 'user', 'content': prompt}],
            'response_format': {'type': 'json_object'}  # Force JSON response
        }
        
        response = requests.post(
            'https://api.openai.com/v1/chat/completions',
            headers=headers,
            json=payload,
            timeout=15
        )
        
        if response.status_code == 200:
            result = response.json()
            content = result.get('choices', [{}])[0].get('message', {}).get('content', '').strip()
            
            if content:
                # Remove markdown code blocks if present (though response_format should prevent this)
                if content.startswith('```json'):
                    content = content[7:]
                if content.startswith('```'):
                    content = content[3:]
                if content.endswith('```'):
                    content = content[:-3]
                content = content.strip()
                
                ai_data = json.loads(content)
                # Add thumbnail
                ai_data['image'] = thumbnail_url
                return ai_data
        raise Exception(f"OpenAI API error: {response.status_code} - {response.text[:200]}")
    except json.JSONDecodeError as e:
        print(f"LAMBDA/YOUTUBE: JSON decode error={str(e)}")
        raise Exception(f"Failed to parse OpenAI response: {str(e)}")
    except Exception as e:
        print(f"LAMBDA/YOUTUBE: OpenAI description error={str(e)}")
        raise

def parse_youtube_recipe_ai_transcript(title: str, transcript: str, thumbnail_url: str) -> Dict[str, Any]:
    """Tier 3: Use OpenAI GPT-4 to extract recipe from video transcript"""
    api_key = os.environ.get('OPENAI_API_KEY')
    if not api_key:
        raise Exception("OPENAI_API_KEY not set")
    
    prompt = f"""Extract recipe information from this YouTube video transcript. The recipe was spoken in the video. Return ONLY valid JSON, no markdown, no backticks, no commentary.

Video Title: {title}

Transcript:
{transcript[:6000]}  # Limit to avoid token limits

Return a JSON object with these exact fields:
{{
  "title": "cleaned recipe title",
  "ingredients": ["ingredient 1", "ingredient 2", ...],
  "instructions": ["step 1", "step 2", ...],
  "servings": "number as string or null"
}}

Rules:
- Extract ALL ingredients mentioned in the video
- CRITICAL: Extract ALL cooking steps/instructions spoken - this is the most important part
- Instructions should be clear, actionable steps in chronological order
- Look for:
  * Numbered steps ("first", "then", "next", "now", "step 1", "step 2")
  * Action verbs (heat, add, mix, stir, cook, bake, fry, boil, simmer, roast, grill, season, dice, chop, slice, pour, whisk, beat, fold, knead, roll, cut, peel, grate, sauté, brown, caramelize, reduce, thicken, garnish, serve, plate, preheat, combine, blend, marinate)
  * Time references ("cook for 5 minutes", "until golden brown", "when it bubbles")
  * Temperature references ("at 350 degrees", "medium heat", "high heat")
  * Technique descriptions ("whisk until smooth", "stir constantly", "let it rest")
- Each instruction should be a complete, actionable step (10-200 characters)
- Extract at least 3-8 steps if possible
- If servings mentioned, extract it; otherwise null
- Title should be clean recipe name only"""
    
    try:
        headers = {
            'Authorization': f'Bearer {api_key}',
            'Content-Type': 'application/json'
        }
        
        payload = {
            'model': 'gpt-4o-mini',  # Using GPT-4o-mini for cost efficiency
            'max_tokens': 2500,  # Increased for better instruction extraction
            'temperature': 0,
            'messages': [{'role': 'user', 'content': prompt}],
            'response_format': {'type': 'json_object'}  # Force JSON response
        }
        
        response = requests.post(
            'https://api.openai.com/v1/chat/completions',
            headers=headers,
            json=payload,
            timeout=15
        )
        
        if response.status_code == 200:
            result = response.json()
            content = result.get('choices', [{}])[0].get('message', {}).get('content', '').strip()
            
            if content:
                # Remove markdown code blocks if present (though response_format should prevent this)
                if content.startswith('```json'):
                    content = content[7:]
                if content.startswith('```'):
                    content = content[3:]
                if content.endswith('```'):
                    content = content[:-3]
                content = content.strip()
                
                ai_data = json.loads(content)
                # Add thumbnail
                ai_data['image'] = thumbnail_url
                return ai_data
        raise Exception(f"OpenAI API error: {response.status_code} - {response.text[:200]}")
    except json.JSONDecodeError as e:
        print(f"LAMBDA/YOUTUBE: JSON decode error={str(e)}")
        raise Exception(f"Failed to parse OpenAI response: {str(e)}")
    except Exception as e:
        print(f"LAMBDA/YOUTUBE: OpenAI transcript error={str(e)}")
        raise

def generate_recipe_from_title(title: str) -> Dict[str, Any]:
    """Tier 2.6: Generate complete recipe (ingredients + instructions) from title only"""
    api_key = os.environ.get('OPENAI_API_KEY')
    if not api_key:
        print("LAMBDA/YOUTUBE: Tier 2.6 skipped - OPENAI_API_KEY not set")
        return {}
    
    if not title or len(title.strip()) < 5:
        print("LAMBDA/YOUTUBE: Tier 2.6 skipped - title too short")
        return {}
    
    try:
        # Clean title (remove YouTube suffixes, pipe separators)
        cleaned_title = re.sub(r'\s*-\s*YouTube$', '', title, flags=re.IGNORECASE)
        cleaned_title = re.sub(r'\s*\|.*$', '', cleaned_title)
        cleaned_title = cleaned_title.strip()
        
        prompt = f"""You are a cooking expert. Generate a complete recipe based on this dish name.

Dish Name: {cleaned_title}

Generate a complete, standard recipe for this dish including typical ingredients and step-by-step cooking instructions.

Return ONLY a JSON object with this exact format, no markdown, no commentary:

{{
  "title": "cleaned recipe title",
  "ingredients": ["ingredient 1", "ingredient 2", ...],
  "instructions": ["step 1", "step 2", "step 3", ...],
  "servings": "number as string or null"
}}

Rules:
- Generate 5-15 typical ingredients for this dish type
- Generate 5-12 clear, actionable cooking steps
- Each instruction should be 15-200 characters
- Include typical cooking techniques for this dish type
- Order steps logically (prep → cook → finish)
- Include timing, temperatures, and techniques where appropriate
- Base recipe on standard, traditional preparation methods
- Make instructions detailed and helpful
- If servings not specified, use null"""

        headers = {
            'Authorization': f'Bearer {api_key}',
            'Content-Type': 'application/json'
        }
        
        payload = {
            'model': 'gpt-4o-mini',
            'max_tokens': 2500,
            'temperature': 0.3,  # Slightly higher for more natural generation
            'messages': [{'role': 'user', 'content': prompt}],
            'response_format': {'type': 'json_object'}
        }
        
        response = requests.post(
            'https://api.openai.com/v1/chat/completions',
            headers=headers,
            json=payload,
            timeout=20  # Slightly longer timeout for title-based generation
        )
        
        if response.status_code == 200:
            result = response.json()
            content = result.get('choices', [{}])[0].get('message', {}).get('content', '').strip()
            
            if content:
                # Remove markdown code blocks if present
                if content.startswith('```json'):
                    content = content[7:]
                if content.startswith('```'):
                    content = content[3:]
                if content.endswith('```'):
                    content = content[:-3]
                content = content.strip()
                
                ai_data = json.loads(content)
                
                # Validate we got usable data
                ingredients = ai_data.get('ingredients', [])
                instructions = ai_data.get('instructions', [])
                
                if len(ingredients) >= 3 and len(instructions) >= 3:
                    print(f"LAMBDA/YOUTUBE: Tier 2.6 generated recipe: {len(ingredients)} ingredients, {len(instructions)} instructions")
                    return ai_data
                else:
                    print(f"LAMBDA/YOUTUBE: Tier 2.6 generated insufficient data ({len(ingredients)} ingredients, {len(instructions)} instructions)")
                    return {}
        else:
            print(f"LAMBDA/YOUTUBE: Tier 2.6 API error: {response.status_code}")
            return {}
            
    except json.JSONDecodeError as e:
        print(f"LAMBDA/YOUTUBE: Tier 2.6 JSON decode error={str(e)}")
        return {}
    except Exception as e:
        print(f"LAMBDA/YOUTUBE: Tier 2.6 error={str(e)}")
        return {}

def generate_instructions_from_ingredients(title: str, ingredients: List[str]) -> List[str]:
    """Tier 2.5: Generate complete cooking instructions from ingredients and dish name"""
    api_key = os.environ.get('OPENAI_API_KEY')
    if not api_key:
        print("LAMBDA/YOUTUBE: Tier 2.5 skipped - OPENAI_API_KEY not set")
        return []
    
    if not ingredients or len(ingredients) < 2:
        print("LAMBDA/YOUTUBE: Tier 2.5 skipped - insufficient ingredients")
        return []
    
    try:
        ingredients_str = ', '.join(ingredients[:20]) if ingredients else "various ingredients"
        
        prompt = f"""You are a cooking expert. Generate complete, step-by-step cooking instructions for this recipe.

Recipe Name: {title}

Ingredients: {ingredients_str}

Generate detailed, step-by-step cooking instructions for making this dish. Base the instructions on standard cooking techniques for this type of recipe.

Return ONLY a JSON object with this exact format, no markdown, no commentary:

{{
  "instructions": ["step 1", "step 2", "step 3", ...]
}}

Rules:
- Generate 5-12 clear, actionable cooking steps
- Each step should be 15-200 characters
- Include typical cooking techniques for this dish type
- Order steps logically (prep → cook → finish)
- Include timing, temperatures, and techniques where appropriate
- Make instructions detailed and helpful
- Base steps on the ingredients provided and common cooking methods"""

        headers = {
            'Authorization': f'Bearer {api_key}',
            'Content-Type': 'application/json'
        }
        
        payload = {
            'model': 'gpt-4o-mini',
            'max_tokens': 2000,
            'temperature': 0.3,  # Slightly higher for more natural generation
            'messages': [{'role': 'user', 'content': prompt}],
            'response_format': {'type': 'json_object'}
        }
        
        response = requests.post(
            'https://api.openai.com/v1/chat/completions',
            headers=headers,
            json=payload,
            timeout=15
        )
        
        if response.status_code == 200:
            result = response.json()
            content = result.get('choices', [{}])[0].get('message', {}).get('content', '').strip()
            
            if content:
                # Remove markdown code blocks if present
                if content.startswith('```json'):
                    content = content[7:]
                if content.startswith('```'):
                    content = content[3:]
                if content.endswith('```'):
                    content = content[:-3]
                content = content.strip()
                
                ai_data = json.loads(content)
                instructions = ai_data.get('instructions', [])
                
                if instructions and len(instructions) >= 3:
                    print(f"LAMBDA/YOUTUBE: Tier 2.5 generated {len(instructions)} instructions from ingredients")
                    return instructions
                else:
                    print(f"LAMBDA/YOUTUBE: Tier 2.5 generated insufficient instructions ({len(instructions) if instructions else 0})")
                    return []
        else:
            print(f"LAMBDA/YOUTUBE: Tier 2.5 API error: {response.status_code}")
            return []
            
    except json.JSONDecodeError as e:
        print(f"LAMBDA/YOUTUBE: Tier 2.5 JSON decode error={str(e)}")
        return []
    except Exception as e:
        print(f"LAMBDA/YOUTUBE: Tier 2.5 error={str(e)}")
        return []

def generate_instructions_from_transcript(title: str, transcript: str, ingredients: List[str]) -> List[str]:
    """Tier 4: Generate instructions from transcript when missing from previous tiers"""
    api_key = os.environ.get('OPENAI_API_KEY')
    if not api_key:
        print("LAMBDA/YOUTUBE: Tier 4 skipped - OPENAI_API_KEY not set")
        return []
    
    if not transcript or len(transcript.strip()) < 100:
        print("LAMBDA/YOUTUBE: Tier 4 skipped - transcript too short")
        return []
    
    try:
        ingredients_str = ', '.join(ingredients[:15]) if ingredients else "various ingredients"
        
        prompt = f"""You are extracting cooking instructions from a YouTube video transcript. 
The video is about making: {title}

Ingredients mentioned: {ingredients_str}

Transcript:
{transcript[:6000]}

Generate step-by-step cooking instructions based on what was said in the video. 
Return ONLY a JSON object with this exact format, no markdown, no commentary:

{{
  "instructions": ["step 1", "step 2", "step 3", ...]
}}

Rules:
- Extract ALL cooking steps mentioned in the transcript
- Instructions should be clear, actionable steps in chronological order
- Look for:
  * Sequential markers ("first", "then", "next", "now", "after that", "finally")
  * Action verbs (heat, add, mix, stir, cook, bake, fry, boil, simmer, roast, grill, season, dice, chop, slice, pour, whisk, beat, fold, knead, roll, cut, peel, grate, sauté, brown, caramelize, reduce, thicken, garnish, serve, plate, preheat, combine, blend, marinate)
  * Time references ("cook for 5 minutes", "until golden brown", "when it bubbles", "for about 10 minutes")
  * Temperature references ("at 350 degrees", "medium heat", "high heat", "low heat")
  * Technique descriptions ("whisk until smooth", "stir constantly", "let it rest", "until tender")
  * Visual cues ("until golden", "when it starts to bubble", "until fragrant")
- Each instruction should be a complete, actionable step (15-200 characters)
- Include specific details mentioned (times, temperatures, techniques)
- Generate at least 3-8 steps if possible
- Order steps chronologically as they appear in the video
- Ignore non-cooking content (introductions, sponsors, subscribe prompts, timestamps)"""

        headers = {
            'Authorization': f'Bearer {api_key}',
            'Content-Type': 'application/json'
        }
        
        payload = {
            'model': 'gpt-4o-mini',
            'max_tokens': 2000,
            'temperature': 0,
            'messages': [{'role': 'user', 'content': prompt}],
            'response_format': {'type': 'json_object'}
        }
        
        response = requests.post(
            'https://api.openai.com/v1/chat/completions',
            headers=headers,
            json=payload,
            timeout=15
        )
        
        if response.status_code == 200:
            result = response.json()
            content = result.get('choices', [{}])[0].get('message', {}).get('content', '').strip()
            
            if content:
                # Remove markdown code blocks if present
                if content.startswith('```json'):
                    content = content[7:]
                if content.startswith('```'):
                    content = content[3:]
                if content.endswith('```'):
                    content = content[:-3]
                content = content.strip()
                
                ai_data = json.loads(content)
                instructions = ai_data.get('instructions', [])
                
                if instructions and len(instructions) >= 2:
                    print(f"LAMBDA/YOUTUBE: Tier 4 generated {len(instructions)} instructions from transcript")
                    return instructions
                else:
                    print(f"LAMBDA/YOUTUBE: Tier 4 generated insufficient instructions ({len(instructions) if instructions else 0})")
                    return []
        else:
            print(f"LAMBDA/YOUTUBE: Tier 4 API error: {response.status_code}")
            return []
            
    except json.JSONDecodeError as e:
        print(f"LAMBDA/YOUTUBE: Tier 4 JSON decode error={str(e)}")
        return []
    except Exception as e:
        print(f"LAMBDA/YOUTUBE: Tier 4 error={str(e)}")
        return []

def validate_youtube_result(result: Dict[str, Any], tier_name: str, strict: bool = False):
    """
    Validate YouTube extraction result with relaxed rules.
    Returns (is_valid, reason)
    
    Strict mode: requires ≥2 ingredients AND ≥2 instructions (original behavior)
    Relaxed mode: accepts ≥2 ingredients OR ≥2 instructions, or ≥1 ingredient AND ≥1 instruction
    """
    ingredients_count = len(result.get('ingredients', []))
    instructions_count = len(result.get('instructions', []))
    
    if strict:
        # Original strict validation
        if ingredients_count >= 2 and instructions_count >= 2:
            return True, f"{tier_name} success - {ingredients_count} ingredients, {instructions_count} instructions"
        else:
            return False, f"{tier_name} insufficient - {ingredients_count} ingredients, {instructions_count} instructions"
    else:
        # Relaxed validation: accept partial data
        if ingredients_count >= 2 and instructions_count >= 2:
            return True, f"{tier_name} success (full) - {ingredients_count} ingredients, {instructions_count} instructions"
        elif ingredients_count >= 2 or instructions_count >= 2:
            # At least one component has good data
            return True, f"{tier_name} success (partial) - {ingredients_count} ingredients, {instructions_count} instructions"
        elif ingredients_count >= 1 and instructions_count >= 1:
            # Minimum viable recipe
            return True, f"{tier_name} success (minimal) - {ingredients_count} ingredients, {instructions_count} instructions"
        else:
            return False, f"{tier_name} insufficient - {ingredients_count} ingredients, {instructions_count} instructions"

def extract_youtube_recipe(video_id: str, video_url: str) -> Dict[str, Any]:
    """Main YouTube recipe extraction with 3-tier fallback"""
    print(f"LAMBDA/YOUTUBE: Starting extraction for video_id={video_id}")
    
    # Track tier failures for better error messages
    tier_failures = []
    
    # Fetch video metadata
    metadata = fetch_youtube_metadata(video_id)
    title = metadata['title']
    description = metadata['description']
    thumbnail_url = metadata['thumbnail_url']
    author = metadata.get('author', '')
    author_url = metadata.get('author_url', '')
    
    print(f"LAMBDA/YOUTUBE: Title={title}, Description length={len(description)}, Author={author}")
    
    # Tier 1: Try deterministic parsing
    try:
        print("LAMBDA/YOUTUBE: Tier 1 - Deterministic parsing")
        result = parse_youtube_recipe_deterministic(title, description)
        
        # Validate Tier 1 result (strict - deterministic parsing should be high quality)
        is_valid, reason = validate_youtube_result(result, "Tier 1", strict=True)
        print(f"LAMBDA/YOUTUBE: {reason}")
        
        if is_valid:
            result['image'] = thumbnail_url
            result['source_url'] = video_url
            result['site_link'] = video_url
            result['site_name'] = 'YouTube'
            result['author'] = author
            result['author_url'] = author_url
            result['metadata'] = {'tier_used': 'youtube_deterministic'}
            return result
        else:
            tier_failures.append(f"Tier 1: {reason}")
    except Exception as e:
        error_msg = f"Tier 1 error: {str(e)}"
        print(f"LAMBDA/YOUTUBE: {error_msg}")
        tier_failures.append(error_msg)
    
    # Tier 2: Try AI description parsing (OpenAI GPT-4)
    tier2_result = None
    try:
        print("LAMBDA/YOUTUBE: Tier 2 - OpenAI GPT-4 description parsing")
        openai_key = os.environ.get('OPENAI_API_KEY')
        if not openai_key:
            tier_failures.append("Tier 2: OPENAI_API_KEY not set")
            print("LAMBDA/YOUTUBE: Tier 2 skipped - OPENAI_API_KEY not set")
        elif description and len(description.strip()) > 50:
            result = parse_youtube_recipe_ai_description(title, description, thumbnail_url)
            tier2_result = result  # Save for potential fallback
            
            # Validate Tier 2 result (relaxed - accept partial data)
            is_valid, reason = validate_youtube_result(result, "Tier 2", strict=False)
            print(f"LAMBDA/YOUTUBE: {reason}")
            
            # Check if instructions are missing - try Tier 2.5 generation first
            ingredients = result.get('ingredients', [])
            instructions = result.get('instructions', [])
            has_missing_instructions = len(ingredients) >= 2 and len(instructions) < 2
            
            if is_valid and not has_missing_instructions:
                # Tier 2 succeeded with full data (has instructions) - return immediately
                result['source_url'] = video_url
                result['site_link'] = video_url
                result['site_name'] = 'YouTube'
                result['author'] = author
                result['author_url'] = author_url
                result['metadata'] = {'tier_used': 'youtube_openai_description'}
                # Lower quality score if partial data
                if "partial" in reason or "minimal" in reason:
                    result['quality_score'] = result.get('quality_score', 0.5) * 0.7
                return result
            elif is_valid and has_missing_instructions:
                # Tier 2 succeeded but instructions missing - try Tier 2.5 generation
                print("LAMBDA/YOUTUBE: Tier 2 succeeded but instructions missing - trying Tier 2.5 generation")
                try:
                    generated_instructions = generate_instructions_from_ingredients(title, ingredients)
                    if generated_instructions and len(generated_instructions) >= 3:
                        print(f"LAMBDA/YOUTUBE: Tier 2.5 generated {len(generated_instructions)} instructions")
                        result['instructions'] = generated_instructions
                        result['metadata'] = {'tier_used': 'youtube_openai_description_enhanced', 'ai_enhanced': True}
                        result['source_url'] = video_url
                        result['site_link'] = video_url
                        result['site_name'] = 'YouTube'
                        result['author'] = author
                        result['author_url'] = author_url
                        # Improve quality score since we now have instructions
                        result['quality_score'] = result.get('quality_score', 0.5) * 1.1
                        return result
                    else:
                        print("LAMBDA/YOUTUBE: Tier 2.5 failed to generate sufficient instructions - continuing to Tier 3/4")
                        # Fall through to Tier 3/4
                except Exception as e:
                    print(f"LAMBDA/YOUTUBE: Tier 2.5 error={str(e)} - continuing to Tier 3/4")
                    # Fall through to Tier 3/4
            else:
                tier_failures.append(f"Tier 2: {reason}")
        else:
            desc_len = len(description.strip()) if description else 0
            tier_failures.append(f"Tier 2: description too short ({desc_len} chars)")
            print("LAMBDA/YOUTUBE: Tier 2 skipped - description too short or empty")
    except Exception as e:
        error_msg = f"Tier 2 error: {str(e)}"
        print(f"LAMBDA/YOUTUBE: {error_msg}")
        tier_failures.append(error_msg)
    
    # Tier 2.6: If Tier 2 extracted 0 ingredients or failed completely, try generating from title
    # This handles cases where description doesn't contain recipe data
    tier2_had_ingredients = tier2_result and len(tier2_result.get('ingredients', [])) > 0
    if not tier2_had_ingredients:
        print("LAMBDA/YOUTUBE: Tier 2 extracted 0 ingredients or failed - trying Tier 2.6 title-based generation")
        try:
            title_result = generate_recipe_from_title(title)
            if title_result and len(title_result.get('ingredients', [])) >= 3 and len(title_result.get('instructions', [])) >= 3:
                print(f"LAMBDA/YOUTUBE: Tier 2.6 generated recipe: {len(title_result.get('ingredients', []))} ingredients, {len(title_result.get('instructions', []))} instructions")
                title_result['image'] = thumbnail_url
                title_result['source_url'] = video_url
                title_result['site_link'] = video_url
                title_result['site_name'] = 'YouTube'
                title_result['author'] = author
                title_result['author_url'] = author_url
                title_result['metadata'] = {'tier_used': 'youtube_title_based_generation', 'ai_enhanced': True}
                title_result['quality_score'] = 0.7  # Good quality for title-based generation
                return title_result
            else:
                print("LAMBDA/YOUTUBE: Tier 2.6 failed to generate sufficient recipe data - continuing to Tier 3")
        except Exception as e:
            print(f"LAMBDA/YOUTUBE: Tier 2.6 error={str(e)} - continuing to Tier 3")
    
    # Tier 3: Try AI transcript parsing (OpenAI GPT-4)
    tier3_result = None
    transcript = None  # Store transcript for Tier 4 if needed
    try:
        print("LAMBDA/YOUTUBE: Tier 3 - OpenAI GPT-4 transcript parsing")
        openai_key = os.environ.get('OPENAI_API_KEY')
        if not openai_key:
            tier_failures.append("Tier 3: OPENAI_API_KEY not set")
            print("LAMBDA/YOUTUBE: Tier 3 skipped - OPENAI_API_KEY not set")
        else:
            transcript = fetch_youtube_transcript(video_id)
            
            if transcript and len(transcript.strip()) > 100:
                result = parse_youtube_recipe_ai_transcript(title, transcript, thumbnail_url)
                tier3_result = result  # Save for potential fallback
                
                # Validate Tier 3 result (relaxed - accept partial data)
                is_valid, reason = validate_youtube_result(result, "Tier 3", strict=False)
                print(f"LAMBDA/YOUTUBE: {reason}")
                
                if is_valid:
                    # Tier 4: If instructions are missing or insufficient, generate them
                    ingredients = result.get('ingredients', [])
                    instructions = result.get('instructions', [])
                    if len(ingredients) >= 2 and len(instructions) < 2:
                        print("LAMBDA/YOUTUBE: Tier 3 succeeded but instructions missing - trying Tier 4")
                        generated_instructions = generate_instructions_from_transcript(title, transcript, ingredients)
                        if generated_instructions and len(generated_instructions) >= 2:
                            print(f"LAMBDA/YOUTUBE: Tier 4 generated {len(generated_instructions)} instructions")
                            result['instructions'] = generated_instructions
                            result['metadata'] = {'tier_used': 'youtube_openai_transcript_tier4_enhanced', 'ai_enhanced': True}
                            # Improve quality score since we now have instructions
                            result['quality_score'] = result.get('quality_score', 0.5) * 1.2  # Boost quality
                    
                    result['source_url'] = video_url
                    result['site_link'] = video_url
                    result['site_name'] = 'YouTube'
                    result['author'] = author
                    result['author_url'] = author_url
                    if 'metadata' not in result:
                        result['metadata'] = {'tier_used': 'youtube_openai_transcript'}
                    # Lower quality score if partial data (but not if Tier 4 enhanced it)
                    if "partial" in reason or "minimal" in reason:
                        if 'quality_score' not in result:
                            result['quality_score'] = result.get('quality_score', 0.5) * 0.7  # Reduce quality for partial data
                    return result
                else:
                    tier_failures.append(f"Tier 3: {reason}")
            else:
                transcript_len = len(transcript.strip()) if transcript else 0
                tier_failures.append(f"Tier 3: transcript unavailable or too short ({transcript_len} chars)")
                print("LAMBDA/YOUTUBE: Tier 3 skipped - transcript empty or too short")
    except Exception as e:
        error_msg = f"Tier 3 error: {str(e)}"
        print(f"LAMBDA/YOUTUBE: {error_msg}")
        tier_failures.append(error_msg)
    
    # Hybrid merging: Combine Tier 2 ingredients + Tier 3 instructions (or vice versa)
    hybrid_result = None
    if tier2_result and tier3_result:
        tier2_ing = len(tier2_result.get('ingredients', []))
        tier2_inst = len(tier2_result.get('instructions', []))
        tier3_ing = len(tier3_result.get('ingredients', []))
        tier3_inst = len(tier3_result.get('instructions', []))
        
        # Case 1: Tier 2 has ingredients but no instructions, Tier 3 has instructions
        if tier2_ing >= 2 and tier2_inst == 0 and tier3_inst >= 2:
            print(f"LAMBDA/YOUTUBE: Hybrid merge - Tier 2 ingredients ({tier2_ing}) + Tier 3 instructions ({tier3_inst})")
            hybrid_result = {
                'title': tier2_result.get('title', title),
                'ingredients': tier2_result.get('ingredients', []),
                'instructions': tier3_result.get('instructions', []),
                'servings': tier2_result.get('servings') or tier3_result.get('servings'),
                'image': thumbnail_url,
                'source_url': video_url,
                'site_link': video_url,
                'site_name': 'YouTube',
                'metadata': {'tier_used': 'youtube_hybrid_t2_ing_t3_inst'}
            }
        # Case 2: Tier 3 has ingredients but no instructions, Tier 2 has instructions
        elif tier3_ing >= 2 and tier3_inst == 0 and tier2_inst >= 2:
            print(f"LAMBDA/YOUTUBE: Hybrid merge - Tier 3 ingredients ({tier3_ing}) + Tier 2 instructions ({tier2_inst})")
            hybrid_result = {
                'title': tier3_result.get('title', title),
                'ingredients': tier3_result.get('ingredients', []),
                'instructions': tier2_result.get('instructions', []),
                'servings': tier3_result.get('servings') or tier2_result.get('servings'),
                'image': thumbnail_url,
                'source_url': video_url,
                'site_link': video_url,
                'site_name': 'YouTube',
                'metadata': {'tier_used': 'youtube_hybrid_t3_ing_t2_inst'}
            }
        # Case 3: Both have partial data - merge best of each
        elif (tier2_ing >= 1 or tier2_inst >= 1) and (tier3_ing >= 1 or tier3_inst >= 1):
            # Use the tier with more ingredients for ingredients, more instructions for instructions
            best_ingredients = tier2_result.get('ingredients', []) if tier2_ing >= tier3_ing else tier3_result.get('ingredients', [])
            best_instructions = tier2_result.get('instructions', []) if tier2_inst >= tier3_inst else tier3_result.get('instructions', [])
            
            if len(best_ingredients) >= 2 and len(best_instructions) >= 2:
                print(f"LAMBDA/YOUTUBE: Hybrid merge - Best ingredients ({len(best_ingredients)}) + Best instructions ({len(best_instructions)})")
                hybrid_result = {
                    'title': tier2_result.get('title', tier3_result.get('title', title)),
                    'ingredients': best_ingredients,
                    'instructions': best_instructions,
                    'servings': tier2_result.get('servings') or tier3_result.get('servings'),
                    'image': thumbnail_url,
                    'source_url': video_url,
                    'site_link': video_url,
                    'site_name': 'YouTube',
                    'metadata': {'tier_used': 'youtube_hybrid_best'}
                }
    
    if hybrid_result:
        hybrid_result['quality_score'] = 0.75  # Good quality for hybrid (combines best of both)
        return hybrid_result
    
    # Final fallback: If Tier 2 or Tier 3 had partial data, use it anyway
    best_result = None
    best_tier = None
    
    if tier2_result:
        ing_count = len(tier2_result.get('ingredients', []))
        inst_count = len(tier2_result.get('instructions', []))
        if ing_count >= 1 or inst_count >= 1:
            best_result = tier2_result
            best_tier = "Tier 2 (fallback)"
    
    if tier3_result and (not best_result or 
                        len(tier3_result.get('ingredients', [])) + len(tier3_result.get('instructions', [])) >
                        len(best_result.get('ingredients', [])) + len(best_result.get('instructions', []))):
        ing_count = len(tier3_result.get('ingredients', []))
        inst_count = len(tier3_result.get('instructions', []))
        if ing_count >= 1 or inst_count >= 1:
            best_result = tier3_result
            best_tier = "Tier 3 (fallback)"
    
    # Tier 4: Generate instructions if missing but we have ingredients and transcript
    if best_result:
        ingredients = best_result.get('ingredients', [])
        instructions = best_result.get('instructions', [])
        
        # If we have ingredients but missing/insufficient instructions, try Tier 4
        if len(ingredients) >= 2 and len(instructions) < 2:
            print("LAMBDA/YOUTUBE: Tier 4 - Generating instructions from transcript (instructions missing)")
            try:
                # Use transcript from Tier 3 if available, otherwise fetch it
                if not transcript or len(transcript.strip()) < 100:
                    print("LAMBDA/YOUTUBE: Tier 4 - Fetching transcript")
                    transcript = fetch_youtube_transcript(video_id)
                
                if transcript and len(transcript.strip()) >= 100:
                    generated_instructions = generate_instructions_from_transcript(title, transcript, ingredients)
                    if generated_instructions and len(generated_instructions) >= 2:
                        print(f"LAMBDA/YOUTUBE: Tier 4 successfully generated {len(generated_instructions)} instructions")
                        best_result['instructions'] = generated_instructions
                        best_tier = f"{best_tier} + Tier 4 (instruction generation)"
                        # Mark as AI-enhanced
                        if 'metadata' not in best_result:
                            best_result['metadata'] = {}
                        best_result['metadata']['ai_enhanced'] = True
                        # Improve quality score since we now have instructions
                        if best_result.get('quality_score', 0) < 0.5:
                            best_result['quality_score'] = 0.6
                    else:
                        print("LAMBDA/YOUTUBE: Tier 4 failed to generate sufficient instructions")
                else:
                    print("LAMBDA/YOUTUBE: Tier 4 skipped - transcript unavailable")
            except Exception as e:
                print(f"LAMBDA/YOUTUBE: Tier 4 error={str(e)}")
                # Continue with best_result even if Tier 4 fails
    
    if best_result:
        print(f"LAMBDA/YOUTUBE: Using {best_tier} with partial data")
        best_result['source_url'] = video_url
        best_result['site_link'] = video_url
        best_result['site_name'] = 'YouTube'
        best_result['author'] = author
        best_result['author_url'] = author_url
        best_result['metadata'] = {'tier_used': best_tier.lower().replace(' ', '_').replace('+', '_plus')}
        if 'quality_score' not in best_result:
            best_result['quality_score'] = 0.3  # Very low quality score for minimal data
        return best_result
    
    # All tiers failed - provide detailed error message
    error_details = []
    if not description or len(description.strip()) < 50:
        error_details.append(f"description_too_short({len(description) if description else 0} chars)")
    openai_key = os.environ.get('OPENAI_API_KEY')
    if not openai_key:
        error_details.append("OPENAI_API_KEY_not_set")
    
    error_msg = f"Failed to extract recipe from YouTube video - all 3 tiers failed"
    if tier_failures:
        error_msg += f" (failures: {'; '.join(tier_failures)})"
    elif error_details:
        error_msg += f" (issues: {', '.join(error_details)})"
    else:
        error_msg += " (video may not contain a recipe)"
    raise Exception(error_msg)

def extract_tiktok_recipe(video_id: str, video_url: str) -> Dict[str, Any]:
    """Main TikTok recipe extraction with multi-tier fallback (reuses YouTube tier system)"""
    print(f"LAMBDA/TIKTOK: Starting extraction for video_id={video_id}, url={video_url}")
    
    # Track tier failures for better error messages
    tier_failures = []
    
    # Fetch video metadata via Apify
    # Note: Apify accepts full TikTok URLs, so we pass video_url directly
    try:
        metadata = fetch_tiktok_metadata(video_id, video_url)
        title = metadata['title']
        description = metadata.get('description', '') or metadata.get('text', '')
        thumbnail_url = metadata.get('thumbnail_url', '')
        author = metadata.get('author', 'Unknown')
        author_url = metadata.get('author_url', '')
        
        print(f"LAMBDA/TIKTOK: Title={title}, Description length={len(description)}, Author={author}")
    except Exception as e:
        error_msg = f"Failed to fetch TikTok metadata: {str(e)}"
        print(f"LAMBDA/TIKTOK: {error_msg}")
        tier_failures.append(error_msg)
        
        # Fallback: try title-only generation
        print("LAMBDA/TIKTOK: Attempting title-only generation as fallback")
        try:
            fallback_title = f"TikTok Recipe {video_id}"
            result = generate_recipe_from_title(fallback_title)
            if result and len(result.get('ingredients', [])) >= 3:
                result['image'] = ''
                result['source_url'] = video_url
                result['site_link'] = video_url
                result['site_name'] = 'TikTok'
                result['author'] = 'Unknown'  # No author available in fallback
                result['author_url'] = ''  # No author URL available in fallback
                result['metadata'] = {'tier_used': 'tiktok_title_fallback', 'ai_enhanced': True}
                result['quality_score'] = 0.5
                return result
        except Exception as fallback_error:
            print(f"LAMBDA/TIKTOK: Title fallback also failed: {str(fallback_error)}")
        
        raise Exception(f"Failed to extract TikTok recipe - {error_msg}")
    
    # Tier 1: Try deterministic parsing (reuse YouTube function)
    try:
        print("LAMBDA/TIKTOK: Tier 1 - Deterministic parsing")
        result = parse_youtube_recipe_deterministic(title, description)
        
        # Validate Tier 1 result (strict - deterministic parsing should be high quality)
        is_valid, reason = validate_youtube_result(result, "Tier 1", strict=True)
        print(f"LAMBDA/TIKTOK: {reason}")
        
        if is_valid:
            result['image'] = thumbnail_url
            result['source_url'] = video_url
            result['site_link'] = video_url
            result['site_name'] = 'TikTok'
            result['author'] = author
            result['author_url'] = author_url
            result['metadata'] = {'tier_used': 'tiktok_deterministic'}
            return result
        else:
            tier_failures.append(f"Tier 1: {reason}")
    except Exception as e:
        error_msg = f"Tier 1 error: {str(e)}"
        print(f"LAMBDA/TIKTOK: {error_msg}")
        tier_failures.append(error_msg)
    
    # Tier 2: Try AI description parsing (reuse YouTube function)
    tier2_result = None
    try:
        print("LAMBDA/TIKTOK: Tier 2 - OpenAI GPT-4 description parsing")
        openai_key = os.environ.get('OPENAI_API_KEY')
        if not openai_key:
            tier_failures.append("Tier 2: OPENAI_API_KEY not set")
            print("LAMBDA/TIKTOK: Tier 2 skipped - OPENAI_API_KEY not set")
        elif description and len(description.strip()) > 50:
            result = parse_youtube_recipe_ai_description(title, description, thumbnail_url)
            tier2_result = result  # Save for potential fallback
            
            # Validate Tier 2 result (relaxed - accept partial data)
            is_valid, reason = validate_youtube_result(result, "Tier 2", strict=False)
            print(f"LAMBDA/TIKTOK: {reason}")
            
            # Check if instructions are missing - try Tier 2.5 generation first
            ingredients = result.get('ingredients', [])
            instructions = result.get('instructions', [])
            has_missing_instructions = len(ingredients) >= 2 and len(instructions) < 2
            
            if is_valid and not has_missing_instructions:
                # Tier 2 succeeded with full data (has instructions) - return immediately
                result['source_url'] = video_url
                result['site_link'] = video_url
                result['site_name'] = 'TikTok'
                result['author'] = author
                result['author_url'] = author_url
                result['metadata'] = {'tier_used': 'tiktok_openai_description'}
                # Lower quality score if partial data
                if "partial" in reason or "minimal" in reason:
                    result['quality_score'] = result.get('quality_score', 0.5) * 0.7
                return result
            elif is_valid and has_missing_instructions:
                # Tier 2 succeeded but instructions missing - try Tier 2.5 generation
                print("LAMBDA/TIKTOK: Tier 2 succeeded but instructions missing - trying Tier 2.5 generation")
                try:
                    generated_instructions = generate_instructions_from_ingredients(title, ingredients)
                    if generated_instructions and len(generated_instructions) >= 3:
                        print(f"LAMBDA/TIKTOK: Tier 2.5 generated {len(generated_instructions)} instructions")
                        result['instructions'] = generated_instructions
                        result['metadata'] = {'tier_used': 'tiktok_openai_description_enhanced', 'ai_enhanced': True}
                        result['source_url'] = video_url
                        result['site_link'] = video_url
                        result['site_name'] = 'TikTok'
                        result['author'] = author
                        result['author_url'] = author_url
                        # Improve quality score since we now have instructions
                        result['quality_score'] = result.get('quality_score', 0.5) * 1.1
                        return result
                    else:
                        print("LAMBDA/TIKTOK: Tier 2.5 failed to generate sufficient instructions - continuing to Tier 2.6")
                        # Fall through to Tier 2.6
                except Exception as e:
                    print(f"LAMBDA/TIKTOK: Tier 2.5 error={str(e)} - continuing to Tier 2.6")
                    # Fall through to Tier 2.6
            else:
                tier_failures.append(f"Tier 2: {reason}")
        else:
            desc_len = len(description.strip()) if description else 0
            tier_failures.append(f"Tier 2: description too short ({desc_len} chars)")
            print("LAMBDA/TIKTOK: Tier 2 skipped - description too short or empty")
    except Exception as e:
        error_msg = f"Tier 2 error: {str(e)}"
        print(f"LAMBDA/TIKTOK: {error_msg}")
        tier_failures.append(error_msg)
    
    # Tier 2.6: If Tier 2 extracted 0 ingredients or failed completely, try generating from title
    tier2_had_ingredients = tier2_result and len(tier2_result.get('ingredients', [])) > 0
    if not tier2_had_ingredients:
        print("LAMBDA/TIKTOK: Tier 2 extracted 0 ingredients or failed - trying Tier 2.6 title-based generation")
        try:
            title_result = generate_recipe_from_title(title)
            if title_result and len(title_result.get('ingredients', [])) >= 3 and len(title_result.get('instructions', [])) >= 3:
                print(f"LAMBDA/TIKTOK: Tier 2.6 generated recipe: {len(title_result.get('ingredients', []))} ingredients, {len(title_result.get('instructions', []))} instructions")
                title_result['image'] = thumbnail_url
                title_result['source_url'] = video_url
                title_result['site_link'] = video_url
                title_result['site_name'] = 'TikTok'
                title_result['author'] = author
                title_result['author_url'] = author_url
                title_result['metadata'] = {'tier_used': 'tiktok_title_based_generation', 'ai_enhanced': True}
                title_result['quality_score'] = 0.7  # Good quality for title-based generation
                return title_result
            else:
                print("LAMBDA/TIKTOK: Tier 2.6 failed to generate sufficient recipe data")
        except Exception as e:
            print(f"LAMBDA/TIKTOK: Tier 2.6 error={str(e)}")
    
    # Final fallback: If Tier 2 or Tier 2.6 had partial data, use it anyway
    best_result = None
    best_tier = None
    
    if tier2_result:
        ing_count = len(tier2_result.get('ingredients', []))
        inst_count = len(tier2_result.get('instructions', []))
        if ing_count >= 1 or inst_count >= 1:
            best_result = tier2_result
            best_tier = "Tier 2 (fallback)"
    
    if best_result:
        print(f"LAMBDA/TIKTOK: Using {best_tier} with partial data")
        best_result['source_url'] = video_url
        best_result['site_link'] = video_url
        best_result['site_name'] = 'TikTok'
        best_result['author'] = author
        best_result['author_url'] = author_url
        best_result['metadata'] = {'tier_used': best_tier.lower().replace(' ', '_').replace('+', '_plus')}
        if 'quality_score' not in best_result:
            best_result['quality_score'] = 0.3  # Very low quality score for minimal data
        return best_result
    
    # All tiers failed - provide detailed error message
    error_details = []
    if not description or len(description.strip()) < 50:
        error_details.append(f"description_too_short({len(description) if description else 0} chars)")
    openai_key = os.environ.get('OPENAI_API_KEY')
    if not openai_key:
        error_details.append("OPENAI_API_KEY_not_set")
    
    error_msg = f"Failed to extract recipe from TikTok video - all tiers failed"
    if tier_failures:
        error_msg += f" (failures: {'; '.join(tier_failures)})"
    elif error_details:
        error_msg += f" (issues: {', '.join(error_details)})"
    else:
        error_msg += " (video may not contain a recipe)"
    raise Exception(error_msg)

def is_bot_wall(content_or_title: str) -> bool:
    """Detect bot/anti-scrape pages"""
    if not isinstance(content_or_title, str):
        return False
    content_lower = content_or_title.lower()
    bot_phrases = [
        "please verify you are a human",
        "are you a robot", 
        "cloudflare",
        "attention required",
        "blocked",
        "access denied"
    ]
    return any(phrase in content_lower for phrase in bot_phrases)

def sanitize_title(title: str, url: str) -> str:
    """Sanitize and derive title from URL if needed"""
    if not title or is_bot_wall(title):
        # Derive from URL slug
        from urllib.parse import urlparse
        parsed = urlparse(url)
        path_parts = [p for p in parsed.path.split('/') if p and p != 'recipe']
        if path_parts:
            # Take last meaningful part, humanize it
            slug = path_parts[-1].replace('-', ' ').replace('_', ' ').title()
            return slug[:200]  # Limit length
        return "Recipe"
    
    # Clean existing title
    title = title.strip()
    
    # Remove site suffixes
    site_suffixes = ['| the kitchn', '- allrecipes', '| food network', '| bon appétit']
    for suffix in site_suffixes:
        if title.lower().endswith(suffix):
            title = title[:-len(suffix)].strip()
    
    # Remove emojis and extra whitespace
    import re
    title = re.sub(r'[^\w\s\-.,!?]', '', title)
    title = re.sub(r'\s+', ' ', title).strip()
    
    return title[:200] if title else "Recipe"

def clamp_quality_score(recipe_data: dict, base_score: float) -> float:
    """Apply realistic quality score clamping"""
    score = float(base_score or 0.0)
    
    # Bot wall detection
    title = recipe_data.get('title', '')
    if is_bot_wall(title):
        score = min(score, 0.40)
        print(f"LAMBDA/SCORE: clamped from={base_score:.2f} to={score:.2f} reason=bot_wall")
    
    # Insufficient instructions
    instructions = recipe_data.get('instructions', [])
    if len(instructions) < 3 or any('instructions not available' in step.lower() for step in instructions):
        score = min(score, 0.40)
        print(f"LAMBDA/SCORE: clamped from={base_score:.2f} to={score:.2f} reason=insufficient_instructions")
    
    # Insufficient ingredients
    ingredients = recipe_data.get('ingredients', [])
    if len(ingredients) < 3:
        score = min(score, 0.50)
        print(f"LAMBDA/SCORE: clamped from={base_score:.2f} to={score:.2f} reason=insufficient_ingredients")
    
    # Image quality check (basic)
    image = recipe_data.get('image', '')
    if not image or any(logo in image.lower() for logo in ['logo', 'favicon', 'placeholder']):
        score = max(0, score - 0.15)
        print(f"LAMBDA/SCORE: penalized from={base_score:.2f} to={score:.2f} reason=poor_image")
    
    return max(0.0, min(1.0, score))

def _ensure_site_link_and_name(recipe_data, url):
    """Ensure site_link and site_name are set in recipe_data"""
    if not recipe_data.get("site_link"):
        recipe_data["site_link"] = url
    
    if not recipe_data.get("site_name"):
        # Extract domain from URL
        from urllib.parse import urlparse
        parsed = urlparse(url)
        recipe_data["site_name"] = parsed.netloc or "Unknown Site"

def finalize_response(recipe_data, url):
    """Finalize recipe data with cleanup, normalization, and HTTP response formatting"""
    print("FINALIZE_RESPONSE ENTRY MARKER - FUNCTION CALLED")
    import re, html as _html
    
    # Compile regex once for efficiency
    LIST_PREFIX = re.compile(r'^\s*(?:\d+\s*[\.\)]\s*|[-–—•●*·]\s+)', re.UNICODE)
    
    def _normalize_text(s: str) -> str:
        """Normalize text and strip list markers, bullets, & extra spaces."""
        if not isinstance(s, str):
            return ""
        # HTML entities and nbsp
        s = _html.unescape(s).replace("\xa0", " ")  # &nbsp; → space
        # Remove hidden/odd characters
        s = (s.replace("\u200b", "")    # zero‑width space
               .replace("\ufeff", "")     # BOM
               .replace("\uFFFD", ""))    # replacement char
        # Common unicode punctuation → ASCII
        s = (s.replace("–", "-").replace("—", "-")
               .replace("'", "'").replace(""", '"').replace(""", '"')
               .replace("•", "").replace("●", "").replace("·", ""))
        # Normalize fraction slash
        s = s.replace('⁄', '/')
        # Strip checkbox/square-like symbols
        s = re.sub(r'[\u25A0-\u25FF\u2610\u2611\u274F\u2751\u2752]', '', s)
        s = s.strip()
        # Remove leading list markers using compiled regex
        s = LIST_PREFIX.sub("", s)
        # Collapse multiple spaces
        s = re.sub(r"\s{2,}", " ", s)
        return s.strip()
    
    def _normalize_ingredient_quantity(ingredient: str) -> str:
        """Add '1' before unit words if quantity is missing.
        
        Examples:
            'cup of flour' -> '1 cup of flour'
            'teaspoon salt' -> '1 teaspoon salt'
            'tablespoon oil' -> '1 tablespoon oil'
            '2 cups sugar' -> '2 cups sugar' (no change)
            '1/2 cup milk' -> '1/2 cup milk' (no change)
        """
        ingredient_clean = ingredient.strip()
        if not ingredient_clean or len(ingredient_clean) < 3:
            return ingredient
        
        ingredient_lower = ingredient_clean.lower()
        
        # Check if it starts with a number or fraction (don't modify)
        # This regex checks for: digits, fractions (1/2), or decimals (1.5) at the start
        # Also check for Unicode fractions (¾, ½, ¼) and common fraction words
        number_pattern = r'^(\d+|\d+/\d+|\d+\.\d+|¾|½|¼|⅓|⅔|⅛|⅜|⅝|⅞)\s+'
        if re.match(number_pattern, ingredient_lower):
            # Debug: log Unicode fractions to verify they're being detected
            if any(frac in ingredient_clean for frac in ['¾', '½', '¼', '⅓', '⅔', '⅛', '⅜', '⅝', '⅞']):
                print(f"LAMBDA/NORM: Skipping '{ingredient_clean}' - has Unicode fraction")
            return ingredient_clean
        
        # After the number check, check if first word is a unit word
        first_word = ingredient_lower.split()[0] if ingredient_lower.split() else ""
        
        unit_words_needing_one = {
            'cup', 'cups',
            'teaspoon', 'teaspoons', 'tsp',
            'tablespoon', 'tablespoons', 'tbsp',
            'pound', 'pounds', 'lb', 'lbs',
            'ounce', 'ounces', 'oz',
            'pint', 'pints', 'pt',
            'quart', 'quarts', 'qt',
            'gallon', 'gallons', 'gal',
            'pinch', 'dash', 'handful',
            'slice', 'slices',
            'piece', 'pieces',
            'clove', 'cloves',
            'sprig', 'sprigs',
            'bunch', 'bunches',
            'can', 'cans',
            'package', 'packages', 'pkg',
            'jar', 'jars',
            'bottle', 'bottles',
            'head', 'heads',
            'stalk', 'stalks',
            'stick', 'sticks'
        }
        
        if first_word in unit_words_needing_one:
            normalized = "1 " + ingredient_clean
            print(f"LAMBDA/NORM: Added '1' to '{ingredient_clean}' -> '{normalized}'")
            return normalized
        
        return ingredient_clean
    
    # Clean ingredients
    if isinstance(recipe_data.get("ingredients"), list):
        _seen = set()
        cleaned_ing = []
        print(f"LAMBDA/NORM: Processing {len(recipe_data['ingredients'])} ingredients")
        for it in recipe_data["ingredients"]:
            original = it
            c = _normalize_text(it)
            print(f"LAMBDA/NORM: Original='{original[:50]}' -> After normalize_text='{c[:50]}'")
            # Normalize quantities (add "1" before units if missing)
            c = _normalize_ingredient_quantity(c)
            if len(c) > 2 and c.lower() not in _seen:
                cleaned_ing.append(c)
                _seen.add(c.lower())
        print(f"LAMBDA/NORM: Final ingredients count: {len(cleaned_ing)}")
        recipe_data["ingredients"] = cleaned_ing
    
    # STEP 4: Normalize ingredient sections (print pages only)
    if isinstance(recipe_data.get("ingredient_sections"), list):
        normalized_sections = []
        for section in recipe_data["ingredient_sections"]:
            if isinstance(section, dict) and 'name' in section and 'ingredients' in section:
                normalized_ingredients = []
                _seen_section = set()
                for ingredient_text in section['ingredients']:
                    c = _normalize_text(ingredient_text)
                    c = _normalize_ingredient_quantity(c)
                    if len(c) > 2 and c.lower() not in _seen_section:
                        normalized_ingredients.append(c)
                        _seen_section.add(c.lower())
                
                if len(normalized_ingredients) >= 2:  # Section must have at least 2 ingredients
                    normalized_sections.append({
                        'name': section['name'].strip(),
                        'ingredients': normalized_ingredients
                    })
        
        if normalized_sections:
            recipe_data["ingredient_sections"] = normalized_sections
            print(f"LAMBDA/NORM: Normalized {len(normalized_sections)} ingredient sections")
        else:
            # Remove if no valid sections after normalization
            recipe_data.pop("ingredient_sections", None)
    
    # STEP 5: Normalize instruction groups (print pages only)
    if isinstance(recipe_data.get("instruction_groups"), list):
        normalized_groups = []
        for group in recipe_data["instruction_groups"]:
            if isinstance(group, dict) and 'label' in group and 'steps' in group:
                normalized_steps = []
                _seen_steps_group = set()
                for step_text in group['steps']:
                    c = _normalize_text(step_text)
                    if len(c) > 5:
                        normalized_step = c.lower().strip()
                        # Deduplicate within group
                        if normalized_step not in _seen_steps_group:
                            normalized_steps.append(c)
                            _seen_steps_group.add(normalized_step)
                
                if len(normalized_steps) >= 1:  # Group must have at least 1 step
                    normalized_groups.append({
                        'label': group['label'].strip(),
                        'steps': normalized_steps
                    })
        
        if normalized_groups:
            recipe_data["instruction_groups"] = normalized_groups
            print(f"LAMBDA/NORM: Normalized {len(normalized_groups)} instruction groups")
        else:
            # Remove if no valid groups after normalization
            recipe_data.pop("instruction_groups", None)
    
    # STEP 6: Normalize recipe notes (print pages only)
    if recipe_data.get("recipe_notes"):
        notes_text = _normalize_text(recipe_data["recipe_notes"])
        if len(notes_text) > 10:  # Must have substantial content
            recipe_data["recipe_notes"] = notes_text
            print(f"LAMBDA/NORM: Normalized recipe notes (length: {len(notes_text)})")
        else:
            recipe_data.pop("recipe_notes", None)
    
    # Clean instructions with improved deduplication
    if isinstance(recipe_data.get("instructions"), list):
        _seen_steps = set()
        cleaned_steps = []
        for step in recipe_data["instructions"]:
            c = _normalize_text(step)
            if len(c) > 5:
                # Normalize for comparison (remove leading numbers, normalize whitespace)
                normalized = c.lower().strip()
                normalized = re.sub(r'^\d+[\.\)]\s*', '', normalized)  # Remove leading numbers
                normalized = re.sub(r'\s+', ' ', normalized).strip()  # Normalize whitespace
                normalized = re.sub(r'[.,;:!?]+$', '', normalized)  # Remove trailing punctuation for comparison
                
                # Check for exact duplicates first (most strict check)
                is_duplicate = False
                if normalized in _seen_steps:
                    is_duplicate = True
                    print(f"LAMBDA/DEDUP: Found exact duplicate instruction: {normalized[:50]}...")
                else:
                    # Then check for near-duplicates (similarity check) - existing logic
                    for seen in _seen_steps:
                        # Check if normalized text is very similar (accounting for minor variations)
                        if normalized == seen or (len(normalized) > 20 and normalized in seen) or (len(seen) > 20 and seen in normalized):
                            is_duplicate = True
                            print(f"LAMBDA/DEDUP: Found near-duplicate instruction: {normalized[:50]}...")
                            break
                        # Additional check: if they're very similar length and mostly the same
                        if abs(len(normalized) - len(seen)) < 10 and len(normalized) > 15:
                            # Check character similarity (simple ratio)
                            common_chars = sum(1 for a, b in zip(normalized, seen) if a == b)
                            similarity = common_chars / max(len(normalized), len(seen)) if max(len(normalized), len(seen)) > 0 else 0
                            if similarity > 0.85:  # 85% similar (slightly more strict than before)
                                is_duplicate = True
                                print(f"LAMBDA/DEDUP: Found similar instruction (similarity: {similarity:.2f}): {normalized[:50]}...")
                                break
                
                if not is_duplicate:
                    cleaned_steps.append(c)
                    _seen_steps.add(normalized)
        
        # Always provide at least one step for UI consistency
        if not cleaned_steps:
            cleaned_steps = ["Instructions not available."]
        
        # Log if duplicates were removed
        original_count = len(recipe_data["instructions"])
        cleaned_count = len(cleaned_steps)
        if original_count > cleaned_count:
            print(f"LAMBDA/DEDUP: Removed {original_count - cleaned_count} duplicate instruction(s)")
        
        recipe_data["instructions"] = cleaned_steps
    
    # Remove editorial watermarks from instructions
    if isinstance(recipe_data.get("instructions"), list):
        cleaned = []
        for instruction in recipe_data["instructions"]:
            clean_inst = instruction
            
            # Remove common watermarks (exact matches)
            watermarks = [
                "Dotdash Meredith Food Studios",
                "DOTDASH MEREDITH FOOD STUDIOS",
                ". Dotdash Meredith Food Studios",
                ", Dotdash Meredith Food Studios",
                "Meredith Food Studio",
                "MEREDITH FOOD STUDIO",
                ". Meredith Food Studio",
                ", Meredith Food Studio",
                "Serious Eats / Eric Kleinberg",
                "Serious Eats / Vicky Wasik"
            ]
            for watermark in watermarks:
                clean_inst = clean_inst.replace(watermark, "")
            
            # Remove AllRecipes credits (using regex for variations)
            # Pattern: "Allrecipes/Name" or "Allrecipes / Name" at end of text
            clean_inst = re.sub(r'\s*Allrecipes\s*/?\s*[A-Za-z\s]+$', '', clean_inst, flags=re.IGNORECASE)
            # Also remove standalone "Allrecipes" at end
            clean_inst = re.sub(r'\s+Allrecipes\s*$', '', clean_inst, flags=re.IGNORECASE)
            
            # Remove any trailing credits/attributions (pattern: "Site/Name" or "Site Name" at end)
            # This catches patterns like "Allrecipes/Qi Ai", "Food Network / Name", etc.
            clean_inst = re.sub(r'\s+[A-Z][a-z]+(?:\s*/\s*[A-Z][a-z\s]+)?\s*$', '', clean_inst)
            
            # Remove any standalone site names at the end (Allrecipes, Food Network, etc.)
            site_names = ['allrecipes', 'food network', 'taste of home', 'bon appétit', 'serious eats']
            for site in site_names:
                clean_inst = re.sub(r'\s+' + re.escape(site) + r'\s*$', '', clean_inst, flags=re.IGNORECASE)
            
            # Clean up punctuation and whitespace
            clean_inst = clean_inst.replace("..", ".").strip()
            clean_inst = re.sub(r'\s+', ' ', clean_inst)  # Normalize whitespace
            clean_inst = clean_inst.strip()
            
            # Remove trailing punctuation that might be left behind
            clean_inst = re.sub(r'[.,;:\s]+$', '', clean_inst)
            
            if clean_inst and len(clean_inst) > 5:  # Only keep if substantial content remains
                cleaned.append(clean_inst)
        recipe_data["instructions"] = cleaned
    
    # Bot wall detection and title sanitization
    if is_bot_wall(recipe_data.get('title', '')):
        print("LAMBDA/REDFLAG: bot_wall")
        # Mark for rejection in metadata
        if 'metadata' not in recipe_data:
            recipe_data['metadata'] = {}
        recipe_data['metadata']['bot_wall_detected'] = True
    
    # Sanitize title
    original_title = recipe_data.get('title', '')
    sanitized_title = sanitize_title(original_title, url)
    if sanitized_title != original_title:
        print(f"LAMBDA/SANITIZE: title_fixed={sanitized_title[:50]}...")
        recipe_data['title'] = sanitized_title
    
    # Ensure site link/name are still set (idempotent)
    _ensure_site_link_and_name(recipe_data, url)
    # If site_link is still missing, fall back to the original URL safely
    if not recipe_data.get("site_link"):
        recipe_data["site_link"] = url
    
    # --- QUALITY SCORE FIX ---
    recipe_data['build'] = BUILD_ID
    base_qs = recipe_data.get('quality_score')
    if base_qs is None:
        base_qs = calculate_quality_score(recipe_data)
    final_quality = clamp_quality_score(recipe_data, base_qs)
    recipe_data['quality_score'] = final_quality
    
    # Final quality check - only reject if recipe has NO usable data
    # Changed: Instead of rejecting on quality_score == 0.0, check if recipe has any valid content
    has_ingredients = len(recipe_data.get('ingredients', [])) >= 2
    has_instructions = len(recipe_data.get('instructions', [])) >= 2
    has_title = recipe_data.get('title') and recipe_data['title'].strip() and recipe_data['title'] != "Untitled Recipe"
    
    # Only reject if recipe has NO usable content
    if not has_ingredients and not has_instructions:
        print("LAMBDA/FINAL: Recipe rejected - no ingredients or instructions")
        return {
            "statusCode": 200,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*"
            },
            "body": json.dumps({
                "error": "Recipe extraction failed - no usable content",
                "quality_score": 0.0,
                "reason": "no_recipe_content"
            })
        }
    
    # Allow recipes with some content, even if quality score is low
    # This allows Food Network, The Kitchn, etc. to pass through
    print(f"LAMBDA/FINAL: Recipe accepted - quality={final_quality:.2f}, has_ingredients={has_ingredients}, has_instructions={has_instructions}")
    
    # Validate prep_time and servings (prevent false positives)
    # Prep time: must be 1-600 minutes
    prep_time = recipe_data.get('prep_time') or recipe_data.get('prep_time_minutes')
    if prep_time is not None:
        try:
            prep_minutes = int(prep_time) if isinstance(prep_time, (int, float, str)) else None
            if prep_minutes is None or prep_minutes < 1 or prep_minutes > 600:
                recipe_data['prep_time'] = None
                recipe_data['prep_time_minutes'] = None
            else:
                # Normalize to prep_time_minutes for consistency
                recipe_data['prep_time_minutes'] = prep_minutes
                recipe_data['prep_time'] = prep_minutes
        except (ValueError, TypeError):
            recipe_data['prep_time'] = None
            recipe_data['prep_time_minutes'] = None
    else:
        recipe_data['prep_time'] = None
        recipe_data['prep_time_minutes'] = None

    # Servings: must be 2-50 (explicitly block "1 serving" fallback)
    servings = recipe_data.get('servings')
    if servings is not None:
        try:
            servings_int = int(servings) if isinstance(servings, (int, float, str)) else None
            if servings_int is None or servings_int < 2 or servings_int > 50:
                recipe_data['servings'] = None
            else:
                recipe_data['servings'] = servings_int
        except (ValueError, TypeError):
            recipe_data['servings'] = None
    else:
        recipe_data['servings'] = None
    
    # Validate nutrition data if present
    nutrition = recipe_data.get('nutrition')
    if nutrition:
        print(f"LAMBDA/FINAL: Validating nutrition - calories: {nutrition.get('calories')}")
        # Must have at least calories to be valid
        if not nutrition.get('calories'):
            print("LAMBDA/FINAL: Nutrition missing calories, removing")
            recipe_data['nutrition'] = None
            recipe_data['nutrition_source'] = None
        else:
            print(f"LAMBDA/FINAL: Nutrition has calories ({nutrition.get('calories')}), validating other fields")
            # Ensure all numeric values are valid strings
            nutrients_to_validate = ['calories', 'protein', 'carbohydrates', 'fat', 'saturated_fat', 
                                    'fiber', 'sugar', 'sodium', 'cholesterol', 'potassium', 'calcium', 
                                    'iron', 'vitamin_a', 'vitamin_c', 'vitamin_d', 'vitamin_e', 'vitamin_k',
                                    'vitamin_b6', 'vitamin_b12', 'thiamin', 'magnesium', 'zinc', 'selenium',
                                    'copper', 'manganese', 'choline', 'iodine', 'folate']
            for key in nutrients_to_validate:
                if key in nutrition and nutrition[key]:
                    try:
                        # Validate it's a number
                        float(nutrition[key])
                    except (ValueError, TypeError):
                        # Remove invalid values
                        print(f"LAMBDA/FINAL: Invalid value for {key}: {nutrition[key]}, removing")
                        nutrition[key] = None
            print(f"LAMBDA/FINAL: Nutrition validation complete - calories: {nutrition.get('calories')}")
    else:
        print("LAMBDA/FINAL: No nutrition data to validate")
    
    # Return response
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

def lambda_handler(event, context):
    """Lambda handler with Tier-4 AI fallback for recipe extraction"""
    print(f"LAMBDA/BOOT: build={BUILD_ID}")
    # Verification marker to confirm this code version is running in CloudWatch
    print("LAMBDA/VERIFY: marker=tier-logging-enabled")
    start_time = time.time()
    
    # Log the event structure at the very start
    try:
        print(f"LAMBDA/EVENT: Event type: {type(event)}")
        print(f"LAMBDA/EVENT: Event keys: {list(event.keys()) if isinstance(event, dict) else 'not a dict'}")
        if isinstance(event, dict) and 'body' in event:
            print(f"LAMBDA/EVENT: Body type: {type(event.get('body'))}")
            body_preview = str(event.get('body'))[:200]
            print(f"LAMBDA/EVENT: Body preview: {body_preview}")
    except Exception as e:
        print(f"LAMBDA/EVENT: Error logging event: {str(e)}")
    
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
        
        # Parse request with detailed logging
        print(f"LAMBDA/PARSE: Checking event structure...")
        if 'body' in event and isinstance(event['body'], str):
            print(f"LAMBDA/PARSE: Body is string, parsing JSON...")
            try:
                body = json.loads(event['body'])
                print(f"LAMBDA/PARSE: JSON parsed successfully")
            except json.JSONDecodeError as e:
                print(f"LAMBDA/PARSE: JSON decode error: {str(e)}")
                raise
        else:
            print(f"LAMBDA/PARSE: Body is not string, using event directly")
            body = event
        
        print(f"LAMBDA/PARSE: Body type after parsing: {type(body)}")
        print(f"LAMBDA/PARSE: Body keys: {list(body.keys()) if isinstance(body, dict) else 'not a dict'}")
        
        url = body.get('url', '')
        html = body.get('html', '')
        html_source = body.get('html_source', 'main')  # STEP 0: Extract html_source (backward compatible)
        
        # Log request type
        if html:
            print(f"LAMBDA/REQ: url+html source={html_source}")
        else:
            print(f"LAMBDA/REQ: url-only")
        
        # CRITICAL: Log what we received for routing decision
        print(f"LAMBDA/ROUTE: URL='{url}'")
        print(f"LAMBDA/ROUTE: URL type={type(url)}")
        print(f"LAMBDA/ROUTE: URL length={len(url) if url else 0}")
        print(f"LAMBDA/ROUTE: HTML length={len(html) if html else 0}")
        
        # Test the YouTube and TikTok checks explicitly with detailed logging
        youtube_check_result = is_youtube_url(url)
        tiktok_check_result = is_tiktok_url(url)
        print(f"LAMBDA/ROUTE: is_youtube_url('{url}') result={youtube_check_result}")
        print(f"LAMBDA/ROUTE: is_tiktok_url('{url}') result={tiktok_check_result}")
        
        if youtube_check_result:
            print(f"LAMBDA/ROUTE: ✅ ROUTING TO YOUTUBE EXTRACTION")
        elif tiktok_check_result:
            print(f"LAMBDA/ROUTE: ✅ ROUTING TO TIKTOK EXTRACTION")
        else:
            print(f"LAMBDA/ROUTE: ❌ NOT YOUTUBE OR TIKTOK - will process as web page")
        
        # Check if this is a YouTube URL FIRST - before any other processing
        # This must happen before Spoonacular check to prevent routing to web parsing
        if youtube_check_result:
            print(f"LAMBDA/YOUTUBE: YouTube URL detected: {url}, routing to YouTube extraction")
            try:
                video_id = extract_youtube_video_id(url)
                if not video_id:
                    print(f"LAMBDA/YOUTUBE: Failed to extract video ID from: {url}")
                    raise Exception("Failed to extract YouTube video ID")
                
                print(f"LAMBDA/YOUTUBE: Extracted video ID: {video_id}")
                recipe_data = extract_youtube_recipe(video_id, url)
                
                # Format response to match standard recipe format
                # Ensure instructions is a list (iOS ImportedRecipe decoder handles both list and string)
                instructions = recipe_data.get('instructions', [])
                if isinstance(instructions, str):
                    # Split string into list if needed
                    recipe_data['instructions'] = [s.strip() for s in instructions.split('\n') if s.strip()]
                elif not isinstance(instructions, list):
                    recipe_data['instructions'] = []
                
                # Ensure servings is a string (iOS will convert to Int)
                servings = recipe_data.get('servings')
                if servings is None:
                    recipe_data['servings'] = '4'  # Default
                elif isinstance(servings, int):
                    recipe_data['servings'] = str(servings)
                elif not isinstance(servings, str):
                    recipe_data['servings'] = str(servings) if servings else '4'
                
                # Ensure all required fields
                if 'image' not in recipe_data:
                    recipe_data['image'] = ''
                if 'source_url' not in recipe_data:
                    recipe_data['source_url'] = url
                if 'site_link' not in recipe_data:
                    recipe_data['site_link'] = url
                if 'site_name' not in recipe_data:
                    recipe_data['site_name'] = 'YouTube'
                
                # Add prep_time_minutes (default 0)
                if 'prep_time_minutes' not in recipe_data and 'prep_time' not in recipe_data:
                    recipe_data['prep_time_minutes'] = 0
                
                # Calculate quality score
                recipe_data['quality_score'] = calculate_quality_score(recipe_data)
                
                print(f"LAMBDA/YOUTUBE: Extraction successful - tier={recipe_data.get('metadata', {}).get('tier_used', 'unknown')}")
                
                try:
                    _dur = int((time.time() - start_time) * 1000)
                    tier_name = recipe_data.get('metadata', {}).get('tier_used', 'youtube')
                    _log_tier("youtube", url, missing_fields=None, quality=recipe_data.get('quality_score'), duration_ms=_dur)
                except Exception:
                    pass
                
                return finalize_response(recipe_data, url)
            except Exception as e:
                print(f"LAMBDA/YOUTUBE: Extraction failed - {str(e)}")
                import traceback
                print(f"LAMBDA/YOUTUBE: Traceback: {traceback.format_exc()}")
                return {
                    'statusCode': 200,  # Return 200 with error in body (iOS expects 200)
                    'headers': {
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*',
                        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                        'Access-Control-Allow-Methods': 'POST,OPTIONS'
                    },
                    'body': json.dumps({'error': f'YouTube extraction failed: {str(e)}', 'quality_score': 0.0, 'reason': 'youtube_extraction_failed'})
                }
        
        # Check if this is a TikTok URL
        elif tiktok_check_result:
            print(f"LAMBDA/TIKTOK: TikTok URL detected: {url}, routing to TikTok extraction")
            try:
                video_id = extract_tiktok_video_id(url)
                # For shortened URLs (tiktok.com/t/...), video_id will be the short code
                # Apify can handle both full URLs and shortened URLs, so we'll use the URL directly
                if not video_id:
                    print(f"LAMBDA/TIKTOK: Could not extract video ID from shortened URL: {url}, will use full URL for Apify")
                    # Use a placeholder - Apify will use the full URL
                    video_id = "shortened_url"
                else:
                    print(f"LAMBDA/TIKTOK: Extracted video ID: {video_id}")
                
                recipe_data = extract_tiktok_recipe(video_id, url)
                
                # Format response to match standard recipe format (same as YouTube)
                # Ensure instructions is a list (iOS ImportedRecipe decoder handles both list and string)
                instructions = recipe_data.get('instructions', [])
                if isinstance(instructions, str):
                    # Split string into list if needed
                    recipe_data['instructions'] = [s.strip() for s in instructions.split('\n') if s.strip()]
                elif not isinstance(instructions, list):
                    recipe_data['instructions'] = []
                
                # Ensure servings is a string (iOS will convert to Int)
                servings = recipe_data.get('servings')
                if servings is None:
                    recipe_data['servings'] = '4'  # Default
                elif isinstance(servings, int):
                    recipe_data['servings'] = str(servings)
                elif not isinstance(servings, str):
                    recipe_data['servings'] = str(servings) if servings else '4'
                
                # Ensure all required fields
                if 'image' not in recipe_data:
                    recipe_data['image'] = ''
                if 'source_url' not in recipe_data:
                    recipe_data['source_url'] = url
                if 'site_link' not in recipe_data:
                    recipe_data['site_link'] = url
                if 'site_name' not in recipe_data:
                    recipe_data['site_name'] = 'TikTok'
                
                # Add prep_time_minutes (default 0)
                if 'prep_time_minutes' not in recipe_data and 'prep_time' not in recipe_data:
                    recipe_data['prep_time_minutes'] = 0
                
                # Calculate quality score
                recipe_data['quality_score'] = calculate_quality_score(recipe_data)
                
                print(f"LAMBDA/TIKTOK: Extraction successful - tier={recipe_data.get('metadata', {}).get('tier_used', 'unknown')}")
                
                try:
                    _dur = int((time.time() - start_time) * 1000)
                    tier_name = recipe_data.get('metadata', {}).get('tier_used', 'tiktok')
                    _log_tier("tiktok", url, missing_fields=None, quality=recipe_data.get('quality_score'), duration_ms=_dur)
                except Exception:
                    pass
                
                return finalize_response(recipe_data, url)
            except Exception as e:
                print(f"LAMBDA/TIKTOK: Extraction failed - {str(e)}")
                import traceback
                print(f"LAMBDA/TIKTOK: Traceback: {traceback.format_exc()}")
                return {
                    'statusCode': 200,  # Return 200 with error in body (iOS expects 200)
                    'headers': {
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*',
                        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                        'Access-Control-Allow-Methods': 'POST,OPTIONS'
                    },
                    'body': json.dumps({'error': f'TikTok extraction failed: {str(e)}', 'quality_score': 0.0, 'reason': 'tiktok_extraction_failed'})
                }
        
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
                spn["quality_score"] = calculate_quality_score(spn)
                print(f"LAMBDA/OUT: tier_used=spoonacular score={calculate_quality_score(spn):.2f}")
                try:
                    _dur = int((time.time() - start_time) * 1000)
                    _log_tier("spoonacular", url, missing_fields=None, quality=spn.get("quality_score"), duration_ms=_dur)
                except Exception:
                    pass
                return finalize_response(spn, url)
        
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
                        spn["quality_score"] = calculate_quality_score(spn)
                        print(f"LAMBDA/OUT: tier_used=spoonacular score={calculate_quality_score(spn):.2f}")
                        try:
                            _dur = int((time.time() - start_time) * 1000)
                            _log_tier("spoonacular", url, missing_fields=None, quality=spn.get("quality_score"), duration_ms=_dur)
                        except Exception:
                            pass
                        return finalize_response(spn, url)

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
        recipe_data = extract_recipe_data(soup, url, html_source)  # STEP 2: Pass html_source
        
        # Calculate quality score and completeness
        quality_score = calculate_quality_score(recipe_data)
        ingredients_full = len(recipe_data.get('ingredients', [])) >= 3
        instructions_full = len(recipe_data.get('instructions', [])) >= 3
        full_recipe = ingredients_full and instructions_full
        
        print(f"LAMBDA/PARSE: tier=deterministic score={quality_score:.2f}")
        
        # Add acceptance gate for deterministic tier
        t1_accepted, t1_reason, t1_score = should_accept_tier(recipe_data, "deterministic", min_trigger_score)
        print(f"LAMBDA/GATE: t1={t1_score:.2f} accept={t1_accepted} reason={t1_reason}")
        
        if t1_accepted:
            # Update metadata and return early
            if 'metadata' not in recipe_data:
                recipe_data['metadata'] = {}
            recipe_data['metadata']['tier_used'] = 'deterministic'
            recipe_data['quality_score'] = t1_score
            print(f"LAMBDA/OUT: tier_used=deterministic score={t1_score:.2f}")
            try:
                _dur = int((time.time() - start_time) * 1000)
                _log_tier("html", url, missing_fields=None, quality=t1_score, duration_ms=_dur)
            except Exception:
                pass
            return finalize_response(recipe_data, url)
        
        # Initialize variable to prevent undefined error
        spoonacular_result = None
        
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
                
                # Add acceptance gate for spoonacular tier
                t2_accepted, t2_reason, t2_score = should_accept_tier(recipe_data, "spoonacular", min_trigger_score)
                print(f"LAMBDA/GATE: t2={t2_score:.2f} accept={t2_accepted} reason={t2_reason}")
                
                if t2_accepted:
                    # Update metadata and return early
                    if 'metadata' not in recipe_data:
                        recipe_data['metadata'] = {}
                    recipe_data['metadata']['tier_used'] = 'spoonacular'
                    recipe_data['quality_score'] = t2_score
                    print(f"LAMBDA/OUT: tier_used=spoonacular score={t2_score:.2f}")
                    try:
                        _dur = int((time.time() - start_time) * 1000)
                        _log_tier("spoonacular", url, missing_fields=None, quality=t2_score, duration_ms=_dur)
                    except Exception:
                        pass
                    return finalize_response(recipe_data, url)
                
                # Update metadata
                if 'metadata' not in recipe_data:
                    recipe_data['metadata'] = {}
                recipe_data['metadata']['tier_used'] = 'spoonacular'
            else:
                print("LAMBDA/PARSE: spoonacular error=no_result")
        
        # Determine best base result and what needs AI patching
        best_base = recipe_data
        best_confidences = calculate_field_confidence(recipe_data, "deterministic")
        if spoonacular_result:
            spoon_confidences = calculate_field_confidence(recipe_data, "spoonacular")
            # Use spoonacular if it has higher overall confidence
            if calculate_weighted_score(recipe_data, spoon_confidences) > calculate_weighted_score(recipe_data, best_confidences):
                best_confidences = spoon_confidences
        
        # Determine what fields need AI patching
        fields_needing_ai = [field for field, conf in best_confidences.items() if conf < 0.6]
        missing_fields = [field for field in ['title', 'image', 'ingredients', 'instructions'] if not best_base.get(field)]
        needs_ai = fields_needing_ai or missing_fields or (quality_score < min_trigger_score)
        
        # Check if AI fallback should be triggered (only if Spoonacular didn't improve quality enough)
        if ai_enabled and needs_ai:
            print("LAMBDA/PARSE: ai-fallback start")
            
            try:
                ai_result = call_ai_fallback(url, html)
                if ai_result:
                    # Use patch-only merge logic
                    recipe_data = merge_ai_results_patch_only(best_base, ai_result, best_confidences)
                    quality_score = calculate_quality_score(recipe_data)
                    print(f"LAMBDA/PARSE: ai-fallback success ing={len(recipe_data.get('ingredients', []))} steps={len(recipe_data.get('instructions', []))}")
                    
                    # Update metadata
                    if 'metadata' not in recipe_data:
                        recipe_data['metadata'] = {}
                    recipe_data['metadata']['tier_used'] = 'ai_fallback'
                    
                    # Log what AI accomplished
                    fields_missing_before = len([f for f in ['title', 'image', 'ingredients', 'instructions'] if not best_base.get(f)])
                    fields_filled_by_ai = len([f for f in ['title', 'image', 'ingredients', 'instructions'] if not best_base.get(f) and recipe_data.get(f)])
                    print(f"LAMBDA/OUT: tier_used=ai_fallback score={quality_score:.2f} fields_missing_before={fields_missing_before} fields_filled_by_ai={fields_filled_by_ai}")
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
        
        # Set quality score before finalize
        recipe_data["quality_score"] = quality_score
        
        # Finalize with cleanup and return
        try:
            _dur = int((time.time() - start_time) * 1000)
            tier_name = recipe_data.get('metadata', {}).get('tier_used', 'deterministic')
            mapped = 'ai' if tier_name == 'ai_fallback' else ('spoonacular' if tier_name == 'spoonacular' else 'html')
            _log_tier(mapped, url, missing_fields=None, quality=quality_score, duration_ms=_dur)
        except Exception:
            pass
        return finalize_response(recipe_data, url)
        
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

def clean_nutrition_value(value):
    """Remove units and text, keep just the number."""
    if not value:
        return ''
    # Handle strings like "964 calories" or "24g" or "24 g"
    match = re.search(r'(\d+(?:\.\d+)?)', str(value))
    return match.group(1) if match else ''

def extract_from_schema(soup):
    """Extract from schema.org structured data (JSON-LD) - most reliable method."""
    scripts = soup.find_all('script', type='application/ld+json')
    
    for script in scripts:
        try:
            if not script.string:
                continue
            data = json.loads(script.string)
            
            # Handle array of schemas
            if isinstance(data, list):
                for item in data:
                    if isinstance(item, dict) and item.get('@type') == 'Recipe':
                        data = item
                        break
            
            # Handle @graph structure
            if isinstance(data, dict) and '@graph' in data:
                for item in data['@graph']:
                    if isinstance(item, dict) and item.get('@type') == 'Recipe':
                        data = item
                        break
            
            if isinstance(data, dict) and data.get('@type') == 'Recipe' and 'nutrition' in data:
                n = data['nutrition']
                calcium_raw = n.get('calciumContent', '')
                print(f"LAMBDA/SCHEMA: Raw calciumContent from schema.org: '{calcium_raw}' (type: {type(calcium_raw)})")
                
                potassium_raw = n.get('potassiumContent', '')
                print(f"LAMBDA/SCHEMA: Raw potassiumContent from schema.org: '{potassium_raw}' (type: {type(potassium_raw)})")
                
                nutrition = {
                    'calories': clean_nutrition_value(n.get('calories', '')),
                    'protein': clean_nutrition_value(n.get('proteinContent', '')),
                    'carbohydrates': clean_nutrition_value(n.get('carbohydrateContent', '')),
                    'fat': clean_nutrition_value(n.get('fatContent', '')),
                    'saturated_fat': clean_nutrition_value(n.get('saturatedFatContent', '')),
                    'fiber': clean_nutrition_value(n.get('fiberContent', '')),
                    'sugar': clean_nutrition_value(n.get('sugarContent', '')),
                    'sodium': clean_nutrition_value(n.get('sodiumContent', '')),
                    'cholesterol': clean_nutrition_value(n.get('cholesterolContent', '')),
                    'potassium': clean_nutrition_value(n.get('potassiumContent', '')),
                    'calcium': clean_nutrition_value(n.get('calciumContent', '')),
                    'iron': clean_nutrition_value(n.get('ironContent', '')),
                    'vitamin_a': clean_nutrition_value(n.get('vitaminAContent', '')),
                    'vitamin_c': clean_nutrition_value(n.get('vitaminCContent', '')),
                    'vitamin_d': clean_nutrition_value(n.get('vitaminDContent', '')),
                    'vitamin_e': clean_nutrition_value(n.get('vitaminEContent', '')),
                    'vitamin_k': clean_nutrition_value(n.get('vitaminKContent', '')),
                    'vitamin_b6': clean_nutrition_value(n.get('vitaminB6Content', '') or n.get('vitaminB6', '')),
                    'vitamin_b12': clean_nutrition_value(n.get('vitaminB12Content', '') or n.get('vitaminB12', '')),
                    'thiamin': clean_nutrition_value(n.get('thiaminContent', '') or n.get('vitaminB1Content', '') or n.get('thiamin', '')),
                    'magnesium': clean_nutrition_value(n.get('magnesiumContent', '')),
                    'zinc': clean_nutrition_value(n.get('zincContent', '')),
                    'selenium': clean_nutrition_value(n.get('seleniumContent', '')),
                    'copper': clean_nutrition_value(n.get('copperContent', '')),
                    'manganese': clean_nutrition_value(n.get('manganeseContent', '')),
                    'choline': clean_nutrition_value(n.get('cholineContent', '')),
                    'iodine': clean_nutrition_value(n.get('iodineContent', '')),
                    'folate': clean_nutrition_value(n.get('folateContent', '') or n.get('folicAcidContent', '')),
                    'source': 'schema.org'
                }
                
                print(f"LAMBDA/SCHEMA: Cleaned calcium value: '{nutrition.get('calcium')}'")
                print(f"LAMBDA/SCHEMA: Cleaned potassium value: '{nutrition.get('potassium')}'")
                print(f"LAMBDA/SCHEMA: Nutrition keys extracted: {list(nutrition.keys())}")
                
                # Only return if we have at least calories
                if nutrition.get('calories'):
                    return nutrition
        except (json.JSONDecodeError, TypeError, KeyError, AttributeError):
            continue
    
    return None

def find_nutrition_section(soup):
    """Find the nutrition facts section on the page."""
    
    # Common section identifiers (in order of reliability)
    id_patterns = [
        'nutrition-facts',
        'nutritionFacts', 
        'nutrition_facts',
        'recipe-nutrition',
        'recipeNutrition',
    ]
    
    class_patterns = [
        'nutrition-facts',
        'mntl-nutrition-facts-summary',
        'mntl-nutrition-facts-label',
        'recipe-nutrition',
        'recipe-nutrition-section',
        'o-NutritionInfo',
        'nutrition-info',
        'nutritional-info',
        'nutrition-summary',
    ]
    
    # Try finding by ID
    for id_name in id_patterns:
        section = soup.find(id=id_name)
        if section:
            return section
        # Also try partial match
        section = soup.find(id=lambda x: x and id_name in x.lower() if x else False)
        if section:
            return section
    
    # Try finding by class
    for class_name in class_patterns:
        section = soup.find(['div', 'section', 'table', 'dl', 'aside'], class_=lambda x: x and class_name in ' '.join(x).lower() if x else False)
        if section:
            return section
    
    # Try finding by heading text
    headings = soup.find_all(['h2', 'h3', 'h4', 'h5', 'span', 'div'])
    for heading in headings:
        text = heading.get_text(strip=True).lower()
        if 'nutrition fact' in text or text == 'nutrition':
            # Get parent container
            parent = heading.find_parent(['div', 'section', 'aside'])
            if parent:
                return parent
            # Or get next sibling
            sibling = heading.find_next_sibling(['div', 'table', 'dl'])
            if sibling:
                return sibling
    
    return None

def parse_nutrition_section(section):
    """Parse nutrition values from a contained section only."""
    nutrition = {}
    
    # Try to parse structured HTML first (tables, dl/dt/dd, etc.)
    # Look for table rows or definition lists
    text_lines = []
    
    # Extract text preserving some structure
    for elem in section.find_all(['tr', 'dt', 'dd', 'div', 'span', 'p']):
        elem_text = elem.get_text(strip=True)
        if elem_text and len(elem_text) > 2:
            text_lines.append(elem_text)
    
    # Also get full text for fallback
    full_text = section.get_text(separator='\n')
    
    # Parse calories - look for "Calories: 179" pattern specifically
    # Try structured parsing first
    calories_found = False
    for line in text_lines:
        line_lower = line.lower()
        if 'calories' in line_lower and not calories_found:
            # Match "Calories: 179" or "Calories 179"
            match = re.search(r'calories[:\s]+(\d+)', line, re.IGNORECASE)
            if match:
                calories_val = match.group(1)
                # Validate: calories should be reasonable (50-2000 per serving)
                try:
                    cal_int = int(calories_val)
                    if 50 <= cal_int <= 2000:
                        nutrition['calories'] = calories_val
                        calories_found = True
                        break
                except ValueError:
                    pass
    
    # Fallback to regex on full text if not found in structured parsing
    if not calories_found:
        calories_patterns = [
            r'calories[:\s]+(\d+)(?:\s|$)',  # "Calories: 179" or "Calories 179"
            r'(?:servings?\s+per\s+recipe[:\s]*\d+[:\s]*)?calories[:\s]+(\d+)',  # After servings
        ]
        for pattern in calories_patterns:
            match = re.search(pattern, full_text, re.IGNORECASE | re.MULTILINE)
            if match:
                calories_val = match.group(1)
                try:
                    cal_int = int(calories_val)
                    if 50 <= cal_int <= 2000:
                        nutrition['calories'] = calories_val
                        calories_found = True
                        break
                except ValueError:
                    pass
    
    if not calories_found:
        return None  # Must have calories to be valid
    
    # Parse other nutrients - use structured parsing when possible
    patterns = {
        'protein': r'protein[:\s]+(\d+)\s*g',
        'carbohydrates': r'(?:total\s+)?carb(?:ohydrate)?s?[:\s]+(\d+)\s*g',
        'fat': r'(?:total\s+)?fat[:\s]+(\d+)\s*g',
        'saturated_fat': r'saturated\s+fat[:\s]+(\d+)\s*g',
        'fiber': r'(?:dietary\s+)?fiber[:\s]+(\d+)\s*g',
        'sugar': r'(?:total\s+)?sugars?[:\s]+(\d+)\s*g',
        'sodium': r'sodium[:\s]+(\d+)\s*(?:mg)?',
        'cholesterol': r'cholesterol[:\s]+(\d+)\s*(?:mg)?',
        'potassium': r'potassium[:\s]+(\d+)\s*(?:mg)?',
        'calcium': r'calcium[:\s]+(\d+)\s*(?:mg)?',
        'iron': r'iron[:\s]+(\d+)\s*(?:mg)?',
        'vitamin_a': r'vitamin\s*a[:\s]+(\d+)',
        'vitamin_c': r'vitamin\s*c[:\s]+(\d+)',
        'vitamin_d': r'vitamin\s*d[:\s]+(\d+)',
        'vitamin_e': r'vitamin\s*e[:\s]+(\d+)',
        'vitamin_k': r'vitamin\s*k[:\s]+(\d+)',
        'vitamin_b6': r'(?:vitamin\s*b[:\s]*6|b6)[:\s]+(\d+)',
        'vitamin_b12': r'(?:vitamin\s*b[:\s]*12|b12)[:\s]+(\d+)',
        'thiamin': r'(?:thiamin|vitamin\s*b1)[:\s]+(\d+)',
        'magnesium': r'magnesium[:\s]+(\d+)\s*(?:mg)?',
        'zinc': r'zinc[:\s]+(\d+)\s*(?:mg)?',
        'selenium': r'selenium[:\s]+(\d+)\s*(?:mcg)?',
        'copper': r'copper[:\s]+(\d+)\s*(?:mg)?',
        'manganese': r'manganese[:\s]+(\d+)\s*(?:mg)?',
        'choline': r'choline[:\s]+(\d+)\s*(?:mg)?',
        'iodine': r'iodine[:\s]+(\d+)\s*(?:mcg)?',
        'folate': r'(?:folate|folic\s+acid)[:\s]+(\d+)\s*(?:mcg)?',
    }
    
    # Try structured parsing first (line by line)
    for line in text_lines:
        line_lower = line.lower()
        for nutrient, pattern in patterns.items():
            if nutrient not in nutrition:  # Don't overwrite if already found
                match = re.search(pattern, line, re.IGNORECASE)
                if match:
                    nutrition[nutrient] = match.group(1)
    
    # Fallback to full text regex for any missing nutrients
    for nutrient, pattern in patterns.items():
        if nutrient not in nutrition:
            match = re.search(pattern, full_text, re.IGNORECASE)
            if match:
                nutrition[nutrient] = match.group(1)
    
    # Also try to find servings info in this section
    servings_match = re.search(r'servings?\s*(?:per\s+recipe)?[:\s]*(\d+)', full_text, re.IGNORECASE)
    if servings_match:
        nutrition['servings_from_nutrition'] = servings_match.group(1)
    
    # Extract prep time from nutrition section (if present)
    prep_time_match = re.search(r'prep(?:aration)?\s*time[:\s]*(\d+)\s*(?:min|mins|minutes?|m)', full_text, re.IGNORECASE)
    if prep_time_match:
        try:
            prep_val = int(prep_time_match.group(1))
            if 1 <= prep_val <= 600:  # Validate range
                nutrition['prep_time_from_nutrition'] = str(prep_val)
        except (ValueError, TypeError):
            pass
    
    # Extract cook time from nutrition section (if present)
    cook_time_match = re.search(r'cook(?:ing)?\s*time[:\s]*(\d+)\s*(?:min|mins|minutes?|m)', full_text, re.IGNORECASE)
    if cook_time_match:
        try:
            cook_val = int(cook_time_match.group(1))
            if 1 <= cook_val <= 600:  # Validate range
                nutrition['cook_time_from_nutrition'] = str(cook_val)
        except (ValueError, TypeError):
            pass
    
    return nutrition

def extract_nutrition_from_html(soup):
    """
    Extract nutrition facts by first finding the nutrition section,
    then parsing values within it. Never search the whole page.
    """
    
    # Priority 1: Try schema.org structured data (most reliable)
    schema_nutrition = extract_from_schema(soup)
    
    # Priority 2: Find the nutrition section by ID or class for HTML parsing
    nutrition_section = find_nutrition_section(soup)
    html_nutrition = None
    if nutrition_section:
        parsed = parse_nutrition_section(nutrition_section)
        if parsed:
            html_nutrition = parsed
    
    # If we have schema.org data, use it as base and fill in missing micronutrients from HTML
    if schema_nutrition and schema_nutrition.get('calories'):
        print(f"LAMBDA/NUTRITION: Extracted {schema_nutrition.get('calories')} calories from schema.org")
        
        # Merge HTML data to fill in missing micronutrients
        if html_nutrition:
            # List of all nutrients that might be missing from schema.org
            # Include macros, minerals, and micronutrients that could be missing
            nutrients_to_merge = ['protein', 'carbohydrates', 'fat', 'sodium', 'potassium', 'calcium', 'iron', 
                                 'vitamin_a', 'vitamin_c', 'vitamin_d', 'vitamin_e', 'vitamin_k', 
                                 'vitamin_b6', 'vitamin_b12', 'thiamin', 'magnesium', 'zinc',
                                 'selenium', 'copper', 'manganese', 'choline', 'iodine', 'folate',
                                 'cholesterol', 'saturated_fat', 'fiber', 'sugar']
            
            for nutrient in nutrients_to_merge:
                # If schema.org doesn't have it (or it's empty/0) but HTML does, use HTML value
                schema_val = schema_nutrition.get(nutrient, '').strip()
                html_val = html_nutrition.get(nutrient, '').strip()
                
                if (not schema_val or schema_val == '0') and html_val and html_val != '0':
                    schema_nutrition[nutrient] = html_val
                    print(f"LAMBDA/NUTRITION: Merged {nutrient} from HTML: {html_val}")
                elif nutrient == 'potassium':
                    # Log potassium specifically for debugging
                    print(f"LAMBDA/NUTRITION: Potassium check - schema: '{schema_val}', html: '{html_val}'")
        
        return schema_nutrition
    
    # If no schema.org, use HTML parsing result
    if html_nutrition:
        html_nutrition['source'] = 'html'
        print(f"LAMBDA/NUTRITION: Extracted {html_nutrition.get('calories')} calories from HTML nutrition section")
        return html_nutrition
    
    # Priority 3: Return None - don't search whole page
    print("LAMBDA/NUTRITION: No nutrition data found on page")
    return None

def parse_iso8601_duration(duration_str):
    """Parse ISO 8601 duration format (e.g., PT30M, PT1H30M) to minutes.
    
    Examples:
        PT30M -> 30 minutes
        PT1H30M -> 90 minutes (1 hour 30 minutes)
        PT2H -> 120 minutes (2 hours)
        PT45M -> 45 minutes
    """
    if not isinstance(duration_str, str):
        return None
    
    duration_str = duration_str.strip().upper()
    if not duration_str.startswith('PT'):
        return None
    
    # Remove 'PT' prefix
    duration_str = duration_str[2:]
    
    total_minutes = 0
    
    # Extract hours (H)
    hour_match = re.search(r'(\d+)H', duration_str)
    if hour_match:
        total_minutes += int(hour_match.group(1)) * 60
    
    # Extract minutes (M)
    minute_match = re.search(r'(\d+)M', duration_str)
    if minute_match:
        total_minutes += int(minute_match.group(1))
    
    # If we found any time components, return total minutes
    if hour_match or minute_match:
        return total_minutes
    
    return None

# ============================================================================
# PRINT PAGE PARSING HELPERS (Print Pages Only)
# ============================================================================

def _test_filter_metadata_and_notes():
    """Quick sanity test for metadata/notes filter."""
    test_cases = [
        ("Author:Sally", False),  # Should be filtered
        ("Prep Time:2 hours", False),  # Should be filtered
        ("1 cup sugar", True),  # Should be kept
        ("2 teaspoons vanilla extract", True),  # Should be kept
        ("Yield:24 cookies", False),  # Should be filtered
        ("Category:Cookies", False),  # Should be filtered
        ("Notes: This is a note", False),  # Should be filtered
        ("1/2 cup butter, softened", True),  # Should be kept
    ]
    
    passed = 0
    failed = 0
    for text, expected in test_cases:
        result = _filter_metadata_and_notes(text)
        if result == expected:
            passed += 1
        else:
            failed += 1
            print(f"LAMBDA/PRINT/TEST: FAILED '{text}' -> expected {expected}, got {result}")
    
    print(f"LAMBDA/PRINT/TEST: Filter test: {passed} passed, {failed} failed")
    return failed == 0

def _filter_metadata_and_notes(text):
    """Filter out metadata and notes-like content from ingredient/instruction candidates.
    
    Args:
        text: Candidate text to filter
        
    Returns:
        bool: True if text should be KEPT (is valid ingredient/instruction), False if filtered out
    """
    if not text or not isinstance(text, str):
        return False
    
    text_lower = text.lower().strip()
    
    # Metadata patterns (case-insensitive)
    metadata_patterns = [
        r'^author\s*:',
        r'^prep\s*time\s*:',
        r'^cook\s*time\s*:',
        r'^total\s*time\s*:',
        r'^yield\s*:',
        r'^category\s*:',
        r'^method\s*:',
        r'^cuisine\s*:',
        r'^servings\s*:',
        r'^serves\s*:',
        r'^makes\s*:',
        r'^prep\s*:',
        r'^cook\s*:',
        r'^total\s*:',
    ]
    
    # Check metadata patterns
    for pattern in metadata_patterns:
        if re.search(pattern, text_lower):
            return False
    
    # Notes-like keywords (must be in the text, not just startswith)
    notes_keywords = [
        'notes', 'tips', 'make ahead', 'storage', 'freezing',
        'special tools', 'equipment', 'faq', 'how to', 'can i',
        'why', 'reference', 'guide', 'flavors', 'corn syrup',
        'room temperature', 'optional:', 'affiliate links'
    ]
    
    # Check for notes keywords (but allow if it's clearly an ingredient with quantity)
    has_notes_keyword = any(keyword in text_lower for keyword in notes_keywords)
    if has_notes_keyword:
        # Allow if it looks like an ingredient (has quantity/unit pattern)
        ingredient_pattern = r'\d+\s*(cup|tbsp|tsp|ounce|pound|gram|g|ml|liter|teaspoon|tablespoon|cup|cups|oz|lb)'
        if not re.search(ingredient_pattern, text_lower, re.I):
            return False
    
    # Filter out paragraph-like sentences (> 120 chars AND contains multiple sentences)
    # unless it clearly looks like an ingredient (quantity+unit+food)
    if len(text) > 120:
        sentence_count = len(re.findall(r'[.!?]+', text))
        if sentence_count >= 2:
            # Check if it's clearly an ingredient (has quantity/unit pattern)
            ingredient_pattern = r'\d+\s*(cup|tbsp|tsp|ounce|pound|gram|g|ml|liter|teaspoon|tablespoon|cup|cups|oz|lb)'
            if not re.search(ingredient_pattern, text_lower, re.I):
                return False
    
    return True

def extract_print_page_ingredient_sections(soup):
    """STEP 3: Extract ingredient sections from print pages (structure-agnostic)
    
    Returns:
        Optional[List[Dict]]: List of sections with name and ingredients, or None if not found
    """
    print("LAMBDA/PRINT: starting ingredient section extraction")
    try:
        sections = []
        
        # Find all potential section labels using flexible detection
        # Look for: h2, h3, h4, p>strong, div>strong, standalone strong/em
        candidate_labels = []
        
        # Method 1: Standard headers (h2, h3, h4)
        for tag in ['h2', 'h3', 'h4']:
            for header in soup.find_all(tag):
                text = header.get_text(strip=True)
                if text and 2 <= len(text) <= 60 and not re.match(r'^\d+', text):
                    candidate_labels.append({
                        'element': header,
                        'text': text,
                        'type': 'header'
                    })
        
        # Method 2: p > strong (common pattern)
        for p in soup.find_all('p'):
            strong = p.find('strong')
            if strong:
                text = strong.get_text(strip=True)
                if text and 2 <= len(text) <= 60 and not re.match(r'^\d+', text):
                    # Check if this looks like a section label (not just bold text in paragraph)
                    p_text = p.get_text(strip=True)
                    if len(p_text) <= 70:  # Short paragraph likely a label
                        candidate_labels.append({
                            'element': p,
                            'text': text,
                            'type': 'p_strong'
                        })
        
        # Method 3: div with class containing "ingredient" or "section"
        for div in soup.find_all('div', class_=lambda x: x and (
            'ingredient' in ' '.join(x).lower() or 
            'section' in ' '.join(x).lower() or
            'group' in ' '.join(x).lower() or
            'part' in ' '.join(x).lower()
        )):
            # Look for strong/em inside as label
            for tag in ['strong', 'em']:
                label_elem = div.find(tag)
                if label_elem:
                    text = label_elem.get_text(strip=True)
                    if text and 2 <= len(text) <= 60 and not re.match(r'^\d+', text):
                        candidate_labels.append({
                            'element': div,
                            'text': text,
                            'type': 'div_label'
                        })
                        break
        
        # Method 4: Standalone strong/em elements (if they look like labels)
        for tag in ['strong', 'em']:
            for elem in soup.find_all(tag):
                # Skip if inside a paragraph (already handled)
                if elem.find_parent('p'):
                    continue
                text = elem.get_text(strip=True)
                if text and 2 <= len(text) <= 60 and not re.match(r'^\d+', text):
                    # Check if followed by ingredient-like content
                    next_sib = elem.find_next_sibling()
                    if next_sib and next_sib.name in ['ul', 'ol', 'div']:
                        candidate_labels.append({
                            'element': elem,
                            'text': text,
                            'type': 'standalone'
                        })
        
        print(f"LAMBDA/PRINT: found {len(candidate_labels)} candidate section labels")
        
        # Negative filter: exclude note/metadata section labels
        note_keywords = [
            "note", "notes",
            "make ahead", "make-ahead",
            "storage", "storing",
            "tips", "tip",
            "freezing", "freeze",
            "special tools", "equipment",
            "yeast", "milk",
            "icing instructions",
            "coffee icing", "vanilla icing",
            "faq", "reference", "guide"
        ]
        
        # Filter out note/metadata labels before processing
        filtered_labels = []
        for label_info in candidate_labels:
            label_text_normalized = label_info['text'].lower().strip()
            # Remove punctuation for better matching
            label_text_normalized = re.sub(r'[^\w\s]', ' ', label_text_normalized)
            label_text_normalized = ' '.join(label_text_normalized.split())  # Normalize whitespace
            
            # Check if label matches any note keyword
            is_note_section = False
            for keyword in note_keywords:
                if keyword in label_text_normalized:
                    is_note_section = True
                    print(f"LAMBDA/PRINT: skipped non-ingredient section label: '{label_info['text']}'")
                    break
            
            if not is_note_section:
                filtered_labels.append(label_info)
        
        print(f"LAMBDA/PRINT: filtered to {len(filtered_labels)} ingredient section candidates")
        
        # Process each filtered candidate label to extract ingredients
        for label_info in filtered_labels[:20]:  # Limit to first 20 candidates
            label_elem = label_info['element']
            label_text = label_info['text']
            
            # Find ingredients following this label
            ingredients = []
            
            # Strategy 1: Look for ul/ol lists (immediate or within next 10 siblings)
            current = label_elem.find_next_sibling()
            search_limit = 10
            found_list = None
            
            while current and search_limit > 0:
                if current.name in ['ul', 'ol']:
                    found_list = current
                    break
                elif current.name == 'div':
                    # Check if div contains a list
                    nested_list = current.find(['ul', 'ol'], recursive=False)
                    if nested_list:
                        found_list = nested_list
                        break
                elif current.name == 'hr':
                    # Stop at horizontal rule (section separator)
                    break
                current = current.find_next_sibling()
                search_limit -= 1
            
            if found_list:
                # Extract from list
                for li in found_list.find_all('li', recursive=False):
                    ingredient_text = li.get_text(strip=True)
                    if ingredient_text and len(ingredient_text) > 2 and len(ingredient_text) < 200:
                        # Filter out metadata and notes
                        if _filter_metadata_and_notes(ingredient_text):
                            ingredients.append(ingredient_text)
            
            # Strategy 2: If no list found, look for ingredient-like <p> elements
            if not ingredients:
                current = label_elem.find_next_sibling()
                search_limit = 10
                while current and search_limit > 0:
                    if current.name == 'p':
                        p_text = current.get_text(strip=True)
                        # Check if this looks like an ingredient (has quantity/unit patterns)
                        if p_text and len(p_text) > 3 and len(p_text) < 200:
                            # Simple heuristic: contains numbers or common units
                            if re.search(r'\d+|cup|tbsp|tsp|ounce|pound|gram|ml|liter', p_text, re.I):
                                # Filter out metadata and notes
                                if _filter_metadata_and_notes(p_text):
                                    ingredients.append(p_text)
                    elif current.name in ['h2', 'h3', 'h4']:
                        # Stop at next section header
                        break
                    elif current.name == 'hr':
                        # Stop at horizontal rule
                        break
                    current = current.find_next_sibling()
                    search_limit -= 1
            
            # Add section if we found at least 1 ingredient
            if len(ingredients) >= 1:
                sections.append({
                    'name': label_text,
                    'ingredients': ingredients
                })
                
                # Maximum 12 sections
                if len(sections) >= 12:
                    break
        
        # Diagnostic logging
        if sections:
            print(f"LAMBDA/PRINT: extracted {len(sections)} ingredient sections")
        else:
            print("LAMBDA/PRINT: no valid ingredient sections found")
        
        return sections if sections else None
        
    except Exception as e:
        print(f"LAMBDA/PRINT: Ingredient section extraction error: {str(e)}")
        return None

def extract_print_page_instruction_groups(soup):
    """STEP 5: Extract instruction groups with labels from print pages (structure-agnostic)
    
    Returns:
        Optional[List[Dict]]: List of groups with label and steps, or None if not found
    """
    try:
        groups = []
        
        # Find all potential instruction labels using flexible detection
        candidate_labels = []
        
        # Method 1: Standard headers (h2, h3, h4)
        for tag in ['h2', 'h3', 'h4']:
            for header in soup.find_all(tag):
                text = header.get_text(strip=True)
                if text and 3 <= len(text) <= 60 and not re.match(r'^\d+', text):
                    candidate_labels.append({
                        'element': header,
                        'text': text,
                        'type': 'header'
                    })
        
        # Method 2: p > strong (common pattern)
        for p in soup.find_all('p'):
            strong = p.find('strong')
            if strong:
                text = strong.get_text(strip=True)
                if text and 3 <= len(text) <= 60 and not re.match(r'^\d+', text):
                    p_text = p.get_text(strip=True)
                    if len(p_text) <= 70:  # Short paragraph likely a label
                        candidate_labels.append({
                            'element': p,
                            'text': text,
                            'type': 'p_strong'
                        })
        
        # Sort labels by document order
        candidate_labels.sort(key=lambda x: x['element'].sourceline if hasattr(x['element'], 'sourceline') else 0)
        
        # Process each candidate label to extract steps
        current_label = None
        current_steps = []
        
        for label_info in candidate_labels[:20]:  # Limit to first 20 candidates
            label_elem = label_info['element']
            label_text = label_info['text']
            
            # Find steps following this label
            steps = []
            
            # Strategy 1: Look for ol/ul lists (ordered lists are common for instructions)
            current = label_elem.find_next_sibling()
            search_limit = 15
            
            while current and search_limit > 0:
                if current.name in ['ol', 'ul']:
                    # Extract from list
                    for li in current.find_all('li', recursive=False):
                        step_text = li.get_text(strip=True)
                        if step_text and len(step_text) > 10 and len(step_text) < 500:
                            # Filter out metadata and notes
                            if _filter_metadata_and_notes(step_text):
                                steps.append(step_text)
                    if steps:
                        break
                elif current.name == 'div':
                    # Check if div contains a list
                    nested_list = current.find(['ol', 'ul'], recursive=False)
                    if nested_list:
                        for li in nested_list.find_all('li', recursive=False):
                            step_text = li.get_text(strip=True)
                            if step_text and len(step_text) > 10 and len(step_text) < 500:
                                steps.append(step_text)
                        if steps:
                            break
                    # Also check for step-like <p> elements in div
                    step_ps = current.find_all('p', recursive=False)
                    for p in step_ps:
                        p_text = p.get_text(strip=True)
                        if p_text and len(p_text) > 10 and len(p_text) < 500:
                            # Filter out metadata and notes
                            if _filter_metadata_and_notes(p_text):
                                steps.append(p_text)
                    if steps:
                        break
                elif current.name in ['h2', 'h3', 'h4']:
                    # Stop at next section header
                    break
                elif current.name == 'hr':
                    # Stop at horizontal rule
                    break
                current = current.find_next_sibling()
                search_limit -= 1
            
            # Strategy 2: If no list found, look for step-like <p> elements
            if not steps:
                current = label_elem.find_next_sibling()
                search_limit = 15
                while current and search_limit > 0:
                    if current.name == 'p':
                        p_text = current.get_text(strip=True)
                        if p_text and len(p_text) > 10 and len(p_text) < 500:
                            # Filter out metadata and notes
                            if _filter_metadata_and_notes(p_text):
                                steps.append(p_text)
                    elif current.name in ['h2', 'h3', 'h4']:
                        break
                    elif current.name == 'hr':
                        break
                    current = current.find_next_sibling()
                    search_limit -= 1
            
            # If we found steps, save previous group and start new one
            if len(steps) >= 1:
                # Save previous group if exists
                if current_label and current_steps:
                    groups.append({
                        'label': current_label,
                        'steps': current_steps
                    })
                
                current_label = label_text
                current_steps = steps
                
                if len(groups) >= 10:  # Max 10 groups
                    break
        
        # Save last group
        if current_label and current_steps:
            groups.append({
                'label': current_label,
                'steps': current_steps
            })
        
        if groups:
            print(f"LAMBDA/PRINT: extracted {len(groups)} instruction groups")
        
        return groups if groups else None
        
    except Exception as e:
        print(f"LAMBDA/PRINT: Instruction group extraction error: {str(e)}")
        return None

def extract_print_page_notes(soup):
    """STEP 6: Extract recipe notes from print pages (structure-agnostic)
    
    Returns:
        Optional[str]: Notes text, or None if not found
    """
    try:
        notes_sections = []
        note_keywords = ['notes', 'make ahead', 'storage', 'tips', 'tip', 'note', 'freezing']
        
        # Find headers matching note keywords (h2, h3, h4)
        headers = soup.find_all(['h2', 'h3', 'h4'])
        matching_headers = []
        for header in headers:
            header_text = header.get_text(strip=True).lower()
            if any(keyword in header_text for keyword in note_keywords):
                matching_headers.append(header)
        
        # Also check for p > strong pattern
        for p in soup.find_all('p'):
            strong = p.find('strong')
            if strong:
                strong_text = strong.get_text(strip=True).lower()
                if any(keyword in strong_text for keyword in note_keywords):
                    # Check if this looks like a note section header
                    p_text = p.get_text(strip=True)
                    if len(p_text) <= 70:  # Short paragraph likely a header
                        matching_headers.append(p)
        
        for header in matching_headers:
            # Capture content until next major header (h1, h2, h3, h4)
            content_parts = []
            current = header.find_next_sibling()
            
            while current:
                if current.name in ['h1', 'h2', 'h3', 'h4']:
                    break
                
                if current.name in ['p', 'ul', 'ol', 'div']:
                    text = current.get_text(strip=True)
                    if text and len(text) > 5:
                        content_parts.append(text)
                
                current = current.find_next_sibling()
            
            if content_parts:
                notes_sections.append(' '.join(content_parts))
        
        # Combine all note sections
        if notes_sections:
            notes_text = ' '.join(notes_sections)
            print("LAMBDA/PRINT: notes section found")
            return notes_text
        
        return None
        
    except Exception as e:
        print(f"LAMBDA/PRINT: Notes extraction error: {str(e)}")
        return None

def extract_recipe_data(soup, url, html_source='main'):
    """Extract recipe data using BeautifulSoup patterns
    
    Args:
        soup: BeautifulSoup parsed HTML
        url: Recipe URL
        html_source: Source of HTML ('print', 'jump-to-recipe', 'main', etc.) - STEP 2: Added parameter
    """
    
    # STEP 2: Print page section extraction (if applicable) - DEFERRED until after JSON-LD check
    ingredient_sections_raw = None
    instruction_groups_raw = None
    recipe_notes_raw = None
    
    # Check if this is Food Network, Barefoot Contessa, or Food & Wine - prefer site-specific parser over JSON-LD
    from urllib.parse import urlparse
    parsed_url = urlparse(url)
    domain = parsed_url.netloc.lower()
    is_foodnetwork = 'foodnetwork.com' in domain
    is_barefootcontessa = 'barefootcontessa.com' in domain
    is_foodandwine = 'foodandwine.com' in domain
    is_loveandlemons = 'loveandlemons.com' in domain
    
    # Try JSON-LD first (but skip for Food Network, Barefoot Contessa, Food & Wine, and Love and Lemons - use site-specific parser instead)
    json_ld_instructions_for_dedup = []  # Store JSON-LD instructions for deduplication if we fall back
    if not is_foodnetwork and not is_barefootcontessa and not is_foodandwine and not is_loveandlemons:
        try:
            for script in soup.find_all('script', type='application/ld+json'):
                try:
                    data = json.loads(script.string)
                    if isinstance(data, list):
                        data = data[0] if data else {}
                    if data.get('@type') == 'Recipe':
                        # Found recipe JSON-LD
                        # Handle image field - can be string, list, or dict in JSON-LD
                        image_raw = data.get('image', '')
                        image_url = ''
                        if isinstance(image_raw, str):
                            image_url = image_raw
                        elif isinstance(image_raw, list) and len(image_raw) > 0:
                            # First item could be string or dict
                            first_img = image_raw[0]
                            if isinstance(first_img, str):
                                image_url = first_img
                            elif isinstance(first_img, dict):
                                image_url = first_img.get('url', '')
                        elif isinstance(image_raw, dict):
                            image_url = image_raw.get('url', '')
                        
                        result = {
                            'title': data.get('name', ''),
                            'ingredients': [i for i in data.get('recipeIngredient', []) if i],
                            'instructions': [],
                            'servings': None,
                            'prep_time': None,
                            'cook_time': None,
                            'total_time': None,
                            'image': image_url,
                            'site_link': url,
                            'source_url': url
                        }
                        # Love and Lemons: clean ingredient descriptions (remove text after dash or colon)
                        try:
                            from urllib.parse import urlparse as _urlp
                            host = (_urlp(url).netloc.lower() if url else '')
                            if 'loveandlemons.com' in host:
                                cleaned_ingredients = []
                                for ing in result['ingredients']:
                                    if isinstance(ing, str) and ing.strip():
                                        # Remove descriptions after dash or colon
                                        cleaned = ing.split(' - ')[0].split(':')[0].strip()
                                        cleaned = cleaned.split(' – ')[0].split(' — ')[0].strip()
                                        if cleaned and len(cleaned) > 2:
                                            cleaned_ingredients.append(cleaned)
                                result['ingredients'] = cleaned_ingredients
                        except Exception:
                            pass
                        # Taste of Home: always prefer page meta image over JSON-LD
                        try:
                            from urllib.parse import urlparse as _urlp
                            host = (_urlp(url).netloc.lower() if url else '')
                            if 'tasteofhome.com' in host:
                                picked = ''
                                for sel in ['meta[property="og:image:secure_url"]',
                                            'meta[property="og:image:url"]',
                                            'meta[property="og:image"]',
                                            'meta[name="twitter:image"]',
                                            'meta[name="twitter:image:src"]']:
                                    m = soup.select_one(sel)
                                    if m and m.get('content'):
                                        picked = m['content'].strip()
                                        break
                                if picked:
                                    if picked.startswith('//'):
                                        picked = 'https:' + picked
                                    if picked.startswith('http://'):
                                        picked = 'https:' + picked[5:]
                                    # Normalize extensions for iOS rendering
                                    try:
                                        from urllib.parse import urlparse as __up
                                        _p = __up(picked)
                                        _path = _p.path or ''
                                        _lower = _path.lower()
                                        if _lower.endswith('.webp'):
                                            picked = picked[:-5] + '.jpg'
                                        else:
                                            # If no extension after last '/', append .jpg
                                            _last = _path.rsplit('/', 1)[-1]
                                            if '.' not in _last:
                                                # keep query/fragment
                                                if '?' in picked or '#' in picked:
                                                    base = picked.split('?', 1)[0].split('#', 1)[0] + '.jpg'
                                                    tail = picked[len(picked.split('?', 1)[0].split('#', 1)[0]):]
                                                    picked = base + tail
                                                else:
                                                    picked = picked + '.jpg'
                                    except Exception:
                                        pass
                                    image_url = picked
                                result['image'] = image_url
                                print(f"LAMBDA/PARSE: ToH final image: {image_url}")
                        except Exception:
                            pass
                        # Try to parse servings from recipeYield / yield
                        try:
                            raw_yield = data.get('recipeYield') or data.get('yield')
                            serv = None
                            if isinstance(raw_yield, (int, float)):
                                serv = int(raw_yield)
                            elif isinstance(raw_yield, str):
                                ym = re.search(r'(\d+)(?:\s*[–-]\s*(\d+))?', raw_yield)
                                if ym:
                                    serv = int(ym.group(2) or ym.group(1))
                            if serv:
                                result['servings'] = serv
                        except Exception:
                            pass
                        # Parse prepTime, cookTime, and totalTime from JSON-LD (ISO 8601 duration format)
                        try:
                            # Parse prepTime (e.g., "PT30M" -> 30 minutes)
                            prep_time_raw = data.get('prepTime')
                            if prep_time_raw:
                                prep_time_minutes = parse_iso8601_duration(prep_time_raw)
                                if prep_time_minutes:
                                    result['prep_time'] = prep_time_minutes
                        except Exception:
                            pass
                        try:
                            # Parse cookTime (e.g., "PT1H30M" -> 90 minutes)
                            cook_time_raw = data.get('cookTime')
                            if cook_time_raw:
                                cook_time_minutes = parse_iso8601_duration(cook_time_raw)
                                if cook_time_minutes:
                                    result['cook_time'] = cook_time_minutes
                        except Exception:
                            pass
                        try:
                            # Parse totalTime (e.g., "PT2H" -> 120 minutes)
                            total_time_raw = data.get('totalTime')
                            if total_time_raw:
                                total_time_minutes = parse_iso8601_duration(total_time_raw)
                                if total_time_minutes:
                                    result['total_time'] = total_time_minutes
                        except Exception:
                            pass
                        # Extract instructions
                        for inst in data.get('recipeInstructions', []):
                            text = inst.get('text', '') if isinstance(inst, dict) else str(inst)
                            if text:
                                result['instructions'].append(text)
                        
                        # Check if JSON-LD has complete data
                        # If instructions are incomplete (< 3 steps), fall back to HTML parsing
                        json_ld_instructions = result.get('instructions', [])
                        has_complete_data = (
                            result['title'] and 
                            result['ingredients'] and 
                            len(json_ld_instructions) >= 3 and
                            all(len(inst.strip()) > 20 for inst in json_ld_instructions)  # Each step should be substantial
                        )
                        
                        if has_complete_data:
                            print(f"LAMBDA/PARSE: Using JSON-LD data (found {len(json_ld_instructions)} instructions)")
                            if html_source == 'print':
                                print("LAMBDA/PRINT: Using JSON-LD recipe; skipping print-page parsing")
                            
                            # Extract nutrition BEFORE returning (for AllRecipes and other sites)
                            # This ensures we capture nutrition data even when JSON-LD is complete
                            try:
                                nutrition = extract_nutrition_from_html(soup)
                                
                                # If nutrition section has servings info and JSON-LD servings is missing/invalid, use nutrition
                                if nutrition and nutrition.get('servings_from_nutrition'):
                                    try:
                                        servings_from_nutrition = int(nutrition['servings_from_nutrition'])
                                        if 2 <= servings_from_nutrition <= 50:
                                            # Only update if current servings is missing or invalid
                                            current_servings = result.get('servings')
                                            if not current_servings or current_servings < 2 or current_servings > 50:
                                                result['servings'] = servings_from_nutrition
                                                print(f"LAMBDA/PARSE: Updated servings from nutrition section: {servings_from_nutrition}")
                                    except (ValueError, TypeError):
                                        pass
                                
                                # If nutrition section has prep time and JSON-LD prep time is missing, use nutrition
                                if nutrition and nutrition.get('prep_time_from_nutrition'):
                                    try:
                                        prep_from_nutrition = int(nutrition['prep_time_from_nutrition'])
                                        if 1 <= prep_from_nutrition <= 600:
                                            # Only update if current prep_time is missing
                                            if not result.get('prep_time'):
                                                result['prep_time'] = prep_from_nutrition
                                                result['prep_time_minutes'] = prep_from_nutrition
                                                print(f"LAMBDA/PARSE: Updated prep_time from nutrition section: {prep_from_nutrition}")
                                    except (ValueError, TypeError):
                                        pass
                                
                                # If nutrition section has cook time and JSON-LD cook time is missing, use nutrition
                                if nutrition and nutrition.get('cook_time_from_nutrition'):
                                    try:
                                        cook_from_nutrition = int(nutrition['cook_time_from_nutrition'])
                                        if 1 <= cook_from_nutrition <= 600:
                                            # Only update if current cook_time is missing
                                            if not result.get('cook_time'):
                                                result['cook_time'] = cook_from_nutrition
                                                print(f"LAMBDA/PARSE: Updated cook_time from nutrition section: {cook_from_nutrition}")
                                    except (ValueError, TypeError):
                                        pass
                                
                                # Add nutrition to result if found
                                if nutrition:
                                    result['nutrition'] = nutrition
                                    result['nutrition_source'] = nutrition.get('source', 'html')
                                    print(f"LAMBDA/RESULT: Added nutrition to response - calories: {nutrition.get('calories')}, source: {nutrition.get('source', 'html')}")
                            except Exception as e:
                                print(f"LAMBDA/NUTRITION: Extraction failed (non-fatal): {e}")
                                # Continue without nutrition - don't break the flow
                            
                            return result
                        else:
                            # JSON-LD exists but instructions are incomplete - fall through to HTML parsing
                            # Store JSON-LD instructions to pass to HTML parser for deduplication
                            json_ld_instructions_for_dedup = json_ld_instructions.copy() if json_ld_instructions else []
                            if json_ld_instructions:
                                print(f"LAMBDA/PARSE: JSON-LD found but instructions incomplete ({len(json_ld_instructions)} steps), falling back to HTML parsing")
                            else:
                                print("LAMBDA/PARSE: JSON-LD found but no instructions, falling back to HTML parsing")
                            # Clear result so we don't use incomplete JSON-LD data
                            result = None
                except:
                    continue  # Try next script tag
        except:
            pass  # Fall through to HTML parsing
    
    # STEP 2a: Main-page JSON-LD fallback (print pages only)
    # If JSON-LD was not found in print HTML, try fetching main page
    json_ld_from_main_page = None
    if html_source == 'print' and not json_ld_instructions_for_dedup:
        try:
            # Derive main page URL by removing print indicators
            main_url = url
            # Remove common print indicators
            main_url = re.sub(r'/print/?$', '', main_url)
            main_url = re.sub(r'[?&]print=1', '', main_url)
            main_url = re.sub(r'[?&]output=1', '', main_url)
            main_url = re.sub(r'[?&]amp', '', main_url)
            main_url = re.sub(r'print/', '', main_url)
            # Clean up trailing ? or &
            main_url = re.sub(r'[?&]$', '', main_url)
            
            # Only fetch if URL changed (was a print URL)
            if main_url != url:
                print(f"LAMBDA/PRINT: JSON-LD missing in print; fetching main URL for JSON-LD: {main_url}")
                try:
                    # Fetch main page HTML
                    headers = {
                        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
                    }
                    main_response = requests.get(main_url, headers=headers, timeout=10)
                    if main_response.status_code == 200:
                        from bs4 import BeautifulSoup
                        main_soup = BeautifulSoup(main_response.text, 'html.parser')
                        
                        # Try JSON-LD extraction on main page
                        for script in main_soup.find_all('script', type='application/ld+json'):
                            try:
                                data = json.loads(script.string)
                                if isinstance(data, list):
                                    data = data[0] if data else {}
                                if data.get('@type') == 'Recipe':
                                    # Found recipe JSON-LD on main page
                                    json_ld_instructions_main = []
                                    for inst in data.get('recipeInstructions', []):
                                        text = inst.get('text', '') if isinstance(inst, dict) else str(inst)
                                        if text:
                                            json_ld_instructions_main.append(text)
                                    
                                    # Validate JSON-LD from main page
                                    has_complete_data = (
                                        data.get('name') and 
                                        data.get('recipeIngredient') and 
                                        len(json_ld_instructions_main) >= 3 and
                                        all(len(inst.strip()) > 20 for inst in json_ld_instructions_main)
                                    )
                                    
                                    if has_complete_data:
                                        print("LAMBDA/PRINT: JSON-LD found on main URL; using JSON-LD result")
                                        # Build result from main page JSON-LD
                                        image_raw = data.get('image', '')
                                        image_url = ''
                                        if isinstance(image_raw, str):
                                            image_url = image_raw
                                        elif isinstance(image_raw, list) and len(image_raw) > 0:
                                            first_img = image_raw[0]
                                            if isinstance(first_img, str):
                                                image_url = first_img
                                            elif isinstance(first_img, dict):
                                                image_url = first_img.get('url', '')
                                        elif isinstance(image_raw, dict):
                                            image_url = image_raw.get('url', '')
                                        
                                        json_ld_from_main_page = {
                                            'title': data.get('name', ''),
                                            'ingredients': [i for i in data.get('recipeIngredient', []) if i],
                                            'instructions': json_ld_instructions_main,
                                            'servings': None,
                                            'prep_time': None,
                                            'cook_time': None,
                                            'total_time': None,
                                            'image': image_url,
                                            'site_link': url,
                                            'source_url': url
                                        }
                                        
                                        # Parse servings
                                        try:
                                            raw_yield = data.get('recipeYield') or data.get('yield')
                                            if isinstance(raw_yield, (int, float)):
                                                json_ld_from_main_page['servings'] = int(raw_yield)
                                            elif isinstance(raw_yield, str):
                                                ym = re.search(r'(\d+)(?:\s*[–-]\s*(\d+))?', raw_yield)
                                                if ym:
                                                    json_ld_from_main_page['servings'] = int(ym.group(2) or ym.group(1))
                                        except:
                                            pass
                                        
                                        # Parse times
                                        try:
                                            prep_time_raw = data.get('prepTime')
                                            if prep_time_raw:
                                                prep_time_minutes = parse_iso8601_duration(prep_time_raw)
                                                if prep_time_minutes:
                                                    json_ld_from_main_page['prep_time'] = prep_time_minutes
                                        except:
                                            pass
                                        try:
                                            cook_time_raw = data.get('cookTime')
                                            if cook_time_raw:
                                                cook_time_minutes = parse_iso8601_duration(cook_time_raw)
                                                if cook_time_minutes:
                                                    json_ld_from_main_page['cook_time'] = cook_time_minutes
                                        except:
                                            pass
                                        try:
                                            total_time_raw = data.get('totalTime')
                                            if total_time_raw:
                                                total_time_minutes = parse_iso8601_duration(total_time_raw)
                                                if total_time_minutes:
                                                    json_ld_from_main_page['total_time'] = total_time_minutes
                                        except:
                                            pass
                                        
                                        # Return early with JSON-LD from main page
                                        return json_ld_from_main_page
                            except:
                                continue
                except Exception as e:
                    print(f"LAMBDA/PRINT: Failed to fetch main page: {str(e)}")
                    pass  # Fall through to print parsing
        
        except Exception as e:
            print(f"LAMBDA/PRINT: Main page JSON-LD fallback error: {str(e)}")
            pass  # Fall through to print parsing
    
    # STEP 2b: Print page section extraction (only if JSON-LD was not used)
    # Only run print-page parsing if JSON-LD is missing or invalid
    if html_source == 'print':
        # Check if we already have valid JSON-LD data (would have returned early above)
        # If we reach here, JSON-LD was either missing or incomplete
        print("LAMBDA/PRINT: JSON-LD still missing; using print parsing")
        try:
            ingredient_sections_raw = extract_print_page_ingredient_sections(soup)
            instruction_groups_raw = extract_print_page_instruction_groups(soup)
            recipe_notes_raw = extract_print_page_notes(soup)
            
            if ingredient_sections_raw:
                print(f"LAMBDA/PRINT: Detected {len(ingredient_sections_raw)} ingredient sections")
                for section in ingredient_sections_raw:
                    print(f"LAMBDA/PRINT: Section '{section['name']}': {len(section['ingredients'])} ingredients")
            if instruction_groups_raw:
                print(f"LAMBDA/PRINT: Detected {len(instruction_groups_raw)} instruction groups")
            if recipe_notes_raw:
                print(f"LAMBDA/PRINT: Captured recipe notes (length: {len(recipe_notes_raw)})")
        except Exception as e:
            print(f"LAMBDA/PRINT: Section extraction failed, falling back: {str(e)}")
            # Fallback silently - continue with existing logic
    
    # Check if this is Barefoot Contessa - use site-specific parser
    if is_barefootcontessa:
        print(f"LAMBDA/PARSE: detected Barefoot Contessa domain={domain}, using site-specific parser")
        barefoot_result = extract_barefootcontessa(soup, url)
        if barefoot_result and len(barefoot_result.get('ingredients', [])) >= 2:
            # Site-specific parser found data, use it
            ing_count = len(barefoot_result.get('ingredients', []))
            inst_count = len(barefoot_result.get('instructions', []))
            print(f"LAMBDA/PARSE: Barefoot Contessa parser SUCCESS - found {ing_count} ingredients, {inst_count} instructions")
            # Use site-specific ingredients and instructions
            title = extract_title(soup)  # Title works fine, keep generic
            ingredients = barefoot_result.get('ingredients', [])
            instructions = barefoot_result.get('instructions', [])
            # Title, servings, prep_time, image work fine - use generic extractors
            servings = extract_servings(soup)
            prep_time = extract_prep_time(soup)
            image = extract_image(soup, url)
            source_url = barefoot_result.get('source_url') or url
        else:
            # Parser didn't find enough data, fall back to generic
            if barefoot_result:
                ing_count = len(barefoot_result.get('ingredients', []))
                print(f"LAMBDA/PARSE: Barefoot Contessa parser found only {ing_count} ingredients (< 2 required), falling back to generic")
            else:
                print("LAMBDA/PARSE: Barefoot Contessa parser returned None, falling back to generic extraction")
            title = extract_title(soup)
            ingredients = extract_ingredients(soup)
            instructions = extract_instructions(soup, existing_instructions=json_ld_instructions_for_dedup if json_ld_instructions_for_dedup else None)
            servings = extract_servings(soup)
            prep_time = extract_prep_time(soup)
            image = extract_image(soup, url)
            source_url = url
    # Check if this is Food Network - use site-specific parser
    elif is_foodnetwork:
        print(f"LAMBDA/PARSE: detected Food Network domain={domain}, using site-specific parser")
        foodnetwork_result = extract_foodnetwork(soup, url)
        if foodnetwork_result and foodnetwork_result.get('ingredients'):
            # Food Network parser found data, use it
            ing_count = len(foodnetwork_result.get('ingredients', []))
            inst_count = len(foodnetwork_result.get('instructions', []))
            print(f"LAMBDA/PARSE: Food Network parser SUCCESS - found {ing_count} ingredients, {inst_count} instructions")
            # Merge with generic extraction for missing fields
            title = foodnetwork_result.get('title') or extract_title(soup)
            ingredients = foodnetwork_result.get('ingredients', [])
            instructions = foodnetwork_result.get('instructions', [])
            # Use Food Network extracted servings/prep_time if available
            servings = foodnetwork_result.get('servings') or extract_servings(soup)
            prep_time = foodnetwork_result.get('prep_time_minutes') or extract_prep_time(soup)
            # Use Food Network extracted image if available
            image = foodnetwork_result.get('image') or extract_image(soup, url)
            # Get source_url from Food Network result
            source_url = foodnetwork_result.get('source_url') or url
        else:
            # Food Network parser didn't find data, fall back to generic
            if foodnetwork_result:
                ing_count = len(foodnetwork_result.get('ingredients', []))
                print(f"LAMBDA/PARSE: Food Network parser found only {ing_count} ingredients (< 2 required), falling back to generic")
            else:
                print("LAMBDA/PARSE: Food Network parser returned None, falling back to generic extraction")
            title = extract_title(soup)
            ingredients = extract_ingredients(soup)
            instructions = extract_instructions(soup)
            # Extract servings, prep time, image for fallback case
            servings = extract_servings(soup)
            prep_time = extract_prep_time(soup)
            image = extract_image(soup, url)
            source_url = url
    # Check if this is Food & Wine - use site-specific parser
    elif is_foodandwine:
        print(f"LAMBDA/PARSE: detected Food & Wine domain={domain}, using site-specific parser")
        foodandwine_result = extract_foodandwine(soup, url)
        if foodandwine_result and foodandwine_result.get('ingredients'):
            # Food & Wine parser found data, use it
            ing_count = len(foodandwine_result.get('ingredients', []))
            inst_count = len(foodandwine_result.get('instructions', []))
            print(f"LAMBDA/PARSE: Food & Wine parser SUCCESS - found {ing_count} ingredients, {inst_count} instructions")
            # Merge with generic extraction for missing fields
            title = foodandwine_result.get('title') or extract_title(soup)
            ingredients = foodandwine_result.get('ingredients', [])
            instructions = foodandwine_result.get('instructions', [])
            # Use Food & Wine extracted servings/prep_time if available
            servings = foodandwine_result.get('servings') or extract_servings(soup)
            prep_time = foodandwine_result.get('prep_time') or extract_prep_time(soup)
            # Use Food & Wine extracted image if available
            image = foodandwine_result.get('image') or extract_image(soup, url)
            # Get source_url from Food & Wine result
            source_url = foodandwine_result.get('source_url') or url
        else:
            # Food & Wine parser didn't find data, fall back to generic
            if foodandwine_result:
                ing_count = len(foodandwine_result.get('ingredients', []))
                print(f"LAMBDA/PARSE: Food & Wine parser found only {ing_count} ingredients (< 2 required), falling back to generic")
            else:
                print("LAMBDA/PARSE: Food & Wine parser returned None, falling back to generic extraction")
            title = extract_title(soup)
            ingredients = extract_ingredients(soup)
            instructions = extract_instructions(soup)
            # Extract servings, prep time, image for fallback case
            servings = extract_servings(soup)
            prep_time = extract_prep_time(soup)
            image = extract_image(soup, url)
            source_url = url
    # Check if this is Love and Lemons - use site-specific parser
    elif is_loveandlemons:
        print(f"LAMBDA/PARSE: detected Love and Lemons domain={domain}, using site-specific parser")
        loveandlemons_result = extract_loveandlemons(soup, url)
        if loveandlemons_result and len(loveandlemons_result.get('ingredients', [])) >= 2:
            # Love and Lemons parser found data, use it
            ing_count = len(loveandlemons_result.get('ingredients', []))
            inst_count = len(loveandlemons_result.get('instructions', []))
            print(f"LAMBDA/PARSE: Love and Lemons parser SUCCESS - found {ing_count} ingredients, {inst_count} instructions")
            # Merge with generic extraction for missing fields
            title = loveandlemons_result.get('title') or extract_title(soup)
            ingredients = loveandlemons_result.get('ingredients', [])
            instructions = loveandlemons_result.get('instructions', [])
            # Use Love and Lemons extracted servings/prep_time/cook_time if available
            servings = loveandlemons_result.get('servings') or extract_servings(soup)
            prep_time = loveandlemons_result.get('prep_time') or extract_prep_time(soup)
            cook_time = loveandlemons_result.get('cook_time')
            total_time = loveandlemons_result.get('total_time')
            # Use Love and Lemons extracted image if available
            image = loveandlemons_result.get('image') or extract_image(soup, url)
            # Get source_url from Love and Lemons result
            source_url = loveandlemons_result.get('source_url') or url
        else:
            # Love and Lemons parser didn't find data, fall back to generic
            if loveandlemons_result:
                ing_count = len(loveandlemons_result.get('ingredients', []))
                print(f"LAMBDA/PARSE: Love and Lemons parser found only {ing_count} ingredients (< 2 required), falling back to generic")
            else:
                print("LAMBDA/PARSE: Love and Lemons parser returned None, falling back to generic extraction")
            title = extract_title(soup)
            ingredients = extract_ingredients(soup)
            instructions = extract_instructions(soup, existing_instructions=json_ld_instructions_for_dedup if json_ld_instructions_for_dedup else None)
            # Extract servings, prep time, image for fallback case
            servings = extract_servings(soup)
            prep_time = extract_prep_time(soup)
            image = extract_image(soup, url)
            source_url = url
    else:
        # Generic extraction for all other sites
        # Extract title
        title = extract_title(soup)
        
        # STEP 4: Extract ingredients - use sections if detected for print pages, otherwise use existing logic
        # Only use sections if this is a print page AND sections were successfully extracted
        # Site-specific parsers take priority, so sections are only used for generic extraction
        if html_source == 'print' and ingredient_sections_raw:
            # Flatten sections into flat ingredients list for compatibility
            ingredients = []
            for section in ingredient_sections_raw:
                ingredients.extend(section['ingredients'])
            print(f"LAMBDA/PRINT: Using {len(ingredients)} ingredients from {len(ingredient_sections_raw)} sections")
        else:
            # Use existing extraction logic (site-specific or generic)
            ingredients = extract_ingredients(soup)
        
        # STEP 5: Extract instructions - use groups if detected for print pages, otherwise use existing logic
        if html_source == 'print' and instruction_groups_raw:
            # Flatten instruction groups into flat instructions list for compatibility
            instructions = []
            for group in instruction_groups_raw:
                instructions.extend(group['steps'])
            print(f"LAMBDA/PRINT: Using {len(instructions)} instructions from {len(instruction_groups_raw)} groups")
        else:
            # Use existing extraction logic (pass JSON-LD instructions for deduplication if available)
            instructions = extract_instructions(soup, existing_instructions=json_ld_instructions_for_dedup if json_ld_instructions_for_dedup else None)
        
        # Extract servings, prep time, image
        servings = extract_servings(soup)
        prep_time = extract_prep_time(soup)
        image = extract_image(soup, url)
        source_url = url
    
    # Extract nutrition from page
    nutrition = None
    cook_time = None  # Initialize cook_time variable
    total_time = None  # Initialize total_time variable
    try:
        nutrition = extract_nutrition_from_html(soup)
        
        # If nutrition was found, check if values are per-recipe (too high) or per-serving
        if nutrition and servings and servings > 1:
            calories_val = nutrition.get('calories')
            if calories_val:
                try:
                    calories_float = float(calories_val)
                    # If calories are suspiciously high (>1000), they might be per-recipe
                    # Otherwise, assume they're already per-serving (most recipe sites show per-serving)
                    if calories_float > 1000:
                        print(f"LAMBDA/NUTRITION: High calories ({calories_float}) detected, assuming per-recipe, dividing by {servings} servings")
                        # Divide all numeric values by servings
                        nutrients_to_divide = ['calories', 'protein', 'carbohydrates', 'fat', 'saturated_fat', 
                                              'fiber', 'sugar', 'sodium', 'cholesterol', 'potassium', 'calcium', 
                                              'iron', 'vitamin_a', 'vitamin_c', 'vitamin_d', 'vitamin_e', 'vitamin_k',
                                              'vitamin_b6', 'vitamin_b12', 'thiamin', 'magnesium', 'zinc', 'selenium',
                                              'copper', 'manganese', 'choline', 'iodine', 'folate']
                        for key in nutrients_to_divide:
                            if nutrition.get(key):
                                try:
                                    val = float(nutrition[key])
                                    nutrition[key] = str(int(val / servings))
                                except (ValueError, TypeError):
                                    pass
                    else:
                        print(f"LAMBDA/NUTRITION: Calories ({calories_float}) appear to be per-serving, not dividing")
                except (ValueError, TypeError):
                    pass
        
        # If nutrition section has servings info and current servings is missing/invalid, use nutrition
        if nutrition and nutrition.get('servings_from_nutrition'):
            try:
                servings_from_nutrition = int(nutrition['servings_from_nutrition'])
                if 2 <= servings_from_nutrition <= 50:
                    # Only update if current servings is missing or invalid
                    if not servings or servings < 2 or servings > 50:
                        servings = servings_from_nutrition
                        print(f"LAMBDA/PARSE: Updated servings from nutrition section: {servings}")
            except (ValueError, TypeError):
                pass
        
        # If nutrition section has prep time and current prep_time is missing, use nutrition
        if nutrition and nutrition.get('prep_time_from_nutrition'):
            try:
                prep_from_nutrition = int(nutrition['prep_time_from_nutrition'])
                if 1 <= prep_from_nutrition <= 600:
                    # Only update if current prep_time is missing
                    if not prep_time:
                        prep_time = prep_from_nutrition
                        print(f"LAMBDA/PARSE: Updated prep_time from nutrition section: {prep_time}")
            except (ValueError, TypeError):
                pass
        
        # If nutrition section has cook time, extract it
        if nutrition and nutrition.get('cook_time_from_nutrition'):
            try:
                cook_from_nutrition = int(nutrition['cook_time_from_nutrition'])
                if 1 <= cook_from_nutrition <= 600:
                    cook_time = cook_from_nutrition
                    print(f"LAMBDA/PARSE: Found cook_time from nutrition section: {cook_time}")
            except (ValueError, TypeError):
                pass
    except Exception as e:
        print(f"LAMBDA/NUTRITION: Extraction failed: {e}")
        nutrition = None
    
    result = {
        'title': title,
        'ingredients': ingredients,
        'instructions': instructions,
        'servings': servings,
        'prep_time': prep_time,
        'cook_time': cook_time if cook_time else '',  # Use cook_time if found, otherwise empty string
        'total_time': total_time if total_time else '',  # Use total_time if found, otherwise empty string
        'image': image,
        'site_link': url,
        'source_url': source_url,
        'site_name': extract_site_name(url),
        'quality_score': 0.0,
        'metadata': {
            'full_recipe': len(ingredients) >= 3 and len(instructions) >= 3
        }
    }
    
    # Add nutrition if found
    if nutrition:
        result['nutrition'] = nutrition
        result['nutrition_source'] = nutrition.get('source', 'html')
        print(f"LAMBDA/RESULT: Added nutrition to response - calories: {nutrition.get('calories')}, source: {nutrition.get('source', 'html')}")
    else:
        print("LAMBDA/RESULT: No nutrition data to add to response")
    
    # STEP 2: Add print page sections (if extracted earlier)
    if html_source == 'print':
        if ingredient_sections_raw:
            result['ingredient_sections'] = ingredient_sections_raw
        if instruction_groups_raw:
            result['instruction_groups'] = instruction_groups_raw
        if recipe_notes_raw:
            result['recipe_notes'] = recipe_notes_raw
        
        # Verify notes are NOT in ingredients/instructions
        ing_count = len(result.get('ingredients', []))
        inst_count = len(result.get('instructions', []))
        notes_len = len(result.get('recipe_notes', '')) if isinstance(result.get('recipe_notes'), str) else 0
        print(f"LAMBDA/PRINT: final counts ingredients={ing_count} instructions={inst_count} notes_len={notes_len}")
    
    return result

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

def extract_instructions(soup, existing_instructions=None):
    """Extract cooking instructions with better filtering and deduplication"""
    instructions = []
    seen_instructions = set()  # Track seen instructions to avoid duplicates (normalized)
    
    # Add existing instructions to seen set (if provided) to prevent duplicates
    if existing_instructions:
        for existing in existing_instructions:
            normalized = existing.strip().lower()
            # Remove common prefixes/suffixes for comparison
            normalized = re.sub(r'^\d+[\.\)]\s*', '', normalized)  # Remove leading numbers
            normalized = re.sub(r'\s+', ' ', normalized).strip()  # Normalize whitespace
            seen_instructions.add(normalized)
            instructions.append(existing)  # Keep original formatting
    
    # Skip words that indicate non-instruction content
    skip_words = [
        'ingredients', 'ingredient', 'linda c', 'by linda', 'submitted by', 
        'recipe by', 'author', 'review', 'rating', 'stars', 'votes',
        'nutrition', 'calories', 'fat', 'protein', 'carbs', 'fiber',
        'sugar', 'sodium', 'cholesterol', 'serves', 'yield', 'prep time',
        'cook time', 'total time', 'difficulty', 'skill level'
    ]
    
    # Try multiple selectors for instructions (including AllRecipes-specific)
    selectors = [
        # AllRecipes-specific selectors (add first for priority)
        '[data-testid="instruction-step"]',
        '[data-testid="instruction-step"] p',
        '.mntl-sc-block-group--OL li',
        '.mntl-sc-block-group--OL p',
        '[class*="mntl-sc-block"] li[class*="instruction"]',
        '[class*="mntl-sc-block"] p[class*="instruction"]',
        # Generic selectors
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
                    # Normalize text for duplicate checking
                    normalized_text = text.strip().lower()
                    normalized_text = re.sub(r'^\d+[\.\)]\s*', '', normalized_text)  # Remove leading numbers
                    normalized_text = re.sub(r'\s+', ' ', normalized_text).strip()  # Normalize whitespace
                    
                    # Check if this looks like an instruction (starts with action words)
                    if any(action in text_lower for action in ['heat', 'add', 'mix', 'stir', 'cook', 'bake', 'fry', 'boil', 'simmer', 'preheat', 'place', 'put', 'combine', 'blend', 'whisk', 'beat', 'fold', 'pour', 'drain', 'remove', 'serve']):
                        if normalized_text not in seen_instructions and len(normalized_text) > 10:
                            instructions.append(text)
                            seen_instructions.add(normalized_text)
                    elif text[0].isdigit() or text.startswith(('1.', '2.', '3.', '4.', '5.', '6.', '7.', '8.', '9.')):
                        if normalized_text not in seen_instructions and len(normalized_text) > 10:
                            instructions.append(text)
                            seen_instructions.add(normalized_text)
                    elif len(text.split()) > 5:  # Longer text is likely an instruction
                        if normalized_text not in seen_instructions and len(normalized_text) > 10:
                            instructions.append(text)
                            seen_instructions.add(normalized_text)
        
        # Continue collecting from all selectors - don't break early
        # This ensures we get ALL instructions, not just the first 5
    
    # If we have very few instructions (< 3), try to find ordered list as fallback
    if len(instructions) < 3:
        for ol in soup.find_all('ol'):
            for li in ol.find_all('li'):
                text = li.get_text().strip()
                if text and len(text) > 10:
                    text_lower = text.lower()
                    if not any(skip in text_lower for skip in skip_words):
                        # Normalize text for duplicate checking
                        normalized_text = text.strip().lower()
                        normalized_text = re.sub(r'^\d+[\.\)]\s*', '', normalized_text)  # Remove leading numbers
                        normalized_text = re.sub(r'\s+', ' ', normalized_text).strip()  # Normalize whitespace
                        if normalized_text not in seen_instructions and len(normalized_text) > 10:
                            instructions.append(text)
                            seen_instructions.add(normalized_text)
    
    # Also try to find any numbered steps in paragraphs if we still have few instructions
    if len(instructions) < 3:
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
    
    return instructions[:30]  # Limit to 30 steps (increased from 15 to capture longer recipes)

def extract_foodnetwork(soup, url=''):
    """FoodNetwork.com specific extraction using their class structure"""
    result = {}
    
    # Set source URL
    if url:
        result['source_url'] = url
    
    # Title
    title_elem = soup.select_one('h1.o-AssetTitle__a-Headline')
    if title_elem:
        result['title'] = title_elem.get_text(strip=True)
        print(f"LAMBDA/FN: found title={result['title'][:50]}")
    else:
        print("LAMBDA/FN: no title found with selector 'h1.o-AssetTitle__a-Headline'")
    
    # Ingredients - try multiple selectors (order matters - try specific ones first)
    ingredients = []
    ingredient_selectors = [
        '.o-Ingredients__a-ListItemText',
        '.o-Ingredients__a-ListItem',
        'p.o-Ingredients__a-Ingredient',
        '.ingredients-list li',
        '.ingredients li',
        '[data-testid="ingredients-list"] li'
    ]
    
    for selector in ingredient_selectors:
        ingredient_elements = soup.select(selector)
        found_count = len(ingredient_elements)
        if found_count > 0:
            print(f"LAMBDA/FN: selector '{selector}' found {found_count} elements")
            for elem in ingredient_elements:
                text = elem.get_text(strip=True)
                if text and len(text) > 2 and len(text) < 200:
                    # Remove step numbers from ingredients
                    text = re.sub(r'^(Step \d+:\s*|\d+\.\s*)', '', text)
                    # Filter out non-ingredient text
                    text_lower = text.lower()
                    skip_words = ['recipe', 'food network', 'cooking', 'prep time', 'cook time', 'total time', 'servings', 'yield', 
                                  'deselect all', 'select all', 'ingredients:', 'ingredient:']
                    if not any(word in text_lower for word in skip_words):
                        # Additional check: skip if it's just "Deselect All" or similar
                        if text_lower.strip() not in ['deselect all', 'select all']:
                            ingredients.append(text)
            if ingredients:
                print(f"LAMBDA/FN: successfully extracted {len(ingredients)} ingredients using selector '{selector}'")
                break
        else:
            print(f"LAMBDA/FN: selector '{selector}' found 0 elements")
    
    if not ingredients:
        print("LAMBDA/FN: WARNING - no ingredients found with any selector")
    
    result['ingredients'] = ingredients
    
    # Instructions - try multiple selectors
    instructions = []
    instruction_selectors = [
        '.o-Method__m-StepText',
        '.o-Method__m-Step',
        'li.o-Method__m-Step',
        '.directions li',
        '.instructions li',
        '[data-testid="instructions-list"] li',
        '.recipe-instructions li',
        '.method li'
    ]
    
    for selector in instruction_selectors:
        instruction_elements = soup.select(selector)
        if instruction_elements:
            for elem in instruction_elements:
                text = elem.get_text(strip=True)
                # Remove step numbers
                text = re.sub(r'^(Step \d+:\s*|\d+\.\s*)', '', text)
                if text and len(text) > 10:
                    instructions.append(text)
            if instructions:
                break
    
    result['instructions'] = instructions
    
    # Extract servings/yield from Food Network specific elements
    servings = None
    servings_selectors = [
        '.o-RecipeInfo__m-Yield',
        '.o-RecipeInfo__a-Headline',
        '[class*="yield"]',
        '[class*="servings"]'
    ]
    for selector in servings_selectors:
        servings_elem = soup.select_one(selector)
        if servings_elem:
            servings_text = servings_elem.get_text(strip=True)
            # Try to extract number from text like "Serves 4" or "Yield: 4 servings"
            servings_match = re.search(r'(\d+)', servings_text)
            if servings_match:
                servings = int(servings_match.group(1))
                print(f"LAMBDA/FN: found servings={servings} from selector '{selector}'")
                break
    
    if servings:
        result['servings'] = servings
    
    # Extract prep time using existing function (better than generic)
    prep_time = extract_prep_time(soup)
    if prep_time:
        result['prep_time_minutes'] = prep_time
        print(f"LAMBDA/FN: found prep_time={prep_time} minutes")
    
    # Extract image with better filtering for Food Network
    image = None
    image_selectors = [
        '.o-AssetTitle__a-Image img',
        '.o-AssetTitle__a-Image',
        '.recipe-image img',
        'meta[property="og:image"]',
        'meta[name="twitter:image"]'
    ]
    
    # Filter words to skip in image URLs
    image_filters = [
        'promo', 'advertisement', 'ad', 'related', 'gallery', 'thumbnail',
        'sidebar', 'recommended', 'you-may-like', 'similar', 'trending',
        'sponsor', 'partner', 'banner', 'promotional'
    ]
    
    for selector in image_selectors:
        if selector.startswith('meta'):
            image_elem = soup.select_one(selector)
            if image_elem and image_elem.get('content'):
                img_url = image_elem['content']
                # Check if image URL contains filter words
                if not any(filter_word in img_url.lower() for filter_word in image_filters):
                    image = img_url
                    print(f"LAMBDA/FN: found image from meta tag: {img_url[:60]}...")
                    break
        else:
            image_elem = soup.select_one(selector)
            if image_elem:
                if image_elem.name == 'img':
                    src = image_elem.get('src') or image_elem.get('data-src')
                else:
                    img = image_elem.find('img')
                    if img:
                        src = img.get('src') or img.get('data-src')
                    else:
                        src = None
                
                if src:
                    # Skip filtered images
                    if any(filter_word in src.lower() for filter_word in image_filters):
                        continue
                    
                    # Make sure it's a full URL
                    if src.startswith('//'):
                        src = 'https:' + src
                    elif src.startswith('/'):
                        src = 'https://www.foodnetwork.com' + src
                    
                    image = src
                    print(f"LAMBDA/FN: found image: {src[:60]}...")
                    break
    
    if image:
        result['image'] = image
    else:
        print("LAMBDA/FN: no valid image found after filtering")
    
    # Log final result
    ing_count = len(result.get('ingredients', []))
    inst_count = len(result.get('instructions', []))
    print(f"LAMBDA/FN: final result - {ing_count} ingredients, {inst_count} instructions, servings={servings}, prep_time={prep_time}")
    
    # Only return if we found ingredients
    if ing_count >= 2:
        print("LAMBDA/FN: returning result (ingredients >= 2)")
        return result
    else:
        print(f"LAMBDA/FN: returning None (only {ing_count} ingredients, need >= 2)")
        return None

def extract_barefootcontessa(soup, url=''):
    """BarefootContessa.com specific extraction - filters navigation items from ingredients and copyright from instructions"""
    result = {}
    
    if url:
        result['source_url'] = url
    
    # Ingredients - filter out navigation items (Recipes, Books, Cookbook Index, etc.)
    ingredients = []
    ingredient_selectors = [
        '.recipe-ingredients li',
        '.ingredients-list li',
        '[class*="ingredient"] li',
        '.ingredient-item',
        'li',  # Fallback - will filter heavily
        'p'    # Fallback - will filter heavily
    ]
    
    # Navigation/category words that should be filtered from ingredients
    skip_words = [
        'recipes', 'books', 'cookbook index', 'tv & events', "ina's world",
        'shop', 'goldbelly', 'cocktails', 'starters', 'lunch', 'dinner',
        'sides', 'dessert', 'breakfast', 'categories', 'tags', 'navigation',
        'menu', 'about', 'ask ina', 'instagram', 'cooking', 'out & about',
        'entertaining', 'baking', 'gardens', 'contact us', 'email sign-up',
        'facebook', 'youtube', 'pinterest', 'privacy policy', 'terms',
        'conditions', 'copyright', 'rights reserved', 'from the cookbook',
        'go-to dinners', 'clarkson potter', 'publishers'
    ]
    
    seen_ingredients = set()
    
    # Try all selectors and collect ALL ingredients (don't break early)
    for selector in ingredient_selectors:
        elements = soup.select(selector)
        if elements:
            # Collect all text first, then join fragments intelligently
            consumed_indices = set()
            for i, elem in enumerate(elements):
                if i in consumed_indices:
                    continue
                text = elem.get_text(strip=True)
                if text and 5 < len(text) < 300:  # Increased max for joined ingredients
                    # Try to join with next element if it looks like a continuation
                    if i < len(elements) - 1 and (i + 1) not in consumed_indices:
                        next_elem = elements[i + 1]
                        next_text = next_elem.get_text(strip=True)
                        next_lower = next_text.lower()
                        # If current ends without punctuation and next doesn't start with number/measurement, might be continuation
                        if (not text.endswith('.') and not text.endswith(',') and 
                            len(text) < 80 and len(next_text) > 0 and
                            not next_text[0].isdigit() and 
                            not any(indicator in next_lower[:10] for indicator in ['cup', 'tablespoon', 'teaspoon', 'pound', 'ounce', '½', '¾', '¼'])):
                            # Check if they look related (next starts with lowercase or is short fragment)
                            if next_text[0].islower() or len(next_text) < 40:
                                text = text + " " + next_text
                                consumed_indices.add(i + 1)
                    
                    text_lower = text.lower()
                    # Filter out navigation/category text
                    if any(skip in text_lower for skip in skip_words):
                        continue
                    # Filter out instruction-like text (starts with OR contains action words/phrases)
                    instruction_starters = [
                        'preheat', 'heat', 'add', 'mix', 'stir', 'cook', 'bake',
                        'discard', 'transfer', 'return', 'spread', 'tie', 'bring',
                        'cover', 'separate', 'pull', 'spoon', 'sprinkle', 'cool',
                        'dry', 'place', 'turn', 'sauté', 'allow', 'check', 'using'
                    ]
                    # Check if text STARTS with instruction (most common case)
                    if any(text_lower.startswith(starter) for starter in instruction_starters):
                        continue
                    # Also check if text CONTAINS instruction patterns (catches joined fragments like "X Preheat...")
                    # If text ends with instruction words or contains instruction phrases, likely an instruction, not ingredient
                    if any(text_lower.endswith(f' {starter}') or f' {starter} ' in text_lower for starter in instruction_starters):
                        # But allow if it's clearly an ingredient (has measurements/food words and is short)
                        has_ingredient_indicators = any(indicator in text_lower for indicator in [
                            'cup', 'cups', 'tablespoon', 'teaspoon', 'pound', 'ounce', 'lb', 'oz', 'gram', 'ml',
                            'flour', 'sugar', 'salt', 'pepper', 'oil', 'butter', 'milk', 'egg', 'chicken'
                        ])
                        # If it's long (>60 chars) and contains instruction words, it's likely an instruction
                        if len(text) > 60 or not has_ingredient_indicators:
                            continue
                    # Must look like an ingredient (has measurement or food word)
                    if any(indicator in text_lower for indicator in [
                        'cup', 'cups', 'tablespoon', 'tablespoons', 'teaspoon', 'teaspoons',
                        'tbsp', 'tsp', 'pound', 'pounds', 'ounce', 'ounces', 'lb', 'oz',
                        'gram', 'grams', 'ml', 'flour', 'sugar', 'salt', 'pepper', 'oil',
                        'butter', 'milk', 'egg', 'eggs', 'cheese', 'chicken', 'beef', 'fish',
                        'vegetable', 'herb', 'spice', 'cloves', 'clove', 'whole', 'diced',
                        'chopped', 'minced', 'sprigs', 'fresh', 'kosher', 'ground', 'black',
                        'scrubbed', 'ribs', 'bulb', 'threads', 'stock', 'water', 'degrees',
                        'sticks', 'vanilla', 'extract', 'jam', 'peanuts', 'bars', 'room',
                        'temperature', 'pan', 'attachment', 'bowl', 'baking'
                    ]):
                        # Remove leading numbers/step markers
                        text = re.sub(r'^(Step \d+:\s*|\d+\.\s*)', '', text)
                        if text and text.lower() not in seen_ingredients:
                            ingredients.append(text)
                            seen_ingredients.add(text.lower())
    # Don't break - collect from all selectors
    
    result['ingredients'] = ingredients
    
    # Instructions - keep as full paragraphs, filter copyright
    # First collect all potential instruction fragments
    instruction_fragments = []
    instruction_selectors = [
        '.recipe-instructions p',
        '.instructions-list p',
        '[class*="instruction"] p',
        '.instruction-step',
        '.recipe-directions p',
        '.directions p'
    ]
    
    # Collect fragments from specific selectors
    for selector in instruction_selectors:
        elements = soup.select(selector)
        if elements:
            for elem in elements:
                text = elem.get_text(strip=True)
                if text and len(text) > 15:
                    text_lower = text.lower()
                    # Filter copyright text
                    if 'copyright' in text_lower or 'rights reserved' in text_lower:
                        continue
                    # Filter other non-instruction text
                    if any(skip in text_lower for skip in [
                        'recipes', 'books', 'cookbook', 'navigation', 'menu',
                        'about', 'shop', 'goldbelly', 'tags', 'share', 'newsletter'
                    ]):
                        continue
                    # Must look like an instruction
                    if (any(action in text_lower for action in [
                        'preheat', 'heat', 'add', 'mix', 'stir', 'cook', 'bake',
                        'fry', 'boil', 'simmer', 'place', 'put', 'combine', 'blend',
                        'whisk', 'beat', 'fold', 'pour', 'drain', 'remove', 'serve',
                        'transfer', 'discard', 'tie', 'bring', 'cover', 'bake',
                        'separate', 'pull', 'reheat', 'spoon', 'sprinkle', 'dry',
                        'sear', 'sauté', 'allow', 'check', 'using', 'spread', 'cream',
                        'grease', 'sift', 'slowly', 'drop', 'worry', 'cut', 'cool'
                    ]) or len(text.split()) > 8):
                        # Remove step numbers if present at start
                        text = re.sub(r'^\d+\.\s*', '', text)
                        instruction_fragments.append(text)
    
    # Also try paragraphs as fallback (always run to catch plain <p> tags)
    # But only if we didn't find enough fragments from specific selectors
    if len(instruction_fragments) < 3:
        for p in soup.find_all('p'):
            text = p.get_text(strip=True)
            if text and len(text) > 25:
                text_lower = text.lower()
                # Filter copyright and navigation
                if 'copyright' in text_lower or 'rights reserved' in text_lower:
                    continue
                # Filter navigation/category text
                if any(skip in text_lower for skip in skip_words[:15]):
                    continue
                # Must be a cooking instruction
                if any(action in text_lower for action in [
                    'preheat', 'heat', 'add', 'discard', 'stir', 'cook', 'bake',
                    'cream', 'grease', 'sift', 'mix', 'spread', 'drop', 'sprinkle',
                    'cut', 'cool', 'combine', 'slowly', 'until', 'bake', 'transfer',
                    'return', 'tie', 'bring', 'cover', 'separate', 'pull', 'spoon',
                    'dry', 'place', 'turn', 'allow', 'check', 'using', 'sauté'
                ]):
                    text = re.sub(r'^\d+\.\s*', '', text)
                    # Don't add duplicates
                    if text.lower() not in [f.lower() for f in instruction_fragments]:
                        instruction_fragments.append(text)
    
    # Now join fragments into full paragraphs
    # Strategy: Join fragments until we hit a clear paragraph boundary
    # A paragraph boundary is when:
    # 1. Fragment ends with period AND is substantial (20+ words), OR
    # 2. Fragment ends with period AND next fragment starts with capital letter (new paragraph), OR
    # 3. Fragment ends with period AND next fragment starts with action word (new instruction)
    instructions = []
    current_para = []
    seen = set()
    
    for i, fragment in enumerate(instruction_fragments):
        frag_lower = fragment.lower()
        if frag_lower in seen:
            continue
        seen.add(frag_lower)
        
        # Remove any numbering that might have been added
        fragment = re.sub(r'^\d+\.\s*', '', fragment)
        
        # Add to current paragraph
        current_para.append(fragment)
        
        # Check if this should end the paragraph
        should_end_para = False
        fragment_words = len(fragment.split())
        
        # If fragment ends with period
        if fragment.endswith('.'):
            # Count sentences in this fragment
            sentences = fragment.count('.')
            # If this fragment has multiple sentences or is substantial, it's likely a complete paragraph
            if sentences >= 2 or fragment_words > 20 or len(fragment) > 100:
                should_end_para = True
            # Or if next fragment starts with capital letter (likely new paragraph)
            elif i < len(instruction_fragments) - 1:
                next_fragment = instruction_fragments[i + 1]
                next_clean = re.sub(r'^\d+\.\s*', '', next_fragment)
                if next_clean and next_clean[0].isupper():
                    next_lower = next_clean.lower()
                    # If next starts with an action word, it's definitely a new paragraph
                    action_starters = ['preheat', 'heat', 'add', 'discard', 'transfer', 'return', 'spread', 'tie', 'bring', 'cover', 'separate', 'pull', 'spoon', 'sprinkle', 'cool', 'dry', 'place', 'turn', 'allow', 'check', 'using', 'sauté']
                    if any(next_lower.startswith(starter) for starter in action_starters):
                        should_end_para = True
                    # Or if current paragraph is already substantial (12+ words total), end it
                    elif sum(len(f.split()) for f in current_para) >= 12:
                        should_end_para = True
        # If fragment doesn't end with period but is very long (30+ words), might be complete
        elif fragment_words > 30:
            should_end_para = True
        # If current paragraph is getting very long (>25 words total), force a break
        elif sum(len(f.split()) for f in current_para) >= 25:
            should_end_para = True
        
        if should_end_para or i == len(instruction_fragments) - 1:
            # Join current paragraph
            full_para = ' '.join(current_para)
            full_para = re.sub(r'\s+', ' ', full_para)  # Normalize whitespace
            # Remove any trailing/leading spaces and ensure it ends properly
            full_para = full_para.strip()
            if full_para and len(full_para) > 20:
                instructions.append(full_para)
            current_para = []
    
    # Final cleanup: filter copyright from end if it slipped through
    cleaned_instructions = []
    for inst in instructions:
        inst_lower = inst.lower()
        if 'copyright' in inst_lower or 'rights reserved' in inst_lower:
            continue
        # Also filter if it's mostly copyright info
        if ('2022' in inst_lower or '2026' in inst_lower) and ('go-to dinners' in inst_lower or 'clarkson potter' in inst_lower or 'barefoot contessa' in inst_lower):
            continue
        cleaned_instructions.append(inst)
    
    result['instructions'] = cleaned_instructions
    
    # Log final result
    ing_count = len(result.get('ingredients', []))
    inst_count = len(result.get('instructions', []))
    print(f"LAMBDA/BC: final result - {ing_count} ingredients, {inst_count} instructions")
    
    # Only return if we found ingredients
    if ing_count >= 2:
        print("LAMBDA/BC: returning result (ingredients >= 2)")
        return result
    else:
        print(f"LAMBDA/BC: returning None (only {ing_count} ingredients, need >= 2)")
        return None

def extract_foodandwine(soup, url=''):
    """FoodAndWine.com specific extraction - extracts ingredients and instructions"""
    result = {}
    
    if url:
        result['source_url'] = url
    
    # Title
    title_elem = soup.select_one('h1')
    if title_elem:
        result['title'] = title_elem.get_text(strip=True)
        print(f"LAMBDA/FW: found title={result['title'][:50]}")
    
    # Ingredients - try multiple selectors for Food & Wine structure
    ingredients = []
    ingredient_selectors = [
        '[class*="ingredient"] li',
        '[class*="ingredient"] p',
        '.ingredients li',
        '.ingredients p',
        '.recipe-ingredients li',
        '.recipe-ingredients p',
        '[itemprop="recipeIngredient"]',
        'li[itemprop="recipeIngredient"]',
        'p[itemprop="recipeIngredient"]',
        '[data-testid*="ingredient"]',
        'ul[class*="ingredient"] li',
        'ol[class*="ingredient"] li',
        'section[class*="ingredient"] li',
        'div[class*="ingredient"] li'
    ]
    
    skip_words = [
        'ingredients', 'directions', 'instructions', 'recipe', 'food & wine',
        'prep time', 'cook time', 'total time', 'servings', 'yield',
        'save', 'rate', 'print', 'share', 'subscribe', 'newsletter',
        'jump to recipe', 'food & wine', 'editorial guidelines'
    ]
    
    for selector in ingredient_selectors:
        ingredient_elements = soup.select(selector)
        found_count = len(ingredient_elements)
        if found_count > 0:
            print(f"LAMBDA/FW: selector '{selector}' found {found_count} elements")
            for elem in ingredient_elements:
                text = elem.get_text(strip=True)
                if text and len(text) > 3 and len(text) < 200:
                    # Remove step numbers from ingredients
                    text = re.sub(r'^(Step \d+:\s*|\d+\.\s*)', '', text)
                    # Fix spacing issues: add space between numbers/fractions and following text
                    # Fix fractions followed by letters: "1/4cup" -> "1/4 cup"
                    text = re.sub(r'(\d+/\d+)([a-zA-Z][a-zA-Z]*)', r'\1 \2', text)
                    # Fix whole numbers followed by letters (but not if part of a fraction): "1medium" -> "1 medium"
                    text = re.sub(r'(?<!/)(\d+)(?!/)([a-zA-Z][a-zA-Z]*)', r'\1 \2', text)
                    # Fix units followed by letters: "cupdry" -> "cup dry"
                    text = re.sub(r'\b(cup|cups|tbsp|tsp|tablespoon|tablespoons|teaspoon|teaspoons|pound|pounds|ounce|ounces|oz|lb|lbs|gram|grams|g|ml|liter|liters|l|kg|pint|pints|quart|quarts|gallon|gallons|dash|dashes|pinch|pinches|piece|pieces|clove|cloves|slice|slices|can|cans|bunch|bunches|head|heads|package|packages|bottle|bottles|jar|jars|box|boxes|bag|bags)\b([a-zA-Z][a-zA-Z]*)', r'\1 \2', text, flags=re.IGNORECASE)
                    # Fix parentheses followed by letters: "(28-ounce)can" -> "(28-ounce) can"
                    text = re.sub(r'(\))([a-zA-Z][a-zA-Z]*)', r'\1 \2', text)
                    # Normalize multiple spaces to single space
                    text = re.sub(r'\s+', ' ', text).strip()
                    # Filter out non-ingredient text
                    text_lower = text.lower()
                    if not any(word in text_lower for word in skip_words):
                        # Additional check: skip if it's just navigation text
                        if text_lower.strip() not in ['save', 'rate', 'print', 'share', 'subscribe', 'newsletter']:
                            ingredients.append(text)
            if ingredients:
                print(f"LAMBDA/FW: successfully extracted {len(ingredients)} ingredients using selector '{selector}'")
                break
        else:
            print(f"LAMBDA/FW: selector '{selector}' found 0 elements")
    
    if not ingredients:
        print("LAMBDA/FW: WARNING - no ingredients found with any selector")
    
    result['ingredients'] = ingredients
    
    # Instructions - try multiple selectors
    instructions = []
    instruction_selectors = [
        '[class*="instruction"] li',
        '[class*="instruction"] p',
        '[class*="direction"] li',
        '[class*="direction"] p',
        '.instructions li',
        '.instructions p',
        '.directions li',
        '.directions p',
        '.recipe-instructions li',
        '.recipe-instructions p',
        '[itemprop="recipeInstructions"] li',
        '[itemprop="recipeInstructions"] p',
        'ol[class*="instruction"] li',
        'ol[class*="direction"] li',
        '[data-testid*="instruction"]',
        'section[class*="instruction"] li',
        'div[class*="direction"] li'
    ]
    
    for selector in instruction_selectors:
        instruction_elements = soup.select(selector)
        if instruction_elements:
            for elem in instruction_elements:
                text = elem.get_text(strip=True)
                # Remove step numbers and photographer credits
                text = re.sub(r'^(Step \d+:\s*|\d+\.\s*)', '', text)
                # Remove photographer/styling credits (e.g., "Jennifer Causey / Food Styling...")
                # Pattern: Name Name / Description / Description pattern
                text = re.sub(r'\s*[A-Z][a-z]+\s+[A-Z][a-z]+(?:\s+/\s+[^/]+)*\s*', '', text)
                # Remove standalone photographer names at start
                text = re.sub(r'^[A-Z][a-z]+\s+[A-Z][a-z]+\s+/\s+', '', text)
                if text and len(text) > 10:
                    instructions.append(text)
            if instructions:
                break
    
    result['instructions'] = instructions
    
    # Extract servings/yield from Food & Wine
    servings = None
    servings_selectors = [
        '[class*="yield"]',
        '[class*="serving"]',
        '[class*="servings"]',
        '[itemprop="recipeYield"]',
        'span[class*="yield"]',
        'div[class*="yield"]'
    ]
    for selector in servings_selectors:
        servings_elem = soup.select_one(selector)
        if servings_elem:
            servings_text = servings_elem.get_text(strip=True)
            # Extract number from text like "8 to 10 servings" or "Yield: 8"
            servings_match = re.search(r'(\d+)(?:\s*to\s*(\d+))?', servings_text)
            if servings_match:
                # Use upper bound if range, otherwise use the number
                servings = int(servings_match.group(2) or servings_match.group(1))
                print(f"LAMBDA/FW: found servings={servings} from selector '{selector}'")
                break
    
    # Also try extracting from text patterns
    if not servings:
        text = soup.get_text().lower()
        servings_match = re.search(r'yield[:\s]*(\d+)(?:\s*to\s*(\d+))?', text)
        if servings_match:
            servings = int(servings_match.group(2) or servings_match.group(1))
            print(f"LAMBDA/FW: found servings={servings} from text pattern")
    
    if servings:
        result['servings'] = servings
    
    # Extract prep time and total time
    prep_time = extract_prep_time(soup)
    if prep_time:
        result['prep_time'] = prep_time
        print(f"LAMBDA/FW: found prep_time={prep_time} minutes")
    
    # Extract image
    image = extract_image(soup, url)
    if image:
        result['image'] = image
    
    # Log final result
    ing_count = len(result.get('ingredients', []))
    inst_count = len(result.get('instructions', []))
    print(f"LAMBDA/FW: final result - {ing_count} ingredients, {inst_count} instructions, servings={servings}, prep_time={prep_time}")
    
    # Only return if we found ingredients
    if ing_count >= 2:
        print("LAMBDA/FW: returning result (ingredients >= 2)")
        return result
    else:
        print(f"LAMBDA/FW: returning None (only {ing_count} ingredients, need >= 2)")
        return None

def extract_loveandlemons(soup, url=''):
    """LoveAndLemons.com specific extraction - cleans ingredient descriptions from schema.org"""
    import re as re_module  # Import at function level for pattern matching
    
    result = {}
    
    if url:
        result['source_url'] = url
    
    # Title
    title_elem = soup.select_one('h1')
    if title_elem:
        result['title'] = title_elem.get_text(strip=True)
        print(f"LAMBDA/LL: found title={result['title'][:50]}")
    
    ingredients = []
    instructions = []
    
    # Extract from schema.org first (Love and Lemons uses schema.org)
    json_ld_scripts = soup.find_all('script', type='application/ld+json')
    
    for script in json_ld_scripts:
        try:
            import json
            data = json.loads(script.string)
            
            # Handle @graph structure
            if isinstance(data, dict) and '@graph' in data:
                for item in data['@graph']:
                    if isinstance(item, dict) and item.get('@type') == 'Recipe':
                        data = item
                        break
            
            # Handle array of objects
            if isinstance(data, list):
                for item in data:
                    if isinstance(item, dict) and item.get('@type') == 'Recipe':
                        data = item
                        break
            
            if isinstance(data, dict) and data.get('@type') == 'Recipe':
                # Extract title if not already found
                if not result.get('title'):
                    result['title'] = data.get('name', '')
                
                # Extract and clean ingredients - remove descriptions after dash or colon, filter navigation items
                raw_ingredients = data.get('recipeIngredient', [])
                
                # Navigation items and non-ingredient content to skip
                navigation_items = [
                    'recipes', 'newsletter', 'cookbook', 'saved recipes', 'about us',
                    'my saved recipes', 'contact', 'instagram', 'facebook', 'pinterest',
                    'twitter', 'best brunch recipes', 'best salad recipes', 'best soup recipes',
                    'easy appetizer recipes', 'avocado', 'brussels sprouts'
                ]
                
                # Skip patterns for tips, substitutions, and recipe suggestions
                skip_patterns = [
                    r'^(recipes|newsletter|cookbook|saved recipes|about|contact|instagram|facebook|pinterest|twitter)',
                    r'^(substitute|instead of|use|add|garnish|optional|for)',
                    r'^(butternut squash soup|tortellini soup|cabbage soup|many veggie vegetable soup)',
                ]
                
                # Common non-ingredient phrases
                skip_phrases = [
                    'for sweet', 'for heat', 'for the celery', 'takes the soup',
                    'releases its starches', 'use store-bought', 'make your own',
                    'cooking liquid', 'in place of', 'some or all'
                ]
                
                for ing in raw_ingredients:
                    if isinstance(ing, str) and ing.strip():
                        # Remove descriptions after dash or colon
                        # "Extra-virgin olive oil - For richness." -> "Extra-virgin olive oil"
                        # "Vegetable broth: Make homemade..." -> "Vegetable broth"
                        cleaned = ing.split(' - ')[0].split(':')[0].strip()
                        # Also handle em-dash and other dash variants
                        cleaned = cleaned.split(' – ')[0].split(' — ')[0].strip()
                        
                        # Filter out navigation items and non-ingredient content
                        cleaned_lower = cleaned.lower()
                        
                        # Skip navigation items
                        if any(nav in cleaned_lower for nav in navigation_items):
                            continue
                        
                        # Skip if matches skip patterns
                        if any(re_module.match(pattern, cleaned_lower) for pattern in skip_patterns):
                            continue
                        
                        # Skip if contains skip phrases
                        if any(phrase in cleaned_lower for phrase in skip_phrases):
                            continue
                        
                        # Skip all-caps short items (navigation)
                        if cleaned.isupper() and len(cleaned.split()) <= 3:
                            continue
                        
                        # Skip tips/substitutions (starts with common patterns)
                        if cleaned_lower.startswith(('substitute', 'instead', 'use ', 'add ', 'garnish', 'optional')):
                            continue
                        
                        # Skip recipe suggestions (common soup names)
                        if any(soup_name in cleaned_lower for soup_name in ['butternut squash soup', 'tortellini soup', 'cabbage soup', 'vegetable soup']):
                            continue
                        
                        if cleaned and len(cleaned) > 2:
                            ingredients.append(cleaned)
                
                # Extract instructions - filter out ingredient descriptions
                for inst in data.get('recipeInstructions', []):
                    text = inst.get('text', '') if isinstance(inst, dict) else str(inst)
                    if text and text.strip():
                        text = text.strip()
                        # Filter out ingredient descriptions (usually short, contain ingredient names)
                        text_lower = text.lower()
                        # Skip if it's too short (likely ingredient description) or contains ingredient-like patterns
                        if len(text) < 30 and any(word in text_lower for word in ['for', 'use', 'make', 'or use', 'store-bought', 'i like', 'i prefer']):
                            continue
                        # Skip if it starts with ingredient-like patterns
                        if re_module.match(r'^(fresh|dried|frozen|organic|extra-virgin|store-bought|homemade)', text_lower):
                            continue
                        instructions.append(text)
                
                # Extract servings - handle ranges like "4 to 6"
                raw_yield = data.get('recipeYield') or data.get('yield')
                if isinstance(raw_yield, (int, float)):
                    result['servings'] = int(raw_yield)
                elif isinstance(raw_yield, str):
                    # Match patterns like "4", "4-6", "4 to 6", "Serves 4 to 6"
                    ym = re_module.search(r'(?:serves\s+)?(\d+)(?:\s*[–-]\s*(\d+)|(?:\s+to\s+(\d+)))?', raw_yield.lower())
                    if ym:
                        # Use higher number if range, otherwise use the number
                        servings_val = int(ym.group(3) or ym.group(2) or ym.group(1))
                        result['servings'] = servings_val
                
                # Extract prep time
                prep_time_raw = data.get('prepTime')
                if prep_time_raw:
                    prep_time_minutes = parse_iso8601_duration(prep_time_raw)
                    if prep_time_minutes:
                        result['prep_time'] = prep_time_minutes
                
                # Extract cook time
                cook_time_raw = data.get('cookTime')
                if cook_time_raw:
                    cook_time_minutes = parse_iso8601_duration(cook_time_raw)
                    if cook_time_minutes:
                        result['cook_time'] = cook_time_minutes
                
                # Extract total time
                total_time_raw = data.get('totalTime')
                if total_time_raw:
                    total_time_minutes = parse_iso8601_duration(total_time_raw)
                    if total_time_minutes:
                        result['total_time'] = total_time_minutes
                
                # Extract image
                image_raw = data.get('image')
                if isinstance(image_raw, str):
                    result['image'] = image_raw
                elif isinstance(image_raw, list) and image_raw:
                    first_img = image_raw[0]
                    if isinstance(first_img, str):
                        result['image'] = first_img
                    elif isinstance(first_img, dict):
                        result['image'] = first_img.get('url', '')
                elif isinstance(image_raw, dict):
                    result['image'] = image_raw.get('url', '')
                
                break  # Found Recipe, stop searching
        except Exception as e:
            print(f"LAMBDA/LL: Error parsing JSON-LD: {e}")
            continue
    
    # If schema.org didn't provide enough ingredients, try HTML parsing
    if len(ingredients) < 2:
        print(f"LAMBDA/LL: Schema.org found only {len(ingredients)} ingredients, trying HTML parsing")
        ingredient_selectors = [
            '[class*="ingredient"] li',
            '[class*="ingredient"] p',
            '.ingredients li',
            '.ingredients p',
            '.recipe-ingredients li',
            '.recipe-ingredients p',
            '[itemprop="recipeIngredient"]',
            'li[itemprop="recipeIngredient"]',
            'p[itemprop="recipeIngredient"]'
        ]
        
        # Navigation items and non-ingredient content to skip (same as schema.org extraction)
        navigation_items = [
            'recipes', 'newsletter', 'cookbook', 'saved recipes', 'about us',
            'my saved recipes', 'contact', 'instagram', 'facebook', 'pinterest',
            'twitter', 'best brunch recipes', 'best salad recipes', 'best soup recipes',
            'easy appetizer recipes', 'avocado', 'brussels sprouts'
        ]
        
        skip_patterns = [
            r'^(recipes|newsletter|cookbook|saved recipes|about|contact|instagram|facebook|pinterest|twitter)',
            r'^(substitute|instead of|use|add|garnish|optional|for)',
            r'^(butternut squash soup|tortellini soup|cabbage soup|many veggie vegetable soup)',
        ]
        
        skip_phrases = [
            'for sweet', 'for heat', 'for the celery', 'takes the soup',
            'releases its starches', 'use store-bought', 'make your own',
            'cooking liquid', 'in place of', 'some or all'
        ]
        
        for selector in ingredient_selectors:
            ingredient_elements = soup.select(selector)
            if ingredient_elements:
                for elem in ingredient_elements:
                    text = elem.get_text(strip=True)
                    if text and len(text) > 3 and len(text) < 200:
                        # Clean: remove descriptions after dash or colon
                        cleaned = text.split(' - ')[0].split(':')[0].strip()
                        cleaned = cleaned.split(' – ')[0].split(' — ')[0].strip()
                        
                        # Filter out navigation items and non-ingredient content
                        cleaned_lower = cleaned.lower()
                        
                        # Skip navigation items
                        if any(nav in cleaned_lower for nav in navigation_items):
                            continue
                        
                        # Skip if matches skip patterns
                        if any(re_module.match(pattern, cleaned_lower) for pattern in skip_patterns):
                            continue
                        
                        # Skip if contains skip phrases
                        if any(phrase in cleaned_lower for phrase in skip_phrases):
                            continue
                        
                        # Skip all-caps short items (navigation)
                        if cleaned.isupper() and len(cleaned.split()) <= 3:
                            continue
                        
                        # Skip tips/substitutions
                        if cleaned_lower.startswith(('substitute', 'instead', 'use ', 'add ', 'garnish', 'optional')):
                            continue
                        
                        # Skip recipe suggestions
                        if any(soup_name in cleaned_lower for soup_name in ['butternut squash soup', 'tortellini soup', 'cabbage soup', 'vegetable soup']):
                            continue
                        
                        if cleaned and cleaned not in ingredients:
                            ingredients.append(cleaned)
                if len(ingredients) >= 2:
                    break
    
    # If schema.org didn't provide enough instructions, try HTML parsing
    if len(instructions) < 3:
        print(f"LAMBDA/LL: Schema.org found only {len(instructions)} instructions, trying HTML parsing")
        instruction_selectors = [
            '[class*="instruction"] li',
            '[class*="instruction"] p',
            '[class*="step"] li',
            '[class*="step"] p',
            '.instructions li',
            '.instructions p',
            '.directions li',
            '.directions p',
            '.recipe-instructions li',
            '.recipe-instructions p',
            '[itemprop="recipeInstructions"] li',
            '[itemprop="recipeInstructions"] p',
            'ol[class*="instruction"] li',
            'ol[class*="step"] li'
        ]
        
        for selector in instruction_selectors:
            instruction_elements = soup.select(selector)
            if instruction_elements:
                for elem in instruction_elements:
                    text = elem.get_text(strip=True)
                    if text and len(text) > 20:  # Instructions should be longer than ingredient descriptions
                        # Remove step numbers
                        text = re.sub(r'^(Step \d+:\s*|\d+\.\s*)', '', text)
                        # Filter out ingredient descriptions
                        text_lower = text.lower()
                        if not any(word in text_lower for word in ['for', 'use', 'make', 'or use', 'store-bought', 'i like', 'i prefer']) or len(text) > 50:
                            if text not in instructions:
                                instructions.append(text)
                if len(instructions) >= 3:
                    break
    
    result['ingredients'] = ingredients
    result['instructions'] = instructions
    
    # Extract servings, prep time, cook time if not already found
    if not result.get('servings'):
        servings = extract_servings(soup)
        if servings:
            result['servings'] = servings
    
    if not result.get('prep_time'):
        prep_time = extract_prep_time(soup)
        if prep_time:
            result['prep_time'] = prep_time
    
    # Extract image if not already found
    if not result.get('image'):
        image = extract_image(soup, url)
        if image:
            result['image'] = image
    
    ing_count = len(ingredients)
    inst_count = len(instructions)
    print(f"LAMBDA/LL: Extracted {ing_count} ingredients, {inst_count} instructions")
    print(f"LAMBDA/LL: Servings={result.get('servings')}, Prep={result.get('prep_time')}, Cook={result.get('cook_time')}, Total={result.get('total_time')}")
    
    # If we found enough ingredients, return result
    if ing_count >= 2:
        return result
    
    # Fallback: Try generic extraction if site-specific didn't find enough ingredients
    print(f"LAMBDA/LL: Only found {ing_count} ingredients, trying generic extraction as fallback")
    generic_ingredients = extract_ingredients(soup)
    generic_instructions = extract_instructions(soup)
    
    # Clean generic ingredients (remove descriptions after dashes/colons and filter navigation items)
    
    cleaned_generic_ingredients = []
    navigation_items = [
        'recipes', 'newsletter', 'cookbook', 'saved recipes', 'about us',
        'my saved recipes', 'contact', 'instagram', 'facebook', 'pinterest',
        'twitter', 'best brunch recipes', 'best salad recipes', 'best soup recipes',
        'easy appetizer recipes', 'avocado', 'brussels sprouts'
    ]
    skip_patterns = [
        r'^(recipes|newsletter|cookbook|saved recipes|about|contact|instagram|facebook|pinterest|twitter)',
        r'^(substitute|instead of|use|add|garnish|optional|for)',
        r'^(butternut squash soup|tortellini soup|cabbage soup|many veggie vegetable soup)',
    ]
    skip_phrases = [
        'for sweet', 'for heat', 'for the celery', 'takes the soup',
        'releases its starches', 'use store-bought', 'make your own',
        'cooking liquid', 'in place of', 'some or all'
    ]
    
    for ing in generic_ingredients:
        cleaned = ing.split(' - ')[0].split(':')[0].strip()
        cleaned = cleaned.split(' – ')[0].split(' — ')[0].strip()
        
        # Filter out navigation items and non-ingredient content
        cleaned_lower = cleaned.lower()
        
        # Skip navigation items
        if any(nav in cleaned_lower for nav in navigation_items):
            continue
        
        # Skip if matches skip patterns
        if any(re_module.match(pattern, cleaned_lower) for pattern in skip_patterns):
            continue
        
        # Skip if contains skip phrases
        if any(phrase in cleaned_lower for phrase in skip_phrases):
            continue
        
        # Skip all-caps short items (navigation)
        if cleaned.isupper() and len(cleaned.split()) <= 3:
            continue
        
        # Skip tips/substitutions
        if cleaned_lower.startswith(('substitute', 'instead', 'use ', 'add ', 'garnish', 'optional')):
            continue
        
        # Skip recipe suggestions
        if any(soup_name in cleaned_lower for soup_name in ['butternut squash soup', 'tortellini soup', 'cabbage soup', 'vegetable soup']):
            continue
        
        if cleaned and len(cleaned) > 2:
            cleaned_generic_ingredients.append(cleaned)
    
    # Use generic extraction if it found more ingredients, otherwise use what we have
    if len(cleaned_generic_ingredients) >= 2:
        print(f"LAMBDA/LL: Generic extraction found {len(cleaned_generic_ingredients)} ingredients, using those")
        result['ingredients'] = cleaned_generic_ingredients
        if len(generic_instructions) > len(instructions):
            result['instructions'] = generic_instructions
        # Fill in missing fields from generic extraction
        if not result.get('title'):
            result['title'] = extract_title(soup)
        if not result.get('servings'):
            servings = extract_servings(soup)
            if servings:
                result['servings'] = servings
        if not result.get('prep_time'):
            prep_time = extract_prep_time(soup)
            if prep_time:
                result['prep_time'] = prep_time
        if not result.get('image'):
            image = extract_image(soup, url)
            if image:
                result['image'] = image
        return result
    
    # If generic extraction also failed, return None
    print(f"LAMBDA/LL: Generic extraction also failed (found {len(cleaned_generic_ingredients)} ingredients), returning None")
    return None

def extract_servings(soup):
    """Extract number of servings with comprehensive search - collects all matches and returns best one based on scoring."""
    
    candidates = []  # List of (servings_value, score, source_description) tuples
    
    # 1. FIRST: Check JSON-LD structured data (most reliable, score 100 - always wins)
    try:
        for script in soup.find_all('script', type='application/ld+json'):
            try:
                data = json.loads(script.string)
                if isinstance(data, list):
                    data = data[0] if data else {}
                if data.get('@type') == 'Recipe':
                    raw_yield = data.get('recipeYield') or data.get('yield')
                    if raw_yield:
                        if isinstance(raw_yield, (int, float)):
                            servings = int(raw_yield)
                            if 2 <= servings <= 50:
                                candidates.append((servings, 100, "JSON-LD (numeric)"))
                        elif isinstance(raw_yield, str):
                            # Extract number from string like "4" or "4-6 servings" or "6 to 8"
                            match = re.search(r'(\d+)(?:\s*[–-]\s*(\d+)|(?:\s+to\s+(\d+)))?', raw_yield)
                            if match:
                                servings = int(match.group(3) or match.group(2) or match.group(1))
                                if 2 <= servings <= 50:
                                    candidates.append((servings, 100, f"JSON-LD (string): {raw_yield[:50]}"))
            except (json.JSONDecodeError, ValueError, TypeError):
                continue
    except Exception:
        pass
    
    # If we found JSON-LD, return it immediately (highest reliability)
    if candidates:
        best = max(candidates, key=lambda x: x[1])
        print(f"LAMBDA/SERVINGS: found {best[0]} from {best[2]} (score: {best[1]})")
        return best[0]
    
    # 2. SECOND: Check HTML elements with semantic markup and common CSS classes (base score 80)
    semantic_selectors = [
        # Microdata attributes (most reliable after JSON-LD, score 85)
        ('[itemprop="recipeYield"]', 85),
        ('[itemprop="yield"]', 85),
        ('[itemprop="servingSize"]', 85),
        # Data attributes (score 82)
        ('[data-servings]', 82),
        ('[data-yield]', 82),
        ('[data-serves]', 82),
        # WordPress plugin classes (score 80)
        ('.wprm-recipe-servings', 80),
        ('.wprm-recipe-servings-amount', 80),
        ('.tasty-recipes-yield', 80),
        ('.tasty-recipes-servings', 80),
        ('.ERSServings', 80),
        # Common CSS classes (score 80)
        ('.recipe-servings', 80),
        ('.servings', 80),
        ('.recipe-yield', 80),
        ('.yield', 80),
        ('.recipe-serves', 80),
        ('.serves', 80),
        ('.recipe-portions', 80),
        ('.portions', 80),
        ('.recipe-meta-item', 80),
        ('.recipe-card-servings', 80),
        # Generic patterns (score 75)
        ('[class*="serving"]', 75),
        ('[class*="yield"]', 75),
        ('[class*="serves"]', 75),
        ('[class*="portion"]', 75)
    ]
    
    serving_keywords = ['servings', 'serves', 'yield', 'makes', 'portions', 'people', 'persons']
    
    for selector, base_score in semantic_selectors:
        elements = soup.select(selector)
        for elem in elements:
            score = base_score
            text = elem.get_text(strip=True)
            
            # Try to get number from data attribute first
            if selector.startswith('[data-'):
                attr_name = selector[1:-1].replace('data-', '')
                if elem.get(attr_name):
                    try:
                        servings = int(elem.get(attr_name))
                        if 2 <= servings <= 50:
                            # Bonus for data attributes (more reliable)
                            score += 5
                            candidates.append((servings, score, f"{selector} attribute"))
                            continue
                    except (ValueError, TypeError):
                        pass
            
            # Extract number from text content
            if text:
                # Handle patterns like "6", "6 servings", "Serves 6", "Yield: 8"
                match = re.search(r'(\d+)(?:\s*[–-]\s*(\d+)|(?:\s+to\s+(\d+)))?', text)
                if match:
                    servings = int(match.group(3) or match.group(2) or match.group(1))
                    if 2 <= servings <= 50:
                        # Bonus for explicit serving keywords in text
                        text_lower = text.lower()
                        if any(keyword in text_lower for keyword in serving_keywords):
                            score += 10
                        # Bonus for common serving sizes (4-12)
                        if 4 <= servings <= 12:
                            score += 5
                        # Penalty for high numbers (>24) without strong context
                        if servings > 24:
                            score -= 10
                            if not any(keyword in text_lower for keyword in serving_keywords):
                                continue  # Skip if no serving keyword
                        
                        candidates.append((servings, score, f"{selector} text: {text[:50]}"))
    
    # 3. THIRD: Text-based regex patterns (collect all matches and score them)
    full_text = soup.get_text()
    text_lower = full_text.lower()
    
    # Exclude sections that commonly contain false positives
    exclude_patterns = [
        r'nutrition.*?servings?',  # Nutrition info with "per serving"
        r'calories.*?per.*?serving',  # Calories per serving
        r'(\d+)\s*(?:oz|ounce|ounces|g|gram|grams|ml|milliliter|milliliters|l|liter|liters|kg|kilogram|kilograms)\s*servings?',  # Ingredient quantities like "40 oz servings"
        r'(\d+)\s*(?:cup|cups|tbsp|tablespoon|teaspoon|pound|pounds)\s*servings?',  # Ingredient quantities
        r'(\d+)\s*x\s*(\d+)\s*servings?',  # Multiplication patterns like "1 x 40 servings"
        r'prep.*?time.*?\d+',  # Prep time patterns
        r'cook.*?time.*?\d+',  # Cook time patterns
        r'(\d+)\s*(?:min|mins|minutes?|m|hr|hrs|hours?|h)',  # Time patterns
    ]
    
    # Base scores by term frequency (from your analysis):
    # Servings (45%) = 60, Yield (25%) = 55, Serves (25%) = 55, Makes (5%) = 50
    
    # Pattern definitions: (pattern, base_score, specificity_bonus, pattern_name)
    patterns = [
        # PATTERN GROUP 1: "Servings" variations (base score 60, most common)
        (r'(?:^|\n|\.|;)\s*servings?:?\s*(?:about|approximately|approx|around|up\s*to)?\s*(\d+)(?:\s*[–-]\s*(\d+)|(?:\s+to\s+(\d+)))?(?:\s*$|\s*\n|\.|;|,|\s)', 60, 20, "Servings (explicit)"),
        (r'(?:^|\n|\.|;)\s*number\s*of\s*servings?:?\s*(\d+)(?:\s*[–-]\s*(\d+)|(?:\s+to\s+(\d+)))?(?:\s*$|\s*\n|\.|;)', 60, 15, "Number of Servings"),
        (r'(?:^|\n|\.|;)\s*recipe\s*servings?:?\s*(\d+)(?:\s*[–-]\s*(\d+)|(?:\s+to\s+(\d+)))?(?:\s*$|\s*\n|\.|;)', 60, 15, "Recipe Servings"),
        (r'(?:^|\n|\.|;)\s*total\s*servings?:?\s*(\d+)(?:\s*[–-]\s*(\d+)|(?:\s+to\s+(\d+)))?(?:\s*$|\s*\n|\.|;)', 60, 15, "Total Servings"),
        (r'servings?:?\s*(?:about|approximately|approx|around|up\s*to)?\s*(\d+)(?:\s*[–-]\s*(\d+)|(?:\s+to\s+(\d+)))?\s*(?:servings?|$|\n|\.|;|,)', 60, 5, "Servings (generic)"),
        
        # PATTERN GROUP 2: "Yield" variations (base score 55, second most common)
        (r'(?:^|\n|\.|;)\s*yield:?\s*(?:about|approximately|approx|around)?\s*(\d+)(?:\s*[–-]\s*(\d+)|(?:\s+to\s+(\d+)))?(?:\s+servings?)?(?:\s*$|\s*\n|\.|;)', 55, 20, "Yield (explicit)"),
        (r'(?:^|\n|\.|;)\s*recipe\s*yield:?\s*(\d+)(?:\s*[–-]\s*(\d+)|(?:\s+to\s+(\d+)))?(?:\s*$|\s*\n|\.|;)', 55, 15, "Recipe Yield"),
        (r'(?:^|\n|\.|;)\s*total\s*yield:?\s*(\d+)(?:\s*[–-]\s*(\d+)|(?:\s+to\s+(\d+)))?(?:\s*$|\s*\n|\.|;)', 55, 15, "Total Yield"),
        (r'yield:?\s*(?:about|approximately|approx|around)?\s*(\d+)(?:\s*[–-]\s*(\d+)|(?:\s+to\s+(\d+)))?(?:\s+servings?)?', 55, 5, "Yield (generic)"),
        
        # PATTERN GROUP 3: "Serves" variations (base score 55, common in UK)
        (r'(?:^|\n|\.|;)\s*serves?:?\s*(?:about|approximately|approx|around|up\s*to)?\s*(\d+)(?:\s*[–-]\s*(\d+)|(?:\s+to\s+(\d+)))?(?:\s+(?:people|persons|servings?))?(?:\s*$|\s*\n|\.|;)', 55, 20, "Serves (explicit)"),
        (r'(?:^|\n|\.|;)\s*serves?:?\s*for\s*(\d+)(?:\s*[–-]\s*(\d+)|(?:\s+to\s+(\d+)))?(?:\s*$|\s*\n|\.|;)', 55, 15, "Serves For"),
        (r'serves?:?\s*(?:about|approximately|approx|around|up\s*to)?\s*(\d+)(?:\s*[–-]\s*(\d+)|(?:\s+to\s+(\d+)))?(?:\s+(?:people|persons|servings?))?', 55, 5, "Serves (generic)"),
        
        # PATTERN GROUP 4: "Makes" variations (base score 50, less common)
        (r'(?:^|\n|\.|;)\s*makes?:?\s*(?:about|approximately|approx|around|enough\s*for)?\s*(\d+)(?:\s*[–-]\s*(\d+)|(?:\s+to\s+(\d+)))?(?:\s+servings?)?(?:\s*$|\s*\n|\.|;)', 50, 20, "Makes (explicit)"),
        (r'(?:^|\n|\.|;)\s*recipe\s*makes?:?\s*(\d+)(?:\s*[–-]\s*(\d+)|(?:\s+to\s+(\d+)))?(?:\s*$|\s*\n|\.|;)', 50, 15, "Recipe Makes"),
        (r'makes?:?\s*(?:about|approximately|approx|around|enough\s*for)?\s*(\d+)(?:\s*[–-]\s*(\d+)|(?:\s+to\s+(\d+)))?(?:\s+servings?)?', 50, 5, "Makes (generic)"),
        
        # PATTERN GROUP 5: Secondary terms (base score 45)
        (r'(?:^|\n|\.|;)\s*portions?:?\s*(\d+)(?:\s*[–-]\s*(\d+)|(?:\s+to\s+(\d+)))?(?:\s*$|\s*\n|\.|;)', 45, 15, "Portions"),
        (r'(?:^|\n|\.|;)\s*persons?:?\s*(\d+)(?:\s*[–-]\s*(\d+)|(?:\s+to\s+(\d+)))?(?:\s*$|\s*\n|\.|;)', 45, 15, "Persons"),
        (r'(?:^|\n|\.|;)\s*people:?\s*(\d+)(?:\s*[–-]\s*(\d+)|(?:\s+to\s+(\d+)))?(?:\s*$|\s*\n|\.|;)', 45, 15, "People"),
        (r'(?:^|\n|\.|;)\s*feeds?:?\s*(\d+)(?:\s*[–-]\s*(\d+)|(?:\s+to\s+(\d+)))?(?:\s*$|\s*\n|\.|;)', 45, 15, "Feeds"),
        (r'(?:^|\n|\.|;)\s*for\s*(\d+)(?:\s*[–-]\s*(\d+)|(?:\s+to\s+(\d+)))?(?:\s+people)?(?:\s*$|\s*\n|\.|;)', 45, 10, "For X People"),
        
        # PATTERN GROUP 6: Quantity/yield patterns (base score 40)
        (r'(?:^|\n|\.|;)\s*quantity:?\s*(\d+)(?:\s*[–-]\s*(\d+)|(?:\s+to\s+(\d+)))?(?:\s*$|\s*\n|\.|;)', 40, 15, "Quantity"),
        (r'(?:^|\n|\.|;)\s*qty:?\s*(\d+)(?:\s*[–-]\s*(\d+)|(?:\s+to\s+(\d+)))?(?:\s*$|\s*\n|\.|;)', 40, 15, "Qty"),
        
        # PATTERN GROUP 7: Generic number + serving word (base score 35, lowest priority)
        (r'(?:^|\n|\.|;)\s*(\d+)(?:\s*[–-]\s*(\d+)|(?:\s+to\s+(\d+)))?\s*(?:servings?|portions?|persons?|people)(?:\s*$|\s*\n|\.|;)', 35, 10, "Generic Number + Serving Word"),
    ]
    
    for pattern, base_score, specificity_bonus, pattern_name in patterns:
        matches = re.finditer(pattern, text_lower, re.MULTILINE)
        for match in matches:
            # Check if this match is in an excluded section (false positive)
            match_start = match.start()
            match_end = match.end()
            match_context = full_text[max(0, match_start-50):min(len(full_text), match_end+50)].lower()
            
            # Skip if it's in a false positive context
            is_false_positive = False
            for exclude_pattern in exclude_patterns:
                if re.search(exclude_pattern, match_context):
                    is_false_positive = True
                    print(f"LAMBDA/SERVINGS: skipping potential false positive: {match_context[:100]}")
                    break
            
            if is_false_positive:
                continue
            
            # Extract servings number
            if len(match.groups()) >= 3 and match.group(3):
                servings = int(match.group(3))  # "to" format
            elif len(match.groups()) >= 2 and match.group(2):
                servings = int(match.group(2))  # "–" or "-" format
            else:
                servings = int(match.group(1))  # Single number
            
            # Validate range
            if 2 <= servings <= 50:
                score = base_score + specificity_bonus
                
                # Context bonuses
                # Bonus for proximity to serving keywords
                if any(keyword in match_context for keyword in serving_keywords):
                    score += 10
                
                # Bonus for common serving sizes (4-12 is most typical)
                if 4 <= servings <= 12:
                    score += 5
                
                # Penalty for high numbers (>24) without strong context
                if servings > 24:
                    score -= 10
                    if not any(keyword in match_context for keyword in serving_keywords):
                        print(f"LAMBDA/SERVINGS: skipping {servings} - no serving keyword in context")
                        continue  # Skip if no serving keyword
                
                # Bonus for being at start of line or after punctuation (more likely to be metadata)
                if match.group(0).strip().startswith(('servings', 'serves', 'yield', 'makes', 'portions', 'people')):
                    score += 5
                
                candidates.append((servings, score, f"{pattern_name}: {match.group(0)[:50]}"))
    
    # Return the best candidate (highest score)
    if candidates:
        # Sort by score (descending), then by servings value (descending for tie-breaker)
        candidates.sort(key=lambda x: (-x[1], -x[0]))
        best = candidates[0]
        print(f"LAMBDA/SERVINGS: found {best[0]} from {best[2]} (score: {best[1]})")
        if len(candidates) > 1:
            print(f"LAMBDA/SERVINGS: top candidates: {[(c[0], c[1]) for c in candidates[:3]]}")
        return best[0]
    
    print("LAMBDA/SERVINGS: no valid servings found")
    return None

def extract_prep_time(soup):
    """Extract prep time with expanded search terms (also handles cook/total time patterns)"""
    text = soup.get_text().lower()
    
    # Expanded prep time patterns (highest priority for prep time extraction)
    prep_time_patterns = [
        r'prep\s*time[:\s]*(\d+)\s*(?:min|mins|minutes?|m|hr|hrs|hours?|h|day|days|d)',
        r'preparation\s*time[:\s]*(\d+)\s*(?:min|mins|minutes?|m|hr|hrs|hours?|h|day|days|d)',
        r'prep[:\s]*(\d+)\s*(?:min|mins|minutes?|m|hr|hrs|hours?|h|day|days|d)',
        r'preparation[:\s]*(\d+)\s*(?:min|mins|minutes?|m|hr|hrs|hours?|h|day|days|d)',
        r'active\s*time[:\s]*(\d+)\s*(?:min|mins|minutes?|m|hr|hrs|hours?|h|day|days|d)',
        r'active\s*prep\s*time[:\s]*(\d+)\s*(?:min|mins|minutes?|m|hr|hrs|hours?|h|day|days|d)',
        r'hands[-\s]*on\s*time[:\s]*(\d+)\s*(?:min|mins|minutes?|m|hr|hrs|hours?|h|day|days|d)',
        r'hands\s*on\s*time[:\s]*(\d+)\s*(?:min|mins|minutes?|m|hr|hrs|hours?|h|day|days|d)',
        r'ready\s*in\s*prep[:\s]*(\d+)\s*(?:min|mins|minutes?|m|hr|hrs|hours?|h|day|days|d)',
    ]
    
    # Cook time patterns (for reference, but function returns prep time)
    cook_time_patterns = [
        r'cook\s*time[:\s]*(\d+)\s*(?:min|mins|minutes?|m|hr|hrs|hours?|h|day|days|d)',
        r'cooking\s*time[:\s]*(\d+)\s*(?:min|mins|minutes?|m|hr|hrs|hours?|h|day|days|d)',
        r'bake\s*time[:\s]*(\d+)\s*(?:min|mins|minutes?|m|hr|hrs|hours?|h|day|days|d)',
        r'baking\s*time[:\s]*(\d+)\s*(?:min|mins|minutes?|m|hr|hrs|hours?|h|day|days|d)',
        r'roast\s*time[:\s]*(\d+)\s*(?:min|mins|minutes?|m|hr|hrs|hours?|h|day|days|d)',
        r'roasting\s*time[:\s]*(\d+)\s*(?:min|mins|minutes?|m|hr|hrs|hours?|h|day|days|d)',
        r'simmer\s*time[:\s]*(\d+)\s*(?:min|mins|minutes?|m|hr|hrs|hours?|h|day|days|d)',
        r'simmering\s*time[:\s]*(\d+)\s*(?:min|mins|minutes?|m|hr|hrs|hours?|h|day|days|d)',
        r'chill\s*time[:\s]*(\d+)\s*(?:min|mins|minutes?|m|hr|hrs|hours?|h|day|days|d)',
        r'chilling\s*time[:\s]*(\d+)\s*(?:min|mins|minutes?|m|hr|hrs|hours?|h|day|days|d)',
        r'marinate\s*time[:\s]*(\d+)\s*(?:min|mins|minutes?|m|hr|hrs|hours?|h|day|days|d)',
        r'marinating\s*time[:\s]*(\d+)\s*(?:min|mins|minutes?|m|hr|hrs|hours?|h|day|days|d)',
        r'cook[:\s]*(\d+)\s*(?:min|mins|minutes?|m|hr|hrs|hours?|h|day|days|d)',
    ]
    
    # Total time patterns
    total_time_patterns = [
        r'total\s*time[:\s]*(\d+)\s*(?:min|mins|minutes?|m|hr|hrs|hours?|h|day|days|d)',
        r'ready\s*in[:\s]*(\d+)\s*(?:min|mins|minutes?|m|hr|hrs|hours?|h|day|days|d)',
        r'ready[:\s]*(\d+)\s*(?:min|mins|minutes?|m|hr|hrs|hours?|h|day|days|d)',
        r'ready\s*to\s*serve[:\s]*(\d+)\s*(?:min|mins|minutes?|m|hr|hrs|hours?|h|day|days|d)',
        r'from\s*start\s*to\s*finish[:\s]*(\d+)\s*(?:min|mins|minutes?|m|hr|hrs|hours?|h|day|days|d)',
        r'start\s*to\s*finish[:\s]*(\d+)\s*(?:min|mins|minutes?|m|hr|hrs|hours?|h|day|days|d)',
        r'total[:\s]*(\d+)\s*(?:min|mins|minutes?|m|hr|hrs|hours?|h|day|days|d)',
    ]
    
    # Generic patterns (time unit first, then label)
    generic_patterns = [
        r'(\d+)\s*(?:min|mins|minutes?|m|hr|hrs|hours?|h|day|days|d)\s*(?:prep|preparation|active|hands[\s-]?on)',
        r'(\d+)\s*(?:min|mins|minutes?|m|hr|hrs|hours?|h|day|days|d)\s*(?:cook|cooking|bake|baking|roast|roasting|simmer|simmering|chill|chilling|marinate|marinating)',
        r'(\d+)\s*(?:min|mins|minutes?|m|hr|hrs|hours?|h|day|days|d)\s*(?:total|ready)',
        r'(\d+)\s*(?:min|mins|minutes?|m|hr|hrs|hours?|h|day|days|d)',
    ]
    
    # Try prep time patterns first (function name implies prep time extraction)
    all_patterns = prep_time_patterns + cook_time_patterns + total_time_patterns + generic_patterns
    
    for pattern in all_patterns:
        match = re.search(pattern, text)
        if match:
            time_val = int(match.group(1))
            # Convert hours/days to minutes - check the actual matched text
            matched_text = match.group(0).lower()
            if any(unit in matched_text for unit in ['day', 'days', 'd']):
                return time_val * 24 * 60  # Convert days to minutes
            elif any(unit in matched_text for unit in ['hr', 'hrs', 'hour', 'hours', 'h']):
                return time_val * 60  # Convert hours to minutes
            return time_val  # Already in minutes or default to minutes
    
    # Look for time in specific HTML elements
    time_elements = soup.find_all(['time', 'span', 'div', 'p', 'li'])
    for element in time_elements:
        elem_text = element.get_text().strip().lower()
        if re.search(r'\d+\s*(?:min|mins|minutes?|m|hr|hrs|hours?|h|day|days|d)', elem_text):
            # Try prep time patterns first
            for pattern in prep_time_patterns + generic_patterns[:1]:
                match = re.search(pattern, elem_text)
                if match:
                    time_val = int(match.group(1))
                    if any(unit in elem_text for unit in ['day', 'days', 'd']):
                        return time_val * 24 * 60
                    elif any(unit in elem_text for unit in ['hr', 'hrs', 'hour', 'hours', 'h']):
                        return time_val * 60
                    return time_val
    
    return None

def extract_image(soup, url=''):
    """Extract recipe image URL with comprehensive selectors"""
    # Extract domain for relative URL construction
    domain = ''
    host = ''
    if url:
        try:
            from urllib.parse import urlparse
            parsed = urlparse(url)
            domain = f"{parsed.scheme}://{parsed.netloc}"
            host = (parsed.netloc or '').lower()
        except:
            pass
    is_toh = 'tasteofhome.com' in host
    
    # Quick high‑res candidates from meta and srcset
    try:
        import re as _re_img, urllib.parse as _urlp
        candidates = []
        for sel in ['meta[property="og:image"]','meta[property="og:image:secure_url"]','meta[name="twitter:image"]']:
            m = soup.select_one(sel)
            if m and m.get('content'):
                candidates.append(m['content'].strip())
        # Taste of Home additional meta fallbacks
        if is_toh:
            for sel in ['meta[property="og:image:url"]','meta[name="twitter:image:src"]']:
                m = soup.select_one(sel)
                if m and m.get('content'):
                    candidates.append(m['content'].strip())
        # Taste of Home only: picture/source srcset and preload hints
        if is_toh:
            for src in soup.select('picture source'):
                srcset = src.get('srcset') or src.get('data-srcset')
                if not srcset:
                    continue
                parts = [p.strip() for p in srcset.split(',')]
                scored = []
                for p in parts:
                    try:
                        u, w = p.rsplit(' ', 1)
                        wnum = int(''.join(ch for ch in w if ch.isdigit()))
                        scored.append((wnum, u.strip()))
                    except Exception:
                        pass
                if scored:
                    candidates.append(max(scored)[1])
            for ln in soup.select('link[rel="preload"][as="image"]'):
                href = ln.get('href')
                if href:
                    candidates.append(href.strip())
        for img in soup.find_all('img'):
            srcset = img.get('srcset') or img.get('data-srcset')
            if not srcset:
                continue
            parts = [p.strip() for p in srcset.split(',')]
            scored = []
            for p in parts:
                try:
                    u, w = p.rsplit(' ', 1)
                    wnum = int(''.join(ch for ch in w if ch.isdigit()))
                    scored.append((wnum, u.strip()))
                except Exception:
                    pass
            if scored:
                candidates.append(max(scored)[1])
        def _abs_url(u: str) -> str:
            if not u:
                return ''
            if u.startswith('//'):
                return 'https:' + u
            if u.startswith('http://'):
                return 'https:' + u[5:]
            if u.startswith('/'):
                if domain:
                    return domain + u
                if url:
                    pu = _urlp.urlparse(url)
                    return f'{pu.scheme}://{pu.netloc}{u}'
            return u
        def _is_thumb(u: str) -> bool:
            bad = ['thumbnail','thumb','sprite','icon','logo','avatar','placeholder','promo','advert','banner','header','nav','social','subscribe','newsletter','you-may-like','recommended']
            size_pat = _re_img.compile(r'[-_](?:\d{2,4}x\d{2,4})(?=\.)')
            return any(b in u.lower() for b in bad) or bool(size_pat.search(u))
        def _upgrade(u: str) -> str:
            return _re_img.sub(r'\\1', _re_img.sub(r'(-|_)\d{2,4}x\d{2,4}(?=\.)', '', u))
        for cu in candidates:
            au = _abs_url(cu)
            if not au or _is_thumb(au):
                continue
            hi = _re_img.sub(r'(-|_)\d{2,4}x\d{2,4}(?=\.)', '', au)
            return hi or au
    except Exception:
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
        # Taste of Home common containers
        '.recipe__lead-media img',
        'article .recipe-hero img',
        'article picture img',
        '.o-recipe-media img',
        
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
    # Add Taste of Home specific selectors only for that domain
    if is_toh:
        img_selectors.extend([
            '.recipe__lead-media img',
            'article .recipe-hero img',
            'article picture img',
            '.o-recipe-media img',
            'figure img',
            'figure picture img',
        ])

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
    
    # Taste of Home specific: try JSON-LD image and large image fallback
    if is_toh:
        try:
            for tag in soup.find_all('script', type='application/ld+json'):
                try:
                    data = json.loads(tag.string or '{}')
                except Exception:
                    continue
                # If list, try to find the Recipe block
                if isinstance(data, list):
                    for d in data:
                        if isinstance(d, dict) and d.get('@type') == 'Recipe':
                            data = d
                            break
                if isinstance(data, dict) and data.get('@type') == 'Recipe':
                    img_raw = data.get('image')
                    img_url = ''
                    if isinstance(img_raw, str):
                        img_url = img_raw
                    elif isinstance(img_raw, list) and img_raw:
                        first = img_raw[0]
                        img_url = first.get('url', '') if isinstance(first, dict) else str(first)
                    elif isinstance(img_raw, dict):
                        img_url = img_raw.get('url', '')
                    if img_url:
                        if img_url.startswith('//'):
                            img_url = 'https:' + img_url
                        if img_url.startswith('http://'):
                            img_url = 'https:' + img_url[5:]
                        return img_url
        except Exception:
            pass
        # Last-resort: first large image within main/article
        for scope in ['main img', 'article img']:
            for im in soup.select(scope):
                s = im.get('src') or im.get('data-src') or im.get('data-original')
                if not s:
                    continue
                try:
                    w = int(im.get('width') or 0)
                    h = int(im.get('height') or 0)
                except Exception:
                    w = h = 0
                if w >= 400 or h >= 300:
                    s = s.strip()
                    if s.startswith('//'):
                        s = 'https:' + s
                    if s.startswith('http://'):
                        s = 'https:' + s[5:]
                    if s.startswith('/') and domain:
                        s = domain + s
                    return s

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

def is_valid_title(title: str) -> bool:
    """Validate that title is not an error page or placeholder"""
    print(f"LAMBDA/DEBUG: is_valid_title called with: '{title}'")
    if not title or not isinstance(title, str):
        return False
    
    title_lower = title.lower().strip()
    
    # Reject error messages
    error_phrases = [
        "page not found",
        "404",
        "error",
        "oops",
        "not found",
        "access denied",
        "we can't find",
        "we cant find",
        "we cannot find",
        "not available",
        "recipe not found",
        "search results",
        "default article title"
    ]
    
    if any(phrase in title_lower for phrase in error_phrases):
        print(f"LAMBDA/DEBUG: REJECTING title due to error phrase")
        return False
    
    # Reject empty or too short titles
    if len(title_lower) < 3:
        return False
    
    # Reject placeholder titles
    if title_lower in ["untitled recipe", "recipe", "no title"]:
        return False
    
    print(f"LAMBDA/DEBUG: ACCEPTING title")
    return True

def is_likely_hallucination(recipe_data: dict) -> bool:
    """Detect AI hallucinations or synthetic data"""
    ingredients = recipe_data.get('ingredients', [])
    title = recipe_data.get('title', '')
    
    # Check for exactly 20 ingredients (common AI default padding)
    if len(ingredients) == 20:
        return True
    
    # Check for generic ingredient patterns
    if ingredients:
        generic_ingredients = ['ingredient', 'item', 'component', 'element']
        generic_count = sum(1 for ing in ingredients if any(gen in ing.lower() for gen in generic_ingredients))
        
        # If more than 30% are generic, likely hallucination
        if generic_count / len(ingredients) > 0.3:
            return True
    
    # Check if title is invalid
    if not is_valid_title(title):
        return True
    
    return False

def calculate_quality_score(recipe_data):
    """Calculate quality score based on recipe completeness"""
    # Reject obvious failures immediately
    title = recipe_data.get("title", "")
    if not is_valid_title(title):
        print(f"LAMBDA/SCORE: rejected invalid title: {title[:50]}")
        return 0.0
    
    if is_likely_hallucination(recipe_data):
        print(f"LAMBDA/SCORE: rejected hallucination: {len(recipe_data.get('ingredients', []))} ingredients")
        return 0.0
    
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

def validate_or_explain(payload: dict) -> Tuple[bool, str]:
    """Validate payload against basic schema requirements"""
    try:
        # Check required fields
        if not payload.get('title') or len(payload['title']) < 3 or len(payload['title']) > 200:
            return False, "title must be 3-200 characters"
        
        if not payload.get('servings') or not isinstance(payload['servings'], int) or payload['servings'] < 1:
            return False, "servings must be integer >= 1"
        
        image = payload.get('image', '')
        # Handle image being a list or dict (from JSON-LD)
        if isinstance(image, list) and len(image) > 0:
            image = image[0] if isinstance(image[0], str) else (image[0].get('url', '') if isinstance(image[0], dict) else '')
        elif isinstance(image, dict):
            image = image.get('url', '')
        if not image or not isinstance(image, str) or not image.startswith('https://'):
            return False, "image must be https URL"
        
        if not payload.get('site_link') or not payload['site_link'].startswith('https://'):
            return False, "site_link must be https URL"
        
        if not payload.get('ingredients') or not isinstance(payload['ingredients'], list) or len(payload['ingredients']) < 1:
            return False, "ingredients must be non-empty list"
        
        if not payload.get('instructions') or not isinstance(payload['instructions'], list) or len(payload['instructions']) < 1:
            return False, "instructions must be non-empty list"
        
        # Check ingredient lengths
        for ingredient in payload['ingredients']:
            if not isinstance(ingredient, str) or len(ingredient) < 3 or len(ingredient) > 220:
                return False, f"ingredient must be 3-220 characters: {ingredient[:50]}"
        
        # Check instruction lengths
        for instruction in payload['instructions']:
            if not isinstance(instruction, str) or len(instruction) < 1 or len(instruction) > 500:
                return False, f"instruction must be 1-500 characters: {instruction[:50]}"
        
        return True, ""
    except Exception as e:
        return False, str(e)

def calculate_field_confidence(recipe_data: dict, tier: str) -> Dict[str, float]:
    """Calculate per-field confidence scores by tier"""
    confidences = {}
    
    # Tier-specific confidence defaults
    if tier == "deterministic":
        base_conf = {"title": 0.9, "image": 0.9, "ingredients": 0.8, "instructions": 0.8, "servings": 0.7, "total_time": 0.7}
    elif tier == "spoonacular":
        base_conf = {"title": 0.8, "image": 0.8, "ingredients": 0.75, "instructions": 0.6, "servings": 0.7, "total_time": 0.6}
    else:
        base_conf = {"title": 0.7, "image": 0.7, "ingredients": 0.7, "instructions": 0.7, "servings": 0.7, "total_time": 0.7}
    
    # Calculate actual confidence based on content quality
    for field, base_score in base_conf.items():
        if field == "title":
            title = recipe_data.get('title', '')
            if not title or title == "Untitled Recipe":
                confidences[field] = 0.0
            elif len(title) < 3 or len(title) > 200:
                confidences[field] = base_score * 0.5
            elif any(brand in title.lower() for brand in ['allrecipes', 'food network', 'taste of home']):
                confidences[field] = base_score * 0.7
            else:
                confidences[field] = base_score
        elif field == "image":
            image = recipe_data.get('image', '')
            # Handle image being a list or dict (from JSON-LD)
            if isinstance(image, list) and len(image) > 0:
                image = image[0] if isinstance(image[0], str) else (image[0].get('url', '') if isinstance(image[0], dict) else '')
            elif isinstance(image, dict):
                image = image.get('url', '')
            # Now image should be a string
            if not image or not isinstance(image, str) or not image.startswith('https://'):
                confidences[field] = 0.0
            elif any(logo in image.lower() for logo in ['logo', 'icon', 'favicon']):
                confidences[field] = base_score * 0.3
            else:
                confidences[field] = base_score
        elif field == "ingredients":
            ingredients = recipe_data.get('ingredients', [])
            if len(ingredients) < 4:
                confidences[field] = base_score * 0.3
            elif len(ingredients) < 8:
                confidences[field] = base_score * 0.7
            else:
                confidences[field] = base_score
        elif field == "instructions":
            instructions = recipe_data.get('instructions', [])
            if len(instructions) < 4:
                confidences[field] = base_score * 0.3
            elif len(instructions) < 6:
                confidences[field] = base_score * 0.7
            else:
                confidences[field] = base_score
        elif field == "servings":
            servings = recipe_data.get('servings')
            if not servings or servings < 1:
                confidences[field] = base_score * 0.5
            else:
                confidences[field] = base_score
        elif field == "total_time":
            total_time = recipe_data.get('total_time_minutes') or recipe_data.get('total_time')
            if not total_time:
                confidences[field] = base_score * 0.5
            else:
                confidences[field] = base_score
    
    return confidences

def detect_red_flags(recipe_data: dict) -> Tuple[bool, str]:
    """Detect red flags that should trigger next tier"""
    red_flags = []
    
    # Check for bot walls
    title = recipe_data.get('title', '')
    if is_bot_wall(title):
        red_flags.append('bot_wall')
        print("LAMBDA/REDFLAG: bot_wall")
    
    # Check for blocked content (existing)
    if any(blocked in title.lower() for blocked in ['access denied', 'instructions not available', 'blocked']):
        red_flags.append('blocked_content')
    
    # Check for insufficient content
    ingredients = recipe_data.get('ingredients', [])
    if len(ingredients) < 3:
        red_flags.append('insufficient_ingredients')
    
    instructions = recipe_data.get('instructions', [])
    if len(instructions) < 3:
        red_flags.append('insufficient_instructions')
    elif any('instructions not available' in step.lower() for step in instructions):
        red_flags.append('insufficient_instructions')
    
    # Check for watermarks
    all_text = ' '.join(ingredients + instructions).lower()
    if any(watermark in all_text for watermark in ['dotdash', 'meredith', 'food studios']):
        red_flags.append('watermarks')
    
    # Check for single step instructions
    if len(instructions) == 1:
        red_flags.append('single_step')
    
    return len(red_flags) > 0, ', '.join(red_flags)

def calculate_weighted_score(recipe_data: dict, confidences: dict) -> float:
    """Calculate weighted acceptance score"""
    weights = {"title": 0.15, "image": 0.15, "ingredients": 0.30, "instructions": 0.30, "servings": 0.05, "total_time": 0.05}
    
    score = 0.0
    for field, weight in weights.items():
        score += confidences.get(field, 0.0) * weight
    
    return score

def should_accept_tier(recipe_data: dict, tier: str, min_trigger_score: float) -> Tuple[bool, str, float]:
    """Determine if tier should be accepted"""
    confidences = calculate_field_confidence(recipe_data, tier)
    weighted_score = calculate_weighted_score(recipe_data, confidences)
    has_red_flags, red_flags = detect_red_flags(recipe_data)
    
    # Check for bot wall in metadata
    if recipe_data.get('metadata', {}).get('bot_wall_detected'):
        return False, "bot_wall_detected", weighted_score
    
    # Additional bot wall check on title
    if is_bot_wall(recipe_data.get('title', '')):
        return False, "bot_wall_title", weighted_score
    
    if has_red_flags:
        return False, f"red_flags:{red_flags}", weighted_score
    
    if weighted_score < min_trigger_score:
        return False, f"low_score:{weighted_score:.2f}", weighted_score
    
    return True, "ok", weighted_score

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
    """Call OpenAI GPT-4o-mini for recipe extraction fallback"""
    try:
        api_key = os.environ.get('OPENAI_API_KEY')
        if not api_key:
            raise Exception("OPENAI_API_KEY not set")
        
        timeout_ms = int(os.environ.get('AI_TIMEOUT_MS', '15000'))  # 15 seconds to match other OpenAI calls
        
        # Log API switch for verification
        print(f"LAMBDA/AI-FALLBACK: Using OpenAI GPT-4o-mini for {url}")
        
        # Truncate HTML if too long (keep first 8000 chars)
        html_truncated = html[:8000] if len(html) > 8000 else html
        
        # Build context for AI
        deterministic_partial = {
            'title': 'Untitled Recipe',
            'image': '',
            'ingredients': [],
            'instructions': []
        }
        
        prompt = f"""You are a disciplined recipe extractor. Output must be a single JSON object that validates this schema:

title: plain text, 3–200 chars (no site name)
servings: integer >= 1
prep_time_minutes, cook_time_minutes, total_time_minutes: integers >= 0
image: https URL to the best hero image (≥800px if available)
site_link: https URL of the original recipe page
ingredients: array of strings; one ingredient per item; "qty unit item" style; 3–220 chars each; no numbering or bullets
instructions: array of strings; strictly step-by-step; DO NOT include numbers in the strings; each 1–500 chars; no section headers or tips

Rules:
- Convert all times to minutes; if only total is known, set prep/cook=0.
- Title must exclude site name, author, or emojis.
- Ingredients must be clean and singular per line; no marketing text.
- Instructions must be complete and atomic actions in order; remove headings like "Make the lattice:" but keep actions as separate steps.
- If an essential field is missing, set a conservative value but keep schema valid.

Return ONLY the JSON object. No markdown, no prose.

Context:
- Original URL: {url}
- HTML excerpt (truncated): {html_truncated[:2000]}
- Deterministic partial JSON: {json.dumps(deterministic_partial)}

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

Return only valid JSON, no markdown, no backticks, no commentary."""

        headers = {
            'Authorization': f'Bearer {api_key}',
            'Content-Type': 'application/json'
        }
        
        payload = {
            'model': 'gpt-4o-mini',  # Hardcoded, matching other OpenAI calls
            'max_tokens': 1200,
            'temperature': 0,  # Keep 0 for deterministic extraction (NOT 0.3)
            'messages': [
                {
                    'role': 'user',
                    'content': prompt
                }
            ],
            'response_format': {'type': 'json_object'}  # ADD THIS for native JSON mode
        }
        
        response = requests.post(
            'https://api.openai.com/v1/chat/completions',
            headers=headers,
            json=payload,
            timeout=timeout_ms / 1000.0
        )
        
        if response.status_code == 200:
            result = response.json()
            content = result.get('choices', [{}])[0].get('message', {}).get('content', '').strip()
            
            if content:
                # Clean up the response (keep markdown stripping for safety, even with JSON mode)
                if content.startswith('```json'):
                    content = content[7:]
                if content.startswith('```'):
                    content = content[3:]
                if content.endswith('```'):
                    content = content[:-3]
                content = content.strip()
                
                # Parse JSON
                ai_data = json.loads(content)
                
                # Validate AI result
                is_valid, validation_error = validate_or_explain(ai_data)
                if not is_valid:
                    print(f"LAMBDA/PARSE: ai-validation-failed error={validation_error}")
                    # Try one reprompt
                    reprompt = f"""Your previous JSON failed validation. Fix ONLY the fields indicated and re-emit a full JSON object that passes the schema. Do not add commentary.

Validation errors:
{validation_error}

Original context:
{prompt}

Return only valid JSON, no markdown, no backticks, no commentary."""
                    
                    retry_payload = {
                        'model': 'gpt-4o-mini',  # Hardcoded
                        'max_tokens': 1200,
                        'temperature': 0,  # Keep 0
                        'messages': [
                            {
                                'role': 'user',
                                'content': reprompt
                            }
                        ],
                        'response_format': {'type': 'json_object'}  # ADD THIS
                    }
                    
                    retry_response = requests.post(
                        'https://api.openai.com/v1/chat/completions',  # Changed endpoint
                        headers=headers,  # Same headers (already updated above)
                        json=retry_payload,
                        timeout=timeout_ms / 1000.0
                    )
                    
                    if retry_response.status_code == 200:
                        retry_result = retry_response.json()
                        retry_content = retry_result.get('choices', [{}])[0].get('message', {}).get('content', '').strip()
                        
                        if retry_content:
                            retry_content = retry_content.strip()
                            if retry_content.startswith('```json'):
                                retry_content = retry_content[7:]
                            if retry_content.startswith('```'):
                                retry_content = retry_content[3:]
                            if retry_content.endswith('```'):
                                retry_content = retry_content[:-3]
                            retry_content = retry_content.strip()
                            
                            ai_data = json.loads(retry_content)
                            is_valid_retry, _ = validate_or_explain(ai_data)
                            if is_valid_retry:
                                print("LAMBDA/PARSE: ai-retry-success")
                            else:
                                print("LAMBDA/PARSE: ai-retry-failed")
                                # Use original result even if invalid
                    else:
                        print("LAMBDA/PARSE: ai-retry-error")
                        # Use original result
                
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
def merge_ai_results_patch_only(base_result: dict, ai_result: dict, base_confidences: dict) -> dict:
    """Merge AI results using patch-only logic, preserving high-confidence fields"""
    merged = base_result.copy()
    
    # Define confidence thresholds for field preservation
    preserve_threshold = 0.8
    improve_threshold = 0.1
    
    # Track what AI improved
    ai_improvements = []
    ai_filled = []
    
    for field in ['title', 'image', 'ingredients', 'instructions', 'servings', 'prep_time', 'cook_time', 'total_time']:
        base_value = base_result.get(field)
        ai_value = ai_result.get(field)
        base_confidence = base_confidences.get(field, 0.0)
        
        if not base_value or base_confidence < 0.5:
            # Field missing or low confidence - use AI if available
            if ai_value:
                merged[field] = ai_value
                ai_filled.append(field)
        elif base_confidence >= preserve_threshold:
            # High confidence field - preserve unless AI is significantly better
            if ai_value and field in ['ingredients', 'instructions']:
                # For lists, check if AI version is significantly longer/better
                if isinstance(ai_value, list) and isinstance(base_value, list):
                    if len(ai_value) > len(base_value) * 1.2:  # 20% improvement
                        merged[field] = ai_value
                        ai_improvements.append(field)
            # For other fields, keep base value
        else:
            # Medium confidence - use AI if available and better
            if ai_value:
                if field in ['title', 'image']:
                    # For title/image, use AI if it looks better
                    if field == 'title' and len(ai_value) > len(base_value or ''):
                        merged[field] = ai_value
                        ai_improvements.append(field)
                    elif field == 'image' and ai_value.startswith('https://'):
                        merged[field] = ai_value
                        ai_improvements.append(field)
                else:
                    merged[field] = ai_value
                    ai_improvements.append(field)
    
    # Log what AI did
    if ai_improvements or ai_filled:
        print(f"LAMBDA/AIMERGE: keep={[f for f in ['title', 'image', 'ingredients', 'instructions'] if f not in ai_improvements and f not in ai_filled]} fill={ai_filled} improve={ai_improvements}")
    
    return merged
