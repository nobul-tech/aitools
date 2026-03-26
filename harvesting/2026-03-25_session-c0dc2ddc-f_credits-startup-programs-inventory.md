# Startup Credits Program Inventory for Nobul

**Date**: 2026-03-25
**Author**: S3-Credits (delegated)
**Constraint**: Bootstrapped, no VC, <$5M revenue, <10 employees
**Purpose**: Actionable inventory ordered by value x likelihood of acceptance

---

## CRITICAL FINDING: Google Cloud and Azure May NOT Be Lost

RFC 0023 states Google Cloud and Azure eligibility was "lost" by signing up retail. Research contradicts this:

**Google Cloud for Startups**: The FAQ explicitly states you need an active Google Cloud account and billing ID to apply. Existing customers CAN apply. The domain on the billing account email must match the company website domain. This means Nobul may still be eligible -- the assumption that signing up retail disqualifies you needs verification.

**Azure for Startups / Microsoft Founders Hub**: Confirmed LOST. The program requires new Azure customers with no prior Azure account. Existing Azure subscribers cannot apply. However, Microsoft Founders Hub ($1K-$5K bootstrapped tier) may still work if the signup path is through a separate Microsoft Account (MSA) -- verify by attempting the application.

**RECOMMENDED ACTION**: Apply to Google Cloud for Startups immediately. Worst case: rejected. Best case: $100K-$200K in credits assumed lost.

---

## Tier 1: High Value x High Likelihood (Apply This Week)

### 1. Cloudflare Startup Program -- $5,000 (BOOTSTRAPPED code)
- **Provider**: Cloudflare
- **Credits**: $5,000 (bootstrapped tier), up to $250K with accelerator/VC
- **Eligibility**: Software-based product, founded in last 5 years, not yet raised $50K
- **How to apply**: Sign up free account, add credit card, use promo code BOOTSTRAPPED
- **Duration**: 12 months
- **Benefits**: Up to 3 Enterprise-level domains, CDN, DDoS, DNS, WAF, Zero Trust
- **Status**: PURSUING (per CLAUDE.md Key Decision #8)
- **Likelihood**: VERY HIGH -- self-serve application, code-based entry, no manual review for $5K tier
- **Strategic value**: Direct Vercel replacement path. Cloudflare Pages/Workers for hosting.
- **Priority**: P0 -- apply immediately, this is the most actionable item

### 2. AWS Activate Founders -- $1,000
- **Provider**: AWS
- **Credits**: $1,000
- **Eligibility**: Self-funded startup, no provider org ID needed
- **How to apply**: aws.amazon.com/activate, Founders package
- **Duration**: 12 months
- **Status**: PURSUING (per RFC 0023)
- **Likelihood**: HIGH -- self-serve, no VC requirement
- **Prerequisite**: Professional @nobul.tech email, clear product description
- **Priority**: P0 -- apply this week

### 3. DigitalOcean Hatch -- up to $100,000
- **Provider**: DigitalOcean
- **Credits**: Variable (up to $100K for referred startups, lower for direct applicants)
- **Eligibility**: Raised $10M or less, company website, business email
- **How to apply**: Create DO team account with @nobul.tech email, fill online form
- **Duration**: 12 months
- **Benefits**: Standard-tier paid support for 15 months, up to 3 months free GPU
- **Status**: NOT APPLIED
- **Likelihood**: MEDIUM-HIGH -- bootstrapped startups eligible, but higher credits need partner referral
- **Strategic value**: Alternative hosting platform, App Platform for PaaS
- **Priority**: P1 -- apply this week

### 4. Google Cloud for Startups -- $100K-$200K (VERIFY ELIGIBILITY)
- **Provider**: Google Cloud
- **Credits**: $100K-$200K (up to $350K for AI startups)
- **Eligibility**: Founded in last 5 years, not yet funded by institutional investor (Start tier). Existing GCP account is OK.
- **How to apply**: cloud.google.com/startup/apply, use business email matching domain
- **Duration**: 24 months
- **Status**: ASSUMED LOST -- but research suggests existing customers CAN apply
- **Likelihood**: MEDIUM -- needs verification. Apply and see.
- **Strategic value**: $100K+ if approved. Massive upside for a 5-minute application.
- **Priority**: P0 -- apply immediately to verify

---

## Tier 2: High Value x Medium Likelihood (Apply This Month)

### 5. Microsoft for Startups Founders Hub -- $1,000-$25,000
- **Provider**: Microsoft (Azure)
- **Credits**: $1K (LinkedIn verification), $5K (business verification), $25K (domain + product demo)
- **Eligibility**: Privately-held, software-based product, pre-Series C. NEW Azure customers only for credits.
- **How to apply**: portal.startups.microsoft.com, takes <10 minutes
- **Duration**: 180 days per credit allotment
- **Benefits**: Microsoft 365 Business Premium, GitHub Enterprise, Visual Studio Enterprise, Dynamics 365
- **Status**: NOT APPLIED
- **Likelihood**: MEDIUM -- requires new Azure account (separate from any existing one)
- **Strategic value**: Beyond credits, the M365/GitHub Enterprise licenses have real value
- **Priority**: P1 -- worth $1K minimum for 10 minutes of work

### 6. MongoDB for Startups -- $5,000
- **Provider**: MongoDB
- **Credits**: Up to $5,000 Atlas credits
- **Eligibility**: Bootstrapped and funded startups both eligible
- **How to apply**: mongodb.com/solutions/startups
- **Duration**: 12 months
- **Benefits**: Dedicated technical advisor, co-marketing, developer ecosystem access
- **Status**: NOT APPLIED
- **Likelihood**: HIGH -- explicit bootstrapped support
- **Strategic value**: Good if Nobul uses MongoDB. Limited if not.
- **Priority**: P2 -- apply if MongoDB becomes a dependency

### 7. Neon Startup Program -- up to $100,000
- **Provider**: Neon (Postgres)
- **Credits**: Up to $100K
- **Eligibility**: Focused on venture-backed companies and accelerator programs
- **How to apply**: neon.com/startups
- **Status**: NOT APPLIED
- **Likelihood**: LOW for bootstrapped -- program targets funded startups
- **Strategic value**: Strong if Nobul adopts Postgres (nobul-auth, nobul-ops)
- **Priority**: P3 -- apply if Postgres becomes a dependency

---

## Tier 3: Moderate Value x High Likelihood (Apply This Month)

### 8. Postmark Bootstrapper Credits -- $75
- **Provider**: Postmark (ActiveCampaign)
- **Credits**: $75 account credit
- **Eligibility**: Fully launched product, charging for it, no outside investment
- **How to apply**: Sign up, message them saying you are applying for Bootstrapper credit, include pricing page link
- **Duration**: One-time credit
- **Status**: NOT APPLIED
- **Likelihood**: VERY HIGH -- explicitly designed for bootstrapped startups
- **Strategic value**: Resend contingency (RFC 0023 P5). Small but free.
- **Priority**: P2 -- trivial to apply

### 9. Twilio/SendGrid Startup Program -- $500-$5,000
- **Provider**: Twilio (owns SendGrid)
- **Credits**: $500-$5,000 in SendGrid credits depending on program
- **Eligibility**: Startup, application process
- **How to apply**: twilio.com/en-us/solutions/startups
- **Duration**: 12 months
- **Benefits**: Mentoring, networking
- **Status**: NOT APPLIED
- **Likelihood**: MEDIUM -- currently "temporarily unavailable" for new applications
- **Strategic value**: Email contingency. But Resend free tier (100/day) covers current needs.
- **Priority**: P3 -- check if program reopens

### 10. Twilio Segment Startup Program -- $50,000
- **Provider**: Twilio Segment
- **Credits**: Up to $50K on Segment Team Plan over 2 years
- **Eligibility**: Startup, application process
- **Benefits**: $1M+ in partner credits (AWS, Google Analytics, Amplitude, Intercom)
- **Status**: NOT APPLIED
- **Likelihood**: MEDIUM -- unclear bootstrapped eligibility
- **Strategic value**: High if Nobul needs CDP/analytics. The partner credits are the real prize.
- **Priority**: P2 -- investigate

---

## Tier 4: Low Value or Low Likelihood (Evaluate Later)

### 11. Railway -- up to $5,000
- **Provider**: Railway
- **Credits**: Up to $5,000 (awarded to 10 high-growth startups per cohort)
- **Eligibility**: High-growth startup, competitive selection
- **Status**: NOT APPLIED
- **Likelihood**: LOW -- very selective (10 startups per cohort)
- **Strategic value**: Vercel alternative, but Cloudflare/Fly.io are better fits

### 12. Render Startup Program -- $5,000-$25,000
- **Provider**: Render
- **Credits**: $5K (VC/accelerator referred), $10K (<$1M funding), $25K ($1M+ funding)
- **Eligibility**: Must apply through registered accelerator or VC for Build/Scale/AI tiers
- **Status**: NOT APPLIED
- **Likelihood**: LOW for bootstrapped -- VC/accelerator gated for meaningful tiers
- **Strategic value**: Hosting alternative, but VC gate defeats the purpose

### 13. Fly.io -- No Formal Program
- **Provider**: Fly.io
- **Credits**: No formal startup credits program as of 2026
- **Status**: NO PROGRAM
- **Note**: Free trial is 2 VM hours or 7 days only. No startup credits.
- **Strategic value**: Still viable as a hosting target (RFC 0023 P0), just no credits

### 14. Supabase -- $150 credits
- **Provider**: Supabase
- **Credits**: $150 via NoCo Founders or similar partner programs
- **Eligibility**: Through partner programs
- **Status**: NOT APPLIED
- **Likelihood**: MEDIUM
- **Strategic value**: Moderate -- generous free tier (500MB DB, 50K MAU) may suffice

### 15. PlanetScale -- Case-by-case migration credits
- **Provider**: PlanetScale
- **Credits**: Variable (migration assistance)
- **Status**: NOT APPLIED
- **Likelihood**: LOW -- case-by-case, migration-only
- **Strategic value**: Low unless Nobul is migrating TO PlanetScale

### 16. Netlify Jamstack Innovation Fund -- Investment, not credits
- **Provider**: Netlify
- **Credits**: Direct funding/investment, not platform credits
- **Status**: NOT APPLIED
- **Likelihood**: LOW -- investment-style program, not credit-based

---

## Already Active (No Action Needed)

| Program | Provider | Credits/Value | Expiry | Status |
|---------|----------|---------------|--------|--------|
| Auth0 for Startups | Auth0 | B2B Pro free 1yr/100K MAU | ~Mar 2027 | ACTIVE |
| Okta for Startups | Okta | WIC free 1yr/25 users | ~Mar 2027 | ACTIVE |
| Datadog Startup Program | Datadog | Pro free 1yr | ~Mar 2027 | ACTIVE |

---

## Already Denied (No Action)

| Program | Provider | Reason | Recoverable? |
|---------|----------|--------|-------------|
| Vercel Startup Program | Vercel | Requires VC affiliation | No (unless VC obtained) |
| Azure for Startups | Microsoft | Signed up retail (existing customer) | No (new account required) |

---

## Summary: Total Addressable Credits

| Scenario | Total Credits | Programs |
|----------|--------------|----------|
| Minimum (self-serve only) | ~$7,075 | Cloudflare BOOTSTRAPPED ($5K) + AWS Founders ($1K) + Postmark ($75) + Microsoft basic ($1K) |
| Likely (with applications) | ~$32K-$107K | Above + DigitalOcean Hatch ($5K-$100K) + Microsoft verified ($5K-$25K) + MongoDB ($5K) |
| Best case (if GCP not lost) | ~$132K-$307K+ | Above + Google Cloud for Startups ($100K-$200K) |

---

## Recommended Application Sequence

**Day 1 (Today)**:
1. Google Cloud for Startups -- verify eligibility (potential $100K+ upside)
2. Cloudflare BOOTSTRAPPED code -- $5K, self-serve
3. AWS Activate Founders -- $1K, self-serve

**Day 2-3**:
4. DigitalOcean Hatch -- up to $100K
5. Microsoft Founders Hub -- $1K-$25K
6. MongoDB for Startups -- $5K

**Week 2**:
7. Twilio Segment -- investigate partner credits
8. Postmark Bootstrapper -- $75
9. Review any that have opened up (SendGrid, etc.)

**Monthly**:
10. Re-check programs that gate on accelerator/VC for any policy changes
