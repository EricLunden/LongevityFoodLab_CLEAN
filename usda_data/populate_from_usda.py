#!/usr/bin/env python3
"""
Populate SQLite nutrition database from USDA JSON files
Requires: nutrition.db (created by create_schema.py)
Input: FoodData_Central_sr_legacy_food_json_2018-04.json
       FoodData_Central_foundation_food_json_2025-04-24.json
"""

import json
import sqlite3
import re
import os
from datetime import datetime
from collections import defaultdict

# USDA Nutrient ID Mapping
NUTRIENT_MAP = {
    1008: "calories",      # Energy (kcal)
    1003: "protein",      # Protein
    1005: "carbohydrates", # Carbohydrates
    1004: "fat",          # Total fat
    1079: "fiber",        # Fiber
    2000: "sugar",        # Total sugars
    1093: "sodium",       # Sodium
    1258: "saturated_fat", # Saturated fat
    1253: "cholesterol",  # Cholesterol
    1092: "potassium",    # Potassium
    1087: "calcium",      # Calcium
    1089: "iron",         # Iron
    1090: "magnesium",    # Magnesium
    1091: "phosphorus",   # Phosphorus
    1095: "zinc",         # Zinc
    1098: "copper",       # Copper
    1101: "manganese",    # Manganese
    1103: "selenium",     # Selenium
    1100: "iodine",       # Iodine
    1106: "vitamin_a",    # Vitamin A (RAE)
    1162: "vitamin_c",    # Vitamin C
    1114: "vitamin_d",    # Vitamin D
    1109: "vitamin_e",    # Vitamin E
    1185: "vitamin_k",    # Vitamin K
    1165: "vitamin_b1",   # Vitamin B1 (Thiamin)
    1166: "vitamin_b2",   # Vitamin B2 (Riboflavin)
    1167: "vitamin_b3",   # Vitamin B3 (Niacin)
    1170: "vitamin_b5",   # Vitamin B5 (Pantothenic acid)
    1175: "vitamin_b6",   # Vitamin B6
    1178: "vitamin_b12",  # Vitamin B12
    1177: "folate",       # Folate (DFE)
    1180: "choline",      # Choline
    1404: "omega_3",      # Omega-3
    1405: "omega_6",      # Omega-6
}

# Popularity scores for common foods
POPULAR_FOODS_100 = {
    "apple", "banana", "chicken", "beef", "rice", "bread", "egg", "milk", 
    "salmon", "broccoli", "potato", "tomato", "onion", "carrot", "cheese", 
    "yogurt", "pasta", "oatmeal", "orange", "strawberry"
}

POPULAR_FOODS_80 = {
    "avocado", "spinach", "almond", "peanut butter", "olive oil", "honey", 
    "garlic", "lemon", "lettuce", "cucumber", "pepper", "corn", "beans", 
    "tuna", "shrimp", "turkey", "pork", "bacon"
}

# Common misspellings and aliases
COMMON_ALIASES = {
    "brocolli": "broccoli",
    "avacado": "avocado",
    "aubergine": "eggplant",
    "courgette": "zucchini",
}

def clean_food_name(description):
    """Clean food name for searchable field"""
    # Remove parenthetical notes like "(includes foods for USDA's Food Distribution Program)"
    name = re.sub(r'\s*\([^)]*\)', '', description)
    # Remove extra whitespace
    name = ' '.join(name.split())
    return name.lower().strip()

def map_category(usda_category):
    """Map USDA category to our simplified categories"""
    if not usda_category:
        return "other"
    
    cat_lower = usda_category.lower()
    
    if "fruit" in cat_lower:
        return "fruit"
    elif "vegetable" in cat_lower or "mushroom" in cat_lower:
        return "vegetable"
    elif any(x in cat_lower for x in ["beef", "pork", "lamb", "game"]):
        return "meat"
    elif "poultry" in cat_lower:
        return "poultry"
    elif any(x in cat_lower for x in ["fish", "shellfish", "seafood"]):
        return "seafood"
    elif any(x in cat_lower for x in ["dairy", "milk", "cheese"]) or "egg" in cat_lower:
        return "dairy"
    elif any(x in cat_lower for x in ["grain", "bread", "cereal", "pasta"]):
        return "grain"
    elif any(x in cat_lower for x in ["legume", "bean", "tofu"]):
        return "legume"
    elif any(x in cat_lower for x in ["nut", "seed"]):
        return "nut"
    elif any(x in cat_lower for x in ["fat", "oil"]):
        return "oil"
    elif any(x in cat_lower for x in ["spice", "sauce", "condiment"]):
        return "condiment"
    elif any(x in cat_lower for x in ["beverage", "drink"]):
        return "beverage"
    elif any(x in cat_lower for x in ["snack", "candy", "sweet"]):
        return "snack"
    elif any(x in cat_lower for x in ["fast food", "restaurant", "meal"]):
        return "prepared"
    else:
        return "other"

def get_popularity_score(name, description):
    """Get popularity score for a food"""
    name_lower = name.lower()
    desc_lower = description.lower()
    
    # Check if it's a whole food (not prepared/processed)
    if any(food in name_lower or food in desc_lower for food in POPULAR_FOODS_100):
        return 100
    elif any(food in name_lower or food in desc_lower for food in POPULAR_FOODS_80):
        return 80
    elif any(word in desc_lower for word in ["prepared", "cooked", "processed", "canned", "frozen"]):
        return 40
    else:
        return 60

def generate_aliases(name, description):
    """Generate aliases for a food"""
    aliases = set()
    name_lower = name.lower()
    
    # Singular/plural variants
    if name_lower.endswith('s') and len(name_lower) > 1:
        aliases.add(name_lower[:-1])  # Remove 's'
    else:
        aliases.add(name_lower + 's')  # Add 's'
    
    # Common misspellings
    for misspelling, correct in COMMON_ALIASES.items():
        if correct in name_lower:
            aliases.add(misspelling)
        if misspelling in name_lower:
            aliases.add(correct)
    
    # Word reordering (e.g., "chicken breast" -> "breast, chicken")
    words = name_lower.split()
    if len(words) == 2:
        aliases.add(f"{words[1]}, {words[0]}")
    
    # Remove duplicates and the original name
    aliases.discard(name_lower)
    return list(aliases)

def extract_nutrients(food_nutrients):
    """Extract nutrients from foodNutrients array"""
    nutrients = {}
    
    for fn in food_nutrients:
        nutrient_id = fn.get('nutrient', {}).get('id')
        if nutrient_id in NUTRIENT_MAP:
            amount = fn.get('amount')
            if amount is not None:
                nutrients[NUTRIENT_MAP[nutrient_id]] = amount
    
    return nutrients

def extract_portions(food_portions):
    """Extract serving sizes from foodPortions array"""
    portions = []
    
    for fp in food_portions:
        description = fp.get('modifier', '')
        grams = fp.get('gramWeight')
        if grams is not None and grams > 0:
            portions.append({
                'description': description or f"{fp.get('amount', 1)} {fp.get('measureUnit', {}).get('name', 'serving')}",
                'grams': grams,
                'is_default': 0  # Will be set later
            })
    
    # Set first portion as default if available
    if portions:
        portions[0]['is_default'] = 1
    
    return portions

def validate_food(nutrients, category):
    """Validate food data"""
    calories = nutrients.get('calories')
    
    # Skip foods with no calorie data
    if calories is None or calories <= 0:
        return False, "No calorie data"
    
    # Skip foods with unreasonable calories (except oils)
    if calories > 900 and category != "oil":
        return False, f"Calories too high: {calories}"
    
    return True, None

def process_food(cursor, food, data_source, skipped_log):
    """Process a single food and insert into database"""
    fdc_id = food.get('fdcId')
    if not fdc_id:
        return False
    
    # Check for duplicates
    cursor.execute("SELECT id FROM foods WHERE fdc_id = ?", (fdc_id,))
    if cursor.fetchone():
        return False  # Already exists
    
    description = food.get('description', '')
    name = clean_food_name(description)
    category = map_category(food.get('foodCategory', {}).get('description', ''))
    popularity_score = get_popularity_score(name, description)
    
    # Extract nutrients
    nutrients = extract_nutrients(food.get('foodNutrients', []))
    
    # Validate
    is_valid, reason = validate_food(nutrients, category)
    if not is_valid:
        skipped_log.append(f"FDC {fdc_id}: {description} - {reason}")
        return False
    
    # Insert food
    cursor.execute("""
        INSERT INTO foods (fdc_id, name, description, category, data_source, popularity_score)
        VALUES (?, ?, ?, ?, ?, ?)
    """, (fdc_id, name, description, category, data_source, popularity_score))
    
    food_id = cursor.lastrowid
    
    # Insert nutrition
    cursor.execute("""
        INSERT INTO nutrition (
            food_id, calories, protein, carbohydrates, fat, fiber, sugar, sodium,
            saturated_fat, cholesterol, potassium, calcium, iron, magnesium,
            phosphorus, zinc, copper, manganese, selenium, iodine,
            vitamin_a, vitamin_c, vitamin_d, vitamin_e, vitamin_k,
            vitamin_b1, vitamin_b2, vitamin_b3, vitamin_b5, vitamin_b6,
            vitamin_b12, folate, choline, omega_3, omega_6
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, (
        food_id,
        nutrients.get('calories'),
        nutrients.get('protein'),
        nutrients.get('carbohydrates'),
        nutrients.get('fat'),
        nutrients.get('fiber'),
        nutrients.get('sugar'),
        nutrients.get('sodium'),
        nutrients.get('saturated_fat'),
        nutrients.get('cholesterol'),
        nutrients.get('potassium'),
        nutrients.get('calcium'),
        nutrients.get('iron'),
        nutrients.get('magnesium'),
        nutrients.get('phosphorus'),
        nutrients.get('zinc'),
        nutrients.get('copper'),
        nutrients.get('manganese'),
        nutrients.get('selenium'),
        nutrients.get('iodine'),
        nutrients.get('vitamin_a'),
        nutrients.get('vitamin_c'),
        nutrients.get('vitamin_d'),
        nutrients.get('vitamin_e'),
        nutrients.get('vitamin_k'),
        nutrients.get('vitamin_b1'),
        nutrients.get('vitamin_b2'),
        nutrients.get('vitamin_b3'),
        nutrients.get('vitamin_b5'),
        nutrients.get('vitamin_b6'),
        nutrients.get('vitamin_b12'),
        nutrients.get('folate'),
        nutrients.get('choline'),
        nutrients.get('omega_3'),
        nutrients.get('omega_6'),
    ))
    
    # Insert servings
    portions = extract_portions(food.get('foodPortions', []))
    for portion in portions:
        cursor.execute("""
            INSERT INTO servings (food_id, description, grams, is_default)
            VALUES (?, ?, ?, ?)
        """, (food_id, portion['description'], portion['grams'], portion['is_default']))
    
    # Insert aliases
    aliases = generate_aliases(name, description)
    for alias in aliases:
        cursor.execute("""
            INSERT INTO aliases (food_id, alias)
            VALUES (?, ?)
        """, (food_id, alias))
    
    return True

def populate_database():
    """Main function to populate database"""
    
    if not os.path.exists("nutrition.db"):
        print("❌ Error: nutrition.db not found. Run create_schema.py first.")
        return
    
    conn = sqlite3.connect("nutrition.db")
    cursor = conn.cursor()
    
    skipped_log = []
    stats = defaultdict(int)
    
    print("=" * 60)
    print("Populating nutrition database from USDA files")
    print("=" * 60)
    
    # Process SR Legacy first
    sr_legacy_file = "FoodData_Central_sr_legacy_food_json_2018-04.json"
    if os.path.exists(sr_legacy_file):
        print(f"\n📂 Processing {sr_legacy_file}...")
        with open(sr_legacy_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
            foods = data.get('SRLegacyFoods', [])
            print(f"   Found {len(foods)} foods")
            
            processed = 0
            for i, food in enumerate(foods, 1):
                if process_food(cursor, food, "sr_legacy", skipped_log):
                    processed += 1
                    stats['sr_legacy'] += 1
                    stats[map_category(food.get('foodCategory', {}).get('description', ''))] += 1
                
                if i % 1000 == 0:
                    conn.commit()
                    print(f"   Processed {i}/{len(foods)} foods... ({processed} inserted)")
            
            conn.commit()
            print(f"✅ SR Legacy: {processed}/{len(foods)} foods inserted")
    else:
        print(f"⚠️  Warning: {sr_legacy_file} not found")
    
    # Process Foundation Foods
    foundation_file = "FoodData_Central_foundation_food_json_2025-04-24.json"
    if os.path.exists(foundation_file):
        print(f"\n📂 Processing {foundation_file}...")
        with open(foundation_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
            foods = data.get('FoundationFoods', [])
            print(f"   Found {len(foods)} foods")
            
            processed = 0
            for i, food in enumerate(foods, 1):
                if process_food(cursor, food, "foundation", skipped_log):
                    processed += 1
                    stats['foundation'] += 1
                    stats[map_category(food.get('foodCategory', {}).get('description', ''))] += 1
                
                if i % 500 == 0:
                    conn.commit()
                    print(f"   Processed {i}/{len(foods)} foods... ({processed} inserted)")
            
            conn.commit()
            print(f"✅ Foundation: {processed}/{len(foods)} foods inserted")
    else:
        print(f"⚠️  Warning: {foundation_file} not found")
    
    # Update metadata
    cursor.execute("SELECT COUNT(*) FROM foods")
    total_foods = cursor.fetchone()[0]
    
    cursor.execute("""
        INSERT OR REPLACE INTO metadata (key, value) VALUES
        ('usda_data_date', ?),
        ('total_foods', ?),
        ('last_updated', ?)
    """, (datetime.now().strftime('%Y-%m-%d'), str(total_foods), datetime.now().isoformat()))
    
    conn.commit()
    conn.close()
    
    # Print summary
    print("\n" + "=" * 60)
    print("POPULATION SUMMARY")
    print("=" * 60)
    print(f"Total foods inserted: {total_foods}")
    print(f"\nBy data source:")
    print(f"  SR Legacy: {stats['sr_legacy']}")
    print(f"  Foundation: {stats['foundation']}")
    print(f"\nBy category:")
    for cat in sorted([k for k in stats.keys() if k not in ['sr_legacy', 'foundation']]):
        print(f"  {cat}: {stats[cat]}")
    
    # Write skipped foods log
    if skipped_log:
        with open("skipped_foods.txt", "w") as f:
            f.write("Skipped Foods Log\n")
            f.write("=" * 60 + "\n\n")
            for entry in skipped_log:
                f.write(entry + "\n")
        print(f"\n⚠️  {len(skipped_log)} foods skipped (see skipped_foods.txt)")
    
    # Write population log
    with open("population_log.txt", "w") as f:
        f.write("Population Log\n")
        f.write("=" * 60 + "\n\n")
        f.write(f"Date: {datetime.now().isoformat()}\n")
        f.write(f"Total foods: {total_foods}\n")
        f.write(f"SR Legacy: {stats['sr_legacy']}\n")
        f.write(f"Foundation: {stats['foundation']}\n")
        f.write(f"Skipped: {len(skipped_log)}\n")
    
    print("\n✅ Database population complete!")
    print(f"   Database: nutrition.db")
    print(f"   Log: population_log.txt")

if __name__ == "__main__":
    populate_database()

