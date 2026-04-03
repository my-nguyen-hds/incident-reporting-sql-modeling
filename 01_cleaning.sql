DROP TABLE IF EXISTS v2_incident, v2_action CASCADE;
--I. Standardization and redesign data model
-- 1.Table core_patient
--1.1. Enforce foreign key reference to core_person table
ALTER TABLE core_patient
ADD CONSTRAINT fk_patient_person
FOREIGN KEY (person_id) 
REFERENCES core_person(person_id);

--1.2. Standardize mrn_norm
ALTER TABLE core_patient
ADD COLUMN mrn_v2 TEXT;
UPDATE core_patient
SET mrn_v2 =
    CASE
        WHEN mrn_norm NOT LIKE '%O%'
        THEN mrn_norm
        WHEN REGEXP_REPLACE(mrn_norm, 'O$', RIGHT(patient_id::text, 1))
             = LPAD(patient_id::text, 6, '0')
        THEN LPAD(patient_id::text, 6, '0')
        ELSE NULL
    END;
	
--2. Create tables v2_incident, v2_action
CREATE TABLE v2_incident (
    incident_id      		INT PRIMARY KEY REFERENCES f_incident(incident_id),
    event_ts         		TIMESTAMP,
    event_ts_flag   		TEXT CHECK (event_ts_flag IN ('unparsable', 'missing')),
    reported_ts      		TIMESTAMP,
    reported_ts_flag 		TEXT CHECK (reported_ts_flag IN ('unparsable', 'missing')),
    delay_days       		INT,
    patient_id       		INT REFERENCES core_patient(patient_id),
    location_id      		INT REFERENCES core_location(location_id),
    staff_id         		INT REFERENCES core_staff(staff_id),
    category         		TEXT CHECK (category IN (
                       		'equipment failure', 'violence', 'medication error',
                        	'fall', 'wrong patient', 'documentation error',
                        	'delay', 'infection control', 'near miss', 'other')),
    category_flag    		TEXT CHECK (category_flag IN ('non-standard', 'missing')),
    severity         		TEXT CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    severity_flag    		TEXT CHECK (severity_flag IN ('non-standard', 'missing')),
    category_reclassified 	TEXT,
	suspected_duplicate     BOOLEAN DEFAULT FALSE,
   duplicate_of_incident_id INT
);

CREATE TABLE v2_action (
    action_id        	INT PRIMARY KEY REFERENCES f_action_item(action_id),
    incident_id      	INT REFERENCES v2_incident(incident_id),
    staff_id         	INT REFERENCES core_staff(staff_id),
    due_date         	DATE,
    due_date_flag    	TEXT CHECK (due_date_flag IN ('unparsable', 'missing')),
    completed_date   	DATE,
    completed_date_flag TEXT CHECK (completed_date_flag IN ('unparsable', 'missing')),
    status           	TEXT CHECK (status IN ('done', 'pending', 'unknown')),
    overdue_status 		TEXT CHECK (overdue_status IN (
    								'on_time', 'late_completed', 'overdue', 'indeterminate')),
	orphan_flag 		BOOLEAN     
);
