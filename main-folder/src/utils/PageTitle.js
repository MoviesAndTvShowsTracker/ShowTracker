import { useEffect } from 'react';
import { BRAND_TAB_TITLE } from '../config/brand';

export default function PageTitle({ title }) {
  useEffect(() => {
    document.title = title ? `${title} · ${BRAND_TAB_TITLE}` : BRAND_TAB_TITLE;
  }, [title]);

  return null;
}
