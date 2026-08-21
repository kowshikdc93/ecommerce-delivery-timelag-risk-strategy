-- ============================================================
-- 01_BASE_EXTRACTION.SQL
-- Delivery Time Lag Risk Analysis
-- Author: K M Kadir Koushik
--
-- Purpose:
--   Joins the fulfillment core table (G2N) with the logistics
--   detail table at package level to produce the foundational
--   dataset used across all downstream time lag analyses.
--
-- Key design decisions:
--   - Both tables are full snapshot tables: always use MAX_PT()
--   - SLA filter applied on the fulfillment table side only,
--     using both required conditions together
--   - Logistics table joined on tracking reference and market
--     code to prevent cross-market false matches
--   - GREATEST applied across all timestamp variants per stage
--     to ensure the latest available value is always used
--   - Outcome classification uses terminal status field only;
--     item-level status is carried through but not used for
--     outcome definition
--   - Only terminal outcomes included: failed and delivered
--     In-transit and other statuses excluded
--
-- Table naming convention (anonymised):
--   analytics.fulfillment_core_df     = G2N core table
--   analytics.logistics_detail_df     = logistics detail table
-- ============================================================

WITH fulfillment_base AS (
    -- Pull SLA-compliant packages with terminal outcomes
    -- from the fulfillment core table
    SELECT  tracking_reference                              -- anonymised: tracking_number
            ,market_code                                    -- anonymised: venture
            ,buyer_account_id                               -- anonymised: buyer_id
            ,order_reference                                -- anonymised: sales_order_id
            ,fulfillment_date                               -- anonymised: fulfillment_create_date
            ,TO_CHAR(fulfillment_date, 'yyyy-MM')           AS month
            ,terminal_delivery_status                       -- anonymised: terminal_status_ops
            ,payment_method_type                            -- anonymised: payment_type
            ,buyer_risk_segment                             -- anonymised: buyer_rankings
            ,category_level2_name
            ,CASE
                WHEN terminal_delivery_status = 'DELIVERY_FAILED' THEN 'Failed'
                WHEN terminal_delivery_status = 'DELIVERED'       THEN 'Delivered'
             END                                            AS outcome

    FROM    analytics.fulfillment_core_df
    WHERE   ds = MAX_PT('analytics.fulfillment_core_df')
    AND     market_code IN ('MARKET_1', 'MARKET_2', 'MARKET_3', 'MARKET_4')
    -- SLA filter: both conditions required together
    AND     sla_performance_flag = 'Within'
    AND     order_to_rts_days   <= 2
    -- Terminal outcomes only
    AND     terminal_delivery_status IN ('DELIVERY_FAILED', 'DELIVERED')
    AND     TO_CHAR(fulfillment_date, 'yyyy-mm-dd')
                BETWEEN '2026-01-01' AND '2026-07-31'
)

,logistics_base AS (
    -- Pull delivery journey timestamps from the logistics detail table
    -- Apply GREATEST across all variants per stage to get latest value
    SELECT  tracking_reference
            ,market_code
            ,buyer_account_id
            -- Ready to Ship timestamp
            ,GREATEST(
                stage1_rts_ts,
                stage1_rts_updated_ts
             )                                              AS rts_time
            -- Transit to Shipment timestamp
            ,GREATEST(
                stage1_tts_ts,
                stage1_tts_updated_ts
             )                                              AS tts_time
            -- Delivery failure timestamp
            ,GREATEST(
                stage1_delivery_failed_ts,
                stage1_delivery_failed_updated_ts
             )                                              AS fd_time
            -- Delivery success timestamp (multiple stage variants)
            ,GREATEST(
                stage1_delivered_ts,
                stage2_delivered_ts,
                stage3_delivered_ts,
                stage1_delivered_updated_ts
             )                                              AS delivered_time
            -- SLA performance flags from logistics side
            ,is_tts_on_time
            ,is_rts_on_time
            -- 3PL backlog metrics
            ,backlog_aging_days_from_handover
            ,handover_timestamp

    FROM    analytics.logistics_detail_df
    WHERE   ds = MAX_PT('analytics.logistics_detail_df')
    AND     market_code IN ('MARKET_1', 'MARKET_2', 'MARKET_3', 'MARKET_4')
)

-- FINAL JOIN: fulfillment core to logistics detail
-- Primary join key: tracking reference + market code
SELECT  f.tracking_reference
        ,f.market_code
        ,f.buyer_account_id
        ,f.month
        ,f.fulfillment_date
        ,f.outcome
        ,f.payment_method_type
        ,f.buyer_risk_segment
        ,f.category_level2_name
        ,l.rts_time
        ,l.tts_time
        ,l.fd_time
        ,l.delivered_time
        ,l.is_tts_on_time
        ,l.is_rts_on_time
        ,l.backlog_aging_days_from_handover
        ,l.handover_timestamp

FROM    fulfillment_base f
JOIN    logistics_base l
ON      f.tracking_reference = l.tracking_reference
AND     f.market_code        = l.market_code
;
