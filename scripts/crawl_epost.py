"""Permission-authorized, resumable Korea Stamp Portal catalog importer.
pip install beautifulsoup4==4.13.4
python scripts/crawl_epost.py --pages 10 --output assets/catalog/official_stamps.json
Use --pages 0 to follow all list pages. Requests are sequential and cached.
"""
import argparse, hashlib, json, re, time, subprocess
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.parse import urljoin, urlparse, parse_qs
from datetime import datetime, timezone
from bs4 import BeautifulSoup

BASE = 'https://stamp.epost.go.kr'

def fetch(url, cache):
    path = cache / (hashlib.sha256(url.encode()).hexdigest() + '.html')
    if path.exists():
        return path.read_text()
    time.sleep(1)
    for attempt in range(3):
        try:
            # curl uses the operating system's CA store; TLS verification stays enabled.
            raw = subprocess.check_output(['curl','--fail','--silent','--show-error',
                '--location','--max-time','25','--user-agent',
                'StampMoaCatalog/1.0 (permission-authorized archival import)',url])
            text = raw.decode('utf-8')
            path.write_text(text)
            return text
        except Exception:
            if attempt == 2: raise
            time.sleep(3 * (attempt + 1))

def parse_detail(html, url):
    soup = BeautifulSoup(html, 'html.parser')
    table = soup.select_one('table.tbl_type02_detail')
    if not table: raise ValueError('missing details table')
    fields = {}
    for row in table.select('tr'):
        th, td = row.find('th'), row.find('td')
        if th and td: fields[th.get_text(strip=True)] = td.get_text(' ', strip=True)
    image = soup.find('img', attrs={'name':'VIEWMAINIMG'})
    description = soup.select_one('.discription .text_area')
    if not image or not description: raise ValueError('missing image or description')
    for br in description.find_all('br'): br.replace_with('\n')
    paragraphs = re.sub(r'\n[ \t\r]*\n+', '\n\n', description.get_text().strip())
    date = re.findall(r'\d+', fields.get('발행일',''))
    number = fields.get('우표번호','')
    if len(date) != 3 or not re.fullmatch(r'\d+', number):
        raise ValueError('ambiguous number/date: ' + number)
    image_url = image['src'].replace('http://','https://')
    if urlparse(image_url).hostname != 'image.epost.go.kr': raise ValueError('unexpected image host')
    name = table.find('caption').get_text(strip=True)
    design = fields.get('디자인','')
    return dict(id='epost_'+number, name=name, country='대한민국', stamp_number=number,
        year=date[0], issue_date=f'{int(date[0]):04}-{int(date[1]):02}-{int(date[2]):02}',
        issue_volume=int(re.search(r'[\d,]+', fields.get('발행량','0')).group().replace(',','')),
        issue_volume_display=fields.get('발행량',''), face_value=fields.get('액면가격',''),
        category='우표', issue_count=fields.get('종수',''), design=design, designer=fields.get('디자이너',''),
        printer=fields.get('인쇄처',''), printing=fields.get('인쇄 및 색수',''),
        size=fields.get('우표크기',''), image_size=fields.get('인면',''),
        perforation=fields.get('천공',''), paper=fields.get('용지',''), sheet=fields.get('전지구성',''),
        description=paragraphs, image_url=image_url, source_image_url=image_url,
        source_url=url, source_name='한국우표포털', match_phrases=[name, design],
        fetched_at=datetime.now(timezone.utc).isoformat(), verification_status='source_verified',
        source_sha256=hashlib.sha256(html.encode()).hexdigest())

def main():
    p=argparse.ArgumentParser(); p.add_argument('--pages',type=int,default=10)
    p.add_argument('--output',type=Path,required=True); p.add_argument('--cache',type=Path,default=Path('.epost-cache'))
    a=p.parse_args(); a.cache.mkdir(parents=True,exist_ok=True)
    records={r['id']:r for r in json.loads(a.output.read_text())} if a.output.exists() else {}
    seen=set(); failures=[]; page=1
    while a.pages == 0 or page <= a.pages:
        html=fetch(BASE+'/sp2/sg/spsg0101.jsp?currentPage='+str(page),a.cache)
        soup=BeautifulSoup(html,'html.parser')
        links=[]
        for link in soup.select('a[href]'):
            href=link['href']
            if '/sp2/sg/spsg0102.jsp?' not in href: continue
            q=parse_qs(urlparse(href).query)
            canonical=BASE+'/sp2/sg/spsg0102.jsp?tbsmh15seqnum='+q['tbsmh15seqnum'][0]+'&tbsmh01seqnum='+q['tbsmh01seqnum'][0]
            if canonical not in seen: seen.add(canonical); links.append(canonical)
        if not links: break
        for url in links:
            try:
                record=parse_detail(fetch(url,a.cache),url)
                records[record['id']]=record
            except Exception as e: failures.append({'url':url,'error':str(e)})
        a.output.parent.mkdir(parents=True,exist_ok=True)
        a.output.write_text(json.dumps(list(records.values()),ensure_ascii=False,indent=2))
        print(f'page={page} records={len(records)} failed={len(failures)}',flush=True)
        page+=1
    a.output.with_suffix('.failures.json').write_text(json.dumps(failures,ensure_ascii=False,indent=2))

if __name__=='__main__': main()
