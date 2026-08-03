# Backup System Deployment Guide

## What Was Implemented

A complete automated backup system for autocontable that:

1. **Backs up daily**:
   - SQLite database (`data/accounting.db`)
   - Uploaded documents (`data/uploads/`)
   - Exported reports (`data/exports/`)

2. **Features**:
   - Automated daily backups via Docker service
   - 30-day retention policy (configurable)
   - Safe SQLite backup using `.backup` command (avoids corruption)
   - Compressed tar.gz archives
   - Status API endpoint for monitoring
   - Restore script for recovery

## Files Added/Modified

### New Files
- `scripts/backup.sh` - Main backup script
- `scripts/restore.sh` - Restore script
- `scripts/test-backup.sh` - Local testing script
- `scripts/README.md` - Documentation

### Modified Files
- `docker-compose.yml` - Added backup service and backup-data volume
- `Dockerfile` - Added sqlite3 and scripts/ directory
- `src/api/reports.py` - Added `/api/reports/backup-status` endpoint

## Deployment Steps

### 1. Deploy to Dokploy

```bash
# From your local machine, commit and push
git add scripts/ Dockerfile docker-compose.yml src/api/reports.py
git commit -m "feat: add automated backup system for production data"
git push

# On Dokploy, rebuild and redeploy
# The new backup service will start automatically
```

### 2. Verify Backup Service

```bash
# SSH to your Hetzner VPS
ssh root@37.27.28.246

# Navigate to project directory
cd /path/to/autocontable

# Check backup service status
docker compose ps backup

# View backup logs
docker compose logs backup -f

# Check if backups are being created
docker compose exec backup ls -lh /app/backups/
```

### 3. Test Backup Manually

```bash
# Run a backup manually to test
docker compose exec backup /app/scripts/backup.sh

# Verify backup was created
docker compose exec backup ls -lh /app/backups/
```

### 4. Test API Endpoint

```bash
# Get an auth token (replace with your credentials)
TOKEN=$(curl -X POST https://your-domain.com/api/auth/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin@example.com&password=yourpassword" | jq -r .access_token)

# Check backup status
curl -H "Authorization: Bearer $TOKEN" https://your-domain.com/api/reports/backup-status
```

Expected response:
```json
{
  "has_backups": true,
  "latest_backup": "autocontable_backup_20260731_120000.tar.gz",
  "latest_date": "2026-07-31T12:00:00",
  "size_mb": 45.3,
  "total_backups": 1
}
```

## Configuration

Environment variables (already configured in `docker-compose.yml`):

```yaml
environment:
  - DATA_DIR=/app/data           # Data directory to backup
  - BACKUP_DIR=/app/backups      # Where to store backups
  - RETENTION_DAYS=30            # Keep backups for 30 days
```

To change retention period, edit `docker-compose.yml` and redeploy.

## Backup Schedule

The backup service runs every 24 hours (86400 seconds). First backup runs when the service starts, then repeats daily.

To change schedule:
1. Edit `docker-compose.yml` backup service command
2. Change `sleep 86400` to desired interval (in seconds)
3. Redeploy: `docker compose up -d backup`

Examples:
- Every 12 hours: `sleep 43200`
- Every 6 hours: `sleep 21600`
- Every hour: `sleep 3600`

## Recovery Procedure

If you need to restore from backup:

```bash
# 1. Stop the application
docker compose stop backend scheduler

# 2. List available backups
docker compose exec backup ls -lh /app/backups/

# 3. Restore (replace filename with actual backup)
docker compose exec backup /app/scripts/restore.sh /app/backups/autocontable_backup_YYYYMMDD_HHMMSS.tar.gz

# 4. Restart the application
docker compose start backend scheduler
```

## Off-Site Backup (Recommended for Production)

The current implementation stores backups on the same server. For production, you should also:

### Option 1: Manual Download (Simple)
```bash
# Periodically download backups to local machine
docker compose cp backup:/app/backups/ ./local-backups/

# Or use rsync
rsync -avz root@37.27.28.246:/path/to/backups/ ./local-backups/
```

### Option 2: Automated Cloud Sync (Better)
Add rclone or restic to sync backups to cloud storage (S3, Backblaze, etc.):

```yaml
# Add to docker-compose.yml
  backup-sync:
    image: rclone/rclone:latest
    volumes:
      - backup-data:/data:ro
      - ./rclone.conf:/config/rclone/rclone.conf:ro
    command: >
      sh -c "while true; do
        rclone sync /data remote:autocontable-backups;
        sleep 3600;
      done"
```

### Option 3: Hetzner Snapshots
Use Hetzner's volume snapshot feature to snapshot the backup volume weekly.

## Monitoring

Add to your monitoring dashboard:
- Call `/api/reports/backup-status` endpoint
- Alert if `has_backups: false` or `latest_date` is older than 25 hours

Example health check (add to cron):
```bash
#!/bin/bash
# /etc/cron.daily/check-backups

STATUS=$(curl -s -H "Authorization: Bearer $TOKEN" https://your-domain.com/api/reports/backup-status)
HAS_BACKUPS=$(echo $STATUS | jq -r .has_backups)

if [ "$HAS_BACKUPS" != "true" ]; then
    echo "ALERT: No backups found!" | mail -s "Autocontable Backup Alert" admin@example.com
fi
```

## Testing

Before deploying to production, test locally:

```bash
# Run the test script
cd /path/to/autocontable
./scripts/test-backup.sh
```

This will:
1. Create test data
2. Run backup script
3. Verify backup contents
4. Test restore
5. Clean up

## Disk Space Considerations

With 30-day retention and daily backups:
- Average backup size: ~50MB (depends on uploaded documents)
- Total storage needed: ~1.5GB (30 days × 50MB)
- Monitor with: `docker compose exec backup du -sh /app/backups/`

If disk space is limited:
- Reduce `RETENTION_DAYS` to 7 or 14
- Consider off-site backups and shorter local retention

## Security Notes

1. **Backup access**: Backups contain sensitive accounting data. Ensure proper access controls on the VPS.
2. **Encryption**: Consider encrypting backups at rest if storing off-site.
3. **API endpoint**: The `/backup-status` endpoint requires authentication (already implemented).
4. **Restore safety**: The restore script prompts for confirmation before overwriting data.

## Troubleshooting

### Backup service not running
```bash
docker compose logs backup
docker compose restart backup
```

### No backups created
```bash
# Check backup service logs
docker compose logs backup

# Manually run backup to see errors
docker compose exec backup /app/scripts/backup.sh
```

### Backup directory not accessible
```bash
# Check volume mount
docker compose exec backup ls -la /app/backups/

# Check volume exists
docker volume ls | grep backup
```

### Database locked during backup
The backup script uses SQLite's `.backup` command, which is safe to run while the database is in use. If you still encounter locks, temporarily stop the backend service during backup.

## Next Steps

After deployment:

1. ✅ Deploy to production
2. ✅ Verify first backup is created (within 24 hours)
3. ✅ Test API endpoint
4. ⚠️ Set up off-site backup sync
5. ⚠️ Add monitoring/alerting
6. ⚠️ Document recovery procedure for team
7. ⚠️ Test restore procedure quarterly

## Support

For issues or questions about the backup system:
- Check logs: `docker compose logs backup`
- Review scripts: `scripts/backup.sh`, `scripts/restore.sh`
- Read documentation: `scripts/README.md`
