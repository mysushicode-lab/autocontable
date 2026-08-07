import { useState, useEffect } from 'react';

export const useAuthImage = (url) => {
  const [src, setSrc] = useState(null);

  useEffect(() => {
    if (!url) {
      setSrc(null);
      return;
    }

    const isExternal = url.startsWith('http://') || url.startsWith('https://');
    const isInternalProtected = !isExternal;

    if (isExternal) {
      setSrc(url);
      return;
    }

    let objectUrl = null;
    const token = localStorage.getItem('auth_token');

    fetch(url, {
      headers: token && isInternalProtected ? { Authorization: `Bearer ${token}` } : {},
    })
      .then((res) => {
        if (!res.ok) throw new Error('image unavailable');
        return res.blob();
      })
      .then((blob) => {
        objectUrl = URL.createObjectURL(blob);
        setSrc(objectUrl);
      })
      .catch(() => setSrc(null));

    return () => {
      if (objectUrl) URL.revokeObjectURL(objectUrl);
    };
  }, [url]);

  return src;
};
