# SEO Execution Plan

## 1) Baseline Audit
- Set up Google Search Console for `https://pgp-messenger.com/`.
- Submit `https://pgp-messenger.com/sitemap.xml`.
- Record baseline: impressions, clicks, CTR, average position, top queries/pages.

## 2) Technical SEO (Implemented in code)
- Indexing directives in `index.html` (`robots`, canonical).
- `robots.txt` and `sitemap.xml` in `public/`.
- Open Graph and Twitter tags added.
- Structured data (WebSite + SoftwareApplication) added.
- Core Web Vitals instrumentation added through `web-vitals`.

## 3) On-Page Optimization (Implemented in code)
- Improved title and meta description.
- Sectioned semantic landing content with meaningful `h1/h2/h3`.
- External links hardened with `rel="noopener noreferrer"`.
- Image loading behavior improved (`loading`/`decoding` attributes).

## 4) Content Strategy (Operational)
- Build a docs/content section for:
  - PGP onboarding guide
  - Device/session security checklist
  - Secure messaging policy template
  - Troubleshooting and FAQ
- Map one primary intent keyword per page to avoid cannibalization.

## 5) Structured Data + Trust
- Keep `SoftwareApplication` pricing and app store URLs current.
- Add privacy policy and terms pages and link them from footer.
- Add organization details (support email, social profiles) once finalized.

## 6) Off-Page SEO
- Create linkable assets (security whitepaper, implementation checklist).
- Reach out to security/privacy communities and relevant app directories.
- Track referring domains and recover broken or lost backlinks.

## 7) Monitoring + Iteration
- Weekly:
  - Review Search Console queries with high impressions and low CTR.
  - Refresh title/meta for underperforming pages.
- Monthly:
  - Re-check Lighthouse/Core Web Vitals.
  - Update schema and content freshness.
  - Publish at least one new intent-focused article.
