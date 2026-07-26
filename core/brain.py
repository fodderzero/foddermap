"""
brain.py
Database layer for FodderMap

Responsibilities:
- Create and connect to per-project SQLite brains
- Apply the schema
- Provide a clean connection with foreign keys enabled
- Handle init / force-recreate logic
"""

from pathlib import Path
import sqlite3
from datetime import datetime, timezone

# Where the schema lives
SCHEMA_PATH = Path(__file__).parent / "brain_schema.sql"

# Where all project databases will live
DATA_DIR = Path("data")