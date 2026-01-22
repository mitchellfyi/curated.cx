# Background Jobs - Solid Queue Configuration

## Overview

Curated.cx uses **Solid Queue** (Rails-native database-backed job queue) for background job processing and recurring task scheduling.

**Why Solid Queue?**
- ✅ Rails-native (no external dependencies like Redis)
- ✅ Database-backed (uses existing PostgreSQL)
- ✅ Built-in recurring task support
- ✅ Simple deployment (runs in same process or separate worker)
- ✅ Works seamlessly with Dokku/Kamal deployments

---

## Configuration

### Queue Adapter

**Production** (`config/environments/production.rb`):
```ruby
config.active_job.queue_adapter = :solid_queue
config.solid_queue.connects_to = { database: { writing: :queue } }
```

Uses separate `queue` database connection to avoid connection pool conflicts.

### Worker Configuration

**Queue Config** (`config/queue.yml`):
```yaml
default:
  dispatchers:
    - polling_interval: 1
      batch_size: 500
  workers:
    - queues: "*"
      threads: 3
      processes: <%= ENV.fetch("JOB_CONCURRENCY", 1) %>
      polling_interval: 0.1
```

**Worker Process**: `bin/jobs` - Solid Queue CLI worker

---

## Deployment Modes

### Single-Server Mode (Default)

**Runs inside Puma process**:
```ruby
# config/puma.rb
plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]
```

**Environment Variable** (`config/deploy.yml`):
```yaml
env:
  clear:
    SOLID_QUEUE_IN_PUMA: true
```

**Benefits**:
- No separate process to manage
- Shared database connections
- Simpler deployment

### Dedicated Worker Mode (Scaling)

**Separate job worker process**:
```yaml
# config/deploy.yml
servers:
  web:
    - 192.168.0.1
  job:
    hosts:
      - 192.168.0.1
    cmd: bin/jobs
```

**Benefits**:
- Isolated worker process
- Can scale workers independently
- Better resource management

---

## Recurring Jobs

### Configuration File

**File**: `config/recurring.yml`

**Format**:
```yaml
environment:
  job_name:
    class: JobClassName        # OR
    command: "Ruby.code.here"  # OR
    queue: queue_name          # Optional
    priority: 1                # Optional
    args: [arg1, arg2]         # Optional
    schedule: every 5 minutes  # Cron-style schedule
```

### Schedule Syntax

Solid Queue supports cron-style scheduling:

```yaml
# Every 5 minutes
schedule: every 5 minutes

# Every hour
schedule: every hour

# Every hour at specific minute
schedule: every hour at minute 12

# Specific time daily
schedule: at 5am every day

# Cron format
schedule: "*/15 * * * *"  # Every 15 minutes
```

### Current Recurring Jobs

**Heartbeat Job** (Every 5 minutes):
- **Purpose**: Verify job scheduling is working
- **Action**: Writes log entry and database record
- **Verification**: Check `heartbeat_logs` table

**Clear Finished Jobs** (Every hour at minute 12):
- **Purpose**: Clean up completed job records
- **Command**: `SolidQueue::Job.clear_finished_in_batches`

---

## Heartbeat Job

### Purpose

The heartbeat job runs every 5 minutes to verify recurring job scheduling is working correctly. It provides:

1. **Verification**: Confirms Solid Queue recurring tasks are executing
2. **Monitoring**: Logs execution timestamps for debugging
3. **Alerting**: Can be monitored to detect scheduling failures

### Implementation

**Job**: `app/jobs/heartbeat_job.rb`

**Actions**:
1. Writes structured log entry to Rails logger
2. Creates `HeartbeatLog` database record
3. Records timestamp, environment, and hostname

### Verification

**Check Recent Heartbeats**:
```ruby
# In Rails console
HeartbeatLog.latest
# => #<HeartbeatLog id: 123, executed_at: "2025-01-20 12:05:00", ...>

# Verify heartbeat ran in last 10 minutes
HeartbeatLog.verify_recent(within: 10.minutes)
# => true
```

**Check Logs**:
```bash
# Search for heartbeat entries
grep "HEARTBEAT" log/production.log

# Example output:
# [HEARTBEAT] {"timestamp":"2025-01-20T12:05:00Z","environment":"production","hostname":"web-1","message":"Heartbeat job executed successfully"}
```

**Database Query**:
```sql
SELECT * FROM heartbeat_logs
ORDER BY executed_at DESC
LIMIT 10;
```

### Troubleshooting

**No Heartbeats Appearing**:
1. Check if Solid Queue worker is running:
   ```bash
   # In production
   ps aux | grep solid_queue
   ```

2. Check recurring task status:
   ```ruby
   # In Rails console
   SolidQueue::RecurringTask.all
   ```

3. Verify `config/recurring.yml` is loaded:
   ```ruby
   # Check if recurring tasks are registered
   SolidQueue::RecurringTask.find_by(name: "heartbeat")
   ```

4. Check Solid Queue logs:
   ```bash
   tail -f log/production.log | grep -i "solid_queue\|heartbeat"
   ```

**Heartbeats Running Late**:
- Check worker process health
- Verify database connection pool is not exhausted
- Check system load (CPU/memory)

---

## Running Jobs Locally

### Development Mode

**Start Rails server** (includes Solid Queue plugin):
```bash
bin/rails server
```

Solid Queue runs inside Puma process automatically.

**Check Recurring Tasks**:
```bash
# In Rails console
rails console

# List recurring tasks
SolidQueue::RecurringTask.all

# Check heartbeat logs
HeartbeatLog.recent
```

### Test Mode

**Run Jobs Synchronously**:
```ruby
# config/environments/test.rb
config.active_job.queue_adapter = :test
```

**Manually Trigger Jobs**:
```ruby
# In test or console
HeartbeatJob.perform_now
```

---

## Production Deployment

### Dokku Deployment

**No Additional Setup Required**:
- Solid Queue runs inside Puma (via plugin)
- Recurring tasks auto-start with application
- Database migrations create necessary tables

**Verify Deployment**:
```bash
# SSH into Dokku container
dokku enter curated web

# Check logs
tail -f /app/log/production.log | grep HEARTBEAT

# Or check database
rails console
HeartbeatLog.recent
```

### Kamal Deployment

**Configured via `config/deploy.yml`**:
```yaml
env:
  clear:
    SOLID_QUEUE_IN_PUMA: true
```

**Verify**:
```bash
# Check container logs
kamal app logs

# Or exec into container
kamal app exec "rails console"
HeartbeatLog.recent
```

---

## Monitoring and Debugging

### Health Check Endpoint

**Check Job System Health**:
```ruby
# Add to health check controller
def heartbeat_status
  recent = HeartbeatLog.verify_recent(within: 10.minutes)
  render json: { healthy: recent, last_heartbeat: HeartbeatLog.latest&.executed_at }
end
```

### Monitoring Queries

**Recent Heartbeats**:
```ruby
HeartbeatLog.recent.limit(10)
```

**Heartbeats by Host**:
```ruby
HeartbeatLog.by_hostname("web-1").recent
```

**Heartbeats in Last Hour**:
```ruby
HeartbeatLog.where("executed_at > ?", 1.hour.ago).order(executed_at: :desc)
```

### Log Analysis

**Find Heartbeat Entries**:
```bash
# Production logs
grep "\[HEARTBEAT\]" log/production.log | tail -20

# With timestamps
grep "\[HEARTBEAT\]" log/production.log | tail -20 | cut -d' ' -f1-3
```

**Check for Missing Heartbeats**:
```ruby
# In Rails console - should have heartbeat every 5 minutes
last_heartbeat = HeartbeatLog.latest&.executed_at
if last_heartbeat && Time.current - last_heartbeat > 10.minutes
  puts "WARNING: No heartbeat in last 10 minutes!"
end
```

---

## Adding New Recurring Jobs

### Example: Daily Cleanup Job

1. **Create Job Class**:
```ruby
# app/jobs/daily_cleanup_job.rb
class DailyCleanupJob < ApplicationJob
  queue_as :default

  def perform
    # Cleanup logic here
  end
end
```

2. **Add to Recurring Config**:
```yaml
# config/recurring.yml
production:
  daily_cleanup:
    class: DailyCleanupJob
    schedule: at 3am every day
```

3. **Test Locally**:
```ruby
# In Rails console
DailyCleanupJob.perform_now
```

4. **Deploy and Verify**:
```bash
# After deployment, check recurring tasks
rails console
SolidQueue::RecurringTask.find_by(name: "daily_cleanup")
```

---

## Alternative: Cron Jobs (Fallback)

If Solid Queue recurring tasks are not suitable, you can use Dokku cron:

**File**: `dokku-cron` or `Procfile`:
```
cron: rails runner "HeartbeatJob.perform_now"
```

**Schedule via cron**:
```bash
# Add to crontab
*/5 * * * * cd /app && rails runner "HeartbeatJob.perform_now"
```

**Note**: Prefer Solid Queue recurring tasks - they're more reliable and easier to monitor.

---

## Summary

**Job Backend**: Solid Queue (Rails-native, database-backed)

**Scheduling**: Solid Queue recurring tasks via `config/recurring.yml`

**Heartbeat**: Runs every 5 minutes, writes to `heartbeat_logs` table

**Verification**: Check `HeartbeatLog.latest` or search logs for `[HEARTBEAT]`

**Deployment**: Works automatically in Dokku/Kamal - no additional setup needed

---

*Last Updated: 2025-01-20*
