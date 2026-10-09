import { parseHTML } from 'npm:linkedom@0.18.12';
export const PORTAL = 'https://stamp.epost.go.kr';
export function canonicalSource(value: string): string {
  const url = new URL(value, PORTAL);
  if (url.hostname !== 'stamp.epost.go.kr' || url.pathname !== '/sp2/sg/spsg0102.jsp') throw new Error('Invalid detail URL');
  const series = url.searchParams.get('tbsmh15seqnum');
  const item = url.searchParams.get('tbsmh01seqnum');
  if (!series || !item || !/^\d+$/.test(series) || !/^\d+$/.test(item)) throw new Error('Invalid detail ID');
  return `${PORTAL}/sp2/sg/spsg0102.jsp?tbsmh15seqnum=${series}&tbsmh01seqnum=${item}`;
}
export function detailLinks(html: string): string[] {
  const { document } = parseHTML(html);
  const links = new Set<string>();
  for (const anchor of document.querySelectorAll('a[href]')) {
    const href = anchor.getAttribute('href')!;
    if (href.includes('/sp2/sg/spsg0102.jsp?')) links.add(canonicalSource(href));
  }
  if (!links.size) throw new Error('Portal list layout changed or empty');
  return [...links];
}
export async function parseDetail(html: string, source: string) {
  const { document } = parseHTML(html);
  const table = document.querySelector('table.tbl_type02_detail');
  const description = document.querySelector('.discription .text_area');
  const image = document.querySelector('img[name="VIEWMAINIMG"]');
  if (!table || !description || !image) throw new Error('Portal detail layout changed');
  const fields: Record<string, string> = {};
  for (const row of table.querySelectorAll('tr')) {
    const th = row.querySelector('th'), td = row.querySelector('td');
    if (th && td) fields[th.textContent!.trim()] = td.textContent!.trim().replace(/\s+/g, ' ');
  }
  for (const br of description.querySelectorAll('br')) br.replaceWith('\n');
  const number = fields['우표번호'];
  const parts = fields['발행일']?.match(/\d+/g);
  const name = table.querySelector('caption')?.textContent?.trim();
  const body = description.textContent!.trim().replace(/\r/g, '').replace(/\n[ \t]*\n+/g, '\n\n');
  const imageURL = new URL(image.getAttribute('src')!.replace(/^http:/, 'https:'));
  if (!/^\d+$/.test(number) || parts?.length !== 3 || !name || !body || !fields['액면가격'] || imageURL.hostname !== 'image.epost.go.kr' || imageURL.protocol !== 'https:') throw new Error('Invalid official stamp fields');
  const date = `${parts[0].padStart(4, '0')}-${parts[1].padStart(2, '0')}-${parts[2].padStart(2, '0')}`;
  if (new Date(date).toISOString().slice(0, 10) !== date) throw new Error('Invalid issue date');
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(html));
  return {
    id: `epost_${number}`, name, country: '대한민국', stamp_number: number,
    year: parts[0], issue_date: date,
    issue_volume: Number(fields['발행량']?.match(/[\d,]+/)?.[0].replaceAll(',', '') ?? 0),
    issue_volume_display: fields['발행량'] ?? '', face_value: fields['액면가격'],
    category: '우표', issue_count: fields['종수'] ?? '', design: fields['디자인'] ?? '',
    designer: fields['디자이너'] ?? '', printer: fields['인쇄처'] ?? '', printing: fields['인쇄 및 색수'] ?? '',
    size: fields['우표크기'] ?? '', image_size: fields['인면'] ?? '', perforation: fields['천공'] ?? '',
    paper: fields['용지'] ?? '', sheet: fields['전지구성'] ?? '', description: body,
    image_url: imageURL.href, source_image_url: imageURL.href, source_url: canonicalSource(source),
    source_name: '한국우표포털', match_phrases: [name, fields['디자인'] ?? ''],
    fetched_at: new Date().toISOString(), verification_status: 'source_verified',
    source_sha256: [...new Uint8Array(digest)].map(n => n.toString(16).padStart(2, '0')).join(''),
  };
}
