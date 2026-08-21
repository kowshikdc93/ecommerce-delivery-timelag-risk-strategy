# Recommendations: Delivery Time Lag Risk Analysis

**Author:** K M Kadir Koushik

---

## Recommendation 1: Introduce a 7-Day Post-TTS Proactive Contact Trigger

**Priority:** High
**Owner:** Risk and Operations jointly

Any COD package not delivered within 7 days of TTS should be flagged for proactive
buyer contact before the next delivery attempt is dispatched. The contact confirms
buyer intent and address availability before a rider is sent, eliminating the logistics
cost of a failed last-mile attempt on a package that has already aged significantly.

The analysis shows that packages in the 8-days-and-above bucket carry the highest FD
ratios across all markets. A day-7 trigger ensures intervention happens at the point
where failure risk is highest but a delivery attempt has not yet been made.

---

## Recommendation 2: Investigate the Anomalous Day-6 FD Ratio Spike

**Priority:** High
**Owner:** Risk and the affected market's Operations team

Run a targeted query on packages at exactly 6 days post-TTS in the affected market to
identify whether a specific carrier handover process, hub retention limit, or SLA deadline
is causing bulk returns at that milestone rather than reattempted delivery.

The spike at a specific day threshold rather than a gradual increase is the diagnostic
signal. Genuine logistics deterioration produces a gradual curve. A spike at a specific
day points to a process trigger.

---

## Recommendation 3: Monitor the Late-Delivery Spike Market Weekly Through the Following Month

**Priority:** High
**Owner:** Risk Analytics with escalation to Operations

Track the 8-days-and-above FD concentration for the market that showed the sharp
single-month jump on a weekly basis for the following month. If the concentration
continues rising, escalate to Operations as a downstream consequence of the platform
change rather than an independent logistics problem.

Weekly monitoring rather than monthly is necessary here because the concentration
moved from 25% to 39% within a single month. At that rate of change, a monthly cadence
would be insufficient to catch a further deterioration before it becomes severe.

---

## Recommendation 4: Exclude Late-Delivery FD from COD Block Rule Targeting

**Priority:** Medium
**Owner:** Risk Analytics

Buyers whose only FD history falls in the 8-days-and-above delivery time lag bucket
should be excluded from COD block rule targeting. Their failure is driven by logistics
timing rather than checkout intent. Blocking them penalises buyers for a carrier or
pipeline failure, generating false positives and unnecessary GMV suppression.

The practical implementation is a lookup against the time lag distribution at the buyer
level: if all of a buyer's FD events fall in the late-delivery bucket and none fall in
the early-window bucket, the buyer should be excluded from the block candidate population.

---

## Recommendation 5: Adopt 3 Days Post-TTS as the Operational KPI Anchor

**Priority:** Medium
**Owner:** Risk and Operations jointly

The analysis consistently shows that 2 to 3 days post-TTS is the peak successful delivery
window across all markets. Risk recommends proposing 3 days post-TTS as the operational
trigger threshold for proactive intervention across the logistics network: buyer SMS
confirmation, rider re-routing, or hub escalation.

Packages that have not reached the buyer by day 3 have a measurably elevated failure risk.
Acting at day 3 rather than waiting for day 7 or 8 gives operations the maximum window to
intervene before the package enters the high-risk zone.
