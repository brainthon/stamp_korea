export type Official = Record<string, unknown> & {id:string; name:string; year:string; face_value:string};
export type Observation = {is_stamp:boolean;name:string;visible_text:string;country:string;year:string;face_value:string};
export type Comparison = {candidate_id:string; visual_match:string; conflicting_details:boolean; readable_title_match:boolean; ambiguous:boolean};
const compact=(x:string)=>x.toLowerCase().replace(/[\s,]/g,'');

// Model confidence is not a calibrated probability. Never expose it as accuracy.
// Metadata agreement plus an unambiguous visual comparison is required for an automatic link.
export function decideMatch(observed:Observation, candidates:Official[], comparison:Comparison|null) {
  if (!observed.is_stamp || !comparison || comparison.visual_match!=='strong' || comparison.conflicting_details || comparison.ambiguous) return null;
  const candidate=candidates.find(c=>c.id===comparison.candidate_id);
  if (!candidate) return null;
  const korean=/대한민국|한국|korea/i.test(observed.country+' '+observed.visible_text);
  const year=observed.year.trim();
  const face=compact(observed.face_value);
  // Korean stamps often print the amount without 원. Do not treat a missing
  // currency suffix as a mismatch, but never equate explicit 전/환 with 원.
  const expected=compact(candidate.face_value);
  const sameFace=face===expected ||
    (korean && /^\d+(?:\.\d+)?$/.test(face) && expected===face+'원');
  if (!korean || !face || !sameFace) return null;
  // Missing evidence is different from contradictory evidence. A legible title
  // can support a strong visual match when the tiny issue year is unreadable.
  if (year && (!/^\d{4}$/.test(year) || year!==String(candidate.year))) return null;
  if (!comparison.readable_title_match && !year) return null;
  return candidate;
}

export function validReference(url:string, projectUrl:string) {
  try {
    const u=new URL(url), p=new URL(projectUrl);
    if(u.protocol!=='https:' || u.username || u.password) return false;
    const stored=u.hostname===p.hostname &&
      u.pathname.startsWith('/storage/v1/object/public/official-stamps/');
    const officialSource=u.hostname==='image.epost.go.kr' &&
      u.pathname.startsWith('/stamp/data_img/');
    return stored || officialSource;
  } catch {return false;}
}
