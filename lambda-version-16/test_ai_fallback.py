#!/usr/bin/env python3
"""
Test script for the AI fallback functionality in lambda_function.py
"""

import json
import os
import sys
sys.path.append('.')

from lambda_function import lambda_handler

def test_deterministic_only():
    """Test with AI disabled (deterministic only)"""
    print("=== Testing Deterministic Only (AI Disabled) ===")
    
    # Set environment variables
    os.environ['AI_TIER_ENABLED'] = 'false'
    
    # Test event
    event = {
        'url': 'https://www.allrecipes.com/recipe/213742/cheesy-chicken-broccoli-casserole/',
        'html': '''
        <html>
        <head><title>Cheesy Chicken Broccoli Casserole</title></head>
        <body>
            <h1>Cheesy Chicken Broccoli Casserole</h1>
            <div class="ingredients">
                <li>2 cups cooked chicken</li>
                <li>1 cup broccoli</li>
                <li>1 cup cheese</li>
            </div>
            <div class="instructions">
                <li>Mix ingredients</li>
                <li>Bake at 350°F</li>
            </div>
        </body>
        </html>
        '''
    }
    
    result = lambda_handler(event, {})
    print(f"Status Code: {result['statusCode']}")
    
    if result['statusCode'] == 200:
        body = json.loads(result['body'])
        print(f"Title: {body.get('title')}")
        print(f"Ingredients: {len(body.get('ingredients', []))}")
        print(f"Instructions: {len(body.get('instructions', []))}")
        print(f"Tier Used: {body.get('metadata', {}).get('tier_used')}")
        print(f"Quality Score: {body.get('quality_score', 0):.2f}")
    else:
        print(f"Error: {result['body']}")

def test_ai_fallback():
    """Test with AI enabled (will show fallback behavior)"""
    print("\n=== Testing AI Fallback (AI Enabled) ===")
    
    # Set environment variables for AI
    os.environ['AI_TIER_ENABLED'] = 'true'
    os.environ['AI_MIN_TRIGGER_SCORE'] = '0.60'
    os.environ['AI_MODEL'] = 'claude-3-haiku-202410'
    os.environ['AI_TIMEOUT_MS'] = '4000'
    
    # Note: This will fail without a real API key, but shows the flow
    os.environ['ANTHROPIC_API_KEY'] = 'test-key-will-fail'
    
    # Test event with poor deterministic parsing
    event = {
        'url': 'https://example.com/recipe',
        'html': '''
        <html>
        <head><title>Complex Recipe</title></head>
        <body>
            <h1>Complex Recipe</h1>
            <!-- Poor structure for deterministic parsing -->
        </body>
        </html>
        '''
    }
    
    result = lambda_handler(event, {})
    print(f"Status Code: {result['statusCode']}")
    
    if result['statusCode'] == 200:
        body = json.loads(result['body'])
        print(f"Title: {body.get('title')}")
        print(f"Ingredients: {len(body.get('ingredients', []))}")
        print(f"Instructions: {len(body.get('instructions', []))}")
        print(f"Tier Used: {body.get('metadata', {}).get('tier_used')}")
        print(f"Quality Score: {body.get('quality_score', 0):.2f}")
        if 'ai_error' in body.get('metadata', {}):
            print(f"AI Error: {body['metadata']['ai_error']}")
    else:
        print(f"Error: {result['body']}")

if __name__ == "__main__":
    test_deterministic_only()
    test_ai_fallback()
