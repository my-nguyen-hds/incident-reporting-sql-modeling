# incident-reporting-sql-modeling
SQL Data Modeling for Hospital Incident Reporting Systems 

## Overview
This project focuses on redesigning a database for a patient safety incident reporting system at **Seeblick Klinikum**. The goal was to transform "messy" manual reports into a structured, analysis-ready format.

## Key Challenges Solved
- **Data Standardization:** Developed SQL logic to fix inconsistent and non-standardized information caused by manual entry errors.
- **Temporal Logic:** Addressed vague timestamps (e.g., "around 2pm") by creating standardized event logs and tracking reporting delays.
- **Data Integrity Audits:** Created diagnostic queries to identify "orphan actions" and mismatches between incident descriptions and severity classifications.

## Technical Stack
- **Database:** PostgreSQL
- **Key SQL Skills:** window functions, case logic, data normalization, regex, integrity c incident-reporting-sql-modeling
SQL Data Modeling for Hospital Incident Reporting Systems 

## Overview
This project focuses on redesigning a database for a patient safety incident reporting system at **Seeblick Klinikum**. The goal was to transform "messy" manual reports into a structured, analysis-ready format.

## Key Challenges Solved
- **Data Standardization:** Developed SQL logic to fix inconsistent Patient IDs (MRN) caused by manual entry errors (e.g., Rule #16 implementation).
- **Temporal Logic:** Addressed vague timestamps (e.g., "around 2pm") by creating standardized event logs and tracking reporting delays.
- **Data Integrity Audits:** Created diagnostic queries to identify "orphan actions" and mismatches between incident descriptions and severity classifications.

## Technical Stack
- **Database:** PostgreSQL
- **Key SQL Skills:** window functions, case logic, data normalization, CTE, regex, integrity constraints

## How to use this Repo
00_mock_data.sql: Sample data   
01_cleaning.sql: Establishes the refined v2 table structures and constraints.  
02_transformation.sql: Performs ETL logic to parse dates, calculate reporting delays, and reclassify incident categories.  
03_quality_audit_&_analytics.sql: Runs queries to quantify data integrity (orphan actions, severity mismatches,etc.) and analyze incident trends.
