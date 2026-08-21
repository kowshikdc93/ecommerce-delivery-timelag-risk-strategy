# Findings: Delivery Time Lag Risk Analysis

**Author:** K M Kadir Koushik

---

## Finding A: FD Ratio Increases Consistently with Delivery Time

The failed delivery ratio rises consistently as the number of days to delivery increases
across all markets and all months. The 7-day and 8-days-and-above buckets carry the
highest FD ratios without exception.

This confirms that delivery timing is a strong and consistent predictor of failure.
It is not a market-specific pattern or a monthly anomaly. It holds across all four
markets across all months in the analysis period.

---

## Finding B: Distinct Two-Population Story

Successful delivery packages concentrate heavily in the 2 to 3 day window across all
markets. Failed delivery packages concentrate in the 8-days-and-above bucket, with
the share ranging from 20% to 46% of total FD volume depending on market and month.

The contrast is stark: the peak SD concentration bucket and the peak FD concentration
bucket are separated by at least 5 days in every market. This is not a gradual shift
but a clear bimodal distribution with distinct populations.

---

## Finding C: One Market Has a Structural Late-Delivery Backlog

One market showed consistently higher FD concentration in the 8-days-and-above bucket
compared to all other markets, ranging from 27% to 46% across months. This market also
carries the highest absolute FD volume.

The pattern is structural rather than episodic: it persists across every month in the
analysis period with no improvement trend. Buyer-level COD block rules cannot address
this because the failure is driven by pipeline aging rather than checkout intent.

---

## Finding D: Sharp Late-Delivery Spike in One Market in a Single Month

A second market showed a jump from 25% to 39% FD concentration in the 8-days-and-above
bucket within a single month, the steepest single-month increase in the dataset.

This spike is inconsistent with organic logistics deterioration and was identified as a
downstream consequence of a separate platform-side change that introduced additional
order volume into the pipeline. The timing correlation between the platform change and
the late-delivery spike confirms the causal direction.

---

## Finding E: Headline FD Ratio Improvement Can Mask a Persistent Tail

One market showed improving overall FD ratios month over month, which appeared positive.
However the 8-days-and-above FD concentration held at a consistent level throughout
the same period.

This demonstrates that overall FD ratio is an insufficient monitoring metric. A market
can improve its average FD performance while still carrying an unaddressed structural
problem in the late-delivery population.

---

## Finding F: Anomalous FD Ratio Spike at a Specific Day Threshold

One market showed a disproportionately high FD ratio at exactly one specific day bucket
rather than a gradual increase across all late buckets. The FD ratio at day 6 was
significantly higher than at day 5 or day 7 in the same market.

This pattern is inconsistent with organic deterioration and suggests a specific carrier
handover process, hub retention limit, or SLA deadline at that day threshold triggering
bulk returns rather than reattempted delivery.

---

## Finding G: The First Month in the Dataset Is Anomalous

The first month of the analysis period shows materially lower FD volumes across all
markets. This is consistent with a data transition or operational ramp-up effect and
is not representative of the steady-state pattern.

May to July is the reliable baseline window. Any threshold or rule calibration derived
from this analysis should be based on this window, not the full April to July range.
