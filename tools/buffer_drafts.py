#!/usr/bin/env python3
"""Send the build's gameplay clip to Buffer as DRAFTS (never published, never queued to go live).

Every connected channel that takes video (TikTok, YouTube Shorts, Instagram, X, Bluesky, ...) gets
one draft with the clip and a caption. Duff opens Buffer on his phone and schedules or deletes
each one: nothing goes public without his tap.

Env:
  BUFFER_API_KEY   personal key from publish.buffer.com/settings/api (a repo secret, never in code)
  VIDEO_URL        public https link to the mp4 (the dev release asset)
  CAPTION          post text
  BUFFER_CHANNELS  optional comma list of services to use, e.g. "tiktok,youtube,bluesky"
Flags: --dry-run  list what would be drafted, send nothing.
Standard library only, so CI needs no installs.
"""
import json, os, sys, urllib.request

API = "https://api.buffer.com"
VIDEO_SERVICES = {"tiktok", "youtube", "instagram", "twitter", "x", "bluesky", "threads", "facebook"}

class Enum(str):
    """A GraphQL enum value: written bare (automatic), not quoted."""


def gql(v):
    """Python value -> GraphQL literal, the same inline style as Buffer's own examples."""
    if isinstance(v, Enum):
        return str(v)
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return str(v)
    if isinstance(v, str):
        return json.dumps(v)
    if isinstance(v, list):
        return "[" + ", ".join(gql(x) for x in v) + "]"
    if isinstance(v, dict):
        return "{" + ", ".join("%s: %s" % (k, gql(x)) for k, x in v.items()) + "}"
    raise TypeError(type(v))


def draft_mutation(inp):
    return ("mutation { createPost(input: %s) { ... on PostActionSuccess { post { id } } "
            "... on MutationError { message } } }" % gql(inp))


def call(key, query, variables=None, opener=urllib.request.urlopen):
    body = json.dumps({"query": query, "variables": variables or {}}).encode()
    req = urllib.request.Request(API, data=body, method="POST", headers={
        "Content-Type": "application/json", "Authorization": "Bearer " + key,
        "User-Agent": "game-build-bot"})
    with opener(req, timeout=60) as r:
        out = json.loads(r.read().decode())
    if out.get("errors"):
        raise RuntimeError(out["errors"][0].get("message", "Buffer error"))
    return out["data"]


def draft_input(channel_id, caption, video_url):
    """The ONLY post shape this tool sends. saveToDraft is always True: a draft is not scheduled
    and is not published until Duff schedules it in Buffer."""
    return {"text": caption, "channelId": channel_id, "schedulingType": Enum("automatic"),
            "mode": Enum("addToQueue"), "saveToDraft": True,
            "assets": [{"video": {"url": video_url, "metadata": {"thumbnailOffset": 2000}}}]}


def channels(key, opener=urllib.request.urlopen):
    orgs = call(key, "query { account { organizations { id } } }", opener=opener)["account"]["organizations"]
    out = []
    for o in orgs:
        q = "query { channels(input: {organizationId: %s}) { id service displayName } }" % json.dumps(o["id"])
        out += call(key, q, opener=opener)["channels"]
    return out


def main(argv, env=os.environ, opener=urllib.request.urlopen):
    dry = "--dry-run" in argv
    key = env.get("BUFFER_API_KEY", "")
    if not key:
        print("BUFFER SKIP (no BUFFER_API_KEY secret in this repo)")
        return 0
    video, caption = env.get("VIDEO_URL", ""), env.get("CAPTION", "")
    if not video.startswith("https://"):
        print("BUFFER FAIL (VIDEO_URL must be a public https link)")
        return 1
    wanted = {s.strip().lower() for s in env.get("BUFFER_CHANNELS", "").split(",") if s.strip()}
    made = 0
    for ch in channels(key, opener):
        svc = str(ch.get("service", "")).lower()
        if svc not in VIDEO_SERVICES or (wanted and svc not in wanted):
            continue
        name = ch.get("displayName") or svc
        if dry:
            print("would draft: %s (%s)" % (name, svc))
            continue
        res = call(key, draft_mutation(draft_input(ch["id"], caption, video)), opener=opener)["createPost"]
        if "message" in res and "post" not in res:
            print("draft failed for %s: %s" % (name, res["message"]))
            continue
        print("drafted: %s (%s)" % (name, svc))
        made += 1
    print("BUFFER PASS (%d drafts waiting in Buffer; nothing posted)" % made if not dry else "BUFFER DRY RUN")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
