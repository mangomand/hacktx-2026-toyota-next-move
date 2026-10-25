#!/usr/bin/env python3
"""QA metadata checks for one B2 anchored visible finding and callout."""
import json, re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
FIXTURE=ROOT/"docs/quality/fixtures/b2-anchor-callout.json"
REGIONS={"front","front-left","left","rear-left","rear","rear-right","right","front-right","roof","interior-front","interior-rear","trunk"}
FORBIDDEN=("safe to drive","roadworthy","engine healthy","mechanical diagnosis","no damage")
def main():
 d=json.loads(FIXTURE.read_text()); assert d["format"]=="qa-b2-anchor-callout-v1" and d["metadataOnly"] is True
 src=d["source"]; assert src["mode"]=="synthetic_replay" and src["label"] in {"Replay","Demo"} and src["liveClaim"] is False
 session=ROOT/src["session"]; assert session.is_file()
 regions=d["regions"]; assert set(regions)<=REGIONS
 for region,v in regions.items():
  assert v["state"] in {"covered","partial","unseen","blocked"}
  assert v["tone"] == ("amber" if v["state"]=="partial" else "neutral")
  if v["state"] != "covered": assert v["anchor"] is None
 finding=d["finding"]; assert finding["regionId"]=="front" and regions["front"]["state"]=="covered"
 assert finding["status"]=="not_a_diagnosis" and finding["evidenceRefs"]
 refs=set(finding["evidenceRefs"]); anchor=regions["front"]["anchor"]; assert anchor and set(anchor["evidenceRefs"])==refs
 assert all((ROOT/r).is_file() for r in refs)
 text=(finding["copy"]+" "+finding["nextAction"]).lower(); assert "glare" in text and not any(x in text for x in FORBIDDEN)
 assert not re.search(r"\b(safe|clear)\b", text)
 print("B2 anchor QA passed: canonical anchor provenance, neutral/amber unknown states, evidence joins, no-diagnosis copy, labeled replay fallback")
if __name__=="__main__": main()
