

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "migration_util";


ALTER SCHEMA "migration_util" OWNER TO "postgres";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE SCHEMA IF NOT EXISTS "staging";


ALTER SCHEMA "staging" OWNER TO "postgres";


CREATE EXTENSION IF NOT EXISTS "http" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_jsonschema" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgaudit" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgjwt" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "tablefunc" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "vector" WITH SCHEMA "public";






CREATE PROCEDURE "migration_util"."build_mapping"()
    LANGUAGE "plpgsql"
    AS $$ BEGIN
  INSERT INTO migration_util.validation_log(phase,validation_type,details)
  VALUES ('MAP','OK','schema mapping stub');
END$$;


ALTER PROCEDURE "migration_util"."build_mapping"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "migration_util"."check_encoding"() RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$ BEGIN
  INSERT INTO migration_util.validation_log(phase,validation_type,details)
  VALUES ('ENC','OK','encoding stub');
END$$;


ALTER FUNCTION "migration_util"."check_encoding"() OWNER TO "postgres";


CREATE PROCEDURE "migration_util"."data_quality_checks"()
    LANGUAGE "plpgsql"
    AS $$ BEGIN
  INSERT INTO migration_util.validation_log(phase,validation_type,details)
  VALUES ('DQ','OK','data quality stub');
END$$;


ALTER PROCEDURE "migration_util"."data_quality_checks"() OWNER TO "postgres";


CREATE PROCEDURE "migration_util"."enable_rollback"()
    LANGUAGE "plpgsql"
    AS $$ BEGIN
  INSERT INTO migration_util.validation_log(phase,validation_type,details)
  VALUES ('RB','OK','rollback stub');
END$$;


ALTER PROCEDURE "migration_util"."enable_rollback"() OWNER TO "postgres";


CREATE PROCEDURE "migration_util"."plan_performance"()
    LANGUAGE "plpgsql"
    AS $$ BEGIN
  INSERT INTO migration_util.validation_log(phase,validation_type,details)
  VALUES ('PERF','OK','performance stub');
END$$;


ALTER PROCEDURE "migration_util"."plan_performance"() OWNER TO "postgres";


CREATE PROCEDURE "migration_util"."run_tests"()
    LANGUAGE "plpgsql"
    AS $$ BEGIN
  INSERT INTO migration_util.validation_log(phase,validation_type,details)
  VALUES ('TEST','OK','tests stub');
END$$;


ALTER PROCEDURE "migration_util"."run_tests"() OWNER TO "postgres";


CREATE PROCEDURE "migration_util"."validate_foreign_keys"()
    LANGUAGE "plpgsql"
    AS $$ BEGIN
  INSERT INTO migration_util.validation_log(phase,validation_type,details)
  VALUES ('FK','OK','FK stub');
END$$;


ALTER PROCEDURE "migration_util"."validate_foreign_keys"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "migration_util"."validate_types"() RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$ BEGIN
  INSERT INTO migration_util.validation_log(phase,validation_type,details)
  VALUES ('TYPE','OK','type check stub');
END$$;


ALTER FUNCTION "migration_util"."validate_types"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."_dto_create_rls"("p_tab" "text", "p_owner_col" "text") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $_$
BEGIN
  EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', p_tab);
  EXECUTE format($f$
      CREATE POLICY org_scope_%I ON %I
      USING  ( %I = (current_setting('request.jwt.claims', true)::json->>'org_scope') )
      WITH CHECK ( %I = (current_setting('request.jwt.claims', true)::json->>'org_scope') );
  $f$, p_tab, p_tab, p_owner_col, p_owner_col);
END;
$_$;


ALTER FUNCTION "public"."_dto_create_rls"("p_tab" "text", "p_owner_col" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_exec_sql"("query" "text") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    result json;
BEGIN
    -- Before executing, we switch the role of the current session to our secure, read-only user.
    -- This is the core of the security model. Any query, no matter what it is, will be
    -- executed with the permissions of 'read_only_user'.
    SET LOCAL ROLE read_only_user;

    -- Now we can safely execute the query. The result is converted to JSON.
    -- We need to use EXECUTE ... INTO to capture the result
    EXECUTE 'SELECT json_agg(t) FROM (' || query || ') AS t' INTO result;
    
    RETURN result;
END;
$$;


ALTER FUNCTION "public"."admin_exec_sql"("query" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."calculate_complexity_score"("solution_text" "text") RETURNS integer
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    score INTEGER := 1;
BEGIN
    -- Code length factor
    IF LENGTH(solution_text) > 200 THEN 
        score := score + 1; 
    END IF;
    IF LENGTH(solution_text) > 500 THEN 
        score := score + 1; 
    END IF;

    -- Technical keywords
    IF solution_text ~* '(import|function|class|loop|api|json|xml)' THEN 
        score := score + 1; 
    END IF;
    IF solution_text ~* '(bytesio|stream|async|await|regex|sql)' THEN 
        score := score + 1; 
    END IF;

    RETURN LEAST(score, 5);
END;
$$;


ALTER FUNCTION "public"."calculate_complexity_score"("solution_text" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."calculate_likelihood_delay"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    -- Calculate weighted average of components (33% each)
    -- Apply persistence multiplier: 0=0%, 1=50%, 2=75%, 3=100%
    DECLARE
        project_weight NUMERIC := 0;
        role_weight NUMERIC := 0;
        it_weight NUMERIC := 0;
        persistence_multiplier_project NUMERIC;
        persistence_multiplier_role NUMERIC;
        persistence_multiplier_it NUMERIC;
    BEGIN
        -- Set persistence multipliers based on persistence values
        CASE
            WHEN NEW.project_outputs_persistence = 0 THEN persistence_multiplier_project := 0;
            WHEN NEW.project_outputs_persistence = 1 THEN persistence_multiplier_project := 0.5;
            WHEN NEW.project_outputs_persistence = 2 THEN persistence_multiplier_project := 0.75;
            WHEN NEW.project_outputs_persistence = 3 THEN persistence_multiplier_project := 1.0;
            ELSE persistence_multiplier_project := 0;
        END CASE;
        
        CASE
            WHEN NEW.role_gaps_persistence = 0 THEN persistence_multiplier_role := 0;
            WHEN NEW.role_gaps_persistence = 1 THEN persistence_multiplier_role := 0.5;
            WHEN NEW.role_gaps_persistence = 2 THEN persistence_multiplier_role := 0.75;
            WHEN NEW.role_gaps_persistence = 3 THEN persistence_multiplier_role := 1.0;
            ELSE persistence_multiplier_role := 0;
        END CASE;
        
        CASE
            WHEN NEW.it_systems_persistence = 0 THEN persistence_multiplier_it := 0;
            WHEN NEW.it_systems_persistence = 1 THEN persistence_multiplier_it := 0.5;
            WHEN NEW.it_systems_persistence = 2 THEN persistence_multiplier_it := 0.75;
            WHEN NEW.it_systems_persistence = 3 THEN persistence_multiplier_it := 1.0;
            ELSE persistence_multiplier_it := 0;
        END CASE;
        
        -- Calculate weighted components with persistence applied
        IF NEW.project_outputs_risk IS NOT NULL THEN
            project_weight := NEW.project_outputs_risk * persistence_multiplier_project * 0.33;
        END IF;
        
        IF NEW.role_gaps_risk IS NOT NULL THEN
            role_weight := NEW.role_gaps_risk * persistence_multiplier_role * 0.33;
        END IF;
        
        IF NEW.it_systems_risk IS NOT NULL THEN
            it_weight := NEW.it_systems_risk * persistence_multiplier_it * 0.33;
        END IF;
        
        -- Set final likelihood_of_delay (as a percentage 0-100)
        NEW.likelihood_of_delay := COALESCE(project_weight + role_weight + it_weight, 0);
        
        -- Calculate maximum delay in days (take the maximum delay from components)
        NEW.delay_days := GREATEST(
            COALESCE(NEW.project_outputs_delay_days, 0),
            COALESCE(NEW.role_gaps_delay_days, 0),
            COALESCE(NEW.it_systems_delay_days, 0)
        );
    END;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."calculate_likelihood_delay"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."capability_health_by_year"("p_year" integer) RETURNS TABLE("capability_id" integer, "capability_name" "text", "health_id" integer, "health_name" "text", "health_score" numeric, "health_date" "date", "health_comments" "text")
    LANGUAGE "plpgsql"
    AS $$BEGIN
    RETURN QUERY
    SELECT 
        c.id   AS capability_id,
        c.name AS capability_name,
        h.id   AS health_id,
        h.name AS health_name,
        h.score,
        h.year AS health_year,
        h.comments
    FROM ent_capabilities AS c
    -- Capabilities → Org units (composite keys)
    LEFT JOIN jt_ent_capabilities_ent_org_units AS jcou
        ON c.id   = jcou.ent_capabilities_id
       AND c.year = jcou.ent_capabilities_year
    LEFT JOIN ent_org_units AS ou
        ON jcou.ent_org_units_id = ou.id
       AND jcou.ent_org_units_year = ou.year
    -- Org units → Culture health (composite keys)
    LEFT JOIN jt_ent_org_units_ent_culture_health_join AS jouh
        ON ou.id  = jouh.ent_org_units_id
       AND ou.year = jouh.ent_org_units_year
    LEFT JOIN ent_culture_health AS h
        ON jouh.ent_culture_health_id  = h.id
       AND jouh.ent_culture_health_year = h.year
    -- Filter for the requested year; include NULLs to show capabilities with no health data
    WHERE (h.year = p_year OR h.year IS NULL)
    ORDER BY c.name, h.year DESC;
END;$$;


ALTER FUNCTION "public"."capability_health_by_year"("p_year" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cleanup_low_usage_memories"() RETURNS integer
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    DELETE FROM AI_COLLECTIVE_MEMORY_UNIVERSAL_KNOWLEDGE_BASE 
    WHERE use_count = 0 
      AND created_timestamp < NOW() - INTERVAL '90 days'
      AND human_validated = FALSE;

    RETURN ROW_COUNT;
END;
$$;


ALTER FUNCTION "public"."cleanup_low_usage_memories"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."column_exists"("p_schema" "text", "p_table" "text", "p_column" "text") RETURNS boolean
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_exists boolean;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = p_schema
        AND table_name = p_table
        AND column_name = p_column
    ) INTO v_exists;
    
    RETURN v_exists;
END;
$$;


ALTER FUNCTION "public"."column_exists"("p_schema" "text", "p_table" "text", "p_column" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."detect_manipulation"("user_request" "text") RETURNS boolean
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN user_request ~* '(remember|store|save|memory|other ai|test.*memory)';
END;
$$;


ALTER FUNCTION "public"."detect_manipulation"("user_request" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."dto_log_operation"("p_operation" character varying, "p_table_name" character varying, "p_record_count" integer, "p_status" character varying, "p_error_message" "text" DEFAULT NULL::"text") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    INSERT INTO public.dto_debug_log (operation, table_name, record_count, status, error_message)
    VALUES (p_operation, p_table_name, p_record_count, p_status, p_error_message);
END;
$$;


ALTER FUNCTION "public"."dto_log_operation"("p_operation" character varying, "p_table_name" character varying, "p_record_count" integer, "p_status" character varying, "p_error_message" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."execute_sql"("sql_query" "text") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  rec RECORD;
  results JSON[] := ARRAY[]::json[];
BEGIN
  -- Security check: only allow SELECT and WITH statements
  IF NOT (LOWER(TRIM(sql_query)) LIKE 'select%' OR LOWER(TRIM(sql_query)) LIKE 'with%') THEN
    RAISE EXCEPTION 'Only SELECT and WITH queries are allowed';
  END IF;

  -- Execute the query and collect results
  FOR rec IN EXECUTE sql_query LOOP
    results := array_append(results, row_to_json(rec)::json);
  END LOOP;

  -- Return as JSON array
  RETURN COALESCE(array_to_json(results), '[]'::json);
EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Query execution failed: %', SQLERRM;
END;
$$;


ALTER FUNCTION "public"."execute_sql"("sql_query" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_wheel_data"("overlay_type" character varying DEFAULT 'operational'::character varying) RETURNS json
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    wheel_data JSON;
BEGIN
    SELECT json_build_object(
        'metadata', json_build_object(
            'overlay_type', overlay_type,
            'generated_at', CURRENT_TIMESTAMP,
            'total_processes', COUNT(*)
        ),
        'l1_segments', json_agg(
            json_build_object(
                'id', process_l1_id,
                'name', l1_name,
                'health_score', AVG(health_score),
                'status', CASE 
                    WHEN AVG(health_score) >= 90 THEN 'excellent'
                    WHEN AVG(health_score) >= 80 THEN 'good'
                    WHEN AVG(health_score) >= 60 THEN 'caution'
                    ELSE 'critical'
                END,
                'l2_processes', (
                    SELECT json_agg(
                        json_build_object(
                            'id', process_l2_id,
                            'name', l2_name,
                            'health_score', health_score,
                            'kpi_status', kpi_status
                        )
                    )
                    FROM vw_heat_map_intelligence hmi2 
                    WHERE hmi2.process_l1_id = hmi.process_l1_id
                )
            )
        )
    ) INTO wheel_data
    FROM vw_heat_map_intelligence hmi
    GROUP BY process_l1_id, l1_name;

    RETURN wheel_data;
END;
$$;


ALTER FUNCTION "public"."generate_wheel_data"("overlay_type" character varying) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_capability_health"("p_year" integer) RETURNS TABLE("capability_id" character varying, "capability_year" integer, "capability_name" character varying, "capability_level" character varying, "capability_parent_id" character varying, "capability_parent_year" integer, "capability_status" character varying, "objective_id" character varying, "objective_name" character varying, "policy_tool_id" character varying, "policy_tool_name" character varying, "total_health_score" numeric, "capability_health_category" character varying)
    LANGUAGE "plpgsql"
    AS $$BEGIN
    -- This calls your renamed original function but only selects specific columns
    RETURN QUERY
    SELECT 
	    capability_id,
	    capability_year,
	    capability_name,
	    capability_level,
	    capability_parent_id,
	    capability_parent_year,
	    capability_status,
	    objective_id,
	    objective_name,
	    policy_tool_id,
	    policy_tool_name,
	    total_health_score,
	    capability_health_category 
    FROM get_capability_health_year(p_year);
END;$$;


ALTER FUNCTION "public"."get_capability_health"("p_year" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_capability_health_year"("p_year" integer) RETURNS TABLE("id" character varying, "name" character varying, "level" character varying, "parent_id" character varying, "year" integer, "status" character varying, "objective_id" character varying, "objective_name" character varying, "policy_tool_id" character varying, "policy_tool_name" character varying, "health_score" numeric, "health_category" character varying, "project_status" character varying, "change_status" character varying, "org_unit_gap" integer, "culture_health_trend" character varying, "process_health" character varying, "it_system_status" character varying)
    LANGUAGE "plpgsql"
    AS $$BEGIN
    RETURN QUERY
    WITH 
    -- Get all capabilities for the specified year
    capabilities AS (
        SELECT 
            c.id,
            c.name,
            c.level,
            c.parent_id,
            c.year,
            c.status
        FROM 
            ent_capabilities c
        WHERE 
            c.year = p_year
    ),
    
    -- Get related objectives
    objectives AS (
        SELECT 
            c.id AS capability_id,
            c.year AS capability_year,
            o.id AS objective_id,
            o.name AS objective_name
        FROM 
            ent_capabilities c
        JOIN 
            jt_sec_performance_ent_capabilities_join j ON c.id = j.ent_capabilities_id AND c.year = j.ent_capabilities_year
        JOIN 
            jt_sec_objectives_sec_performance_join jo ON j.sec_performance_id = jo.sec_performance_id AND j.sec_performance_year = jo.sec_performance_year
        JOIN 
            sec_objectives o ON jo.sec_objectives_id = o.id AND jo.sec_objectives_year = o.year
        WHERE 
            c.year = p_year
    ),
    
    -- Get related policy tools
    policy_tools AS (
        SELECT 
            c.id AS capability_id,
            c.year AS capability_year,
            pt.id AS policy_tool_id,
            pt.name AS policy_tool_name
        FROM 
            ent_capabilities c
        JOIN 
            jt_sec_policy_tools_ent_capabilities_join j ON c.id = j.ent_capabilities_id AND c.year = j.ent_capabilities_year
        JOIN 
            sec_policy_tools pt ON j.sec_policy_tools_id = pt.id AND j.sec_policy_tools_year = pt.year
        WHERE 
            c.year = p_year
    ),
    
    -- Get project data for health calculation
    projects_data AS (
        SELECT 
            c.id AS capability_id,
            c.year AS capability_year,
            p.status AS project_status_val,
            ca.status AS change_status_val
        FROM 
            ent_capabilities c
        JOIN 
            jt_ent_capabilities_ent_projects_join jp ON c.id = jp.ent_capabilities_id AND c.year = jp.ent_capabilities_year
        JOIN 
            ent_projects p ON jp.ent_projects_id = p.id AND jp.ent_projects_year = p.year
        LEFT JOIN 
            jt_ent_projects_ent_change_adoption_join jca ON p.id = jca.ent_projects_id AND p.year = jca.ent_projects_year
        LEFT JOIN 
            ent_change_adoption ca ON jca.ent_change_adoption_id = ca.id AND jca.ent_change_adoption_year = ca.year
        WHERE 
            c.year = p_year AND c.level = 'L3'
    ),
    
    -- Get org unit data for health calculation
    org_units_data AS (
        SELECT 
            c.id AS capability_id,
            c.year AS capability_year,
            ou.gap AS org_unit_gap_val,
            ou.staff_count AS staff_count_val,
            ch.trend AS culture_health_trend_val
        FROM 
            ent_capabilities c
        JOIN 
            jt_ent_capabilities_ent_org_units_join jou ON c.id = jou.ent_capabilities_id AND c.year = jou.ent_capabilities_year
        JOIN 
            ent_org_units ou ON jou.ent_org_units_id = ou.id AND jou.ent_org_units_year = ou.year
        LEFT JOIN 
            jt_ent_org_units_ent_culture_health_join jch ON ou.id = jch.ent_org_units_id AND ou.year = jch.ent_org_units_year
        LEFT JOIN 
            ent_culture_health ch ON jch.ent_culture_health_id = ch.id AND jch.ent_culture_health_year = ch.year
        WHERE 
            c.year = p_year AND c.level = 'L3'
    ),
    
    -- Get process data for health calculation
    processes_data AS (
        SELECT 
            c.id AS capability_id,
            c.year AS capability_year,
            p.health_status AS process_health_val
        FROM 
            ent_capabilities c
        JOIN 
            jt_ent_capabilities_ent_processes_join jp ON c.id = jp.ent_capabilities_id AND c.year = jp.ent_capabilities_year
        JOIN 
            ent_processes p ON jp.ent_processes_id = p.id AND jp.ent_processes_year = p.year
        WHERE 
            c.year = p_year AND c.level = 'L3'
    ),
    
    -- Get IT systems data for health calculation
    it_systems_data AS (
        SELECT 
            c.id AS capability_id,
            c.year AS capability_year,
            its.operational_status AS it_system_status_val
        FROM 
            ent_capabilities c
        JOIN 
            jt_ent_capabilities_ent_it_systems_join jits ON c.id = jits.ent_capabilities_id AND c.year = jits.ent_capabilities_year
        JOIN 
            ent_it_systems its ON jits.ent_it_systems_id = its.id AND jits.ent_it_systems_year = its.year
        WHERE 
            c.year = p_year AND c.level = 'L3'
    ),
    
    -- Calculate health scores for L3 capabilities
    l3_health_scores AS (
        SELECT 
            c.id AS cap_id,
            c.year AS cap_year,
            
            -- Project output score (25%)
            COALESCE(
                CASE 
                    WHEN pd.project_status_val IN ('complete', 'completed') THEN 25
                    WHEN pd.project_status_val IN ('late') THEN 0
                    WHEN pd.project_status_val IN ('planned', 'active') THEN 10
                    ELSE 0
                END, 0
            ) AS project_output_score_val,
            
            -- Change adoption score (10%)
            COALESCE(
                CASE 
                    WHEN pd.project_status_val = 'late' THEN 0
                    WHEN pd.change_status_val IN ('complete', 'completed') THEN 10
                    WHEN pd.change_status_val = 'in progress' THEN 5
                    WHEN pd.change_status_val IN ('not started', 'late') THEN 0
                    ELSE 0
                END, 0
            ) AS change_adoption_score_val,
            
            -- Org role gaps score (25%)
            COALESCE(
                CASE 
                    WHEN oud.org_unit_gap_val = 0 THEN 25
                    WHEN oud.org_unit_gap_val <= (oud.staff_count_val * 0.25) THEN 10
                    ELSE 0
                END, 0
            ) AS org_role_gaps_score_val,
            
            -- Culture health score (10%)
            COALESCE(
                CASE 
                    WHEN oud.org_unit_gap_val > (oud.staff_count_val * 0.25) THEN 0
                    WHEN oud.culture_health_trend_val = 'stable' THEN 5
                    WHEN oud.culture_health_trend_val = 'rising' THEN 10
                    WHEN oud.culture_health_trend_val = 'declining' THEN 0
                    ELSE 0
                END, 0
            ) AS culture_health_score_val,
            
            -- Process health score (20%)
            COALESCE(
                CASE 
                    WHEN prd.process_health_val = '1' THEN 20
                    WHEN prd.process_health_val = '0' THEN 10
                    ELSE 0
                END, 0
            ) AS process_health_score_val,
            
            -- IT systems score (10%)
            COALESCE(
                CASE 
                    WHEN itsd.it_system_status_val = 'active' THEN 10
                    WHEN itsd.it_system_status_val = 'developing' THEN 5
                    WHEN itsd.it_system_status_val IN ('planned', 'late') THEN 0
                    ELSE 0
                END, 0
            ) AS it_systems_score_val,
            
            -- Store original values for display
            pd.project_status_val,
            pd.change_status_val,
            oud.org_unit_gap_val,
            oud.culture_health_trend_val,
            prd.process_health_val,
            itsd.it_system_status_val
            
        FROM 
            capabilities c
        LEFT JOIN 
            projects_data pd ON c.id = pd.capability_id AND c.year = pd.capability_year
        LEFT JOIN 
            org_units_data oud ON c.id = oud.capability_id AND c.year = oud.capability_year
        LEFT JOIN 
            processes_data prd ON c.id = prd.capability_id AND c.year = prd.capability_year
        LEFT JOIN 
            it_systems_data itsd ON c.id = itsd.capability_id AND c.year = itsd.capability_year
        WHERE 
            c.level = 'L3'
    ),
    
    -- Calculate total health scores for L3 capabilities
    l3_total_health AS (
        SELECT 
            cap_id,
            cap_year,
            project_output_score_val + change_adoption_score_val + org_role_gaps_score_val + 
            culture_health_score_val + process_health_score_val + it_systems_score_val AS health_score_val,
            project_status_val,
            change_status_val,
            org_unit_gap_val,
            culture_health_trend_val,
            process_health_val,
            it_system_status_val
        FROM 
            l3_health_scores
    ),
    
    -- Roll up health scores to L2 capabilities
    l2_health AS (
        SELECT 
            c.id AS cap_id,
            c.year AS cap_year,
            COALESCE(AVG(l3h.health_score_val), 0) AS health_score_val,
            NULL::varchar AS project_status_val,
            NULL::varchar AS change_status_val,
            NULL::integer AS org_unit_gap_val,
            NULL::varchar AS culture_health_trend_val,
            NULL::varchar AS process_health_val,
            NULL::varchar AS it_system_status_val
        FROM 
            capabilities c
        LEFT JOIN 
            capabilities c_child ON c.id = c_child.parent_id AND c.year = c_child.year
        LEFT JOIN 
            l3_total_health l3h ON c_child.id = l3h.cap_id AND c_child.year = l3h.cap_year
        WHERE 
            c.level = 'L2'
        GROUP BY 
            c.id, c.year
    ),
    
    -- Roll up health scores to L1 capabilities
    l1_health AS (
        SELECT 
            c.id AS cap_id,
            c.year AS cap_year,
            COALESCE(AVG(l2h.health_score_val), 0) AS health_score_val,
            NULL::varchar AS project_status_val,
            NULL::varchar AS change_status_val,
            NULL::integer AS org_unit_gap_val,
            NULL::varchar AS culture_health_trend_val,
            NULL::varchar AS process_health_val,
            NULL::varchar AS it_system_status_val
        FROM 
            capabilities c
        LEFT JOIN 
            capabilities c_child ON c.id = c_child.parent_id AND c.year = c_child.year
        LEFT JOIN 
            l2_health l2h ON c_child.id = l2h.cap_id AND c_child.year = l2h.cap_year
        WHERE 
            c.level = 'L1'
        GROUP BY 
            c.id, c.year
    ),
    
    -- Combine all health scores
    all_health_scores AS (
        SELECT cap_id, cap_year, health_score_val, project_status_val, change_status_val, org_unit_gap_val, culture_health_trend_val, process_health_val, it_system_status_val FROM l3_total_health
        UNION ALL
        SELECT cap_id, cap_year, health_score_val, project_status_val, change_status_val, org_unit_gap_val, culture_health_trend_val, process_health_val, it_system_status_val FROM l2_health
        UNION ALL
        SELECT cap_id, cap_year, health_score_val, project_status_val, change_status_val, org_unit_gap_val, culture_health_trend_val, process_health_val, it_system_status_val FROM l1_health
    ),
    
    -- Determine health category based on score
    health_categories AS (
        SELECT 
            cap_id,
            cap_year,
            health_score_val,
            CASE 
                WHEN health_score_val >= 80 THEN 'Excellent'::varchar
                WHEN health_score_val >= 60 THEN 'Good'::varchar
                WHEN health_score_val >= 40 THEN 'Fair'::varchar
                WHEN health_score_val >= 20 THEN 'Poor'::varchar
                ELSE 'Critical'::varchar
            END AS health_category_val,
            project_status_val,
            change_status_val,
            org_unit_gap_val,
            culture_health_trend_val,
            process_health_val,
            it_system_status_val
        FROM 
            all_health_scores
    )
    
    -- Final result combining all data
    SELECT 
        c.id::varchar,
        c.name::varchar,
        c.level::varchar,
        c.parent_id::varchar,
        c.year,
        c.status::varchar,
        o.objective_id::varchar,
        o.objective_name::varchar,
        pt.policy_tool_id::varchar,
        pt.policy_tool_name::varchar,
        ROUND(h.health_score_val::numeric, 2) AS health_score,
        h.health_category_val::varchar AS health_category,
        h.project_status_val::varchar AS project_status,
        h.change_status_val::varchar AS change_status,
        h.org_unit_gap_val AS org_unit_gap,
        h.culture_health_trend_val::varchar AS culture_health_trend,
        h.process_health_val::varchar AS process_health,
        h.it_system_status_val::varchar AS it_system_status
    FROM 
        capabilities c
    LEFT JOIN 
        objectives o ON c.id = o.capability_id AND c.year = o.capability_year
    LEFT JOIN 
        policy_tools pt ON c.id = pt.capability_id AND c.year = pt.capability_year
    LEFT JOIN 
        health_categories h ON c.id = h.cap_id AND c.year = h.cap_year
    ORDER BY 
        c.level, c.id;
END;$$;


ALTER FUNCTION "public"."get_capability_health_year"("p_year" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_capability_performance_kpis"("capability_id" "text", "year_param" integer, "level_param" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    result_data jsonb;
BEGIN
    -- For L3 level (leaf nodes) - direct data
    IF level_param = 'L3' THEN
        SELECT jsonb_build_object(
            'kpis', COALESCE(
                jsonb_agg(
                    jsonb_build_object(
                        'name', sp.name,
                        'kpi_type', sp.kpi_type,
                        'unit', sp.unit,
                        'target', sp.target,
                        'actual', sp.actual,
                        'status', sp.status,
                        'frequency', sp.frequency,
                        'description', sp.description,
                        'calculation_formula', sp.calculation_formula,
                        'measurement_frequency', sp.measurement_frequency,
                        'thresholds', sp.thresholds,
                        'data_source', sp.data_source
                    )
                ),
                '[]'::jsonb
            )
        ) INTO result_data
        FROM ent_capabilities c
        JOIN jt_sec_performance_ent_capabilities_join jpc 
            ON c.id = jpc.ent_capabilities_id AND c.year = jpc.ent_capabilities_year
        JOIN sec_performance sp 
            ON jpc.sec_performance_id = sp.id AND jpc.sec_performance_year = sp.year
        WHERE c.id = capability_id AND c.year = year_param;
    
    -- For L2 level (mid-level aggregation) - aggregate child L3 capabilities
    ELSIF level_param = 'L2' THEN
        WITH child_capabilities AS (
            SELECT * FROM ent_capabilities 
            WHERE parent_id = capability_id AND parent_year = year_param AND level = 'L3'
        )
        SELECT jsonb_build_object(
            'kpis', COALESCE(
                jsonb_agg(
                    jsonb_build_object(
                        'name', sp.name,
                        'kpi_type', sp.kpi_type,
                        'unit', sp.unit,
                        'target', sp.target,
                        'actual', sp.actual,
                        'status', sp.status,
                        'frequency', sp.frequency,
                        'description', sp.description,
                        'calculation_formula', sp.calculation_formula,
                        'measurement_frequency', sp.measurement_frequency,
                        'thresholds', sp.thresholds,
                        'data_source', sp.data_source
                    )
                ),
                '[]'::jsonb
            )
        ) INTO result_data
        FROM child_capabilities cc
        JOIN jt_sec_performance_ent_capabilities_join jpc 
            ON cc.id = jpc.ent_capabilities_id AND cc.year = jpc.ent_capabilities_year
        JOIN sec_performance sp 
            ON jpc.sec_performance_id = sp.id AND jpc.sec_performance_year = sp.year;
    
    -- For L1 level (top-level aggregation) - aggregate all descendant capabilities
    ELSIF level_param = 'L1' THEN
        WITH all_descendants AS (
            SELECT * FROM ent_capabilities 
            WHERE id LIKE capability_id || '.%' AND year = year_param AND level IN ('L2', 'L3')
        )
        SELECT jsonb_build_object(
            'kpis', COALESCE(
                jsonb_agg(
                    jsonb_build_object(
                        'name', sp.name,
                        'kpi_type', sp.kpi_type,
                        'unit', sp.unit,
                        'target', sp.target,
                        'actual', sp.actual,
                        'status', sp.status,
                        'frequency', sp.frequency,
                        'description', sp.description,
                        'calculation_formula', sp.calculation_formula,
                        'measurement_frequency', sp.measurement_frequency,
                        'thresholds', sp.thresholds,
                        'data_source', sp.data_source
                    )
                ),
                '[]'::jsonb
            )
        ) INTO result_data
        FROM all_descendants ad
        JOIN jt_sec_performance_ent_capabilities_join jpc 
            ON ad.id = jpc.ent_capabilities_id AND ad.year = jpc.ent_capabilities_year
        JOIN sec_performance sp 
            ON jpc.sec_performance_id = sp.id AND jpc.sec_performance_year = sp.year;
    END IF;

    -- Return empty array if no data found
    IF result_data IS NULL THEN
        result_data := jsonb_build_object('kpis', '[]'::jsonb);
    END IF;

    RETURN result_data;
END;
$$;


ALTER FUNCTION "public"."get_capability_performance_kpis"("capability_id" "text", "year_param" integer, "level_param" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_capability_popup_data"("capability_id" "text", "year_param" integer) RETURNS "jsonb"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    capability_data jsonb;
    planned_start_year integer;
    spider_data jsonb;
    capability_status text;
BEGIN
    -- Get core capability information
    SELECT jsonb_build_object(
        'id', c.id,
        'year', c.year,
        'name', c.name,
        'description', c.description,
        'status', c.status,
        'level', c.level,
        'maturity_level', c.maturity_level,
        'target_maturity_level', c.target_maturity_level,
        'quarter', c.quarter
    ) INTO capability_data
    FROM ent_capabilities c
    WHERE c.id = capability_id AND c.year = year_param;

    -- Get planned start year
    SELECT MIN(year) INTO planned_start_year
    FROM ent_capabilities
    WHERE id = capability_id AND status = 'active';

    -- Get capability status for conditional logic
    SELECT status INTO capability_status
    FROM ent_capabilities
    WHERE id = capability_id AND year = year_param;

    -- Only calculate spider data if status is 'active' or 'developing'
    IF capability_status IN ('active', 'developing') THEN
        -- Calculate Project Deliverables Score
        WITH project_score AS (
            SELECT COALESCE(AVG(p.progress_percentage), 0) as score
            FROM ent_projects p
            JOIN jt_ent_capabilities_ent_projects_join jp 
                ON p.id = jp.ent_projects_id AND p.year = jp.ent_projects_year
            WHERE jp.ent_capabilities_id = capability_id AND jp.ent_capabilities_year = year_param
        ),
        -- Calculate Role Gaps Score
        role_gaps_score AS (
            SELECT COALESCE(100 - AVG(ou.gap), 0) as score
            FROM ent_org_units ou
            JOIN jt_ent_capabilities_ent_org_units_join jou 
                ON ou.id = jou.ent_org_units_id AND ou.year = jou.ent_org_units_year
            WHERE jou.ent_capabilities_id = capability_id AND jou.ent_capabilities_year = year_param
        ),
        -- Calculate Culture Health Score
        culture_score AS (
            SELECT COALESCE(AVG(ch.survey_score), 0) as score
            FROM ent_culture_health ch
            JOIN jt_ent_capabilities_ent_culture_health_join jch 
                ON ch.id = jch.ent_culture_health_id AND ch.year = jch.ent_culture_health_year
            WHERE jch.ent_capabilities_id = capability_id AND jch.ent_capabilities_year = year_param
        ),
        -- Calculate Change Adoption Score
        change_adoption_score AS (
            SELECT COALESCE(AVG(
                CASE 
                    WHEN ca.status = 'complete' THEN 100
                    WHEN ca.status = 'active' THEN 75
                    WHEN ca.status = 'planned' THEN 25
                    ELSE 0
                END
            ), 0) as score
            FROM ent_change_adoption ca
            JOIN jt_ent_capabilities_ent_change_adoption_join jca 
                ON ca.id = jca.ent_change_adoption_id AND ca.year = jca.ent_change_adoption_year
            WHERE jca.ent_capabilities_id = capability_id AND jca.ent_capabilities_year = year_param
        ),
        -- Calculate IT Systems Score
        it_systems_score AS (
            SELECT COALESCE(AVG(
                CASE 
                    WHEN its.operational_status = 'operational' THEN 100
                    WHEN its.operational_status = 'maintenance' THEN 75
                    WHEN its.operational_status = 'development' THEN 50
                    ELSE 25
                END
            ), 0) as score
            FROM ent_it_systems its
            JOIN jt_ent_capabilities_ent_it_systems_join jits 
                ON its.id = jits.ent_it_systems_id AND its.year = jits.ent_it_systems_year
            WHERE jits.ent_capabilities_id = capability_id AND jits.ent_capabilities_year = year_param
        )
        -- Combine all scores into spider data
        SELECT jsonb_build_object(
            'projectDeliverables', (SELECT score FROM project_score),
            'roleGaps', (SELECT score FROM role_gaps_score),
            'cultureHealth', (SELECT score FROM culture_score),
            'changeAdoption', (SELECT score FROM change_adoption_score),
            'itSystems', (SELECT score FROM it_systems_score)
        ) INTO spider_data;
    ELSE
        spider_data := NULL;
    END IF;

    -- Return the complete result
    RETURN jsonb_build_object(
        'capability', capability_data,
        'plannedStartYear', planned_start_year,
        'spiderData', spider_data
    );
END;
$$;


ALTER FUNCTION "public"."get_capability_popup_data"("capability_id" "text", "year_param" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_capability_popup_data_secure"("capability_id" "text", "year_param" integer) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
BEGIN
    -- No role check - allow anyone to access
    -- Call the original function with elevated privileges
    RETURN public.get_capability_popup_data(capability_id, year_param);
END;
$$;


ALTER FUNCTION "public"."get_capability_popup_data_secure"("capability_id" "text", "year_param" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_capability_summary"("capability_id" "text", "year_param" integer) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    summary_data jsonb;
BEGIN
    -- Get only non-sensitive capability information
    SELECT jsonb_build_object(
        'id', c.id,
        'year', c.year,
        'name', c.name,
        'description', c.description,
        'status', c.status,
        'level', c.level,
        'maturity_level', c.maturity_level
        -- Note: Omitting sensitive fields like budget information
    ) INTO summary_data
    FROM ent_capabilities c
    WHERE c.id = capability_id AND c.year = year_param;

    RETURN summary_data;
END;
$$;


ALTER FUNCTION "public"."get_capability_summary"("capability_id" "text", "year_param" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_change_adoption_detail"("capability_id" "text", "year_param" integer, "level_param" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    result_data jsonb;
BEGIN
    -- For L3 level (leaf nodes) - direct data
    IF level_param = 'L3' THEN
        SELECT jsonb_build_object(
            'items', COALESCE(
                jsonb_agg(
                    jsonb_build_object(
                        'name', ca.name,
                        'status', ca.status,
                        'change_type', ca.change_type,
                        'target_group', ca.target_group
                    )
                ),
                '[]'::jsonb
            )
        ) INTO result_data
        FROM ent_capabilities c
        JOIN jt_ent_capabilities_ent_change_adoption_join jca 
            ON c.id = jca.ent_capabilities_id AND c.year = jca.ent_capabilities_year
        JOIN ent_change_adoption ca 
            ON jca.ent_change_adoption_id = ca.id AND jca.ent_change_adoption_year = ca.year
        WHERE c.id = capability_id AND c.year = year_param;
    
    -- For L2 level (mid-level aggregation) - aggregate child L3 capabilities
    ELSIF level_param = 'L2' THEN
        WITH child_capabilities AS (
            SELECT * FROM ent_capabilities 
            WHERE parent_id = capability_id AND parent_year = year_param AND level = 'L3'
        )
        SELECT jsonb_build_object(
            'items', COALESCE(
                jsonb_agg(
                    jsonb_build_object(
                        'name', ca.name,
                        'status', ca.status,
                        'change_type', ca.change_type,
                        'target_group', ca.target_group
                    )
                ),
                '[]'::jsonb
            )
        ) INTO result_data
        FROM child_capabilities cc
        JOIN jt_ent_capabilities_ent_change_adoption_join jca 
            ON cc.id = jca.ent_capabilities_id AND cc.year = jca.ent_capabilities_year
        JOIN ent_change_adoption ca 
            ON jca.ent_change_adoption_id = ca.id AND jca.ent_change_adoption_year = ca.year;
    
    -- For L1 level (top-level aggregation) - aggregate all descendant capabilities
    ELSIF level_param = 'L1' THEN
        WITH all_descendants AS (
            SELECT * FROM ent_capabilities 
            WHERE id LIKE capability_id || '.%' AND year = year_param AND level IN ('L2', 'L3')
        )
        SELECT jsonb_build_object(
            'items', COALESCE(
                jsonb_agg(
                    jsonb_build_object(
                        'name', ca.name,
                        'status', ca.status,
                        'change_type', ca.change_type,
                        'target_group', ca.target_group
                    )
                ),
                '[]'::jsonb
            )
        ) INTO result_data
        FROM all_descendants ad
        JOIN jt_ent_capabilities_ent_change_adoption_join jca 
            ON ad.id = jca.ent_capabilities_id AND ad.year = jca.ent_capabilities_year
        JOIN ent_change_adoption ca 
            ON jca.ent_change_adoption_id = ca.id AND jca.ent_change_adoption_year = ca.year;
    END IF;

    -- Return empty array if no data found
    IF result_data IS NULL THEN
        result_data := jsonb_build_object('items', '[]'::jsonb);
    END IF;

    RETURN result_data;
END;
$$;


ALTER FUNCTION "public"."get_change_adoption_detail"("capability_id" "text", "year_param" integer, "level_param" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_culture_health_detail"("capability_id" "text", "year_param" integer, "level_param" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    result_data jsonb;
BEGIN
    -- For L3 level (leaf nodes) - direct data
    IF level_param = 'L3' THEN
        SELECT jsonb_build_object(
            'items', COALESCE(
                jsonb_agg(
                    jsonb_build_object(
                        'name', ch.name,
                        'survey_score', ch.survey_score,
                        'trend', ch.trend,
                        'target', ch.target,
                        'participation_rate', ch.participation_rate,
                        'historical_trends', ch.historical_trends,
                        'baseline', ch.baseline
                    )
                ),
                '[]'::jsonb
            )
        ) INTO result_data
        FROM ent_capabilities c
        JOIN jt_ent_capabilities_ent_culture_health_join jch 
            ON c.id = jch.ent_capabilities_id AND c.year = jch.ent_capabilities_year
        JOIN ent_culture_health ch 
            ON jch.ent_culture_health_id = ch.id AND jch.ent_culture_health_year = ch.year
        WHERE c.id = capability_id AND c.year = year_param;
    
    -- For L2 level (mid-level aggregation) - aggregate child L3 capabilities
    ELSIF level_param = 'L2' THEN
        WITH child_capabilities AS (
            SELECT * FROM ent_capabilities 
            WHERE parent_id = capability_id AND parent_year = year_param AND level = 'L3'
        )
        SELECT jsonb_build_object(
            'items', COALESCE(
                jsonb_agg(
                    jsonb_build_object(
                        'name', ch.name,
                        'survey_score', ch.survey_score,
                        'trend', ch.trend,
                        'target', ch.target,
                        'participation_rate', ch.participation_rate,
                        'historical_trends', ch.historical_trends,
                        'baseline', ch.baseline
                    )
                ),
                '[]'::jsonb
            )
        ) INTO result_data
        FROM child_capabilities cc
        JOIN jt_ent_capabilities_ent_culture_health_join jch 
            ON cc.id = jch.ent_capabilities_id AND cc.year = jch.ent_capabilities_year
        JOIN ent_culture_health ch 
            ON jch.ent_culture_health_id = ch.id AND jch.ent_culture_health_year = ch.year;
    
    -- For L1 level (top-level aggregation) - aggregate all descendant capabilities
    ELSIF level_param = 'L1' THEN
        WITH all_descendants AS (
            SELECT * FROM ent_capabilities 
            WHERE id LIKE capability_id || '.%' AND year = year_param AND level IN ('L2', 'L3')
        )
        SELECT jsonb_build_object(
            'items', COALESCE(
                jsonb_agg(
                    jsonb_build_object(
                        'name', ch.name,
                        'survey_score', ch.survey_score,
                        'trend', ch.trend,
                        'target', ch.target,
                        'participation_rate', ch.participation_rate,
                        'historical_trends', ch.historical_trends,
                        'baseline', ch.baseline
                    )
                ),
                '[]'::jsonb
            )
        ) INTO result_data
        FROM all_descendants ad
        JOIN jt_ent_capabilities_ent_culture_health_join jch 
            ON ad.id = jch.ent_capabilities_id AND ad.year = jch.ent_capabilities_year
        JOIN ent_culture_health ch 
            ON jch.ent_culture_health_id = ch.id AND jch.ent_culture_health_year = ch.year;
    END IF;

    -- Return empty array if no data found
    IF result_data IS NULL THEN
        result_data := jsonb_build_object('items', '[]'::jsonb);
    END IF;

    RETURN result_data;
END;
$$;


ALTER FUNCTION "public"."get_culture_health_detail"("capability_id" "text", "year_param" integer, "level_param" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_current_timestamp"() RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  RETURN json_build_object(
    'timestamp', NOW(),
    'date', CURRENT_DATE,
    'time', CURRENT_TIME
  );
END;
$$;


ALTER FUNCTION "public"."get_current_timestamp"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_it_systems_detail"("capability_id" "text", "year_param" integer, "level_param" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    result_data jsonb;
BEGIN
    -- For L3 level (leaf nodes) - direct data
    IF level_param = 'L3' THEN
        SELECT jsonb_build_object(
            'items', COALESCE(
                jsonb_agg(
                    jsonb_build_object(
                        'name', its.name,
                        'operational_status', its.operational_status,
                        'system_type', its.system_type,
                        'deployment_date', its.deployment_date,
                        'criticality', its.criticality,
                        'annual_maintenance_costs', its.annual_maintenance_costs,
                        'technology_stack', its.technology_stack,
                        'vendor_supplier', its.vendor_supplier
                    )
                ),
                '[]'::jsonb
            )
        ) INTO result_data
        FROM ent_capabilities c
        JOIN jt_ent_capabilities_ent_it_systems_join jits 
            ON c.id = jits.ent_capabilities_id AND c.year = jits.ent_capabilities_year
        JOIN ent_it_systems its 
            ON jits.ent_it_systems_id = its.id AND jits.ent_it_systems_year = its.year
        WHERE c.id = capability_id AND c.year = year_param;
    
    -- For L2 level (mid-level aggregation) - aggregate child L3 capabilities
    ELSIF level_param = 'L2' THEN
        WITH child_capabilities AS (
            SELECT * FROM ent_capabilities 
            WHERE parent_id = capability_id AND parent_year = year_param AND level = 'L3'
        )
        SELECT jsonb_build_object(
            'items', COALESCE(
                jsonb_agg(
                    jsonb_build_object(
                        'name', its.name,
                        'operational_status', its.operational_status,
                        'system_type', its.system_type,
                        'deployment_date', its.deployment_date,
                        'criticality', its.criticality,
                        'annual_maintenance_costs', its.annual_maintenance_costs,
                        'technology_stack', its.technology_stack,
                        'vendor_supplier', its.vendor_supplier
                    )
                ),
                '[]'::jsonb
            )
        ) INTO result_data
        FROM child_capabilities cc
        JOIN jt_ent_capabilities_ent_it_systems_join jits 
            ON cc.id = jits.ent_capabilities_id AND cc.year = jits.ent_capabilities_year
        JOIN ent_it_systems its 
            ON jits.ent_it_systems_id = its.id AND jits.ent_it_systems_year = its.year;
    
    -- For L1 level (top-level aggregation) - aggregate all descendant capabilities
    ELSIF level_param = 'L1' THEN
        WITH all_descendants AS (
            SELECT * FROM ent_capabilities 
            WHERE id LIKE capability_id || '.%' AND year = year_param AND level IN ('L2', 'L3')
        )
        SELECT jsonb_build_object(
            'items', COALESCE(
                jsonb_agg(
                    jsonb_build_object(
                        'name', its.name,
                        'operational_status', its.operational_status,
                        'system_type', its.system_type,
                        'deployment_date', its.deployment_date,
                        'criticality', its.criticality,
                        'annual_maintenance_costs', its.annual_maintenance_costs,
                        'technology_stack', its.technology_stack,
                        'vendor_supplier', its.vendor_supplier
                    )
                ),
                '[]'::jsonb
            )
        ) INTO result_data
        FROM all_descendants ad
        JOIN jt_ent_capabilities_ent_it_systems_join jits 
            ON ad.id = jits.ent_capabilities_id AND ad.year = jits.ent_capabilities_year
        JOIN ent_it_systems its 
            ON jits.ent_it_systems_id = its.id AND jits.ent_it_systems_year = its.year;
    END IF;

    -- Return empty array if no data found
    IF result_data IS NULL THEN
        result_data := jsonb_build_object('items', '[]'::jsonb);
    END IF;

    RETURN result_data;
END;
$$;


ALTER FUNCTION "public"."get_it_systems_detail"("capability_id" "text", "year_param" integer, "level_param" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_next_join_table_id"("p_sequence_name" "text") RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  next_id numeric;
  table_name text;
BEGIN
  -- Extract the table name from the sequence name
  table_name := REPLACE(p_sequence_name, '_id_seq', '');
  
  -- First, check the maximum existing ID in the table
  EXECUTE format('SELECT COALESCE(MAX(CAST(id AS numeric)), 0) + 1.0 FROM %I', table_name) INTO next_id;
  
  -- Then, get the next value from the sequence
  EXECUTE format('SELECT nextval(%L)', p_sequence_name) INTO next_id;
  
  RETURN next_id::text;
END;
$$;


ALTER FUNCTION "public"."get_next_join_table_id"("p_sequence_name" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_project_deliverables_detail"("capability_id" "text", "year_param" integer, "level_param" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    result_data jsonb;
BEGIN
    -- For L3 level (leaf nodes) - direct data
    IF level_param = 'L3' THEN
        SELECT jsonb_build_object(
            'items', COALESCE(
                jsonb_agg(
                    jsonb_build_object(
                        'name', p.name,
                        'status', p.status,
                        'start_date', p.start_date,
                        'end_date', p.end_date,
                        'progress_percentage', p.progress_percentage,
                        'budget', p.budget,
                        'deliverable', p.deliverable,
                        'project_manager', p.project_manager,
                        'type', p.type
                    )
                ), 
                '[]'::jsonb
            )
        ) INTO result_data
        FROM ent_capabilities c
        JOIN jt_ent_capabilities_ent_projects_join jp 
            ON c.id = jp.ent_capabilities_id AND c.year = jp.ent_capabilities_year
        JOIN ent_projects p 
            ON jp.ent_projects_id = p.id AND jp.ent_projects_year = p.year
        WHERE c.id = capability_id AND c.year = year_param;
    
    -- For L2 level (mid-level aggregation) - aggregate child L3 capabilities
    ELSIF level_param = 'L2' THEN
        WITH child_capabilities AS (
            SELECT * FROM ent_capabilities 
            WHERE parent_id = capability_id AND parent_year = year_param AND level = 'L3'
        )
        SELECT jsonb_build_object(
            'items', COALESCE(
                jsonb_agg(
                    jsonb_build_object(
                        'name', p.name,
                        'status', p.status,
                        'start_date', p.start_date,
                        'end_date', p.end_date,
                        'progress_percentage', p.progress_percentage,
                        'budget', p.budget,
                        'deliverable', p.deliverable,
                        'project_manager', p.project_manager,
                        'type', p.type
                    )
                ),
                '[]'::jsonb
            )
        ) INTO result_data
        FROM child_capabilities cc
        JOIN jt_ent_capabilities_ent_projects_join jp 
            ON cc.id = jp.ent_capabilities_id AND cc.year = jp.ent_capabilities_year
        JOIN ent_projects p 
            ON jp.ent_projects_id = p.id AND jp.ent_projects_year = p.year;
    
    -- For L1 level (top-level aggregation) - aggregate all descendant capabilities
    ELSIF level_param = 'L1' THEN
        WITH all_descendants AS (
            SELECT * FROM ent_capabilities 
            WHERE id LIKE capability_id || '.%' AND year = year_param AND level IN ('L2', 'L3')
        )
        SELECT jsonb_build_object(
            'items', COALESCE(
                jsonb_agg(
                    jsonb_build_object(
                        'name', p.name,
                        'status', p.status,
                        'start_date', p.start_date,
                        'end_date', p.end_date,
                        'progress_percentage', p.progress_percentage,
                        'budget', p.budget,
                        'deliverable', p.deliverable,
                        'project_manager', p.project_manager,
                        'type', p.type
                    )
                ),
                '[]'::jsonb
            )
        ) INTO result_data
        FROM all_descendants ad
        JOIN jt_ent_capabilities_ent_projects_join jp 
            ON ad.id = jp.ent_capabilities_id AND ad.year = jp.ent_capabilities_year
        JOIN ent_projects p 
            ON jp.ent_projects_id = p.id AND jp.ent_projects_year = p.year;
    END IF;

    -- Return empty array if no data found
    IF result_data IS NULL THEN
        result_data := jsonb_build_object('items', '[]'::jsonb);
    END IF;

    RETURN result_data;
END;
$$;


ALTER FUNCTION "public"."get_project_deliverables_detail"("capability_id" "text", "year_param" integer, "level_param" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_project_deliverables_detail_secure"("capability_id" "text", "year_param" integer, "level_param" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
BEGIN
    -- No role check - allow anyone to access
    -- Call the original function with elevated privileges
    RETURN public.get_project_deliverables_detail(capability_id, year_param, level_param);
END;
$$;


ALTER FUNCTION "public"."get_project_deliverables_detail_secure"("capability_id" "text", "year_param" integer, "level_param" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_role_gaps_detail"("capability_id" "text", "year_param" integer, "level_param" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    result_data jsonb;
BEGIN
    -- For L3 level (leaf nodes) - direct data
    IF level_param = 'L3' THEN
        SELECT jsonb_build_object(
            'items', COALESCE(
                jsonb_agg(
                    jsonb_build_object(
                        'name', ou.name,
                        'gap', ou.gap,
                        'headcount', ou.headcount,
                        'staff_count', ou.staff_count,
                        'unit_type', ou.unit_type,
                        'head_of_unit', ou.head_of_unit,
                        'annual_budget', ou.annual_budget,
                        'location', ou.location
                    )
                ),
                '[]'::jsonb
            )
        ) INTO result_data
        FROM ent_capabilities c
        JOIN jt_ent_capabilities_ent_org_units_join jou 
            ON c.id = jou.ent_capabilities_id AND c.year = jou.ent_capabilities_year
        JOIN ent_org_units ou 
            ON jou.ent_org_units_id = ou.id AND jou.ent_org_units_year = ou.year
        WHERE c.id = capability_id AND c.year = year_param;
    
    -- For L2 level (mid-level aggregation) - aggregate child L3 capabilities
    ELSIF level_param = 'L2' THEN
        WITH child_capabilities AS (
            SELECT * FROM ent_capabilities 
            WHERE parent_id = capability_id AND parent_year = year_param AND level = 'L3'
        )
        SELECT jsonb_build_object(
            'items', COALESCE(
                jsonb_agg(
                    jsonb_build_object(
                        'name', ou.name,
                        'gap', ou.gap,
                        'headcount', ou.headcount,
                        'staff_count', ou.staff_count,
                        'unit_type', ou.unit_type,
                        'head_of_unit', ou.head_of_unit,
                        'annual_budget', ou.annual_budget,
                        'location', ou.location
                    )
                ),
                '[]'::jsonb
            )
        ) INTO result_data
        FROM child_capabilities cc
        JOIN jt_ent_capabilities_ent_org_units_join jou 
            ON cc.id = jou.ent_capabilities_id AND cc.year = jou.ent_capabilities_year
        JOIN ent_org_units ou 
            ON jou.ent_org_units_id = ou.id AND jou.ent_org_units_year = ou.year;
    
    -- For L1 level (top-level aggregation) - aggregate all descendant capabilities
    ELSIF level_param = 'L1' THEN
        WITH all_descendants AS (
            SELECT * FROM ent_capabilities 
            WHERE id LIKE capability_id || '.%' AND year = year_param AND level IN ('L2', 'L3')
        )
        SELECT jsonb_build_object(
            'items', COALESCE(
                jsonb_agg(
                    jsonb_build_object(
                        'name', ou.name,
                        'gap', ou.gap,
                        'headcount', ou.headcount,
                        'staff_count', ou.staff_count,
                        'unit_type', ou.unit_type,
                        'head_of_unit', ou.head_of_unit,
                        'annual_budget', ou.annual_budget,
                        'location', ou.location
                    )
                ),
                '[]'::jsonb
            )
        ) INTO result_data
        FROM all_descendants ad
        JOIN jt_ent_capabilities_ent_org_units_join jou 
            ON ad.id = jou.ent_capabilities_id AND ad.year = jou.ent_capabilities_year
        JOIN ent_org_units ou 
            ON jou.ent_org_units_id = ou.id AND jou.ent_org_units_year = ou.year;
    END IF;

    -- Return empty array if no data found
    IF result_data IS NULL THEN
        result_data := jsonb_build_object('items', '[]'::jsonb);
    END IF;

    RETURN result_data;
END;
$$;


ALTER FUNCTION "public"."get_role_gaps_detail"("capability_id" "text", "year_param" integer, "level_param" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."has_role"("required_role" "text") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  -- Check if the user has the required role in their JWT claims
  RETURN (
    SELECT 
      CASE WHEN auth.jwt() ->> 'app_metadata' IS NULL THEN false
      ELSE 
        COALESCE(
          (auth.jwt() -> 'app_metadata' -> 'roles')::jsonb ? required_role,
          false
        )
      END
  );
END;
$$;


ALTER FUNCTION "public"."has_role"("required_role" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_service_role"() RETURNS boolean
    LANGUAGE "sql" SECURITY DEFINER
    AS $$
    SELECT COALESCE(
        (SELECT rolname = 'service_role' 
         FROM pg_roles 
         WHERE rolname = current_user),
        false
    );
$$;


ALTER FUNCTION "public"."is_service_role"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."kg_edges_enforce"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  src_t TEXT;
  dst_t TEXT;
  ok   INT;
BEGIN
  SELECT type INTO src_t FROM kg_nodes WHERE id = NEW.src_id;
  IF src_t IS NULL THEN
    RAISE EXCEPTION 'kg_edges_enforce: src node % not found', NEW.src_id;
  END IF;

  SELECT type INTO dst_t FROM kg_nodes WHERE id = NEW.dst_id;
  IF dst_t IS NULL THEN
    RAISE EXCEPTION 'kg_edges_enforce: dst node % not found', NEW.dst_id;
  END IF;

  SELECT 1 INTO ok FROM rel_allowlist
    WHERE src_type = src_t AND rel_name = NEW.rel_type AND dst_type = dst_t
    LIMIT 1;

  IF ok IS NULL THEN
    RAISE EXCEPTION 'Edge not permitted by DTDL: (%, %, %)', src_t, NEW.rel_type, dst_t;
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."kg_edges_enforce"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."manage_risk_associations"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    -- Only proceed if the risk score has changed or is being set for the first time
    IF (TG_OP = 'INSERT') OR (OLD.risk_score IS DISTINCT FROM NEW.risk_score) THEN
        -- Check if the risk affects policy tools or performance
        IF NEW.affecting_policy_tools_or_performance = 'policy_tools' THEN
            -- Handle policy tools association
            IF NEW.risk_score >= 50 THEN
                -- Get the policy tool associated with the capability
                WITH policy_tools AS (
                    SELECT pt.id, pt.year, pt.name
                    FROM sec_policy_tools pt
                    JOIN jt_sec_policy_tools_ent_capabilities_join j 
                        ON pt.id = j.sec_policy_tools_id AND pt.year = j.sec_policy_tools_year
                    WHERE j.ent_capabilities_id = NEW.id AND j.ent_capabilities_year = NEW.year
                )
                SELECT string_agg(id || ' (' || year || '): ' || name, ', ') 
                INTO NEW.policy_tools_associated
                FROM policy_tools;
                
                -- Clear any performance association
                NEW.performance_target_associated := NULL;
            ELSE
                -- Risk score below threshold, clear the association
                NEW.policy_tools_associated := NULL;
            END IF;
        ELSIF NEW.affecting_policy_tools_or_performance = 'performance' THEN
            -- Handle performance association
            IF NEW.risk_score >= 50 THEN
                -- Get the performance targets associated with the capability
                WITH performance AS (
                    SELECT p.id, p.year, p.name
                    FROM sec_performance p
                    JOIN jt_sec_performance_ent_capabilities_join j 
                        ON p.id = j.sec_performance_id AND p.year = j.sec_performance_year
                    WHERE j.ent_capabilities_id = NEW.id AND j.ent_capabilities_year = NEW.year
                )
                SELECT string_agg(id || ' (' || year || '): ' || name, ', ') 
                INTO NEW.performance_target_associated
                FROM performance;
                
                -- Clear any policy tools association
                NEW.policy_tools_associated := NULL;
            ELSE
                -- Risk score below threshold, clear the association
                NEW.performance_target_associated := NULL;
            END IF;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."manage_risk_associations"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."safe_to_boolean"("p_value" "text") RETURNS boolean
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    IF p_value IS NULL OR p_value = '' THEN
        RETURN NULL;
    ELSIF lower(p_value) IN ('true', 't', 'yes', 'y', '1') THEN
        RETURN TRUE;
    ELSIF lower(p_value) IN ('false', 'f', 'no', 'n', '0') THEN
        RETURN FALSE;
    ELSE
        RETURN NULL;  -- Return NULL for any unexpected input
    END IF;
EXCEPTION WHEN OTHERS THEN
    RETURN NULL;  -- Handle any unexpected errors
END;
$$;


ALTER FUNCTION "public"."safe_to_boolean"("p_value" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."safe_to_date"("p_value" "text") RETURNS "date"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    IF p_value IS NULL OR p_value = '' THEN
        RETURN NULL;
    END IF;

    RETURN p_value::DATE;
EXCEPTION WHEN OTHERS THEN
    RETURN to_date(p_value, 'MM/DD/YYYY');
END;
$$;


ALTER FUNCTION "public"."safe_to_date"("p_value" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."safe_to_float"("p_value" "text") RETURNS double precision
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    IF p_value IS NULL OR p_value = '' THEN
        RETURN NULL;
    END IF;

    RETURN p_value::FLOAT;
EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
END;
$$;


ALTER FUNCTION "public"."safe_to_float"("p_value" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."table_exists"("schema_name" "text", "table_name" "text") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT FROM information_schema.tables 
    WHERE table_schema = schema_name
    AND table_name = table_name
  );
END;
$$;


ALTER FUNCTION "public"."table_exists"("schema_name" "text", "table_name" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."temp_split_string"("p_string" "text", "p_delimiter" "text" DEFAULT ';'::"text") RETURNS TABLE("val" "text")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    IF p_string IS NULL OR p_string = '' THEN
        RETURN;
    END IF;

    RETURN QUERY 
    SELECT trim(unnest) AS val
    FROM unnest(string_to_array(p_string, p_delimiter)) 
    WHERE trim(unnest) <> '';
END;
$$;


ALTER FUNCTION "public"."temp_split_string"("p_string" "text", "p_delimiter" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_inherent_risk_score"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $_$
BEGIN
    NEW.inherent_risk_score := 
        CASE 
            WHEN NEW.probability::text ~ '^[0-9]+$' AND NEW.impact_level::text ~ '^[0-9]+$' 
            THEN NEW.probability::integer * NEW.impact_level::integer
            ELSE NULL
        END;
    RETURN NEW;
END;
$_$;


ALTER FUNCTION "public"."update_inherent_risk_score"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_modified_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_modified_column"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_modified_timestamp"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.modified_date = CURRENT_TIMESTAMP;
    IF TG_OP = 'UPDATE' THEN
        NEW.version_number = COALESCE(OLD.version_number, 0) + 1;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_modified_timestamp"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_project_memory_timestamp"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_project_memory_timestamp"() OWNER TO "service_role";


CREATE OR REPLACE FUNCTION "public"."update_risk_affecting_field"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    -- Check if field is already set explicitly
    IF NEW.affecting_policy_tools_or_performance IS NOT NULL THEN
        RETURN NEW;
    END IF;
    
    -- Determine if this risk affects policy tools or performance based on linked tables
    DECLARE
        has_policy_tools boolean;
        has_performance boolean;
    BEGIN
        -- Check if capability has associated policy tools
        SELECT EXISTS (
            SELECT 1 FROM jt_sec_policy_tools_ent_capabilities_join
            WHERE ent_capabilities_id = NEW.id AND ent_capabilities_year = NEW.year
        ) INTO has_policy_tools;
        
        -- Check if capability has associated performance targets
        SELECT EXISTS (
            SELECT 1 FROM jt_sec_performance_ent_capabilities_join
            WHERE ent_capabilities_id = NEW.id AND ent_capabilities_year = NEW.year
        ) INTO has_performance;
        
        -- Set the affecting field based on what's found
        IF has_policy_tools AND NOT has_performance THEN
            NEW.affecting_policy_tools_or_performance := 'policy_tools';
        ELSIF has_performance AND NOT has_policy_tools THEN
            NEW.affecting_policy_tools_or_performance := 'performance';
        ELSIF has_policy_tools AND has_performance THEN
            -- If both exist, default to policy tools as they take precedence
            NEW.affecting_policy_tools_or_performance := 'policy_tools';
        ELSE
            -- If neither exists, set to null
            NEW.affecting_policy_tools_or_performance := NULL;
        END IF;
    END;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_risk_affecting_field"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_risk_performance_junction"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    -- Only proceed if affecting performance and risk score >= 50
    IF NEW.affecting_policy_tools_or_performance = 'performance' AND NEW.risk_score >= 50 THEN
        -- First delete any existing associations for this risk
        DELETE FROM jt_ent_risks_sec_performance_join 
        WHERE ent_risks_id = NEW.id AND ent_risks_year = NEW.year;
        
        -- Then insert new associations based on the capability's performance targets
        INSERT INTO jt_ent_risks_sec_performance_join (ent_risks_id, ent_risks_year, sec_performance_id, sec_performance_year)
        SELECT NEW.id, NEW.year, j.sec_performance_id, j.sec_performance_year
        FROM jt_sec_performance_ent_capabilities_join j
        WHERE j.ent_capabilities_id = NEW.id AND j.ent_capabilities_year = NEW.year;
    ELSE
        -- Risk score below threshold or not affecting performance, remove associations
        DELETE FROM jt_ent_risks_sec_performance_join 
        WHERE ent_risks_id = NEW.id AND ent_risks_year = NEW.year;
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_risk_performance_junction"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_risk_policy_tool_junction"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    -- Only proceed if affecting policy tools and risk score >= 50
    IF NEW.affecting_policy_tools_or_performance = 'policy_tools' AND NEW.risk_score >= 50 THEN
        -- First delete any existing associations for this risk
        DELETE FROM jt_ent_risks_sec_policy_tools_join 
        WHERE ent_risks_id = NEW.id AND ent_risks_year = NEW.year;
        
        -- Then insert new associations based on the capability's policy tools
        INSERT INTO jt_ent_risks_sec_policy_tools_join (ent_risks_id, ent_risks_year, sec_policy_tools_id, sec_policy_tools_year)
        SELECT NEW.id, NEW.year, j.sec_policy_tools_id, j.sec_policy_tools_year
        FROM jt_sec_policy_tools_ent_capabilities_join j
        WHERE j.ent_capabilities_id = NEW.id AND j.ent_capabilities_year = NEW.year;
    ELSE
        -- Risk score below threshold or not affecting policy tools, remove associations
        DELETE FROM jt_ent_risks_sec_policy_tools_join 
        WHERE ent_risks_id = NEW.id AND ent_risks_year = NEW.year;
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_risk_policy_tool_junction"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_risk_scores"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    -- Update the risk score components
    IF (TG_OP = 'UPDATE') AND (
        OLD.project_outputs_risk IS DISTINCT FROM NEW.project_outputs_risk OR
        OLD.role_gaps_risk IS DISTINCT FROM NEW.role_gaps_risk OR
        OLD.it_systems_risk IS DISTINCT FROM NEW.it_systems_risk OR
        OLD.project_outputs_persistence IS DISTINCT FROM NEW.project_outputs_persistence OR
        OLD.role_gaps_persistence IS DISTINCT FROM NEW.role_gaps_persistence OR
        OLD.it_systems_persistence IS DISTINCT FROM NEW.it_systems_persistence OR
        OLD.project_outputs_delay_days IS DISTINCT FROM NEW.project_outputs_delay_days OR
        OLD.role_gaps_delay_days IS DISTINCT FROM NEW.role_gaps_delay_days OR
        OLD.it_systems_delay_days IS DISTINCT FROM NEW.it_systems_delay_days
    ) THEN
        -- The risk_score will be automatically recalculated via the stored generated column
        -- No need to manually update it
        NULL;
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_risk_scores"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_session_context"("p_session_id" character varying, "p_user_id" character varying, "p_focus" character varying, "p_action" character varying DEFAULT 'view'::character varying) RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    INSERT INTO dto_heat_map_sessions (session_id, user_id, current_focus)
    VALUES (p_session_id, p_user_id, p_focus)
    ON CONFLICT (session_id) DO UPDATE SET
        current_focus = EXCLUDED.current_focus,
        drill_down_path = CASE 
            WHEN p_action = 'drill_down' THEN 
                COALESCE(dto_heat_map_sessions.drill_down_path, '[]'::jsonb) || 
                json_build_array(p_focus)::jsonb
            WHEN p_action = 'back' THEN
                CASE 
                    WHEN jsonb_array_length(dto_heat_map_sessions.drill_down_path) > 0 THEN
                        dto_heat_map_sessions.drill_down_path #- '{-1}'
                    ELSE '[]'::jsonb
                END
            ELSE dto_heat_map_sessions.drill_down_path
        END,
        last_interaction = CURRENT_TIMESTAMP;
END;
$$;


ALTER FUNCTION "public"."update_session_context"("p_session_id" character varying, "p_user_id" character varying, "p_focus" character varying, "p_action" character varying) OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "migration_util"."validation_log" (
    "validation_id" integer NOT NULL,
    "phase" "text",
    "validation_type" "text",
    "details" "text",
    "logged_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE "migration_util"."validation_log" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "migration_util"."validation_log_validation_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "migration_util"."validation_log_validation_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "migration_util"."validation_log_validation_id_seq" OWNED BY "migration_util"."validation_log"."validation_id";



CREATE TABLE IF NOT EXISTS "public"."documentation_plans" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "plan_name" "text" NOT NULL,
    "version" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "content" "text",
    "structured_data" "jsonb",
    "category" "text"
);


ALTER TABLE "public"."documentation_plans" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."dtdl_models" (
    "id" "text" NOT NULL,
    "json" "jsonb" NOT NULL,
    "version" integer NOT NULL
);


ALTER TABLE "public"."dtdl_models" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ent_capabilities" (
    "id" character varying(10) NOT NULL,
    "year" integer NOT NULL,
    "name" character varying(255),
    "description" "text",
    "quarter" integer,
    "maturity_level" integer,
    "level" character varying(10) NOT NULL,
    "parent_id" character varying(10),
    "parent_year" integer,
    "status" character varying(50),
    "target_maturity_level" character varying(50),
    "type" "text",
    CONSTRAINT "ent_capabilities_id_check" CHECK ((("id")::"text" ~ '^[1-9][0-9]*\.0$|^[1-9][0-9]*\.[1-9][0-9]*$|^[1-9][0-9]*\.[1-9][0-9]*\.[1-9][0-9]*$'::"text")),
    CONSTRAINT "ent_capabilities_level_check" CHECK ((("level")::"text" = ANY (ARRAY[('L1'::character varying)::"text", ('L2'::character varying)::"text", ('L3'::character varying)::"text"])))
);


ALTER TABLE "public"."ent_capabilities" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ent_change_adoption" (
    "id" character varying(10) NOT NULL,
    "year" integer NOT NULL,
    "quarter" integer,
    "name" character varying(255),
    "level" character varying(10) NOT NULL,
    "parent_id" character varying(10),
    "parent_year" integer,
    "change_type" character varying(255),
    "target_group" "text",
    "status" character varying(50),
    CONSTRAINT "ent_change_adoption_id_check" CHECK ((("id")::"text" ~ '^[1-9][0-9]*\.0$|^[1-9][0-9]*\.[1-9][0-9]*$|^[1-9][0-9]*\.[1-9][0-9]*\.[1-9][0-9]*$'::"text")),
    CONSTRAINT "ent_change_adoption_level_check" CHECK ((("level")::"text" = ANY (ARRAY[('L1'::character varying)::"text", ('L2'::character varying)::"text", ('L3'::character varying)::"text"])))
);


ALTER TABLE "public"."ent_change_adoption" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ent_culture_health" (
    "id" character varying(10) NOT NULL,
    "year" integer NOT NULL,
    "quarter" integer,
    "name" character varying(255),
    "level" character varying(10) NOT NULL,
    "parent_id" character varying(10),
    "parent_year" integer,
    "survey_score" numeric(5,2),
    "trend" character varying(50),
    "target" numeric(5,2),
    "participation_rate" numeric(5,2),
    "historical_trends" character varying(50),
    "baseline" numeric(5,2),
    CONSTRAINT "ent_culture_health_id_check" CHECK ((("id")::"text" ~ '^[1-9][0-9]*\.0$|^[1-9][0-9]*\.[1-9][0-9]*$|^[1-9][0-9]*\.[1-9][0-9]*\.[1-9][0-9]*$'::"text")),
    CONSTRAINT "ent_culture_health_level_check" CHECK ((("level")::"text" = ANY (ARRAY[('L1'::character varying)::"text", ('L2'::character varying)::"text", ('L3'::character varying)::"text"])))
);


ALTER TABLE "public"."ent_culture_health" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ent_it_systems" (
    "id" character varying(10) NOT NULL,
    "year" integer NOT NULL,
    "quarter" integer,
    "name" character varying(255),
    "level" character varying(10) NOT NULL,
    "parent_id" character varying(10),
    "parent_year" integer,
    "system_type" character varying(255),
    "technology_stack" "text",
    "owner" character varying(255),
    "operational_status" character varying(50),
    "acquisition_cost" numeric(15,2),
    "number_of_modules" integer,
    "licensing" character varying(255),
    "annual_maintenance_costs" numeric(15,2),
    "criticality" character varying(50),
    "deployment_date" "date",
    "vendor_supplier" character varying(255),
    CONSTRAINT "ent_it_systems_id_check" CHECK ((("id")::"text" ~ '^[1-9][0-9]*\.0$|^[1-9][0-9]*\.[1-9][0-9]*$|^[1-9][0-9]*\.[1-9][0-9]*\.[1-9][0-9]*$'::"text")),
    CONSTRAINT "ent_it_systems_level_check" CHECK ((("level")::"text" = ANY (ARRAY[('L1'::character varying)::"text", ('L2'::character varying)::"text", ('L3'::character varying)::"text"])))
);


ALTER TABLE "public"."ent_it_systems" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ent_org_units" (
    "id" character varying(10) NOT NULL,
    "year" integer NOT NULL,
    "quarter" integer,
    "name" character varying(255),
    "level" character varying(10) NOT NULL,
    "parent_id" character varying(10),
    "parent_year" integer,
    "unit_type" character varying(255),
    "headcount" integer,
    "budget" numeric(15,2),
    "location" character varying(255),
    "head_of_unit" character varying(255),
    "annual_budget" numeric(15,2),
    "staff_count" integer,
    "gap" smallint,
    CONSTRAINT "ent_org_units_id_check" CHECK ((("id")::"text" ~ '^[1-9][0-9]*\.0$|^[1-9][0-9]*\.[1-9][0-9]*$|^[1-9][0-9]*\.[1-9][0-9]*\.[1-9][0-9]*$'::"text")),
    CONSTRAINT "ent_org_units_level_check" CHECK ((("level")::"text" = ANY (ARRAY[('L1'::character varying)::"text", ('L2'::character varying)::"text", ('L3'::character varying)::"text"])))
);


ALTER TABLE "public"."ent_org_units" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ent_processes" (
    "id" character varying(10) NOT NULL,
    "year" integer NOT NULL,
    "quarter" integer,
    "name" character varying(255),
    "level" character varying(10) NOT NULL,
    "parent_id" character varying(10),
    "parent_year" integer,
    "process_type" character varying(255),
    "maturity_level" integer,
    "automated" character varying(50),
    "automation_due" character varying,
    "health_status" character varying(50),
    "stage" character varying(50),
    "description" "text",
    "inputs" "text",
    "outputs" "text",
    CONSTRAINT "ent_processes_id_check" CHECK ((("id")::"text" ~ '^[1-9][0-9]*\.0$|^[1-9][0-9]*\.[1-9][0-9]*$|^[1-9][0-9]*\.[1-9][0-9]*\.[1-9][0-9]*$'::"text")),
    CONSTRAINT "ent_processes_level_check" CHECK ((("level")::"text" = ANY (ARRAY[('L1'::character varying)::"text", ('L2'::character varying)::"text", ('L3'::character varying)::"text"])))
);


ALTER TABLE "public"."ent_processes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ent_projects" (
    "id" character varying(10) NOT NULL,
    "year" integer NOT NULL,
    "quarter" integer,
    "name" character varying(255),
    "level" character varying(10) NOT NULL,
    "parent_id" character varying(10),
    "parent_year" integer,
    "start_date" "date",
    "end_date" "date",
    "status" character varying(50),
    "budget" numeric(15,2),
    "progress_percentage" numeric,
    CONSTRAINT "ent_projects_id_check" CHECK ((("id")::"text" ~ '^[1-9][0-9]*\.0$|^[1-9][0-9]*\.[1-9][0-9]*$|^[1-9][0-9]*\.[1-9][0-9]*\.[1-9][0-9]*$'::"text")),
    CONSTRAINT "ent_projects_level_check" CHECK ((("level")::"text" = ANY (ARRAY[('L1'::character varying)::"text", ('L2'::character varying)::"text", ('L3'::character varying)::"text"])))
);


ALTER TABLE "public"."ent_projects" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ent_risks" (
    "id" character varying NOT NULL,
    "year" integer NOT NULL,
    "quarter" integer,
    "name" character varying,
    "level" character varying NOT NULL,
    "parent_id" character varying,
    "parent_year" integer,
    "risk_category" character varying,
    "project_outputs_risk" numeric,
    "role_gaps_risk" numeric,
    "it_systems_risk" numeric,
    "project_outputs_persistence" integer,
    "role_gaps_persistence" integer,
    "it_systems_persistence" integer,
    "project_outputs_delay_days" integer,
    "role_gaps_delay_days" integer,
    "it_systems_delay_days" integer,
    "likelihood_of_delay" numeric,
    "delay_days" integer,
    "risk_score" numeric GENERATED ALWAYS AS (("likelihood_of_delay" * ("delay_days")::numeric)) STORED,
    "people_score" numeric,
    "process_score" numeric,
    "tools_score" numeric,
    "operational_health_score" numeric GENERATED ALWAYS AS (((("people_score" + "process_score") + "tools_score") / (3)::numeric)) STORED,
    "identified_date" "date",
    "last_review_date" "date",
    "next_review_date" "date",
    "risk_status" character varying,
    "closure_date" "date",
    "risk_owner" character varying,
    "risk_reviewer" character varying,
    "affecting_policy_tools_or_performance" character varying,
    "policy_tools_associated" "text",
    "performance_target_associated" "text",
    "mitigation_strategy" "text",
    "risk_description" "text",
    "kpi" "text",
    "threshold_red" "text",
    "threshold_amber" "text",
    "threshold_green" "text",
    "external_factors" "text",
    "dependencies" "text",
    CONSTRAINT "ent_risks_id_check" CHECK ((("id")::"text" ~ '^[1-9][0-9]*\.0$|^[1-9][0-9]*\.[1-9][0-9]*$|^[1-9][0-9]*\.[1-9][0-9]*\.[1-9][0-9]*$'::"text")),
    CONSTRAINT "ent_risks_it_systems_persistence_check" CHECK ((("it_systems_persistence" >= 0) AND ("it_systems_persistence" <= 3))),
    CONSTRAINT "ent_risks_level_check" CHECK ((("level")::"text" = ANY (ARRAY['L1'::"text", 'L2'::"text", 'L3'::"text"]))),
    CONSTRAINT "ent_risks_project_outputs_persistence_check" CHECK ((("project_outputs_persistence" >= 0) AND ("project_outputs_persistence" <= 3))),
    CONSTRAINT "ent_risks_risk_status_check" CHECK ((("risk_status")::"text" = ANY ((ARRAY['Open'::character varying, 'Mitigating'::character varying, 'Closed'::character varying, 'Accepted'::character varying, 'Transferred'::character varying])::"text"[]))),
    CONSTRAINT "ent_risks_role_gaps_persistence_check" CHECK ((("role_gaps_persistence" >= 0) AND ("role_gaps_persistence" <= 3)))
);


ALTER TABLE "public"."ent_risks" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ent_vendors" (
    "id" character varying(10) NOT NULL,
    "year" integer NOT NULL,
    "quarter" integer,
    "name" character varying(255),
    "level" character varying(10) NOT NULL,
    "parent_id" character varying(10),
    "parent_year" integer,
    "service_domain" character varying(255),
    "service_detail" "text",
    "contract_value" numeric(15,2),
    "performance_rating" integer,
    "service_level_agreements" "text",
    CONSTRAINT "ent_vendors_id_check" CHECK ((("id")::"text" ~ '^[1-9][0-9]*\.0$|^[1-9][0-9]*\.[1-9][0-9]*$|^[1-9][0-9]*\.[1-9][0-9]*\.[1-9][0-9]*$'::"text")),
    CONSTRAINT "ent_vendors_level_check" CHECK ((("level")::"text" = ANY (ARRAY[('L1'::character varying)::"text", ('L2'::character varying)::"text", ('L3'::character varying)::"text"])))
);


ALTER TABLE "public"."ent_vendors" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."forum_comments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "episode_id" "text" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "user_email" "text" NOT NULL,
    "text" "text" NOT NULL,
    "parent_id" "uuid",
    "likes" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."forum_comments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."jt_ent_capabilities_ent_it_systems_join" (
    "ent_capabilities_id" character varying(10),
    "ent_capabilities_year" integer,
    "ent_it_systems_id" character varying(10),
    "ent_it_systems_year" integer,
    "uid" bigint NOT NULL
);


ALTER TABLE "public"."jt_ent_capabilities_ent_it_systems_join" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."jt_ent_capabilities_ent_it_systems_join_uid_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."jt_ent_capabilities_ent_it_systems_join_uid_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."jt_ent_capabilities_ent_it_systems_join_uid_seq" OWNED BY "public"."jt_ent_capabilities_ent_it_systems_join"."uid";



CREATE TABLE IF NOT EXISTS "public"."jt_ent_capabilities_ent_org_units_join" (
    "ent_capabilities_id" character varying(10),
    "ent_capabilities_year" integer,
    "ent_org_units_id" character varying(10),
    "ent_org_units_year" integer,
    "uid" bigint NOT NULL
);


ALTER TABLE "public"."jt_ent_capabilities_ent_org_units_join" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."jt_ent_capabilities_ent_org_units_join_uid_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."jt_ent_capabilities_ent_org_units_join_uid_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."jt_ent_capabilities_ent_org_units_join_uid_seq" OWNED BY "public"."jt_ent_capabilities_ent_org_units_join"."uid";



CREATE TABLE IF NOT EXISTS "public"."jt_ent_capabilities_ent_processes_join" (
    "ent_capabilities_id" character varying(10),
    "ent_capabilities_year" integer,
    "ent_processes_id" character varying(10),
    "ent_processes_year" integer,
    "uid" bigint NOT NULL
);


ALTER TABLE "public"."jt_ent_capabilities_ent_processes_join" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."jt_ent_capabilities_ent_processes_join_uid_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."jt_ent_capabilities_ent_processes_join_uid_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."jt_ent_capabilities_ent_processes_join_uid_seq" OWNED BY "public"."jt_ent_capabilities_ent_processes_join"."uid";



CREATE TABLE IF NOT EXISTS "public"."jt_ent_change_adoption_ent_it_systems_join" (
    "ent_change_adoption_id" character varying NOT NULL,
    "ent_change_adoption_year" integer NOT NULL,
    "ent_it_systems_id" character varying NOT NULL,
    "ent_it_systems_year" integer NOT NULL,
    "uid" bigint NOT NULL
);


ALTER TABLE "public"."jt_ent_change_adoption_ent_it_systems_join" OWNER TO "postgres";


ALTER TABLE "public"."jt_ent_change_adoption_ent_it_systems_join" ALTER COLUMN "uid" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."jt_ent_change_adoption_ent_it_systems_join_uid_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."jt_ent_change_adoption_ent_org_units_join" (
    "ent_change_adoption_id" character varying NOT NULL,
    "ent_change_adoption_year" integer NOT NULL,
    "ent_org_units_id" character varying NOT NULL,
    "ent_org_units_year" integer NOT NULL,
    "uid" bigint NOT NULL
);


ALTER TABLE "public"."jt_ent_change_adoption_ent_org_units_join" OWNER TO "postgres";


ALTER TABLE "public"."jt_ent_change_adoption_ent_org_units_join" ALTER COLUMN "uid" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."jt_ent_change_adoption_ent_org_units_join_uid_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."jt_ent_change_adoption_ent_processes_join" (
    "ent_change_adoption_id" character varying NOT NULL,
    "ent_change_adoption_year" integer NOT NULL,
    "ent_processes_id" character varying NOT NULL,
    "ent_processes_year" integer NOT NULL,
    "uid" bigint NOT NULL
);


ALTER TABLE "public"."jt_ent_change_adoption_ent_processes_join" OWNER TO "postgres";


ALTER TABLE "public"."jt_ent_change_adoption_ent_processes_join" ALTER COLUMN "uid" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."jt_ent_change_adoption_ent_processes_join_uid_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."jt_ent_it_systems_ent_vendors_join" (
    "uid" bigint NOT NULL,
    "ent_it_systems_id" character varying NOT NULL,
    "ent_it_systems_year" integer NOT NULL,
    "ent_vendors_id" character varying NOT NULL,
    "ent_vendors_year" integer NOT NULL,
    "sla_details" "text"
);


ALTER TABLE "public"."jt_ent_it_systems_ent_vendors_join" OWNER TO "postgres";


ALTER TABLE "public"."jt_ent_it_systems_ent_vendors_join" ALTER COLUMN "uid" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."jt_ent_it_systems_ent_vendors_join_uid_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."jt_ent_org_units_ent_culture_health_join" (
    "uid" integer NOT NULL,
    "ent_org_units_id" "text" NOT NULL,
    "ent_org_units_year" integer NOT NULL,
    "ent_culture_health_id" "text" NOT NULL,
    "ent_culture_health_year" integer NOT NULL
);


ALTER TABLE "public"."jt_ent_org_units_ent_culture_health_join" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."jt_ent_org_units_ent_culture_health_join_uid_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."jt_ent_org_units_ent_culture_health_join_uid_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."jt_ent_org_units_ent_culture_health_join_uid_seq" OWNED BY "public"."jt_ent_org_units_ent_culture_health_join"."uid";



CREATE TABLE IF NOT EXISTS "public"."jt_ent_org_units_ent_processes_join" (
    "uid" bigint NOT NULL,
    "ent_org_units_id" character varying NOT NULL,
    "ent_org_units_year" integer NOT NULL,
    "ent_processes_id" character varying NOT NULL,
    "ent_processes_year" integer NOT NULL
);


ALTER TABLE "public"."jt_ent_org_units_ent_processes_join" OWNER TO "postgres";


ALTER TABLE "public"."jt_ent_org_units_ent_processes_join" ALTER COLUMN "uid" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."jt_ent_org_units_ent_processes_join_uid_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."jt_ent_processes_ent_it_systems_join" (
    "uid" bigint NOT NULL,
    "ent_processes_id" character varying NOT NULL,
    "ent_processes_year" integer NOT NULL,
    "ent_it_systems_id" character varying NOT NULL,
    "ent_it_systems_year" integer NOT NULL
);


ALTER TABLE "public"."jt_ent_processes_ent_it_systems_join" OWNER TO "postgres";


ALTER TABLE "public"."jt_ent_processes_ent_it_systems_join" ALTER COLUMN "uid" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."jt_ent_processes_ent_it_systems_join_uid_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."jt_ent_projects_ent_change_adoption_join" (
    "uid" integer NOT NULL,
    "ent_projects_id" "text" NOT NULL,
    "ent_projects_year" integer NOT NULL,
    "ent_change_adoption_id" "text" NOT NULL,
    "ent_change_adoption_year" integer NOT NULL
);


ALTER TABLE "public"."jt_ent_projects_ent_change_adoption_join" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."jt_ent_projects_ent_change_adoption_join_uid_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."jt_ent_projects_ent_change_adoption_join_uid_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."jt_ent_projects_ent_change_adoption_join_uid_seq" OWNED BY "public"."jt_ent_projects_ent_change_adoption_join"."uid";



CREATE TABLE IF NOT EXISTS "public"."jt_ent_projects_ent_it_systems_join" (
    "ent_projects_id" character varying NOT NULL,
    "ent_projects_year" integer NOT NULL,
    "ent_it_systems_id" character varying NOT NULL,
    "ent_it_systems_year" integer NOT NULL,
    "uid" bigint NOT NULL
);


ALTER TABLE "public"."jt_ent_projects_ent_it_systems_join" OWNER TO "postgres";


ALTER TABLE "public"."jt_ent_projects_ent_it_systems_join" ALTER COLUMN "uid" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."jt_ent_projects_ent_it_systems_join_uid_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."jt_ent_projects_ent_org_units_join" (
    "uid" bigint NOT NULL,
    "ent_projects_id" character varying NOT NULL,
    "ent_projects_year" integer NOT NULL,
    "ent_org_units_id" character varying NOT NULL,
    "ent_org_units_year" integer NOT NULL,
    "relationship_type" character varying
);


ALTER TABLE "public"."jt_ent_projects_ent_org_units_join" OWNER TO "postgres";


ALTER TABLE "public"."jt_ent_projects_ent_org_units_join" ALTER COLUMN "uid" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."jt_ent_projects_ent_org_units_join_uid_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."jt_ent_projects_ent_processes_join" (
    "ent_projects_id" character varying NOT NULL,
    "ent_projects_year" integer NOT NULL,
    "ent_processes_id" character varying NOT NULL,
    "ent_processes_year" integer NOT NULL,
    "uid" bigint NOT NULL
);


ALTER TABLE "public"."jt_ent_projects_ent_processes_join" OWNER TO "postgres";


ALTER TABLE "public"."jt_ent_projects_ent_processes_join" ALTER COLUMN "uid" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."jt_ent_projects_ent_processes_join_uid_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."jt_ent_risks_sec_performance_join" (
    "ent_risks_id" character varying NOT NULL,
    "ent_risks_year" integer NOT NULL,
    "sec_performance_id" character varying NOT NULL,
    "sec_performance_year" integer NOT NULL,
    "uid" bigint NOT NULL
);


ALTER TABLE "public"."jt_ent_risks_sec_performance_join" OWNER TO "postgres";


ALTER TABLE "public"."jt_ent_risks_sec_performance_join" ALTER COLUMN "uid" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."jt_ent_risks_sec_performance_join_uid_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."jt_ent_risks_sec_policy_tools_join" (
    "ent_risks_id" character varying(10),
    "ent_risks_year" integer,
    "sec_policy_tools_id" character varying(10),
    "sec_policy_tools_year" integer,
    "uid" bigint NOT NULL
);


ALTER TABLE "public"."jt_ent_risks_sec_policy_tools_join" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."jt_ent_risks_sec_policy_tools_join_uid_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."jt_ent_risks_sec_policy_tools_join_uid_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."jt_ent_risks_sec_policy_tools_join_uid_seq" OWNED BY "public"."jt_ent_risks_sec_policy_tools_join"."uid";



CREATE TABLE IF NOT EXISTS "public"."jt_sec_admin_records_sec_businesses_join" (
    "uid" bigint NOT NULL,
    "sec_admin_records_id" character varying NOT NULL,
    "sec_admin_records_year" integer NOT NULL,
    "sec_businesses_id" character varying NOT NULL,
    "sec_businesses_year" integer NOT NULL
);


ALTER TABLE "public"."jt_sec_admin_records_sec_businesses_join" OWNER TO "postgres";


ALTER TABLE "public"."jt_sec_admin_records_sec_businesses_join" ALTER COLUMN "uid" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."jt_sec_admin_records_sec_businesses_join_uid_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."jt_sec_admin_records_sec_citizens_join" (
    "uid" bigint NOT NULL,
    "sec_admin_records_id" character varying NOT NULL,
    "sec_admin_records_year" integer NOT NULL,
    "sec_citizens_id" character varying NOT NULL,
    "sec_citizens_year" integer NOT NULL
);


ALTER TABLE "public"."jt_sec_admin_records_sec_citizens_join" OWNER TO "postgres";


ALTER TABLE "public"."jt_sec_admin_records_sec_citizens_join" ALTER COLUMN "uid" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."jt_sec_admin_records_sec_citizens_join_uid_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."jt_sec_admin_records_sec_gov_entities_join" (
    "uid" bigint NOT NULL,
    "sec_admin_records_id" character varying NOT NULL,
    "sec_admin_records_year" integer NOT NULL,
    "sec_gov_entities_id" character varying NOT NULL,
    "sec_gov_entities_year" integer NOT NULL
);


ALTER TABLE "public"."jt_sec_admin_records_sec_gov_entities_join" OWNER TO "postgres";


ALTER TABLE "public"."jt_sec_admin_records_sec_gov_entities_join" ALTER COLUMN "uid" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."jt_sec_admin_records_sec_gov_entities_join_uid_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."jt_sec_businesses_sec_data_transactions_join" (
    "sec_businesses_id" character varying(10),
    "sec_businesses_year" integer,
    "sec_data_transactions_id" character varying(10),
    "sec_data_transactions_year" integer,
    "uid" bigint NOT NULL
);


ALTER TABLE "public"."jt_sec_businesses_sec_data_transactions_join" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."jt_sec_businesses_sec_data_transactions_join_uid_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."jt_sec_businesses_sec_data_transactions_join_uid_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."jt_sec_businesses_sec_data_transactions_join_uid_seq" OWNED BY "public"."jt_sec_businesses_sec_data_transactions_join"."uid";



CREATE TABLE IF NOT EXISTS "public"."jt_sec_citizens_sec_data_transactions_join" (
    "sec_citizens_id" character varying(10),
    "sec_citizens_year" integer,
    "sec_data_transactions_id" character varying(10),
    "sec_data_transactions_year" integer,
    "uid" bigint NOT NULL
);


ALTER TABLE "public"."jt_sec_citizens_sec_data_transactions_join" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."jt_sec_citizens_sec_data_transactions_join_uid_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."jt_sec_citizens_sec_data_transactions_join_uid_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."jt_sec_citizens_sec_data_transactions_join_uid_seq" OWNED BY "public"."jt_sec_citizens_sec_data_transactions_join"."uid";



CREATE TABLE IF NOT EXISTS "public"."jt_sec_data_transactions_sec_performance_join" (
    "sec_data_transactions_id" character varying NOT NULL,
    "sec_data_transactions_year" integer NOT NULL,
    "sec_performance_id" character varying NOT NULL,
    "sec_performance_year" integer NOT NULL,
    "uid" bigint NOT NULL
);


ALTER TABLE "public"."jt_sec_data_transactions_sec_performance_join" OWNER TO "postgres";


ALTER TABLE "public"."jt_sec_data_transactions_sec_performance_join" ALTER COLUMN "uid" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."jt_sec_data_transactions_sec_performance_join_uid_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."jt_sec_gov_entities_sec_data_transactions_join" (
    "sec_gov_entities_id" character varying(10),
    "sec_gov_entities_year" integer,
    "sec_data_transactions_id" character varying(10),
    "sec_data_transactions_year" integer,
    "uid" bigint NOT NULL
);


ALTER TABLE "public"."jt_sec_gov_entities_sec_data_transactions_join" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."jt_sec_gov_entities_sec_data_transactions_join_uid_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."jt_sec_gov_entities_sec_data_transactions_join_uid_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."jt_sec_gov_entities_sec_data_transactions_join_uid_seq" OWNED BY "public"."jt_sec_gov_entities_sec_data_transactions_join"."uid";



CREATE TABLE IF NOT EXISTS "public"."jt_sec_objectives_sec_performance_join" (
    "uid" integer NOT NULL,
    "sec_objectives_id" "text" NOT NULL,
    "sec_objectives_year" integer NOT NULL,
    "sec_performance_id" "text" NOT NULL,
    "sec_performance_year" integer NOT NULL
);


ALTER TABLE "public"."jt_sec_objectives_sec_performance_join" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."jt_sec_objectives_sec_performance_join_uid_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."jt_sec_objectives_sec_performance_join_uid_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."jt_sec_objectives_sec_performance_join_uid_seq" OWNED BY "public"."jt_sec_objectives_sec_performance_join"."uid";



CREATE TABLE IF NOT EXISTS "public"."jt_sec_objectives_sec_policy_tools_join" (
    "sec_objectives_id" character varying(10),
    "sec_objectives_year" integer,
    "sec_policy_tools_id" character varying(10),
    "sec_policy_tools_year" integer,
    "uid" bigint NOT NULL
);


ALTER TABLE "public"."jt_sec_objectives_sec_policy_tools_join" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."jt_sec_objectives_sec_policy_tools_join_uid_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."jt_sec_objectives_sec_policy_tools_join_uid_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."jt_sec_objectives_sec_policy_tools_join_uid_seq" OWNED BY "public"."jt_sec_objectives_sec_policy_tools_join"."uid";



CREATE TABLE IF NOT EXISTS "public"."jt_sec_performance_ent_capabilities_join" (
    "sec_performance_id" character varying(10),
    "sec_performance_year" integer,
    "ent_capabilities_id" character varying(10),
    "ent_capabilities_year" integer,
    "uid" bigint NOT NULL
);


ALTER TABLE "public"."jt_sec_performance_ent_capabilities_join" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."jt_sec_performance_ent_capabilities_join_uid_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."jt_sec_performance_ent_capabilities_join_uid_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."jt_sec_performance_ent_capabilities_join_uid_seq" OWNED BY "public"."jt_sec_performance_ent_capabilities_join"."uid";



CREATE TABLE IF NOT EXISTS "public"."jt_sec_policy_tools_ent_capabilities_join" (
    "sec_policy_tools_id" character varying(10),
    "sec_policy_tools_year" integer,
    "ent_capabilities_id" character varying(10),
    "ent_capabilities_year" integer,
    "uid" bigint NOT NULL
);


ALTER TABLE "public"."jt_sec_policy_tools_ent_capabilities_join" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."jt_sec_policy_tools_ent_capabilities_join_uid_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."jt_sec_policy_tools_ent_capabilities_join_uid_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."jt_sec_policy_tools_ent_capabilities_join_uid_seq" OWNED BY "public"."jt_sec_policy_tools_ent_capabilities_join"."uid";



CREATE TABLE IF NOT EXISTS "public"."jt_sec_policy_tools_sec_admin_records_join" (
    "sec_policy_tools_id" character varying(10),
    "sec_policy_tools_year" integer,
    "sec_admin_records_id" character varying(10),
    "sec_admin_records_year" integer,
    "uid" bigint NOT NULL
);


ALTER TABLE "public"."jt_sec_policy_tools_sec_admin_records_join" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."jt_sec_policy_tools_sec_admin_records_join_uid_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."jt_sec_policy_tools_sec_admin_records_join_uid_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."jt_sec_policy_tools_sec_admin_records_join_uid_seq" OWNED BY "public"."jt_sec_policy_tools_sec_admin_records_join"."uid";



CREATE TABLE IF NOT EXISTS "public"."kg_edges" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "src_id" "uuid" NOT NULL,
    "rel_type" "text" NOT NULL,
    "dst_id" "uuid" NOT NULL,
    "props" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "valid_from" timestamp with time zone DEFAULT "now"() NOT NULL,
    "valid_to" timestamp with time zone
);


ALTER TABLE "public"."kg_edges" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."kg_nodes" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "type" "text" NOT NULL,
    "props" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "valid_from" timestamp with time zone DEFAULT "now"() NOT NULL,
    "valid_to" timestamp with time zone
);


ALTER TABLE "public"."kg_nodes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."rel_allowlist" (
    "src_type" "text" NOT NULL,
    "rel_name" "text" NOT NULL,
    "dst_type" "text" NOT NULL
);


ALTER TABLE "public"."rel_allowlist" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."sec_admin_records" (
    "id" character varying(10) NOT NULL,
    "year" integer NOT NULL,
    "quarter" integer,
    "record_type" character varying(255),
    "category" character varying(255),
    "dataset_name" character varying(255),
    "data_owner" character varying(255),
    "update_frequency" character varying(50),
    "content" "text",
    "publication_date" "date",
    "author_issuing_authority" character varying(255),
    "version" character varying(50),
    "status" character varying(50),
    "access_level" character varying(50),
    "level" character varying(10) NOT NULL,
    "parent_id" character varying(10),
    "parent_year" integer,
    CONSTRAINT "sec_admin_records_id_check" CHECK ((("id")::"text" ~ '^[1-9][0-9]*\.0$|^[1-9][0-9]*\.[1-9][0-9]*$|^[1-9][0-9]*\.[1-9][0-9]*\.[1-9][0-9]*$'::"text")),
    CONSTRAINT "sec_admin_records_level_check" CHECK ((("level")::"text" = ANY (ARRAY[('L1'::character varying)::"text", ('L2'::character varying)::"text", ('L3'::character varying)::"text"])))
);


ALTER TABLE "public"."sec_admin_records" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."sec_businesses" (
    "id" character varying(10) NOT NULL,
    "year" integer NOT NULL,
    "name" character varying(255),
    "quarter" integer,
    "registered_services" character varying(255),
    "operating_sector" character varying(255),
    "investment_portfolio" "text",
    "compliance_status" character varying(50),
    "investment_goals" "text",
    "associated_projects" "text",
    "level" character varying(10) NOT NULL,
    "parent_id" character varying(10),
    "parent_year" integer,
    CONSTRAINT "sec_businesses_id_check" CHECK ((("id")::"text" ~ '^[1-9][0-9]*\.0$|^[1-9][0-9]*\.[1-9][0-9]*$|^[1-9][0-9]*\.[1-9][0-9]*\.[1-9][0-9]*$'::"text")),
    CONSTRAINT "sec_businesses_level_check" CHECK ((("level")::"text" = ANY (ARRAY[('L1'::character varying)::"text", ('L2'::character varying)::"text", ('L3'::character varying)::"text"])))
);


ALTER TABLE "public"."sec_businesses" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."sec_citizens" (
    "id" character varying(10) NOT NULL,
    "year" integer NOT NULL,
    "quarter" integer,
    "type" character varying(255),
    "region" character varying(255),
    "district" character varying(255),
    "demographic_segment" character varying(255),
    "service_uptake" integer,
    "satisfaction_level" numeric(5,2),
    "demographic_details" character varying(255) NOT NULL,
    "service_history" character varying(255),
    "benefit_entitlements" character varying(255),
    "complaints" integer,
    "level" character varying(10) NOT NULL,
    "parent_id" character varying(10),
    "parent_year" integer,
    CONSTRAINT "sec_citizens_id_check" CHECK ((("id")::"text" ~ '^[1-9][0-9]*\.0$|^[1-9][0-9]*\.[1-9][0-9]*$|^[1-9][0-9]*\.[1-9][0-9]*\.[1-9][0-9]*$'::"text")),
    CONSTRAINT "sec_citizens_level_check" CHECK ((("level")::"text" = ANY (ARRAY[('L1'::character varying)::"text", ('L2'::character varying)::"text", ('L3'::character varying)::"text"])))
);


ALTER TABLE "public"."sec_citizens" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."sec_data_transactions" (
    "id" character varying(10) NOT NULL,
    "year" integer NOT NULL,
    "quarter" integer,
    "domain" character varying(255),
    "department" character varying(255),
    "transaction_type" character varying(255),
    "volume" integer,
    "efficiency_rating" numeric(5,2),
    "volume_quantity" integer,
    "productivity_metrics" character varying(255),
    "it_systems" character varying(255),
    "level" character varying(10) NOT NULL,
    "parent_id" character varying(10),
    "parent_year" integer,
    CONSTRAINT "sec_data_transactions_id_check" CHECK ((("id")::"text" ~ '^[1-9][0-9]*\.0$|^[1-9][0-9]*\.[1-9][0-9]*$|^[1-9][0-9]*\.[1-9][0-9]*\.[1-9][0-9]*$'::"text")),
    CONSTRAINT "sec_data_transactions_level_check" CHECK ((("level")::"text" = ANY (ARRAY[('L1'::character varying)::"text", ('L2'::character varying)::"text", ('L3'::character varying)::"text"])))
);


ALTER TABLE "public"."sec_data_transactions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."sec_gov_entities" (
    "id" character varying(10) NOT NULL,
    "year" integer NOT NULL,
    "name" character varying(255),
    "quarter" integer,
    "type" character varying(255),
    "domain" character varying(255),
    "specific_topic" character varying(255),
    "engagement_level" integer,
    "role_in_partnership" character varying(50),
    "collaboration_agreements" character varying(255),
    "points_of_contact" character varying(255),
    "partnership_status" character varying(50),
    "linked_policies" character varying(255) NOT NULL,
    "level" character varying(10) NOT NULL,
    "parent_id" character varying(10),
    "parent_year" integer,
    CONSTRAINT "sec_gov_entities_id_check" CHECK ((("id")::"text" ~ '^[1-9][0-9]*\.0$|^[1-9][0-9]*\.[1-9][0-9]*$|^[1-9][0-9]*\.[1-9][0-9]*\.[1-9][0-9]*$'::"text")),
    CONSTRAINT "sec_gov_entities_level_check" CHECK ((("level")::"text" = ANY (ARRAY[('L1'::character varying)::"text", ('L2'::character varying)::"text", ('L3'::character varying)::"text"])))
);


ALTER TABLE "public"."sec_gov_entities" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."sec_objectives" (
    "id" character varying(10) NOT NULL,
    "year" integer NOT NULL,
    "name" character varying(255),
    "level" character varying(10) NOT NULL,
    "parent_id" character varying(10),
    "parent_year" integer,
    "baseline" numeric(15,2),
    "target" numeric(15,2),
    "actual" numeric(15,2),
    "indicator_type" character varying(255),
    "frequency" character varying(50),
    "status" character varying(50),
    "rationale" "text",
    "expected_outcomes" "text",
    "timeframe" "date" NOT NULL,
    "priority_level" integer NOT NULL,
    "budget_allocated" numeric(15,2) NOT NULL,
    CONSTRAINT "sec_objectives_id_check" CHECK ((("id")::"text" ~ '^[1-9][0-9]*\.0$|^[1-9][0-9]*\.[1-9][0-9]*$|^[1-9][0-9]*\.[1-9][0-9]*\.[1-9][0-9]*$'::"text")),
    CONSTRAINT "sec_objectives_level_check" CHECK ((("level")::"text" = ANY (ARRAY[('L1'::character varying)::"text", ('L2'::character varying)::"text", ('L3'::character varying)::"text"])))
);


ALTER TABLE "public"."sec_objectives" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."sec_performance" (
    "id" character varying(10) NOT NULL,
    "year" integer NOT NULL,
    "quarter" integer,
    "name" character varying(255),
    "level" character varying(10) NOT NULL,
    "parent_id" character varying(10),
    "parent_year" integer,
    "kpi_type" character varying(255),
    "unit" character varying(255),
    "frequency" character varying(50),
    "target" numeric(15,2),
    "actual" numeric(15,2),
    "status" character varying(50),
    "description" "text",
    "calculation_formula" "text" NOT NULL,
    "measurement_frequency" character varying(50),
    "thresholds" character varying(255),
    "data_source" character varying(255),
    CONSTRAINT "sec_performance_id_check" CHECK ((("id")::"text" ~ '^[1-9][0-9]*\.0$|^[1-9][0-9]*\.[1-9][0-9]*$|^[1-9][0-9]*\.[1-9][0-9]*\.[1-9][0-9]*$'::"text")),
    CONSTRAINT "sec_performance_level_check" CHECK ((("level")::"text" = ANY (ARRAY[('L1'::character varying)::"text", ('L2'::character varying)::"text", ('L3'::character varying)::"text"])))
);


ALTER TABLE "public"."sec_performance" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."sec_policy_tools" (
    "id" character varying(10) NOT NULL,
    "year" integer NOT NULL,
    "name" character varying(255),
    "quarter" integer,
    "level" character varying(10) NOT NULL,
    "parent_id" character varying(10),
    "parent_year" integer,
    "tool_type" character varying(255),
    "impact_target" character varying,
    "delivery_channel" character varying(255),
    "status" character varying(50),
    "cost_of_implementation" numeric(15,2) NOT NULL,
    CONSTRAINT "sec_policy_tools_id_check" CHECK ((("id")::"text" ~ '^[1-9][0-9]*\.0$|^[1-9][0-9]*\.[1-9][0-9]*$|^[1-9][0-9]*\.[1-9][0-9]*\.[1-9][0-9]*$'::"text")),
    CONSTRAINT "sec_policy_tools_level_check" CHECK ((("level")::"text" = ANY (ARRAY[('L1'::character varying)::"text", ('L2'::character varying)::"text", ('L3'::character varying)::"text"])))
);


ALTER TABLE "public"."sec_policy_tools" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."temp_quarterly_dashboard_data" (
    "id" integer NOT NULL,
    "quarter" "text" NOT NULL,
    "dimension_id" "text" NOT NULL,
    "dimension_title" "text" NOT NULL,
    "kpi_description" "text" NOT NULL,
    "kpi_formula" "text" NOT NULL,
    "kpi_base_value" numeric(10,2) NOT NULL,
    "kpi_actual" numeric(10,2) NOT NULL,
    "kpi_planned" numeric(10,2) NOT NULL,
    "kpi_next_target" numeric(10,2) NOT NULL,
    "kpi_final_target" numeric(10,2) NOT NULL,
    "health_score" numeric NOT NULL,
    "health_state" "text" NOT NULL,
    "trend" "text" NOT NULL,
    "projections" "jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."temp_quarterly_dashboard_data" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."temp_quarterly_dashboard_data_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."temp_quarterly_dashboard_data_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."temp_quarterly_dashboard_data_id_seq" OWNED BY "public"."temp_quarterly_dashboard_data"."id";



CREATE TABLE IF NOT EXISTS "public"."vec_chunks" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "node_id" "uuid",
    "text" "text" NOT NULL,
    "embedding" "public"."vector"(1536) NOT NULL,
    "meta" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL
);


ALTER TABLE "public"."vec_chunks" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."view_admin_records_with_node" WITH ("security_invoker"='true') AS
 SELECT "a"."id",
    "a"."year",
    "a"."quarter",
    "a"."record_type",
    "a"."category",
    "a"."dataset_name",
    "a"."data_owner",
    "a"."update_frequency",
    "a"."content",
    "a"."publication_date",
    "a"."author_issuing_authority",
    "a"."version",
    "a"."status",
    "a"."access_level",
    "a"."level",
    "a"."parent_id",
    "a"."parent_year",
    "n"."id" AS "node_id",
    "n"."props" AS "node_props",
    "n"."type" AS "node_type"
   FROM ("public"."sec_admin_records" "a"
     LEFT JOIN "public"."kg_nodes" "n" ON ((("n"."type" = 'AdminRecord'::"text") AND (("n"."props" ->> 'id'::"text") = ("a"."id")::"text") AND (("n"."props" ->> 'year'::"text") = ("a"."year")::"text"))));


ALTER VIEW "public"."view_admin_records_with_node" OWNER TO "postgres";


COMMENT ON VIEW "public"."view_admin_records_with_node" IS 'Security fix applied on 2025-10-20: Removed SECURITY DEFINER. Now uses SECURITY INVOKER (respects caller permissions and RLS policies).';



CREATE OR REPLACE VIEW "public"."view_businesses_with_node" WITH ("security_invoker"='on') AS
 SELECT "b"."id",
    "b"."year",
    "b"."name",
    "b"."quarter",
    "b"."registered_services",
    "b"."operating_sector",
    "b"."investment_portfolio",
    "b"."compliance_status",
    "b"."investment_goals",
    "b"."associated_projects",
    "b"."level",
    "b"."parent_id",
    "b"."parent_year",
    "n"."id" AS "node_id",
    "n"."props" AS "node_props",
    "n"."type" AS "node_type"
   FROM ("public"."sec_businesses" "b"
     LEFT JOIN "public"."kg_nodes" "n" ON ((("n"."type" = 'Business'::"text") AND (("n"."props" ->> 'id'::"text") = ("b"."id")::"text") AND (("n"."props" ->> 'year'::"text") = ("b"."year")::"text"))));


ALTER VIEW "public"."view_businesses_with_node" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."view_capabilities_with_node" WITH ("security_invoker"='true') AS
 SELECT "c"."id",
    "c"."year",
    "c"."name",
    "c"."description",
    "c"."quarter",
    "c"."maturity_level",
    "c"."level",
    "c"."parent_id",
    "c"."parent_year",
    "c"."status",
    "c"."target_maturity_level",
    "c"."type",
    "n"."id" AS "node_id",
    "n"."props" AS "node_props",
    "n"."type" AS "node_type"
   FROM ("public"."ent_capabilities" "c"
     LEFT JOIN "public"."kg_nodes" "n" ON ((("n"."type" = 'Capability'::"text") AND (("n"."props" ->> 'id'::"text") = ("c"."id")::"text"))));


ALTER VIEW "public"."view_capabilities_with_node" OWNER TO "postgres";


COMMENT ON VIEW "public"."view_capabilities_with_node" IS 'Security fix applied on 2025-10-20: Removed SECURITY DEFINER. Now uses SECURITY INVOKER (respects caller permissions and RLS policies).';



CREATE OR REPLACE VIEW "public"."view_change_adoption_with_node" WITH ("security_invoker"='on') AS
 SELECT "c"."id",
    "c"."year",
    "c"."quarter",
    "c"."name",
    "c"."level",
    "c"."parent_id",
    "c"."parent_year",
    "c"."change_type",
    "c"."target_group",
    "c"."status",
    "n"."id" AS "node_id",
    "n"."props" AS "node_props",
    "n"."type" AS "node_type"
   FROM ("public"."ent_change_adoption" "c"
     LEFT JOIN "public"."kg_nodes" "n" ON ((("n"."type" = 'ChangeArchitecture'::"text") AND (("n"."props" ->> 'id'::"text") = ("c"."id")::"text"))));


ALTER VIEW "public"."view_change_adoption_with_node" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."view_citizens_with_node" WITH ("security_invoker"='true') AS
 SELECT "c"."id",
    "c"."year",
    "c"."quarter",
    "c"."type",
    "c"."region",
    "c"."district",
    "c"."demographic_segment",
    "c"."service_uptake",
    "c"."satisfaction_level",
    "c"."demographic_details",
    "c"."service_history",
    "c"."benefit_entitlements",
    "c"."complaints",
    "c"."level",
    "c"."parent_id",
    "c"."parent_year",
    "n"."id" AS "node_id",
    "n"."props" AS "node_props",
    "n"."type" AS "node_type"
   FROM ("public"."sec_citizens" "c"
     LEFT JOIN "public"."kg_nodes" "n" ON ((("n"."type" = 'Citizen'::"text") AND (("n"."props" ->> 'id'::"text") = ("c"."id")::"text") AND (("n"."props" ->> 'year'::"text") = ("c"."year")::"text"))));


ALTER VIEW "public"."view_citizens_with_node" OWNER TO "postgres";


COMMENT ON VIEW "public"."view_citizens_with_node" IS 'Security fix applied on 2025-10-20: Removed SECURITY DEFINER. Now uses SECURITY INVOKER (respects caller permissions and RLS policies).';



CREATE OR REPLACE VIEW "public"."view_culture_health_with_node" WITH ("security_invoker"='true') AS
 SELECT "ch"."id",
    "ch"."year",
    "ch"."quarter",
    "ch"."name",
    "ch"."level",
    "ch"."parent_id",
    "ch"."parent_year",
    "ch"."survey_score",
    "ch"."trend",
    "ch"."target",
    "ch"."participation_rate",
    "ch"."historical_trends",
    "ch"."baseline",
    "n"."id" AS "node_id",
    "n"."props" AS "node_props",
    "n"."type" AS "node_type"
   FROM ("public"."ent_culture_health" "ch"
     LEFT JOIN "public"."kg_nodes" "n" ON ((("n"."type" = 'CultureHealth'::"text") AND (("n"."props" ->> 'id'::"text") = ("ch"."id")::"text"))));


ALTER VIEW "public"."view_culture_health_with_node" OWNER TO "postgres";


COMMENT ON VIEW "public"."view_culture_health_with_node" IS 'Security fix applied on 2025-10-20: Removed SECURITY DEFINER. Now uses SECURITY INVOKER (respects caller permissions and RLS policies).';



CREATE OR REPLACE VIEW "public"."view_data_transactions_with_node" WITH ("security_invoker"='true') AS
 SELECT "d"."id",
    "d"."year",
    "d"."quarter",
    "d"."domain",
    "d"."department",
    "d"."transaction_type",
    "d"."volume",
    "d"."efficiency_rating",
    "d"."volume_quantity",
    "d"."productivity_metrics",
    "d"."it_systems",
    "d"."level",
    "d"."parent_id",
    "d"."parent_year",
    "n"."id" AS "node_id",
    "n"."props" AS "node_props",
    "n"."type" AS "node_type"
   FROM ("public"."sec_data_transactions" "d"
     LEFT JOIN "public"."kg_nodes" "n" ON ((("n"."type" = 'DataTransaction'::"text") AND (("n"."props" ->> 'id'::"text") = ("d"."id")::"text") AND (("n"."props" ->> 'year'::"text") = ("d"."year")::"text"))));


ALTER VIEW "public"."view_data_transactions_with_node" OWNER TO "postgres";


COMMENT ON VIEW "public"."view_data_transactions_with_node" IS 'Security fix applied on 2025-10-20: Removed SECURITY DEFINER. Now uses SECURITY INVOKER (respects caller permissions and RLS policies).';



CREATE OR REPLACE VIEW "public"."view_gov_entities_with_node" WITH ("security_invoker"='on') AS
 SELECT "g"."id",
    "g"."year",
    "g"."name",
    "g"."quarter",
    "g"."type",
    "g"."domain",
    "g"."specific_topic",
    "g"."engagement_level",
    "g"."role_in_partnership",
    "g"."collaboration_agreements",
    "g"."points_of_contact",
    "g"."partnership_status",
    "g"."linked_policies",
    "g"."level",
    "g"."parent_id",
    "g"."parent_year",
    "n"."id" AS "node_id",
    "n"."props" AS "node_props",
    "n"."type" AS "node_type"
   FROM ("public"."sec_gov_entities" "g"
     LEFT JOIN "public"."kg_nodes" "n" ON ((("n"."type" = 'GovEntity'::"text") AND (("n"."props" ->> 'id'::"text") = ("g"."id")::"text") AND (("n"."props" ->> 'year'::"text") = ("g"."year")::"text"))));


ALTER VIEW "public"."view_gov_entities_with_node" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."view_it_systems_with_node" WITH ("security_invoker"='on') AS
 SELECT "s"."id",
    "s"."year",
    "s"."quarter",
    "s"."name",
    "s"."level",
    "s"."parent_id",
    "s"."parent_year",
    "s"."system_type",
    "s"."technology_stack",
    "s"."owner",
    "s"."operational_status",
    "s"."acquisition_cost",
    "s"."number_of_modules",
    "s"."licensing",
    "s"."annual_maintenance_costs",
    "s"."criticality",
    "s"."deployment_date",
    "s"."vendor_supplier",
    "n"."id" AS "node_id",
    "n"."props" AS "node_props",
    "n"."type" AS "node_type"
   FROM ("public"."ent_it_systems" "s"
     LEFT JOIN "public"."kg_nodes" "n" ON ((("n"."type" = 'ITSystem'::"text") AND (("n"."props" ->> 'id'::"text") = ("s"."id")::"text"))));


ALTER VIEW "public"."view_it_systems_with_node" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."view_kg_edges_expanded" WITH ("security_invoker"='on') AS
 SELECT "e"."id" AS "edge_id",
    "e"."rel_type",
    "e"."props" AS "edge_props",
    "e"."valid_from",
    "e"."valid_to",
    "e"."src_id",
    "src_n"."type" AS "src_node_type",
    "src_n"."props" AS "src_props",
    "e"."dst_id",
    "dst_n"."type" AS "dst_node_type",
    "dst_n"."props" AS "dst_props"
   FROM (("public"."kg_edges" "e"
     LEFT JOIN "public"."kg_nodes" "src_n" ON (("src_n"."id" = "e"."src_id")))
     LEFT JOIN "public"."kg_nodes" "dst_n" ON (("dst_n"."id" = "e"."dst_id")));


ALTER VIEW "public"."view_kg_edges_expanded" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."view_kg_nodes_expanded" WITH ("security_invoker"='on') AS
 SELECT "id" AS "node_id",
    "type" AS "node_type",
    "props" AS "node_props",
    ("props" ->> 'id'::"text") AS "props_id",
    ("props" ->> 'year'::"text") AS "props_year",
    ("props" ->> 'name'::"text") AS "props_name",
    "valid_from",
    "valid_to"
   FROM "public"."kg_nodes" "n";


ALTER VIEW "public"."view_kg_nodes_expanded" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."view_objective_policytool_edges" WITH ("security_invoker"='on') AS
 SELECT "e"."id" AS "edge_id",
    "e"."rel_type",
    "o"."id" AS "objective_id",
    "o"."year" AS "objective_year",
    "p"."id" AS "policy_tool_id",
    "p"."year" AS "policy_tool_year",
    "e"."props" AS "edge_props"
   FROM (((("public"."kg_edges" "e"
     JOIN "public"."kg_nodes" "ns" ON (("ns"."id" = "e"."src_id")))
     JOIN "public"."kg_nodes" "nd" ON (("nd"."id" = "e"."dst_id")))
     JOIN "public"."sec_objectives" "o" ON ((("ns"."type" = 'Objective'::"text") AND (("ns"."props" ->> 'id'::"text") = ("o"."id")::"text") AND (("ns"."props" ->> 'year'::"text") = ("o"."year")::"text"))))
     JOIN "public"."sec_policy_tools" "p" ON ((("nd"."type" = 'PolicyTool'::"text") AND (("nd"."props" ->> 'id'::"text") = ("p"."id")::"text") AND (("nd"."props" ->> 'year'::"text") = ("p"."year")::"text"))))
  WHERE ("e"."rel_type" = ANY (ARRAY['governedBy'::"text", 'governedBy_inverse'::"text", 'governed_by'::"text"]));


ALTER VIEW "public"."view_objective_policytool_edges" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."view_org_units_with_node" WITH ("security_invoker"='true') AS
 SELECT "o"."id",
    "o"."year",
    "o"."quarter",
    "o"."name",
    "o"."level",
    "o"."parent_id",
    "o"."parent_year",
    "o"."unit_type",
    "o"."headcount",
    "o"."budget",
    "o"."location",
    "o"."head_of_unit",
    "o"."annual_budget",
    "o"."staff_count",
    "o"."gap",
    "n"."id" AS "node_id",
    "n"."props" AS "node_props",
    "n"."type" AS "node_type"
   FROM ("public"."ent_org_units" "o"
     LEFT JOIN "public"."kg_nodes" "n" ON ((("n"."type" = 'Organization'::"text") AND (("n"."props" ->> 'id'::"text") = ("o"."id")::"text"))));


ALTER VIEW "public"."view_org_units_with_node" OWNER TO "postgres";


COMMENT ON VIEW "public"."view_org_units_with_node" IS 'Security fix applied on 2025-10-20: Removed SECURITY DEFINER. Now uses SECURITY INVOKER (respects caller permissions and RLS policies).';



CREATE OR REPLACE VIEW "public"."view_performance_datatransaction_edges" WITH ("security_invoker"='true') AS
 SELECT "e"."id" AS "edge_id",
    "e"."rel_type",
    "per"."id" AS "performance_id",
    "per"."year" AS "performance_year",
    "dt"."id" AS "data_transaction_id",
    "dt"."year" AS "data_transaction_year",
    "e"."props" AS "edge_props"
   FROM (((("public"."kg_edges" "e"
     JOIN "public"."kg_nodes" "ns" ON (("ns"."id" = "e"."src_id")))
     JOIN "public"."kg_nodes" "nd" ON (("nd"."id" = "e"."dst_id")))
     JOIN "public"."sec_performance" "per" ON ((("ns"."type" = 'Performance'::"text") AND (("ns"."props" ->> 'id'::"text") = ("per"."id")::"text") AND (("ns"."props" ->> 'year'::"text") = ("per"."year")::"text"))))
     JOIN "public"."sec_data_transactions" "dt" ON ((("nd"."type" = 'DataTransaction'::"text") AND (("nd"."props" ->> 'id'::"text") = ("dt"."id")::"text") AND (("nd"."props" ->> 'year'::"text") = ("dt"."year")::"text"))))
  WHERE ("e"."rel_type" = 'measures'::"text");


ALTER VIEW "public"."view_performance_datatransaction_edges" OWNER TO "postgres";


COMMENT ON VIEW "public"."view_performance_datatransaction_edges" IS 'Security fix applied on 2025-10-20: Removed SECURITY DEFINER. Now uses SECURITY INVOKER (respects caller permissions and RLS policies).';



CREATE OR REPLACE VIEW "public"."view_processes_with_node" WITH ("security_invoker"='true') AS
 SELECT "p"."id",
    "p"."year",
    "p"."quarter",
    "p"."name",
    "p"."level",
    "p"."parent_id",
    "p"."parent_year",
    "p"."process_type",
    "p"."maturity_level",
    "p"."automated",
    "p"."automation_due",
    "p"."health_status",
    "p"."stage",
    "p"."description",
    "p"."inputs",
    "p"."outputs",
    "n"."id" AS "node_id",
    "n"."props" AS "node_props",
    "n"."type" AS "node_type"
   FROM ("public"."ent_processes" "p"
     LEFT JOIN "public"."kg_nodes" "n" ON ((("n"."type" = 'Process'::"text") AND (("n"."props" ->> 'id'::"text") = ("p"."id")::"text"))));


ALTER VIEW "public"."view_processes_with_node" OWNER TO "postgres";


COMMENT ON VIEW "public"."view_processes_with_node" IS 'Security fix applied on 2025-10-20: Removed SECURITY DEFINER. Now uses SECURITY INVOKER (respects caller permissions and RLS policies).';



CREATE OR REPLACE VIEW "public"."view_projects_with_node" WITH ("security_invoker"='true') AS
 SELECT "p"."id",
    "p"."year",
    "p"."quarter",
    "p"."name",
    "p"."level",
    "p"."parent_id",
    "p"."parent_year",
    "p"."start_date",
    "p"."end_date",
    "p"."status",
    "p"."budget",
    "p"."progress_percentage",
    "n"."id" AS "node_id",
    "n"."props" AS "node_props",
    "n"."type" AS "node_type"
   FROM ("public"."ent_projects" "p"
     LEFT JOIN "public"."kg_nodes" "n" ON ((("n"."type" = 'ProjectOutput'::"text") AND (("n"."props" ->> 'id'::"text") = ("p"."id")::"text"))));


ALTER VIEW "public"."view_projects_with_node" OWNER TO "postgres";


COMMENT ON VIEW "public"."view_projects_with_node" IS 'Security fix applied on 2025-10-20: Removed SECURITY DEFINER. Now uses SECURITY INVOKER (respects caller permissions and RLS policies).';



CREATE OR REPLACE VIEW "public"."view_risks_with_node" WITH ("security_invoker"='true') AS
 SELECT "r"."id",
    "r"."year",
    "r"."quarter",
    "r"."name",
    "r"."level",
    "r"."parent_id",
    "r"."parent_year",
    "r"."risk_category",
    "r"."project_outputs_risk",
    "r"."role_gaps_risk",
    "r"."it_systems_risk",
    "r"."project_outputs_persistence",
    "r"."role_gaps_persistence",
    "r"."it_systems_persistence",
    "r"."project_outputs_delay_days",
    "r"."role_gaps_delay_days",
    "r"."it_systems_delay_days",
    "r"."likelihood_of_delay",
    "r"."delay_days",
    "r"."risk_score",
    "r"."people_score",
    "r"."process_score",
    "r"."tools_score",
    "r"."operational_health_score",
    "r"."identified_date",
    "r"."last_review_date",
    "r"."next_review_date",
    "r"."risk_status",
    "r"."closure_date",
    "r"."risk_owner",
    "r"."risk_reviewer",
    "r"."affecting_policy_tools_or_performance",
    "r"."policy_tools_associated",
    "r"."performance_target_associated",
    "r"."mitigation_strategy",
    "r"."risk_description",
    "r"."kpi",
    "r"."threshold_red",
    "r"."threshold_amber",
    "r"."threshold_green",
    "r"."external_factors",
    "r"."dependencies",
    "n"."id" AS "node_id",
    "n"."props" AS "node_props",
    "n"."type" AS "node_type"
   FROM ("public"."ent_risks" "r"
     LEFT JOIN "public"."kg_nodes" "n" ON ((("n"."type" = 'Risk'::"text") AND (("n"."props" ->> 'id'::"text") = ("r"."id")::"text"))));


ALTER VIEW "public"."view_risks_with_node" OWNER TO "postgres";


COMMENT ON VIEW "public"."view_risks_with_node" IS 'Security fix applied on 2025-10-20: Removed SECURITY DEFINER. Now uses SECURITY INVOKER (respects caller permissions and RLS policies).';



CREATE OR REPLACE VIEW "public"."view_sec_objectives_with_node" WITH ("security_invoker"='true') AS
 SELECT "o"."id",
    "o"."year",
    "o"."name",
    "o"."level",
    "o"."parent_id",
    "o"."parent_year",
    "o"."baseline",
    "o"."target",
    "o"."actual",
    "o"."indicator_type",
    "o"."frequency",
    "o"."status",
    "o"."rationale",
    "o"."expected_outcomes",
    "o"."timeframe",
    "o"."priority_level",
    "o"."budget_allocated",
    "n"."id" AS "node_id",
    "n"."props" AS "node_props",
    "n"."type" AS "node_type"
   FROM ("public"."sec_objectives" "o"
     LEFT JOIN "public"."kg_nodes" "n" ON ((("n"."type" = 'Objective'::"text") AND (("n"."props" ->> 'id'::"text") = ("o"."id")::"text") AND (("n"."props" ->> 'year'::"text") = ("o"."year")::"text"))));


ALTER VIEW "public"."view_sec_objectives_with_node" OWNER TO "postgres";


COMMENT ON VIEW "public"."view_sec_objectives_with_node" IS 'Security fix applied on 2025-10-20: Removed SECURITY DEFINER. Now uses SECURITY INVOKER (respects caller permissions and RLS policies).';



CREATE OR REPLACE VIEW "public"."view_sec_performance_with_node" WITH ("security_invoker"='on') AS
 SELECT "s"."id",
    "s"."year",
    "s"."quarter",
    "s"."name",
    "s"."level",
    "s"."parent_id",
    "s"."parent_year",
    "s"."kpi_type",
    "s"."unit",
    "s"."frequency",
    "s"."target",
    "s"."actual",
    "s"."status",
    "s"."description",
    "s"."calculation_formula",
    "s"."measurement_frequency",
    "s"."thresholds",
    "s"."data_source",
    "n"."id" AS "node_id",
    "n"."props" AS "node_props",
    "n"."type" AS "node_type"
   FROM ("public"."sec_performance" "s"
     LEFT JOIN "public"."kg_nodes" "n" ON ((("n"."type" = 'Performance'::"text") AND (("n"."props" ->> 'id'::"text") = ("s"."id")::"text") AND (("n"."props" ->> 'year'::"text") = ("s"."year")::"text"))));


ALTER VIEW "public"."view_sec_performance_with_node" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."view_sec_policy_tools_with_node" WITH ("security_invoker"='true') AS
 SELECT "p"."id",
    "p"."year",
    "p"."name",
    "p"."quarter",
    "p"."level",
    "p"."parent_id",
    "p"."parent_year",
    "p"."tool_type",
    "p"."impact_target",
    "p"."delivery_channel",
    "p"."status",
    "p"."cost_of_implementation",
    "n"."id" AS "node_id",
    "n"."props" AS "node_props",
    "n"."type" AS "node_type"
   FROM ("public"."sec_policy_tools" "p"
     LEFT JOIN "public"."kg_nodes" "n" ON ((("n"."type" = 'PolicyTool'::"text") AND (("n"."props" ->> 'id'::"text") = ("p"."id")::"text") AND (("n"."props" ->> 'year'::"text") = ("p"."year")::"text"))));


ALTER VIEW "public"."view_sec_policy_tools_with_node" OWNER TO "postgres";


COMMENT ON VIEW "public"."view_sec_policy_tools_with_node" IS 'Security fix applied on 2025-10-20: Removed SECURITY DEFINER. Now uses SECURITY INVOKER (respects caller permissions and RLS policies).';



CREATE OR REPLACE VIEW "public"."view_vendors_with_node" WITH ("security_invoker"='true') AS
 SELECT "v"."id",
    "v"."year",
    "v"."quarter",
    "v"."name",
    "v"."level",
    "v"."parent_id",
    "v"."parent_year",
    "v"."service_domain",
    "v"."service_detail",
    "v"."contract_value",
    "v"."performance_rating",
    "v"."service_level_agreements",
    "n"."id" AS "node_id",
    "n"."props" AS "node_props",
    "n"."type" AS "node_type"
   FROM ("public"."ent_vendors" "v"
     LEFT JOIN "public"."kg_nodes" "n" ON ((("n"."type" = 'VendorSLA'::"text") AND (("n"."props" ->> 'id'::"text") = ("v"."id")::"text"))));


ALTER VIEW "public"."view_vendors_with_node" OWNER TO "postgres";


COMMENT ON VIEW "public"."view_vendors_with_node" IS 'Security fix applied on 2025-10-20: Removed SECURITY DEFINER. Now uses SECURITY INVOKER (respects caller permissions and RLS policies).';



CREATE TABLE IF NOT EXISTS "staging"."episode_articles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "episode_code" "text" NOT NULL,
    "title" "text" NOT NULL,
    "summary" "text",
    "full_text_md" "text",
    "author" "text" DEFAULT 'DTO GPT'::"text",
    "keywords" "text"[],
    "visuals" "jsonb" DEFAULT '[]'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "staging"."episode_articles" OWNER TO "service_role";


CREATE TABLE IF NOT EXISTS "staging"."episode_impact_reports" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "episode_code" "text" NOT NULL,
    "impact_summary" "text" NOT NULL,
    "design_decisions" "jsonb" DEFAULT '{}'::"jsonb",
    "status" "text" DEFAULT 'draft'::"text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "staging"."episode_impact_reports" OWNER TO "service_role";


CREATE TABLE IF NOT EXISTS "staging"."episode_tracking" (
    "id" integer NOT NULL,
    "chapter_number" integer,
    "chapter_title" "text",
    "episode_number" "text" NOT NULL,
    "episode_title" "text" NOT NULL,
    "status" "text",
    "notes" "text",
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "staging"."episode_tracking" OWNER TO "service_role";


CREATE SEQUENCE IF NOT EXISTS "staging"."episode_tracking_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "staging"."episode_tracking_id_seq" OWNER TO "service_role";


ALTER SEQUENCE "staging"."episode_tracking_id_seq" OWNED BY "staging"."episode_tracking"."id";



CREATE TABLE IF NOT EXISTS "staging"."financial_tracking" (
    "financial_id" "text" NOT NULL,
    "linked_initiative_id" "text",
    "budget" character varying(255),
    "actuals" character varying(255),
    "variance" character varying(255),
    "notes" character varying(255),
    "budget_utilization_rate" real
);


ALTER TABLE "staging"."financial_tracking" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "staging"."it_systems" (
    "system_id" "text" NOT NULL,
    "system_name" character varying(255),
    "used_by_unit_id" "text",
    "system_type" character varying(255),
    "vendor_provider" character varying(255),
    "linked_deliverable_id" "text",
    "linked_process_ids" character varying(255)
);


ALTER TABLE "staging"."it_systems" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "staging"."journeys" (
    "journey_id" "text" NOT NULL,
    "name" character varying(255),
    "type" character varying(255),
    "start_point" character varying(255),
    "end_point" character varying(255)
);


ALTER TABLE "staging"."journeys" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "staging"."knowledge_container_pages" (
    "id" integer NOT NULL,
    "page_number" "text",
    "content" "text",
    "tags" "text" DEFAULT ''::"text",
    "related_episodes" "text" DEFAULT ''::"text"
);


ALTER TABLE "staging"."knowledge_container_pages" OWNER TO "service_role";


CREATE SEQUENCE IF NOT EXISTS "staging"."knowledge_container_pages_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "staging"."knowledge_container_pages_id_seq" OWNER TO "service_role";


ALTER SEQUENCE "staging"."knowledge_container_pages_id_seq" OWNED BY "staging"."knowledge_container_pages"."id";



CREATE TABLE IF NOT EXISTS "staging"."operational_kpis" (
    "kpi_id" character varying(255) NOT NULL,
    "kpi_name" character varying(255),
    "kpi_type" character varying(255),
    "owner_unit" character varying(255),
    "target_2025" character varying(255),
    "formula" character varying(255),
    "unit" character varying(255),
    "primary_process_id" character varying(255),
    "linked_strategic_kpi_id" "text",
    "description" character varying(255),
    "additional_description" character varying(255)
);


ALTER TABLE "staging"."operational_kpis" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "staging"."org_structure" (
    "unit_id" "text" NOT NULL,
    "n" character varying(255),
    "unit_name" character varying(255),
    "parent_unit" character varying(255)
);


ALTER TABLE "staging"."org_structure" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "staging"."policy_entity_assignments" (
    "assignment_id" character varying(255) NOT NULL,
    "policy_tool_id" "text",
    "policy_tool_linked_process_id" "text",
    "unit_id" "text"
);


ALTER TABLE "staging"."policy_entity_assignments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "staging"."policy_tools" (
    "tool_id" "text" NOT NULL,
    "linked_process_id" "text" NOT NULL,
    "tool_name" character varying(255),
    "tool_type" character varying(255),
    "owning_unit_id" "text",
    "description" character varying(255),
    "objective_id" "text"
);


ALTER TABLE "staging"."policy_tools" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "staging"."process_ownership" (
    "ownership_id" character varying(255) NOT NULL,
    "unit_id" "text",
    "process_id" "text"
);


ALTER TABLE "staging"."process_ownership" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "staging"."process_system_link" (
    "link_id" character varying(255) NOT NULL,
    "process_id" "text",
    "system_id" "text"
);


ALTER TABLE "staging"."process_system_link" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "staging"."processes_backup" (
    "process_id" character varying(255) NOT NULL,
    "process_group_id" character varying(255),
    "process_group_name" character varying(255),
    "process_category_id" character varying,
    "process_category_name" character varying(255),
    "process_name_l3" character varying(255),
    "journey_id" "text",
    "strategic_objective_id" "text",
    "tools_used" character varying(255),
    "owner_unit" character varying(255),
    "status" character varying(255),
    "apqc_id" "text",
    "linked_process_metric_ids" character varying(255)
);


ALTER TABLE "staging"."processes_backup" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "staging"."processes_l3" (
    "id" "text" NOT NULL,
    "name_en" "text" NOT NULL,
    "name_ar" "text",
    "description_en" "text",
    "description_ar" "text",
    "l2_id" "text",
    "linked_process_metric_ids" "text",
    "apqc_id" "text",
    "tools_used" "text",
    "owner_unit" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "staging"."processes_l3" OWNER TO "service_role";


CREATE TABLE IF NOT EXISTS "staging"."programs" (
    "program_id" "text" NOT NULL,
    "program_name" character varying(255),
    "owner_unit_id" "text",
    "linked_objective_ids" character varying(255)
);


ALTER TABLE "staging"."programs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "staging"."project_memory" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "topic" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "detail" "text",
    "category" "text",
    "importance" integer DEFAULT 3,
    "created_by" "text",
    CONSTRAINT "project_memory_importance_check" CHECK ((("importance" >= 1) AND ("importance" <= 5)))
);


ALTER TABLE "staging"."project_memory" OWNER TO "noor_admin";


CREATE TABLE IF NOT EXISTS "staging"."resource_allocation" (
    "resource_id" character varying(255) NOT NULL,
    "linked_deliverable_id" character varying(255),
    "resource_type" character varying(255),
    "allocated_amount" character varying(255),
    "actual_used" character varying(255),
    "notes" character varying(255),
    "difference" character varying(255),
    "over_utilized" boolean
);


ALTER TABLE "staging"."resource_allocation" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "staging"."risk_initiative_link" (
    "link_id" character varying(255) NOT NULL,
    "risk_id" "text",
    "initiative_id" real
);


ALTER TABLE "staging"."risk_initiative_link" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "staging"."risk_program_link" (
    "link_id" character varying(255) NOT NULL,
    "risk_id" "text",
    "program_id" "text"
);


ALTER TABLE "staging"."risk_program_link" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "staging"."risk_register" (
    "riskid" character varying(255) NOT NULL,
    "linkedprocessid" character varying(255),
    "riskdescription" character varying(255),
    "probability" character varying(255),
    "impact" character varying(255),
    "mitigationplan" character varying(255),
    "owner" character varying(255)
);


ALTER TABLE "staging"."risk_register" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "staging"."roles" (
    "role_id" "text" NOT NULL,
    "role_name" character varying(255),
    "unit_id" "text",
    "job_description" real,
    "extra_column" character varying(255)
);


ALTER TABLE "staging"."roles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "staging"."service_process_link" (
    "link_id" character varying(255) NOT NULL,
    "policy_tool_id" "text",
    "policy_tool_linked_process_id" "text",
    "process_id" "text"
);


ALTER TABLE "staging"."service_process_link" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "staging"."stakeholder_initiative_link" (
    "link_id" character varying(255) NOT NULL,
    "stakeholder_id" "text",
    "initiative_id" real
);


ALTER TABLE "staging"."stakeholder_initiative_link" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "staging"."stakeholders" (
    "stakeholder_id" "text" NOT NULL,
    "stakeholder_name" character varying(255),
    "stakeholder_type" character varying(255),
    "description" "text"
);


ALTER TABLE "staging"."stakeholders" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "staging"."strategic_kpis" (
    "kpi_id" character varying NOT NULL,
    "kpi_name" character varying(255),
    "kpi_description" character varying(255),
    "owner" character varying(255),
    "owner_unit" character varying(255),
    "baseline" character varying(255),
    "2025_target" character varying(255),
    "type" character varying(255),
    "kpi_formula" character varying(255),
    "process_id" "text",
    "objectives_linked_id" "text"
);


ALTER TABLE "staging"."strategic_kpis" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "staging"."taxonomy" (
    "id" bigint NOT NULL,
    "term" character varying(255),
    "definition" character varying(255),
    "example" character varying(255)
);


ALTER TABLE "staging"."taxonomy" OWNER TO "postgres";


ALTER TABLE "staging"."taxonomy" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "staging"."taxonomy_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "staging"."user_feedback" (
    "feedback_id" character varying(255) NOT NULL,
    "journey_id" character varying(255),
    "user_type" character varying(255),
    "feedback" character varying(255),
    "date" character varying(255),
    "resolution_status" character varying(255)
);


ALTER TABLE "staging"."user_feedback" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "staging"."whitelist_tables" (
    "table_name" "text" NOT NULL
);


ALTER TABLE "staging"."whitelist_tables" OWNER TO "postgres";


ALTER TABLE ONLY "migration_util"."validation_log" ALTER COLUMN "validation_id" SET DEFAULT "nextval"('"migration_util"."validation_log_validation_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."jt_ent_capabilities_ent_it_systems_join" ALTER COLUMN "uid" SET DEFAULT "nextval"('"public"."jt_ent_capabilities_ent_it_systems_join_uid_seq"'::"regclass");



ALTER TABLE ONLY "public"."jt_ent_capabilities_ent_org_units_join" ALTER COLUMN "uid" SET DEFAULT "nextval"('"public"."jt_ent_capabilities_ent_org_units_join_uid_seq"'::"regclass");



ALTER TABLE ONLY "public"."jt_ent_capabilities_ent_processes_join" ALTER COLUMN "uid" SET DEFAULT "nextval"('"public"."jt_ent_capabilities_ent_processes_join_uid_seq"'::"regclass");



ALTER TABLE ONLY "public"."jt_ent_org_units_ent_culture_health_join" ALTER COLUMN "uid" SET DEFAULT "nextval"('"public"."jt_ent_org_units_ent_culture_health_join_uid_seq"'::"regclass");



ALTER TABLE ONLY "public"."jt_ent_projects_ent_change_adoption_join" ALTER COLUMN "uid" SET DEFAULT "nextval"('"public"."jt_ent_projects_ent_change_adoption_join_uid_seq"'::"regclass");



ALTER TABLE ONLY "public"."jt_ent_risks_sec_policy_tools_join" ALTER COLUMN "uid" SET DEFAULT "nextval"('"public"."jt_ent_risks_sec_policy_tools_join_uid_seq"'::"regclass");



ALTER TABLE ONLY "public"."jt_sec_businesses_sec_data_transactions_join" ALTER COLUMN "uid" SET DEFAULT "nextval"('"public"."jt_sec_businesses_sec_data_transactions_join_uid_seq"'::"regclass");



ALTER TABLE ONLY "public"."jt_sec_citizens_sec_data_transactions_join" ALTER COLUMN "uid" SET DEFAULT "nextval"('"public"."jt_sec_citizens_sec_data_transactions_join_uid_seq"'::"regclass");



ALTER TABLE ONLY "public"."jt_sec_gov_entities_sec_data_transactions_join" ALTER COLUMN "uid" SET DEFAULT "nextval"('"public"."jt_sec_gov_entities_sec_data_transactions_join_uid_seq"'::"regclass");



ALTER TABLE ONLY "public"."jt_sec_objectives_sec_performance_join" ALTER COLUMN "uid" SET DEFAULT "nextval"('"public"."jt_sec_objectives_sec_performance_join_uid_seq"'::"regclass");



ALTER TABLE ONLY "public"."jt_sec_objectives_sec_policy_tools_join" ALTER COLUMN "uid" SET DEFAULT "nextval"('"public"."jt_sec_objectives_sec_policy_tools_join_uid_seq"'::"regclass");



ALTER TABLE ONLY "public"."jt_sec_performance_ent_capabilities_join" ALTER COLUMN "uid" SET DEFAULT "nextval"('"public"."jt_sec_performance_ent_capabilities_join_uid_seq"'::"regclass");



ALTER TABLE ONLY "public"."jt_sec_policy_tools_ent_capabilities_join" ALTER COLUMN "uid" SET DEFAULT "nextval"('"public"."jt_sec_policy_tools_ent_capabilities_join_uid_seq"'::"regclass");



ALTER TABLE ONLY "public"."jt_sec_policy_tools_sec_admin_records_join" ALTER COLUMN "uid" SET DEFAULT "nextval"('"public"."jt_sec_policy_tools_sec_admin_records_join_uid_seq"'::"regclass");



ALTER TABLE ONLY "public"."temp_quarterly_dashboard_data" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."temp_quarterly_dashboard_data_id_seq"'::"regclass");



ALTER TABLE ONLY "staging"."episode_tracking" ALTER COLUMN "id" SET DEFAULT "nextval"('"staging"."episode_tracking_id_seq"'::"regclass");



ALTER TABLE ONLY "staging"."knowledge_container_pages" ALTER COLUMN "id" SET DEFAULT "nextval"('"staging"."knowledge_container_pages_id_seq"'::"regclass");



ALTER TABLE ONLY "migration_util"."validation_log"
    ADD CONSTRAINT "validation_log_pkey" PRIMARY KEY ("validation_id");



ALTER TABLE ONLY "public"."documentation_plans"
    ADD CONSTRAINT "documentation_plans_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."dtdl_models"
    ADD CONSTRAINT "dtdl_models_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ent_capabilities"
    ADD CONSTRAINT "ent_capabilities_pkey" PRIMARY KEY ("id", "year");



ALTER TABLE ONLY "public"."ent_change_adoption"
    ADD CONSTRAINT "ent_change_adoption_pkey" PRIMARY KEY ("id", "year");



ALTER TABLE ONLY "public"."ent_culture_health"
    ADD CONSTRAINT "ent_culture_health_pkey" PRIMARY KEY ("id", "year");



ALTER TABLE ONLY "public"."ent_it_systems"
    ADD CONSTRAINT "ent_it_systems_pkey" PRIMARY KEY ("id", "year");



ALTER TABLE ONLY "public"."ent_org_units"
    ADD CONSTRAINT "ent_org_units_pkey" PRIMARY KEY ("id", "year");



ALTER TABLE ONLY "public"."ent_processes"
    ADD CONSTRAINT "ent_processes_pkey" PRIMARY KEY ("id", "year");



ALTER TABLE ONLY "public"."ent_projects"
    ADD CONSTRAINT "ent_projects_pkey" PRIMARY KEY ("id", "year");



ALTER TABLE ONLY "public"."ent_risks"
    ADD CONSTRAINT "ent_risks_pkey" PRIMARY KEY ("id", "year");



ALTER TABLE ONLY "public"."ent_vendors"
    ADD CONSTRAINT "ent_vendors_pkey" PRIMARY KEY ("id", "year");



ALTER TABLE ONLY "public"."forum_comments"
    ADD CONSTRAINT "forum_comments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."jt_ent_capabilities_ent_it_systems_join"
    ADD CONSTRAINT "jt_ent_capabilities_ent_it_systems_join_pkey" PRIMARY KEY ("uid");



ALTER TABLE ONLY "public"."jt_ent_capabilities_ent_org_units_join"
    ADD CONSTRAINT "jt_ent_capabilities_ent_org_units_join_pkey" PRIMARY KEY ("uid");



ALTER TABLE ONLY "public"."jt_ent_capabilities_ent_processes_join"
    ADD CONSTRAINT "jt_ent_capabilities_ent_processes_join_pkey" PRIMARY KEY ("uid");



ALTER TABLE ONLY "public"."jt_ent_it_systems_ent_vendors_join"
    ADD CONSTRAINT "jt_ent_it_systems_ent_vendors_join_pkey" PRIMARY KEY ("uid");



ALTER TABLE ONLY "public"."jt_ent_org_units_ent_culture_health_join"
    ADD CONSTRAINT "jt_ent_org_units_ent_culture_health_join_pkey" PRIMARY KEY ("uid");



ALTER TABLE ONLY "public"."jt_ent_org_units_ent_processes_join"
    ADD CONSTRAINT "jt_ent_org_units_ent_processes_join_pkey" PRIMARY KEY ("uid");



ALTER TABLE ONLY "public"."jt_ent_processes_ent_it_systems_join"
    ADD CONSTRAINT "jt_ent_processes_ent_it_systems_join_pkey" PRIMARY KEY ("uid");



ALTER TABLE ONLY "public"."jt_ent_projects_ent_change_adoption_join"
    ADD CONSTRAINT "jt_ent_projects_ent_change_adoption_join_pkey" PRIMARY KEY ("uid");



ALTER TABLE ONLY "public"."jt_ent_projects_ent_org_units_join"
    ADD CONSTRAINT "jt_ent_projects_ent_org_units_join_pkey" PRIMARY KEY ("uid");



ALTER TABLE ONLY "public"."jt_ent_risks_sec_policy_tools_join"
    ADD CONSTRAINT "jt_ent_risks_sec_policy_tools_join_pkey" PRIMARY KEY ("uid");



ALTER TABLE ONLY "public"."jt_sec_admin_records_sec_businesses_join"
    ADD CONSTRAINT "jt_sec_admin_records_sec_businesses_join_pkey" PRIMARY KEY ("uid");



ALTER TABLE ONLY "public"."jt_sec_admin_records_sec_citizens_join"
    ADD CONSTRAINT "jt_sec_admin_records_sec_citizens_join_pkey" PRIMARY KEY ("uid");



ALTER TABLE ONLY "public"."jt_sec_admin_records_sec_gov_entities_join"
    ADD CONSTRAINT "jt_sec_admin_records_sec_gov_entities_join_pkey" PRIMARY KEY ("uid");



ALTER TABLE ONLY "public"."jt_sec_businesses_sec_data_transactions_join"
    ADD CONSTRAINT "jt_sec_businesses_sec_data_transactions_join_pkey" PRIMARY KEY ("uid");



ALTER TABLE ONLY "public"."jt_sec_citizens_sec_data_transactions_join"
    ADD CONSTRAINT "jt_sec_citizens_sec_data_transactions_join_pkey" PRIMARY KEY ("uid");



ALTER TABLE ONLY "public"."jt_sec_gov_entities_sec_data_transactions_join"
    ADD CONSTRAINT "jt_sec_gov_entities_sec_data_transactions_join_pkey" PRIMARY KEY ("uid");



ALTER TABLE ONLY "public"."jt_sec_objectives_sec_performance_join"
    ADD CONSTRAINT "jt_sec_objectives_sec_performance_join_pkey" PRIMARY KEY ("uid");



ALTER TABLE ONLY "public"."jt_sec_objectives_sec_policy_tools_join"
    ADD CONSTRAINT "jt_sec_objectives_sec_policy_tools_join_pkey" PRIMARY KEY ("uid");



ALTER TABLE ONLY "public"."jt_sec_performance_ent_capabilities_join"
    ADD CONSTRAINT "jt_sec_performance_ent_capabilities_join_pkey" PRIMARY KEY ("uid");



ALTER TABLE ONLY "public"."jt_sec_policy_tools_ent_capabilities_join"
    ADD CONSTRAINT "jt_sec_policy_tools_ent_capabilities_join_pkey" PRIMARY KEY ("uid");



ALTER TABLE ONLY "public"."jt_sec_policy_tools_sec_admin_records_join"
    ADD CONSTRAINT "jt_sec_policy_tools_sec_admin_records_join_pkey" PRIMARY KEY ("uid");



ALTER TABLE ONLY "public"."kg_edges"
    ADD CONSTRAINT "kg_edges_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."kg_nodes"
    ADD CONSTRAINT "kg_nodes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."rel_allowlist"
    ADD CONSTRAINT "rel_allowlist_pkey" PRIMARY KEY ("src_type", "rel_name", "dst_type");



ALTER TABLE ONLY "public"."sec_admin_records"
    ADD CONSTRAINT "sec_admin_records_pkey" PRIMARY KEY ("id", "year");



ALTER TABLE ONLY "public"."sec_businesses"
    ADD CONSTRAINT "sec_businesses_pkey" PRIMARY KEY ("id", "year");



ALTER TABLE ONLY "public"."sec_citizens"
    ADD CONSTRAINT "sec_citizens_pkey" PRIMARY KEY ("id", "year");



ALTER TABLE ONLY "public"."sec_data_transactions"
    ADD CONSTRAINT "sec_data_transactions_pkey" PRIMARY KEY ("id", "year");



ALTER TABLE ONLY "public"."sec_gov_entities"
    ADD CONSTRAINT "sec_gov_entities_pkey" PRIMARY KEY ("id", "year");



ALTER TABLE ONLY "public"."sec_objectives"
    ADD CONSTRAINT "sec_objectives_pkey" PRIMARY KEY ("id", "year");



ALTER TABLE ONLY "public"."sec_performance"
    ADD CONSTRAINT "sec_performance_pkey" PRIMARY KEY ("id", "year");



ALTER TABLE ONLY "public"."sec_policy_tools"
    ADD CONSTRAINT "sec_policy_tools_pkey" PRIMARY KEY ("id", "year");



ALTER TABLE ONLY "public"."temp_quarterly_dashboard_data"
    ADD CONSTRAINT "temp_quarterly_dashboard_data_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."vec_chunks"
    ADD CONSTRAINT "vec_chunks_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "staging"."episode_articles"
    ADD CONSTRAINT "episode_articles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "staging"."episode_impact_reports"
    ADD CONSTRAINT "episode_impact_reports_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "staging"."episode_tracking"
    ADD CONSTRAINT "episode_tracking_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "staging"."financial_tracking"
    ADD CONSTRAINT "financial_tracking_pkey" PRIMARY KEY ("financial_id");



ALTER TABLE ONLY "staging"."it_systems"
    ADD CONSTRAINT "it_systems_pkey" PRIMARY KEY ("system_id");



ALTER TABLE ONLY "staging"."journeys"
    ADD CONSTRAINT "journeys_pkey" PRIMARY KEY ("journey_id");



ALTER TABLE ONLY "staging"."knowledge_container_pages"
    ADD CONSTRAINT "knowledge_container_pages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "staging"."operational_kpis"
    ADD CONSTRAINT "operational_kpis_pkey" PRIMARY KEY ("kpi_id");



ALTER TABLE ONLY "staging"."org_structure"
    ADD CONSTRAINT "org_structure_pkey" PRIMARY KEY ("unit_id");



ALTER TABLE ONLY "staging"."policy_entity_assignments"
    ADD CONSTRAINT "policy_entity_assignments_pkey" PRIMARY KEY ("assignment_id");



ALTER TABLE ONLY "staging"."policy_tools"
    ADD CONSTRAINT "policy_tools_pkey" PRIMARY KEY ("tool_id", "linked_process_id");



ALTER TABLE ONLY "staging"."process_ownership"
    ADD CONSTRAINT "process_ownership_pkey" PRIMARY KEY ("ownership_id");



ALTER TABLE ONLY "staging"."process_system_link"
    ADD CONSTRAINT "process_system_link_pkey" PRIMARY KEY ("link_id");



ALTER TABLE ONLY "staging"."processes_l3"
    ADD CONSTRAINT "processes_l3_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "staging"."processes_backup"
    ADD CONSTRAINT "processes_pkey" PRIMARY KEY ("process_id");



ALTER TABLE ONLY "staging"."programs"
    ADD CONSTRAINT "programs_pkey" PRIMARY KEY ("program_id");



ALTER TABLE ONLY "staging"."project_memory"
    ADD CONSTRAINT "project_memory_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "staging"."resource_allocation"
    ADD CONSTRAINT "resource_allocation_pkey" PRIMARY KEY ("resource_id");



ALTER TABLE ONLY "staging"."risk_initiative_link"
    ADD CONSTRAINT "risk_initiative_link_pkey" PRIMARY KEY ("link_id");



ALTER TABLE ONLY "staging"."risk_program_link"
    ADD CONSTRAINT "risk_program_link_pkey" PRIMARY KEY ("link_id");



ALTER TABLE ONLY "staging"."risk_register"
    ADD CONSTRAINT "risk_register_pkey" PRIMARY KEY ("riskid");



ALTER TABLE ONLY "staging"."roles"
    ADD CONSTRAINT "roles_pkey" PRIMARY KEY ("role_id");



ALTER TABLE ONLY "staging"."service_process_link"
    ADD CONSTRAINT "service_process_link_pkey" PRIMARY KEY ("link_id");



ALTER TABLE ONLY "staging"."stakeholder_initiative_link"
    ADD CONSTRAINT "stakeholder_initiative_link_pkey" PRIMARY KEY ("link_id");



ALTER TABLE ONLY "staging"."stakeholders"
    ADD CONSTRAINT "stakeholders_pkey" PRIMARY KEY ("stakeholder_id");



ALTER TABLE ONLY "staging"."strategic_kpis"
    ADD CONSTRAINT "strategic_kpis_pkey" PRIMARY KEY ("kpi_id");



ALTER TABLE ONLY "staging"."taxonomy"
    ADD CONSTRAINT "taxonomy_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "staging"."user_feedback"
    ADD CONSTRAINT "user_feedback_pkey" PRIMARY KEY ("feedback_id");



ALTER TABLE ONLY "staging"."whitelist_tables"
    ADD CONSTRAINT "whitelist_tables_pkey" PRIMARY KEY ("table_name");



CREATE INDEX "forum_comments_episode_created_idx" ON "public"."forum_comments" USING "btree" ("episode_id", "created_at");



CREATE INDEX "idx_kg_edges_dst" ON "public"."kg_edges" USING "btree" ("dst_id");



CREATE INDEX "idx_kg_edges_rel" ON "public"."kg_edges" USING "btree" ("rel_type");



CREATE INDEX "idx_kg_edges_src" ON "public"."kg_edges" USING "btree" ("src_id");



CREATE INDEX "idx_kg_nodes_props_gin" ON "public"."kg_nodes" USING "gin" ("props");



CREATE INDEX "idx_kg_nodes_type" ON "public"."kg_nodes" USING "btree" ("type");



CREATE INDEX "idx_vec_embedding" ON "public"."vec_chunks" USING "ivfflat" ("embedding" "public"."vector_cosine_ops");



CREATE INDEX "idx_vec_node" ON "public"."vec_chunks" USING "btree" ("node_id");



CREATE OR REPLACE TRIGGER "calculate_likelihood_delay_trigger" BEFORE INSERT OR UPDATE ON "public"."ent_risks" FOR EACH ROW EXECUTE FUNCTION "public"."calculate_likelihood_delay"();



CREATE OR REPLACE TRIGGER "manage_risk_associations_trigger" BEFORE INSERT OR UPDATE ON "public"."ent_risks" FOR EACH ROW EXECUTE FUNCTION "public"."manage_risk_associations"();



CREATE OR REPLACE TRIGGER "set_affecting_field_trigger" BEFORE INSERT OR UPDATE ON "public"."ent_risks" FOR EACH ROW EXECUTE FUNCTION "public"."update_risk_affecting_field"();



CREATE OR REPLACE TRIGGER "set_documentation_plans_updated_at" BEFORE UPDATE ON "public"."documentation_plans" FOR EACH ROW EXECUTE FUNCTION "public"."update_modified_column"();



CREATE OR REPLACE TRIGGER "trg_kg_edges_enforce" BEFORE INSERT OR UPDATE ON "public"."kg_edges" FOR EACH ROW EXECUTE FUNCTION "public"."kg_edges_enforce"();



CREATE OR REPLACE TRIGGER "update_risk_affecting_field_trigger" BEFORE INSERT OR UPDATE ON "public"."ent_risks" FOR EACH ROW EXECUTE FUNCTION "public"."update_risk_affecting_field"();



CREATE OR REPLACE TRIGGER "update_risk_performance_junction_trigger" AFTER INSERT OR UPDATE ON "public"."ent_risks" FOR EACH ROW EXECUTE FUNCTION "public"."update_risk_performance_junction"();



CREATE OR REPLACE TRIGGER "update_risk_policy_tool_junction_trigger" AFTER INSERT OR UPDATE ON "public"."ent_risks" FOR EACH ROW EXECUTE FUNCTION "public"."update_risk_policy_tool_junction"();



CREATE OR REPLACE TRIGGER "update_risk_scores_trigger" BEFORE UPDATE ON "public"."ent_risks" FOR EACH ROW EXECUTE FUNCTION "public"."update_risk_scores"();



CREATE OR REPLACE TRIGGER "trg_update_project_memory" BEFORE UPDATE ON "staging"."project_memory" FOR EACH ROW EXECUTE FUNCTION "public"."update_project_memory_timestamp"();



ALTER TABLE ONLY "public"."ent_capabilities"
    ADD CONSTRAINT "ent_capabilities_parent_id_parent_year_fkey" FOREIGN KEY ("parent_id", "parent_year") REFERENCES "public"."ent_capabilities"("id", "year");



ALTER TABLE ONLY "public"."ent_change_adoption"
    ADD CONSTRAINT "ent_change_adoption_parent_id_parent_year_fkey" FOREIGN KEY ("parent_id", "parent_year") REFERENCES "public"."ent_change_adoption"("id", "year");



ALTER TABLE ONLY "public"."ent_culture_health"
    ADD CONSTRAINT "ent_culture_health_parent_id_parent_year_fkey" FOREIGN KEY ("parent_id", "parent_year") REFERENCES "public"."ent_culture_health"("id", "year");



ALTER TABLE ONLY "public"."ent_it_systems"
    ADD CONSTRAINT "ent_it_systems_parent_id_parent_year_fkey" FOREIGN KEY ("parent_id", "parent_year") REFERENCES "public"."ent_it_systems"("id", "year");



ALTER TABLE ONLY "public"."ent_org_units"
    ADD CONSTRAINT "ent_org_units_parent_id_parent_year_fkey" FOREIGN KEY ("parent_id", "parent_year") REFERENCES "public"."ent_org_units"("id", "year");



ALTER TABLE ONLY "public"."ent_processes"
    ADD CONSTRAINT "ent_processes_parent_id_parent_year_fkey" FOREIGN KEY ("parent_id", "parent_year") REFERENCES "public"."ent_processes"("id", "year");



ALTER TABLE ONLY "public"."ent_projects"
    ADD CONSTRAINT "ent_projects_parent_id_parent_year_fkey" FOREIGN KEY ("parent_id", "parent_year") REFERENCES "public"."ent_projects"("id", "year") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."ent_risks"
    ADD CONSTRAINT "ent_risks_id_year_fkey" FOREIGN KEY ("id", "year") REFERENCES "public"."ent_capabilities"("id", "year");



ALTER TABLE ONLY "public"."ent_risks"
    ADD CONSTRAINT "ent_risks_parent_id_parent_year_fkey" FOREIGN KEY ("parent_id", "parent_year") REFERENCES "public"."ent_risks"("id", "year");



ALTER TABLE ONLY "public"."ent_vendors"
    ADD CONSTRAINT "ent_vendors_parent_id_parent_year_fkey" FOREIGN KEY ("parent_id", "parent_year") REFERENCES "public"."ent_vendors"("id", "year");



ALTER TABLE ONLY "public"."jt_ent_projects_ent_change_adoption_join"
    ADD CONSTRAINT "fk_change" FOREIGN KEY ("ent_change_adoption_id", "ent_change_adoption_year") REFERENCES "public"."ent_change_adoption"("id", "year") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."jt_ent_org_units_ent_culture_health_join"
    ADD CONSTRAINT "fk_culture" FOREIGN KEY ("ent_culture_health_id", "ent_culture_health_year") REFERENCES "public"."ent_culture_health"("id", "year") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."sec_data_transactions"
    ADD CONSTRAINT "fk_data_transactions_performance" FOREIGN KEY ("id", "year") REFERENCES "public"."sec_performance"("id", "year");



ALTER TABLE ONLY "public"."jt_sec_objectives_sec_performance_join"
    ADD CONSTRAINT "fk_objective" FOREIGN KEY ("sec_objectives_id", "sec_objectives_year") REFERENCES "public"."sec_objectives"("id", "year") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."sec_objectives"
    ADD CONSTRAINT "fk_objectives_performance" FOREIGN KEY ("id", "year") REFERENCES "public"."sec_performance"("id", "year");



ALTER TABLE ONLY "public"."jt_ent_org_units_ent_culture_health_join"
    ADD CONSTRAINT "fk_orgunit" FOREIGN KEY ("ent_org_units_id", "ent_org_units_year") REFERENCES "public"."ent_org_units"("id", "year") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."jt_sec_objectives_sec_performance_join"
    ADD CONSTRAINT "fk_performance" FOREIGN KEY ("sec_performance_id", "sec_performance_year") REFERENCES "public"."sec_performance"("id", "year") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."jt_ent_projects_ent_change_adoption_join"
    ADD CONSTRAINT "fk_proj" FOREIGN KEY ("ent_projects_id", "ent_projects_year") REFERENCES "public"."ent_projects"("id", "year") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."forum_comments"
    ADD CONSTRAINT "forum_comments_parent_id_fkey" FOREIGN KEY ("parent_id") REFERENCES "public"."forum_comments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."jt_ent_capabilities_ent_it_systems_join"
    ADD CONSTRAINT "jt_ent_capabilities_ent_it_sy_ent_capabilities_id_ent_capa_fkey" FOREIGN KEY ("ent_capabilities_id", "ent_capabilities_year") REFERENCES "public"."ent_capabilities"("id", "year");



ALTER TABLE ONLY "public"."jt_ent_capabilities_ent_it_systems_join"
    ADD CONSTRAINT "jt_ent_capabilities_ent_it_sy_ent_it_systems_id_ent_it_sys_fkey" FOREIGN KEY ("ent_it_systems_id", "ent_it_systems_year") REFERENCES "public"."ent_it_systems"("id", "year");



ALTER TABLE ONLY "public"."jt_ent_capabilities_ent_org_units_join"
    ADD CONSTRAINT "jt_ent_capabilities_ent_org_u_ent_capabilities_id_ent_capa_fkey" FOREIGN KEY ("ent_capabilities_id", "ent_capabilities_year") REFERENCES "public"."ent_capabilities"("id", "year");



ALTER TABLE ONLY "public"."jt_ent_capabilities_ent_org_units_join"
    ADD CONSTRAINT "jt_ent_capabilities_ent_org_u_ent_org_units_id_ent_org_uni_fkey" FOREIGN KEY ("ent_org_units_id", "ent_org_units_year") REFERENCES "public"."ent_org_units"("id", "year");



ALTER TABLE ONLY "public"."jt_ent_capabilities_ent_processes_join"
    ADD CONSTRAINT "jt_ent_capabilities_ent_proce_ent_capabilities_id_ent_capa_fkey" FOREIGN KEY ("ent_capabilities_id", "ent_capabilities_year") REFERENCES "public"."ent_capabilities"("id", "year");



ALTER TABLE ONLY "public"."jt_ent_capabilities_ent_processes_join"
    ADD CONSTRAINT "jt_ent_capabilities_ent_proce_ent_processes_id_ent_process_fkey" FOREIGN KEY ("ent_processes_id", "ent_processes_year") REFERENCES "public"."ent_processes"("id", "year");



ALTER TABLE ONLY "public"."jt_ent_it_systems_ent_vendors_join"
    ADD CONSTRAINT "jt_ent_it_systems_ent_vendors_ent_it_systems_id_ent_it_sys_fkey" FOREIGN KEY ("ent_it_systems_id", "ent_it_systems_year") REFERENCES "public"."ent_it_systems"("id", "year");



ALTER TABLE ONLY "public"."jt_ent_it_systems_ent_vendors_join"
    ADD CONSTRAINT "jt_ent_it_systems_ent_vendors_ent_vendors_id_ent_vendors_y_fkey" FOREIGN KEY ("ent_vendors_id", "ent_vendors_year") REFERENCES "public"."ent_vendors"("id", "year");



ALTER TABLE ONLY "public"."jt_ent_org_units_ent_processes_join"
    ADD CONSTRAINT "jt_ent_org_units_ent_processe_ent_org_units_id_ent_org_uni_fkey" FOREIGN KEY ("ent_org_units_id", "ent_org_units_year") REFERENCES "public"."ent_org_units"("id", "year");



ALTER TABLE ONLY "public"."jt_ent_org_units_ent_processes_join"
    ADD CONSTRAINT "jt_ent_org_units_ent_processe_ent_processes_id_ent_process_fkey" FOREIGN KEY ("ent_processes_id", "ent_processes_year") REFERENCES "public"."ent_processes"("id", "year");



ALTER TABLE ONLY "public"."jt_ent_processes_ent_it_systems_join"
    ADD CONSTRAINT "jt_ent_processes_ent_it_syste_ent_it_systems_id_ent_it_sys_fkey" FOREIGN KEY ("ent_it_systems_id", "ent_it_systems_year") REFERENCES "public"."ent_it_systems"("id", "year");



ALTER TABLE ONLY "public"."jt_ent_processes_ent_it_systems_join"
    ADD CONSTRAINT "jt_ent_processes_ent_it_syste_ent_processes_id_ent_process_fkey" FOREIGN KEY ("ent_processes_id", "ent_processes_year") REFERENCES "public"."ent_processes"("id", "year");



ALTER TABLE ONLY "public"."jt_ent_projects_ent_org_units_join"
    ADD CONSTRAINT "jt_ent_projects_ent_org_units_ent_org_units_id_ent_org_uni_fkey" FOREIGN KEY ("ent_org_units_id", "ent_org_units_year") REFERENCES "public"."ent_org_units"("id", "year");



ALTER TABLE ONLY "public"."jt_ent_projects_ent_org_units_join"
    ADD CONSTRAINT "jt_ent_projects_ent_org_units_ent_projects_id_ent_projects_fkey" FOREIGN KEY ("ent_projects_id", "ent_projects_year") REFERENCES "public"."ent_projects"("id", "year");



ALTER TABLE ONLY "public"."jt_ent_risks_sec_policy_tools_join"
    ADD CONSTRAINT "jt_ent_risks_sec_policy_tools_sec_policy_tools_id_sec_poli_fkey" FOREIGN KEY ("sec_policy_tools_id", "sec_policy_tools_year") REFERENCES "public"."sec_policy_tools"("id", "year");



ALTER TABLE ONLY "public"."jt_sec_admin_records_sec_businesses_join"
    ADD CONSTRAINT "jt_sec_admin_records_sec_busi_sec_admin_records_id_sec_adm_fkey" FOREIGN KEY ("sec_admin_records_id", "sec_admin_records_year") REFERENCES "public"."sec_admin_records"("id", "year");



ALTER TABLE ONLY "public"."jt_sec_admin_records_sec_businesses_join"
    ADD CONSTRAINT "jt_sec_admin_records_sec_busi_sec_businesses_id_sec_busine_fkey" FOREIGN KEY ("sec_businesses_id", "sec_businesses_year") REFERENCES "public"."sec_businesses"("id", "year");



ALTER TABLE ONLY "public"."jt_sec_admin_records_sec_citizens_join"
    ADD CONSTRAINT "jt_sec_admin_records_sec_citi_sec_admin_records_id_sec_adm_fkey" FOREIGN KEY ("sec_admin_records_id", "sec_admin_records_year") REFERENCES "public"."sec_admin_records"("id", "year");



ALTER TABLE ONLY "public"."jt_sec_admin_records_sec_citizens_join"
    ADD CONSTRAINT "jt_sec_admin_records_sec_citi_sec_citizens_id_sec_citizens_fkey" FOREIGN KEY ("sec_citizens_id", "sec_citizens_year") REFERENCES "public"."sec_citizens"("id", "year");



ALTER TABLE ONLY "public"."jt_sec_admin_records_sec_gov_entities_join"
    ADD CONSTRAINT "jt_sec_admin_records_sec_gov__sec_admin_records_id_sec_adm_fkey" FOREIGN KEY ("sec_admin_records_id", "sec_admin_records_year") REFERENCES "public"."sec_admin_records"("id", "year");



ALTER TABLE ONLY "public"."jt_sec_admin_records_sec_gov_entities_join"
    ADD CONSTRAINT "jt_sec_admin_records_sec_gov__sec_gov_entities_id_sec_gov__fkey" FOREIGN KEY ("sec_gov_entities_id", "sec_gov_entities_year") REFERENCES "public"."sec_gov_entities"("id", "year");



ALTER TABLE ONLY "public"."jt_sec_businesses_sec_data_transactions_join"
    ADD CONSTRAINT "jt_sec_businesses_sec_data_tr_sec_businesses_id_sec_busine_fkey" FOREIGN KEY ("sec_businesses_id", "sec_businesses_year") REFERENCES "public"."sec_businesses"("id", "year");



ALTER TABLE ONLY "public"."jt_sec_businesses_sec_data_transactions_join"
    ADD CONSTRAINT "jt_sec_businesses_sec_data_tr_sec_data_transactions_id_sec_fkey" FOREIGN KEY ("sec_data_transactions_id", "sec_data_transactions_year") REFERENCES "public"."sec_data_transactions"("id", "year");



ALTER TABLE ONLY "public"."jt_sec_citizens_sec_data_transactions_join"
    ADD CONSTRAINT "jt_sec_citizens_sec_data_tran_sec_citizens_id_sec_citizens_fkey" FOREIGN KEY ("sec_citizens_id", "sec_citizens_year") REFERENCES "public"."sec_citizens"("id", "year");



ALTER TABLE ONLY "public"."jt_sec_citizens_sec_data_transactions_join"
    ADD CONSTRAINT "jt_sec_citizens_sec_data_tran_sec_data_transactions_id_sec_fkey" FOREIGN KEY ("sec_data_transactions_id", "sec_data_transactions_year") REFERENCES "public"."sec_data_transactions"("id", "year");



ALTER TABLE ONLY "public"."jt_sec_gov_entities_sec_data_transactions_join"
    ADD CONSTRAINT "jt_sec_gov_entities_sec_data__sec_data_transactions_id_sec_fkey" FOREIGN KEY ("sec_data_transactions_id", "sec_data_transactions_year") REFERENCES "public"."sec_data_transactions"("id", "year");



ALTER TABLE ONLY "public"."jt_sec_gov_entities_sec_data_transactions_join"
    ADD CONSTRAINT "jt_sec_gov_entities_sec_data__sec_gov_entities_id_sec_gov__fkey" FOREIGN KEY ("sec_gov_entities_id", "sec_gov_entities_year") REFERENCES "public"."sec_gov_entities"("id", "year");



ALTER TABLE ONLY "public"."jt_sec_objectives_sec_policy_tools_join"
    ADD CONSTRAINT "jt_sec_objectives_sec_policy__sec_objectives_id_sec_object_fkey" FOREIGN KEY ("sec_objectives_id", "sec_objectives_year") REFERENCES "public"."sec_objectives"("id", "year");



ALTER TABLE ONLY "public"."jt_sec_objectives_sec_policy_tools_join"
    ADD CONSTRAINT "jt_sec_objectives_sec_policy__sec_policy_tools_id_sec_poli_fkey" FOREIGN KEY ("sec_policy_tools_id", "sec_policy_tools_year") REFERENCES "public"."sec_policy_tools"("id", "year");



ALTER TABLE ONLY "public"."jt_sec_performance_ent_capabilities_join"
    ADD CONSTRAINT "jt_sec_performance_ent_capabi_ent_capabilities_id_ent_capa_fkey" FOREIGN KEY ("ent_capabilities_id", "ent_capabilities_year") REFERENCES "public"."ent_capabilities"("id", "year");



ALTER TABLE ONLY "public"."jt_sec_performance_ent_capabilities_join"
    ADD CONSTRAINT "jt_sec_performance_ent_capabi_sec_performance_id_sec_perfo_fkey" FOREIGN KEY ("sec_performance_id", "sec_performance_year") REFERENCES "public"."sec_performance"("id", "year");



ALTER TABLE ONLY "public"."jt_sec_policy_tools_ent_capabilities_join"
    ADD CONSTRAINT "jt_sec_policy_tools_ent_capab_ent_capabilities_id_ent_capa_fkey" FOREIGN KEY ("ent_capabilities_id", "ent_capabilities_year") REFERENCES "public"."ent_capabilities"("id", "year");



ALTER TABLE ONLY "public"."jt_sec_policy_tools_ent_capabilities_join"
    ADD CONSTRAINT "jt_sec_policy_tools_ent_capab_sec_policy_tools_id_sec_poli_fkey" FOREIGN KEY ("sec_policy_tools_id", "sec_policy_tools_year") REFERENCES "public"."sec_policy_tools"("id", "year");



ALTER TABLE ONLY "public"."jt_sec_policy_tools_sec_admin_records_join"
    ADD CONSTRAINT "jt_sec_policy_tools_sec_admin_sec_admin_records_id_sec_adm_fkey" FOREIGN KEY ("sec_admin_records_id", "sec_admin_records_year") REFERENCES "public"."sec_admin_records"("id", "year");



ALTER TABLE ONLY "public"."jt_sec_policy_tools_sec_admin_records_join"
    ADD CONSTRAINT "jt_sec_policy_tools_sec_admin_sec_policy_tools_id_sec_poli_fkey" FOREIGN KEY ("sec_policy_tools_id", "sec_policy_tools_year") REFERENCES "public"."sec_policy_tools"("id", "year");



ALTER TABLE ONLY "public"."kg_edges"
    ADD CONSTRAINT "kg_edges_dst_id_fkey" FOREIGN KEY ("dst_id") REFERENCES "public"."kg_nodes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kg_edges"
    ADD CONSTRAINT "kg_edges_src_id_fkey" FOREIGN KEY ("src_id") REFERENCES "public"."kg_nodes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."sec_admin_records"
    ADD CONSTRAINT "sec_admin_records_parent_id_parent_year_fkey" FOREIGN KEY ("parent_id", "parent_year") REFERENCES "public"."sec_admin_records"("id", "year");



ALTER TABLE ONLY "public"."sec_businesses"
    ADD CONSTRAINT "sec_businesses_parent_id_parent_year_fkey" FOREIGN KEY ("parent_id", "parent_year") REFERENCES "public"."sec_businesses"("id", "year");



ALTER TABLE ONLY "public"."sec_citizens"
    ADD CONSTRAINT "sec_citizens_parent_id_parent_year_fkey" FOREIGN KEY ("parent_id", "parent_year") REFERENCES "public"."sec_citizens"("id", "year");



ALTER TABLE ONLY "public"."sec_data_transactions"
    ADD CONSTRAINT "sec_data_transactions_parent_id_parent_year_fkey" FOREIGN KEY ("parent_id", "parent_year") REFERENCES "public"."sec_data_transactions"("id", "year");



ALTER TABLE ONLY "public"."sec_gov_entities"
    ADD CONSTRAINT "sec_gov_entities_parent_id_parent_year_fkey" FOREIGN KEY ("parent_id", "parent_year") REFERENCES "public"."sec_gov_entities"("id", "year");



ALTER TABLE ONLY "public"."sec_objectives"
    ADD CONSTRAINT "sec_objectives_parent_id_parent_year_fkey" FOREIGN KEY ("parent_id", "parent_year") REFERENCES "public"."sec_objectives"("id", "year");



ALTER TABLE ONLY "public"."sec_performance"
    ADD CONSTRAINT "sec_performance_parent_id_parent_year_fkey" FOREIGN KEY ("parent_id", "parent_year") REFERENCES "public"."sec_performance"("id", "year");



ALTER TABLE ONLY "public"."sec_policy_tools"
    ADD CONSTRAINT "sec_policy_tools_parent_id_parent_year_fkey" FOREIGN KEY ("parent_id", "parent_year") REFERENCES "public"."sec_policy_tools"("id", "year");



ALTER TABLE ONLY "public"."vec_chunks"
    ADD CONSTRAINT "vec_chunks_node_id_fkey" FOREIGN KEY ("node_id") REFERENCES "public"."kg_nodes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "staging"."operational_kpis"
    ADD CONSTRAINT "operational_kpis_linked_strategic_kpi_id_fkey" FOREIGN KEY ("linked_strategic_kpi_id") REFERENCES "staging"."strategic_kpis"("kpi_id");



ALTER TABLE ONLY "staging"."operational_kpis"
    ADD CONSTRAINT "operational_kpis_primary_process_id_fkey" FOREIGN KEY ("primary_process_id") REFERENCES "staging"."processes_backup"("process_id");



ALTER TABLE ONLY "staging"."policy_entity_assignments"
    ADD CONSTRAINT "policy_entity_assignments_policy_tool_id_policy_tool_linke_fkey" FOREIGN KEY ("policy_tool_id", "policy_tool_linked_process_id") REFERENCES "staging"."policy_tools"("tool_id", "linked_process_id");



ALTER TABLE ONLY "staging"."policy_entity_assignments"
    ADD CONSTRAINT "policy_entity_assignments_unit_id_fkey" FOREIGN KEY ("unit_id") REFERENCES "staging"."org_structure"("unit_id");



ALTER TABLE ONLY "staging"."process_ownership"
    ADD CONSTRAINT "process_ownership_process_id_fkey" FOREIGN KEY ("process_id") REFERENCES "staging"."processes_backup"("process_id");



ALTER TABLE ONLY "staging"."process_ownership"
    ADD CONSTRAINT "process_ownership_unit_id_fkey" FOREIGN KEY ("unit_id") REFERENCES "staging"."org_structure"("unit_id");



ALTER TABLE ONLY "staging"."process_system_link"
    ADD CONSTRAINT "process_system_link_process_id_fkey" FOREIGN KEY ("process_id") REFERENCES "staging"."processes_backup"("process_id");



ALTER TABLE ONLY "staging"."process_system_link"
    ADD CONSTRAINT "process_system_link_system_id_fkey" FOREIGN KEY ("system_id") REFERENCES "staging"."it_systems"("system_id");



ALTER TABLE ONLY "staging"."risk_initiative_link"
    ADD CONSTRAINT "risk_initiative_link_risk_id_fkey" FOREIGN KEY ("risk_id") REFERENCES "staging"."risk_register"("riskid");



ALTER TABLE ONLY "staging"."risk_program_link"
    ADD CONSTRAINT "risk_program_link_program_id_fkey" FOREIGN KEY ("program_id") REFERENCES "staging"."programs"("program_id");



ALTER TABLE ONLY "staging"."risk_program_link"
    ADD CONSTRAINT "risk_program_link_risk_id_fkey" FOREIGN KEY ("risk_id") REFERENCES "staging"."risk_register"("riskid");



ALTER TABLE ONLY "staging"."service_process_link"
    ADD CONSTRAINT "service_process_link_policy_tool_id_policy_tool_linked_pro_fkey" FOREIGN KEY ("policy_tool_id", "policy_tool_linked_process_id") REFERENCES "staging"."policy_tools"("tool_id", "linked_process_id");



ALTER TABLE ONLY "staging"."service_process_link"
    ADD CONSTRAINT "service_process_link_process_id_fkey" FOREIGN KEY ("process_id") REFERENCES "staging"."processes_backup"("process_id");



ALTER TABLE ONLY "staging"."stakeholder_initiative_link"
    ADD CONSTRAINT "stakeholder_initiative_link_stakeholder_id_fkey" FOREIGN KEY ("stakeholder_id") REFERENCES "staging"."stakeholders"("stakeholder_id");



ALTER TABLE ONLY "staging"."strategic_kpis"
    ADD CONSTRAINT "strategic_kpis_process_id_fkey" FOREIGN KEY ("process_id") REFERENCES "staging"."processes_backup"("process_id");



CREATE POLICY "Allow anon read access to jt_ent_change_adoption_ent_it_systems" ON "public"."jt_ent_change_adoption_ent_it_systems_join" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Allow anon read access to jt_ent_change_adoption_ent_org_units_" ON "public"."jt_ent_change_adoption_ent_org_units_join" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Allow anon read access to jt_ent_change_adoption_ent_processes_" ON "public"."jt_ent_change_adoption_ent_processes_join" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Allow anon read access to jt_ent_it_systems_ent_vendors_join" ON "public"."jt_ent_it_systems_ent_vendors_join" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Allow anon read access to jt_ent_org_units_ent_processes_join" ON "public"."jt_ent_org_units_ent_processes_join" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Allow anon read access to jt_ent_processes_ent_it_systems_join" ON "public"."jt_ent_processes_ent_it_systems_join" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Allow anon read access to jt_ent_projects_ent_it_systems_join" ON "public"."jt_ent_projects_ent_it_systems_join" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Allow anon read access to jt_ent_projects_ent_org_units_join" ON "public"."jt_ent_projects_ent_org_units_join" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Allow anon read access to jt_ent_projects_ent_processes_join" ON "public"."jt_ent_projects_ent_processes_join" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Allow anon read access to jt_ent_risks_sec_performance_join" ON "public"."jt_ent_risks_sec_performance_join" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Allow anon read access to jt_sec_admin_records_sec_businesses_j" ON "public"."jt_sec_admin_records_sec_businesses_join" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Allow anon read access to jt_sec_admin_records_sec_citizens_joi" ON "public"."jt_sec_admin_records_sec_citizens_join" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Allow anon read access to jt_sec_admin_records_sec_gov_entities" ON "public"."jt_sec_admin_records_sec_gov_entities_join" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Allow anon read access to jt_sec_data_transactions_sec_performa" ON "public"."jt_sec_data_transactions_sec_performance_join" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Allow capability read access based on user role" ON "public"."ent_capabilities" FOR SELECT TO "authenticated" USING (("public"."has_role"('capability_viewer'::"text") OR "public"."has_role"('capability_editor'::"text") OR "public"."has_role"('admin'::"text")));



CREATE POLICY "Allow capability write access based on user role" ON "public"."ent_capabilities" FOR UPDATE TO "authenticated" USING (("public"."has_role"('capability_editor'::"text") OR "public"."has_role"('admin'::"text"))) WITH CHECK (("public"."has_role"('capability_editor'::"text") OR "public"."has_role"('admin'::"text")));



CREATE POLICY "Enable read access for all users" ON "public"."dtdl_models" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."ent_capabilities" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."ent_change_adoption" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."ent_culture_health" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."ent_it_systems" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."ent_org_units" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."ent_projects" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."jt_ent_capabilities_ent_it_systems_join" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."jt_ent_capabilities_ent_org_units_join" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."jt_sec_performance_ent_capabilities_join" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."kg_edges" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."kg_nodes" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."rel_allowlist" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."sec_performance" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."temp_quarterly_dashboard_data" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."vec_chunks" USING (true);



CREATE POLICY "Enable read access for authenticated users" ON "public"."jt_sec_objectives_sec_policy_tools_join" FOR SELECT TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "auth"."uid"()));



CREATE POLICY "Enable read access for authenticated users" ON "public"."jt_sec_policy_tools_ent_capabilities_join" FOR SELECT TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "auth"."uid"()));



CREATE POLICY "Enable read access for authenticated users" ON "public"."sec_objectives" FOR SELECT TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "auth"."uid"()));



CREATE POLICY "Enable read access for authenticated users" ON "public"."sec_policy_tools" FOR SELECT TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "auth"."uid"()));



CREATE POLICY "Policy with security definer functions" ON "public"."ent_risks" TO "anon" USING (true);



CREATE POLICY "Restrict access to budget information" ON "public"."ent_projects" FOR SELECT TO "authenticated" USING (
CASE
    WHEN ("public"."has_role"('finance_viewer'::"text") OR "public"."has_role"('admin'::"text")) THEN true
    ELSE ("budget" IS NULL)
END);



CREATE POLICY "anon_full_access_documentation_plans" ON "public"."documentation_plans" TO "anon" USING (true) WITH CHECK (true);



CREATE POLICY "anon_read_access_jt_ent_org_units_ent_culture_health_join" ON "public"."jt_ent_org_units_ent_culture_health_join" FOR SELECT TO "anon" USING (true);



CREATE POLICY "anon_read_access_jt_ent_projects_ent_change_adoption_join" ON "public"."jt_ent_projects_ent_change_adoption_join" FOR SELECT TO "anon" USING (true);



CREATE POLICY "anon_read_access_jt_sec_objectives_sec_performance_join" ON "public"."jt_sec_objectives_sec_performance_join" FOR SELECT TO "anon" USING (true);



CREATE POLICY "anon_read_ent_capabilities" ON "public"."ent_capabilities" FOR SELECT TO "anon" USING (true);



CREATE POLICY "anon_read_ent_change_adoption" ON "public"."ent_change_adoption" FOR SELECT TO "anon" USING (true);



CREATE POLICY "anon_read_ent_culture_health" ON "public"."ent_culture_health" FOR SELECT TO "anon" USING (true);



CREATE POLICY "anon_read_ent_it_systems" ON "public"."ent_it_systems" FOR SELECT TO "anon" USING (true);



CREATE POLICY "anon_read_ent_org_units" ON "public"."ent_org_units" FOR SELECT TO "anon" USING (true);



CREATE POLICY "anon_read_ent_processes" ON "public"."ent_processes" FOR SELECT TO "anon" USING (true);



CREATE POLICY "anon_read_ent_projects" ON "public"."ent_projects" FOR SELECT TO "anon" USING (true);



CREATE POLICY "anon_read_ent_vendors" ON "public"."ent_vendors" FOR SELECT TO "anon" USING (true);



CREATE POLICY "anon_read_jt_ent_capabilities_ent_it_systems_join" ON "public"."jt_ent_capabilities_ent_it_systems_join" FOR SELECT TO "anon" USING (true);



CREATE POLICY "anon_read_jt_ent_capabilities_ent_org_units_join" ON "public"."jt_ent_capabilities_ent_org_units_join" FOR SELECT TO "anon" USING (true);



CREATE POLICY "anon_read_jt_ent_capabilities_ent_processes_join" ON "public"."jt_ent_capabilities_ent_processes_join" FOR SELECT TO "anon" USING (true);



CREATE POLICY "anon_read_jt_ent_risks_sec_policy_tools_join" ON "public"."jt_ent_risks_sec_policy_tools_join" FOR SELECT TO "anon" USING (true);



CREATE POLICY "anon_read_jt_sec_businesses_sec_data_transactions_join" ON "public"."jt_sec_businesses_sec_data_transactions_join" FOR SELECT TO "anon" USING (true);



CREATE POLICY "anon_read_jt_sec_citizens_sec_data_transactions_join" ON "public"."jt_sec_citizens_sec_data_transactions_join" FOR SELECT TO "anon" USING (true);



CREATE POLICY "anon_read_jt_sec_gov_entities_sec_data_transactions_join" ON "public"."jt_sec_gov_entities_sec_data_transactions_join" FOR SELECT TO "anon" USING (true);



CREATE POLICY "anon_read_jt_sec_objectives_sec_policy_tools_join" ON "public"."jt_sec_objectives_sec_policy_tools_join" FOR SELECT TO "anon" USING (true);



CREATE POLICY "anon_read_jt_sec_performance_ent_capabilities_join" ON "public"."jt_sec_performance_ent_capabilities_join" FOR SELECT TO "anon" USING (true);



CREATE POLICY "anon_read_jt_sec_policy_tools_ent_capabilities_join" ON "public"."jt_sec_policy_tools_ent_capabilities_join" FOR SELECT TO "anon" USING (true);



CREATE POLICY "anon_read_jt_sec_policy_tools_sec_admin_records_join" ON "public"."jt_sec_policy_tools_sec_admin_records_join" FOR SELECT TO "anon" USING (true);



CREATE POLICY "anon_read_sec_admin_records" ON "public"."sec_admin_records" FOR SELECT TO "anon" USING (true);



CREATE POLICY "anon_read_sec_businesses" ON "public"."sec_businesses" FOR SELECT TO "anon" USING (true);



CREATE POLICY "anon_read_sec_citizens" ON "public"."sec_citizens" FOR SELECT TO "anon" USING (true);



CREATE POLICY "anon_read_sec_data_transactions" ON "public"."sec_data_transactions" FOR SELECT TO "anon" USING (true);



CREATE POLICY "anon_read_sec_gov_entities" ON "public"."sec_gov_entities" FOR SELECT TO "anon" USING (true);



CREATE POLICY "anon_read_sec_objectives" ON "public"."sec_objectives" FOR SELECT TO "anon" USING (true);



CREATE POLICY "anon_read_sec_performance" ON "public"."sec_performance" FOR SELECT TO "anon" USING (true);



CREATE POLICY "anon_read_sec_policy_tools" ON "public"."sec_policy_tools" FOR SELECT TO "anon" USING (true);



CREATE POLICY "authenticated_all_access_ent_capabilities" ON "public"."ent_capabilities" TO "authenticated", "anon" USING (true) WITH CHECK (true);



CREATE POLICY "authenticated_all_access_ent_change_adoption" ON "public"."ent_change_adoption" TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "authenticated_all_access_ent_culture_health" ON "public"."ent_culture_health" TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "authenticated_all_access_ent_it_systems" ON "public"."ent_it_systems" TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "authenticated_all_access_ent_org_units" ON "public"."ent_org_units" TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "authenticated_all_access_ent_processes" ON "public"."ent_processes" TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "authenticated_all_access_ent_projects" ON "public"."ent_projects" TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "authenticated_all_access_ent_vendors" ON "public"."ent_vendors" TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "authenticated_all_access_jt_ent_capabilities_ent_it_systems_joi" ON "public"."jt_ent_capabilities_ent_it_systems_join" TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "authenticated_all_access_jt_ent_capabilities_ent_org_units_join" ON "public"."jt_ent_capabilities_ent_org_units_join" TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "authenticated_all_access_jt_ent_capabilities_ent_processes_join" ON "public"."jt_ent_capabilities_ent_processes_join" TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "authenticated_all_access_jt_ent_risks_sec_policy_tools_join" ON "public"."jt_ent_risks_sec_policy_tools_join" TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "authenticated_all_access_jt_sec_businesses_sec_data_transaction" ON "public"."jt_sec_businesses_sec_data_transactions_join" TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "authenticated_all_access_jt_sec_citizens_sec_data_transactions_" ON "public"."jt_sec_citizens_sec_data_transactions_join" TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "authenticated_all_access_jt_sec_gov_entities_sec_data_transacti" ON "public"."jt_sec_gov_entities_sec_data_transactions_join" TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "authenticated_all_access_jt_sec_objectives_sec_policy_tools_joi" ON "public"."jt_sec_objectives_sec_policy_tools_join" TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "authenticated_all_access_jt_sec_performance_ent_capabilities_jo" ON "public"."jt_sec_performance_ent_capabilities_join" TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "authenticated_all_access_jt_sec_policy_tools_ent_capabilities_j" ON "public"."jt_sec_policy_tools_ent_capabilities_join" TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "authenticated_all_access_jt_sec_policy_tools_sec_admin_records_" ON "public"."jt_sec_policy_tools_sec_admin_records_join" TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "authenticated_all_access_sec_admin_records" ON "public"."sec_admin_records" TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "authenticated_all_access_sec_businesses" ON "public"."sec_businesses" TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "authenticated_all_access_sec_citizens" ON "public"."sec_citizens" TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "authenticated_all_access_sec_data_transactions" ON "public"."sec_data_transactions" TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "authenticated_all_access_sec_gov_entities" ON "public"."sec_gov_entities" TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "authenticated_all_access_sec_objectives" ON "public"."sec_objectives" TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "authenticated_all_access_sec_performance" ON "public"."sec_performance" TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "authenticated_all_access_sec_policy_tools" ON "public"."sec_policy_tools" TO "authenticated" USING (true) WITH CHECK (true);



ALTER TABLE "public"."documentation_plans" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."dtdl_models" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."ent_capabilities" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."ent_change_adoption" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."ent_culture_health" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."ent_it_systems" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."ent_org_units" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."ent_processes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."ent_projects" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."ent_risks" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."ent_vendors" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."forum_comments" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "insert_auth" ON "public"."forum_comments" FOR INSERT WITH CHECK (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."jt_ent_capabilities_ent_it_systems_join" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."jt_ent_capabilities_ent_org_units_join" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."jt_ent_capabilities_ent_processes_join" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."jt_ent_change_adoption_ent_it_systems_join" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."jt_ent_change_adoption_ent_org_units_join" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."jt_ent_change_adoption_ent_processes_join" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."jt_ent_it_systems_ent_vendors_join" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."jt_ent_org_units_ent_culture_health_join" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."jt_ent_org_units_ent_processes_join" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."jt_ent_processes_ent_it_systems_join" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."jt_ent_projects_ent_change_adoption_join" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."jt_ent_projects_ent_it_systems_join" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."jt_ent_projects_ent_org_units_join" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."jt_ent_projects_ent_processes_join" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."jt_ent_risks_sec_performance_join" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."jt_ent_risks_sec_policy_tools_join" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."jt_sec_admin_records_sec_businesses_join" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."jt_sec_admin_records_sec_citizens_join" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."jt_sec_admin_records_sec_gov_entities_join" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."jt_sec_businesses_sec_data_transactions_join" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."jt_sec_citizens_sec_data_transactions_join" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."jt_sec_data_transactions_sec_performance_join" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."jt_sec_gov_entities_sec_data_transactions_join" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."jt_sec_objectives_sec_performance_join" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."jt_sec_objectives_sec_policy_tools_join" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."jt_sec_performance_ent_capabilities_join" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."jt_sec_policy_tools_ent_capabilities_join" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."jt_sec_policy_tools_sec_admin_records_join" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."kg_edges" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."kg_nodes" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "read_all" ON "public"."forum_comments" FOR SELECT USING (true);



ALTER TABLE "public"."rel_allowlist" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sec_admin_records" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sec_businesses" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sec_citizens" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sec_data_transactions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sec_gov_entities" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sec_objectives" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sec_performance" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sec_policy_tools" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "service_role_all_access_jt_ent_capabilities_ent_it_systems_join" ON "public"."jt_ent_capabilities_ent_it_systems_join" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_all_access_jt_ent_capabilities_ent_org_units_join" ON "public"."jt_ent_capabilities_ent_org_units_join" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_all_access_jt_ent_capabilities_ent_processes_join" ON "public"."jt_ent_capabilities_ent_processes_join" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_all_access_jt_ent_risks_sec_policy_tools_join" ON "public"."jt_ent_risks_sec_policy_tools_join" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_all_access_jt_sec_businesses_sec_data_transactions" ON "public"."jt_sec_businesses_sec_data_transactions_join" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_all_access_jt_sec_citizens_sec_data_transactions_j" ON "public"."jt_sec_citizens_sec_data_transactions_join" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_all_access_jt_sec_gov_entities_sec_data_transactio" ON "public"."jt_sec_gov_entities_sec_data_transactions_join" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_all_access_jt_sec_objectives_sec_policy_tools_join" ON "public"."jt_sec_objectives_sec_policy_tools_join" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_all_access_jt_sec_performance_ent_capabilities_joi" ON "public"."jt_sec_performance_ent_capabilities_join" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_all_access_jt_sec_policy_tools_ent_capabilities_jo" ON "public"."jt_sec_policy_tools_ent_capabilities_join" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_all_access_jt_sec_policy_tools_sec_admin_records_j" ON "public"."jt_sec_policy_tools_sec_admin_records_join" TO "service_role" USING (true) WITH CHECK (true);



ALTER TABLE "public"."temp_quarterly_dashboard_data" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "update_auth" ON "public"."forum_comments" FOR UPDATE USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."vec_chunks" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "Anon users can select from financial_tracking." ON "staging"."financial_tracking" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Anon users can select from it_systems." ON "staging"."it_systems" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Anon users can select from journeys." ON "staging"."journeys" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Anon users can select from operational_kpis." ON "staging"."operational_kpis" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Anon users can select from org_structure." ON "staging"."org_structure" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Anon users can select from policy_entity_assignments." ON "staging"."policy_entity_assignments" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Anon users can select from policy_tools." ON "staging"."policy_tools" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Anon users can select from process_ownership." ON "staging"."process_ownership" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Anon users can select from process_system_link." ON "staging"."process_system_link" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Anon users can select from processes." ON "staging"."processes_backup" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Anon users can select from programs." ON "staging"."programs" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Anon users can select from resource_allocation." ON "staging"."resource_allocation" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Anon users can select from risk_initiative_link." ON "staging"."risk_initiative_link" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Anon users can select from risk_program_link." ON "staging"."risk_program_link" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Anon users can select from risk_register." ON "staging"."risk_register" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Anon users can select from roles." ON "staging"."roles" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Anon users can select from service_process_link." ON "staging"."service_process_link" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Anon users can select from stakeholder_initiative_link." ON "staging"."stakeholder_initiative_link" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Anon users can select from stakeholders." ON "staging"."stakeholders" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Anon users can select from strategic_kpis." ON "staging"."strategic_kpis" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Anon users can select from taxonomy." ON "staging"."taxonomy" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Anon users can select from user_feedback." ON "staging"."user_feedback" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Anon users can select from whitelist_tables." ON "staging"."whitelist_tables" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Authenticated users can select from financial_tracking" ON "staging"."financial_tracking" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Authenticated users can select from it_systems" ON "staging"."it_systems" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Authenticated users can select from journeys" ON "staging"."journeys" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Authenticated users can select from operational_kpis" ON "staging"."operational_kpis" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Authenticated users can select from org_structure" ON "staging"."org_structure" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Authenticated users can select from policy_entity_assignments" ON "staging"."policy_entity_assignments" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Authenticated users can select from policy_tools" ON "staging"."policy_tools" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Authenticated users can select from programs" ON "staging"."programs" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Authenticated users can select from resource_allocation" ON "staging"."resource_allocation" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Authenticated users can select from risk_register" ON "staging"."risk_register" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Authenticated users can select from stakeholders" ON "staging"."stakeholders" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Authenticated users can select from strategic_kpis" ON "staging"."strategic_kpis" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Authenticated users can select from taxonomy" ON "staging"."taxonomy" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Authenticated users can select from user_feedback" ON "staging"."user_feedback" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Authenticated users can select from whitelist_tables" ON "staging"."whitelist_tables" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Deny All Access" ON "staging"."episode_articles" USING (false);



CREATE POLICY "Deny All Access" ON "staging"."episode_impact_reports" USING (false);



CREATE POLICY "Deny All Access" ON "staging"."episode_tracking" USING (false);



CREATE POLICY "Deny All Access" ON "staging"."financial_tracking" USING (false);



CREATE POLICY "Deny All Access" ON "staging"."it_systems" USING (false);



CREATE POLICY "Deny All Access" ON "staging"."journeys" USING (false);



CREATE POLICY "Deny All Access" ON "staging"."knowledge_container_pages" USING (false);



CREATE POLICY "Deny All Access" ON "staging"."operational_kpis" USING (false);



CREATE POLICY "Deny All Access" ON "staging"."org_structure" USING (false);



CREATE POLICY "Deny All Access" ON "staging"."policy_entity_assignments" USING (false);



CREATE POLICY "Deny All Access" ON "staging"."policy_tools" USING (false);



CREATE POLICY "Deny All Access" ON "staging"."process_ownership" USING (false);



CREATE POLICY "Deny All Access" ON "staging"."process_system_link" USING (false);



CREATE POLICY "Deny All Access" ON "staging"."processes_backup" USING (false);



CREATE POLICY "Deny All Access" ON "staging"."processes_l3" USING (false);



CREATE POLICY "Deny All Access" ON "staging"."programs" USING (false);



CREATE POLICY "Deny All Access" ON "staging"."project_memory" USING (false);



CREATE POLICY "Deny All Access" ON "staging"."resource_allocation" USING (false);



CREATE POLICY "Deny All Access" ON "staging"."risk_initiative_link" USING (false);



CREATE POLICY "Deny All Access" ON "staging"."risk_program_link" USING (false);



CREATE POLICY "Deny All Access" ON "staging"."risk_register" USING (false);



CREATE POLICY "Deny All Access" ON "staging"."roles" USING (false);



CREATE POLICY "Deny All Access" ON "staging"."service_process_link" USING (false);



CREATE POLICY "Deny All Access" ON "staging"."stakeholder_initiative_link" USING (false);



CREATE POLICY "Deny All Access" ON "staging"."stakeholders" USING (false);



CREATE POLICY "Deny All Access" ON "staging"."strategic_kpis" USING (false);



CREATE POLICY "Deny All Access" ON "staging"."taxonomy" USING (false);



CREATE POLICY "Deny All Access" ON "staging"."user_feedback" USING (false);



CREATE POLICY "Deny All Access" ON "staging"."whitelist_tables" USING (false);



CREATE POLICY "Policy with security definer functions" ON "staging"."episode_articles" TO "anon" USING (true);



CREATE POLICY "Policy with security definer functions" ON "staging"."episode_impact_reports" TO "anon" USING (true);



CREATE POLICY "allow_all_access" ON "staging"."knowledge_container_pages" USING (true) WITH CHECK (true);



CREATE POLICY "anon  can select from project_memory" ON "staging"."project_memory" FOR SELECT TO "anon" USING (true);



CREATE POLICY "anon  can update project_memory" ON "staging"."project_memory" FOR UPDATE TO "anon" USING (true) WITH CHECK (true);



CREATE POLICY "anon can delete from project_memory" ON "staging"."project_memory" FOR DELETE TO "anon" USING (true);



CREATE POLICY "anon can insert into project_memory" ON "staging"."project_memory" FOR INSERT TO "anon" WITH CHECK (true);



ALTER TABLE "staging"."episode_articles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "staging"."episode_impact_reports" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "staging"."episode_tracking" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "episode_tracking_full_access" ON "staging"."episode_tracking" USING (true) WITH CHECK (true);



ALTER TABLE "staging"."financial_tracking" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "staging"."it_systems" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "staging"."journeys" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "staging"."knowledge_container_pages" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "noor_admin can delete from financial_tracking" ON "staging"."financial_tracking" FOR DELETE TO "noor_admin" USING (true);



CREATE POLICY "noor_admin can delete from it_systems" ON "staging"."it_systems" FOR DELETE TO "noor_admin" USING (true);



CREATE POLICY "noor_admin can delete from journeys" ON "staging"."journeys" FOR DELETE TO "noor_admin" USING (true);



CREATE POLICY "noor_admin can delete from operational_kpis" ON "staging"."operational_kpis" FOR DELETE TO "noor_admin" USING (true);



CREATE POLICY "noor_admin can delete from org_structure" ON "staging"."org_structure" FOR DELETE TO "noor_admin" USING (true);



CREATE POLICY "noor_admin can delete from policy_entity_assignments" ON "staging"."policy_entity_assignments" FOR DELETE TO "noor_admin" USING (true);



CREATE POLICY "noor_admin can delete from policy_tools" ON "staging"."policy_tools" FOR DELETE TO "noor_admin" USING (true);



CREATE POLICY "noor_admin can delete from process_ownership" ON "staging"."process_ownership" FOR DELETE TO "noor_admin" USING (true);



CREATE POLICY "noor_admin can delete from process_system_link" ON "staging"."process_system_link" FOR DELETE TO "noor_admin" USING (true);



CREATE POLICY "noor_admin can delete from processes_backup" ON "staging"."processes_backup" FOR DELETE TO "noor_admin" USING (true);



CREATE POLICY "noor_admin can delete from programs" ON "staging"."programs" FOR DELETE TO "noor_admin" USING (true);



CREATE POLICY "noor_admin can delete from resource_allocation" ON "staging"."resource_allocation" FOR DELETE TO "noor_admin" USING (true);



CREATE POLICY "noor_admin can delete from risk_initiative_link" ON "staging"."risk_initiative_link" FOR DELETE TO "noor_admin" USING (true);



CREATE POLICY "noor_admin can delete from risk_program_link" ON "staging"."risk_program_link" FOR DELETE TO "noor_admin" USING (true);



CREATE POLICY "noor_admin can delete from risk_register" ON "staging"."risk_register" FOR DELETE TO "noor_admin" USING (true);



CREATE POLICY "noor_admin can delete from roles" ON "staging"."roles" FOR DELETE TO "noor_admin" USING (true);



CREATE POLICY "noor_admin can delete from service_process_link" ON "staging"."service_process_link" FOR DELETE TO "noor_admin" USING (true);



CREATE POLICY "noor_admin can delete from stakeholder_initiative_link" ON "staging"."stakeholder_initiative_link" FOR DELETE TO "noor_admin" USING (true);



CREATE POLICY "noor_admin can delete from stakeholders" ON "staging"."stakeholders" FOR DELETE TO "noor_admin" USING (true);



CREATE POLICY "noor_admin can delete from strategic_kpis" ON "staging"."strategic_kpis" FOR DELETE TO "noor_admin" USING (true);



CREATE POLICY "noor_admin can delete from taxonomy" ON "staging"."taxonomy" FOR DELETE TO "noor_admin" USING (true);



CREATE POLICY "noor_admin can delete from user_feedback" ON "staging"."user_feedback" FOR DELETE TO "noor_admin" USING (true);



CREATE POLICY "noor_admin can delete from whitelist_tables" ON "staging"."whitelist_tables" FOR DELETE TO "noor_admin" USING (true);



CREATE POLICY "noor_admin can insert into financial_tracking" ON "staging"."financial_tracking" FOR INSERT TO "noor_admin" WITH CHECK (true);



CREATE POLICY "noor_admin can insert into it_systems" ON "staging"."it_systems" FOR INSERT TO "noor_admin" WITH CHECK (true);



CREATE POLICY "noor_admin can insert into journeys" ON "staging"."journeys" FOR INSERT TO "noor_admin" WITH CHECK (true);



CREATE POLICY "noor_admin can insert into operational_kpis" ON "staging"."operational_kpis" FOR INSERT TO "noor_admin" WITH CHECK (true);



CREATE POLICY "noor_admin can insert into org_structure" ON "staging"."org_structure" FOR INSERT TO "noor_admin" WITH CHECK (true);



CREATE POLICY "noor_admin can insert into policy_entity_assignments" ON "staging"."policy_entity_assignments" FOR INSERT TO "noor_admin" WITH CHECK (true);



CREATE POLICY "noor_admin can insert into policy_tools" ON "staging"."policy_tools" FOR INSERT TO "noor_admin" WITH CHECK (true);



CREATE POLICY "noor_admin can insert into process_ownership" ON "staging"."process_ownership" FOR INSERT TO "noor_admin" WITH CHECK (true);



CREATE POLICY "noor_admin can insert into process_system_link" ON "staging"."process_system_link" FOR INSERT TO "noor_admin" WITH CHECK (true);



CREATE POLICY "noor_admin can insert into processes_backup" ON "staging"."processes_backup" FOR INSERT TO "noor_admin" WITH CHECK (true);



CREATE POLICY "noor_admin can insert into programs" ON "staging"."programs" FOR INSERT TO "noor_admin" WITH CHECK (true);



CREATE POLICY "noor_admin can insert into resource_allocation" ON "staging"."resource_allocation" FOR INSERT TO "noor_admin" WITH CHECK (true);



CREATE POLICY "noor_admin can insert into risk_initiative_link" ON "staging"."risk_initiative_link" FOR INSERT TO "noor_admin" WITH CHECK (true);



CREATE POLICY "noor_admin can insert into risk_program_link" ON "staging"."risk_program_link" FOR INSERT TO "noor_admin" WITH CHECK (true);



CREATE POLICY "noor_admin can insert into risk_register" ON "staging"."risk_register" FOR INSERT TO "noor_admin" WITH CHECK (true);



CREATE POLICY "noor_admin can insert into roles" ON "staging"."roles" FOR INSERT TO "noor_admin" WITH CHECK (true);



CREATE POLICY "noor_admin can insert into service_process_link" ON "staging"."service_process_link" FOR INSERT TO "noor_admin" WITH CHECK (true);



CREATE POLICY "noor_admin can insert into stakeholder_initiative_link" ON "staging"."stakeholder_initiative_link" FOR INSERT TO "noor_admin" WITH CHECK (true);



CREATE POLICY "noor_admin can insert into stakeholders" ON "staging"."stakeholders" FOR INSERT TO "noor_admin" WITH CHECK (true);



CREATE POLICY "noor_admin can insert into strategic_kpis" ON "staging"."strategic_kpis" FOR INSERT TO "noor_admin" WITH CHECK (true);



CREATE POLICY "noor_admin can insert into taxonomy" ON "staging"."taxonomy" FOR INSERT TO "noor_admin" WITH CHECK (true);



CREATE POLICY "noor_admin can insert into user_feedback" ON "staging"."user_feedback" FOR INSERT TO "noor_admin" WITH CHECK (true);



CREATE POLICY "noor_admin can insert into whitelist_tables" ON "staging"."whitelist_tables" FOR INSERT TO "noor_admin" WITH CHECK (true);



CREATE POLICY "noor_admin can select from financial_tracking" ON "staging"."financial_tracking" FOR SELECT TO "noor_admin" USING (true);



CREATE POLICY "noor_admin can select from it_systems" ON "staging"."it_systems" FOR SELECT TO "noor_admin" USING (true);



CREATE POLICY "noor_admin can select from journeys" ON "staging"."journeys" FOR SELECT TO "noor_admin" USING (true);



CREATE POLICY "noor_admin can select from operational_kpis" ON "staging"."operational_kpis" FOR SELECT TO "noor_admin" USING (true);



CREATE POLICY "noor_admin can select from org_structure" ON "staging"."org_structure" FOR SELECT TO "noor_admin" USING (true);



CREATE POLICY "noor_admin can select from policy_entity_assignments" ON "staging"."policy_entity_assignments" FOR SELECT TO "noor_admin" USING (true);



CREATE POLICY "noor_admin can select from policy_tools" ON "staging"."policy_tools" FOR SELECT TO "noor_admin" USING (true);



CREATE POLICY "noor_admin can select from process_ownership" ON "staging"."process_ownership" FOR SELECT TO "noor_admin" USING (true);



CREATE POLICY "noor_admin can select from process_system_link" ON "staging"."process_system_link" FOR SELECT TO "noor_admin" USING (true);



CREATE POLICY "noor_admin can select from processes_backup" ON "staging"."processes_backup" FOR SELECT TO "noor_admin" USING (true);



CREATE POLICY "noor_admin can select from programs" ON "staging"."programs" FOR SELECT TO "noor_admin" USING (true);



CREATE POLICY "noor_admin can select from resource_allocation" ON "staging"."resource_allocation" FOR SELECT TO "noor_admin" USING (true);



CREATE POLICY "noor_admin can select from risk_initiative_link" ON "staging"."risk_initiative_link" FOR SELECT TO "noor_admin" USING (true);



CREATE POLICY "noor_admin can select from risk_program_link" ON "staging"."risk_program_link" FOR SELECT TO "noor_admin" USING (true);



CREATE POLICY "noor_admin can select from risk_register" ON "staging"."risk_register" FOR SELECT TO "noor_admin" USING (true);



CREATE POLICY "noor_admin can select from roles" ON "staging"."roles" FOR SELECT TO "noor_admin" USING (true);



CREATE POLICY "noor_admin can select from service_process_link" ON "staging"."service_process_link" FOR SELECT TO "noor_admin" USING (true);



CREATE POLICY "noor_admin can select from stakeholder_initiative_link" ON "staging"."stakeholder_initiative_link" FOR SELECT TO "noor_admin" USING (true);



CREATE POLICY "noor_admin can select from stakeholders" ON "staging"."stakeholders" FOR SELECT TO "noor_admin" USING (true);



CREATE POLICY "noor_admin can select from strategic_kpis" ON "staging"."strategic_kpis" FOR SELECT TO "noor_admin" USING (true);



CREATE POLICY "noor_admin can select from taxonomy" ON "staging"."taxonomy" FOR SELECT TO "noor_admin" USING (true);



CREATE POLICY "noor_admin can select from user_feedback" ON "staging"."user_feedback" FOR SELECT TO "noor_admin" USING (true);



CREATE POLICY "noor_admin can select from whitelist_tables" ON "staging"."whitelist_tables" FOR SELECT TO "noor_admin" USING (true);



CREATE POLICY "noor_admin can update financial_tracking" ON "staging"."financial_tracking" FOR UPDATE TO "noor_admin" USING (true) WITH CHECK (true);



CREATE POLICY "noor_admin can update it_systems" ON "staging"."it_systems" FOR UPDATE TO "noor_admin" USING (true) WITH CHECK (true);



CREATE POLICY "noor_admin can update journeys" ON "staging"."journeys" FOR UPDATE TO "noor_admin" USING (true) WITH CHECK (true);



CREATE POLICY "noor_admin can update operational_kpis" ON "staging"."operational_kpis" FOR UPDATE TO "noor_admin" USING (true) WITH CHECK (true);



CREATE POLICY "noor_admin can update org_structure" ON "staging"."org_structure" FOR UPDATE TO "noor_admin" USING (true) WITH CHECK (true);



CREATE POLICY "noor_admin can update policy_entity_assignments" ON "staging"."policy_entity_assignments" FOR UPDATE TO "noor_admin" USING (true) WITH CHECK (true);



CREATE POLICY "noor_admin can update policy_tools" ON "staging"."policy_tools" FOR UPDATE TO "noor_admin" USING (true) WITH CHECK (true);



CREATE POLICY "noor_admin can update process_ownership" ON "staging"."process_ownership" FOR UPDATE TO "noor_admin" USING (true) WITH CHECK (true);



CREATE POLICY "noor_admin can update process_system_link" ON "staging"."process_system_link" FOR UPDATE TO "noor_admin" USING (true) WITH CHECK (true);



CREATE POLICY "noor_admin can update processes_backup" ON "staging"."processes_backup" FOR UPDATE TO "noor_admin" USING (true) WITH CHECK (true);



CREATE POLICY "noor_admin can update programs" ON "staging"."programs" FOR UPDATE TO "noor_admin" USING (true) WITH CHECK (true);



CREATE POLICY "noor_admin can update resource_allocation" ON "staging"."resource_allocation" FOR UPDATE TO "noor_admin" USING (true) WITH CHECK (true);



CREATE POLICY "noor_admin can update risk_initiative_link" ON "staging"."risk_initiative_link" FOR UPDATE TO "noor_admin" USING (true) WITH CHECK (true);



CREATE POLICY "noor_admin can update risk_program_link" ON "staging"."risk_program_link" FOR UPDATE TO "noor_admin" USING (true) WITH CHECK (true);



CREATE POLICY "noor_admin can update risk_register" ON "staging"."risk_register" FOR UPDATE TO "noor_admin" USING (true) WITH CHECK (true);



CREATE POLICY "noor_admin can update roles" ON "staging"."roles" FOR UPDATE TO "noor_admin" USING (true) WITH CHECK (true);



CREATE POLICY "noor_admin can update service_process_link" ON "staging"."service_process_link" FOR UPDATE TO "noor_admin" USING (true) WITH CHECK (true);



CREATE POLICY "noor_admin can update stakeholder_initiative_link" ON "staging"."stakeholder_initiative_link" FOR UPDATE TO "noor_admin" USING (true) WITH CHECK (true);



CREATE POLICY "noor_admin can update stakeholders" ON "staging"."stakeholders" FOR UPDATE TO "noor_admin" USING (true) WITH CHECK (true);



CREATE POLICY "noor_admin can update strategic_kpis" ON "staging"."strategic_kpis" FOR UPDATE TO "noor_admin" USING (true) WITH CHECK (true);



CREATE POLICY "noor_admin can update taxonomy" ON "staging"."taxonomy" FOR UPDATE TO "noor_admin" USING (true) WITH CHECK (true);



CREATE POLICY "noor_admin can update user_feedback" ON "staging"."user_feedback" FOR UPDATE TO "noor_admin" USING (true) WITH CHECK (true);



CREATE POLICY "noor_admin can update whitelist_tables" ON "staging"."whitelist_tables" FOR UPDATE TO "noor_admin" USING (true) WITH CHECK (true);



ALTER TABLE "staging"."operational_kpis" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "staging"."org_structure" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "staging"."policy_entity_assignments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "staging"."policy_tools" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "staging"."process_ownership" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "staging"."process_system_link" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "staging"."processes_backup" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "staging"."processes_l3" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "staging"."programs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "staging"."project_memory" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "staging"."resource_allocation" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "staging"."risk_initiative_link" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "staging"."risk_program_link" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "staging"."risk_register" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "staging"."roles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "staging"."service_process_link" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "staging"."stakeholder_initiative_link" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "staging"."stakeholders" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "staging"."strategic_kpis" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "staging"."taxonomy" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "staging"."user_feedback" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "staging"."whitelist_tables" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";
GRANT ALL ON SCHEMA "public" TO "noor_admin";
GRANT USAGE ON SCHEMA "public" TO "read_only_user";



GRANT USAGE ON SCHEMA "staging" TO "supabase_admin";
GRANT USAGE ON SCHEMA "staging" TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_in"("cstring", "oid", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_in"("cstring", "oid", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_in"("cstring", "oid", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_in"("cstring", "oid", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_out"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_out"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_out"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_out"("public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_recv"("internal", "oid", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_recv"("internal", "oid", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_recv"("internal", "oid", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_recv"("internal", "oid", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_send"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_send"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_send"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_send"("public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_typmod_in"("cstring"[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_typmod_in"("cstring"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_typmod_in"("cstring"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_typmod_in"("cstring"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_in"("cstring", "oid", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_in"("cstring", "oid", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_in"("cstring", "oid", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_in"("cstring", "oid", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_out"("public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_out"("public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_out"("public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_out"("public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_recv"("internal", "oid", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_recv"("internal", "oid", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_recv"("internal", "oid", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_recv"("internal", "oid", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_send"("public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_send"("public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_send"("public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_send"("public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_typmod_in"("cstring"[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_typmod_in"("cstring"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_typmod_in"("cstring"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_typmod_in"("cstring"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_in"("cstring", "oid", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_in"("cstring", "oid", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_in"("cstring", "oid", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_in"("cstring", "oid", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_out"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_out"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_out"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_out"("public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_recv"("internal", "oid", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_recv"("internal", "oid", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_recv"("internal", "oid", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_recv"("internal", "oid", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_send"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_send"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_send"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_send"("public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_typmod_in"("cstring"[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_typmod_in"("cstring"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_typmod_in"("cstring"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_typmod_in"("cstring"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_halfvec"(real[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(real[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(real[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(real[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(real[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(real[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(real[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(real[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_vector"(real[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_vector"(real[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_vector"(real[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_vector"(real[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_halfvec"(double precision[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(double precision[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(double precision[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(double precision[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(double precision[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(double precision[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(double precision[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(double precision[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_vector"(double precision[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_vector"(double precision[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_vector"(double precision[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_vector"(double precision[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_halfvec"(integer[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(integer[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(integer[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(integer[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(integer[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(integer[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(integer[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(integer[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_vector"(integer[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_vector"(integer[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_vector"(integer[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_vector"(integer[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_halfvec"(numeric[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(numeric[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(numeric[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(numeric[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(numeric[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(numeric[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(numeric[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(numeric[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_vector"(numeric[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_vector"(numeric[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_vector"(numeric[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_vector"(numeric[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_to_float4"("public"."halfvec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_to_float4"("public"."halfvec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_to_float4"("public"."halfvec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_to_float4"("public"."halfvec", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec"("public"."halfvec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec"("public"."halfvec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec"("public"."halfvec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec"("public"."halfvec", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_to_sparsevec"("public"."halfvec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_to_sparsevec"("public"."halfvec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_to_sparsevec"("public"."halfvec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_to_sparsevec"("public"."halfvec", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_to_vector"("public"."halfvec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_to_vector"("public"."halfvec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_to_vector"("public"."halfvec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_to_vector"("public"."halfvec", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_to_halfvec"("public"."sparsevec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_to_halfvec"("public"."sparsevec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_to_halfvec"("public"."sparsevec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_to_halfvec"("public"."sparsevec", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec"("public"."sparsevec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec"("public"."sparsevec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec"("public"."sparsevec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec"("public"."sparsevec", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_to_vector"("public"."sparsevec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_to_vector"("public"."sparsevec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_to_vector"("public"."sparsevec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_to_vector"("public"."sparsevec", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_to_float4"("public"."vector", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_to_float4"("public"."vector", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_to_float4"("public"."vector", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_to_float4"("public"."vector", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_to_halfvec"("public"."vector", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_to_halfvec"("public"."vector", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_to_halfvec"("public"."vector", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_to_halfvec"("public"."vector", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_to_sparsevec"("public"."vector", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_to_sparsevec"("public"."vector", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_to_sparsevec"("public"."vector", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_to_sparsevec"("public"."vector", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector"("public"."vector", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector"("public"."vector", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."vector"("public"."vector", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector"("public"."vector", integer, boolean) TO "service_role";























































































































































































































































































GRANT ALL ON FUNCTION "public"."_dto_create_rls"("p_tab" "text", "p_owner_col" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."_dto_create_rls"("p_tab" "text", "p_owner_col" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_dto_create_rls"("p_tab" "text", "p_owner_col" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."admin_exec_sql"("query" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_exec_sql"("query" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."admin_exec_sql"("query" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_exec_sql"("query" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."calculate_complexity_score"("solution_text" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."calculate_complexity_score"("solution_text" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."calculate_complexity_score"("solution_text" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."calculate_likelihood_delay"() TO "anon";
GRANT ALL ON FUNCTION "public"."calculate_likelihood_delay"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."calculate_likelihood_delay"() TO "service_role";



GRANT ALL ON FUNCTION "public"."capability_health_by_year"("p_year" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."capability_health_by_year"("p_year" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."capability_health_by_year"("p_year" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."cleanup_low_usage_memories"() TO "anon";
GRANT ALL ON FUNCTION "public"."cleanup_low_usage_memories"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."cleanup_low_usage_memories"() TO "service_role";



GRANT ALL ON FUNCTION "public"."column_exists"("p_schema" "text", "p_table" "text", "p_column" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."column_exists"("p_schema" "text", "p_table" "text", "p_column" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."column_exists"("p_schema" "text", "p_table" "text", "p_column" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."detect_manipulation"("user_request" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."detect_manipulation"("user_request" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."detect_manipulation"("user_request" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."dto_log_operation"("p_operation" character varying, "p_table_name" character varying, "p_record_count" integer, "p_status" character varying, "p_error_message" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."dto_log_operation"("p_operation" character varying, "p_table_name" character varying, "p_record_count" integer, "p_status" character varying, "p_error_message" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."dto_log_operation"("p_operation" character varying, "p_table_name" character varying, "p_record_count" integer, "p_status" character varying, "p_error_message" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."execute_sql"("sql_query" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."execute_sql"("sql_query" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."execute_sql"("sql_query" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_wheel_data"("overlay_type" character varying) TO "anon";
GRANT ALL ON FUNCTION "public"."generate_wheel_data"("overlay_type" character varying) TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_wheel_data"("overlay_type" character varying) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_capability_health"("p_year" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_capability_health"("p_year" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_capability_health"("p_year" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_capability_health_year"("p_year" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_capability_health_year"("p_year" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_capability_health_year"("p_year" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_capability_performance_kpis"("capability_id" "text", "year_param" integer, "level_param" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_capability_performance_kpis"("capability_id" "text", "year_param" integer, "level_param" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_capability_performance_kpis"("capability_id" "text", "year_param" integer, "level_param" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_capability_popup_data"("capability_id" "text", "year_param" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_capability_popup_data"("capability_id" "text", "year_param" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_capability_popup_data"("capability_id" "text", "year_param" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_capability_popup_data_secure"("capability_id" "text", "year_param" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_capability_popup_data_secure"("capability_id" "text", "year_param" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_capability_popup_data_secure"("capability_id" "text", "year_param" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_capability_summary"("capability_id" "text", "year_param" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_capability_summary"("capability_id" "text", "year_param" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_capability_summary"("capability_id" "text", "year_param" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_change_adoption_detail"("capability_id" "text", "year_param" integer, "level_param" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_change_adoption_detail"("capability_id" "text", "year_param" integer, "level_param" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_change_adoption_detail"("capability_id" "text", "year_param" integer, "level_param" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_culture_health_detail"("capability_id" "text", "year_param" integer, "level_param" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_culture_health_detail"("capability_id" "text", "year_param" integer, "level_param" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_culture_health_detail"("capability_id" "text", "year_param" integer, "level_param" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_current_timestamp"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_current_timestamp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_current_timestamp"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_it_systems_detail"("capability_id" "text", "year_param" integer, "level_param" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_it_systems_detail"("capability_id" "text", "year_param" integer, "level_param" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_it_systems_detail"("capability_id" "text", "year_param" integer, "level_param" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_next_join_table_id"("p_sequence_name" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_next_join_table_id"("p_sequence_name" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_next_join_table_id"("p_sequence_name" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_project_deliverables_detail"("capability_id" "text", "year_param" integer, "level_param" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_project_deliverables_detail"("capability_id" "text", "year_param" integer, "level_param" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_project_deliverables_detail"("capability_id" "text", "year_param" integer, "level_param" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_project_deliverables_detail_secure"("capability_id" "text", "year_param" integer, "level_param" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_project_deliverables_detail_secure"("capability_id" "text", "year_param" integer, "level_param" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_project_deliverables_detail_secure"("capability_id" "text", "year_param" integer, "level_param" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_role_gaps_detail"("capability_id" "text", "year_param" integer, "level_param" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_role_gaps_detail"("capability_id" "text", "year_param" integer, "level_param" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_role_gaps_detail"("capability_id" "text", "year_param" integer, "level_param" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_accum"(double precision[], "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_accum"(double precision[], "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_accum"(double precision[], "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_accum"(double precision[], "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_add"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_add"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_add"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_add"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_avg"(double precision[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_avg"(double precision[]) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_avg"(double precision[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_avg"(double precision[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_cmp"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_cmp"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_cmp"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_cmp"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_combine"(double precision[], double precision[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_combine"(double precision[], double precision[]) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_combine"(double precision[], double precision[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_combine"(double precision[], double precision[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_concat"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_concat"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_concat"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_concat"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_eq"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_eq"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_eq"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_eq"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_ge"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_ge"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_ge"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_ge"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_gt"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_gt"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_gt"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_gt"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_l2_squared_distance"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_l2_squared_distance"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_l2_squared_distance"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_l2_squared_distance"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_le"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_le"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_le"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_le"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_lt"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_lt"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_lt"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_lt"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_mul"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_mul"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_mul"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_mul"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_ne"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_ne"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_ne"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_ne"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_negative_inner_product"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_negative_inner_product"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_negative_inner_product"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_negative_inner_product"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_spherical_distance"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_spherical_distance"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_spherical_distance"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_spherical_distance"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_sub"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_sub"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_sub"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_sub"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."hamming_distance"(bit, bit) TO "postgres";
GRANT ALL ON FUNCTION "public"."hamming_distance"(bit, bit) TO "anon";
GRANT ALL ON FUNCTION "public"."hamming_distance"(bit, bit) TO "authenticated";
GRANT ALL ON FUNCTION "public"."hamming_distance"(bit, bit) TO "service_role";



GRANT ALL ON FUNCTION "public"."has_role"("required_role" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."has_role"("required_role" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."has_role"("required_role" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."hnsw_bit_support"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."hnsw_bit_support"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."hnsw_bit_support"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."hnsw_bit_support"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."hnsw_halfvec_support"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."hnsw_halfvec_support"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."hnsw_halfvec_support"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."hnsw_halfvec_support"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."hnsw_sparsevec_support"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."hnsw_sparsevec_support"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."hnsw_sparsevec_support"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."hnsw_sparsevec_support"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."hnswhandler"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."hnswhandler"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."hnswhandler"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."hnswhandler"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."inner_product"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."inner_product"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."inner_product"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_service_role"() TO "anon";
GRANT ALL ON FUNCTION "public"."is_service_role"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_service_role"() TO "service_role";



GRANT ALL ON FUNCTION "public"."ivfflat_bit_support"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."ivfflat_bit_support"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."ivfflat_bit_support"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."ivfflat_bit_support"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."ivfflat_halfvec_support"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."ivfflat_halfvec_support"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."ivfflat_halfvec_support"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."ivfflat_halfvec_support"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."ivfflathandler"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."ivfflathandler"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."ivfflathandler"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."ivfflathandler"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."jaccard_distance"(bit, bit) TO "postgres";
GRANT ALL ON FUNCTION "public"."jaccard_distance"(bit, bit) TO "anon";
GRANT ALL ON FUNCTION "public"."jaccard_distance"(bit, bit) TO "authenticated";
GRANT ALL ON FUNCTION "public"."jaccard_distance"(bit, bit) TO "service_role";



GRANT ALL ON FUNCTION "public"."kg_edges_enforce"() TO "anon";
GRANT ALL ON FUNCTION "public"."kg_edges_enforce"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."kg_edges_enforce"() TO "service_role";



GRANT ALL ON FUNCTION "public"."l1_distance"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."l1_distance"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."l1_distance"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."l2_distance"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."l2_distance"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."l2_distance"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."l2_norm"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_norm"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_norm"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_norm"("public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."l2_norm"("public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_norm"("public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_norm"("public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_norm"("public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."manage_risk_associations"() TO "anon";
GRANT ALL ON FUNCTION "public"."manage_risk_associations"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."manage_risk_associations"() TO "service_role";



GRANT ALL ON FUNCTION "public"."safe_to_boolean"("p_value" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."safe_to_boolean"("p_value" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."safe_to_boolean"("p_value" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."safe_to_date"("p_value" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."safe_to_date"("p_value" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."safe_to_date"("p_value" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."safe_to_float"("p_value" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."safe_to_float"("p_value" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."safe_to_float"("p_value" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_cmp"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_cmp"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_cmp"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_cmp"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_eq"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_eq"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_eq"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_eq"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_ge"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_ge"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_ge"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_ge"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_gt"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_gt"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_gt"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_gt"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_l2_squared_distance"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_l2_squared_distance"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_l2_squared_distance"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_l2_squared_distance"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_le"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_le"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_le"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_le"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_lt"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_lt"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_lt"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_lt"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_ne"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_ne"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_ne"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_ne"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_negative_inner_product"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_negative_inner_product"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_negative_inner_product"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_negative_inner_product"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."subvector"("public"."halfvec", integer, integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."subvector"("public"."halfvec", integer, integer) TO "anon";
GRANT ALL ON FUNCTION "public"."subvector"("public"."halfvec", integer, integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."subvector"("public"."halfvec", integer, integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."subvector"("public"."vector", integer, integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."subvector"("public"."vector", integer, integer) TO "anon";
GRANT ALL ON FUNCTION "public"."subvector"("public"."vector", integer, integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."subvector"("public"."vector", integer, integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."table_exists"("schema_name" "text", "table_name" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."table_exists"("schema_name" "text", "table_name" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."table_exists"("schema_name" "text", "table_name" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."temp_split_string"("p_string" "text", "p_delimiter" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."temp_split_string"("p_string" "text", "p_delimiter" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."temp_split_string"("p_string" "text", "p_delimiter" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_inherent_risk_score"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_inherent_risk_score"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_inherent_risk_score"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_modified_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_modified_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_modified_column"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_modified_timestamp"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_modified_timestamp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_modified_timestamp"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_risk_affecting_field"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_risk_affecting_field"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_risk_affecting_field"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_risk_performance_junction"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_risk_performance_junction"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_risk_performance_junction"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_risk_policy_tool_junction"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_risk_policy_tool_junction"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_risk_policy_tool_junction"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_risk_scores"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_risk_scores"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_risk_scores"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_session_context"("p_session_id" character varying, "p_user_id" character varying, "p_focus" character varying, "p_action" character varying) TO "anon";
GRANT ALL ON FUNCTION "public"."update_session_context"("p_session_id" character varying, "p_user_id" character varying, "p_focus" character varying, "p_action" character varying) TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_session_context"("p_session_id" character varying, "p_user_id" character varying, "p_focus" character varying, "p_action" character varying) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_accum"(double precision[], "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_accum"(double precision[], "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_accum"(double precision[], "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_accum"(double precision[], "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_add"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_add"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_add"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_add"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_avg"(double precision[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_avg"(double precision[]) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_avg"(double precision[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_avg"(double precision[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_cmp"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_cmp"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_cmp"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_cmp"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_combine"(double precision[], double precision[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_combine"(double precision[], double precision[]) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_combine"(double precision[], double precision[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_combine"(double precision[], double precision[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_concat"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_concat"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_concat"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_concat"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_dims"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_dims"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_dims"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_dims"("public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_dims"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_dims"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_dims"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_dims"("public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_eq"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_eq"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_eq"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_eq"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_ge"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_ge"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_ge"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_ge"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_gt"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_gt"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_gt"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_gt"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_l2_squared_distance"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_l2_squared_distance"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_l2_squared_distance"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_l2_squared_distance"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_le"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_le"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_le"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_le"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_lt"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_lt"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_lt"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_lt"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_mul"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_mul"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_mul"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_mul"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_ne"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_ne"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_ne"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_ne"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_negative_inner_product"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_negative_inner_product"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_negative_inner_product"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_negative_inner_product"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_norm"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_norm"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_norm"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_norm"("public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_spherical_distance"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_spherical_distance"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_spherical_distance"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_spherical_distance"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_sub"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_sub"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_sub"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_sub"("public"."vector", "public"."vector") TO "service_role";












GRANT ALL ON FUNCTION "public"."avg"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."avg"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."avg"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."avg"("public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."avg"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."avg"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."avg"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."avg"("public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."sum"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sum"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."sum"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sum"("public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sum"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."sum"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."sum"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sum"("public"."vector") TO "service_role";









GRANT ALL ON TABLE "public"."documentation_plans" TO "anon";
GRANT ALL ON TABLE "public"."documentation_plans" TO "authenticated";
GRANT ALL ON TABLE "public"."documentation_plans" TO "service_role";
GRANT ALL ON TABLE "public"."documentation_plans" TO "noor_admin";
GRANT SELECT ON TABLE "public"."documentation_plans" TO "read_only_user";



GRANT ALL ON TABLE "public"."dtdl_models" TO "anon";
GRANT ALL ON TABLE "public"."dtdl_models" TO "authenticated";
GRANT ALL ON TABLE "public"."dtdl_models" TO "service_role";
GRANT ALL ON TABLE "public"."dtdl_models" TO "noor_admin";
GRANT SELECT ON TABLE "public"."dtdl_models" TO "read_only_user";



GRANT ALL ON TABLE "public"."ent_capabilities" TO "anon";
GRANT ALL ON TABLE "public"."ent_capabilities" TO "authenticated";
GRANT ALL ON TABLE "public"."ent_capabilities" TO "service_role";
GRANT ALL ON TABLE "public"."ent_capabilities" TO "noor_admin";
GRANT SELECT ON TABLE "public"."ent_capabilities" TO "read_only_user";



GRANT ALL ON TABLE "public"."ent_change_adoption" TO "anon";
GRANT ALL ON TABLE "public"."ent_change_adoption" TO "authenticated";
GRANT ALL ON TABLE "public"."ent_change_adoption" TO "service_role";
GRANT ALL ON TABLE "public"."ent_change_adoption" TO "noor_admin";
GRANT SELECT ON TABLE "public"."ent_change_adoption" TO "read_only_user";



GRANT ALL ON TABLE "public"."ent_culture_health" TO "anon";
GRANT ALL ON TABLE "public"."ent_culture_health" TO "authenticated";
GRANT ALL ON TABLE "public"."ent_culture_health" TO "service_role";
GRANT ALL ON TABLE "public"."ent_culture_health" TO "noor_admin";
GRANT SELECT ON TABLE "public"."ent_culture_health" TO "read_only_user";



GRANT ALL ON TABLE "public"."ent_it_systems" TO "anon";
GRANT ALL ON TABLE "public"."ent_it_systems" TO "authenticated";
GRANT ALL ON TABLE "public"."ent_it_systems" TO "service_role";
GRANT ALL ON TABLE "public"."ent_it_systems" TO "noor_admin";
GRANT SELECT ON TABLE "public"."ent_it_systems" TO "read_only_user";



GRANT ALL ON TABLE "public"."ent_org_units" TO "anon";
GRANT ALL ON TABLE "public"."ent_org_units" TO "authenticated";
GRANT ALL ON TABLE "public"."ent_org_units" TO "service_role";
GRANT ALL ON TABLE "public"."ent_org_units" TO "noor_admin";
GRANT SELECT ON TABLE "public"."ent_org_units" TO "read_only_user";



GRANT ALL ON TABLE "public"."ent_processes" TO "anon";
GRANT ALL ON TABLE "public"."ent_processes" TO "authenticated";
GRANT ALL ON TABLE "public"."ent_processes" TO "service_role";
GRANT ALL ON TABLE "public"."ent_processes" TO "noor_admin";
GRANT SELECT ON TABLE "public"."ent_processes" TO "read_only_user";



GRANT ALL ON TABLE "public"."ent_projects" TO "anon";
GRANT ALL ON TABLE "public"."ent_projects" TO "authenticated";
GRANT ALL ON TABLE "public"."ent_projects" TO "service_role";
GRANT ALL ON TABLE "public"."ent_projects" TO "noor_admin";
GRANT SELECT ON TABLE "public"."ent_projects" TO "read_only_user";



GRANT ALL ON TABLE "public"."ent_risks" TO "anon";
GRANT ALL ON TABLE "public"."ent_risks" TO "authenticated";
GRANT ALL ON TABLE "public"."ent_risks" TO "service_role";
GRANT ALL ON TABLE "public"."ent_risks" TO "noor_admin";
GRANT SELECT ON TABLE "public"."ent_risks" TO "read_only_user";



GRANT ALL ON TABLE "public"."ent_vendors" TO "anon";
GRANT ALL ON TABLE "public"."ent_vendors" TO "authenticated";
GRANT ALL ON TABLE "public"."ent_vendors" TO "service_role";
GRANT ALL ON TABLE "public"."ent_vendors" TO "noor_admin";
GRANT SELECT ON TABLE "public"."ent_vendors" TO "read_only_user";



GRANT ALL ON TABLE "public"."forum_comments" TO "anon";
GRANT ALL ON TABLE "public"."forum_comments" TO "authenticated";
GRANT ALL ON TABLE "public"."forum_comments" TO "service_role";
GRANT ALL ON TABLE "public"."forum_comments" TO "noor_admin";
GRANT SELECT ON TABLE "public"."forum_comments" TO "read_only_user";



GRANT ALL ON TABLE "public"."jt_ent_capabilities_ent_it_systems_join" TO "anon";
GRANT ALL ON TABLE "public"."jt_ent_capabilities_ent_it_systems_join" TO "authenticated";
GRANT ALL ON TABLE "public"."jt_ent_capabilities_ent_it_systems_join" TO "service_role";
GRANT ALL ON TABLE "public"."jt_ent_capabilities_ent_it_systems_join" TO "noor_admin";
GRANT SELECT ON TABLE "public"."jt_ent_capabilities_ent_it_systems_join" TO "read_only_user";



GRANT ALL ON SEQUENCE "public"."jt_ent_capabilities_ent_it_systems_join_uid_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."jt_ent_capabilities_ent_it_systems_join_uid_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."jt_ent_capabilities_ent_it_systems_join_uid_seq" TO "service_role";



GRANT ALL ON TABLE "public"."jt_ent_capabilities_ent_org_units_join" TO "anon";
GRANT ALL ON TABLE "public"."jt_ent_capabilities_ent_org_units_join" TO "authenticated";
GRANT ALL ON TABLE "public"."jt_ent_capabilities_ent_org_units_join" TO "service_role";
GRANT ALL ON TABLE "public"."jt_ent_capabilities_ent_org_units_join" TO "noor_admin";
GRANT SELECT ON TABLE "public"."jt_ent_capabilities_ent_org_units_join" TO "read_only_user";



GRANT ALL ON SEQUENCE "public"."jt_ent_capabilities_ent_org_units_join_uid_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."jt_ent_capabilities_ent_org_units_join_uid_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."jt_ent_capabilities_ent_org_units_join_uid_seq" TO "service_role";



GRANT ALL ON TABLE "public"."jt_ent_capabilities_ent_processes_join" TO "anon";
GRANT ALL ON TABLE "public"."jt_ent_capabilities_ent_processes_join" TO "authenticated";
GRANT ALL ON TABLE "public"."jt_ent_capabilities_ent_processes_join" TO "service_role";
GRANT ALL ON TABLE "public"."jt_ent_capabilities_ent_processes_join" TO "noor_admin";
GRANT SELECT ON TABLE "public"."jt_ent_capabilities_ent_processes_join" TO "read_only_user";



GRANT ALL ON SEQUENCE "public"."jt_ent_capabilities_ent_processes_join_uid_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."jt_ent_capabilities_ent_processes_join_uid_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."jt_ent_capabilities_ent_processes_join_uid_seq" TO "service_role";



GRANT ALL ON TABLE "public"."jt_ent_change_adoption_ent_it_systems_join" TO "anon";
GRANT ALL ON TABLE "public"."jt_ent_change_adoption_ent_it_systems_join" TO "authenticated";
GRANT ALL ON TABLE "public"."jt_ent_change_adoption_ent_it_systems_join" TO "service_role";
GRANT ALL ON TABLE "public"."jt_ent_change_adoption_ent_it_systems_join" TO "noor_admin";
GRANT SELECT ON TABLE "public"."jt_ent_change_adoption_ent_it_systems_join" TO "read_only_user";



GRANT ALL ON SEQUENCE "public"."jt_ent_change_adoption_ent_it_systems_join_uid_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."jt_ent_change_adoption_ent_it_systems_join_uid_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."jt_ent_change_adoption_ent_it_systems_join_uid_seq" TO "service_role";



GRANT ALL ON TABLE "public"."jt_ent_change_adoption_ent_org_units_join" TO "anon";
GRANT ALL ON TABLE "public"."jt_ent_change_adoption_ent_org_units_join" TO "authenticated";
GRANT ALL ON TABLE "public"."jt_ent_change_adoption_ent_org_units_join" TO "service_role";
GRANT ALL ON TABLE "public"."jt_ent_change_adoption_ent_org_units_join" TO "noor_admin";
GRANT SELECT ON TABLE "public"."jt_ent_change_adoption_ent_org_units_join" TO "read_only_user";



GRANT ALL ON SEQUENCE "public"."jt_ent_change_adoption_ent_org_units_join_uid_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."jt_ent_change_adoption_ent_org_units_join_uid_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."jt_ent_change_adoption_ent_org_units_join_uid_seq" TO "service_role";



GRANT ALL ON TABLE "public"."jt_ent_change_adoption_ent_processes_join" TO "anon";
GRANT ALL ON TABLE "public"."jt_ent_change_adoption_ent_processes_join" TO "authenticated";
GRANT ALL ON TABLE "public"."jt_ent_change_adoption_ent_processes_join" TO "service_role";
GRANT ALL ON TABLE "public"."jt_ent_change_adoption_ent_processes_join" TO "noor_admin";
GRANT SELECT ON TABLE "public"."jt_ent_change_adoption_ent_processes_join" TO "read_only_user";



GRANT ALL ON SEQUENCE "public"."jt_ent_change_adoption_ent_processes_join_uid_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."jt_ent_change_adoption_ent_processes_join_uid_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."jt_ent_change_adoption_ent_processes_join_uid_seq" TO "service_role";



GRANT ALL ON TABLE "public"."jt_ent_it_systems_ent_vendors_join" TO "anon";
GRANT ALL ON TABLE "public"."jt_ent_it_systems_ent_vendors_join" TO "authenticated";
GRANT ALL ON TABLE "public"."jt_ent_it_systems_ent_vendors_join" TO "service_role";
GRANT ALL ON TABLE "public"."jt_ent_it_systems_ent_vendors_join" TO "noor_admin";
GRANT SELECT ON TABLE "public"."jt_ent_it_systems_ent_vendors_join" TO "read_only_user";



GRANT ALL ON SEQUENCE "public"."jt_ent_it_systems_ent_vendors_join_uid_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."jt_ent_it_systems_ent_vendors_join_uid_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."jt_ent_it_systems_ent_vendors_join_uid_seq" TO "service_role";



GRANT ALL ON TABLE "public"."jt_ent_org_units_ent_culture_health_join" TO "anon";
GRANT ALL ON TABLE "public"."jt_ent_org_units_ent_culture_health_join" TO "authenticated";
GRANT ALL ON TABLE "public"."jt_ent_org_units_ent_culture_health_join" TO "service_role";
GRANT ALL ON TABLE "public"."jt_ent_org_units_ent_culture_health_join" TO "noor_admin";
GRANT SELECT ON TABLE "public"."jt_ent_org_units_ent_culture_health_join" TO "read_only_user";



GRANT ALL ON SEQUENCE "public"."jt_ent_org_units_ent_culture_health_join_uid_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."jt_ent_org_units_ent_culture_health_join_uid_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."jt_ent_org_units_ent_culture_health_join_uid_seq" TO "service_role";



GRANT ALL ON TABLE "public"."jt_ent_org_units_ent_processes_join" TO "anon";
GRANT ALL ON TABLE "public"."jt_ent_org_units_ent_processes_join" TO "authenticated";
GRANT ALL ON TABLE "public"."jt_ent_org_units_ent_processes_join" TO "service_role";
GRANT ALL ON TABLE "public"."jt_ent_org_units_ent_processes_join" TO "noor_admin";
GRANT SELECT ON TABLE "public"."jt_ent_org_units_ent_processes_join" TO "read_only_user";



GRANT ALL ON SEQUENCE "public"."jt_ent_org_units_ent_processes_join_uid_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."jt_ent_org_units_ent_processes_join_uid_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."jt_ent_org_units_ent_processes_join_uid_seq" TO "service_role";



GRANT ALL ON TABLE "public"."jt_ent_processes_ent_it_systems_join" TO "anon";
GRANT ALL ON TABLE "public"."jt_ent_processes_ent_it_systems_join" TO "authenticated";
GRANT ALL ON TABLE "public"."jt_ent_processes_ent_it_systems_join" TO "service_role";
GRANT ALL ON TABLE "public"."jt_ent_processes_ent_it_systems_join" TO "noor_admin";
GRANT SELECT ON TABLE "public"."jt_ent_processes_ent_it_systems_join" TO "read_only_user";



GRANT ALL ON SEQUENCE "public"."jt_ent_processes_ent_it_systems_join_uid_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."jt_ent_processes_ent_it_systems_join_uid_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."jt_ent_processes_ent_it_systems_join_uid_seq" TO "service_role";



GRANT ALL ON TABLE "public"."jt_ent_projects_ent_change_adoption_join" TO "anon";
GRANT ALL ON TABLE "public"."jt_ent_projects_ent_change_adoption_join" TO "authenticated";
GRANT ALL ON TABLE "public"."jt_ent_projects_ent_change_adoption_join" TO "service_role";
GRANT ALL ON TABLE "public"."jt_ent_projects_ent_change_adoption_join" TO "noor_admin";
GRANT SELECT ON TABLE "public"."jt_ent_projects_ent_change_adoption_join" TO "read_only_user";



GRANT ALL ON SEQUENCE "public"."jt_ent_projects_ent_change_adoption_join_uid_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."jt_ent_projects_ent_change_adoption_join_uid_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."jt_ent_projects_ent_change_adoption_join_uid_seq" TO "service_role";



GRANT ALL ON TABLE "public"."jt_ent_projects_ent_it_systems_join" TO "anon";
GRANT ALL ON TABLE "public"."jt_ent_projects_ent_it_systems_join" TO "authenticated";
GRANT ALL ON TABLE "public"."jt_ent_projects_ent_it_systems_join" TO "service_role";
GRANT ALL ON TABLE "public"."jt_ent_projects_ent_it_systems_join" TO "noor_admin";
GRANT SELECT ON TABLE "public"."jt_ent_projects_ent_it_systems_join" TO "read_only_user";



GRANT ALL ON SEQUENCE "public"."jt_ent_projects_ent_it_systems_join_uid_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."jt_ent_projects_ent_it_systems_join_uid_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."jt_ent_projects_ent_it_systems_join_uid_seq" TO "service_role";



GRANT ALL ON TABLE "public"."jt_ent_projects_ent_org_units_join" TO "anon";
GRANT ALL ON TABLE "public"."jt_ent_projects_ent_org_units_join" TO "authenticated";
GRANT ALL ON TABLE "public"."jt_ent_projects_ent_org_units_join" TO "service_role";
GRANT ALL ON TABLE "public"."jt_ent_projects_ent_org_units_join" TO "noor_admin";
GRANT SELECT ON TABLE "public"."jt_ent_projects_ent_org_units_join" TO "read_only_user";



GRANT ALL ON SEQUENCE "public"."jt_ent_projects_ent_org_units_join_uid_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."jt_ent_projects_ent_org_units_join_uid_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."jt_ent_projects_ent_org_units_join_uid_seq" TO "service_role";



GRANT ALL ON TABLE "public"."jt_ent_projects_ent_processes_join" TO "anon";
GRANT ALL ON TABLE "public"."jt_ent_projects_ent_processes_join" TO "authenticated";
GRANT ALL ON TABLE "public"."jt_ent_projects_ent_processes_join" TO "service_role";
GRANT ALL ON TABLE "public"."jt_ent_projects_ent_processes_join" TO "noor_admin";
GRANT SELECT ON TABLE "public"."jt_ent_projects_ent_processes_join" TO "read_only_user";



GRANT ALL ON SEQUENCE "public"."jt_ent_projects_ent_processes_join_uid_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."jt_ent_projects_ent_processes_join_uid_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."jt_ent_projects_ent_processes_join_uid_seq" TO "service_role";



GRANT ALL ON TABLE "public"."jt_ent_risks_sec_performance_join" TO "anon";
GRANT ALL ON TABLE "public"."jt_ent_risks_sec_performance_join" TO "authenticated";
GRANT ALL ON TABLE "public"."jt_ent_risks_sec_performance_join" TO "service_role";
GRANT ALL ON TABLE "public"."jt_ent_risks_sec_performance_join" TO "noor_admin";
GRANT SELECT ON TABLE "public"."jt_ent_risks_sec_performance_join" TO "read_only_user";



GRANT ALL ON SEQUENCE "public"."jt_ent_risks_sec_performance_join_uid_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."jt_ent_risks_sec_performance_join_uid_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."jt_ent_risks_sec_performance_join_uid_seq" TO "service_role";



GRANT ALL ON TABLE "public"."jt_ent_risks_sec_policy_tools_join" TO "anon";
GRANT ALL ON TABLE "public"."jt_ent_risks_sec_policy_tools_join" TO "authenticated";
GRANT ALL ON TABLE "public"."jt_ent_risks_sec_policy_tools_join" TO "service_role";
GRANT ALL ON TABLE "public"."jt_ent_risks_sec_policy_tools_join" TO "noor_admin";
GRANT SELECT ON TABLE "public"."jt_ent_risks_sec_policy_tools_join" TO "read_only_user";



GRANT ALL ON SEQUENCE "public"."jt_ent_risks_sec_policy_tools_join_uid_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."jt_ent_risks_sec_policy_tools_join_uid_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."jt_ent_risks_sec_policy_tools_join_uid_seq" TO "service_role";



GRANT ALL ON TABLE "public"."jt_sec_admin_records_sec_businesses_join" TO "anon";
GRANT ALL ON TABLE "public"."jt_sec_admin_records_sec_businesses_join" TO "authenticated";
GRANT ALL ON TABLE "public"."jt_sec_admin_records_sec_businesses_join" TO "service_role";
GRANT ALL ON TABLE "public"."jt_sec_admin_records_sec_businesses_join" TO "noor_admin";
GRANT SELECT ON TABLE "public"."jt_sec_admin_records_sec_businesses_join" TO "read_only_user";



GRANT ALL ON SEQUENCE "public"."jt_sec_admin_records_sec_businesses_join_uid_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."jt_sec_admin_records_sec_businesses_join_uid_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."jt_sec_admin_records_sec_businesses_join_uid_seq" TO "service_role";



GRANT ALL ON TABLE "public"."jt_sec_admin_records_sec_citizens_join" TO "anon";
GRANT ALL ON TABLE "public"."jt_sec_admin_records_sec_citizens_join" TO "authenticated";
GRANT ALL ON TABLE "public"."jt_sec_admin_records_sec_citizens_join" TO "service_role";
GRANT ALL ON TABLE "public"."jt_sec_admin_records_sec_citizens_join" TO "noor_admin";
GRANT SELECT ON TABLE "public"."jt_sec_admin_records_sec_citizens_join" TO "read_only_user";



GRANT ALL ON SEQUENCE "public"."jt_sec_admin_records_sec_citizens_join_uid_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."jt_sec_admin_records_sec_citizens_join_uid_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."jt_sec_admin_records_sec_citizens_join_uid_seq" TO "service_role";



GRANT ALL ON TABLE "public"."jt_sec_admin_records_sec_gov_entities_join" TO "anon";
GRANT ALL ON TABLE "public"."jt_sec_admin_records_sec_gov_entities_join" TO "authenticated";
GRANT ALL ON TABLE "public"."jt_sec_admin_records_sec_gov_entities_join" TO "service_role";
GRANT ALL ON TABLE "public"."jt_sec_admin_records_sec_gov_entities_join" TO "noor_admin";
GRANT SELECT ON TABLE "public"."jt_sec_admin_records_sec_gov_entities_join" TO "read_only_user";



GRANT ALL ON SEQUENCE "public"."jt_sec_admin_records_sec_gov_entities_join_uid_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."jt_sec_admin_records_sec_gov_entities_join_uid_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."jt_sec_admin_records_sec_gov_entities_join_uid_seq" TO "service_role";



GRANT ALL ON TABLE "public"."jt_sec_businesses_sec_data_transactions_join" TO "anon";
GRANT ALL ON TABLE "public"."jt_sec_businesses_sec_data_transactions_join" TO "authenticated";
GRANT ALL ON TABLE "public"."jt_sec_businesses_sec_data_transactions_join" TO "service_role";
GRANT ALL ON TABLE "public"."jt_sec_businesses_sec_data_transactions_join" TO "noor_admin";
GRANT SELECT ON TABLE "public"."jt_sec_businesses_sec_data_transactions_join" TO "read_only_user";



GRANT ALL ON SEQUENCE "public"."jt_sec_businesses_sec_data_transactions_join_uid_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."jt_sec_businesses_sec_data_transactions_join_uid_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."jt_sec_businesses_sec_data_transactions_join_uid_seq" TO "service_role";



GRANT ALL ON TABLE "public"."jt_sec_citizens_sec_data_transactions_join" TO "anon";
GRANT ALL ON TABLE "public"."jt_sec_citizens_sec_data_transactions_join" TO "authenticated";
GRANT ALL ON TABLE "public"."jt_sec_citizens_sec_data_transactions_join" TO "service_role";
GRANT ALL ON TABLE "public"."jt_sec_citizens_sec_data_transactions_join" TO "noor_admin";
GRANT SELECT ON TABLE "public"."jt_sec_citizens_sec_data_transactions_join" TO "read_only_user";



GRANT ALL ON SEQUENCE "public"."jt_sec_citizens_sec_data_transactions_join_uid_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."jt_sec_citizens_sec_data_transactions_join_uid_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."jt_sec_citizens_sec_data_transactions_join_uid_seq" TO "service_role";



GRANT ALL ON TABLE "public"."jt_sec_data_transactions_sec_performance_join" TO "anon";
GRANT ALL ON TABLE "public"."jt_sec_data_transactions_sec_performance_join" TO "authenticated";
GRANT ALL ON TABLE "public"."jt_sec_data_transactions_sec_performance_join" TO "service_role";
GRANT ALL ON TABLE "public"."jt_sec_data_transactions_sec_performance_join" TO "noor_admin";
GRANT SELECT ON TABLE "public"."jt_sec_data_transactions_sec_performance_join" TO "read_only_user";



GRANT ALL ON SEQUENCE "public"."jt_sec_data_transactions_sec_performance_join_uid_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."jt_sec_data_transactions_sec_performance_join_uid_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."jt_sec_data_transactions_sec_performance_join_uid_seq" TO "service_role";



GRANT ALL ON TABLE "public"."jt_sec_gov_entities_sec_data_transactions_join" TO "anon";
GRANT ALL ON TABLE "public"."jt_sec_gov_entities_sec_data_transactions_join" TO "authenticated";
GRANT ALL ON TABLE "public"."jt_sec_gov_entities_sec_data_transactions_join" TO "service_role";
GRANT ALL ON TABLE "public"."jt_sec_gov_entities_sec_data_transactions_join" TO "noor_admin";
GRANT SELECT ON TABLE "public"."jt_sec_gov_entities_sec_data_transactions_join" TO "read_only_user";



GRANT ALL ON SEQUENCE "public"."jt_sec_gov_entities_sec_data_transactions_join_uid_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."jt_sec_gov_entities_sec_data_transactions_join_uid_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."jt_sec_gov_entities_sec_data_transactions_join_uid_seq" TO "service_role";



GRANT ALL ON TABLE "public"."jt_sec_objectives_sec_performance_join" TO "anon";
GRANT ALL ON TABLE "public"."jt_sec_objectives_sec_performance_join" TO "authenticated";
GRANT ALL ON TABLE "public"."jt_sec_objectives_sec_performance_join" TO "service_role";
GRANT ALL ON TABLE "public"."jt_sec_objectives_sec_performance_join" TO "noor_admin";
GRANT SELECT ON TABLE "public"."jt_sec_objectives_sec_performance_join" TO "read_only_user";



GRANT ALL ON SEQUENCE "public"."jt_sec_objectives_sec_performance_join_uid_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."jt_sec_objectives_sec_performance_join_uid_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."jt_sec_objectives_sec_performance_join_uid_seq" TO "service_role";



GRANT ALL ON TABLE "public"."jt_sec_objectives_sec_policy_tools_join" TO "anon";
GRANT ALL ON TABLE "public"."jt_sec_objectives_sec_policy_tools_join" TO "authenticated";
GRANT ALL ON TABLE "public"."jt_sec_objectives_sec_policy_tools_join" TO "service_role";
GRANT ALL ON TABLE "public"."jt_sec_objectives_sec_policy_tools_join" TO "noor_admin";
GRANT SELECT ON TABLE "public"."jt_sec_objectives_sec_policy_tools_join" TO "read_only_user";



GRANT ALL ON SEQUENCE "public"."jt_sec_objectives_sec_policy_tools_join_uid_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."jt_sec_objectives_sec_policy_tools_join_uid_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."jt_sec_objectives_sec_policy_tools_join_uid_seq" TO "service_role";



GRANT ALL ON TABLE "public"."jt_sec_performance_ent_capabilities_join" TO "anon";
GRANT ALL ON TABLE "public"."jt_sec_performance_ent_capabilities_join" TO "authenticated";
GRANT ALL ON TABLE "public"."jt_sec_performance_ent_capabilities_join" TO "service_role";
GRANT ALL ON TABLE "public"."jt_sec_performance_ent_capabilities_join" TO "noor_admin";
GRANT SELECT ON TABLE "public"."jt_sec_performance_ent_capabilities_join" TO "read_only_user";



GRANT ALL ON SEQUENCE "public"."jt_sec_performance_ent_capabilities_join_uid_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."jt_sec_performance_ent_capabilities_join_uid_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."jt_sec_performance_ent_capabilities_join_uid_seq" TO "service_role";



GRANT ALL ON TABLE "public"."jt_sec_policy_tools_ent_capabilities_join" TO "anon";
GRANT ALL ON TABLE "public"."jt_sec_policy_tools_ent_capabilities_join" TO "authenticated";
GRANT ALL ON TABLE "public"."jt_sec_policy_tools_ent_capabilities_join" TO "service_role";
GRANT ALL ON TABLE "public"."jt_sec_policy_tools_ent_capabilities_join" TO "noor_admin";
GRANT SELECT ON TABLE "public"."jt_sec_policy_tools_ent_capabilities_join" TO "read_only_user";



GRANT ALL ON SEQUENCE "public"."jt_sec_policy_tools_ent_capabilities_join_uid_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."jt_sec_policy_tools_ent_capabilities_join_uid_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."jt_sec_policy_tools_ent_capabilities_join_uid_seq" TO "service_role";



GRANT ALL ON TABLE "public"."jt_sec_policy_tools_sec_admin_records_join" TO "anon";
GRANT ALL ON TABLE "public"."jt_sec_policy_tools_sec_admin_records_join" TO "authenticated";
GRANT ALL ON TABLE "public"."jt_sec_policy_tools_sec_admin_records_join" TO "service_role";
GRANT ALL ON TABLE "public"."jt_sec_policy_tools_sec_admin_records_join" TO "noor_admin";
GRANT SELECT ON TABLE "public"."jt_sec_policy_tools_sec_admin_records_join" TO "read_only_user";



GRANT ALL ON SEQUENCE "public"."jt_sec_policy_tools_sec_admin_records_join_uid_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."jt_sec_policy_tools_sec_admin_records_join_uid_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."jt_sec_policy_tools_sec_admin_records_join_uid_seq" TO "service_role";



GRANT ALL ON TABLE "public"."kg_edges" TO "anon";
GRANT ALL ON TABLE "public"."kg_edges" TO "authenticated";
GRANT ALL ON TABLE "public"."kg_edges" TO "service_role";
GRANT ALL ON TABLE "public"."kg_edges" TO "noor_admin";
GRANT SELECT ON TABLE "public"."kg_edges" TO "read_only_user";



GRANT ALL ON TABLE "public"."kg_nodes" TO "anon";
GRANT ALL ON TABLE "public"."kg_nodes" TO "authenticated";
GRANT ALL ON TABLE "public"."kg_nodes" TO "service_role";
GRANT ALL ON TABLE "public"."kg_nodes" TO "noor_admin";
GRANT SELECT ON TABLE "public"."kg_nodes" TO "read_only_user";



GRANT ALL ON TABLE "public"."rel_allowlist" TO "anon";
GRANT ALL ON TABLE "public"."rel_allowlist" TO "authenticated";
GRANT ALL ON TABLE "public"."rel_allowlist" TO "service_role";
GRANT ALL ON TABLE "public"."rel_allowlist" TO "noor_admin";
GRANT SELECT ON TABLE "public"."rel_allowlist" TO "read_only_user";



GRANT ALL ON TABLE "public"."sec_admin_records" TO "anon";
GRANT ALL ON TABLE "public"."sec_admin_records" TO "authenticated";
GRANT ALL ON TABLE "public"."sec_admin_records" TO "service_role";
GRANT ALL ON TABLE "public"."sec_admin_records" TO "noor_admin";
GRANT SELECT ON TABLE "public"."sec_admin_records" TO "read_only_user";



GRANT ALL ON TABLE "public"."sec_businesses" TO "anon";
GRANT ALL ON TABLE "public"."sec_businesses" TO "authenticated";
GRANT ALL ON TABLE "public"."sec_businesses" TO "service_role";
GRANT ALL ON TABLE "public"."sec_businesses" TO "noor_admin";
GRANT SELECT ON TABLE "public"."sec_businesses" TO "read_only_user";



GRANT ALL ON TABLE "public"."sec_citizens" TO "anon";
GRANT ALL ON TABLE "public"."sec_citizens" TO "authenticated";
GRANT ALL ON TABLE "public"."sec_citizens" TO "service_role";
GRANT ALL ON TABLE "public"."sec_citizens" TO "noor_admin";
GRANT SELECT ON TABLE "public"."sec_citizens" TO "read_only_user";



GRANT ALL ON TABLE "public"."sec_data_transactions" TO "anon";
GRANT ALL ON TABLE "public"."sec_data_transactions" TO "authenticated";
GRANT ALL ON TABLE "public"."sec_data_transactions" TO "service_role";
GRANT ALL ON TABLE "public"."sec_data_transactions" TO "noor_admin";
GRANT SELECT ON TABLE "public"."sec_data_transactions" TO "read_only_user";



GRANT ALL ON TABLE "public"."sec_gov_entities" TO "anon";
GRANT ALL ON TABLE "public"."sec_gov_entities" TO "authenticated";
GRANT ALL ON TABLE "public"."sec_gov_entities" TO "service_role";
GRANT ALL ON TABLE "public"."sec_gov_entities" TO "noor_admin";
GRANT SELECT ON TABLE "public"."sec_gov_entities" TO "read_only_user";



GRANT ALL ON TABLE "public"."sec_objectives" TO "anon";
GRANT ALL ON TABLE "public"."sec_objectives" TO "authenticated";
GRANT ALL ON TABLE "public"."sec_objectives" TO "service_role";
GRANT ALL ON TABLE "public"."sec_objectives" TO "noor_admin";
GRANT SELECT ON TABLE "public"."sec_objectives" TO "read_only_user";



GRANT ALL ON TABLE "public"."sec_performance" TO "anon";
GRANT ALL ON TABLE "public"."sec_performance" TO "authenticated";
GRANT ALL ON TABLE "public"."sec_performance" TO "service_role";
GRANT ALL ON TABLE "public"."sec_performance" TO "noor_admin";
GRANT SELECT ON TABLE "public"."sec_performance" TO "read_only_user";



GRANT ALL ON TABLE "public"."sec_policy_tools" TO "anon";
GRANT ALL ON TABLE "public"."sec_policy_tools" TO "authenticated";
GRANT ALL ON TABLE "public"."sec_policy_tools" TO "service_role";
GRANT ALL ON TABLE "public"."sec_policy_tools" TO "noor_admin";
GRANT SELECT ON TABLE "public"."sec_policy_tools" TO "read_only_user";



GRANT ALL ON TABLE "public"."temp_quarterly_dashboard_data" TO "anon";
GRANT ALL ON TABLE "public"."temp_quarterly_dashboard_data" TO "authenticated";
GRANT ALL ON TABLE "public"."temp_quarterly_dashboard_data" TO "service_role";
GRANT ALL ON TABLE "public"."temp_quarterly_dashboard_data" TO "noor_admin";
GRANT SELECT ON TABLE "public"."temp_quarterly_dashboard_data" TO "read_only_user";



GRANT ALL ON SEQUENCE "public"."temp_quarterly_dashboard_data_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."temp_quarterly_dashboard_data_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."temp_quarterly_dashboard_data_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."vec_chunks" TO "anon";
GRANT ALL ON TABLE "public"."vec_chunks" TO "authenticated";
GRANT ALL ON TABLE "public"."vec_chunks" TO "service_role";
GRANT ALL ON TABLE "public"."vec_chunks" TO "noor_admin";
GRANT SELECT ON TABLE "public"."vec_chunks" TO "read_only_user";



GRANT ALL ON TABLE "public"."view_admin_records_with_node" TO "anon";
GRANT ALL ON TABLE "public"."view_admin_records_with_node" TO "authenticated";
GRANT ALL ON TABLE "public"."view_admin_records_with_node" TO "service_role";
GRANT ALL ON TABLE "public"."view_admin_records_with_node" TO "noor_admin";
GRANT SELECT ON TABLE "public"."view_admin_records_with_node" TO "read_only_user";



GRANT ALL ON TABLE "public"."view_businesses_with_node" TO "anon";
GRANT ALL ON TABLE "public"."view_businesses_with_node" TO "authenticated";
GRANT ALL ON TABLE "public"."view_businesses_with_node" TO "service_role";
GRANT ALL ON TABLE "public"."view_businesses_with_node" TO "noor_admin";
GRANT SELECT ON TABLE "public"."view_businesses_with_node" TO "read_only_user";



GRANT ALL ON TABLE "public"."view_capabilities_with_node" TO "anon";
GRANT ALL ON TABLE "public"."view_capabilities_with_node" TO "authenticated";
GRANT ALL ON TABLE "public"."view_capabilities_with_node" TO "service_role";
GRANT ALL ON TABLE "public"."view_capabilities_with_node" TO "noor_admin";
GRANT SELECT ON TABLE "public"."view_capabilities_with_node" TO "read_only_user";



GRANT ALL ON TABLE "public"."view_change_adoption_with_node" TO "anon";
GRANT ALL ON TABLE "public"."view_change_adoption_with_node" TO "authenticated";
GRANT ALL ON TABLE "public"."view_change_adoption_with_node" TO "service_role";
GRANT ALL ON TABLE "public"."view_change_adoption_with_node" TO "noor_admin";
GRANT SELECT ON TABLE "public"."view_change_adoption_with_node" TO "read_only_user";



GRANT ALL ON TABLE "public"."view_citizens_with_node" TO "anon";
GRANT ALL ON TABLE "public"."view_citizens_with_node" TO "authenticated";
GRANT ALL ON TABLE "public"."view_citizens_with_node" TO "service_role";
GRANT ALL ON TABLE "public"."view_citizens_with_node" TO "noor_admin";
GRANT SELECT ON TABLE "public"."view_citizens_with_node" TO "read_only_user";



GRANT ALL ON TABLE "public"."view_culture_health_with_node" TO "anon";
GRANT ALL ON TABLE "public"."view_culture_health_with_node" TO "authenticated";
GRANT ALL ON TABLE "public"."view_culture_health_with_node" TO "service_role";
GRANT ALL ON TABLE "public"."view_culture_health_with_node" TO "noor_admin";
GRANT SELECT ON TABLE "public"."view_culture_health_with_node" TO "read_only_user";



GRANT ALL ON TABLE "public"."view_data_transactions_with_node" TO "anon";
GRANT ALL ON TABLE "public"."view_data_transactions_with_node" TO "authenticated";
GRANT ALL ON TABLE "public"."view_data_transactions_with_node" TO "service_role";
GRANT ALL ON TABLE "public"."view_data_transactions_with_node" TO "noor_admin";
GRANT SELECT ON TABLE "public"."view_data_transactions_with_node" TO "read_only_user";



GRANT ALL ON TABLE "public"."view_gov_entities_with_node" TO "anon";
GRANT ALL ON TABLE "public"."view_gov_entities_with_node" TO "authenticated";
GRANT ALL ON TABLE "public"."view_gov_entities_with_node" TO "service_role";
GRANT ALL ON TABLE "public"."view_gov_entities_with_node" TO "noor_admin";
GRANT SELECT ON TABLE "public"."view_gov_entities_with_node" TO "read_only_user";



GRANT ALL ON TABLE "public"."view_it_systems_with_node" TO "anon";
GRANT ALL ON TABLE "public"."view_it_systems_with_node" TO "authenticated";
GRANT ALL ON TABLE "public"."view_it_systems_with_node" TO "service_role";
GRANT ALL ON TABLE "public"."view_it_systems_with_node" TO "noor_admin";
GRANT SELECT ON TABLE "public"."view_it_systems_with_node" TO "read_only_user";



GRANT ALL ON TABLE "public"."view_kg_edges_expanded" TO "anon";
GRANT ALL ON TABLE "public"."view_kg_edges_expanded" TO "authenticated";
GRANT ALL ON TABLE "public"."view_kg_edges_expanded" TO "service_role";
GRANT ALL ON TABLE "public"."view_kg_edges_expanded" TO "noor_admin";
GRANT SELECT ON TABLE "public"."view_kg_edges_expanded" TO "read_only_user";



GRANT ALL ON TABLE "public"."view_kg_nodes_expanded" TO "anon";
GRANT ALL ON TABLE "public"."view_kg_nodes_expanded" TO "authenticated";
GRANT ALL ON TABLE "public"."view_kg_nodes_expanded" TO "service_role";
GRANT ALL ON TABLE "public"."view_kg_nodes_expanded" TO "noor_admin";
GRANT SELECT ON TABLE "public"."view_kg_nodes_expanded" TO "read_only_user";



GRANT ALL ON TABLE "public"."view_objective_policytool_edges" TO "anon";
GRANT ALL ON TABLE "public"."view_objective_policytool_edges" TO "authenticated";
GRANT ALL ON TABLE "public"."view_objective_policytool_edges" TO "service_role";
GRANT ALL ON TABLE "public"."view_objective_policytool_edges" TO "noor_admin";
GRANT SELECT ON TABLE "public"."view_objective_policytool_edges" TO "read_only_user";



GRANT ALL ON TABLE "public"."view_org_units_with_node" TO "anon";
GRANT ALL ON TABLE "public"."view_org_units_with_node" TO "authenticated";
GRANT ALL ON TABLE "public"."view_org_units_with_node" TO "service_role";
GRANT ALL ON TABLE "public"."view_org_units_with_node" TO "noor_admin";
GRANT SELECT ON TABLE "public"."view_org_units_with_node" TO "read_only_user";



GRANT ALL ON TABLE "public"."view_performance_datatransaction_edges" TO "anon";
GRANT ALL ON TABLE "public"."view_performance_datatransaction_edges" TO "authenticated";
GRANT ALL ON TABLE "public"."view_performance_datatransaction_edges" TO "service_role";
GRANT ALL ON TABLE "public"."view_performance_datatransaction_edges" TO "noor_admin";
GRANT SELECT ON TABLE "public"."view_performance_datatransaction_edges" TO "read_only_user";



GRANT ALL ON TABLE "public"."view_processes_with_node" TO "anon";
GRANT ALL ON TABLE "public"."view_processes_with_node" TO "authenticated";
GRANT ALL ON TABLE "public"."view_processes_with_node" TO "service_role";
GRANT ALL ON TABLE "public"."view_processes_with_node" TO "noor_admin";
GRANT SELECT ON TABLE "public"."view_processes_with_node" TO "read_only_user";



GRANT ALL ON TABLE "public"."view_projects_with_node" TO "anon";
GRANT ALL ON TABLE "public"."view_projects_with_node" TO "authenticated";
GRANT ALL ON TABLE "public"."view_projects_with_node" TO "service_role";
GRANT ALL ON TABLE "public"."view_projects_with_node" TO "noor_admin";
GRANT SELECT ON TABLE "public"."view_projects_with_node" TO "read_only_user";



GRANT ALL ON TABLE "public"."view_risks_with_node" TO "anon";
GRANT ALL ON TABLE "public"."view_risks_with_node" TO "authenticated";
GRANT ALL ON TABLE "public"."view_risks_with_node" TO "service_role";
GRANT ALL ON TABLE "public"."view_risks_with_node" TO "noor_admin";
GRANT SELECT ON TABLE "public"."view_risks_with_node" TO "read_only_user";



GRANT ALL ON TABLE "public"."view_sec_objectives_with_node" TO "anon";
GRANT ALL ON TABLE "public"."view_sec_objectives_with_node" TO "authenticated";
GRANT ALL ON TABLE "public"."view_sec_objectives_with_node" TO "service_role";
GRANT ALL ON TABLE "public"."view_sec_objectives_with_node" TO "noor_admin";
GRANT SELECT ON TABLE "public"."view_sec_objectives_with_node" TO "read_only_user";



GRANT ALL ON TABLE "public"."view_sec_performance_with_node" TO "anon";
GRANT ALL ON TABLE "public"."view_sec_performance_with_node" TO "authenticated";
GRANT ALL ON TABLE "public"."view_sec_performance_with_node" TO "service_role";
GRANT ALL ON TABLE "public"."view_sec_performance_with_node" TO "noor_admin";
GRANT SELECT ON TABLE "public"."view_sec_performance_with_node" TO "read_only_user";



GRANT ALL ON TABLE "public"."view_sec_policy_tools_with_node" TO "anon";
GRANT ALL ON TABLE "public"."view_sec_policy_tools_with_node" TO "authenticated";
GRANT ALL ON TABLE "public"."view_sec_policy_tools_with_node" TO "service_role";
GRANT ALL ON TABLE "public"."view_sec_policy_tools_with_node" TO "noor_admin";
GRANT SELECT ON TABLE "public"."view_sec_policy_tools_with_node" TO "read_only_user";



GRANT ALL ON TABLE "public"."view_vendors_with_node" TO "anon";
GRANT ALL ON TABLE "public"."view_vendors_with_node" TO "authenticated";
GRANT ALL ON TABLE "public"."view_vendors_with_node" TO "service_role";
GRANT ALL ON TABLE "public"."view_vendors_with_node" TO "noor_admin";
GRANT SELECT ON TABLE "public"."view_vendors_with_node" TO "read_only_user";



GRANT ALL ON TABLE "staging"."financial_tracking" TO "anon";
GRANT ALL ON TABLE "staging"."financial_tracking" TO "authenticated";
GRANT ALL ON TABLE "staging"."financial_tracking" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "staging"."financial_tracking" TO "noor_admin";
GRANT SELECT ON TABLE "staging"."financial_tracking" TO "supabase_admin";



GRANT ALL ON TABLE "staging"."it_systems" TO "anon";
GRANT ALL ON TABLE "staging"."it_systems" TO "authenticated";
GRANT ALL ON TABLE "staging"."it_systems" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "staging"."it_systems" TO "noor_admin";
GRANT SELECT ON TABLE "staging"."it_systems" TO "supabase_admin";



GRANT ALL ON TABLE "staging"."journeys" TO "anon";
GRANT ALL ON TABLE "staging"."journeys" TO "authenticated";
GRANT ALL ON TABLE "staging"."journeys" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "staging"."journeys" TO "noor_admin";
GRANT SELECT ON TABLE "staging"."journeys" TO "supabase_admin";



GRANT ALL ON TABLE "staging"."operational_kpis" TO "anon";
GRANT ALL ON TABLE "staging"."operational_kpis" TO "authenticated";
GRANT ALL ON TABLE "staging"."operational_kpis" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "staging"."operational_kpis" TO "noor_admin";
GRANT SELECT ON TABLE "staging"."operational_kpis" TO "supabase_admin";



GRANT ALL ON TABLE "staging"."org_structure" TO "anon";
GRANT ALL ON TABLE "staging"."org_structure" TO "authenticated";
GRANT ALL ON TABLE "staging"."org_structure" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "staging"."org_structure" TO "noor_admin";
GRANT SELECT ON TABLE "staging"."org_structure" TO "supabase_admin";



GRANT ALL ON TABLE "staging"."policy_entity_assignments" TO "anon";
GRANT ALL ON TABLE "staging"."policy_entity_assignments" TO "authenticated";
GRANT ALL ON TABLE "staging"."policy_entity_assignments" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "staging"."policy_entity_assignments" TO "noor_admin";
GRANT SELECT ON TABLE "staging"."policy_entity_assignments" TO "supabase_admin";



GRANT ALL ON TABLE "staging"."policy_tools" TO "anon";
GRANT ALL ON TABLE "staging"."policy_tools" TO "authenticated";
GRANT ALL ON TABLE "staging"."policy_tools" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "staging"."policy_tools" TO "noor_admin";
GRANT SELECT ON TABLE "staging"."policy_tools" TO "supabase_admin";



GRANT ALL ON TABLE "staging"."process_ownership" TO "anon";
GRANT ALL ON TABLE "staging"."process_ownership" TO "authenticated";
GRANT ALL ON TABLE "staging"."process_ownership" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "staging"."process_ownership" TO "noor_admin";
GRANT SELECT ON TABLE "staging"."process_ownership" TO "supabase_admin";



GRANT ALL ON TABLE "staging"."process_system_link" TO "anon";
GRANT ALL ON TABLE "staging"."process_system_link" TO "authenticated";
GRANT ALL ON TABLE "staging"."process_system_link" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "staging"."process_system_link" TO "noor_admin";
GRANT SELECT ON TABLE "staging"."process_system_link" TO "supabase_admin";



GRANT ALL ON TABLE "staging"."processes_backup" TO "anon";
GRANT ALL ON TABLE "staging"."processes_backup" TO "authenticated";
GRANT ALL ON TABLE "staging"."processes_backup" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "staging"."processes_backup" TO "noor_admin";
GRANT SELECT ON TABLE "staging"."processes_backup" TO "supabase_admin";



GRANT SELECT ON TABLE "staging"."processes_l3" TO "supabase_admin";



GRANT ALL ON TABLE "staging"."programs" TO "anon";
GRANT ALL ON TABLE "staging"."programs" TO "authenticated";
GRANT ALL ON TABLE "staging"."programs" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "staging"."programs" TO "noor_admin";
GRANT SELECT ON TABLE "staging"."programs" TO "supabase_admin";



GRANT ALL ON TABLE "staging"."resource_allocation" TO "anon";
GRANT ALL ON TABLE "staging"."resource_allocation" TO "authenticated";
GRANT ALL ON TABLE "staging"."resource_allocation" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "staging"."resource_allocation" TO "noor_admin";
GRANT SELECT ON TABLE "staging"."resource_allocation" TO "supabase_admin";



GRANT ALL ON TABLE "staging"."risk_initiative_link" TO "anon";
GRANT ALL ON TABLE "staging"."risk_initiative_link" TO "authenticated";
GRANT ALL ON TABLE "staging"."risk_initiative_link" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "staging"."risk_initiative_link" TO "noor_admin";
GRANT SELECT ON TABLE "staging"."risk_initiative_link" TO "supabase_admin";



GRANT ALL ON TABLE "staging"."risk_program_link" TO "anon";
GRANT ALL ON TABLE "staging"."risk_program_link" TO "authenticated";
GRANT ALL ON TABLE "staging"."risk_program_link" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "staging"."risk_program_link" TO "noor_admin";
GRANT SELECT ON TABLE "staging"."risk_program_link" TO "supabase_admin";



GRANT ALL ON TABLE "staging"."risk_register" TO "anon";
GRANT ALL ON TABLE "staging"."risk_register" TO "authenticated";
GRANT ALL ON TABLE "staging"."risk_register" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "staging"."risk_register" TO "noor_admin";
GRANT SELECT ON TABLE "staging"."risk_register" TO "supabase_admin";



GRANT ALL ON TABLE "staging"."roles" TO "anon";
GRANT ALL ON TABLE "staging"."roles" TO "authenticated";
GRANT ALL ON TABLE "staging"."roles" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "staging"."roles" TO "noor_admin";
GRANT SELECT ON TABLE "staging"."roles" TO "supabase_admin";



GRANT ALL ON TABLE "staging"."service_process_link" TO "anon";
GRANT ALL ON TABLE "staging"."service_process_link" TO "authenticated";
GRANT ALL ON TABLE "staging"."service_process_link" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "staging"."service_process_link" TO "noor_admin";
GRANT SELECT ON TABLE "staging"."service_process_link" TO "supabase_admin";



GRANT ALL ON TABLE "staging"."stakeholder_initiative_link" TO "anon";
GRANT ALL ON TABLE "staging"."stakeholder_initiative_link" TO "authenticated";
GRANT ALL ON TABLE "staging"."stakeholder_initiative_link" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "staging"."stakeholder_initiative_link" TO "noor_admin";
GRANT SELECT ON TABLE "staging"."stakeholder_initiative_link" TO "supabase_admin";



GRANT ALL ON TABLE "staging"."stakeholders" TO "anon";
GRANT ALL ON TABLE "staging"."stakeholders" TO "authenticated";
GRANT ALL ON TABLE "staging"."stakeholders" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "staging"."stakeholders" TO "noor_admin";
GRANT SELECT ON TABLE "staging"."stakeholders" TO "supabase_admin";



GRANT ALL ON TABLE "staging"."strategic_kpis" TO "anon";
GRANT ALL ON TABLE "staging"."strategic_kpis" TO "authenticated";
GRANT ALL ON TABLE "staging"."strategic_kpis" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "staging"."strategic_kpis" TO "noor_admin";
GRANT SELECT ON TABLE "staging"."strategic_kpis" TO "supabase_admin";



GRANT ALL ON TABLE "staging"."taxonomy" TO "anon";
GRANT ALL ON TABLE "staging"."taxonomy" TO "authenticated";
GRANT ALL ON TABLE "staging"."taxonomy" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "staging"."taxonomy" TO "noor_admin";
GRANT SELECT ON TABLE "staging"."taxonomy" TO "supabase_admin";



GRANT ALL ON SEQUENCE "staging"."taxonomy_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "staging"."taxonomy_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "staging"."taxonomy_id_seq" TO "service_role";



GRANT ALL ON TABLE "staging"."user_feedback" TO "anon";
GRANT ALL ON TABLE "staging"."user_feedback" TO "authenticated";
GRANT ALL ON TABLE "staging"."user_feedback" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "staging"."user_feedback" TO "noor_admin";
GRANT SELECT ON TABLE "staging"."user_feedback" TO "supabase_admin";



GRANT ALL ON TABLE "staging"."whitelist_tables" TO "anon";
GRANT ALL ON TABLE "staging"."whitelist_tables" TO "authenticated";
GRANT ALL ON TABLE "staging"."whitelist_tables" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "staging"."whitelist_tables" TO "noor_admin";
GRANT SELECT ON TABLE "staging"."whitelist_tables" TO "supabase_admin";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "noor_admin";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT SELECT ON TABLES TO "read_only_user";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "staging" GRANT SELECT ON TABLES TO "supabase_admin";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "staging" GRANT SELECT ON TABLES TO "service_role";



























RESET ALL;
