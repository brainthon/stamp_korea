import { load } from "npm:cheerio@1.0.0";

export function portalURL(source: string): string {
  const url = new URL(source);
  if (url.protocol !== "https:" || url.hostname !== "stamp.epost.go.kr" || url.pathname !== "/sp2/sg/spsg0102.jsp") throw Error("invalid_source");
  const a=url.searchParams.get("tbsmh15seqnum"), b=url.searchParams.get("tbsmh01seqnum");
  if (!a || !b || !/^\d+$/.test(a) || !/^\d+$/.test(b)) throw Error("invalid_source");
  return `https://stamp.epost.go.kr/sp2/sg/spsg0102.jsp?tbsmh15seqnum=${a}&tbsmh01seqnum=${b}`;
}

export function parsePortal(html: string, id: string): Record<string,unknown> {
  const $=load(html), table=$("table.tbl_type02_detail");
  const fields:Record<string,string>={};
  table.find("tr").each((_,row)=>{const key=$(row).find("th").text().trim(); if(key) fields[key]=$(row).find("td").text().replace(/\s+/g," ").trim();});
  const name=table.find("caption").text().trim(), number=fields['우표번호'];
  const dates=(fields['발행일']||'').match(/\d+/g)||[];
  const description=$(".discription .text_area");
  description.find('br').replaceWith('\n');
  const text=description.text().trim();
  if (!name || !text || dates.length!==3 || id!==`epost_${number}` || !fields['액면가격']) throw Error("invalid_details");
  const day=`${dates[0].padStart(4,'0')}-${dates[1].padStart(2,'0')}-${dates[2].padStart(2,'0')}`;
  const issued=new Date(day+'T00:00:00Z');
  if (!Number.isFinite(issued.getTime()) || issued.toISOString().slice(0,10)!==day) throw Error("invalid_details");
  const image=new URL(String($("img[name=VIEWMAINIMG]").attr('src')||'').replace(/^http:/,'https:'));
  if(image.protocol!=='https:' || image.hostname!=='image.epost.go.kr' || !image.pathname.startsWith('/stamp/data_img/')) throw Error('invalid_image');
  return {id,name,stamp_number:number,year:dates[0],issue_date:day,description:text,image_url:image.href,source_image_url:image.href,
    face_value:fields['액면가격'],issue_count:fields['종수']||'',issue_volume_display:fields['발행량']||'',
    issue_volume:Number((fields['발행량']||'').match(/[\d,]+/)?.[0]?.replace(/,/g,''))||0,
    design:fields['디자인']||'',printing:fields['인쇄 및 색수']||'',sheet:fields['전지구성']||'',designer:fields['디자이너']||'',
    size:fields['우표크기']||'',image_size:fields['인면']||'',perforation:fields['천공']||'',paper:fields['용지']||'',printer:fields['인쇄처']||''};
}

export async function boundedBody(response:Response, limit:number):Promise<Uint8Array> {
  if(!response.ok || Number(response.headers.get('content-length')||0)>limit || !response.body) throw Error('source_unavailable');
  const reader=response.body.getReader(), chunks:Uint8Array[]=[]; let size=0;
  try {while(true) {const {done,value}=await reader.read(); if(done) break; size+=value.length; if(size>limit) throw Error('source_too_large'); chunks.push(value);}}
  finally {await reader.cancel();}
  const bytes=new Uint8Array(size); let offset=0; for(const part of chunks){bytes.set(part,offset);offset+=part.length;} return bytes;
}
