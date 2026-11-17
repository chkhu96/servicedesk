"""Shared DB helper. Connection string is read from the Key Vault CSI mount (not env vars)."""
import os
import pyodbc

SECRETS_DIR = os.getenv("SECRETS_DIR", "/mnt/secrets")


def read_secret(name: str) -> str:
    with open(os.path.join(SECRETS_DIR, name), encoding="utf-8") as f:
        return f.read().strip()


def connect() -> pyodbc.Connection:
    # Read every time so Key Vault secret rotation (CSI rotation poll) is picked up
    return pyodbc.connect(read_secret("sql-connection-string"), autocommit=True)


def rows_to_dicts(cursor) -> list[dict]:
    cols = [c[0] for c in cursor.description]
    return [dict(zip(cols, r)) for r in cursor.fetchall()]


def schema_ready() -> bool:
    try:
        with connect() as conn:
            conn.execute("SELECT TOP 1 1 FROM dbo.Tickets")
        return True
    except Exception:
        return False
