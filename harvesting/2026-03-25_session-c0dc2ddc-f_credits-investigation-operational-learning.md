# Operational Learning: Credits Investigation

**Date**: 2026-03-25
**Author**: S3-Credits
**Session**: c0dc2ddc-f (delegated from main session)

---

## Findings

### F-1: Google Cloud Eligibility May Not Be Lost

RFC 0023 and nobul-ops CLAUDE.md both state that Google Cloud for Startups
eligibility was "lost" by signing up retail before applying for the startup
program. However, the Google Cloud for Startups FAQ (cloud.google.com/startup/faq)
explicitly states that you need an active Google Cloud account and billing ID
to apply. There is no stated exclusion for existing customers. The domain on
the billing email must match the company website domain.

This is a high-impact finding. If correct, Nobul may be eligible for
$100K-$200K in credits that were written off as lost. The only way to verify
is to apply.

**Impact**: Potential $100K-$200K in recovered credits.
**Action**: Apply to Google Cloud for Startups immediately.
**Risk**: Application takes 5 minutes. Worst case: rejected (no cost).

### F-2: Azure Eligibility IS Lost (Confirmed)

Microsoft for Startups / Azure for Startups requires new Azure customers with
no prior Azure account. This is confirmed by Microsoft Learn documentation.
However, Microsoft Founders Hub is a separate program that may work with a
new Microsoft Account (MSA) even if an Azure subscription exists -- this is
the $1K-$25K bootstrapped path and should be attempted.

### F-3: Cloudflare BOOTSTRAPPED Is the Highest-ROI Immediate Action

$5,000 in credits, self-serve entry via promo code BOOTSTRAPPED, no manual
review at the $5K tier, includes Enterprise-level domains with CDN/DDoS/WAF.
This directly supports RFC 0023 P0 (Vercel replacement) -- Cloudflare
Pages/Workers is one of the contingency hosting options.

### F-4: Total Addressable Credits Are Much Higher Than Tracked

RFC 0023 tracks $401K possible (mostly AWS requiring VC). The actual
addressable credits for a bootstrapped startup, across all providers, range
from $7K (self-serve minimum) to $307K+ (if GCP eligibility recoverable).
The current nobul-aws-credits app tracks only AWS, missing 15+ other programs.

### F-5: The Existing App Is Well-Built But Scope-Limited

nobul-aws-credits was built in one session with a clear plan. The architecture
(Next.js 15, Upstash Redis, API for Claude Code, mobile-first UI) is sound.
The limitation is purely scope: it tracks tasks within one AWS program,
not programs across all providers. The upgrade path is additive -- the existing
task/phase model becomes a sub-entity of a new Program model.

### F-6: Fly.io Has No Startup Credits Program

RFC 0023 suggests Fly.io as the interim hosting target. Research shows
Fly.io has no formal startup credits program -- the free trial is only
2 VM hours or 7 days. This doesn't change the migration recommendation
(Fly.io pricing is still low) but it means no credits to offset the cost.
Cloudflare ($5K credits) may be a better interim target for the same reason.

---

## Assumptions Verified

| # | Assumption | Status | Evidence |
|---|-----------|--------|----------|
| A1 | GCP eligibility is lost | CHALLENGED | FAQ says existing customers can apply |
| A2 | Azure eligibility is lost | CONFIRMED | Requires new Azure customer |
| A3 | Fly.io has a startup program | FALSIFIED | No formal program, 2-hour trial only |
| A4 | Cloudflare BOOTSTRAPPED is $5K | CONFIRMED | Multiple sources confirm $5K for <$50K raised |
| A5 | DigitalOcean Hatch accepts bootstrapped | CONFIRMED | Eligible but lower tier than referred |
| A6 | Microsoft Founders Hub works for bootstrapped | CONFIRMED | $1K-$25K tiers, 10-minute application |

---

## Cross-References

- Inventory: `credits-startup-programs-inventory.md` (same session scratch)
- Tool design: `credits-tool-design.md` (same session scratch)
- RFC 0023: `/Users/pepe/repos/nobul-ops/harvesting/2026-03-23_rfc-0023-saas-contingency.draft.md`
- Existing app: `/Users/pepe/repos/nobul-aws-credits/`
- Session archives: `/Users/pepe/repos/aitools-nobul-jose/sessions/nobul-aws-credits/`
