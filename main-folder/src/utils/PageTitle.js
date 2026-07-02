import { useEffect } from 'react';
import { BRAND_NAME } from '../config/brand';

export default function PageTitle({ title }) {
  useEffect(() => {
    document.title = title ? `${title} · ${BRAND_NAME}` : BRAND_NAME;
  }, [title]);

  return null;
}
