# Scripts

## PostgreSQL Migration

### Migrating from SQLite to PostgreSQL

If you're moving from SQLite to PostgreSQL (recommended for production):

1. **Start PostgreSQL** (if using docker-compose.yml with PostgreSQL):
   ```bash
   docker compose up -d postgres
   ```

2. **Set PostgreSQL connection URL**:
   ```bash
   export DATABASE_URL="postgresql://autocontable:changeme@localhost:5432/autocontable"
   export POSTGRES_PASSWORD="changeme"
   ```

3. **Run the migration script**:
   ```bash
   python scripts/migrate-sqlite-to-pg.py
   ```

4. **Update your environment variables** to use PostgreSQL permanently:
   - Edit `.env`: `DATABASE_URL=postgresql://autocontable:changeme@localhost:5432/autocontable`
   - Or set it in docker-compose.yml (already configured in production docker-compose.yml)

5. **Restart services**:
   ```bash
   docker compose restart backend scheduler
   ```

The migration script will:
- Create all tables in PostgreSQL
- Copy all data from SQLite
- Handle auto-increment sequence resets
- Skip duplicate records (ON CONFLICT DO NOTHING)

## Backup System

### Overview

Automated backup system for autocontable that backs up:
- SQLite database (`data/accounting.db`)
- Uploaded documents (`data/uploads/`)
- Exported reports (`data/exports/`)

## Configuration

The backup service runs daily at midnight (24-hour intervals) via Docker Compose.

Environment variables (configured in `docker-compose.yml`):
- `DATA_DIR`: Directory containing data to backup (default: `/app/data`)
- `BACKUP_DIR`: Directory to store backups (default: `/app/backups`)
- `RETENTION_DAYS`: How many days to keep old backups (default: `30`)

## Usage

### Automated Backups

Backups run automatically via the `backup` service in Docker Compose:

```bash
# View backup logs
docker compose logs backup -f

# Check backup status
curl -H "Authorization: Bearer YOUR_TOKEN" https://your-domain.com/api/reports/backup-status
```

### Manual Backup

```bash
# Run backup manually
docker compose exec backup /app/scripts/backup.sh
```

### Restore from Backup

```bash
# List available backups
docker compose exec backup ls -lh /app/backups/

# Restore from a specific backup
docker compose exec backup /app/scripts/restore.sh /app/backups/autocontable_backup_20260731_120000.tar.gz

# Restart services after restore
docker compose restart backend scheduler
```

### Access Backup Files

Backup files are stored in the `backup-data` Docker volume:

```bash
# Copy backup to local machine
docker compose cp backup:/app/backups/autocontable_backup_20260731_120000.tar.gz ./

# Inspect backup volume
docker volume inspect autocontable_backup-data
```

## Backup Format

Backups are compressed tar archives (`.tar.gz`) containing:
```
accounting.db         # SQLite database
uploads/              # Uploaded invoices and documents
exports/              # Generated reports (if any)
```

## Monitoring

The `/api/reports/backup-status` endpoint returns:
```json
{
  "has_backups": true,
  "latest_backup": "autocontable_backup_20260731_120000.tar.gz",
  "latest_date": "2026-07-31T12:00:00",
  "size_mb": 45.3,
  "total_backups": 15
}
```

## Recovery Procedure

In case of data loss:

1. Stop the application:
   ```bash
   docker compose stop backend scheduler
   ```

2. Restore from backup:
   ```bash
   docker compose exec backup /app/scripts/restore.sh /app/backups/autocontable_backup_YYYYMMDD_HHMMSS.tar.gz
   ```

3. Restart the application:
   ```bash
   docker compose start backend scheduler
   ```

## Off-site Backups

For production, it's recommended to also copy backups off-site. You can:

1. **Manual copy**: Periodically download backups to a secure location
2. **Automated sync**: Add a sidecar container with rclone/restic to sync to S3/Backblaze/etc.
3. **Hetzner snapshots**: Use Hetzner's volume snapshot feature for the backup volume

Example with rclone (to be added as a separate service):
```bash
# Install rclone in backup container or separate service
rclone sync /app/backups remote:autocontable-backups
```
