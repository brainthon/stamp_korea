{{flutter_js}}
{{flutter_build_config}}

(async () => {
  // Retire only this app's legacy Flutter offline worker. Keep auth and user data.
  if ('serviceWorker' in navigator) {
    const registrations = await navigator.serviceWorker.getRegistrations();
    for (const registration of registrations) {
      const script = registration.active?.scriptURL || registration.waiting?.scriptURL || '';
      if (script.startsWith(location.origin + '/') && new URL(script).pathname.endsWith('/flutter_service_worker.js')) {
        await registration.unregister();
        for (const name of ['flutter-app-cache', 'flutter-temp-cache', 'flutter-app-manifest']) {
          await caches.delete(name);
        }
      }
    }
  }
  const version = new URLSearchParams(location.search).get('v') || '20261009-yellow-splash3';
  for (const build of _flutter.buildConfig.builds) {
    if (build.mainJsPath) build.mainJsPath += '?v=' + encodeURIComponent(version);
  }
  _flutter.loader.load();
})();
