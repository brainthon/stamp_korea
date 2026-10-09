// Version pinned to the upstream IIFE build. This request downloads code, never photos.
self.onmessage = async ({data}) => {
  let bitmap;
  try {
    const blob = new Blob([data], {type:'image/heic'});
    try { bitmap = await createImageBitmap(blob); }
    catch (_) {
      importScripts('https://cdn.jsdelivr.net/npm/heic-to@1.6.5/dist/iife/heic-to.js');
      bitmap = await HeicTo({blob, type:'bitmap'});
    }
    if (!bitmap.width || !bitmap.height || bitmap.width * bitmap.height > 80000000) throw new Error('Invalid dimensions');
    const scale = Math.min(1, 1600 / Math.max(bitmap.width, bitmap.height));
    const canvas = new OffscreenCanvas(Math.max(1, Math.round(bitmap.width*scale)),Math.max(1, Math.round(bitmap.height*scale)));
    const context = canvas.getContext('2d');
    context.fillStyle = '#ffffff'; context.fillRect(0,0,canvas.width,canvas.height);
    context.drawImage(bitmap,0,0,canvas.width,canvas.height);
    const jpeg = await canvas.convertToBlob({type:'image/jpeg',quality:0.9});
    const bytes = await jpeg.arrayBuffer();
    self.postMessage({ok:true,bytes},[bytes]);
  } catch (_) { self.postMessage({ok:false}); }
  finally { bitmap?.close?.(); }
};
