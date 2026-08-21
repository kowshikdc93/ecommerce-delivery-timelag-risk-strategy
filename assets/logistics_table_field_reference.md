# Logistics Table Field Reference

**Author:** K M Kadir Koushik
**Table alias:** Logistics detail table
**Anonymised table name:** analytics.logistics_detail_df
**Partition:** ds = MAX_PT('analytics.logistics_detail_df')
**Type:** Full snapshot

---

## Key Identifiers

| Field (anonymised) | Description |
|---|---|
| `tracking_reference` | Unique package identifier — primary join key to fulfillment table |
| `market_code` | Market code — always include in join condition to prevent cross-market matches |
| `buyer_account_id` | Buyer account identifier |

---

## Journey Stage Timestamps

The delivery journey follows this sequence: RTS → TTS → Delivered or Failed

For each stage, always use GREATEST across all available variants to get the latest value.

### Ready to Ship (RTS)
Package is ready for pickup by the carrier.

| Field (anonymised) | Description |
|---|---|
| `stage1_rts_ts` | Primary RTS timestamp |
| `stage1_rts_updated_ts` | Updated RTS timestamp |

**Usage:** `GREATEST(stage1_rts_ts, stage1_rts_updated_ts) AS rts_time`

---

### Transit to Shipment (TTS)
Package has been picked up and is in active transit toward the buyer.

| Field (anonymised) | Description |
|---|---|
| `stage1_tts_ts` | Primary TTS timestamp |
| `stage1_tts_updated_ts` | Updated TTS timestamp |

**Usage:** `GREATEST(stage1_tts_ts, stage1_tts_updated_ts) AS tts_time`

---

### Delivery Failure
Package reached terminal failed status at the doorstep.

| Field (anonymised) | Description |
|---|---|
| `stage1_delivery_failed_ts` | Primary delivery failure timestamp |
| `stage1_delivery_failed_updated_ts` | Updated delivery failure timestamp |

**Usage:** `GREATEST(stage1_delivery_failed_ts, stage1_delivery_failed_updated_ts) AS fd_time`

---

### Delivery Success
Package successfully delivered to the buyer. Three stage variants exist across
different carrier confirmation flows.

| Field (anonymised) | Description |
|---|---|
| `stage1_delivered_ts` | Primary delivery success timestamp |
| `stage2_delivered_ts` | Second stage delivery confirmation timestamp |
| `stage3_delivered_ts` | Third stage delivery confirmation timestamp |
| `stage1_delivered_updated_ts` | Updated delivery success timestamp |

**Usage:** `GREATEST(stage1_delivered_ts, stage2_delivered_ts, stage3_delivered_ts, stage1_delivered_updated_ts) AS delivered_time`

---

## SLA Performance Flags

| Field (anonymised) | Description |
|---|---|
| `is_tts_on_time` | Boolean flag: whether the TTS stage was completed on time |
| `is_rts_on_time` | Boolean flag: whether the RTS stage was completed on time |

---

## 3PL Backlog Metrics

| Field (anonymised) | Description |
|---|---|
| `backlog_aging_days_from_handover` | Number of days the package has been with the current carrier since handover |
| `handover_timestamp` | Timestamp when the package was handed over to the current carrier |

---

## Standard Base CTE Pattern

```sql
,logistics_base AS (
    SELECT  tracking_reference
            ,market_code
            ,GREATEST(stage1_rts_ts, stage1_rts_updated_ts)             AS rts_time
            ,GREATEST(stage1_tts_ts, stage1_tts_updated_ts)             AS tts_time
            ,GREATEST(stage1_delivery_failed_ts,
                      stage1_delivery_failed_updated_ts)                 AS fd_time
            ,GREATEST(stage1_delivered_ts,
                      stage2_delivered_ts,
                      stage3_delivered_ts,
                      stage1_delivered_updated_ts)                       AS delivered_time
            ,is_tts_on_time
            ,is_rts_on_time
            ,backlog_aging_days_from_handover
            ,handover_timestamp

    FROM    analytics.logistics_detail_df
    WHERE   ds = MAX_PT('analytics.logistics_detail_df')
    AND     market_code IN ('MARKET_1', 'MARKET_2', 'MARKET_3', 'MARKET_4')
)
```
