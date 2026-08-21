# Methodology: Delivery Time Lag Risk Analysis

**Author:** K M Kadir Koushik

---

## Problem Identification

The investigation was motivated by a gap in the existing buyer risk framework: all
SLA-compliant failed deliveries were treated as behaviorally equivalent at the point of
checkout, regardless of how long the package had been in transit before the failure
occurred. A buyer whose package aged in the logistics pipeline for 10 days before being
rejected was treated identically to a buyer who rejected a package on the first attempt.

The hypothesis was that delivery timing is a measurable predictor of delivery outcome.
If true, this would open two intervention opportunities: refining buyer risk rules to
exclude late-delivery failures from COD block targeting, and creating an operational
trigger to flag aged packages before a delivery attempt is made.

---

## Data Architecture

Two tables form the analytical foundation:

**Fulfillment Core Table**
Primary source of delivery outcome data. Contains terminal delivery status, SLA
performance fields, buyer segment, and order creation date. Full snapshot table requiring
MAX_PT() for partition resolution.

The SLA filter requires both conditions applied together:
- SLA performance flag must equal the within-SLA value
- Order to RTS days must be 2 or fewer

**Logistics Detail Table**
Source of precise delivery journey timestamps per stage. Full snapshot table requiring
MAX_PT(). Introduced specifically because the fulfillment table does not carry journey
stage timestamps at the required granularity.

---

## Timestamp Engineering

Each journey stage has a primary timestamp and one or more updated timestamp variants.
The correct approach is always to take the maximum available value using GREATEST:

```sql
GREATEST(stage1_rts_ts, stage1_rts_updated_ts)                  AS rts_time
GREATEST(stage1_tts_ts, stage1_tts_updated_ts)                   AS tts_time
GREATEST(stage1_delivery_failed_ts, stage1_delivery_failed_updated_ts) AS fd_time
GREATEST(stage1_delivered_ts, stage2_delivered_ts,
         stage3_delivered_ts, stage1_delivered_updated_ts)       AS delivered_time
```

The delivery success timestamp has three stage variants because delivery confirmation
can be recorded at different points depending on the carrier and market.

---

## Time Lag Definition

**Version 1 (RTS to Outcome):** Measures from Ready to Ship to terminal outcome.
Captures the full journey from dispatch readiness. Produced first for distribution
understanding.

**Version 2 (TTS to Outcome):** Measures from Transit to Shipment to terminal outcome.
Isolates the in-transit and last-mile period only. This is the primary output used
for findings and recommendations because it reflects the period where logistics
intervention is most actionable.

---

## Bucketing Design

Days 1 through 7 as individual buckets, with day 8 and above as a single late-delivery
tail bucket. Individual day granularity in the 1 to 7 range was essential for identifying
the anomalous FD ratio spike at a specific day threshold in one market, which would have
been invisible in a coarser scheme.

---

## Limitations

Packages where the logistics table has null values for the relevant timestamp are excluded.
The April data is anomalous and should not be used as a calibration baseline. May to July
is the reliable baseline window.
