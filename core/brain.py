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

def get_db_path (project_name: str) -> Path:
    """
    Return the full path to a project's brain database
    Example: get_db_path("myproject") -> data/bullish.db
    """
    return DATA_DIR / f"{project_name}.db"

def get_connection (db_path: Path) -> sqlite3.Connection:
    """
    Open a connection to the given database with the 
    default FodderMap settings
    """
    conn = sqlite3.connect(db_path)
    conn.execute("PRAGMA journal_mode = WAL;")
    conn.execute("PRAGMA synchronous = NORMAL;")
    conn.execute("PRAGMA foreign_keys = ON;")
    conn.execute("PRAGMA busy_timeout = 5000;")
    return conn 

def init_brain (project_name: str, force: bool = False) -> Path:
    