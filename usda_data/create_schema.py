#!/usr/bin/env python3
"""
Create SQLite database schema for nutrition database
Output: nutrition.db
"""

import sqlite3
import os
from datetime import datetime

DB_FILE = "nutrition.db"

def create_schema():
    """Create the database schema"""
    
    # Remove existing database if it exists
    if os.path.exists(DB_FILE):
        os.remove(DB_FILE)
        print(f"Removed existing {DB_FILE}")
    
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    
    print("Creating database schema...")
    
    # TABLE: foods
    cursor.execute("""
        CREATE TABLE foods (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            fdc_id INTEGER UNIQUE NOT NULL,
            name TEXT NOT NULL,
            description TEXT,
            category TEXT,
            data_source TEXT,
            popularity_score INTEGER DEFAULT 0
        )
    """)
    
    # TABLE: servings
    cursor.execute("""
        CREATE TABLE servings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            food_id INTEGER NOT NULL,
            description TEXT NOT NULL,
            grams REAL NOT NULL,
            is_default INTEGER DEFAULT 0,
            FOREIGN KEY (food_id) REFERENCES foods(id)
        )
    """)
    
    # TABLE: nutrition
    cursor.execute("""
        CREATE TABLE nutrition (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            food_id INTEGER NOT NULL UNIQUE,
            calories REAL,
            protein REAL,
            carbohydrates REAL,
            fat REAL,
            fiber REAL,
            sugar REAL,
            sodium REAL,
            saturated_fat REAL,
            cholesterol REAL,
            potassium REAL,
            calcium REAL,
            iron REAL,
            magnesium REAL,
            phosphorus REAL,
            zinc REAL,
            copper REAL,
            manganese REAL,
            selenium REAL,
            iodine REAL,
            vitamin_a REAL,
            vitamin_c REAL,
            vitamin_d REAL,
            vitamin_e REAL,
            vitamin_k REAL,
            vitamin_b1 REAL,
            vitamin_b2 REAL,
            vitamin_b3 REAL,
            vitamin_b5 REAL,
            vitamin_b6 REAL,
            vitamin_b12 REAL,
            folate REAL,
            choline REAL,
            omega_3 REAL,
            omega_6 REAL,
            FOREIGN KEY (food_id) REFERENCES foods(id)
        )
    """)
    
    # TABLE: aliases
    cursor.execute("""
        CREATE TABLE aliases (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            food_id INTEGER NOT NULL,
            alias TEXT NOT NULL,
            FOREIGN KEY (food_id) REFERENCES foods(id)
        )
    """)
    
    # TABLE: metadata
    cursor.execute("""
        CREATE TABLE metadata (
            key TEXT PRIMARY KEY,
            value TEXT
        )
    """)
    
    # Create indexes
    print("Creating indexes...")
    cursor.execute("CREATE INDEX idx_foods_name ON foods(name)")
    cursor.execute("CREATE INDEX idx_foods_category ON foods(category)")
    cursor.execute("CREATE INDEX idx_foods_popularity ON foods(popularity_score DESC)")
    cursor.execute("CREATE INDEX idx_aliases_alias ON aliases(alias)")
    cursor.execute("CREATE INDEX idx_nutrition_food_id ON nutrition(food_id)")
    cursor.execute("CREATE INDEX idx_servings_food_id ON servings(food_id)")
    
    # Insert initial metadata
    cursor.execute("""
        INSERT INTO metadata (key, value) VALUES
        ('database_version', '1.0'),
        ('created_date', ?)
    """, (datetime.now().isoformat(),))
    
    conn.commit()
    conn.close()
    
    print(f"✅ Database schema created: {DB_FILE}")
    print(f"   Tables: foods, servings, nutrition, aliases, metadata")
    print(f"   Indexes: 6 indexes created")

if __name__ == "__main__":
    create_schema()

