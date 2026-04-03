III. QUALITY AUDIT AND ANALYTICS
--1. Incident volume trends & spikes
--incidents were excluded due to missing or unparsable event timestamps
SELECT COUNT(*) AS excluded_incidents 
FROM v2_incident 
WHERE event_ts IS NULL;

-- Count incidents by day
SELECT 
    DATE(event_ts) AS incident_date,
    COUNT(*) AS incident_count
FROM v2_incident
WHERE event_ts IS NOT NULL
GROUP BY incident_date
ORDER BY incident_date;

--Count incidents by week
SELECT 
  EXTRACT(WEEK FROM event_ts) AS week_number,
  COUNT(*) AS incident_count
FROM v2_incident
WHERE event_ts IS NOT NULL
GROUP BY EXTRACT(YEAR FROM event_ts), EXTRACT(WEEK FROM event_ts)
ORDER BY incident_count DESC;

-- Day spikes (>95th percentile)
WITH daily_counts AS (
    SELECT DATE(event_ts) AS incident_date, COUNT(*) AS incident_count
    FROM v2_incident WHERE event_ts IS NOT NULL
    GROUP BY incident_date
),
threshold AS (
    SELECT
        PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY incident_count)  AS p95,
        ROUND(AVG(incident_count), 1) AS avg_daily
    FROM daily_counts
)
SELECT
    d.incident_date,
    d.incident_count,
    avg_daily,
    p95
FROM daily_counts d, threshold t
WHERE d.incident_count > t.p95
ORDER BY d.incident_count DESC;

-- Week spikes
WITH weekly_counts AS (
    SELECT
        EXTRACT(WEEK FROM event_ts)  AS week_number,
        COUNT(*)                     AS incident_count
    FROM v2_incident
    WHERE event_ts IS NOT NULL
    GROUP BY week_number
),
threshold AS (
    SELECT
        ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY incident_count)::numeric, 1) AS p95,
        ROUND(AVG(incident_count), 1) AS avg_weekly
    FROM weekly_counts
)
SELECT
    w.week_number,
    w.incident_count,
    avg_weekly,
    p95
FROM weekly_counts w, threshold t
WHERE w.incident_count > t.p95
ORDER BY w.incident_count DESC;

--2. Top Incident Categories
--Top categories 
SELECT
    category,
    COUNT(*) AS incident_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS percentage
FROM v2_incident
GROUP BY category 
ORDER BY incident_count DESC;

--3. Severity distributions by department
--Total number of incidents that could be linked to a department
-- Tính tổng số lượng sự cố có thể liên kết với Department và tỷ lệ %
SELECT 
    COUNT(i.incident_id) AS linked_to_department,
    (SELECT COUNT(*) FROM v2_incident) AS total_incidents,
    ROUND(100.0 * COUNT(i.incident_id) / (SELECT COUNT(*) FROM v2_incident), 1) AS linked_pct
FROM v2_incident i
JOIN core_staff s ON i.staff_id = s.staff_id
WHERE s.department IS NOT NULL;


--Severity distributions by department
SELECT
    s.department,
    COUNT(*) AS total_incidents,
    SUM(CASE WHEN i.severity = 'low' THEN 1 ELSE 0 END) AS low,
    SUM(CASE WHEN i.severity = 'medium' THEN 1 ELSE 0 END) AS medium,
    SUM(CASE WHEN i.severity = 'high' THEN 1 ELSE 0 END) AS high,
    SUM(CASE WHEN i.severity = 'critical' THEN 1 ELSE 0 END) AS critical,
    SUM(CASE WHEN i.severity IS NULL THEN 1 ELSE 0 END) AS unknown
FROM v2_incident i
JOIN core_staff s ON i.staff_id = s.staff_id
WHERE s.department IS NOT NULL
GROUP BY s.department
ORDER BY total_incidents DESC;

--High/critical severity incidents 
SELECT
    s.department,
    COUNT(*) AS total_incidents,
    SUM(CASE WHEN i.severity IN ('high', 'critical') THEN 1 ELSE 0 END) AS high_critical_count,
    ROUND(100.0 * SUM(CASE WHEN i.severity IN ('high', 'critical') THEN 1 ELSE 0 END) 
        / NULLIF(COUNT(*), 0), 1) AS severity_ratio_pct
FROM v2_incident i
JOIN core_staff s ON i.staff_id = s.staff_id
WHERE s.department IS NOT NULL
GROUP BY s.department
ORDER BY severity_ratio_pct DESC;


--4. Follow-up completion & overdue rates
--Quantify incidents that have follow-up actions
SELECT 
  COUNT(DISTINCT i.incident_id) AS total_incidents,
  COUNT(DISTINCT a.incident_id) AS incidents_with_actions,
  COUNT(DISTINCT i.incident_id) - COUNT(DISTINCT a.incident_id) AS incidents_without_actions,
  ROUND(100.0 * COUNT(DISTINCT a.incident_id) / COUNT(DISTINCT i.incident_id), 1) AS pct_with_actions
FROM v2_incident i
LEFT JOIN v2_action a ON i.incident_id = a.incident_id;

--Quantify high/critical severity incidents that have follow-up actions
SELECT
    COUNT(*) AS total_high_critical,
    COUNT(*) FILTER (WHERE incident_id IN (SELECT incident_id FROM v2_action)) AS with_action_count,
    ROUND(100.0 * COUNT(*) FILTER (WHERE incident_id IN (SELECT incident_id FROM v2_action)) / COUNT(*), 1) AS with_action_pct
FROM v2_incident
WHERE severity IN ('high', 'critical');

--Completion rate based on completion status
SELECT
    COUNT(*) AS total_actions,
    SUM(CASE WHEN status = 'done' THEN 1 ELSE 0 END) AS completed,
    SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) AS pending,
	SUM(CASE WHEN status = 'unknown' THEN 1 ELSE 0 END) AS unknown,
    ROUND(100.0 * SUM(CASE WHEN status = 'done' THEN 1 ELSE 0 END) 
        /SUM(CASE WHEN status IN ('done','pending') THEN 1 ELSE 0 END), 1) AS completion_rate_pct
FROM v2_action;

-- Overdue rates compare to total number of actions
SELECT    
	overdue_status,
    COUNT(*) AS action_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS percentage
FROM v2_action
GROUP BY overdue_status
ORDER BY action_count DESC;
--Overdue rates compare to total number of action with known status (not ‘indeterminate’) 
SELECT 	overdue_status,
    	COUNT(*) AS action_count,
    	ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS percentage
FROM v2_action
WHERE overdue_status != 'indeterminate'
GROUP BY overdue_status
ORDER BY action_count DESC;

--5. Reporting Delay
SELECT 
    ROUND(AVG(delay_days), 1) AS mean_delay,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY delay_days) AS median_delay,
    MIN(delay_days) AS min_delay,
    MAX(delay_days) AS max_delay
FROM v2_incident
WHERE delay_days IS NOT NULL;

--Identify extreme cases
SELECT 
    COUNT(*) AS total,
    ROUND(100.0 * SUM(CASE WHEN delay_days > 15  THEN 1 ELSE 0 END) / COUNT(*), 1) AS over_15_pct,
    ROUND(100.0 * SUM(CASE WHEN delay_days > 60  THEN 1 ELSE 0 END) / COUNT(*), 1) AS over_60_pct,
    ROUND(100.0 * SUM(CASE WHEN delay_days > 180 THEN 1 ELSE 0 END) / COUNT(*), 1) AS over_180_pct
FROM v2_incident
WHERE delay_days IS NOT NULL;
select *
from core_patient
ORDER by mrn_v2;
--6.Under-reporting signals
WITH dept_stats AS (
    SELECT
        s.department,
        COUNT(DISTINCT i.incident_id) AS incident_count,
        COUNT(DISTINCT s.staff_id) AS total_staff,
        ROUND(1.0 * COUNT(DISTINCT i.incident_id) / NULLIF(COUNT(DISTINCT s.staff_id), 0), 2) AS incidents_per_staff
    FROM core_staff s
    LEFT JOIN v2_incident i ON s.staff_id = i.staff_id
    WHERE s.department IS NOT NULL
    GROUP BY s.department
),
avg_stat AS (
    SELECT ROUND(AVG(incidents_per_staff), 2) AS avg_incidents_per_staff
    FROM dept_stats
)
SELECT
    d.department,
    d.incident_count,
    d.total_staff,
    d.incidents_per_staff,
    a.avg_incidents_per_staff
FROM dept_stats d
CROSS JOIN avg_stat a
ORDER BY d.incidents_per_staff ASC;

--7. Duplicate reporting patterns 
-- Flag suspected duplicates in v2_incident
WITH scored_pairs AS (
    SELECT
        a.incident_id AS incident_a,
        b.incident_id AS incident_b,
        (CASE WHEN a.location_id = b.location_id THEN 1 ELSE 0 END +
         CASE WHEN a.category    = b.category    THEN 1 ELSE 0 END +
         CASE WHEN ABS(DATE(a.event_ts) - DATE(b.event_ts)) <= 1 THEN 1 ELSE 0 END
        ) AS match_score
    FROM v2_incident a
    JOIN v2_incident b ON a.incident_id < b.incident_id
    WHERE a.patient_id = b.patient_id
)
UPDATE v2_incident i
SET
    suspected_duplicate = TRUE,
    duplicate_of_incident_id = sp.incident_b
FROM scored_pairs sp
WHERE i.incident_id = sp.incident_a
  AND sp.match_score >= 2;

--Suspected duplicates
SELECT *
FROM v2_incident
WHERE suspected_duplicate = TRUE 
      OR incident_id IN  (SELECT duplicate_of_incident_id FROM v2_incident)
ORDER BY patient_id, incident_id;

--8. Data quality indicators
-- Missing patient links
SELECT
    COUNT(*) AS total_incidents,
    SUM(CASE WHEN patient_id IS NULL THEN 1 ELSE 0 END) AS missing_patient_ids,
    ROUND(100.0 * SUM(CASE WHEN patient_id IS NULL THEN 1 ELSE 0 END) / COUNT(*), 1) AS missing_pct
FROM v2_incident;

-- Quantify unknown locations
SELECT 
    COUNT(*) AS total_incidents,
    SUM(CASE WHEN location_id IS NULL THEN 1 ELSE 0 END) AS unknown_location,
    ROUND(100.0 * SUM(CASE WHEN location_id IS NULL THEN 1 ELSE 0 END) / COUNT(*), 1) AS unknown_pct
FROM v2_incident;

-- Non-standard category
SELECT
    COUNT(*) AS total_incidents,
	SUM(CASE WHEN category_flag ='missing' THEN 1 ELSE 0 END) AS unknown_category,
    SUM(CASE WHEN category_flag IS NULL THEN 1 ELSE 0 END) AS stardard_category,
    SUM(CASE WHEN category_flag = 'non-standard' THEN 1 ELSE 0 END) AS non_standard_category,
    ROUND(100.0 * SUM(CASE WHEN category_flag = 'non-standard' THEN 1 ELSE 0 END) / COUNT(*), 1) AS non_standard_pct
FROM v2_incident;
-- Non-standard severity
SELECT
    COUNT(*) AS total_incidents,
	SUM(CASE WHEN severity_flag ='missing' THEN 1 ELSE 0 END) AS unknown_severity,
    SUM(CASE WHEN severity_flag IS NULL THEN 1 ELSE 0 END) AS stardard_severity,
    SUM(CASE WHEN severity_flag = 'non-standard' THEN 1 ELSE 0 END) AS non_standard_severity,
    ROUND(100.0 * SUM(CASE WHEN severity_flag = 'non-standard' THEN 1 ELSE 0 END) / COUNT(*), 1) AS non_standard_pct
FROM v2_incident;

--Category mismatching signal
SELECT 
    COUNT(*) AS category_mismatch_count,
    (SELECT COUNT(*) FROM v2_incident) AS total_incident,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM v2_incident), 1) AS mismatch_pct
FROM v2_incident
WHERE category_reclassified IS NOT NULL
  AND category != category_reclassified;
	  
--Severity mismatching signal 
SELECT 
    COUNT(*) AS severity_mismatch_count,
    (SELECT COUNT(*) FROM v2_incident) AS total_incidents,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM v2_incident), 1) AS mismatch_pct
FROM f_incident f
JOIN v2_incident i ON f.incident_id = i.incident_id
WHERE f.description ILIKE '%no harm%'
  AND i.severity IN ('high', 'critical');

--Quantify orphan actions
SELECT
    COUNT(*) AS total_actions,
    SUM(CASE WHEN orphan_flag = TRUE THEN 1 ELSE 0 END) AS orphan_count,
    ROUND(100.0 * SUM(CASE WHEN orphan_flag = TRUE THEN 1 ELSE 0 END) / COUNT(*), 1) AS orphan_pct
FROM v2_action;

--Incompleted action tracking
SELECT
    COUNT(*) AS total_actions,
    SUM(CASE WHEN status = 'unknown' OR status IS NULL THEN 1 ELSE 0 END) AS incomplete_count,
    ROUND(100.0 * SUM(CASE WHEN status = 'unknown' OR status IS NULL THEN 1 ELSE 0 END) / COUNT(*), 1) AS incomplete_pct
FROM v2_action;

SELECT
    status,
    COUNT(*) AS action,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM v2_action), 2) AS action_pct
FROM v2_action
GROUP BY status
ORDER BY action DESC;


--Number of incident with illogical chronology of timestamp 
SELECT
    COUNT(*) AS illogical_incident,
    (SELECT COUNT(*) FROM v2_incident) AS total_incident,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM v2_incident), 1) AS illogical_incident_pct
FROM v2_incident
WHERE reported_ts < event_ts;