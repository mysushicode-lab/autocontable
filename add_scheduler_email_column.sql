-- Add scheduler_email column to client_files table
-- Run this migration manually or via Alembic

ALTER TABLE client_files
ADD COLUMN IF NOT EXISTS scheduler_email VARCHAR(200);

-- Add comment for documentation
COMMENT ON COLUMN client_files.scheduler_email IS 'Email address monitored by the scheduler for automatic invoice import';
