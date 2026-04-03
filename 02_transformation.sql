INSERT INTO v2_incident (
    incident_id,
    event_ts,
    event_ts_flag,
    reported_ts,
    reported_ts_flag,
    patient_id,
    location_id,
    staff_id,
    category,
    category_flag,
    severity,
    severity_flag,
    category_reclassified 
)
SELECT
    incident_id,
    -- event_ts
    CASE
        WHEN event_ts ~ '^\d{2}\.\d{2}\.\d{4} \d{2}:\d{2}'
            AND SUBSTRING(event_ts FROM 4 FOR 2)::INT BETWEEN 1 AND 12
            THEN TO_TIMESTAMP(event_ts, 'DD.MM.YYYY HH24:MI:SS')
        WHEN event_ts ~ '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}'
            AND SUBSTRING(event_ts FROM 6 FOR 2)::INT BETWEEN 1 AND 12
            THEN TO_TIMESTAMP(event_ts, 'YYYY-MM-DD HH24:MI:SS')
        ELSE NULL
    END AS event_ts,
    -- event_ts_flag
    CASE
        WHEN TRIM(event_ts) IN ('', '??', 'n/a') OR event_ts IS NULL
            THEN 'missing'
        WHEN LOWER(event_ts) LIKE '%yesterday%' OR LOWER(event_ts) LIKE '%around%'
            THEN 'unparsable'
        WHEN (event_ts ~ '^\d{2}\.\d{2}\.\d{4} \d{2}:\d{2}'
            AND SUBSTRING(event_ts FROM 4 FOR 2)::INT > 12)
            OR (event_ts ~ '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}'
            AND SUBSTRING(event_ts FROM 6 FOR 2)::INT > 12)
            THEN 'unparsable'
        ELSE NULL
    END AS event_ts_flag,
    -- reported_ts
    CASE
        WHEN reported_ts ~ '^\d{2}\.\d{2}\.\d{4} \d{2}:\d{2}'
            AND SUBSTRING(reported_ts FROM 4 FOR 2)::INT <= 12
            THEN TO_TIMESTAMP(reported_ts, 'DD.MM.YYYY HH24:MI:SS')
        WHEN reported_ts ~ '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}'
            AND SUBSTRING(reported_ts FROM 6 FOR 2)::INT <= 12
            THEN TO_TIMESTAMP(reported_ts, 'YYYY-MM-DD HH24:MI:SS')
        ELSE NULL
    END AS reported_ts,
    -- reported_ts_flag
    CASE
        WHEN TRIM(reported_ts) IN ('', '??', 'n/a') OR reported_ts IS NULL
            THEN 'missing'
        WHEN LOWER(reported_ts) LIKE '%yesterday%' OR LOWER(reported_ts) LIKE '%around%'
            THEN 'unparsable'
        WHEN (reported_ts ~ '^\d{2}\.\d{2}\.\d{4} \d{2}:\d{2}'
            AND SUBSTRING(reported_ts FROM 4 FOR 2)::INT > 12)
            OR (reported_ts ~ '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}'
            AND SUBSTRING(reported_ts FROM 6 FOR 2)::INT > 12)
            THEN 'unparsable'
        ELSE NULL
    END AS reported_ts_flag,
    patient_id,
    location_id,
    staff_id,
    -- category
    CASE
        WHEN LOWER(TRIM(category)) IN ('equipment failure', 'equipmnt fail')    THEN 'equipment failure'
        WHEN LOWER(TRIM(category)) IN ('violence', 'violance')                  THEN 'violence'
        WHEN LOWER(TRIM(category)) IN ('medication error', 'medicaton eror')    THEN 'medication error'
        WHEN LOWER(TRIM(category)) IN ('fall', 'fal')                           THEN 'fall'
        WHEN LOWER(TRIM(category)) IN ('wrong patient', 'wrong pat.')           THEN 'wrong patient'
        WHEN LOWER(TRIM(category)) IN ('documentation error', 'documantation')  THEN 'documentation error'
        WHEN LOWER(TRIM(category)) IN ('delay', 'dely')                         THEN 'delay'
        WHEN LOWER(TRIM(category)) IN ('infection control', 'infecton ctrl')    THEN 'infection control'
        WHEN LOWER(TRIM(category)) IN ('near miss', 'nearmiss')                 THEN 'near miss'
        WHEN LOWER(TRIM(category)) IN ('other', 'othre')                        THEN 'other'
        ELSE NULL
    END AS category,
    -- category_flag 
    CASE
        WHEN category IS NULL
            THEN 'missing'
        WHEN LOWER(TRIM(category)) NOT IN (
            'equipment failure', 'violence', 'medication error', 'fall',
            'wrong patient', 'documentation error', 'delay', 
			'infection control', 'near miss', 'other')
            THEN 'non-standard'
        ELSE NULL
    END AS category_flag,
    -- severity: correction rule #10
    CASE LOWER(TRIM(severity))
        WHEN 'low'      THEN 'low'
        WHEN 'medium'   THEN 'medium'
        WHEN 'med'      THEN 'medium'
        WHEN 'high'     THEN 'high'
        WHEN 'h'        THEN 'high'
        WHEN 'critical' THEN 'critical'
        ELSE NULL
    END AS severity,
    -- severity_flag
    CASE
        WHEN TRIM(severity) IN ('', '??') OR severity IS NULL
            THEN 'missing'
        WHEN LOWER(TRIM(severity)) NOT IN ('low','medium','high','critical')
            THEN 'non-standard'
        ELSE NULL
    END AS severity_flag,
    ---category_reclassified: correction rule #9
    CASE 
        WHEN LOWER(description) LIKE '%wrong dose administered%' THEN 'medication error'
        WHEN LOWER(description) LIKE '%equipment alarm ignored%' THEN 'equipment failure'
        WHEN LOWER(description) LIKE '%aggressive visitor%' THEN 'violence'
        WHEN LOWER(description) LIKE '%patient nearly fell%' THEN 'fall' 
        WHEN LOWER(description) LIKE '%delay%' THEN 'delay'
        WHEN LOWER(description) LIKE '%documentation missing%' THEN 'documentation error'
        WHEN LOWER(description) LIKE '%infection control%' THEN 'infection control'
	    ELSE NULL
     END AS category_reclassified
FROM f_incident;

-- Resolve NULL patient_id
UPDATE v2_incident i          
SET patient_id = p.patient_id
FROM f_incident f             
JOIN core_patient p           
    ON LPAD(REGEXP_REPLACE(f.patient_key_raw, '[^0-9]', '', 'g'), 6, '0') = p.mrn_v2
WHERE i.patient_id IS NULL
  AND i.incident_id = f.incident_id 
  AND f.patient_key_raw NOT LIKE '%O%';
  
-- Resolve NULL location_id: 
UPDATE v2_incident i
SET location_id = l.location_id
FROM f_incident f
JOIN core_location l ON f.location_raw = l.location_code
WHERE i.location_id IS NULL
  AND i.incident_id = f.incident_id;


-- Calculate delay_days
UPDATE v2_incident
SET delay_days = (reported_ts::DATE - event_ts::DATE)
WHERE reported_ts IS NOT NULL
  AND event_ts IS NOT NULL
  AND reported_ts >= event_ts; 

INSERT INTO v2_action (
    action_id,
    incident_id,
    staff_id,
    due_date,
    due_date_flag,
    completed_date,
    completed_date_flag,
	orphan_flag
)
SELECT 
    action_id,
    incident_id,
    assigned_staff_id,
    -- due_date 
    CASE 
        WHEN due_date ~ '^\d{4}-\d{2}-\d{2}$' 
             AND SUBSTRING(due_date FROM 6 FOR 2)::INT <= 12 
             THEN due_date::DATE
        ELSE NULL
    END AS due_date,
    -- due_date_flag: correction rule #2-4  
    CASE 
        WHEN TRIM(due_date) IN ('', 'n/a') OR due_date IS NULL THEN 'missing'
        WHEN due_date !~ '^\d{4}-\d{2}-\d{2}$' 
             OR (due_date ~ '^\d{4}-\d{2}-\d{2}$' AND SUBSTRING(due_date FROM 6 FOR 2)::INT > 12) 
             THEN 'unparsable'
        ELSE NULL 
    END AS due_date_flag,
    -- completion_date 
    CASE 
        WHEN completed_on ~ '^\d{4}-\d{2}-\d{2}$' 
             AND SUBSTRING(completed_on FROM 6 FOR 2)::INT <= 12
             THEN completed_on::DATE
        ELSE NULL 
    END AS completed_date,
    -- completion_date_flag
    CASE 
        WHEN TRIM(completed_on) IN ('', 'n/a') OR completed_on IS NULL THEN 'missing'
        WHEN completed_on !~ '^\d{4}-\d{2}-\d{2}$' 
             OR (completed_on ~ '^\d{4}-\d{2}-\d{2}$' AND SUBSTRING(completed_on FROM 6 FOR 2)::INT > 12) 
             THEN 'unparsable'
        ELSE NULL 
    END AS completed_date_flag,
	-- orphan_flag
	CASE 
        WHEN (incident_id IS NULL OR incident_id NOT IN (SELECT incident_id FROM v2_incident)) THEN TRUE
		ELSE FALSE
	END AS orphan_flag
FROM f_action_item;

-- Standardize action status
UPDATE v2_action a
SET status = CASE 
    --if a valid completed_date exists or raw status is 'done' then it's 'done'
	WHEN a.completed_date IS NOT NULL OR f.status = 'done' THEN 'done'
	WHEN f.status IN ('wip', 'open') THEN 'pending'
    ELSE 'unknown'
END
FROM f_action_item f
WHERE a.action_id = f.action_id;

-- Evaluate overdue statusUPDATE v2_action 
SET overdue_status = CASE 
    WHEN (status = 'done' OR completed_date IS NOT NULL) THEN
         CASE 
            WHEN due_date IS NULL OR completed_date IS NULL THEN 'indeterminate'
            WHEN completed_date <= due_date THEN 'on_time'
            ELSE 'late_completed'
         END
    WHEN status = 'pending' THEN
         CASE 
            WHEN due_date IS NULL THEN 'indeterminate'
            WHEN due_date < CURRENT_DATE THEN 'overdue'
            ELSE 'on_time'
         END
    ELSE 'indeterminate'
END;
