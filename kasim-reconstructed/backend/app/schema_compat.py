"""Small SQLite compatibility migration for the bundled development database.

Production PostgreSQL deployments should use normal managed migrations. This
keeps existing local Kasim 2.x databases runnable after the 3.0 reconstruction.
"""

from sqlalchemy import inspect, text
from sqlalchemy.engine import Engine


SQLITE_COLUMNS: dict[str, dict[str, str]] = {
    "access_policies": {
        "policy_mode": "VARCHAR NOT NULL DEFAULT 'SPECIFIC_BROWSER_NO_AI'",
        "web_access_scope": "VARCHAR NOT NULL DEFAULT 'ANY_SITE'",
    },
    "users": {
        "auth_provider": "VARCHAR NOT NULL DEFAULT 'password'",
    },
    "exam_sessions": {
        "description": "TEXT",
        "allowed_ai": "VARCHAR",
        "policy_mode": "VARCHAR NOT NULL DEFAULT 'SPECIFIC_BROWSER_NO_AI'",
        "camera_required": "BOOLEAN NOT NULL DEFAULT 0",
        "submissions_enabled": "BOOLEAN NOT NULL DEFAULT 1",
    },
    "student_sessions": {
        "camera_status": "VARCHAR NOT NULL DEFAULT 'not_required'",
        "camera_frame_path": "TEXT",
        "camera_frame_updated_at": "DATETIME",
        "completed_at": "DATETIME",
    },
}


def apply_sqlite_compatibility_migrations(engine: Engine) -> None:
    if engine.dialect.name != "sqlite":
        return
    inspector = inspect(engine)
    existing_tables = set(inspector.get_table_names())
    with engine.begin() as connection:
        for table, columns in SQLITE_COLUMNS.items():
            if table not in existing_tables:
                continue
            existing_columns = {item["name"] for item in inspector.get_columns(table)}
            for name, definition in columns.items():
                if name not in existing_columns:
                    connection.execute(text(
                        f'ALTER TABLE "{table}" ADD COLUMN "{name}" {definition}'
                    ))
