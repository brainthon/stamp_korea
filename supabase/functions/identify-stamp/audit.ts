// Deliberately excludes pixels, OCR, provider messages and secrets.
export function auditRecord(value:Record<string,unknown>,status:number,owner:string,id:string,model:string,duration:number) {
  const official=value.official as {id?:string}|null;
  const candidates=Array.isArray(value.candidates)?value.candidates as Array<{id?:string}>:[];
  return {id,user_id:owner,outcome:status>=400?'error':String(value.match_status||'no_match'),
    predicted_id:official?.id||null,candidate_ids:candidates.slice(0,5).map(c=>c.id).filter(Boolean),
    error_code:typeof value.code==='string'?value.code:null,duration_ms:Math.max(0,Math.round(duration)),
    model,algorithm_version:'hybrid-2026-10-04-v1'};
}
