import json, sys
from pathlib import Path

records=json.loads(Path(sys.argv[1]).read_text())
destination=Path(sys.argv[2]); destination.mkdir(parents=True,exist_ok=True)
for offset in range(0,len(records),40):
    rows=[]
    for r in records[offset:offset+40]:
        r.setdefault('source_image_url',r['image_url'])
        text=' '.join([r['name'],r.get('design',''),r['face_value']]).lower()
        quote=lambda x: "'"+str(x).replace("'","''")+"'"
        rows.append('('+','.join([quote(r['id']),quote(r['name']),str(int(r['year'])),quote(r['face_value']),quote(text),quote(json.dumps(r,ensure_ascii=False))+'::jsonb','false'])+')')
    sql='insert into public.official_stamp_catalog(id,name,year,face_value,search_text,data,source_verified) values\n'+',\n'.join(rows)+'\non conflict(id) do nothing;'
    (destination/f'batch-{offset//40:03}.sql').write_text(sql)
