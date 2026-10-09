// Decoder loads only when a HEIC photo is selected. Pixels stay on the device.
(() => {
  window.stampConvertHeic = (bytes) => new Promise((resolve, reject) => {
    if (!(bytes instanceof Uint8Array) || bytes.byteLength > 20 * 1024 * 1024) {
      reject(new Error('Invalid photo size')); return;
    }
    const worker = new Worker(new URL('heic/worker.js', document.baseURI));
    const timer = setTimeout(() => { worker.terminate(); reject(new Error('HEIC conversion timeout')); }, 55000);
    const finish = () => { clearTimeout(timer); worker.terminate(); };
    worker.onmessage = ({data}) => { finish(); data.ok ? resolve(new Uint8Array(data.bytes)) : reject(new Error('HEIC conversion failed')); };
    worker.onerror = () => { finish(); reject(new Error('HEIC decoder unavailable')); };
    // Transfer a copy, so callers retain their original bytes on failure.
    const copy = bytes.slice();
    worker.postMessage(copy.buffer, [copy.buffer]);
  });
})();
