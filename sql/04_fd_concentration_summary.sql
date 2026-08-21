-- ============================================================
-- 04_FD_CONCENTRATION_SUMMARY.SQL
-- Delivery Time Lag Risk Analysis
-- Author: K M Kadir Koushik
--
-- Purpose:
--   Produces a summary view combining FD and SD package counts
--   per time lag bucket with the FD ratio (FD / total packages)
--   at each bucket. This is the primary analytical output used
--   to validate Finding A (FD ratio increases with delivery time)
--   and identify the healthy delivery window.
--
-- Output:
--   One row per month, market, and time lag bucket showing:
--   - FD package count
--   - SD package count
--   - Total package count
--   - FD ratio as a percentage
--   - FD share of all FD packages in that month and market
--   - SD share of all SD packages in that month and market
-- ============================================================

WITH fulfillment_base AS (
    SELECT  tracking_reference
            ,market_code
            ,TO_CHAR(fulfillment_date, 'yyyy-MM')           AS month
            ,CASE
                WHEN terminal_delivery_status = 'DELIVERY_FAILED' THEN 'Failed'
                WHEN terminal_delivery_status = 'DELIVERED'       THEN 'Delivered'
             END                                            AS outcome

    FROM    analytics.fulfillment_core_df
    WHERE   ds = MAX_PT('analytics.fulfillment_core_df')
    AND     market_code IN ('MARKET_1', 'MARKET_2', 'MARKET_3', 'MARKET_4')
    AND     sla_performance_flag = 'Within'
    AND     order_to_rts_days   <= 2
    AND     terminal_delivery_status IN ('DELIVERY_FAILED', 'DELIVERED')
    AND     TO_CHAR(fulfillment_date, 'yyyy-mm-dd')
                BETWEEN '2026-01-01' AND '2026-07-31'
)

,logistics_base AS (
    SELECT  tracking_reference
            ,market_code
            ,GREATEST(stage1_tts_ts,
                      stage1_tts_updated_ts)                AS tts_time
            ,GREATEST(stage1_delivery_failed_ts,
                      stage1_delivery_failed_updated_ts)    AS fd_time
            ,GREATEST(stage1_delivered_ts,
                      stage2_delivered_ts,
                      stage3_delivered_ts,
                      stage1_delivered_updated_ts)          AS delivered_time

    FROM    analytics.logistics_detail_df
    WHERE   ds = MAX_PT('analytics.logistics_detail_df')
    AND     market_code IN ('MARKET_1', 'MARKET_2', 'MARKET_3', 'MARKET_4')
)

,joined AS (
    SELECT  f.tracking_reference
            ,f.market_code
            ,f.month
            ,f.outcome
            ,CASE
                WHEN f.outcome = 'Failed'
                THEN DATEDIFF(l.fd_time, l.tts_time, 'dd')
                WHEN f.outcome = 'Delivered'
                THEN DATEDIFF(l.delivered_time, l.tts_time, 'dd')
             END                                            AS tts_to_outcome_days

    FROM    fulfillment_base f
    JOIN    logistics_base l
    ON      f.tracking_reference = l.tracking_reference
    AND     f.market_code        = l.market_code
)

,bucketed AS (
    SELECT  month
            ,market_code
            ,outcome
            ,tracking_reference
            ,CASE
                WHEN tts_to_outcome_days <= 1  THEN '1 day'
                WHEN tts_to_outcome_days <= 2  THEN '2 days'
                WHEN tts_to_outcome_days <= 3  THEN '3 days'
                WHEN tts_to_outcome_days <= 4  THEN '4 days'
                WHEN tts_to_outcome_days <= 5  THEN '5 days'
                WHEN tts_to_outcome_days <= 6  THEN '6 days'
                WHEN tts_to_outcome_days <= 7  THEN '7 days'
                WHEN tts_to_outcome_days > 7   THEN '8 days and above'
                ELSE 'Unknown'
             END                                            AS time_lag_bucket

    FROM    joined
    WHERE   tts_to_outcome_days IS NOT NULL
    AND     tts_to_outcome_days >= 0
)

,pivoted AS (
    SELECT  month
            ,market_code
            ,time_lag_bucket
            ,COUNT(DISTINCT CASE WHEN outcome = 'Failed'
                                 THEN tracking_reference END)   AS fd_packages
            ,COUNT(DISTINCT CASE WHEN outcome = 'Delivered'
                                 THEN tracking_reference END)   AS sd_packages
            ,COUNT(DISTINCT tracking_reference)                 AS total_packages

    FROM    bucketed
    GROUP BY month, market_code, time_lag_bucket
)

SELECT  month
        ,market_code
        ,time_lag_bucket
        ,fd_packages
        ,sd_packages
        ,total_packages
        -- FD ratio: what share of packages in this bucket failed
        ,ROUND(
            fd_packages * 100.0 / NULLIF(total_packages, 0)
        , 2)                                                AS fd_ratio_pct
        -- FD concentration: this bucket's share of all FD in market and month
        ,ROUND(
            fd_packages * 100.0
            / NULLIF(SUM(fd_packages) OVER (PARTITION BY month, market_code), 0)
        , 2)                                                AS fd_concentration_pct
        -- SD concentration: this bucket's share of all SD in market and month
        ,ROUND(
            sd_packages * 100.0
            / NULLIF(SUM(sd_packages) OVER (PARTITION BY month, market_code), 0)
        , 2)                                                AS sd_concentration_pct

FROM    pivoted
ORDER BY
    month ASC
    ,market_code ASC
    ,CASE time_lag_bucket
        WHEN '1 day'            THEN 1
        WHEN '2 days'           THEN 2
        WHEN '3 days'           THEN 3
        WHEN '4 days'           THEN 4
        WHEN '5 days'           THEN 5
        WHEN '6 days'           THEN 6
        WHEN '7 days'           THEN 7
        WHEN '8 days and above' THEN 8
        ELSE 9
     END
;
