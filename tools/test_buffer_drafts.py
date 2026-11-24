#!/usr/bin/env python3
"""Proves tools/buffer_drafts.py only ever makes DRAFTS: every post it sends has saveToDraft: true,
nothing says shareNow, and only video channels get one. Fake Buffer, no network. Prints BUFFER TEST PASS."""
import io, json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import buffer_drafts as bd

sent = []

class Resp(io.BytesIO):
    def __enter__(self): return self
    def __exit__(self, *a): pass

def fake(req, timeout=0):
    q = json.loads(req.data.decode())["query"]
    sent.append(q)
    if "organizations" in q:
        d = {"account": {"organizations": [{"id": "org1"}]}}
    elif "channels" in q:
        d = {"channels": [{"id": "c1", "service": "tiktok", "displayName": "tt"},
                          {"id": "c2", "service": "bluesky", "displayName": "bs"},
                          {"id": "c3", "service": "linkedin", "displayName": "li"}]}
    else:
        d = {"createPost": {"post": {"id": "p"}}}
    return Resp(json.dumps({"data": d}).encode())

env = {"BUFFER_API_KEY": "test", "VIDEO_URL": "https://example.com/clip.mp4", "CAPTION": "New build"}
ok = bd.main([], env=env, opener=fake) == 0
posts = [q for q in sent if "createPost" in q]
ok &= len(posts) == 2                                   # tiktok + bluesky, not linkedin
ok &= all("saveToDraft: true" in q for q in posts)
ok &= not any("shareNow" in q or "shareNext" in q for q in posts)
ok &= all('url: "https://example.com/clip.mp4"' in q for q in posts)
ok &= bd.main([], env={}, opener=fake) == 0             # no key = skip quietly
print("BUFFER TEST PASS" if ok else "BUFFER TEST FAIL")
sys.exit(0 if ok else 1)
