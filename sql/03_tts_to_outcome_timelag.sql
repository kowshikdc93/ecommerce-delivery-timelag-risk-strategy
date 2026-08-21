-- ============================================================
-- 03_TTS_TO_OUTCOME_TIMELAG.SQL
-- Delivery Time Lag Risk Analysis
-- Author: K M Kadir Koushik
--
-- Purpose:
--   Final version of the time lag analysis. Measures the number
--   of days from Transit to Shipment (TTS) to terminal delivery
--   outcome, isolating the in-transit and last-mile period only.
--
--   This is the primary query used for the findings and
--   recommendations in this project.
--
-- Time lag definition:
--   Failed packages:    DATEDIFF(fd_time, tts_time)
--   Delivered packages: DATEDIFF(delivered_time, tts_time)
--
-- Why TTS rather than RTS:
--   TTS is when the package physically begins its transit journey
--   toward the buyer. Measuring from TTS isolates the last-mile
--   in-transit period, which is more directly actionable for
--   logistics operations than the full RTS-to-outcome window.
--
-- Output dimensions:
--   month, market_code, outcome, time_lag_bucket
--
-- Output metrics:
--   package_count, pct_of_outcome_packages
-- ============================================================

WITH fulfillment_base AS (
    SELECT  tracking_reference
            ,market_code
            ,TO_CHAR(fulfillment_date, 'yyyy-MM')           AS month
            ,terminal_delivery_status
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
            -- Compute time lag from TTS to terminal outcome
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
            ,tts_to_outcome_days
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

SELECT  month
        ,market_code
        ,outcome
        ,time_lag_bucket
        ,COUNT(DISTINCT tracking_reference)                 AS package_count
        ,ROUND(
            COUNT(DISTINCT tracking_reference) * 100.0
            / NULLIF(SUM(COUNT(DISTINCT tracking_reference))
                OVER (PARTITION BY month, market_code, outcome)
            , 0)
        , 2)                                                AS pct_of_outcome_packages

FROM    bucketed
GROUP BY month, market_code, outcome, time_lag_bucket
ORDER BY
    month ASC
    ,market_code ASC
    ,outcome ASC
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
