# Admin I ch.7 - DNS issue and fix (2026-10-20)

Problem: oc import-image failed: lookup cdn01.quay.io on 172.30.0.10:53: server misbehaving
Diagnosis: Technitium log showed 468 of 470 failures = DNSSEC validation failed, missing RRSIG for ". DNSKEY",
           all using forwarder 192.168.1.1 (ZTE router does not return DNSSEC records).
Fix: disabled DNSSEC validation in Technitium, flushed cache (deliberate lab trade-off, documented).
Result: Resolve-DnsName OK for cdn01.quay.io, registry.redhat.io, infogw.api.openshift.com;
        oc import-image httpd-imp:v1 succeeded (digest sha256:3f5d378c...).

## Admin I ch.7 - Image change trigger (2026-10-20)

- Deployment web already had a trigger on ImageStreamTag httpd:v1 (a reference tag, no digest, so no real rollout control).
- Removed it: oc set triggers deploy/web --from-image=httpd:v1 -c httpd-24 --remove
- Added: oc set triggers deploy/web --from-image=httpd-imp:v1 -c httpd-24
- Result: rollout 2/2, image pinned by digest sha256:3f5d378c...
- Evidence: web-before-trigger.yaml, web-after-trigger.yaml, web-pods-after.txt, web-triggers-after.txt
- Update test: oc tag registry.access.redhat.com/ubi8/httpd-24:latest httpd-imp:v1
  -> istag digest changed from sha256:3f5d378c... (ubi9) to sha256:f155a200... (ubi8)
  -> trigger rolled out web automatically, 2/2 Running, 0 restarts.
  -> rollback command: oc tag registry.access.redhat.com/ubi9/httpd-24:latest httpd-imp:v1
