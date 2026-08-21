-- ============================================================
-- 02_RTS_TO_OUTCOME_TIMELAG.SQL
-- Delivery Time Lag Risk Analysis
-- Author: K M Kadir Koushik
--
-- Purpose:
--   First version of the time lag analysis measuring the number
--   of days from the Ready to Ship (RTS) timestamp to the
--   terminal delivery outcome for each package.
--
--   This version was produced to understand the full journey
--   time from when a package was ready for dispatch, including
--   the TTS stage. The follow-up analysis (03) refined this to
--   measure from TTS rather than RTS to isolate the in-transit
--   period only.
--
-- Time lag definition:
--   Failed packages:    DATEDIFF(fd_time, rts_time)
--   Delivered packages: DATEDIFF(delivered_time, rts_time)
-- ============================================================

WITH base AS (
    -- Re-produce the joined base from 01_base_extraction
    -- using the same SLA filter and timestamp logic
    SELECT  f.tracking_reference
            ,f.market_code
            ,f.month
            ,f.outcome
            ,GREATEST(l.stage1_rts_ts,
                      l.stage1_rts_updated_ts)              AS rts_time
            ,GREATEST(l.stage1_tts_ts,
                      l.stage1_tts_updated_ts)              AS tts_time
            ,GREATEST(l.stage1_delivery_failed_ts,
                      l.stage1_delivery_failed_updated_ts)  AS fd_time
            ,GREATEST(l.stage1_delivered_ts,
                      l.stage2_delivered_ts,
                      l.stage3_delivered_ts,
                      l.stage1_delivered_updated_ts)        AS delivered_time

    FROM    analytics.fulfillment_core_df f
    JOIN    analytics.logistics_detail_df l
    ON      f.tracking_reference = l.tracking_reference
    AND     f.market_code        = l.market_code
    WHERE   f.ds = MAX_PT('analytics.fulfillment_core_df')
    AND     l.ds = MAX_PT('analytics.logistics_detail_df')
    AND     f.market_code IN ('MARKET_1', 'MARKET_2', 'MARKET_3', 'MARKET_4')
    AND     f.sla_performance_flag = 'Within'
    AND     f.order_to_rts_days   <= 2
    AND     f.terminal_delivery_status IN ('DELIVERY_FAILED', 'DELIVERED')
    AND     TO_CHAR(f.fulfillment_date, 'yyyy-mm-dd')
                BETWEEN '2026-01-01' AND '2026-07-31'
)

,time_lag_computed AS (
    SELECT  tracking_reference
            ,market_code
            ,month
            ,outcome
            ,CASE
                WHEN outcome = 'Failed'
                THEN DATEDIFF(fd_time, rts_time, 'dd')
                WHEN outcome = 'Delivered'
                THEN DATEDIFF(delivered_time, rts_time, 'dd')
             END                                            AS rts_to_outcome_days

    FROM    base
    WHERE   rts_time IS NOT NULL
)

,bucketed AS (
    SELECT  market_code
            ,month
            ,outcome
            ,tracking_reference
            ,rts_to_outcome_days
            ,CASE
                WHEN rts_to_outcome_days <= 1  THEN '1 day'
                WHEN rts_to_outcome_days <= 2  THEN '2 days'
                WHEN rts_to_outcome_days <= 3  THEN '3 days'
                WHEN rts_to_outcome_days <= 4  THEN '4 days'
                WHEN rts_to_outcome_days <= 5  THEN '5 days'
                WHEN rts_to_outcome_days <= 6  THEN '6 days'
                WHEN rts_to_outcome_days <= 7  THEN '7 days'
                WHEN rts_to_outcome_days > 7   THEN '8 days and above'
                ELSE 'Unknown'
             END                                            AS time_lag_bucket

    FROM    time_lag_computed
    WHERE   rts_to_outcome_days IS NOT NULL
    AND     rts_to_outcome_days >= 0
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
