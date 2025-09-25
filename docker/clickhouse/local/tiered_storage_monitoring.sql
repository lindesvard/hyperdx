-- ClickHouse Tiered Storage Monitoring Queries for HyperDX
-- Execute these queries to monitor and verify the tiered storage configuration

-- 1. Check disk usage and configuration
SELECT 
    name,
    path,
    formatReadableSize(total_space) AS total,
    formatReadableSize(free_space) AS free,
    formatReadableSize(total_space - free_space) AS used,
    round((1 - free_space / total_space) * 100, 2) AS used_percent
FROM system.disks
WHERE name IN ('hot_disk', 'cold_disk', 'default')
ORDER BY name;

-- 2. Check storage policies configuration
SELECT 
    policy_name,
    volume_name,
    disk_name,
    max_data_part_size,
    move_factor,
    perform_ttl_move_on_insert
FROM system.storage_policies
WHERE policy_name = 'tiered_storage';

-- 3. Check data distribution across volumes for all HyperDX tables
SELECT 
    database,
    table,
    disk_name,
    formatReadableSize(sum(bytes_on_disk)) AS size,
    count() AS parts_count,
    min(min_time) AS oldest_data,
    max(max_time) AS newest_data
FROM system.parts
WHERE active 
    AND database = 'default' 
    AND table IN ('otel_logs', 'otel_traces', 'otel_metrics_sum', 'otel_metrics_histogram', 'otel_metrics_gauge', 'hyperdx_sessions')
GROUP BY database, table, disk_name
ORDER BY database, table, sum(bytes_on_disk) DESC;

-- 4. Monitor TTL movements and data aging
SELECT 
    database,
    table,
    partition,
    disk_name,
    min_time,
    max_time,
    formatReadableSize(bytes_on_disk) AS size,
    rows
FROM system.parts
WHERE active 
    AND database = 'default'
    AND table IN ('otel_logs', 'otel_traces', 'otel_metrics_sum', 'otel_metrics_histogram', 'otel_metrics_gauge', 'hyperdx_sessions')
ORDER BY table, max_time DESC
LIMIT 50;

-- 5. Check table storage policies
SELECT 
    database,
    name AS table,
    storage_policy,
    engine
FROM system.tables
WHERE database = 'default' 
    AND name IN ('otel_logs', 'otel_traces', 'otel_metrics_sum', 'otel_metrics_histogram', 'otel_metrics_gauge', 'hyperdx_sessions');

-- 6. Monitor data volume trends (daily data volume for capacity planning)
SELECT 
    toDate(TimestampTime) AS date,
    'logs' AS table_type,
    formatReadableSize(sum(bytes_on_disk)) AS daily_size,
    count() AS parts_count
FROM system.parts p
JOIN (SELECT partition FROM system.parts WHERE table = 'otel_logs' AND active) t 
    ON p.partition = t.partition
WHERE p.table = 'otel_logs' AND p.active
GROUP BY date
ORDER BY date DESC
LIMIT 30;

-- 7. Check TTL expressions for all tables
SELECT 
    database,
    table,
    ttl_expression,
    engine
FROM system.tables
WHERE database = 'default' 
    AND name IN ('otel_logs', 'otel_traces', 'otel_metrics_sum', 'otel_metrics_histogram', 'otel_metrics_gauge', 'hyperdx_sessions')
    AND ttl_expression != '';

-- 8. Monitor move operations (shows recent data movements between volumes)
SELECT 
    event_time,
    database,
    table,
    part_name,
    disk_name,
    formatReadableSize(size_in_bytes) AS size
FROM system.part_log
WHERE event_type = 'MovePart'
    AND database = 'default'
    AND event_time > now() - INTERVAL 24 HOUR
ORDER BY event_time DESC
LIMIT 20;

-- 9. Storage utilization summary
SELECT 
    'Hot Storage' AS storage_type,
    formatReadableSize(sum(bytes_on_disk)) AS total_used
FROM system.parts
WHERE active AND disk_name = 'hot_disk'
UNION ALL
SELECT 
    'Cold Storage' AS storage_type,
    formatReadableSize(sum(bytes_on_disk)) AS total_used
FROM system.parts
WHERE active AND disk_name = 'cold_disk'
UNION ALL
SELECT 
    'Default Storage' AS storage_type,
    formatReadableSize(sum(bytes_on_disk)) AS total_used
FROM system.parts
WHERE active AND disk_name = 'default';

-- 10. Test query to verify configuration works
-- This will show if tables are using the tiered storage policy
SELECT 
    'Configuration Test' AS test_name,
    CASE 
        WHEN count(*) > 0 THEN 'PASS - Tables found with tiered storage'
        ELSE 'FAIL - No tables using tiered storage'
    END AS result
FROM system.tables
WHERE storage_policy = 'tiered_storage' AND database = 'default';
