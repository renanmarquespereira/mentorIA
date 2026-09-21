from sqlalchemy import text
from app.db.session import engine

def run_lightweight_migrations():
    """
    Development migrations for existing databases.
    Safe to execute repeatedly because every ALTER uses IF NOT EXISTS.
    """
    statements = [
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS role VARCHAR(20) DEFAULT 'mentee'",
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS approval_status VARCHAR(30) DEFAULT 'pending_approval'",
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS approved_by_user_id VARCHAR(36)",
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS phone VARCHAR(40) DEFAULT ''",
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS profile_photo TEXT DEFAULT ''",
        "UPDATE users SET role = 'mentee' WHERE role IS NULL",
        "UPDATE users SET approval_status = 'active' WHERE approval_status IS NULL",
        "CREATE INDEX IF NOT EXISTS ix_users_role ON users (role)",
        "CREATE INDEX IF NOT EXISTS ix_users_phone ON users (phone)",
        "CREATE INDEX IF NOT EXISTS ix_users_approval_status ON users (approval_status)",
        "ALTER TABLE pillar_reports ADD COLUMN IF NOT EXISTS mentor_review_status VARCHAR(20) DEFAULT 'none'",
        "ALTER TABLE pillar_reports ADD COLUMN IF NOT EXISTS mentor_review_note TEXT DEFAULT ''",
        "ALTER TABLE pillar_reports ADD COLUMN IF NOT EXISTS mentor_reviewed_by_user_id VARCHAR(36)",
        "ALTER TABLE pillar_reports ADD COLUMN IF NOT EXISTS mentor_reviewed_at TIMESTAMP",
        "ALTER TABLE pillar_reports ADD COLUMN IF NOT EXISTS completion_question TEXT",
        "ALTER TABLE action_plan_items ADD COLUMN IF NOT EXISTS due_date DATE",
        "ALTER TABLE action_plan_items ADD COLUMN IF NOT EXISTS notes TEXT DEFAULT ''",
        "ALTER TABLE action_plan_items ADD COLUMN IF NOT EXISTS completed_at TIMESTAMP",
        "ALTER TABLE action_plan_items ADD COLUMN IF NOT EXISTS progress_percent INTEGER DEFAULT 0",
        "ALTER TABLE action_plan_items ADD COLUMN IF NOT EXISTS linked_session_id VARCHAR(36)",
        "ALTER TABLE mentor_sessions ADD COLUMN IF NOT EXISTS subject VARCHAR(300) DEFAULT ''",
        "ALTER TABLE mentor_sessions ADD COLUMN IF NOT EXISTS mentee_hidden BOOLEAN DEFAULT FALSE",
        "ALTER TABLE mentor_sessions ADD COLUMN IF NOT EXISTS cancellation_reason TEXT DEFAULT ''",
        "CREATE INDEX IF NOT EXISTS ix_action_plan_items_linked_session_id ON action_plan_items (linked_session_id)",
        "ALTER TABLE mentee_checkins ADD COLUMN IF NOT EXISTS confidence_level INTEGER DEFAULT 3",
        "ALTER TABLE sales ADD COLUMN IF NOT EXISTS request_id VARCHAR(64)",
        "CREATE UNIQUE INDEX IF NOT EXISTS uq_sales_user_request ON sales (user_id, request_id)",
    ]

    with engine.begin() as conn:
        for statement in statements:
            conn.execute(text(statement))
