# Delivery Time Lag Risk Analysis
### E-Commerce Risk Analytics | Failed Delivery Concentration by Delivery Journey Stage

**Author:** K M Kadir Koushik  
**Domain:** Risk Analytics | Logistics Performance | Failed Delivery Prevention  
**Stack:** ODPS SQL (MaxCompute) | Alibaba Cloud Data Warehouse | Multi-table Join Architecture  
**Venture:** South Asian E-Commerce Platform (Multi-venture)

---

## Overview

This project examines the relationship between delivery time lag and delivery outcomes across
a major South Asian e-commerce platform operating in four markets. The analysis measures
how long each package takes to reach its terminal status from the point it enters the
logistics pipeline, and identifies where failed and successful deliveries concentrate across
that time spectrum.

The central finding is that delivery timing is a strong and previously unmeasured predictor
of delivery failure. Packages delivered within 2 to 3 days succeed at the highest rate
across all markets. Packages still in the logistics pipeline beyond 7 days fail at
disproportionately high rates, yet no operational trigger existed to intervene before
a delivery attempt was made on these aged packages.

The analysis covers April to July 2026 and is scoped exclusively to SLA-compliant packages,
meaning every package in scope was processed and dispatched on time. All observed failures
are therefore attributable to buyer behavior or last-mile logistics conditions rather than
upstream operational delay.

---

## The Problem

The existing buyer risk framework evaluated all SLA-compliant failed deliveries as
behaviorally equivalent at the point of checkout. This created two structural gaps:

```
Gap 1: No delivery timing signal in buyer risk rules
       A buyer whose package failed on day 1 and a buyer whose package failed after
       10 days of transit were treated as identical risk profiles. The COD block
       framework applied the same intervention logic to both, generating false positives
       for buyers whose failure was driven by logistics delay rather than checkout intent.

Gap 2: No operational trigger for aging packages
       Packages that had been in the logistics pipeline beyond the healthy delivery
       window (2 to 3 days) continued toward delivery attempt without any proactive
       intervention. The platform absorbed the cost of a failed last-mile attempt on
       packages that were already high-risk due to their aging status.
```

This analysis directly addresses both gaps by quantifying where failed and successful
delivery packages concentrate across the delivery time lag spectrum at market and monthly
granularity.

---

## Analytical Approach

### Data Architecture

Two tables form the analytical foundation:

| Table | Purpose |
|---|---|
| Fulfillment core table (G2N) | Terminal delivery status, SLA filter, buyer segment, payment type |
| Logistics detail table | Precise delivery journey timestamps: RTS, TTS, delivery success, delivery failure |

The tables are joined at package level using the tracking reference as the primary key.

### Timestamp Logic

The logistics table stores multiple timestamp variants per journey stage to capture
system updates. The correct approach is to always take the latest available value across
all variants for each stage:

```sql
-- Ready to Ship timestamp
GREATEST(stage1_rts_ts, stage1_rts_updated_ts)                  AS rts_time

-- Transit to Shipment timestamp
GREATEST(stage1_tts_ts, stage1_tts_updated_ts)                  AS tts_time

-- Delivery failure timestamp
GREATEST(stage1_delivery_failed_ts, stage1_delivery_failed_updated_ts)
                                                                AS fd_time

-- Delivery success timestamp (multiple stage variants)
GREATEST(stage1_delivered_ts, stage2_delivered_ts,
         stage3_delivered_ts, stage1_delivered_updated_ts)      AS delivered_time
```

### Delivery Journey Sequence

```
RTS (Ready to Ship) → TTS (Transit to Shipment) → Delivered / Failed
```

### Time Lag Definition

Time lag is measured from TTS to terminal outcome:
- **Failed packages:** Days from TTS timestamp to delivery failure timestamp
- **Delivered packages:** Days from TTS timestamp to delivery success timestamp

### Bucketing

| Bucket | Range |
|---|---|
| 1 day | TTS to outcome = 1 day |
| 2 days | TTS to outcome = 2 days |
| 3 days | TTS to outcome = 3 days |
| 4 days | TTS to outcome = 4 days |
| 5 days | TTS to outcome = 5 days |
| 6 days | TTS to outcome = 6 days |
| 7 days | TTS to outcome = 7 days |
| 8 days and above | TTS to outcome > 7 days |

---

## Key Findings

### Finding A: FD Ratio Increases Consistently with Delivery Time

The failed delivery ratio rises consistently as the number of days to delivery increases
across all markets. The 7-day and 8-days-and-above buckets carry the highest FD ratios
in every market and every month without exception.

### Finding B: SD Packages Concentrate in 2 to 3 Days, FD Packages in 8 Days and Above

Successful delivery packages concentrate heavily in the 2 to 3 day window. Failed delivery
packages concentrate in the 8-days-and-above bucket, with the share ranging from 20% to 46%
of total FD volume depending on market and month.

### Finding C: One Market Has a Structural Late-Delivery Backlog Problem

One market showed consistently higher FD concentration in the 8-days-and-above bucket
compared to all other markets, ranging from 27% to 46% across months. Combined with the
highest absolute FD volume, this points to a systemic last-mile pipeline backlog that
buyer-level risk rules cannot address.

### Finding D: Another Market Showed a Sharp Late-Delivery Spike in a Single Month

A second market showed a jump from 25% to 39% FD concentration in the 8-days-and-above
bucket within a single month, the steepest single-month increase in the dataset. This
was identified as a downstream consequence of a separate platform-side change rather
than an independent logistics deterioration.

### Finding E: Overall FD Ratio Improvement Can Mask a Persistent Late-Delivery Tail

One market showed improving overall FD ratios month over month, but the 8-days-and-above
FD concentration held at a consistent level throughout. Headline FD ratio improvements
can mask structural backlog problems in the long-tail delivery population.

### Finding F: Anomalous FD Ratio Spike at a Specific Day Threshold

One market showed a disproportionately high FD ratio at exactly one specific day bucket
(day 6) rather than a gradual increase across all late buckets. This pattern is inconsistent
with organic deterioration and suggests a specific carrier handover process or hub retention
limit triggering bulk returns at that milestone.

### Finding G: The Earliest Month in the Dataset Is Anomalous

The first month in the analysis period shows materially lower FD volumes across all markets
compared to subsequent months. This is consistent with a data transition or operational
ramp-up effect and should not be used as a baseline for threshold calibration.

---

## Recommendations

| # | Recommendation | Priority |
|---|---|---|
| 1 | Introduce a proactive buyer contact trigger at day 7 post-TTS for COD packages in the high-backlog market before further delivery attempts are made | High |
| 2 | Investigate the anomalous day-6 FD ratio spike in the affected market with the logistics operations team to identify whether a carrier or hub process is triggering bulk returns at that milestone | High |
| 3 | Monitor the market showing a sharp July late-delivery spike weekly through August as an early warning system | High |
| 4 | Exclude buyers whose only FD history falls in the 8-days-and-above bucket from COD block targeting to eliminate false positives driven by logistics delay rather than buyer intent | Medium |
| 5 | Adopt 3 days post-TTS as the operational KPI anchor and trigger threshold for proactive intervention across all markets | Medium |

---

## Repository Structure

```
ecommerce-delivery-timelag-risk-analysis/
├── README.md                                    # This file
├── sql/
│   ├── 01_base_extraction.sql                   # G2N and logistics table join with timestamp logic
│   ├── 02_rts_to_outcome_timelag.sql            # Time lag analysis from RTS to terminal outcome
│   ├── 03_tts_to_outcome_timelag.sql            # Time lag analysis from TTS to terminal outcome (final)
│   └── 04_fd_concentration_summary.sql          # FD concentration summary with FD ratio by bucket
├── docs/
│   ├── methodology.md                           # Full analytical methodology and design decisions
│   ├── findings.md                              # Detailed findings with market-level context
│   └── recommendations.md                       # Recommendations with business justification
└── assets/
    └── logistics_table_field_reference.md       # Confirmed field definitions for the logistics table
```

---

## Skills Demonstrated

- **Multi-table join architecture:** Joining a fulfillment core table to a logistics detail
  table at package level with venture-scoped partition filters on both sides
- **Timestamp engineering:** GREATEST function applied across multiple timestamp variants
  per journey stage to ensure the latest available value is used in all calculations
- **Time window analysis:** Unix timestamp arithmetic for precise day-level lag computation
  across delivery journey stages
- **Distribution analysis:** Bucketed concentration analysis with percentage-of-total window
  functions partitioned by market, month, and outcome
- **Anomaly detection:** Identifying structural versus organic deterioration patterns from
  distribution data across multiple markets and time periods
- **Operational recommendation design:** Translating analytical findings into specific
  intervention triggers with defined ownership and priority

---

*This project was conducted as part of a delivery risk analytics initiative at a major South
Asian e-commerce platform. All table names, field names, schema references, market names,
and specific figures have been anonymised or generalised for public sharing. The analytical
logic, timestamp engineering, methodology, findings, and recommendations are original work.*
