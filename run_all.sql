-- =====================================================================
-- run_all.sql: runs the whole pipeline in order.
-- From the project root:
--     psql -U postgres -d road_safety -P pager=off -f run_all.sql
-- =====================================================================
\set ON_ERROR_STOP on
\timing on
\pset pager off

\echo '== 1/10 Creating tables =='
\i sql/01_create_tables.sql
\echo '== 2/10 Loading CSVs =='
\i sql/02_load_data.sql
\echo '== 3/10 Cleaning, decoding, indexing =='
\i sql/03_clean_transform.sql
\echo '== 4/10 Data quality checks =='
\i sql/04_data_quality_checks.sql
\echo '== 5/10 Trends =='
\i sql/05_trends.sql
\echo '== 6/10 When =='
\i sql/06_when.sql
\echo '== 7/10 Where and conditions =='
\i sql/07_where_conditions.sql
\echo '== 8/10 Who =='
\i sql/08_who.sql
\echo '== 9/10 Power BI views + export =='
\i sql/09_powerbi_export.sql
\echo '== 10/10 Road Safety Strategy target tracking =='
\i sql/10_target_tracking.sql
\echo '== Done =='
