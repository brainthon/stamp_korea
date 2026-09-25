import argparse, json
from pathlib import Path

p=argparse.ArgumentParser()
p.add_argument('source',type=Path); p.add_argument('destination',type=Path)
p.add_argument('--batch-size',type=int,default=200)
a=p.parse_args()
records=json.loads(a.source.read_text())
destination=a.destination; destination.mkdir(parents=True,exist_ok=True)
for offset in range(0,len(records),a.batch_size):
    rows=[]
    for r in records[offset:offset+a.batch_size]:
        r.setdefault('source_image_url',r['image_url'])
        text=' '.join([r['name'],r.get('design',''),r['face_value']]).lower()
        quote=lambda x: "'"+str(x).replace("'","''")+"'"
        rows.append('('+','.join([quote(r['id']),quote(r['name']),str(int(r['year'])),quote(r['face_value']),quote(text),quote(json.dumps(r,ensure_ascii=False))+'::jsonb','false'])+')')
    sql='insert into public.official_stamp_catalog(id,name,year,face_value,search_text,data,source_verified) values\n'+',\n'.join(rows)+'\non conflict(id) do nothing;'
    (destination/f'batch-{offset//a.batch_size:03}.sql').write_text(sql)
