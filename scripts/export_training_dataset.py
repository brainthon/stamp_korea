"""Export only currently approved training opt-ins. Run on trusted admin machine.
Env: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY. Never ship the service key to Flutter.
Output stays outside source control; no model is trained by this command.
"""
import hashlib
import json
import os
from pathlib import Path
import urllib.parse
import urllib.request

base = os.environ['SUPABASE_URL'].rstrip('/')
key = os.environ['SUPABASE_SERVICE_ROLE_KEY']
out = Path(os.environ.get('TRAINING_OUTPUT', '/tmp/stamp-training-dataset'))
out.mkdir(parents=True, exist_ok=True)
if any(out.iterdir()):
    raise SystemExit('Use an empty directory so withdrawn photos cannot survive an earlier export.')
headers = {'apikey': key, 'Authorization': f'Bearer {key}'}
def get(path):
    with urllib.request.urlopen(urllib.request.Request(base + path, headers=headers), timeout=30) as response:
        return response.read()
rows = []
offset = 0
while True:
    batch = json.loads(get('/rest/v1/photo_contributions?select=id,user_id,stamp_id,image_path,consent_version&status=eq.approved&training_consent=eq.true&reference_consent=eq.true&order=id&limit=500&offset=' + str(offset)))
    rows.extend(batch)
    if len(batch) < 500:
        break
    offset += 500
manifest, hashes = [], set()
for row in rows:
    data = get('/storage/v1/object/authenticated/recognition-contributions/' + urllib.parse.quote(row['image_path']))
    digest = hashlib.sha256(data).hexdigest()
    # Avoid byte-identical leakage. Additional perceptual deduplication is required before training.
    if digest in hashes:
        continue
    active = json.loads(get('/rest/v1/photo_contributions?select=id&id=eq.' + row['id'] + '&status=eq.approved&training_consent=eq.true&reference_consent=eq.true'))
    if not active:
        continue
    hashes.add(digest)
    (out / (row['id'] + '.jpg')).write_bytes(data)
    # Keep all images by a contributor in one split to reduce train/test leakage.
    group = hashlib.sha256(row['user_id'].encode()).hexdigest()
    split = 'validation' if int(group[:8], 16) % 5 == 0 else 'train'
    manifest.append({'id': row['id'], 'stamp_id': row['stamp_id'], 'sha256': digest, 'split': split, 'consent_version': row['consent_version']})
(out / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2))
print(f'Exported {len(manifest)} opted-in reviewed photos. Revalidate IDs/consent before every training run.')
