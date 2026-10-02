"""Validate a fresh portal crawl and prepare insert-only SQL for the trusted DB connector.
Usage: python scripts/prepare_new_stamps.py crawl.json output.sql
Never executes SQL or contains credentials. Existing records are never overwritten.
"""
import json, re, sys
from datetime import date
from pathlib import Path
from urllib.parse import urlparse

def prepare(records):
    values, rejected = [], []
    quote = lambda value: "'" + str(value).replace("'", "''") + "'"
    seen = set()
    for r in records:
        try:
            assert re.fullmatch(r'epost_\d+', r['id'])
            assert r['id'] == 'epost_' + r['stamp_number']
            issued = date.fromisoformat(r['issue_date'])
            assert str(issued.year) == str(r['year'])
            assert r['name'].strip() and r['description'].strip() and r['face_value'].strip()
            assert urlparse(r['source_url']).hostname == 'stamp.epost.go.kr'
            image = urlparse(r['image_url'])
            assert image.scheme == 'https' and image.hostname == 'image.epost.go.kr'
            assert re.fullmatch('[a-f0-9]{64}', r['source_sha256'])
            assert len(json.dumps(r)) < 100000
            if r['id'] in seen:
                continue
            seen.add(r['id'])
            text = ' '.join([r['name'], r.get('design',''), r['face_value']]).lower()
            values.append('(' + ','.join([quote(r['id']), quote(r['name']), str(issued.year), quote(r['face_value']), quote(text), quote(json.dumps(r,ensure_ascii=False))+'::jsonb','true']) + ')')
        except (AssertionError, KeyError, TypeError, ValueError):
            rejected.append(r.get('id','unknown'))
    if not values:
        raise ValueError('No valid records; database unchanged')
    sql = 'with inserted as (insert into public.official_stamp_catalog(id,name,year,face_value,search_text,data,source_verified) values\n' + ',\n'.join(values) + '\non conflict(id) do nothing returning id,name,year), logged as (insert into public.catalog_import_runs(kind,status,finished_at,imported_count,message) select \'scheduled_import\',\'success\',now(),count(*),\'신규 우표 확인 완료\' from inserted returning id) select inserted.*, logged.id as run_id from inserted cross join logged;'
    return sql, rejected

if __name__ == '__main__':
    source, output = map(Path,sys.argv[1:3])
    sql, rejected = prepare(json.loads(source.read_text()))
    output.write_text(sql)
    output.with_suffix('.rejected.json').write_text(json.dumps(rejected))
    print(json.dumps({'sql_file':str(output),'rejected':rejected}))
