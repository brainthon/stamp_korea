import { strict as assert } from 'node:assert';
import { canonicalSource, detailLinks, parseDetail } from './portal.ts';
const source = 'https://stamp.epost.go.kr/sp2/sg/spsg0102.jsp?tbsmh15seqnum=4237&tbsmh01seqnum=5265';
const html = `<img name="VIEWMAINIMG" src="http://image.epost.go.kr/stamp/data_img/so/example.jpg">
<table class="tbl_type02_detail"><caption>주시경 탄생 150돌</caption>
<tr><th>우표번호</th><td>3927</td></tr><tr><th>발행일</th><td>2026. 10. 8.</td></tr>
<tr><th>액면가격</th><td>500원</td></tr><tr><th>발행량</th><td>480,000(전지 30,000장)</td></tr></table>
<div class="discription"><p class="text_area">첫 문단<br><br>둘째 문단</p></div>`;
Deno.test('official detail preserves paragraphs and validates date and image host', async () => {
  const record = await parseDetail(html, source);
  assert.equal(record.id, 'epost_3927');
  assert.equal(record.issue_date, '2026-10-08');
  assert.equal(record.issue_volume, 480000);
  assert.equal(record.description, '첫 문단\n\n둘째 문단');
  assert.ok(record.image_url.startsWith('https://image.epost.go.kr/'));
  await assert.rejects(() => parseDetail(html.replace('image.epost.go.kr', 'evil.example'), source));
  await assert.rejects(() => parseDetail(html.replace('2026. 10. 8.', '2026. 2. 30.'), source));
  await assert.rejects(() => parseDetail(html.replace('VIEWMAINIMG', 'MISSING'), source));
});
Deno.test('canonical detail URLs reject unsafe hosts and deduplicate listing variants', () => {
  const variant = source + '&page_num=1';
  assert.deepEqual(detailLinks(`<a href="${source}">one</a><a href="${variant}">two</a>`), [source]);
  assert.throws(() => canonicalSource(source.replace('stamp.epost.go.kr', 'evil.example')));
  assert.throws(() => detailLinks('<html>Changed portal layout</html>'));
});
