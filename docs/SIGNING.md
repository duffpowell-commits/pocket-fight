# Signing: the keystone key

Android only installs an update over an app signed with the same key. Every Duff game is signed
with ONE key, the **keystone**: `signing/keystone.keystore.enc` (encrypted) + `signing/keystone.sha256`
(its public fingerprint), unlocked in CI by the repo secret **KEYSTONE_PASS**. Games made from this
template carry it already. **Lethemoor is the exception**: it keeps its own key, separate on purpose.
Different games keep different package names (`com.duffpowell.<repo>`), so they install side by side.

## Making the keystone (once, ever; from the phone)
1. Pick a passphrase: 5+ random words (spaces are ignored, 20+ letters). **Save it in your password
   manager first.** GitHub secrets can't be read back: lose the passphrase and the key is gone.
2. godot-game-starter on github.com -> Settings -> Secrets and variables -> Actions -> New repository
   secret. Name `KEYSTONE_PASS`, value the passphrase.
3. Actions -> **make keystone (run once)** -> Run workflow. It commits the key to main and prints the
   SHA-256. It refuses to run again once the keystone exists.

## Each game repo needs the secret (GitHub doesn't copy secrets)
Settings -> Secrets and variables -> Actions -> New repository secret: `KEYSTONE_PASS`, same
passphrase. Then push anything (or Actions -> build -> Run workflow).
A repo with no copy of the keystone fetches it from godot-game-starter at build time and checks
the fingerprint; commit a copy into the repo when convenient.

## What CI does (`signing/unlock.sh`, same file in every repo)
keystone if KEYSTONE_PASS unlocks it (a wrong passphrase fails the build) -> else a throwaway key +
a warning (that APK can't update an installed copy).

## Never
- Never commit the unlocked keystore or the passphrase, or paste the passphrase in chat.
- Never replace the keystone: every installed game would need an uninstall (and lose its save).
- Key details: alias `androiddebugkey`, store/key password `android`, RSA 4096, 100 years. The
  encryption (AES-256, PBKDF2 200k) + passphrase is the real lock.
